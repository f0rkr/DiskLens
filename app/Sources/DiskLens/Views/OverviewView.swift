import SwiftUI
import Charts

/// The dashboard: a single screen (no scrolling) that fills the window — a row
/// of stat cards on top, then "usage by type" and "largest items" side by side.
struct OverviewView: View {
    let insights: ScanInsights
    var delta: ScanDelta? = nil
    var history: [ScanSnapshot] = []
    var diskStats: DiskStats? = nil

    private var catTotal: Int64 { max(1, insights.categories.reduce(0) { $0 + $1.bytes }) }
    private var maxTop: Int64 { insights.topItems.first?.size ?? 1 }
    private var topItems: [FileNode] { Array(insights.topItems.prefix(7)) }

    /// One size for every stat value, so the cards read consistently.
    private let statFont = Font.system(size: 30, weight: .bold, design: .rounded)

    var body: some View {
        Group {
            if insights.totalFiles == 0 {
                ContentUnavailableView("Nothing to chart", systemImage: "chart.pie",
                                       description: Text("This folder has no files to summarize."))
            } else {
                VStack(spacing: 16) {
                    if let d = delta, d.hasChanges { historyCard(d) }
                    statRow
                    HStack(spacing: 16) {
                        byType
                        largest
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - top stat cards

    private var statRow: some View {
        HStack(spacing: 14) {
            totalCard
            stat("Files", insights.totalFiles.formatted(), "doc.on.doc.fill")
            stat("Types", "\(insights.categories.count)", "square.grid.2x2.fill")
            stat("Largest", ByteFormat.string(insights.topItems.first?.size ?? 0), "arrow.up.circle.fill",
                 sub: insights.largestName)
        }
        .frame(height: 128)
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Total used", systemImage: "internaldrive.fill")
                .font(.caption).foregroundStyle(.secondary)
            Text(ByteFormat.string(insights.totalBytes))
                .font(statFont)
                .foregroundStyle(LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing))
                .lineLimit(1).minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            if let d = diskStats, d.total > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(Color.brand.gradient)
                            .frame(width: g.size.width * CGFloat(d.used) / CGFloat(d.total))
                    }
                }
                .frame(height: 8)
                Text("\(ByteFormat.string(d.free)) free of \(ByteFormat.string(d.total))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(insights.categories) { c in
                            Rectangle().fill(c.color)
                                .frame(width: max(2, g.size.width * CGFloat(c.bytes) / CGFloat(catTotal)))
                        }
                    }
                }
                .frame(height: 8).clipShape(Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .card(16)
    }

    private func stat(_ label: String, _ value: String, _ icon: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value).font(statFont).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            if let sub { Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .card(16)
    }

    // MARK: - usage by type (donut + legend)

    private var byType: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Usage by type").font(.headline)
            HStack(spacing: 18) {
                Chart(insights.categories) { c in
                    SectorMark(angle: .value("Size", Double(c.bytes)), innerRadius: .ratio(0.64), angularInset: 2)
                        .cornerRadius(4)
                        .foregroundStyle(c.color)
                }
                .frame(width: 148, height: 148)
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(insights.categories.count)").font(.title2.bold())
                        Text("types").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 8) {
                    ForEach(insights.categories) { c in
                        HStack(spacing: 9) {
                            RoundedRectangle(cornerRadius: 3).fill(c.color).frame(width: 11, height: 11)
                            Text(c.label).lineLimit(1)
                            Spacer(minLength: 10)
                            Text(pct(c.bytes)).foregroundStyle(.secondary).monospacedDigit()
                            Text(ByteFormat.string(c.bytes)).frame(width: 72, alignment: .trailing).monospacedDigit()
                        }
                        .font(.callout)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(18)
    }

    // MARK: - largest items

    private var largest: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Largest items").font(.headline)
            VStack(spacing: 9) {
                ForEach(topItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(FileColor.color(for: item)).frame(width: 18)
                        Text(item.name).lineLimit(1).truncationMode(.middle)
                            .frame(width: 150, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary)
                                Capsule().fill(FileColor.color(for: item).gradient)
                                    .frame(width: max(4, g.size.width * CGFloat(item.size) / CGFloat(maxTop)))
                            }
                        }
                        .frame(height: 9)
                        Text(ByteFormat.string(item.size)).font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary).frame(width: 78, alignment: .trailing)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(18)
    }

    // MARK: - "what grew" since the last scan of this folder

    private func historyCard(_ d: ScanDelta) -> some View {
        let grew = d.totalChange >= 0
        let accent = grew ? Color.orange : Color.green
        return HStack(spacing: 12) {
            Image(systemName: grew ? "arrow.up.forward.circle.fill" : "arrow.down.forward.circle.fill")
                .foregroundStyle(accent)
            Text("\(grew ? "+" : "-")\(ByteFormat.string(abs(d.totalChange)))")
                .font(.headline).foregroundStyle(accent)
            Text("since \(d.since.formatted(.relative(presentation: .named)))")
                .foregroundStyle(.secondary).lineLimit(1)
            ForEach(Array(d.changes.prefix(3).enumerated()), id: \.offset) { _, ch in
                HStack(spacing: 4) {
                    Image(systemName: ch.delta >= 0 ? "arrow.up" : "arrow.down").font(.caption2)
                    Text(ch.name).lineLimit(1)
                    Text("\(ch.delta >= 0 ? "+" : "-")\(ByteFormat.string(abs(ch.delta)))")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
            Spacer(minLength: 12)
            if history.count >= 2 {
                trend.frame(width: 200, height: 42)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(14)
    }

    /// Sparkline of this folder's total size across past scans.
    private var trend: some View {
        Chart(history, id: \.date) { snap in
            AreaMark(x: .value("When", snap.date), y: .value("Size", Double(snap.totalBytes)))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [Color.brand.opacity(0.35), Color.brand.opacity(0.02)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("When", snap.date), y: .value("Size", Double(snap.totalBytes)))
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.brand)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
    }

    private func pct(_ b: Int64) -> String {
        let p = Double(b) / Double(catTotal) * 100
        return p >= 9.5 ? "\(Int(p.rounded()))%" : String(format: "%.1f%%", p)
    }
}
