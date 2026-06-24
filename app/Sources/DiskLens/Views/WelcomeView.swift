import SwiftUI

/// The landing screen shown before a scan. A single, non-scrolling page: a
/// brand hero over a soft aurora, the primary "choose a folder" call to action,
/// quick-scan shortcuts, and recent folders.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            aurora
            VStack(spacing: 24) {
                Spacer(minLength: 8)
                hero
                cta
                Spacer(minLength: 8)
                quick
                if !model.recentFolders.isEmpty { recents }
                Spacer(minLength: 8)
            }
            .frame(maxWidth: 600)
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 12)
        .onAppear {
            if reduceMotion { appear = true }
            else { withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appear = true } }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.scan(url)   // scan exactly what was dropped (folder, file, or archive)
            return true
        } isTargeted: { dropTargeted = $0 }
    }

    private var aurora: some View {
        ZStack {
            Circle().fill(Color.brand.opacity(0.20)).frame(width: 460).blur(radius: 130)
                .offset(x: -180, y: -200)
            Circle().fill(Color.brand2.opacity(0.18)).frame(width: 420).blur(radius: 130)
                .offset(x: 200, y: 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            BrandMark(size: 68)
            Text("DiskLens")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing))
            Text("See what's eating your disk, then reclaim it.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var cta: some View {
        VStack(spacing: 12) {
            Button { model.chooseFolder() } label: {
                Label("Choose a Folder to Scan", systemImage: "folder.badge.plus").padding(.horizontal, 8)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            dropZone
        }
    }

    private var dropZone: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
            Text("…or drop a folder anywhere in this window")
        }
        .font(.callout)
        .foregroundStyle(dropTargeted ? Color.brand : .secondary)
        .padding(.vertical, 12).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(dropTargeted ? Color.brand.opacity(0.12) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(dropTargeted ? Color.brand : Color.secondary.opacity(0.30),
                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
    }

    private var quick: some View {
        VStack(spacing: 10) {
            sectionLabel("Quick scan")
            HStack(spacing: 10) {
                ForEach(model.quickFolders, id: \.0) { item in
                    Button { model.scan(item.2) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.1).font(.title2).foregroundStyle(Color.brand)
                            Text(item.0).font(.caption).foregroundStyle(.primary)
                        }
                        .frame(width: 88, height: 72)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
        }
    }

    private var recents: some View {
        VStack(spacing: 8) {
            sectionLabel("Recent")
            VStack(spacing: 0) {
                ForEach(Array(model.recentFolders.prefix(4).enumerated()), id: \.element) { idx, url in
                    if idx > 0 { Divider() }
                    Button { model.scan(url) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(url.lastPathComponent)
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption2).foregroundStyle(.tertiary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowButtonStyle())
                }
            }
            .card(12)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
