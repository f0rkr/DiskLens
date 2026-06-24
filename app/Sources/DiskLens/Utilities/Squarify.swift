import Foundation
import CoreGraphics

struct TreemapTile: Identifiable {
    let id: UUID
    let node: FileNode
    let rect: CGRect
}

/// Squarified treemap layout (Bruls, Huizing & van Wijk). Produces tiles whose
/// areas are proportional to node sizes and whose aspect ratios stay close to 1.
enum Squarify {
    static func layout(_ nodes: [FileNode], in bounds: CGRect) -> [TreemapTile] {
        let items = nodes.filter { $0.size > 0 }
        let totalSize = items.reduce(0) { $0 + $1.size }
        guard totalSize > 0, bounds.width > 1, bounds.height > 1 else { return [] }

        let totalArea = Double(bounds.width) * Double(bounds.height)
        let scale = totalArea / Double(totalSize)

        struct Item { let node: FileNode; let area: Double }
        var remaining = items.map { Item(node: $0, area: Double($0.size) * scale) }
        var rect = bounds
        var tiles: [TreemapTile] = []

        func worst(_ areas: [Double], _ side: Double) -> Double {
            guard let mn = areas.min(), let mx = areas.max(), mn > 0 else { return .infinity }
            let s = areas.reduce(0, +)
            guard s > 0, side > 0 else { return .infinity }
            let s2 = s * s
            return Swift.max((side * side * mx) / s2, s2 / (side * side * mn))
        }

        while !remaining.isEmpty {
            let side = Double(min(rect.width, rect.height))
            var row: [Item] = []
            var i = 0
            while i < remaining.count {
                let candidate = row + [remaining[i]]
                if row.isEmpty ||
                    worst(candidate.map { $0.area }, side) <= worst(row.map { $0.area }, side) {
                    row = candidate
                    i += 1
                } else {
                    break
                }
            }

            let rowArea = row.reduce(0) { $0 + $1.area }
            if rect.width >= rect.height {
                let w = CGFloat(rowArea) / rect.height
                var y = rect.minY
                for it in row {
                    let h = rect.height * CGFloat(it.area / rowArea)
                    tiles.append(TreemapTile(id: it.node.id, node: it.node,
                                             rect: CGRect(x: rect.minX, y: y, width: w, height: h)))
                    y += h
                }
                rect = CGRect(x: rect.minX + w, y: rect.minY,
                              width: rect.width - w, height: rect.height)
            } else {
                let h = CGFloat(rowArea) / rect.width
                var x = rect.minX
                for it in row {
                    let w = rect.width * CGFloat(it.area / rowArea)
                    tiles.append(TreemapTile(id: it.node.id, node: it.node,
                                             rect: CGRect(x: x, y: rect.minY, width: w, height: h)))
                    x += w
                }
                rect = CGRect(x: rect.minX, y: rect.minY + h,
                              width: rect.width, height: rect.height - h)
            }
            remaining.removeFirst(row.count)
        }
        return tiles
    }
}
