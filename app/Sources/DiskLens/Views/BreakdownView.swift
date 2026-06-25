import SwiftUI

struct BreakdownView: View {
    let root: FileNode
    @State private var search = ""
    @State private var sort: BreakdownSort = .size

    enum BreakdownSort: String { case size, name }

    private var items: [FileNode] {
        let base = search.isEmpty
            ? root.children
            : root.children.filter { $0.name.localizedCaseInsensitiveContains(search) }
        switch sort {
        case .size: return base   // root.children is already largest-first
        case .name: return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter top-level items", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("Size").tag(BreakdownSort.size)
                        Text("Name").tag(BreakdownSort.name)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down").foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton).fixedSize()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .card(10)
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            if !search.isEmpty && items.isEmpty {
                ContentUnavailableView("No matches", systemImage: "magnifyingglass",
                                       description: Text("No items match “\(search)”."))
                    .frame(maxHeight: .infinity)
            } else {
                PaginatedList(items: items, resetKey: AnyHashable("\(search)|\(sort.rawValue)"), spacing: 2) { child, _ in
                    BreakdownRow(node: child, siblingMax: root.children.first?.size ?? 1, depth: 0)
                }
            }
        }
    }
}

private struct BreakdownRow: View {
    @Environment(AppModel.self) private var model
    let node: FileNode
    let siblingMax: Int64
    let depth: Int
    @State private var expanded = false

    private var fraction: CGFloat {
        siblingMax > 0 ? CGFloat(node.size) / CGFloat(siblingMax) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
                .contentShape(Rectangle())
                .onTapGesture {
                    if node.childrenOrNil != nil { withAnimation(.snappy) { expanded.toggle() } }
                }
                .contextMenu {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([node.url])
                    }
                    if model.isInBin(node.url) {
                        Button { model.removeFromBin(node.url) } label: { Label("Remove from Bin", systemImage: "xmark.bin") }
                    } else {
                        Button { model.addToBin(node) } label: { Label("Add to Bin", systemImage: "xmark.bin") }
                    }
                    if node.isDirectory {
                        Divider()
                        Button { model.compressAndTrash(node.url, size: node.size) } label: {
                            Label("Compress & Move Original to Trash", systemImage: "archivebox")
                        }
                    }
                }

            if expanded, let children = node.childrenOrNil {
                ForEach(children.prefix(250)) { child in
                    BreakdownRow(node: child,
                                 siblingMax: children.first?.size ?? 1,
                                 depth: depth + 1)
                }
                if children.count > 250 {
                    Text("+ \(children.count - 250) more…")
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.leading, CGFloat(depth + 1) * 18 + 30)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: node.childrenOrNil != nil
                  ? (expanded ? "chevron.down" : "chevron.right")
                  : "circle.fill")
                .font(node.childrenOrNil != nil ? .caption : .system(size: 5))
                .foregroundStyle(node.childrenOrNil != nil ? Color.secondary : FileColor.color(for: node))
                .frame(width: 12)

            Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(node.isDirectory ? Color.accentColor : .secondary)
                .font(.callout)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            // Size bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(FileColor.color(for: node).gradient)
                        .frame(width: max(2, geo.size.width * fraction))
                }
            }
            .frame(width: 140, height: 7)

            Text(ByteFormat.string(node.size))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.trailing, 16)
        .padding(.leading, CGFloat(depth) * 18 + 12)
    }
}
