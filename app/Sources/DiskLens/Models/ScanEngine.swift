import Foundation

/// Recursively walks a directory and builds a `FileNode` tree with aggregated
/// allocated sizes. Pure & `nonisolated` so it can run off the main actor.
enum ScanEngine {
    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey, .nameKey,
        .contentModificationDateKey
    ]
    private static let prefetchKeys = Array(keys)

    /// Absolute locations we never descend into while scanning (unless the user
    /// explicitly picks one as the scan root): the read-only system volume, other
    /// mounted volumes, VM swap, device files, and system metadata. They're huge
    /// and/or not user-reclaimable — descending into them is what made a
    /// whole-Mac scan ("/") crawl and the UI feel buggy.
    private static let excludedPaths: Set<String> = [
        "/System", "/Volumes", "/dev", "/net", "/home", "/cores", "/.vol",
        "/private/var/vm", "/private/var/folders", "/private/var/db/diagnostics",
        "/.Spotlight-V100", "/.fseventsd", "/.DocumentRevisions-V100",
        "/.TemporaryItems", "/.Trashes", "/.PKInstallSandboxManager-SystemSoftware"
    ]

    /// Whether `path` is a system location we skip on a full-disk scan.
    static func isExcludedSystemPath(_ path: String) -> Bool {
        excludedPaths.contains(path)
    }

    static func buildTree(at root: URL,
                          isCancelled: @escaping () -> Bool,
                          progress: @escaping (Int, String) -> Void) -> FileNode? {
        var counter = 0
        let rootPath = root.path
        var lastEmit = DispatchTime.now()

        // Report progress at most ~12×/sec. A whole-Mac scan touches millions of
        // files; hopping to the main actor for each one floods the UI. Gate on a
        // cheap counter mask first, then on elapsed time.
        func tick(_ path: String, force: Bool = false) {
            counter += 1
            guard force || counter & 0x3FF == 0 else { return }
            let now = DispatchTime.now()
            if force || now.uptimeNanoseconds &- lastEmit.uptimeNanoseconds > 80_000_000 {
                lastEmit = now
                progress(counter, path)
            }
        }

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
                // Skip excluded system locations (but honor an explicit choice to
                // scan one directly as the root).
                if url.path != rootPath && isExcludedSystemPath(url.path) {
                    return nil
                }

                let node = FileNode(url: url, name: name, isDirectory: true)
                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: prefetchKeys,
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
                tick(url.path)
                return node
            } else {
                let size = Int64(values?.totalFileAllocatedSize
                                 ?? values?.fileAllocatedSize
                                 ?? values?.fileSize
                                 ?? 0)
                let node = FileNode(url: url, name: name, isDirectory: false, size: size)
                node.fileCount = 1
                node.modifiedAt = values?.contentModificationDate
                tick(url.path)
                return node
            }
        }

        let result = recurse(root)
        progress(counter, root.path)   // always emit a final, accurate count
        return result
    }
}
