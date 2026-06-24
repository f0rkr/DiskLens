import Foundation

/// A point-in-time record of a scan: each top-level item's size plus the total,
/// so a later scan of the same folder can show what grew or shrank.
struct ScanSnapshot: Codable, Equatable {
    var date: Date
    var totalBytes: Int64
    var entries: [String: Int64]   // top-level item name -> allocated size
}

/// The change between two snapshots of the same folder.
struct ScanDelta {
    let since: Date
    let totalChange: Int64
    /// Per-item changes, largest magnitude first; unchanged items omitted.
    let changes: [(name: String, delta: Int64)]

    var biggestGrower: (name: String, delta: Int64)? { changes.first { $0.delta > 0 } }
    var hasChanges: Bool { totalChange != 0 || !changes.isEmpty }
}

/// Persists a short history of scans (keyed by folder path) and diffs them.
enum ScanHistory {
    private static let key = "scanHistoryV1"
    private static let maxPerRoot = 12

    /// Build a snapshot from a freshly scanned tree.
    static func snapshot(of root: FileNode, date: Date) -> ScanSnapshot {
        var entries: [String: Int64] = [:]
        for c in root.children { entries[c.name] = c.size }
        return ScanSnapshot(date: date, totalBytes: root.size, entries: entries)
    }

    /// Pure diff of two snapshots (no I/O).
    static func delta(from old: ScanSnapshot, to new: ScanSnapshot) -> ScanDelta {
        var names = Set(old.entries.keys)
        names.formUnion(new.entries.keys)
        var changes: [(name: String, delta: Int64)] = []
        for n in names {
            let d = (new.entries[n] ?? 0) - (old.entries[n] ?? 0)
            if d != 0 { changes.append((name: n, delta: d)) }
        }
        changes.sort { abs($0.delta) > abs($1.delta) }
        return ScanDelta(since: old.date,
                         totalChange: new.totalBytes - old.totalBytes,
                         changes: changes)
    }

    // MARK: - persistence (UserDefaults, keyed by folder path)

    private static func loadAll() -> [String: [ScanSnapshot]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let all = try? JSONDecoder().decode([String: [ScanSnapshot]].self, from: data)
        else { return [:] }
        return all
    }

    private static func saveAll(_ all: [String: [ScanSnapshot]]) {
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Record a scan of `path`; returns the delta vs the most recent prior
    /// snapshot of the same folder, or `nil` if this is the first scan of it.
    @discardableResult
    static func record(_ root: FileNode, path: String, date: Date = Date()) -> ScanDelta? {
        var all = loadAll()
        let previous = all[path]?.last
        let snap = snapshot(of: root, date: date)
        var list = all[path] ?? []
        list.append(snap)
        if list.count > maxPerRoot { list.removeFirst(list.count - maxPerRoot) }
        all[path] = list
        saveAll(all)
        guard let previous else { return nil }
        return delta(from: previous, to: snap)
    }
}
