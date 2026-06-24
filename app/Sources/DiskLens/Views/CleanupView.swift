import SwiftUI

struct CleanupView: View {
    @Environment(AppModel.self) private var model
    @State private var selected: Set<URL> = []

    private var grouped: [(CleanupSuggestion.Category, [CleanupSuggestion])] {
        CleanupSuggestion.Category.allCases.compactMap { cat in
            let items = model.cleanupSuggestions.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
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
        .navigationTitle("Cleanup")
    }

    private var content: some View {
        VStack(spacing: 0) {
            UndoBanner()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(grouped, id: \.0) { cat, items in
                        categorySection(cat, items)
                    }
                }
                .padding(14)
            }
            actionBar
        }
    }

    private func categorySection(_ cat: CleanupSuggestion.Category, _ items: [CleanupSuggestion]) -> some View {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        let allSelected = items.allSatisfy { selected.contains($0.url) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: cat.icon).foregroundStyle(.tint)
                Text(cat.rawValue).font(.headline)
                Text(ByteFormat.string(total)).foregroundStyle(.secondary)
                Spacer()
                Button(allSelected ? "Deselect all" : "Select all") {
                    if allSelected { items.forEach { selected.remove($0.url) } }
                    else { items.forEach { selected.insert($0.url) } }
                }
                .font(.caption).buttonStyle(.link)
            }
            Text(cat.blurb).font(.caption).foregroundStyle(.secondary)

            ForEach(items) { item in
                row(item)
            }
        }
    }

    private func row(_ item: CleanupSuggestion) -> some View {
        let isOn = selected.contains(item.url)
        return HStack(spacing: 10) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.url.lastPathComponent).lineLimit(1)
                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.detail).font(.caption).foregroundStyle(.secondary)
            Text(ByteFormat.string(item.size))
                .monospacedDigit().frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 5).padding(.horizontal, 10)
        .card(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if isOn { selected.remove(item.url) } else { selected.insert(item.url) }
        }
        .contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }

    private var actionBar: some View {
        HStack {
            Text(selected.isEmpty ? "Select items to clean"
                 : "\(selected.count) selected · \(ByteFormat.string(selectedBytes))")
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                let items = model.cleanupSuggestions
                    .filter { selected.contains($0.url) }
                    .map { (url: $0.url, size: $0.size) }
                model.trash(items)
                selected.removeAll()
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.bar)
    }
}
