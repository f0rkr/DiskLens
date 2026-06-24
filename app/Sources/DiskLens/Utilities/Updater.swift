import Foundation
import AppKit

/// Self-updater: downloads the latest release `.dmg`, then hands off to a small
/// shell helper that waits for this app to quit, swaps the bundle in place, and
/// relaunches. No third-party dependency. Best-effort for an unsigned app — the
/// helper strips the quarantine flag so the new build launches without a prompt.
enum Updater {
    static let dmgURL = URL(string: "https://github.com/f0rkr/DiskLens/releases/latest/download/DiskLens.dmg")!

    enum UpdaterError: LocalizedError {
        case appNotFoundInImage
        case notWritable
        var errorDescription: String? {
            switch self {
            case .appNotFoundInImage: return "Couldn't find DiskLens.app in the downloaded image."
            case .notWritable: return "Can't update in place here. Move DiskLens to Applications, then try again."
            }
        }
    }

    /// Download + install the latest build. On success the app terminates and a
    /// helper relaunches the new version; on failure it throws.
    static func installLatest() async throws {
        let target = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            throw UpdaterError.notWritable
        }

        // 1. download the .dmg
        let (downloaded, _) = try await URLSession.shared.download(from: dmgURL)
        let dmg = FileManager.default.temporaryDirectory.appendingPathComponent("DiskLens-update-\(UUID().uuidString).dmg")
        try? FileManager.default.removeItem(at: dmg)
        try FileManager.default.moveItem(at: downloaded, to: dmg)

        // 2. mount it
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("DiskLensUpdate-\(UUID().uuidString)")
        _ = try shell("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-noverify", "-mountpoint", mount.path])

        // 3. find the new app
        let newApp = mount.appendingPathComponent("DiskLens.app")
        guard FileManager.default.fileExists(atPath: newApp.path) else {
            _ = try? shell("/usr/bin/hdiutil", ["detach", mount.path, "-quiet"])
            throw UpdaterError.appNotFoundInImage
        }

        // 4. hand off to a helper that swaps + relaunches once we exit.
        let pid = ProcessInfo.processInfo.processIdentifier
        func q(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "\\\"") }
        let script = """
        #!/bin/sh
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.3; done
        /bin/sleep 0.4
        if /usr/bin/ditto "\(q(newApp.path))" "\(q(target.path)).new"; then
          /bin/rm -rf "\(q(target.path))"
          /bin/mv "\(q(target.path)).new" "\(q(target.path))"
          /usr/bin/xattr -dr com.apple.quarantine "\(q(target.path))" 2>/dev/null
        fi
        /usr/bin/hdiutil detach "\(q(mount.path))" -quiet 2>/dev/null
        /bin/rm -f "\(q(dmg.path))"
        /usr/bin/open "\(q(target.path))"
        """
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("dl-update-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [scriptURL.path]
        try p.run()

        await MainActor.run { NSApp.terminate(nil) }
    }

    @discardableResult
    private static func shell(_ launchPath: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
