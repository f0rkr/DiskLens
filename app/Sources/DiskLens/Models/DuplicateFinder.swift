import Foundation
import CryptoKit

/// A set of byte-identical files.
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let size: Int64           // size of one file
    let files: [URL]
    /// Bytes recoverable if all but one copy were removed.
    var reclaimable: Int64 { size * Int64(max(0, files.count - 1)) }
}

enum DuplicateFinder {
    /// Finds duplicate files under `root`. Strategy: bucket by size first (cheap),
    /// then hash only the files that share a size (expensive). Skips empty files.
    static func find(in root: FileNode,
                     isCancelled: @escaping () -> Bool,
                     progress: @escaping (String) -> Void) -> [DuplicateGroup] {
        // Collect (size, url) for every regular file.
        var bySize: [Int64: [URL]] = [:]
        func collect(_ node: FileNode) {
            if isCancelled() { return }
            if node.isDirectory {
                for c in node.children { collect(c) }
            } else if !node.isSymlink, node.size > 0 {
                bySize[node.size, default: []].append(node.url)
            }
        }
        collect(root)

        var groups: [DuplicateGroup] = []
        for (size, urls) in bySize where urls.count > 1 {
            if isCancelled() { break }
            progress("Comparing \(urls.count) files of \(ByteFormat.string(size))…")
            var byHash: [String: [URL]] = [:]
            for url in urls {
                if isCancelled() { break }
                if let h = hash(of: url) {
                    byHash[h, default: []].append(url)
                }
            }
            for (_, matched) in byHash where matched.count > 1 {
                groups.append(DuplicateGroup(size: size, files: matched))
            }
        }
        return groups.sorted { $0.reclaimable > $1.reclaimable }
    }

    /// Streaming SHA-256 so we never load a whole file into memory.
    private static func hash(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try? handle.read(upToCount: 1 << 20) // 1 MB
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
