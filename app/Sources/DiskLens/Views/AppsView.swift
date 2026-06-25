import SwiftUI
import AppKit

struct AppsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isScanningApps {
                progress
            } else if !model.didRunApps {
                prompt
            } else if model.appUsages.isEmpty {
                ContentUnavailableView("No apps found", systemImage: "square.grid.2x2",
                                       description: Text("Couldn't find applications to measure."))
            } else {
                results
            }
        }
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2.fill").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Storage by app").font(.title2.bold())
            Text("Measures every app plus the data it leaves around the system — containers, caches, Application Support, and logs — so you can see which apps really cost you space.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
            Button { model.findApps() } label: {
                Label("Measure Apps", systemImage: "square.grid.2x2").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var progress: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Measuring apps…").font(.headline)
            Text(model.appsProgress).font(.caption.monospaced()).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle).frame(maxWidth: 420)
            Button("Cancel") { model.cancelApps() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        VStack(spacing: 0) {
            UndoBanner()
            HStack {
                Label("\(model.appUsages.count) apps", systemImage: "square.grid.2x2.fill")
                Spacer()
                Button { model.findApps() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            PaginatedList(items: model.appUsages, pageSize: 40, spacing: 8) { app, _ in
                AppRow(app: app, maxTotal: model.appUsages.first?.total ?? 1)
            }
        }
    }
}

private struct AppRow: View {
    @Environment(AppModel.self) private var model
    let app: AppUsage
    let maxTotal: Int64
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if app.locations.isEmpty {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.clear).frame(width: 12)
                } else {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(.secondary).frame(width: 12)
                }
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).lineLimit(1).truncationMode(.middle)
                    Text("\(ByteFormat.string(app.bundleSize)) app · \(ByteFormat.string(app.dataSize)) data")
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                Spacer(minLength: 12)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(Color.brand.gradient)
                            .frame(width: max(4, g.size.width * CGFloat(app.total) / CGFloat(max(1, maxTotal))))
                    }
                }
                .frame(width: 110, height: 8)
                Text(ByteFormat.string(app.total)).font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary).frame(width: 78, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture { if !app.locations.isEmpty { withAnimation(.snappy) { expanded.toggle() } } }
            .contextMenu {
                if let u = app.bundleURL {
                    Button { NSWorkspace.shared.activateFileViewerSelecting([u]) } label: { Label("Reveal app", systemImage: "folder") }
                }
            }

            if expanded {
                Divider().padding(.vertical, 6)
                ForEach(app.locations) { loc in
                    HStack(spacing: 8) {
                        Image(systemName: "folder").font(.caption2).foregroundStyle(.secondary)
                        Text(loc.label).font(.caption)
                        Text(loc.url.path).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(ByteFormat.string(loc.size)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Button { model.addToBin(url: loc.url, size: loc.size, name: "\(app.name) \(loc.label)") } label: {
                            Image(systemName: model.isInBin(loc.url) ? "checkmark.circle.fill" : "xmark.bin")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(model.isInBin(loc.url) ? Color.green : Color.secondary)
                        .help("Add this data folder to the Bin")
                    }
                    .padding(.leading, 24).padding(.vertical, 1)
                }
                Text("Tip: the app bundle isn't shown here — drag it from Finder to uninstall. The data folders above are safe to clear.")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.leading, 24).padding(.top, 4)
            }
        }
        .padding(12).card(8)
    }

    private var icon: some View {
        Group {
            if let u = app.bundleURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: u.path)).resizable()
            } else {
                Image(systemName: "app.dashed").resizable()
            }
        }
        .frame(width: 28, height: 28)
    }
}
