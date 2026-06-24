import Foundation

enum ByteFormat {
    private static let decimal: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f
    }()
    private static let binary: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f
    }()

    static func string(_ bytes: Int64) -> String {
        let useBinary = UserDefaults.standard.bool(forKey: "useBinaryUnits")
        return (useBinary ? binary : decimal).string(fromByteCount: bytes)
    }
}
