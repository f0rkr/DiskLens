import Foundation

/// Opens a macOS Quick Look preview for a file. Uses `qlmanage -p`, which shows
/// the standard Quick Look panel without needing AppKit responder-chain plumbing.
enum QuickLook {
    static func show(_ url: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        p.arguments = ["-p", url.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
