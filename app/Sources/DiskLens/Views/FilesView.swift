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
    @State private var kind: FileColor.Kind?   // nil == All

    private var cutoff: Date { Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? .distantPast }

    /// Largest files after the optional "old only" filter (before the kind tab).
    private var base: [FileNode] {
        let all = model.insights.topFiles
        return oldOnly ? all.filter { ($0.modifiedAt ?? .now) < cutoff } : all
    }
    private var presentKinds: [FileColor.Kind] {
        let order: [FileColor.Kind] = [.media, .code, .document, .archive, .app, .data, .other]
        let present = Set(base.map { FileColor.kind(for: $0) })
        return order.filter { present.contains($0) }
    }
    private var files: [FileNode] {
        guard let k = kind else { return base }
        return base.filter { FileColor.kind(for: $0) == k }
    }
    private var maxSize: Int64 { model.insights.topFiles.first?.size ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            UndoBanner()
            header
            if !presentKinds.isEmpty { kindTabs }

            if files.isEmpty {
                ContentUnavailableView(
                    (kind != nil || oldOnly) ? "No matching files" : "No files",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(oldOnly ? "None of the largest files are older than a year." : "Nothing to list."))
                    .frame(maxHeight: .infinity)
            } else {
                PaginatedList(items: files,
                              resetKey: AnyHashable("\(kind.map { "\($0)" } ?? "all")|\(oldOnly)")) { f, idx in
                    FileRow(file: f, rank: idx + 1, maxSize: maxSize)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Largest files").font(.headline)
            Spacer()
            Toggle(isOn: $oldOnly.animation(.snappy)) {
                Label("Old only (1y+)", systemImage: "clock.badge.exclamationmark")
            }
            .toggleStyle(.switch).controlSize(.mini)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
    }

    private var kindTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                kindPill(nil, "All", base.count)
                ForEach(presentKinds, id: \.self) { k in
                    kindPill(k, FileColor.label(for: k), base.filter { FileColor.kind(for: $0) == k }.count)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
    }

    private func kindPill(_ k: FileColor.Kind?, _ label: String, _ count: Int) -> some View {
        let on = kind == k
        return Button { withAnimation(.easeOut(duration: 0.12)) { kind = k } } label: {
            HStack(spacing: 6) {
                if let k { Circle().fill(FileColor.color(forKind: k)).frame(width: 8, height: 8) }
                Text(label)
                Text("\(count)").font(.caption2.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(on ? Color.white.opacity(0.25) : Color.primary.opacity(0.10), in: Capsule())
            }
            .font(.callout.weight(on ? .semibold : .regular)).fixedSize()
            .padding(.horizontal, 12).padding(.vertical, 6)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? Color.brand : Color.primary.opacity(0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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

            let inBin = model.isInBin(file.url)
            Button { withAnimation(.snappy) { model.toggleBin(file) } } label: {
                Image(systemName: inBin ? "checkmark.circle.fill" : "trash.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(inBin ? Color.green : Color.secondary)
            .help(inBin ? "Staged in the Bin, click to remove" : "Add to Bin")
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
            if model.isInBin(file.url) {
                Button { model.removeFromBin(file.url) } label: { Label("Remove from Bin", systemImage: "xmark.bin") }
            } else {
                Button { model.addToBin(file) } label: { Label("Add to Bin", systemImage: "xmark.bin") }
            }
            Button(role: .destructive) { model.trashOne(file.url, size: file.size) } label: {
                Label("Move to Trash now", systemImage: "trash")
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
