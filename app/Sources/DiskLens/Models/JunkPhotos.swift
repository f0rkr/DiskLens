import Foundation
import ImageIO
import CoreGraphics
import CoreServices

/// A photo flagged as likely junk — either out-of-focus or a screen capture.
struct JunkPhoto: Identifiable {
    let id = UUID()
    let node: FileNode
    let reason: Reason
    let sharpness: Double          // Laplacian variance; lower = blurrier (0 for screenshots)
    enum Reason: String { case blurry = "Blurry", screenshot = "Screenshot" }
}

/// Finds low-value photos with on-device analysis (no third-party deps):
///   • blurry shots — measured by the variance of the Laplacian, a classic focus metric
///   • screen captures — Spotlight's `kMDItemIsScreenCapture` flag, backed by a name heuristic
/// Everything is review-first: results show thumbnails and only stage to the Bin.
enum JunkPhotos {
    private static let maxImages = 4000
    /// Laplacian-variance threshold (on an 8-bit, ≤256px grayscale). Below this a
    /// photo is considered likely out of focus. Conservative to avoid false hits.
    static let blurThreshold = 70.0

    static func find(in root: FileNode,
                     blurThreshold: Double = blurThreshold,
                     isCancelled: @escaping () -> Bool,
                     progress: @escaping (String) -> Void) -> [JunkPhoto] {
        var images: [FileNode] = []
        func collect(_ n: FileNode) {
            if isCancelled() || n.isSymlink { return }
            if n.isDirectory { for c in n.children { collect(c) } }
            else if SimilarImages.imageExts.contains(n.fileExtension), n.size > 0 { images.append(n) }
        }
        collect(root)
        images.sort { $0.size > $1.size }
        if images.count > maxImages { images = Array(images.prefix(maxImages)) }
        guard !images.isEmpty else { return [] }

        var junk: [JunkPhoto] = []
        for (i, img) in images.enumerated() {
            if isCancelled() { return [] }
            if i % 20 == 0 { progress("Analyzing \(i + 1) of \(images.count) photos…") }

            if isScreenshot(img.url) {
                junk.append(JunkPhoto(node: img, reason: .screenshot, sharpness: 0))
            } else if let v = sharpness(img.url), v < blurThreshold {
                junk.append(JunkPhoto(node: img, reason: .blurry, sharpness: v))
            }
        }
        return junk.sorted { $0.node.size > $1.node.size }
    }

    // MARK: - Screenshots

    static func isScreenshot(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if name.hasPrefix("screenshot") || name.hasPrefix("screen shot")
            || name.hasPrefix("cleanshot") || name.contains("screen recording") { return true }
        // Spotlight's screen-capture flag (raw key — not exposed as a Swift constant).
        if let item = MDItemCreate(nil, url.path as CFString) {
            let v = MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString)
            if (v as? Bool) == true || (v as? NSNumber)?.boolValue == true { return true }
        }
        return false
    }

    // MARK: - Blur (focus measure)

    /// Variance of the Laplacian over a downscaled grayscale render. Returns nil if
    /// the image can't be decoded.
    static func sharpness(_ url: URL) -> Double? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 3, h >= 3 else { return nil }

        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return laplacianVariance(pixels: pixels, width: w, height: h)
    }

    /// Pure focus metric (extracted so it's unit-testable): the variance of a 4-neighbour
    /// Laplacian over an 8-bit grayscale buffer. High = sharp, near-zero = flat/blurry.
    static func laplacianVariance(pixels: [UInt8], width w: Int, height h: Int) -> Double {
        guard w >= 3, h >= 3, pixels.count >= w * h else { return 0 }
        var sum = 0.0, sumSq = 0.0
        var n = 0
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                let lap = 4.0 * Double(pixels[i])
                    - Double(pixels[i - 1]) - Double(pixels[i + 1])
                    - Double(pixels[i - w]) - Double(pixels[i + w])
                sum += lap
                sumSq += lap * lap
                n += 1
            }
        }
        guard n > 0 else { return 0 }
        let mean = sum / Double(n)
        return max(0, sumSq / Double(n) - mean * mean)
    }
}
