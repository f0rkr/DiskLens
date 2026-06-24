import SwiftUI
import Charts

struct OverviewView: View {
    let insights: ScanInsights

    private var catTotal: Int64 { max(1, insights.categories.reduce(0) { $0 + $1.bytes }) }
    private var maxTop: Int64 { insights.topItems.first?.size ?? 1 }

    var body: some View {
        Group {
            if insights.totalFiles == 0 {
                ContentUnavailableView("Nothing to chart", systemImage: "chart.pie",
                                       description: Text("This folder has no files to summarize."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        hero
                        byType
                        largest
                    }
                    .padding(22)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Overview")
    }

    // MARK: hero — big total + colorful stacked usage bar
    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(ByteFormat.string(insights.totalBytes))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.brand, .brand2], startPoint: .leading, endPoint: .trailing))
                Text("· \(insights.totalFiles.formatted()) files")
                    .font(.title3).foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(insights.categories) { c in
                        Rectangle().fill(c.color)
                            .frame(width: max(3, g.size.width * CGFloat(c.bytes) / CGFloat(catTotal)))
                    }
                }
            }
            .frame(height: 18)
            .clipShape(Capsule())
            HStack(spacing: 16) {
                ForEach(insights.categories.prefix(5)) { c in
                    HStack(spacing: 6) {
                        Circle().fill(c.color).frame(width: 9, height: 9)
                        Text(c.label).font(.caption)
                        Text(pct(c.bytes)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    // MARK: by type — donut + legend
    private var byType: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage by type").font(.headline)
            HStack(alignment: .center, spacing: 28) {
                Chart(insights.categories) { c in
                    SectorMark(angle: .value("Size", Double(c.bytes)), innerRadius: .ratio(0.64), angularInset: 2)
                        .cornerRadius(4)
                        .foregroundStyle(c.color)
                }
                .frame(width: 200, height: 200)
                .overlay {
                    VStack(spacing: 2) {
                        Text("\(insights.categories.count)").font(.title.bold())
                        Text("types").font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 11) {
                    ForEach(insights.categories) { c in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3).fill(c.color).frame(width: 12, height: 12)
                            Text(c.label)
                            Spacer(minLength: 16)
                            Text(pct(c.bytes)).foregroundStyle(.secondary).monospacedDigit()
                            Text(ByteFormat.string(c.bytes)).frame(width: 80, alignment: .trailing).monospacedDigit()
                        }
                        .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    // MARK: largest items — list with gradient bars
    private var largest: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Largest items").font(.headline)
            VStack(spacing: 11) {
                ForEach(insights.topItems) { item in
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
                            .foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func pct(_ b: Int64) -> String {
        let p = Double(b) / Double(catTotal) * 100
        return p >= 9.5 ? "\(Int(p.rounded()))%" : String(format: "%.1f%%", p)
    }
}
