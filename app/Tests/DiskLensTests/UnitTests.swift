import Testing
import CoreGraphics
import Foundation
@testable import DiskLens

// MARK: - in-memory fixtures

func mkFile(_ name: String, _ size: Int64, modified: Date? = nil) -> FileNode {
    let n = FileNode(url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: false, size: size)
    n.fileCount = 1
    n.modifiedAt = modified
    return n
}

func mkDir(_ name: String, _ children: [FileNode]) -> FileNode {
    let n = FileNode(url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: true)
    n.children = children.sorted { $0.size > $1.size }
    n.size = children.reduce(0) { $0 + $1.size }
    n.fileCount = children.reduce(0) { $0 + $1.fileCount }
    return n
}

// MARK: - Squarify (treemap layout)

@Suite struct SquarifyTests {
    @Test func tilesCoverBoundsProportionally() {
        let nodes = [mkFile("a", 100), mkFile("b", 50), mkFile("c", 25), mkFile("d", 25)]
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let tiles = Squarify.layout(nodes, in: bounds)

        #expect(tiles.count == 4)
        let area = tiles.reduce(0.0) { $0 + Double($1.rect.width) * Double($1.rect.height) }
        #expect(abs(area - 120_000) <= 120_000 * 0.02)   // ~full coverage
        for t in tiles {
            #expect(Double(t.rect.minX) >= -0.5)
            #expect(Double(t.rect.minY) >= -0.5)
            #expect(Double(t.rect.maxX) <= 400.5)
            #expect(Double(t.rect.maxY) <= 300.5)
        }
    }

    @Test func emptyAndZeroSize() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(Squarify.layout([], in: bounds).isEmpty)
        #expect(Squarify.layout([mkFile("z", 0)], in: bounds).isEmpty)
    }
}

// MARK: - FileColor categorization

@Suite struct FileColorTests {
    @Test func kinds() {
        #expect(FileColor.kind(for: mkFile("a.swift", 1)) == .code)
        #expect(FileColor.kind(for: mkFile("photo.PNG", 1)) == .media)   // case-insensitive
        #expect(FileColor.kind(for: mkFile("a.zip", 1)) == .archive)
        #expect(FileColor.kind(for: mkFile("a.pdf", 1)) == .document)
        #expect(FileColor.kind(for: mkFile("a.xyz", 1)) == .other)
        #expect(FileColor.kind(for: mkDir("d", [])) == .folder)
    }
}

// MARK: - Cleanup rules

@Suite struct CleanupRulesTests {
    @Test func flagsExpectedItems() {
        let root = mkDir("proj", [
            mkDir("node_modules", [mkFile("index.js", 5_000_000)]),
            mkFile(".DS_Store", 4096),
            mkFile("big.zip", 200 * 1024 * 1024),
            mkFile("notes.md", 1000),
        ])
        let s = CleanupRules.analyze(root)
        #expect(s.contains { $0.category == .buildArtifacts && $0.url.lastPathComponent == "node_modules" })
        #expect(s.contains { $0.category == .junk && $0.url.lastPathComponent == ".DS_Store" })
        #expect(s.contains { $0.category == .largeArchives && $0.url.lastPathComponent == "big.zip" })
        #expect(!s.contains { $0.url.lastPathComponent == "notes.md" })
    }
}

// MARK: - Insights aggregation

@Suite struct ScanInsightsTests {
    @Test func aggregation() {
        let root = mkDir("root", [
            mkFile("a.png", 3_000_000),
            mkFile("b.png", 2_000_000),
            mkFile("c.swift", 1_000_000),
        ])
        let ins = ScanInsights.compute(from: root)
        #expect(ins.totalFiles == 3)
        #expect(ins.categories.first?.kind == .media)        // 5 MB media > 1 MB code
        #expect(ins.topFiles.first?.name == "a.png")
        #expect(ins.topFiles.count == 3)
    }
}

// MARK: - Byte formatting

@Suite struct ByteFormatTests {
    @Test func decimalUnits() {
        UserDefaults.standard.set(false, forKey: "useBinaryUnits")
        #expect(ByteFormat.string(1_500_000).contains("MB"))
        #expect(ByteFormat.string(2_000_000_000).contains("GB"))
    }
}

