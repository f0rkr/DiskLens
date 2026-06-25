import SwiftUI

/// One slice of the "usage by type" breakdown.
struct CategoryStat: Identifiable {
    let id = UUID()
    let kind: FileColor.Kind
    let label: String
    let bytes: Int64
    let count: Int
    var color: Color { FileColor.color(forKind: kind) }
}

/// A generic labeled slice (used for the by-extension and by-age breakdowns).
struct GroupStat: Identifiable {
    let id = UUID()
    let label: String
    let bytes: Int64
    let count: Int
}

/// Pre-computed aggregates for the Overview charts. Built once per scan (off the
/// main actor) so the charts never walk the tree during rendering.
struct ScanInsights {
    var totalBytes: Int64 = 0
    var totalFiles: Int = 0
    var categories: [CategoryStat] = []   // file types, largest-first
    var topItems: [FileNode] = []         // largest top-level items
    var topFiles: [FileNode] = []         // largest individual files anywhere
    var byExtension: [GroupStat] = []     // usage by file extension, largest-first (top 30)
    var byAge: [GroupStat] = []           // usage by file age, newest bucket first

    var largestName: String { topItems.first?.name ?? "None" }

    nonisolated static func compute(from root: FileNode, now: Date = Date()) -> ScanInsights {
        var bytesByKind: [FileColor.Kind: Int64] = [:]
        var countByKind: [FileColor.Kind: Int] = [:]
        var bytesByExt: [String: Int64] = [:]
        var countByExt: [String: Int] = [:]
        let ageLabels = ["Last 30 days", "1-6 months", "6-12 months", "1-2 years", "2+ years", "Unknown date"]
        var bytesByAge = [Int64](repeating: 0, count: ageLabels.count)
        var countByAge = [Int](repeating: 0, count: ageLabels.count)
        func ageIndex(_ d: Date?) -> Int {
            guard let d else { return 5 }
            let days = now.timeIntervalSince(d) / 86_400
            if days < 30 { return 0 }
            if days < 180 { return 1 }
            if days < 365 { return 2 }
            if days < 730 { return 3 }
            return 4
        }

        // Keep only the largest `limit` files, sorted descending, via a bounded
        // insert — so a whole-Mac scan (millions of files) never builds and sorts
        // a giant array. Most files fail the `> threshold` test in O(1).
        let limit = 250
        var top: [FileNode] = []
        top.reserveCapacity(limit + 1)
        var threshold: Int64 = 0   // smallest size currently kept (once full)

        func consider(_ n: FileNode) {
            if top.count < limit {
                let i = top.firstIndex { $0.size < n.size } ?? top.count
                top.insert(n, at: i)
                if top.count == limit { threshold = top[limit - 1].size }
            } else if n.size > threshold {
                let i = top.firstIndex { $0.size < n.size } ?? top.count
                top.insert(n, at: i)
                top.removeLast()
                threshold = top[limit - 1].size
            }
        }

        func walk(_ n: FileNode) {
            if n.isDirectory {
                for c in n.children { walk(c) }
            } else if !n.isSymlink {
                let k = FileColor.kind(for: n)
                bytesByKind[k, default: 0] += n.size
                countByKind[k, default: 0] += 1
                let ext = n.fileExtension.isEmpty ? "(none)" : n.fileExtension
                bytesByExt[ext, default: 0] += n.size
                countByExt[ext, default: 0] += 1
                let ai = ageIndex(n.modifiedAt)
                bytesByAge[ai] += n.size
                countByAge[ai] += 1
                if n.size > 0 { consider(n) }
            }
        }
        walk(root)

        let order: [FileColor.Kind] = [.code, .media, .document, .archive, .app, .data, .other]
        var cats: [CategoryStat] = []
        for k in order {
            let b = bytesByKind[k] ?? 0
            if b > 0 {
                cats.append(CategoryStat(kind: k, label: FileColor.label(for: k),
                                         bytes: b, count: countByKind[k] ?? 0))
            }
        }
        cats.sort { $0.bytes > $1.bytes }

        var insights = ScanInsights()
        insights.totalBytes = root.size
        insights.totalFiles = root.fileCount
        insights.categories = cats
        insights.topItems = Array(root.children.prefix(10))
        insights.topFiles = top   // already the largest, sorted descending
        insights.byExtension = bytesByExt
            .map { GroupStat(label: $0.key, bytes: $0.value, count: countByExt[$0.key] ?? 0) }
            .sorted { $0.bytes > $1.bytes }
            .prefix(30).map { $0 }
        insights.byAge = ageLabels.enumerated()
            .filter { bytesByAge[$0.offset] > 0 || countByAge[$0.offset] > 0 }
            .map { GroupStat(label: $0.element, bytes: bytesByAge[$0.offset], count: countByAge[$0.offset]) }
        return insights
    }
}
