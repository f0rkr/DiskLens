import SwiftUI
import AppKit

/// Banner showing the last action with an Undo button (when something is restorable).
struct UndoBanner: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        if let msg = model.lastActionMessage {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(msg).font(.callout)
                Spacer()
                if !model.lastTrashPairs.isEmpty {
                    Button("Undo") { model.undoLastTrash() }.controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.green.opacity(0.10))
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}

struct FilesView: View {
    @Environment(AppModel.self) private var model
    @State private var oldOnly = false

    private var cutoff: Date { Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? .distantPast }
    private var files: [FileNode] {
        let all = model.insights.topFiles
        return oldOnly ? all.filter { ($0.modifiedAt ?? .now) < cutoff } : all
    }
    private var maxSize: Int64 { model.insights.topFiles.first?.size ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            UndoBanner()
            HStack {
                Text("Largest files").font(.headline)
                Spacer()
                Toggle(isOn: $oldOnly.animation(.snappy)) {
                    Label("Old only (1y+)", systemImage: "clock.badge.exclamationmark")
                }
                .toggleStyle(.switch).controlSize(.mini)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            if files.isEmpty {
                ContentUnavailableView(
                    oldOnly ? "No old large files" : "No files",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(oldOnly ? "None of the largest files are older than a year." : "Nothing to list."))
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(files.enumerated()), id: \.element.id) { idx, f in
                            FileRow(file: f, rank: idx + 1, maxSize: maxSize)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

private struct FileRow: View {
    @Environment(AppModel.self) private var model
    let file: FileNode
    let rank: Int
    let maxSize: Int64

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                .frame(width: 26, alignment: .trailing)
            Image(systemName: "doc.fill").foregroundStyle(FileColor.color(for: file))
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).lineLimit(1).truncationMode(.middle)
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(FileColor.color(for: file).gradient)
                        .frame(width: max(4, g.size.width * CGFloat(file.size) / CGFloat(maxSize)))
                }
            }
            .frame(width: 120, height: 8)
            Text(ByteFormat.string(file.size)).font(.callout.monospacedDigit())
                .foregroundStyle(.secondary).frame(width: 76, alignment: .trailing)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .card(10)
        .contentShape(Rectangle())
        .onTapGesture { QuickLook.show(file.url) }
        .contextMenu {
            Button { QuickLook.show(file.url) } label: { Label("Quick Look", systemImage: "eye") }
            Button { NSWorkspace.shared.open(file.url) } label: { Label("Open", systemImage: "arrow.up.forward.app") }
            Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Label("Reveal in Finder", systemImage: "folder") }
            Divider()
            Button(role: .destructive) { model.trashOne(file.url, size: file.size) } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    private var subtitle: String {
        let dir = file.url.deletingLastPathComponent().path
        if let d = file.modifiedAt {
            return "\(dir) · modified \(d.formatted(.relative(presentation: .named)))"
        }
        return dir
    }
}
