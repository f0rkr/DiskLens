import Foundation

/// "Hidden" reclaimable space that a folder scan can't see: Time Machine local
/// snapshots and the OS's purgeable space.
struct HiddenSpace {
    var snapshots: [String] = []     // Time Machine local snapshot identifiers
    var purgeable: Int64 = 0         // space macOS can reclaim on its own (caches, snapshots)

    var snapshotCount: Int { snapshots.count }
}

enum HiddenSpaceScanner {
    /// Read current state (runs `tmutil` + reads volume capacity). Safe / read-only.
    static func scan(volume: URL) -> HiddenSpace {
        var h = HiddenSpace()
        h.snapshots = parseSnapshots(run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]))
        if let v = try? volume.resourceValues(forKeys: [.volumeAvailableCapacityKey,
                                                        .volumeAvailableCapacityForImportantUsageKey]) {
            let avail = Int64(v.volumeAvailableCapacity ?? 0)
            let important = v.volumeAvailableCapacityForImportantUsage ?? 0
            h.purgeable = max(0, important - avail)
        }
        return h
    }

    /// Ask macOS to thin (delete) local Time Machine snapshots, freeing their
    /// space. The on-disk Time Machine backups are untouched. Returns tmutil's
    /// output (or an error description).
    static func reclaimSnapshots() -> String {
        run("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999", "4"])
    }

    /// Pure parser for `tmutil listlocalsnapshots` output (unit-testable).
    static func parseSnapshots(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("com.apple.TimeMachine") }
    }

    private static func run(_ launchPath: String, _ args: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: launchPath) else { return "" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
