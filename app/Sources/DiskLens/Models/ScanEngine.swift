import Foundation

/// Recursively walks a directory and builds a `FileNode` tree with aggregated
/// allocated sizes. Pure & `nonisolated` so it can run off the main actor.
enum ScanEngine {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .nameKey,
        .contentModificationDateKey
    ]

    static func buildTree(at root: URL,
                          isCancelled: @escaping () -> Bool,
                          progress: @escaping (Int, String) -> Void) -> FileNode? {
        var counter = 0

        func recurse(_ url: URL) -> FileNode? {
            if isCancelled() { return nil }

            let values = try? url.resourceValues(forKeys: keys)
            let name = values?.name ?? url.lastPathComponent
            let isSymlink = values?.isSymbolicLink ?? false
            let isDir = values?.isDirectory ?? false

            // Never follow symlinks — avoids cycles and double-counting.
            if isSymlink {
                let node = FileNode(url: url, name: name, isDirectory: false, isSymlink: true, size: 0)
                node.fileCount = 0
                return node
            }

            if isDir {
                let node = FileNode(url: url, name: name, isDirectory: true)
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(keys),
                    options: [])) ?? []

                var total: Int64 = 0
                var count = 0
                var kids: [FileNode] = []
                kids.reserveCapacity(contents.count)
                for child in contents {
                    if isCancelled() { break }
                    if let c = recurse(child) {
                        total += c.size
                        count += c.fileCount
                        c.parent = node
                        kids.append(c)
                    }
                }
                node.size = total
                node.fileCount = count
                node.children = kids.sorted { $0.size > $1.size }

                counter += 1
                if counter & 0xFF == 0 { progress(counter, url.path) }
                return node
            } else {
                let size = Int64(values?.totalFileAllocatedSize
                                 ?? values?.fileAllocatedSize
                                 ?? values?.fileSize
                                 ?? 0)
                let node = FileNode(url: url, name: name, isDirectory: false, size: size)
                node.fileCount = 1
                node.modifiedAt = values?.contentModificationDate
                counter += 1
                if counter & 0xFF == 0 { progress(counter, url.path) }
                return node
            }
        }

        let result = recurse(root)
        progress(counter, root.path)
        return result
    }
}
