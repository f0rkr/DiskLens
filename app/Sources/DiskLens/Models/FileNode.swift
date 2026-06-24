import Foundation

/// A node in the scanned filesystem tree. Reference type so children can point
/// back at their parent and so the (potentially large) tree isn't copied around.
final class FileNode: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let isSymlink: Bool

    /// Aggregated allocated size in bytes (sum of all descendants for directories).
    var size: Int64
    /// Total number of regular files at or below this node.
    var fileCount: Int = 0
    /// Last content-modification date (for the "old & large" finder).
    var modifiedAt: Date?
    /// Children sorted largest-first. Empty for files.
    var children: [FileNode] = []
    weak var parent: FileNode?

    init(url: URL, name: String, isDirectory: Bool, isSymlink: Bool = false, size: Int64 = 0) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.isSymlink = isSymlink
        self.size = size
    }

    /// `nil` for leaves so `OutlineGroup`/treemap treat them as terminal.
    var childrenOrNil: [FileNode]? {
        (isDirectory && !children.isEmpty) ? children : nil
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }
}
