import Foundation
import Vision
import ImageIO

/// A set of visually-similar images (not byte-identical — those are Duplicates).
struct SimilarGroup: Identifiable {
    let id = UUID()
    var files: [FileNode]                       // similar images, largest first
    var size: Int64 { files.first?.size ?? 0 }
    var reclaimable: Int64 { files.dropFirst().reduce(0) { $0 + $1.size } }
}

/// Finds visually-similar photos using Vision feature prints (on-device, no deps).
/// Catches resized/re-encoded/lightly-edited copies that SHA-256 dedup misses.
enum SimilarImages {
    static let imageExts: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"]
    private static let maxImages = 3000          // cap so huge libraries stay responsive
    static let defaultThreshold: Float = 0.30    // smaller distance = more similar

    /// Pure grouping core (no Vision), so it's unit-testable: greedily clusters
    /// indices whose pairwise `distance` is under `threshold` (within the same bucket).
    static func groupIndices(_ n: Int,
                             threshold: Float,
                             sameBucket: (Int, Int) -> Bool,
                             distance: (Int, Int) -> Float?) -> [[Int]] {
        var used = [Bool](repeating: false, count: n)
        var groups: [[Int]] = []
        for i in 0..<n where !used[i] {
            var group = [i]; used[i] = true
            for j in (i + 1)..<n where !used[j] {
                guard sameBucket(i, j) else { continue }
                if let d = distance(i, j), d < threshold { group.append(j); used[j] = true }
            }
            if group.count > 1 { groups.append(group) }
        }
        return groups
    }

    static func find(in root: FileNode,
                     threshold: Float = defaultThreshold,
                     isCancelled: @escaping () -> Bool,
                     progress: @escaping (String) -> Void) -> [SimilarGroup] {
        var images: [FileNode] = []
        func collect(_ n: FileNode) {
            if isCancelled() || n.isSymlink { return }
            if n.isDirectory { for c in n.children { collect(c) } }
            else if imageExts.contains(n.fileExtension), n.size > 0 { images.append(n) }
        }
        collect(root)
        images.sort { $0.size > $1.size }
        if images.count > maxImages { images = Array(images.prefix(maxImages)) }
        guard images.count > 1 else { return [] }

        // Feature print + aspect bucket per image.
        var nodes: [FileNode] = []
        var prints: [VNFeaturePrintObservation] = []
        var buckets: [Int] = []
        nodes.reserveCapacity(images.count)
        for (i, img) in images.enumerated() {
            if isCancelled() { return [] }
            if i % 20 == 0 { progress("Analyzing \(i + 1) of \(images.count) images…") }
            guard let fp = featurePrint(img.url) else { continue }
            nodes.append(img); prints.append(fp); buckets.append(aspectBucket(img.url))
        }
        guard nodes.count > 1 else { return [] }

        let clusters = groupIndices(
            nodes.count, threshold: threshold,
            sameBucket: { buckets[$0] == buckets[$1] },
            distance: { a, b in
                var dist: Float = 0
                return (try? prints[a].computeDistance(&dist, to: prints[b])) != nil ? dist : nil
            })

        return clusters
            .map { idxs in SimilarGroup(files: idxs.map { nodes[$0] }.sorted { $0.size > $1.size }) }
            .sorted { $0.reclaimable > $1.reclaimable }
    }

    private static func featurePrint(_ url: URL) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(url: url, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    /// Coarse aspect-ratio bucket so we only compare similarly-shaped images.
    private static func aspectBucket(_ url: URL) -> Int {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double,
              let h = props[kCGImagePropertyPixelHeight] as? Double, h > 0 else { return 0 }
        return Int((w / h * 4).rounded())
    }
}