// MARK: - Scan exclusions (whole-disk performance)

@Suite struct ScanEngineSkipTests {
    @Test func excludesSystemLocationsButNotUserData() {
        #expect(ScanEngine.isExcludedSystemPath("/System"))
        #expect(ScanEngine.isExcludedSystemPath("/Volumes"))
        #expect(ScanEngine.isExcludedSystemPath("/dev"))
        #expect(ScanEngine.isExcludedSystemPath("/private/var/vm"))
        #expect(!ScanEngine.isExcludedSystemPath("/"))
        #expect(!ScanEngine.isExcludedSystemPath("/Applications"))
        #expect(!ScanEngine.isExcludedSystemPath("/Users/me/Documents"))
    }

    @Test func classifiesPermissionErrors() {
        #expect(ScanEngine.isPermissionDenied(NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)))
        #expect(ScanEngine.isPermissionDenied(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        #expect(!ScanEngine.isPermissionDenied(NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)))
    }
}

// MARK: - Scan history ("what grew")

@Suite struct ScanHistoryTests {
    @Test func snapshotCapturesTopLevelAndTotal() {
        let root = mkDir("root", [mkFile("a", 100), mkDir("sub", [mkFile("x", 30)])])
        let s = ScanHistory.snapshot(of: root, date: Date(timeIntervalSince1970: 0))
        #expect(s.totalBytes == 130)
        #expect(s.entries["a"] == 100)
        #expect(s.entries["sub"] == 30)
        #expect(s.entries.count == 2)
    }

    @Test func deltaRanksChangesAndTotals() {
        let old = ScanSnapshot(date: Date(timeIntervalSince1970: 0), totalBytes: 100,
                               entries: ["A": 50, "B": 50])
        let new = ScanSnapshot(date: Date(timeIntervalSince1970: 1000), totalBytes: 140,
                               entries: ["A": 90, "B": 40, "C": 10])   // A +40, B -10, C +10
        let d = ScanHistory.delta(from: old, to: new)
        #expect(d.totalChange == 40)
        #expect(d.changes.count == 3)
        #expect(d.changes.first?.name == "A")        // largest magnitude first
        #expect(d.changes.first?.delta == 40)
        #expect(d.biggestGrower?.name == "A")
    }
}

// MARK: - In-app Bin (staged deletions)

@Suite(.serialized) @MainActor struct BinTests {
    @Test func addRemoveToggleAndTotal() {
        let m = AppModel()
        m.clearBin()
        let a = mkFile("a.bin", 1_000)
        let b = mkFile("b.bin", 2_500)

        m.addToBin(a)
        m.addToBin(b)
        m.addToBin(a)                       // duplicate add is a no-op
        #expect(m.binItems.count == 2)
        #expect(m.binTotalBytes == 3_500)
        #expect(m.isInBin(a.url))

        m.toggleBin(a)                       // removes a
        #expect(!m.isInBin(a.url))
        #expect(m.binItems.count == 1)
        #expect(m.binTotalBytes == 2_500)

        m.toggleBin(a)                       // re-adds a
        #expect(m.binItems.count == 2)

        m.removeFromBin(b.url)
        #expect(m.binItems.count == 1)
        #expect(m.binTotalBytes == 1_000)

        m.clearBin()
        #expect(m.binItems.isEmpty)
        #expect(m.binTotalBytes == 0)
    }

    @Test func binPersistsAcrossRelaunchAndPrunesVanished() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bin-persist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("staged.bin")
        try Data(count: 4096).write(to: f)

        let m1 = AppModel()
        m1.clearBin()
        m1.addToBin(url: f, size: 4096, name: "staged.bin", isDirectory: false)
        #expect(m1.isInBin(f))

        let m2 = AppModel()                          // fresh launch reloads the saved bin
        #expect(m2.isInBin(f))
        #expect(m2.binItems.contains { $0.url == f })

        // A file that vanished on disk should not survive the next reload.
        try FileManager.default.removeItem(at: f)
        let m3 = AppModel()
        #expect(!m3.isInBin(f))
        m3.clearBin()
    }
}
