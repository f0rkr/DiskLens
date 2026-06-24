import SwiftUI
import AppKit

struct DiskStats {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 { max(0, total - free) }

    static func current() -> DiskStats {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        var s = DiskStats()
        s.total = Int64(v?.volumeTotalCapacity ?? 0)
        s.free = v?.volumeAvailableCapacityForImportantUsage ?? 0
        return s
    }
}

/// Menu-bar quick overview of the whole disk + quick actions.
struct MenuBarView: View {
    let model: AppModel
    @State private var stats = DiskStats.current()

    private var usedFrac: CGFloat { stats.total > 0 ? CGFloat(stats.used) / CGFloat(stats.total) : 0 }
    private var usageColor: Color { usedFrac > 0.9 ? .red : (usedFrac > 0.75 ? .orange : .brand) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                BrandMark(size: 26)
                Text("DiskLens").font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ByteFormat.string(stats.free)).font(.title2.weight(.bold)).foregroundStyle(.green)
                    Text("free").foregroundStyle(.secondary)
                    Spacer()
                    Text("of \(ByteFormat.string(stats.total))").font(.caption).foregroundStyle(.secondary)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(usageColor.gradient).frame(width: max(4, g.size.width * usedFrac))
                    }
                }
                .frame(height: 10)
                Text("\(ByteFormat.string(stats.used)) used · \(Int((usedFrac * 100).rounded()))%")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            menuButton("Open DiskLens", "macwindow") { activate() }
            menuButton("Scan Home Folder", "house") {
                model.scan(FileManager.default.homeDirectoryForCurrentUser); activate()
            }
            menuButton("Refresh", "arrow.clockwise") { stats = DiskStats.current() }
        }
        .padding(16)
        .frame(width: 264)
        .onAppear { stats = DiskStats.current() }
    }

    private func menuButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6).padding(.horizontal, 8)
        }
        .buttonStyle(RowButtonStyle())
    }

    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }
}
