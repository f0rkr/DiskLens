import SwiftUI

/// Cleanup, organized as category tabs with a paginated table underneath, so a
/// folder with thousands of suggestions stays fast and navigable instead of one
/// endless scroll. Selection is kept across pages and categories.
struct CleanupView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<URL> = []
    @State private var activeCategory: CleanupSuggestion.Category?
    @State private var page = 0

    private let pageSize = 50

    private var nonEmptyCategories: [CleanupSuggestion.Category] {
        CleanupSuggestion.Category.allCases.filter { cat in
            model.cleanupSuggestions.contains { $0.category == cat }
        }
    }
    private func items(for cat: CleanupSuggestion.Category) -> [CleanupSuggestion] {
        model.cleanupSuggestions.filter { $0.category == cat }
    }
    private var currentCat: CleanupSuggestion.Category? { activeCategory ?? nonEmptyCategories.first }
    private var currentItems: [CleanupSuggestion] { currentCat.map { items(for: $0) } ?? [] }

    private var pageCount: Int { max(1, (currentItems.count + pageSize - 1) / pageSize) }
    private var clampedPage: Int { min(max(0, page), pageCount - 1) }
    private var pageItems: [CleanupSuggestion] {
        let start = clampedPage * pageSize
        let end = min(start + pageSize, currentItems.count)
        return start < end ? Array(currentItems[start..<end]) : []
    }
    private var allPageSelected: Bool {
        !pageItems.isEmpty && pageItems.allSatisfy { selected.contains($0.url) }
    }
    private var selectedBytes: Int64 {
        model.cleanupSuggestions.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        Group {
            if model.cleanupSuggestions.isEmpty {
                ContentUnavailableView("Nothing obvious to clean",
                                       systemImage: "sparkles",
                                       description: Text("No caches, build folders, or junk files found under this folder."))
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            UndoBanner()
            categoryTabs
            if let c = currentCat {
                Text(c.blurb)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 6)
            }
            tableHeader
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(pageItems) { item in row(item) }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            paginationBar
            actionBar
        }
    }

    // MARK: category tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(nonEmptyCategories) { cat in
                    categoryPill(cat)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func categoryPill(_ cat: CleanupSuggestion.Category) -> some View {
        let on = currentCat == cat
        let group = items(for: cat)
        let total = group.reduce(Int64(0)) { $0 + $1.size }
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { activeCategory = cat; page = 0 }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                Text(cat.rawValue)
                Text("\(group.count)")
                    .font(.caption2.weight(.bold)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(on ? Color.white.opacity(0.25) : Color.primary.opacity(0.10), in: Capsule())
                Text(ByteFormat.string(total)).font(.caption2).opacity(0.85)
            }
            .font(.callout.weight(on ? .semibold : .regular))
            .lineLimit(1).fixedSize()
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? Color.brand : Color.primary.opacity(0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: table

    private var tableHeader: some View {
        HStack(spacing: 10) {
            Button {
                if allPageSelected { pageItems.forEach { selected.remove($0.url) } }
                else { pageItems.forEach { selected.insert($0.url) } }
            } label: {
                Image(systemName: allPageSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(allPageSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain).help("Select everything on this page")
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Location").frame(maxWidth: .infinity, alignment: .leading)
            Text("Detail").frame(width: 96, alignment: .leading)
            Text("Size").frame(width: 78, alignment: .trailing)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func row(_ item: CleanupSuggestion) -> some View {
        let isOn = selected.contains(item.url)
        let inBin = model.isInBin(item.url)
        return HStack(spacing: 10) {
            Button { toggle(item.url) } label: {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                if inBin {
                    Text("in Bin").font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.green.opacity(0.18), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.url.deletingLastPathComponent().path)
                .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).frame(width: 96, alignment: .leading)

            Text(ByteFormat.string(item.size)).monospacedDigit()
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
        .card(6)
        .contentShape(Rectangle())
        .onTapGesture { toggle(item.url) }
        .contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }

    private func toggle(_ url: URL) {
        if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
    }

    // MARK: pagination + actions

    private var paginationBar: some View {
        let start = currentItems.isEmpty ? 0 : clampedPage * pageSize + 1
        let end = min((clampedPage + 1) * pageSize, currentItems.count)
        return HStack(spacing: 14) {
            Text("\(start)–\(end) of \(currentItems.count)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Button(allPageSelected ? "Deselect page" : "Select all \(currentItems.count)") {
                if allPageSelected { pageItems.forEach { selected.remove($0.url) } }
                else { currentItems.forEach { selected.insert($0.url) } }
            }
            .buttonStyle(.link).font(.caption)

            Spacer()

            Button { withAnimation(.snappy) { page = max(0, clampedPage - 1) } } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(clampedPage == 0)
            Text("Page \(clampedPage + 1) of \(pageCount)").font(.caption.monospacedDigit())
            Button { withAnimation(.snappy) { page = min(pageCount - 1, clampedPage + 1) } } label: {
                HStack(spacing: 4) { Text("Next"); Image(systemName: "chevron.right") }
            }
            .disabled(clampedPage >= pageCount - 1)
        }
        .controlSize(.small)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var actionBar: some View {
        HStack {
            Text(selected.isEmpty ? "Select items to clean"
                 : "\(selected.count) selected · \(ByteFormat.string(selectedBytes))")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                for s in model.cleanupSuggestions where selected.contains(s.url) {
                    model.addToBin(url: s.url, size: s.size)
                }
                selected.removeAll()
            } label: {
                Label("Add to Bin", systemImage: "xmark.bin")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
            Button(role: .destructive) {
                let items = model.cleanupSuggestions
                    .filter { selected.contains($0.url) }
                    .map { (url: $0.url, size: $0.size) }
                model.trash(items)
                selected.removeAll()
            } label: {
                Label("Trash now", systemImage: "trash")
            }
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
