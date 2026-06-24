import SwiftUI
import AppKit

/// The in-app Bin: a staging area for files you intend to delete. You review the
/// total space they'll free, then commit with one button — and even then they
/// only move to the Trash, so nothing is ever an unrecoverable delete.
struct BinView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            UndoBanner()
            if model.binItems.isEmpty {
                ContentUnavailableView {
                    Label("Bin is empty", systemImage: "xmark.bin")
                } description: {
                    Text("Add files from any view to stage them here. Nothing is deleted until you empty the bin — and then it just goes to the Trash.")
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.binItems) { item in
                            BinRow(item: item)
                        }
                    }
                    .padding(16)
                }
                actionBar
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(model.binItems.count) item\(model.binItems.count == 1 ? "" : "s") staged")
                    .font(.callout.weight(.medium))
                Text("\(ByteFormat.string(model.binTotalBytes)) will be freed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Clear") { model.clearBin() }
                .controlSize(.large)
            Button(role: .destructive) { model.emptyBin() } label: {
                Label("Empty Bin → Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.bar)
    }
}

private struct BinRow: View {
    @Environment(AppModel.self) private var model
    let item: BinItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption2).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text(ByteFormat.string(item.size))
                .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)
            Button { model.removeFromBin(item.url) } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Remove from bin")
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .card(10)
        .contextMenu {
            Button { QuickLook.show(item.url) } label: { Label("Quick Look", systemImage: "eye") }
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            Divider()
            Button { model.removeFromBin(item.url) } label: {
                Label("Remove from Bin", systemImage: "xmark")
            }
        }
    }
}
