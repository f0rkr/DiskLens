import SwiftUI
import AppKit

/// Treemap drawn with a single Canvas (one draw pass, not one view per tile) so
/// it stays fast even on folders with thousands of children. Hover and click use
/// exact point-in-rect hit-testing, so the highlighted tile is always the one
/// under the cursor.
struct TreemapView: View {
    @Environment(AppModel.self) private var model
    let root: FileNode
    @State private var stack: [FileNode] = []
    @State private var hoveredID: UUID?

    private let maxTiles = 150
    private var current: FileNode { stack.last ?? root }

    private var visibleChildren: [FileNode] {
        let kids = current.childrenOrNil ?? []
        return kids.count > maxTiles ? Array(kids.prefix(maxTiles)) : kids
    }
    private var omitted: Int { max(0, (current.childrenOrNil?.count ?? 0) - maxTiles) }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
            Divider()
            GeometryReader { geo in
                let bounds = CGRect(origin: .zero, size: geo.size).insetBy(dx: 3, dy: 3)
                let tiles = Squarify.layout(visibleChildren, in: bounds)
                Canvas { ctx, _ in
                    for tile in tiles { draw(tile, in: ctx) }
                }
                .contentShape(Rectangle())
                .onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active(let pt):
                        let id = tiles.first { $0.rect.contains(pt) }?.node.id
                        if id != hoveredID { hoveredID = id }
                    case .ended:
                        hoveredID = nil
                    }
                }
                .gesture(
                    SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                        guard let node = tiles.first(where: { $0.rect.contains(value.location) })?.node else { return }
                        if node.childrenOrNil != nil {
                            withAnimation(.snappy(duration: 0.22)) { stack.append(node); hoveredID = nil }
                        } else {
                            NSWorkspace.shared.activateFileViewerSelecting([node.url])
                        }
                    }
                )
                .contextMenu {
                    if let n = hoveredNode {
                        Button { model.inspecting = n } label: { Label("Get Info", systemImage: "info.circle") }
                        if n.childrenOrNil != nil {
                            Button { withAnimation(.snappy) { stack.append(n); hoveredID = nil } } label: {
                                Label("Zoom into \(n.name)", systemImage: "plus.magnifyingglass")
                            }
                        } else {
                            Button { QuickLook.show(n.url) } label: { Label("Quick Look", systemImage: "eye") }
                        }
                        Button { NSWorkspace.shared.activateFileViewerSelecting([n.url]) } label: {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        Divider()
                        if model.isInBin(n.url) {
                            Button { model.removeFromBin(n.url) } label: { Label("Remove from Bin", systemImage: "xmark.bin") }
                        } else {
                            Button { model.addToBin(n) } label: { Label("Add to Bin", systemImage: "xmark.bin") }
                        }
                        if n.isDirectory {
                            Divider()
                            Button { model.compressAndTrash(n.url, size: n.size) } label: {
                                Label("Compress & Trash original", systemImage: "archivebox")
                            }
                        }
                    }
                }
                .overlay {
                    if tiles.isEmpty {
                        Text("This folder is empty").foregroundStyle(.secondary)
                    }
                }
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            statusBar
        }
        .navigationTitle("Treemap")
    }

    private func draw(_ tile: TreemapTile, in ctx: GraphicsContext) {
        let inset = tile.rect.insetBy(dx: 1, dy: 1)
        guard inset.width > 1, inset.height > 1 else { return }
        let path = Path(roundedRect: inset, cornerRadius: 3)
        let highlighted = hoveredID == tile.node.id
        ctx.fill(path, with: .color(FileColor.color(for: tile.node).opacity(highlighted ? 1.0 : 0.92)))
        ctx.stroke(path, with: .color(highlighted ? .white : .black.opacity(0.20)),
                   lineWidth: highlighted ? 2 : 0.5)

        guard inset.width > 50, inset.height > 24 else { return }
        var label = ctx
        label.clip(to: path)
        label.draw(
            Text(tile.node.name).font(.caption2.weight(.semibold)).foregroundColor(.white),
            at: CGPoint(x: inset.minX + 6, y: inset.minY + 5), anchor: .topLeading)
        if inset.height > 40 {
            label.draw(
                Text(ByteFormat.string(tile.node.size)).font(.system(size: 9)).foregroundColor(.white.opacity(0.85)),
                at: CGPoint(x: inset.minX + 6, y: inset.minY + 21), anchor: .topLeading)
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Button { stack.removeAll(); hoveredID = nil } label: {
                Label(root.name, systemImage: "house.fill").labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            ForEach(Array(stack.enumerated()), id: \.element.id) { idx, node in
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                Button { stack = Array(stack.prefix(idx + 1)); hoveredID = nil } label: { Text(node.name) }
                    .buttonStyle(.plain)
            }
            Spacer()
            if !stack.isEmpty {
                Button { withAnimation(.snappy) { _ = stack.removeLast(); hoveredID = nil } } label: {
                    Label("Up", systemImage: "arrow.up.left")
                }
            }
        }
        .font(.callout)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var hoveredNode: FileNode? {
        guard let id = hoveredID else { return nil }
        return visibleChildren.first { $0.id == id }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if let h = hoveredNode {
                Circle().fill(FileColor.color(for: h)).frame(width: 9, height: 9)
                Text(h.name).bold().lineLimit(1)
                Text(ByteFormat.string(h.size)).foregroundStyle(.secondary)
            } else {
                Text(current.name).bold().lineLimit(1)
                Text("· \(ByteFormat.string(current.size))").foregroundStyle(.secondary)
                Text(omitted > 0 ? "· +\(omitted) smaller items not shown" : "· hover a tile, click to zoom in")
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
