import SwiftUI

/// One hub that gathers everything reclaimable — smart cleanup, old & large
/// files, exact duplicates, similar photos, and hidden OS space — each with a
/// one-tap action (stage to the Bin, or a system reclaim for snapshots).
struct ReclaimView: View {
    @Environment(AppModel.self) private var model

    private var cutoff: Date { Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? .distantPast }
    private var oldLarge: [FileNode] { model.insights.topFiles.filter { ($0.modifiedAt ?? .now) < cutoff } }

    private var cleanupTotal: Int64 { model.cleanupSuggestions.reduce(0) { $0 + $1.size } }
    private var oldLargeTotal: Int64 { oldLarge.reduce(0) { $0 + $1.size } }
    private var dupTotal: Int64 { model.duplicateGroups.reduce(0) { $0 + $1.reclaimable } }
    private var similarTotal: Int64 { model.similarGroups.reduce(0) { $0 + $1.reclaimable } }
    private var headline: Int64 { cleanupTotal + oldLargeTotal + dupTotal + similarTotal }

    var body: some View {
        VStack(spacing: 0) {
            UndoBanner()
            ScrollView {
                VStack(spacing: 14) {
                    summary
                    cleanupCard
                    oldLargeCard
                    duplicatesCard
                    similarCard
                    hiddenCard
                }
                .padding(16)
                .frame(maxWidth: 820).frame(maxWidth: .infinity)
            }
        }
        .task { await model.refreshHiddenSpace() }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text(ByteFormat.string(headline))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing))
            Text("ready to reclaim, staged safely to the Bin").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    private func card<Trailing: View>(_ icon: String, _ title: String, _ detail: String,
                                      tint: Color = .brand,
                                      @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private func amount(_ bytes: Int64, _ label: String, _ action: @escaping () -> Void) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(ByteFormat.string(bytes)).font(.callout.bold().monospacedDigit())
            Button(label, action: action).controlSize(.small)
        }
    }

    private var cleanupCard: some View {
        card("sparkles", "Smart cleanup",
             cleanupTotal > 0 ? "\(model.cleanupSuggestions.count) items in caches, build dirs, and junk"
                              : "Nothing obvious to clean") {
            if cleanupTotal > 0 {
                amount(cleanupTotal, "Add to Bin") {
                    for s in model.cleanupSuggestions { model.addToBin(url: s.url, size: s.size) }
                }
            }
        }
    }

    private var oldLargeCard: some View {
        card("clock.badge.exclamationmark", "Old & large files",
             oldLarge.isEmpty ? "No large files untouched for a year" : "\(oldLarge.count) files untouched 1y+",
             tint: .orange) {
            if !oldLarge.isEmpty {
                amount(oldLargeTotal, "Add to Bin") { for f in oldLarge { model.addToBin(f) } }
            }
        }
    }

    private var duplicatesCard: some View {
        card("doc.on.doc.fill", "Exact duplicates",
             model.didRunDuplicates ? "\(model.duplicateGroups.count) duplicate sets" : "Not scanned yet") {
            if model.didRunDuplicates {
                if dupTotal > 0 {
                    amount(dupTotal, "Add extras to Bin") {
                        for g in model.duplicateGroups {
                            for u in g.files.dropFirst() { model.addToBin(url: u, size: g.size, isDirectory: false) }
                        }
                    }
                } else { Text("None found").foregroundStyle(.secondary) }
            } else {
                Button("Scan") { model.selection = .duplicates; model.findDuplicates() }.controlSize(.small)
            }
        }
    }

    private var similarCard: some View {
        card("photo.on.rectangle.angled", "Similar photos",
             model.didRunSimilar ? "\(model.similarGroups.count) similar sets" : "Not scanned yet",
             tint: .brand2) {
            if model.didRunSimilar {
                if similarTotal > 0 {
                    amount(similarTotal, "Add to Bin") {
                        for g in model.similarGroups { for f in g.files.dropFirst() { model.addToBin(f) } }
                    }
                } else { Text("None found").foregroundStyle(.secondary) }
            } else {
                Button("Scan") { model.selection = .similar; model.findSimilarPhotos() }.controlSize(.small)
            }
        }
    }

    private var hiddenCard: some View {
        let h = model.hiddenSpace
        let snaps = h?.snapshotCount ?? 0
        let purge = h?.purgeable ?? 0
        return card("clock.arrow.circlepath", "Time Machine local snapshots",
                    h == nil ? "Checking…"
                             : (snaps > 0 ? "\(snaps) local snapshots · ~\(ByteFormat.string(purge)) purgeable by macOS"
                                          : "No local snapshots"),
                    tint: .green) {
            if snaps > 0 {
                Button("Reclaim") { Task { await model.reclaimSnapshots() } }.controlSize(.small)
            }
        }
    }
}
