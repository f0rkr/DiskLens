import SwiftUI
import AppKit
import Combine

struct DiskStats {
    var total: Int64 = 0
    var free: Int64 = 0
    var used: Int64 { max(0, total - free) }

    static func current(for url: URL = URL(fileURLWithPath: NSHomeDirectory())) -> DiskStats {
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
    @State private var sampler = SystemStats.Sampler()
    @State private var sys = SystemStats()
    @State private var cpuHistory: [Double] = []
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    private let historyCap = 44

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

            VStack(spacing: 9) {
                gauge("CPU", "cpu", "\(Int((sys.cpuBusy * 100).rounded()))%", sys.cpuBusy)
                if cpuHistory.count > 1 { Sparkline(values: cpuHistory, tint: sparkTint).frame(height: 26) }
                gauge("Memory", "memorychip",
                      "\(ByteFormat.string(sys.memUsed)) of \(ByteFormat.string(sys.memTotal))", sys.memFrac)
            }

            Divider()

            menuButton("Open DiskLens", "macwindow") { activate() }
            menuButton("Scan Home Folder", "house") {
                model.scan(FileManager.default.homeDirectoryForCurrentUser); activate()
            }
            menuButton(DiskGaugeController.shared.isVisible ? "Hide Desktop Gauge" : "Show Desktop Gauge",
                       "speedometer") { DiskGaugeController.shared.toggle() }
            menuButton("Refresh", "arrow.clockwise") { stats = DiskStats.current(); tick() }
        }
        .padding(16)
        .frame(width: 264)
        .onAppear { stats = DiskStats.current(); tick() }
        .onReceive(timer) { _ in tick() }
    }

    private func tick() {
        sys = sampler.sample()
        cpuHistory.append(sys.cpuBusy)
        if cpuHistory.count > historyCap { cpuHistory.removeFirst(cpuHistory.count - historyCap) }
    }

    private var sparkTint: Color {
        let peak = cpuHistory.max() ?? 0
        return peak > 0.9 ? .red : (peak > 0.7 ? .orange : .brand)
    }

    private func gauge(_ label: String, _ icon: String, _ value: String, _ frac: Double) -> some View {
        let c: Color = frac > 0.9 ? .red : (frac > 0.7 ? .orange : .brand)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(.secondary).font(.caption)
                Text(label).font(.caption.weight(.medium))
                Spacer()
                Text(value).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(c.gradient).frame(width: max(3, g.size.width * CGFloat(min(1, max(0, frac)))))
                }
            }
            .frame(height: 7)
        }
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

/// Rolling history (0…1 values) drawn as a filled line sparkline.
private struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let n = values.count
            let pts: [CGPoint] = n > 1
                ? values.enumerated().map { i, v in
                    CGPoint(x: w * CGFloat(i) / CGFloat(n - 1),
                            y: h * (1 - CGFloat(min(1, max(0, v)))))
                  }
                : []
            ZStack {
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
    }
}
