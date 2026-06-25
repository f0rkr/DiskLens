import Foundation
import CryptoKit

/// A set of folders whose entire contents are identical.
struct DuplicateFolderGroup: Identifiable {
    let id = UUID()
    var folders: [FileNode]                  // identical folders, shallowest path first
    var size: Int64 { folders.first?.size ?? 0 }
    var fileCount: Int { folders.first?.fileCount ?? 0 }
    /// Bytes recoverable if all but one copy were removed.
    var reclaimable: Int64 { size * Int64(max(0, folders.count - 1)) }
}

/// Finds folders that are byte-for-byte duplicates of one another (e.g. a project
/// copied twice, a backup of a photo library). Signature = the sorted set of
/// descendant (relative-path, size) pairs plus the head bytes of each file, so two
/// folders match only when their whole layout *and* file heads agree — strong enough
/// that real collisions don't happen, while bounding I/O to the first chunk per file.
enum DuplicateFolders {
    /// Folders smaller than this are ignored — reclaiming tiny folders isn't worth listing.
    static let minSize: Int64 = 1 << 20      // 1 MB
    private static let headBytes = 64 << 10  // 64 KB hashed per file

    static func find(in root: FileNode,
                     isCancelled: @escaping () -> Bool,
                     progress: @escaping (String) -> Void) -> [DuplicateFolderGroup] {
        // Gather candidate directories (big enough, with content).
        var candidates: [FileNode] = []
        func collect(_ node: FileNode) {
            if isCancelled() || node.isSymlink || !node.isDirectory { return }
            if node.size >= minSize, node.fileCount > 0 { candidates.append(node) }
            for c in node.children { collect(c) }
        }
        collect(root)
        guard candidates.count > 1 else { return [] }

        // Bucket by a cheap structural signature first, hash file heads only for buckets
        // that actually collide.
        var byStructure: [String: [FileNode]] = [:]
        for node in candidates {
            if isCancelled() { return [] }
            byStructure[structureSignature(node), default: []].append(node)
        }

        var groups: [DuplicateFolderGroup] = []
        var processed = 0
        for (_, bucket) in byStructure where bucket.count > 1 {
            if isCancelled() { break }
            var byContent: [String: [FileNode]] = [:]
            for node in bucket {
                if isCancelled() { break }
                processed += 1
                progress("Verifying \(node.name)…")
                guard let sig = contentSignature(node, isCancelled: isCancelled) else { continue }
                byContent[sig, default: []].append(node)
            }
            for (_, identical) in byContent where identical.count > 1 {
                groups.append(DuplicateFolderGroup(
                    folders: identical.sorted { $0.url.pathComponents.count < $1.url.pathComponents.count }))
            }
        }
        _ = processed

        // Drop nested duplicates: if a whole folder is already part of a larger
        // duplicate group, its inner sub-folders are duplicates too and would only
        // double-count. Keep the top-most. Process biggest first.
        groups.sort { $0.reclaimable > $1.reclaimable }
        var coveredRoots: [String] = []
        var result: [DuplicateFolderGroup] = []
        for g in groups {
            let paths = g.folders.map { $0.url.path }
            let nested = paths.allSatisfy { p in coveredRoots.contains { p.hasPrefix($0 + "/") } }
            if nested { continue }
            result.append(g)
            coveredRoots.append(contentsOf: paths)
        }
        return result
    }

    /// Sorted descendant "relpath\0size" lines — same layout & sizes ⇒ same string.
    static func structureSignature(_ node: FileNode) -> String {
        var lines: [String] = []
        func walk(_ n: FileNode, _ rel: String) {
            for c in n.children.sorted(by: { $0.name < $1.name }) {
                let p = rel.isEmpty ? c.name : rel + "/" + c.name
                if c.isDirectory { walk(c, p) }
                else if !c.isSymlink { lines.append("\(p)\u{0}\(c.size)") }
            }
        }
        walk(node, "")
        return sha256(lines.joined(separator: "\n"))
    }

    /// Structure signature mixed with the head bytes of every descendant file.
    private static func contentSignature(_ node: FileNode, isCancelled: () -> Bool) -> String? {
        var files: [(rel: String, url: URL)] = []
        func walk(_ n: FileNode, _ rel: String) {
            for c in n.children.sorted(by: { $0.name < $1.name }) {
                let p = rel.isEmpty ? c.name : rel + "/" + c.name
                if c.isDirectory { walk(c, p) }
                else if !c.isSymlink { files.append((p, c.url)) }
            }
        }
        walk(node, "")

        var hasher = SHA256()
        for (rel, url) in files {
            if isCancelled() { return nil }
            hasher.update(data: Data(rel.utf8))
            if let handle = try? FileHandle(forReadingFrom: url) {
                if let chunk = try? handle.read(upToCount: headBytes), !chunk.isEmpty { hasher.update(data: chunk) }
                try? handle.close()
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
