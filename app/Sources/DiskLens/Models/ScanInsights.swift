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

/// Pre-computed aggregates for the Overview charts. Built once per scan (off the
/// main actor) so the charts never walk the tree during rendering.
struct ScanInsights {
    var totalBytes: Int64 = 0
    var totalFiles: Int = 0
    var categories: [CategoryStat] = []   // file types, largest-first
    var topItems: [FileNode] = []         // largest top-level items
    var topFiles: [FileNode] = []         // largest individual files anywhere

    var largestName: String { topItems.first?.name ?? "—" }

    nonisolated static func compute(from root: FileNode) -> ScanInsights {
        var bytesByKind: [FileColor.Kind: Int64] = [:]
        var countByKind: [FileColor.Kind: Int] = [:]
        var files: [FileNode] = []

        func walk(_ n: FileNode) {
            if n.isDirectory {
                for c in n.children { walk(c) }
            } else if !n.isSymlink {
                let k = FileColor.kind(for: n)
                bytesByKind[k, default: 0] += n.size
                countByKind[k, default: 0] += 1
                if n.size > 0 { files.append(n) }
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
        insights.topFiles = Array(files.sorted { $0.size > $1.size }.prefix(250))
        return insights
    }
}
