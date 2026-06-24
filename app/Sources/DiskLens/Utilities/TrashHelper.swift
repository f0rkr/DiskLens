import Foundation

enum TrashHelper {
    struct Result {
        var trashedBytes: Int64 = 0
        var trashedCount: Int = 0
        var failures: [(URL, String)] = []
        /// (original location, location inside the Trash) — used to undo.
        var restorePairs: [(original: URL, trashed: URL)] = []
    }

    /// Moves the given items to the Trash (recoverable). Returns a summary.
    @discardableResult
    static func moveToTrash(_ items: [(url: URL, size: Int64)]) -> Result {
        var result = Result()
        for item in items {
            do {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resulting)
                result.trashedBytes += item.size
                result.trashedCount += 1
                if let trashed = resulting as URL? {
                    result.restorePairs.append((item.url, trashed))
                }
            } catch {
                result.failures.append((item.url, error.localizedDescription))
            }
        }
        return result
    }

    /// Moves items back from the Trash to their original locations. Returns count restored.
    @discardableResult
    static func restore(_ pairs: [(original: URL, trashed: URL)]) -> Int {
        var restored = 0
        for p in pairs {
            do {
                try FileManager.default.moveItem(at: p.trashed, to: p.original)
                restored += 1
            } catch {
                // best effort
            }
        }
        return restored
    }
}
