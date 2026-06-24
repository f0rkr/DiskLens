import Foundation

/// Checks GitHub Releases for a newer version. This is the only network request
/// DiskLens ever makes — it sends no file data, only a GET to the public API —
/// and it's opt-out in Preferences ("Check for updates on launch").
enum UpdateChecker {
    static let releasesPage = URL(string: "https://github.com/f0rkr/DiskLens/releases/latest")!
    private static let api = URL(string: "https://api.github.com/repos/f0rkr/DiskLens/releases/latest")!

    /// The bundled version (CFBundleShortVersionString), e.g. "1.3.0".
    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// The latest release version (e.g. "1.3.1") if it's newer than the current
    /// build, otherwise nil. Never throws — any failure just yields nil.
    static func latestIfNewer() async -> String? {
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 8
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { return nil }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return isNewer(latest, than: currentVersion) ? latest : nil
    }

    /// Dotted-numeric version compare: true when `a` is strictly newer than `b`.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
