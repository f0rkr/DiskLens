import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let v = model.availableUpdate { UpdateBanner(version: v) }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await model.maybeCheckForUpdate() }
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning && model.rootNode == nil {
            ScanProgressView()
        } else if let root = model.rootNode {
            VStack(spacing: 0) {
                TopBar()
                if model.unreadableCount > 0 {
                    FullDiskAccessBanner(count: model.unreadableCount)
                }
                sectionContent(root: root)
                    .id(root.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            WelcomeView()
        }
    }

    @ViewBuilder
    private func sectionContent(root: FileNode) -> some View {
        switch model.selection {
        case .overview:   OverviewView(insights: model.insights, delta: model.lastDelta,
                                        history: model.lastHistory, diskStats: model.diskStats)
        case .breakdown:  BreakdownView(root: root)
        case .treemap:    TreemapView(root: root)
        case .files:      FilesView()
        case .duplicates: DuplicatesView()
        case .cleanup:    CleanupView()
        case .bin:        BinView()
        }
    }
}

/// Glassy top navbar — folder context (left), section tabs (center), actions (right).
/// Only ever shown once a scan exists, so the tabs are never empty.
struct TopBar: View {
    @Environment(AppModel.self) private var model
    @State private var hoveredTab: AppModel.Section?

    var body: some View {
        HStack(spacing: 14) {
            Button { model.reset() } label: {
                Image(systemName: "chevron.backward").font(.body.weight(.semibold))
            }
            .buttonStyle(HoverIconStyle())
            .help("Choose another folder")

            BrandMark(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.scannedRoot?.lastPathComponent ?? "DiskLens")
                    .font(.headline).lineLimit(1).truncationMode(.middle)
                if let root = model.rootNode {
                    Text("\(ByteFormat.string(root.size)) · \(root.fileCount) files")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: 240, alignment: .leading)

            Spacer(minLength: 12)
            tabs.layoutPriority(1)
            Spacer(minLength: 12)

            Button { model.exportReport() } label: {
                Image(systemName: "square.and.arrow.up").font(.body.weight(.semibold))
            }
            .buttonStyle(HoverIconStyle())
            .help("Export a report of this scan")

            Button { if let u = model.scannedRoot { model.scan(u) } } label: {
                Image(systemName: "arrow.clockwise").font(.body.weight(.semibold))
            }
            .buttonStyle(HoverIconStyle())
            .help("Rescan this folder")
            .disabled(model.isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    // Show full icon+title tabs when they fit on one line; on a narrower window,
    // fall back to icon-only tabs (titles become tooltips) so labels never wrap.
    private var tabs: some View {
        ViewThatFits(in: .horizontal) {
            tabRow(compact: false)
            tabRow(compact: true)
        }
    }

    private func tabRow(compact: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(AppModel.Section.allCases) { sec in
                tabButton(sec, compact: compact)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
    }

    private func tabButton(_ sec: AppModel.Section, compact: Bool) -> some View {
        let on = model.selection == sec
        let hot = hoveredTab == sec
        return Button { withAnimation(.easeOut(duration: 0.15)) { model.selection = sec } } label: {
            tabLabel(sec, compact: compact)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .font(.callout.weight(on ? .semibold : .regular))
                .padding(.horizontal, compact ? 9 : 12).padding(.vertical, 6)
                .foregroundStyle(on ? Color.white : (hot ? Color.primary : Color.secondary))
                .background(on ? Color.brand : (hot ? Color.primary.opacity(0.10) : Color.clear), in: Capsule())
                .overlay(alignment: .topTrailing) { binBadge(sec) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(sec.rawValue)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveredTab = h ? sec : (hoveredTab == sec ? nil : hoveredTab) } }
    }

    @ViewBuilder
    private func tabLabel(_ sec: AppModel.Section, compact: Bool) -> some View {
        if compact {
            Label(sec.rawValue, systemImage: sec.icon).labelStyle(.iconOnly)
        } else {
            Label(sec.rawValue, systemImage: sec.icon).labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private func binBadge(_ sec: AppModel.Section) -> some View {
        if sec == .bin, model.binItems.count > 0 {
            Text("\(model.binItems.count)")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.red, in: Capsule())
                .offset(x: 2, y: -3)
                .transition(.scale)
        }
    }
}

/// Full-window animated progress shown during a scan.
struct ScanProgressView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 4)
                    .frame(width: 104, height: 104)
                Circle().trim(from: 0, to: 0.28)
                    .stroke(Color.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 104, height: 104)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                miniTreemap
                    .frame(width: 46, height: 46)
                    .scaleEffect(pulse ? 1.06 : 0.92)
                    .opacity(pulse ? 1 : 0.75)
            }
            Text("Scanning…").font(.title2.weight(.semibold))
            Text("\(model.filesScanned) items")
                .font(.body.monospacedDigit()).foregroundStyle(.secondary)
                .contentTransition(.numericText()).animation(.default, value: model.filesScanned)
            Text(model.currentPath)
                .font(.caption.monospaced()).foregroundStyle(.tertiary)
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: 440)
            Button("Cancel") { model.cancelScan() }.controlSize(.small).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var miniTreemap: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                tile(FileColor.color(forKind: .folder),   0,        0,        w * 0.54, h * 0.60)
                tile(FileColor.color(forKind: .code),      w * 0.58, 0,        w * 0.42, h * 0.44)
                tile(FileColor.color(forKind: .media),     w * 0.58, h * 0.48, w * 0.42, h * 0.52)
                tile(FileColor.color(forKind: .document),  0,        h * 0.64, w * 0.54, h * 0.36)
            }
        }
    }
    private func tile(_ c: Color, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(c).frame(width: w, height: h).offset(x: x, y: y)
    }
}

/// Shown after a scan when some folders couldn't be read — points the user to
/// grant Full Disk Access so the next scan can see everything.
struct FullDiskAccessBanner: View {
    @Environment(AppModel.self) private var model
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill").foregroundStyle(.orange)
            Text("\(count) folder\(count == 1 ? "" : "s") couldn't be read. Grant Full Disk Access to include everything.")
                .font(.callout)
            Spacer()
            Button("Grant Access…") { openFullDiskAccess() }.controlSize(.small)
            Button("Rescan") { if let u = model.scannedRoot { model.scan(u) } }
                .controlSize(.small).disabled(model.isScanning)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.orange.opacity(0.10))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Slim banner shown when the launch update check finds a newer release.
/// "Install" downloads the new build and relaunches into it.
struct UpdateBanner: View {
    @Environment(AppModel.self) private var model
    let version: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.brand)
            if model.isUpdating {
                ProgressView().controlSize(.small)
                Text("Downloading DiskLens \(version)… the app will relaunch.")
                    .font(.callout.weight(.medium))
            } else if let err = model.updateError {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(err).font(.callout).lineLimit(2)
            } else {
                Text("DiskLens \(version) is available.").font(.callout.weight(.medium))
            }
            Spacer(minLength: 12)
            if !model.isUpdating {
                Button("Install") { Task { await model.installUpdate() } }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("View") { NSWorkspace.shared.open(UpdateChecker.releasesPage) }
                    .controlSize(.small)
                Button { model.availableUpdate = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Dismiss")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.brand.opacity(0.10))
        .overlay(alignment: .bottom) { Divider() }
    }
}
