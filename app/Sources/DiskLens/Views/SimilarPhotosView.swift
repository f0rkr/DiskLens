import SwiftUI
import AppKit
import ImageIO

struct SimilarPhotosView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .similar

    enum Mode: String, CaseIterable, Identifiable {
        case similar = "Similar copies", junk = "Junk"
        var id: String { rawValue }
    }

    private var totalReclaimable: Int64 { model.similarGroups.reduce(0) { $0 + $1.reclaimable } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode.animation(.snappy)) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            switch mode {
            case .similar: similarContent
            case .junk:    JunkPhotosContent()
            }
        }
        .navigationTitle("Photos")
    }

    @ViewBuilder private var similarContent: some View {
        if model.isFindingSimilar {
            progress
        } else if !model.didRunSimilar {
            prompt
        } else if model.similarGroups.isEmpty {
            ContentUnavailableView("No similar photos",
                                   systemImage: "checkmark.seal.fill",
                                   description: Text("No visually-similar images were found under this folder."))
        } else {
            results
        }
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Find similar photos").font(.title2.bold())
            Text("Uses on-device image analysis (Vision) to find visually-similar photos — resized, re-encoded, or lightly-edited copies that the byte-exact duplicate finder misses.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
            Button { model.findSimilarPhotos() } label: {
                Label("Find Similar Photos", systemImage: "sparkle.magnifyingglass").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var progress: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Analyzing photos…").font(.headline)
            Text(model.similarProgress).font(.caption.monospaced()).foregroundStyle(.secondary)
            Button("Cancel") { model.cancelSimilar() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(model.similarGroups.count) similar sets", systemImage: "photo.on.rectangle.angled")
                Spacer()
                Text("Up to \(ByteFormat.string(totalReclaimable)) reclaimable").foregroundStyle(.secondary)
                Button { model.findSimilarPhotos() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            PaginatedList(items: model.similarGroups, pageSize: 30, spacing: 10) { group, _ in
                SimilarGroupRow(group: group)
            }
        }
    }
}

// MARK: - Junk photos (blurry / screenshots)

private struct JunkPhotosContent: View {
    @Environment(AppModel.self) private var model

    private var total: Int64 { model.junkPhotos.reduce(0) { $0 + $1.node.size } }
    private var blurryCount: Int { model.junkPhotos.filter { $0.reason == .blurry }.count }
    private var shotCount: Int { model.junkPhotos.filter { $0.reason == .screenshot }.count }

    var body: some View {
        if model.isFindingJunk {
            progress
        } else if !model.didRunJunk {
            prompt
        } else if model.junkPhotos.isEmpty {
            ContentUnavailableView("No junk photos",
                                   systemImage: "checkmark.seal.fill",
                                   description: Text("No blurry shots or screenshots were found under this folder."))
        } else {
            results
        }
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Find junk photos").font(.title2.bold())
            Text("Flags likely out-of-focus shots (measured on-device) and screen captures, so you can clear the photos you'd never keep. Review the thumbnails before staging anything.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
            Button { model.findJunkPhotos() } label: {
                Label("Find Junk Photos", systemImage: "sparkle.magnifyingglass").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var progress: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Analyzing photos…").font(.headline)
            Text(model.junkProgress).font(.caption.monospaced()).foregroundStyle(.secondary)
            Button("Cancel") { model.cancelJunk() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(blurryCount) blurry · \(shotCount) screenshots", systemImage: "photo.badge.exclamationmark")
                Spacer()
                Text("\(ByteFormat.string(total)) total").foregroundStyle(.secondary)
                Button { for j in model.junkPhotos { model.addToBin(j.node) } } label: {
                    Label("Add all to Bin", systemImage: "xmark.bin")
                }
                .controlSize(.small)
                Button { model.findJunkPhotos() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            PaginatedList(items: model.junkPhotos, pageSize: 40, spacing: 8) { item, _ in
                JunkPhotoRow(item: item)
            }
        }
    }
}

private struct JunkPhotoRow: View {
    @Environment(AppModel.self) private var model
    let item: JunkPhoto

    private var badgeColor: Color { item.reason == .blurry ? .orange : .blue }

    var body: some View {
        HStack(spacing: 12) {
            Thumbnail(url: item.node.url)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.node.name).lineLimit(1).truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(item.reason.rawValue).font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(badgeColor.opacity(0.15), in: Capsule()).foregroundStyle(badgeColor)
                    Text(item.node.url.deletingLastPathComponent().path)
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            Text(ByteFormat.string(item.node.size)).font(.callout.monospacedDigit())
                .foregroundStyle(.secondary).frame(width: 72, alignment: .trailing)
            let inBin = model.isInBin(item.node.url)
            Button { withAnimation(.snappy) { model.toggleBin(item.node) } } label: {
                Image(systemName: inBin ? "checkmark.circle.fill" : "trash.circle").font(.title3)
            }
            .buttonStyle(.plain).foregroundStyle(inBin ? Color.green : Color.secondary)
            .help(inBin ? "Staged in the Bin, click to remove" : "Add to Bin")
        }
        .padding(8).card(10)
        .contentShape(Rectangle())
        .onTapGesture { QuickLook.show(item.node.url) }
        .contextMenu {
            Button { model.inspecting = item.node } label: { Label("Get Info", systemImage: "info.circle") }
            Button { QuickLook.show(item.node.url) } label: { Label("Quick Look", systemImage: "eye") }
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.node.url]) } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }
}

private struct SimilarGroupRow: View {
    @Environment(AppModel.self) private var model
    let group: SimilarGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(group.files.count) similar").font(.headline)
                Text("save \(ByteFormat.string(group.reclaimable))")
                    .font(.caption.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule()).foregroundStyle(.tint)
                Spacer()
                Button { for f in group.files.dropFirst() { model.addToBin(f) } } label: {
                    Label("Add \(group.files.count - 1) to Bin", systemImage: "xmark.bin")
                }
                .controlSize(.small)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(group.files.enumerated()), id: \.element.id) { idx, f in
                        VStack(spacing: 4) {
                            Thumbnail(url: f.url)
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(idx == 0 ? Color.green : Color.primary.opacity(0.12),
                                                  lineWidth: idx == 0 ? 2 : 1))
                                .overlay(alignment: .topLeading) {
                                    if idx == 0 {
                                        Text("keep").font(.caption2.bold())
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(.green, in: Capsule()).foregroundStyle(.white).padding(4)
                                    }
                                }
                            Text(ByteFormat.string(f.size)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .onTapGesture { QuickLook.show(f.url) }
                        .contextMenu {
                            Button { QuickLook.show(f.url) } label: { Label("Quick Look", systemImage: "eye") }
                            Button { NSWorkspace.shared.activateFileViewerSelecting([f.url]) } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                            if idx != 0 {
                                Button { model.addToBin(f) } label: { Label("Add to Bin", systemImage: "xmark.bin") }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12).card(8)
    }
}

/// Fast downscaled thumbnail loaded off the main thread via ImageIO.
private struct Thumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .task(id: url) { image = await Self.load(url) }
    }

    static func load(_ url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 200,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return NSImage(cgImage: cg, size: .zero)
        }.value
    }
}
