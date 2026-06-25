import Foundation

/// Creates a .zip of a file/folder using `ditto` (the macOS-native zipper that
/// preserves resource forks and metadata). No third-party dependency.
enum Archiver {
    /// Zip `source` into `dest` (replacing any existing file there). Returns
    /// whether a non-empty archive was produced.
    static func zip(source: URL, to dest: URL) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, dest.path]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do { try p.run(); p.waitUntilExit() } catch { return false }
        guard p.terminationStatus == 0 else { return false }
        let size = (try? dest.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return FileManager.default.fileExists(atPath: dest.path) && size > 0
    }
}
