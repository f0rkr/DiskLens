import SwiftUI

/// Bottom "Previous / Next" bar for a paginated list.
struct PagerBar: View {
    let total: Int
    let pageSize: Int
    let page: Int
    let onPrev: () -> Void
    let onNext: () -> Void

    private var pageCount: Int { max(1, (total + pageSize - 1) / pageSize) }

    var body: some View {
        let start = total == 0 ? 0 : page * pageSize + 1
        let end = min((page + 1) * pageSize, total)
        HStack(spacing: 12) {
            Text("\(start)–\(end) of \(total)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
            Button(action: onPrev) { Label("Previous", systemImage: "chevron.left") }
                .disabled(page <= 0)
            Text("Page \(page + 1) of \(pageCount)").font(.caption.monospacedDigit())
            Button(action: onNext) {
                HStack(spacing: 4) { Text("Next"); Image(systemName: "chevron.right") }
            }
            .disabled(page >= pageCount - 1)
        }
        .controlSize(.small)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// A list rendered one page at a time with a Previous/Next pager, so big
/// result sets stay fast and navigable instead of one endless scroll. The row
/// builder gets the item and its global (across-pages) index. Pass `resetKey`
/// so changing a filter jumps back to page 1.
struct PaginatedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var pageSize: Int = 50
    var resetKey: AnyHashable = AnyHashable(0)
    var spacing: CGFloat = 8
    @ViewBuilder var row: (Item, Int) -> Row

    @State private var page = 0

    private var pageCount: Int { max(1, (items.count + pageSize - 1) / pageSize) }
    private var clamped: Int { min(max(0, page), pageCount - 1) }

    var body: some View {
        let base = clamped * pageSize
        let end = min(base + pageSize, items.count)
        let slice = base < end ? Array(items[base..<end]) : []
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: spacing) {
                    ForEach(Array(slice.enumerated()), id: \.element.id) { local, item in
                        row(item, base + local)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if items.count > pageSize {
                PagerBar(total: items.count, pageSize: pageSize, page: clamped,
                         onPrev: { withAnimation(.snappy) { page = max(0, clamped - 1) } },
                         onNext: { withAnimation(.snappy) { page = min(pageCount - 1, clamped + 1) } })
            }
        }
        .onChange(of: resetKey) { page = 0 }
    }
}
