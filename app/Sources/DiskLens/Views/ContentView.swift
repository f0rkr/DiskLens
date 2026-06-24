import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isScanning && model.rootNode == nil {
                ScanProgressView()
            } else if let root = model.rootNode {
                VStack(spacing: 0) {
                    TopBar()
                    sectionContent(root: root)
                        .id(root.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sectionContent(root: FileNode) -> some View {
        switch model.selection {
        case .overview:   OverviewView(insights: model.insights)
        case .breakdown:  BreakdownView(root: root)
        case .treemap:    TreemapView(root: root)
        case .files:      FilesView()
        case .duplicates: DuplicatesView()
        case .cleanup:    CleanupView()
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
                Text(model.scannedRoot?.lastPathComponent ?? "DiskLens").font(.headline).lineLimit(1)
                if let root = model.rootNode {
                    Text("\(ByteFormat.string(root.size)) · \(root.fileCount) files")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)
            tabs
            Spacer(minLength: 12)

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

    private var tabs: some View {
        HStack(spacing: 3) {
            ForEach(AppModel.Section.allCases) { sec in
                let on = model.selection == sec
                let hot = hoveredTab == sec
                Button { withAnimation(.easeOut(duration: 0.15)) { model.selection = sec } } label: {
                    Label(sec.rawValue, systemImage: sec.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.callout.weight(on ? .semibold : .regular))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(on ? Color.white : (hot ? Color.primary : Color.secondary))
                        .background(on ? Color.brand : (hot ? Color.primary.opacity(0.10) : Color.clear), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hoveredTab = h ? sec : (hoveredTab == sec ? nil : hoveredTab) } }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
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
