import Testing
import Foundation
@testable import DiskLens

/// End-to-end: lay down a real folder on disk, scan it, and run the whole
/// analysis pipeline (sizes, duplicates, insights) against the result.
/// A fresh instance (and fresh temp dir) is created for every `@Test`.
@Suite final class ScanIntegrationTests {
    let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("disklens-it-\(UUID().uuidString)")
        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        try Data(count: 1_048_576).write(to: dir.appendingPathComponent("big.bin"))   // 1 MB
        let payload = Data(repeating: 65, count: 40_000)
        try payload.write(to: dir.appendingPathComponent("a.txt"))                      // duplicate…
        try payload.write(to: sub.appendingPathComponent("b.txt"))                      // …of a.txt
        try Data(repeating: 66, count: 10_000).write(to: dir.appendingPathComponent("unique.txt"))
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func scanTreeIsAccurate() throws {
        let root = try #require(ScanEngine.buildTree(at: dir, isCancelled: { false }, progress: { _, _ in }))
        #expect(root.isDirectory)
        #expect(root.fileCount == 4)
        #expect(root.size >= 1_048_576)
        // children sorted largest-first
        let sizes = root.children.map(\.size)
        #expect(sizes == sizes.sorted(by: >))
    }

    @Test func duplicateFinderDetectsIdenticalFiles() throws {
        let root = try #require(ScanEngine.buildTree(at: dir, isCancelled: { false }, progress: { _, _ in }))
        let groups = DuplicateFinder.find(in: root, isCancelled: { false }, progress: { _ in })
        #expect(groups.count == 1)
        #expect(groups.first?.files.count == 2)
        #expect((groups.first?.reclaimable ?? 0) > 0)
    }

    @Test func insightsFromRealScan() throws {
        let root = try #require(ScanEngine.buildTree(at: dir, isCancelled: { false }, progress: { _, _ in }))
        let ins = ScanInsights.compute(from: root)
        #expect(ins.totalFiles == 4)
        #expect(ins.topFiles.first?.name == "big.bin")
        #expect(ins.totalBytes == root.size)
    }

    @Test func scanIsCancellable() {
        let root = ScanEngine.buildTree(at: dir, isCancelled: { true }, progress: { _, _ in })
        // Cancelled up-front — nothing gathered.
        #expect(root?.children.isEmpty ?? true)
    }
}
