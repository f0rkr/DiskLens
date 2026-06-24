import SwiftUI
import AppKit
import Observation

/// One file or folder staged for deletion in the in-app Bin.
struct BinItem: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let name: String
    let isDirectory: Bool
    var id: URL { url }
}

@MainActor
@Observable
final class AppModel {
    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case breakdown = "Breakdown"
        case treemap = "Treemap"
        case files = "Files"
        case duplicates = "Duplicates"
        case cleanup = "Cleanup"
        case bin = "Bin"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview:   return "chart.pie.fill"
            case .breakdown:  return "list.bullet.indent"
            case .treemap:    return "square.grid.3x3.fill"
            case .files:      return "doc.text.magnifyingglass"
            case .duplicates: return "doc.on.doc.fill"
            case .cleanup:    return "sparkles"
            case .bin:        return "xmark.bin.fill"
            }
        }
    }

    // Scan state
    var rootNode: FileNode?
    var scannedRoot: URL?
    var isScanning = false
    var filesScanned = 0
    var currentPath = ""
    var selection: Section = .overview
    var insights = ScanInsights()

    // Derived analyses (computed lazily after a scan / on demand)
    var duplicateGroups: [DuplicateGroup] = []
    var isFindingDuplicates = false
    var duplicateProgress = ""
    var didRunDuplicates = false

    var cleanupSuggestions: [CleanupSuggestion] = []

    var lastActionMessage: String?
    var lastTrashPairs: [(original: URL, trashed: URL)] = []
    var recentFolders: [URL] = []

    // In-app Bin: files staged for deletion. Nothing is removed until the user
    // empties the bin, and even then everything just moves to the Trash.
    var binItems: [BinItem] = []
    private var binURLs: Set<URL> = []

    private var pendingMessage: String?
    private let recentsKey = "recentFolders"
    private var scanTask: Task<Void, Never>?
    private var dupTask: Task<Void, Never>?

    init() { loadRecents() }

    func loadRecents() {
        let paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        recentFolders = paths.map { URL(fileURLWithPath: $0) }
    }

    private func addRecent(_ url: URL) {
        var paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        paths = Array(paths.prefix(6))
        UserDefaults.standard.set(paths, forKey: recentsKey)
        recentFolders = paths.map { URL(fileURLWithPath: $0) }
    }

    // MARK: - Folder selection

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Choose a folder to analyze"
        if panel.runModal() == .OK, let url = panel.url {
            scan(url)
        }
    }

    var quickFolders: [(String, String, URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("Home", "house.fill", home),
            ("Downloads", "arrow.down.circle.fill", home.appending(path: "Downloads")),
            ("Documents", "doc.fill", home.appending(path: "Documents")),
            ("Desktop", "menubar.dock.rectangle", home.appending(path: "Desktop")),
            ("Library", "books.vertical.fill", home.appending(path: "Library"))
        ]
    }

    // MARK: - Scanning

    func scan(_ url: URL) {
        scanTask?.cancel()
        dupTask?.cancel()
        isScanning = true
        filesScanned = 0
        currentPath = url.path
        scannedRoot = url
        addRecent(url)
        rootNode = nil
        insights = ScanInsights()
        duplicateGroups = []
        didRunDuplicates = false
        cleanupSuggestions = []
        lastActionMessage = nil

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let node = ScanEngine.buildTree(
                at: url,
                isCancelled: { Task.isCancelled },
                progress: { count, path in
                    Task { @MainActor [weak self] in
                        self?.filesScanned = count
                        self?.currentPath = path
                    }
                })
            // Heavy aggregation runs off the main actor so the UI never walks the tree.
            let insights = node.map { ScanInsights.compute(from: $0) } ?? ScanInsights()
            let cleanup = node.map { CleanupRules.analyze($0) } ?? []
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !Task.isCancelled {
                    self.rootNode = node
                    self.insights = insights
                    self.cleanupSuggestions = cleanup
                    self.lastActionMessage = self.pendingMessage
                    self.pendingMessage = nil
                }
                self.isScanning = false
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
    }

    /// Clear everything and return to the folder-choosing screen.
    func reset() {
        scanTask?.cancel()
        dupTask?.cancel()
        isScanning = false
        isFindingDuplicates = false
        rootNode = nil
        scannedRoot = nil
        insights = ScanInsights()
        duplicateGroups = []
        didRunDuplicates = false
        cleanupSuggestions = []
        lastActionMessage = nil
    }

    // MARK: - Duplicates (run on demand — it's the expensive pass)

    func findDuplicates() {
        guard let root = rootNode, !isFindingDuplicates else { return }
        dupTask?.cancel()
        isFindingDuplicates = true
        duplicateProgress = "Starting…"
        duplicateGroups = []

        dupTask = Task.detached(priority: .userInitiated) { [weak self] in
            let groups = DuplicateFinder.find(
                in: root,
                isCancelled: { Task.isCancelled },
                progress: { msg in
                    Task { @MainActor [weak self] in self?.duplicateProgress = msg }
                })
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !Task.isCancelled {
                    self.duplicateGroups = groups
                    self.didRunDuplicates = true
                }
                self.isFindingDuplicates = false
            }
        }
    }

    func cancelDuplicates() {
        dupTask?.cancel()
        isFindingDuplicates = false
    }

    // MARK: - Deletion

    /// Moves items to Trash and re-scans so sizes stay accurate.
    func trash(_ items: [(url: URL, size: Int64)]) {
        guard !items.isEmpty else { return }
        let result = TrashHelper.moveToTrash(items)
        lastTrashPairs = result.restorePairs
        var msg = "Moved \(result.trashedCount) item(s) — \(ByteFormat.string(result.trashedBytes)) to Trash."
        if !result.failures.isEmpty {
            msg += " \(result.failures.count) couldn't be removed."
        }
        pendingMessage = msg
        if let root = scannedRoot { scan(root) }
    }

    /// Undo the most recent trash by moving the items back from the Trash.
    func undoLastTrash() {
        guard !lastTrashPairs.isEmpty else { return }
        let n = TrashHelper.restore(lastTrashPairs)
        lastTrashPairs = []
        pendingMessage = "Restored \(n) item(s)."
        if let root = scannedRoot { scan(root) }
    }

    /// Move a single item to the Trash (used by per-row actions everywhere).
    func trashOne(_ url: URL, size: Int64) {
        trash([(url: url, size: size)])
    }

    // MARK: - Bin (staged deletions)

    var binTotalBytes: Int64 { binItems.reduce(0) { $0 + $1.size } }
    func isInBin(_ url: URL) -> Bool { binURLs.contains(url) }

    func addToBin(_ node: FileNode) {
        addToBin(url: node.url, size: node.size, name: node.name, isDirectory: node.isDirectory)
    }

    /// Stage a file/folder for deletion. `isDirectory` is auto-detected when not given.
    func addToBin(url: URL, size: Int64, name: String? = nil, isDirectory: Bool? = nil) {
        guard !binURLs.contains(url) else { return }
        let isDir = isDirectory
            ?? ((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false)
        binURLs.insert(url)
        binItems.append(BinItem(url: url, size: size,
                                name: name ?? url.lastPathComponent, isDirectory: isDir))
    }

    func toggleBin(_ node: FileNode) {
        if binURLs.contains(node.url) { removeFromBin(node.url) } else { addToBin(node) }
    }

    func removeFromBin(_ url: URL) {
        binURLs.remove(url)
        binItems.removeAll { $0.url == url }
    }

    /// Un-stage everything without deleting.
    func clearBin() {
        binItems.removeAll()
        binURLs.removeAll()
    }

    /// Commit the bin: move every staged item to the Trash (recoverable), then
    /// empty the bin. Re-scans so sizes stay accurate, and the result is undoable.
    func emptyBin() {
        guard !binItems.isEmpty else { return }
        let items = binItems.map { (url: $0.url, size: $0.size) }
        clearBin()
        trash(items)
    }
}
