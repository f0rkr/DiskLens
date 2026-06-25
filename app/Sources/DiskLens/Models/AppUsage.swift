import Foundation

/// How much disk one application is responsible for: its bundle plus the data
/// it leaves around the system (containers, caches, Application Support, logs…).
struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String?
    let bundleURL: URL?
    var bundleSize: Int64
    var locations: [Location]

    var dataSize: Int64 { locations.reduce(0) { $0 + $1.size } }
    var total: Int64 { bundleSize + dataSize }

    struct Location: Identifiable {
        let id = UUID()
        let label: String
        let url: URL
        let size: Int64
    }
}

enum AppUsageScanner {
    /// Measure every app in /Applications (+ ~/Applications) and its on-disk
    /// footprint. Heavy (walks several Library folders per app) so run off-main.
    static func scan(isCancelled: @escaping () -> Bool, progress: @escaping (String) -> Void) -> [AppUsage] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")

        var bundles: [URL] = []
        for dir in ["/Applications", home.appendingPathComponent("Applications").path] {
            let urls = (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: dir),
                                                    includingPropertiesForKeys: nil)) ?? []
            bundles.append(contentsOf: urls.filter { $0.pathExtension == "app" })
        }

        var result: [AppUsage] = []
        for (i, bundle) in bundles.enumerated() {
            if isCancelled() { break }
            let name = bundle.deletingPathExtension().lastPathComponent
            progress("Measuring \(name) (\(i + 1)/\(bundles.count))…")
            let bid = Bundle(url: bundle)?.bundleIdentifier

            var locs: [AppUsage.Location] = []
            func add(_ label: String, _ url: URL) {
                guard fm.fileExists(atPath: url.path) else { return }
                let s = dirSize(url)
                if s > 0 { locs.append(.init(label: label, url: url, size: s)) }
            }
            if let bid {
                add("Container", lib.appendingPathComponent("Containers/\(bid)"))
                add("Caches", lib.appendingPathComponent("Caches/\(bid)"))
                add("HTTP storage", lib.appendingPathComponent("HTTPStorages/\(bid)"))
                add("WebKit data", lib.appendingPathComponent("WebKit/\(bid)"))
                add("Saved state", lib.appendingPathComponent("Saved Application State/\(bid).savedState"))
            }
            add("Application Support", lib.appendingPathComponent("Application Support/\(name)"))
            add("Logs", lib.appendingPathComponent("Logs/\(name)"))

            result.append(AppUsage(name: name, bundleID: bid, bundleURL: bundle,
                                   bundleSize: dirSize(bundle), locations: locs))
        }
        return result.sorted { $0.total > $1.total }
    }

    /// Allocated on-disk size of a file or directory tree.
    static func dirSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: keys)
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        if let en = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: nil) {
            for case let f as URL in en {
                let v = try? f.resourceValues(forKeys: keys)
                if v?.isRegularFile == true {
                    total += Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }
}
