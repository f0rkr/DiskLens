import SwiftUI
import AppKit
import Observation

/// One file or folder staged for deletion in the in-app Bin.
struct BinItem: Identifiable, Hashable, Codable {
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
        case byApp = "Apps"
        case byType = "By Type"
        case duplicates = "Duplicates"
        case similar = "Similar"
        case cleanup = "Cleanup"
        case reclaim = "Reclaim"
        case bin = "Bin"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview:   return "chart.pie.fill"
            case .breakdown:  return "list.bullet.indent"
            case .treemap:    return "square.grid.3x3.fill"
            case .files:      return "doc.text.magnifyingglass"
            case .byApp:      return "square.grid.2x2.fill"
            case .byType:     return "tag.fill"
            case .duplicates: return "doc.on.doc.fill"
            case .similar:    return "photo.on.rectangle.angled"
            case .cleanup:    return "sparkles"
            case .reclaim:    return "arrow.3.trianglepath"
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
    var lastDelta: ScanDelta?        // what grew/shrank vs the previous scan of this folder
    var lastHistory: [ScanSnapshot] = []   // saved snapshots of this folder, for the trend chart
    var diskStats: DiskStats?        // free/total for the scanned folder's volume
    var unreadableCount = 0          // directories skipped because they couldn't be read
    var availableUpdate: String?     // a newer release version, when the update check finds one
    var isUpdating = false           // downloading/installing a self-update
    var updateError: String?         // why a self-update attempt failed
    var isArchiving = false          // compressing a folder before trashing the original

    // Derived analyses (computed lazily after a scan / on demand)
    var duplicateGroups: [DuplicateGroup] = []
    var isFindingDuplicates = false
    var duplicateProgress = ""
    var didRunDuplicates = false

    var similarGroups: [SimilarGroup] = []
    var isFindingSimilar = false
    var similarProgress = ""
    var didRunSimilar = false

    var hiddenSpace: HiddenSpace?    // Time Machine snapshots + purgeable, for the Reclaim view

    var appUsages: [AppUsage] = []   // per-application storage ("By App"), on demand
    var isScanningApps = false
    var appsProgress = ""
    var didRunApps = false

    var isWatching = false           // live folder watching (FSEvents)
    var folderChanged = false        // the watched folder changed since the last scan

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
    private let binKey = "binItems"
    private var scanTask: Task<Void, Never>?
    private var dupTask: Task<Void, Never>?
    private var similarTask: Task<Void, Never>?
    private var appsTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: FolderWatcher?

    init() {
        UserDefaults.standard.register(defaults: ["checkForUpdates": true])
        loadRecents()
        loadBin()
        watcher = FolderWatcher { [weak self] in
            Task { @MainActor in self?.handleFolderChange() }
        }
    }

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
        similarTask?.cancel()
        isScanning = true
        filesScanned = 0
        currentPath = url.path
        scannedRoot = url
        addRecent(url)
        folderChanged = false
        if isWatching { watcher?.start(path: url.path) }
        rootNode = nil
        insights = ScanInsights()
        duplicateGroups = []
        didRunDuplicates = false
        similarGroups = []
        didRunSimilar = false
        hiddenSpace = nil
        cleanupSuggestions = []
        lastActionMessage = nil
        lastDelta = nil
        lastHistory = []
        diskStats = nil
        unreadableCount = 0

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var deniedCount = 0
            let node = ScanEngine.buildTree(
                at: url,
                isCancelled: { Task.isCancelled },
                progress: { count, path in
                    Task { @MainActor [weak self] in
                        self?.filesScanned = count
                        self?.currentPath = path
                    }
                },
                onUnreadable: { _ in deniedCount += 1 })
            // Heavy work runs off the main actor so the UI never walks the tree.
            let insights = node.map { ScanInsights.compute(from: $0) } ?? ScanInsights()
            let cleanup = node.map { CleanupRules.analyze($0) } ?? []
            let delta = node.flatMap { ScanHistory.record($0, path: url.path) }
            let history = ScanHistory.history(for: url.path)
            let disk = DiskStats.current(for: url)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !Task.isCancelled {
                    self.rootNode = node
                    self.insights = insights
                    self.cleanupSuggestions = cleanup
                    self.lastDelta = delta
                    self.lastHistory = history
                    self.diskStats = disk
                    self.unreadableCount = deniedCount
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
        similarTask?.cancel()
        appsTask?.cancel()
        watcher?.stop()
        isScanning = false
        isFindingDuplicates = false
        isFindingSimilar = false
        isScanningApps = false
        isWatching = false
        folderChanged = false
        rootNode = nil
        scannedRoot = nil
        insights = ScanInsights()
        duplicateGroups = []
        didRunDuplicates = false
        similarGroups = []
        didRunSimilar = false
        hiddenSpace = nil
        cleanupSuggestions = []
        lastActionMessage = nil
        lastDelta = nil
        lastHistory = []
        diskStats = nil
        unreadableCount = 0
        appUsages = []
        didRunApps = false
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

    // MARK: - Similar photos (Vision; on-demand, the expensive pass)

    func findSimilarPhotos() {
        guard let root = rootNode, !isFindingSimilar else { return }
        similarTask?.cancel()
        isFindingSimilar = true
        similarProgress = "Starting…"
        similarGroups = []

        similarTask = Task.detached(priority: .userInitiated) { [weak self] in
            let groups = SimilarImages.find(
                in: root,
                isCancelled: { Task.isCancelled },
                progress: { msg in Task { @MainActor [weak self] in self?.similarProgress = msg } })
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !Task.isCancelled {
                    self.similarGroups = groups
                    self.didRunSimilar = true
                }
                self.isFindingSimilar = false
            }
        }
    }

