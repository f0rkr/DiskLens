import SwiftUI

/// Two extra lenses on a scan: usage grouped by file extension, or by file age.
struct ByTypeView: View {
    let insights: ScanInsights
    @State private var mode: Mode = .ext

    enum Mode: String, CaseIterable, Identifiable {
        case ext = "By extension"
        case age = "By age"
        var id: String { rawValue }
    }

    private var rows: [GroupStat] { mode == .ext ? insights.byExtension : insights.byAge }
    private var maxBytes: Int64 { rows.map(\.bytes).max() ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode.animation(.snappy)) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(maxWidth: 300)
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider()

            if rows.isEmpty {
                ContentUnavailableView("Nothing to group", systemImage: "tag",
                                       description: Text("This folder has no files to group."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(rows) { row($0) }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func row(_ r: GroupStat) -> some View {
        HStack(spacing: 12) {
            Text(mode == .ext ? formatExt(r.label) : r.label)
                .frame(width: 150, alignment: .leading).lineLimit(1).truncationMode(.middle)
            Text("\(r.count) file\(r.count == 1 ? "" : "s")")
                .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.brand.gradient)
                        .frame(width: max(4, g.size.width * CGFloat(r.bytes) / CGFloat(maxBytes)))
                }
            }
            .frame(height: 9)
            Text(ByteFormat.string(r.bytes)).font(.callout.monospacedDigit())
                .foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 6).padding(.horizontal, 12)
        .card(8)
    }

    private func formatExt(_ e: String) -> String { e == "(none)" ? "No extension" : ".\(e)" }
}
