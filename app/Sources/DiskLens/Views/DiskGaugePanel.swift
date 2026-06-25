import SwiftUI
import AppKit

/// A small always-on-top desktop gauge showing free space at a glance — DiskLens's
/// take on a disk widget. Built as a floating `NSPanel` (no extension, no signing,
/// no entitlements) so it ships in the same unsigned app bundle as everything else.
@MainActor
final class DiskGaugeController: NSObject, NSWindowDelegate {
    static let shared = DiskGaugeController()

    private var panel: NSPanel?
    private let frameKey = "diskGaugeFrame"
    private let visibleKey = "diskGaugeVisible"

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Re-open the gauge on launch if it was showing when the app last quit.
    func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: visibleKey) { show() }
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        if panel == nil { panel = makePanel() }
        panel?.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: visibleKey)
    }

    func hide() {
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: visibleKey)
    }

    private func makePanel() -> NSPanel {
        let host = NSHostingView(rootView: DiskGaugeWidget())
        host.frame = CGRect(origin: .zero, size: host.fittingSize)

        let p = NSPanel(contentRect: host.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.contentView = host
        p.setContentSize(host.fittingSize)
        p.delegate = self

        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            p.setFrame(NSRectFromString(saved), display: false)
        } else if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            let size = host.fittingSize
            p.setFrameOrigin(CGPoint(x: vf.maxX - size.width - 24, y: vf.maxY - size.height - 24))
        }
        return p
    }

    func windowDidMove(_ notification: Notification) { saveFrame() }
    func windowDidEndLiveResize(_ notification: Notification) { saveFrame() }

    private func saveFrame() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }
}

/// The glanceable gauge: a usage ring with free space front-and-centre, refreshing live.
struct DiskGaugeWidget: View {
    @State private var stats = DiskStats.current()
    @State private var hover = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var usedFrac: Double { stats.total > 0 ? Double(stats.used) / Double(stats.total) : 0 }
    private var color: Color { usedFrac > 0.9 ? .red : (usedFrac > 0.75 ? .orange : .brand) }

    private var volumeName: String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        return (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? "Macintosh HD"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill").foregroundStyle(color).font(.caption)
                Text(volumeName).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 4)
                if hover {
                    Button { DiskGaugeController.shared.hide() } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Hide the gauge")
                }
            }

            ZStack {
                Circle().stroke(.quaternary, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: usedFrac)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: usedFrac)
                VStack(spacing: 1) {
                    Text(ByteFormat.string(stats.free))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text("free").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 116, height: 116)
            .padding(.vertical, 2)

            Text("\(ByteFormat.string(stats.used)) of \(ByteFormat.string(stats.total))")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 184)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .tint(.brand)
        .onHover { hover = $0 }
        .onReceive(timer) { _ in withAnimation(.snappy) { stats = DiskStats.current() } }
        .contextMenu {
            Button("Open DiskLens") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            }
            Button("Refresh") { stats = DiskStats.current() }
            Divider()
            Button("Hide Gauge") { DiskGaugeController.shared.hide() }
        }
    }
}