    func cancelSimilar() {
        similarTask?.cancel()
        isFindingSimilar = false
    }

    // MARK: - Per-app storage (on demand; independent of the folder scan)

    func findApps() {
        guard !isScanningApps else { return }
        appsTask?.cancel()
        isScanningApps = true
        appsProgress = "Starting…"
        appUsages = []

        appsTask = Task.detached(priority: .userInitiated) { [weak self] in
            let apps = AppUsageScanner.scan(
                isCancelled: { Task.isCancelled },
                progress: { msg in Task { @MainActor [weak self] in self?.appsProgress = msg } })
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !Task.isCancelled {
                    self.appUsages = apps
                    self.didRunApps = true
                }
                self.isScanningApps = false
            }
        }
    }

    func cancelApps() {
        appsTask?.cancel()
        isScanningApps = false
    }

    // MARK: - Live folder watching (FSEvents)

    func toggleWatch() {
        isWatching.toggle()
        if isWatching, let r = scannedRoot {
            folderChanged = false
            watcher?.start(path: r.path)
        } else {
            watcher?.stop()
        }
    }

    private func handleFolderChange() {
        guard isWatching, !isScanning else { return }
        if UserDefaults.standard.bool(forKey: "autoRescan"), let r = scannedRoot {
            scan(r)
        } else {
            folderChanged = true
        }
    }

    // MARK: - Hidden space (Time Machine local snapshots, purgeable)

    func refreshHiddenSpace() async {
        let vol = scannedRoot ?? URL(fileURLWithPath: NSHomeDirectory())
        hiddenSpace = await Task.detached { HiddenSpaceScanner.scan(volume: vol) }.value
    }

    func reclaimSnapshots() async {
        _ = await Task.detached { HiddenSpaceScanner.reclaimSnapshots() }.value
        lastActionMessage = "Thinned Time Machine local snapshots."
        await refreshHiddenSpace()
        if let r = scannedRoot { diskStats = DiskStats.current(for: r) }
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
        saveBin()
    }

    func toggleBin(_ node: FileNode) {
        if binURLs.contains(node.url) { removeFromBin(node.url) } else { addToBin(node) }
    }

    func removeFromBin(_ url: URL) {
        binURLs.remove(url)
        binItems.removeAll { $0.url == url }
        saveBin()
    }

    /// Un-stage everything without deleting.
    func clearBin() {
        binItems.removeAll()
        binURLs.removeAll()
        saveBin()
    }

    // The Bin survives quits: persisted to UserDefaults, reloaded on launch
    // (dropping anything that no longer exists on disk).
    private func loadBin() {
        guard let data = UserDefaults.standard.data(forKey: binKey),
              let saved = try? JSONDecoder().decode([BinItem].self, from: data) else { return }
        let existing = saved.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        binItems = existing
        binURLs = Set(existing.map(\.url))
        if existing.count != saved.count { saveBin() }   // prune vanished items
    }

    private func saveBin() {
        if let data = try? JSONEncoder().encode(binItems) {
            UserDefaults.standard.set(data, forKey: binKey)
        }
    }

    /// Commit the bin: move every staged item to the Trash (recoverable), then
    /// empty the bin. Re-scans so sizes stay accurate, and the result is undoable.
    func emptyBin() {
        guard !binItems.isEmpty else { return }
        let items = binItems.map { (url: $0.url, size: $0.size) }
        clearBin()
        trash(items)
    }

    // MARK: - Update check (opt-out in Preferences)

    func maybeCheckForUpdate() async {
        guard UserDefaults.standard.bool(forKey: "checkForUpdates") else { return }
        if let v = await UpdateChecker.latestIfNewer() { availableUpdate = v }
    }

    /// Download and install the latest release, then relaunch. On success the
    /// app quits (a helper finishes the swap); on failure we surface the reason.
    func installUpdate() async {
        guard !isUpdating else { return }
        isUpdating = true
        updateError = nil
        do {
            try await Updater.installLatest()
        } catch {
            updateError = error.localizedDescription
            isUpdating = false
        }
    }

    // MARK: - Export

    /// Save a Markdown report of the current scan to a file the user picks,
    /// then reveal it in Finder.
    func exportReport() {
        guard let root = rootNode else { return }
        let text = ReportBuilder.markdown(root: root, insights: insights, scannedRoot: scannedRoot, date: Date())
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DiskLens-\(scannedRoot?.lastPathComponent ?? "scan").md"
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = true
        panel.title = "Export scan report"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            lastActionMessage = "Couldn't save the report: \(error.localizedDescription)"
        }
    }

    /// Compress a file/folder into a .zip the user picks, then move the original
    /// to the Trash (recoverable) — reclaim space while keeping the data.
    func compressAndTrash(_ url: URL, size: Int64) {
        guard !isArchiving else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent + ".zip"
        panel.directoryURL = url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.title = "Compress and archive"
        guard panel.runModal() == .OK, let dest = panel.url else { return }

        isArchiving = true
        lastActionMessage = "Compressing \(url.lastPathComponent)…"
        Task.detached(priority: .userInitiated) {
            let ok = Archiver.zip(source: url, to: dest)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isArchiving = false
                guard ok else { self.lastActionMessage = "Couldn't create the archive."; return }
                let result = TrashHelper.moveToTrash([(url: url, size: size)])
                self.lastTrashPairs = result.restorePairs
                self.pendingMessage = "Archived to \(dest.lastPathComponent); original moved to the Trash."
                if let root = self.scannedRoot {
                    self.scan(root)
                } else {
                    self.lastActionMessage = self.pendingMessage
                    self.pendingMessage = nil
                }
            }
        }
    }
}
