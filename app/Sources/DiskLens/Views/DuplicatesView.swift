import SwiftUI

struct DuplicatesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.isFindingDuplicates {
                progress
            } else if !model.didRunDuplicates {
                prompt
            } else if model.duplicateGroups.isEmpty {
                ContentUnavailableView("No duplicates found",
                                       systemImage: "checkmark.seal.fill",
                                       description: Text("Every file under this folder is unique."))
            } else {
                results
            }
        }
        .navigationTitle("Duplicates")
    }

    private var totalReclaimable: Int64 {
        model.duplicateGroups.reduce(0) { $0 + $1.reclaimable }
    }

    private var prompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc.fill").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Find duplicate files").font(.title2.bold())
            Text("Compares files by content (SHA-256) to find exact copies.\nFiles are matched by size first, so it's fast.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { model.findDuplicates() } label: {
                Label("Scan for Duplicates", systemImage: "magnifyingglass").padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var progress: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text("Hashing files…").font(.headline)
            Text(model.duplicateProgress).font(.caption.monospaced()).foregroundStyle(.secondary)
            Button("Cancel") { model.cancelDuplicates() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var results: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(model.duplicateGroups.count) duplicate sets", systemImage: "doc.on.doc")
                Spacer()
                Text("Up to \(ByteFormat.string(totalReclaimable)) reclaimable")
                    .foregroundStyle(.secondary)
                Button { model.findDuplicates() } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.duplicateGroups) { group in
                        DuplicateGroupRow(group: group)
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct DuplicateGroupRow: View {
    @Environment(AppModel.self) private var model
    let group: DuplicateGroup
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption).foregroundStyle(.secondary).frame(width: 12)
                Text(group.files.first?.lastPathComponent ?? "—").bold().lineLimit(1)
                Text("×\(group.files.count)").foregroundStyle(.secondary)
                Spacer()
                Text(ByteFormat.string(group.size)).foregroundStyle(.secondary).monospacedDigit()
                Text("save \(ByteFormat.string(group.reclaimable))")
                    .font(.caption.bold())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { expanded.toggle() } }

            if expanded {
                Divider().padding(.vertical, 6)
                ForEach(Array(group.files.enumerated()), id: \.element) { idx, url in
                    HStack {
                        Image(systemName: idx == 0 ? "lock.fill" : "doc")
                            .foregroundStyle(idx == 0 ? .green : .secondary)
                            .font(.caption)
                        Text(url.path)
                            .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        if idx == 0 {
                            Text("keep").font(.caption2).foregroundStyle(.green)
                        } else {
                            Button("Reveal") {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }.buttonStyle(.link).font(.caption)
                        }
                    }
                    .padding(.vertical, 1)
                }
                Button(role: .destructive) {
                    let toTrash = group.files.dropFirst().map { (url: $0, size: group.size) }
                    model.trash(Array(toTrash))
                } label: {
                    Label("Trash \(group.files.count - 1) extra cop\(group.files.count - 1 == 1 ? "y" : "ies")",
                          systemImage: "trash")
                }
                .controlSize(.small)
                .padding(.top, 6)
            }
        }
        .padding(12)
        .card(8)
    }
}
