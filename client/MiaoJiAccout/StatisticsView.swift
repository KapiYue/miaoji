import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var period = 0
    private var calendar: Calendar { .current }
    private var scopedRecords: [ExpenseRecord] { store.records.filter { $0.recordType == .expense && interval(containing: .now).contains($0.date) } }
    private var total: Double { scopedRecords.reduce(0) { $0 + $1.amount } }
    private var trend: [(String, Double)] {
        (0..<7).map { offset in
            let date: Date
            if period == 0 { date = calendar.date(byAdding: .month, value: offset - 6, to: .now)! }
            else if period == 1 { date = calendar.date(byAdding: .month, value: (offset - 6) * 3, to: .now)! }
            else { date = calendar.date(byAdding: .year, value: offset - 6, to: .now)! }
            let range = interval(containing: date)
            let sum = store.records.filter { $0.recordType == .expense && range.contains($0.date) }.reduce(0) { $0 + $1.amount }
            let year = calendar.component(.year, from: date)
            let label = period == 0 ? "\(calendar.component(.month, from: date))月" : period == 1 ? "\(String(year).suffix(2))年\((calendar.component(.month, from: date) - 1) / 3 + 1)季" : "\(year)年"
            return (label, sum)
        }
    }
    private var categoryTotals: [(ExpenseCategory, Double)] { store.categories.map { category in (category, scopedRecords.filter { $0.categoryID == category.id }.reduce(0) { $0 + $1.amount }) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 } }
    private func interval(containing date: Date) -> Range<Date> {
        if period == 0 { return calendar.dateInterval(of: .month, for: date)!.start..<calendar.dateInterval(of: .month, for: date)!.end }
        if period == 2 { return calendar.dateInterval(of: .year, for: date)!.start..<calendar.dateInterval(of: .year, for: date)!.end }
        let year = calendar.component(.year, from: date), month = calendar.component(.month, from: date), startMonth = ((month - 1) / 3) * 3 + 1
        let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1))!, end = calendar.date(byAdding: .month, value: 3, to: start)!
        return start..<end
    }
    private var periodName: String { ["本月", "本季度", "本年"][period] }
    private var previousScopedRecords: [ExpenseRecord] {
        let current = interval(containing: .now)
        let duration = current.upperBound.timeIntervalSince(current.lowerBound)
        let previous = current.lowerBound.addingTimeInterval(-duration)..<current.lowerBound
        return store.records.filter { $0.recordType == .expense && previous.contains($0.date) }
    }
    private var conclusions: [(String, String, String)] {
        guard !scopedRecords.isEmpty else { return [("暂无可分析记录", "添加几笔支出后，这里会自动生成消费结论。", "待积累")] }
        let previousTotal = previousScopedRecords.reduce(0) { $0 + $1.amount }
        let changeTitle: String
        let changeDetail: String
        let changeTag: String
        if previousTotal > 0 {
            let change = (total - previousTotal) / previousTotal * 100
            changeTitle = "支出较上个周期\(change >= 0 ? "上升" : "下降") \(abs(change).formatted(.number.precision(.fractionLength(1))))%"
            changeDetail = change > 0 ? "可重点检查增幅较高的消费分类。" : "当前支出节奏有所改善，请继续保持。"
            changeTag = change > 0 ? "关注" : "良好"
        } else {
            changeTitle = "已记录 \(scopedRecords.count) 笔支出"
            changeDetail = "上个周期暂无数据，暂时无法进行环比。"
            changeTag = "概览"
        }
        guard let top = categoryTotals.first else { return [(changeTitle, changeDetail, changeTag)] }
        let share = total == 0 ? 0 : top.1 / total * 100
        return [("\(top.0.name)是最大支出分类", "占\(periodName)支出的 \(share.formatted(.number.precision(.fractionLength(1))))%，可优先关注。", "重点"), (changeTitle, changeDetail, changeTag)]
    }
    var body: some View {
        Screen {
            Hero(eyebrow: "数据分析", title: "统计", subtitle: "用更少的图表，呈现更关键的消费变化。", pill: ["月度", "季度", "年度"][period], showsContainer: false) {
                SegmentedPicker(items: ["月", "季度", "年"], selection: $period)
            }
            MetricsRow(metrics: [("\(periodName)支出", store.format(total)), ("平均每笔", store.format(scopedRecords.isEmpty ? 0 : total / Double(scopedRecords.count))), ("记录数", "\(scopedRecords.count)")])
            GlassCard {
                VStack(spacing: 16) {
                    SectionHeading(title: "支出趋势", subtitle: "切换维度后，柱状高度会更新。", trailing: "趋势")
                    TrendChart(items: trend)
                }
            }
            GlassCard {
                VStack(spacing: 16) {
                    SectionHeading(title: "分类分布", subtitle: "用圆环图概括消费结构。", trailing: "占比")
                    DonutChart(items: categoryTotals.map { ($0.1, BadgeColor.from($0.0.colorIndex).colors[0]) }, total: store.format(total), subtitle: "\(periodName)总支出")
                    if scopedRecords.isEmpty { Text("该周期暂无记录。").font(.caption).foregroundStyle(Palette.muted) }
                    ForEach(categoryTotals, id: \.0.id) { category, amount in
                        ExpenseRow(badge: "", color: .from(category.colorIndex), title: category.name, meta: "\(scopedRecords.filter { $0.categoryID == category.id }.count) 笔 · 分类占比", amount: store.format(amount), note: total == 0 ? "0%" : "\((amount / total * 100).formatted(.number.precision(.fractionLength(1))))%")
                    }
                }
            }
            GlassCard {
                VStack(spacing: 14) {
                    SectionHeading(title: "关键结论", subtitle: "用摘要卡片快速理解消费变化。")
                    ForEach(Array(conclusions.enumerated()), id: \.offset) { _, conclusion in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conclusion.0).font(.system(size: 14, weight: .bold))
                                Text(conclusion.1).font(.system(size: 12)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 8)
                            Pill(conclusion.2)
                        }.softRow()
                    }
                }
            }
        }
    }
}

struct SegmentedPicker: View {
    let items: [String]
    @Binding var selection: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                Button(items[index]) { withAnimation(.easeOut(duration: 0.2)) { selection = index } }
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(selection == index ? Color(red: 8/255, green: 17/255, blue: 29/255) : Palette.muted)
                    .padding(.horizontal, 15).padding(.vertical, 9)
                    .background(selection == index ? AnyShapeStyle(LinearGradient(colors: [Palette.primary, Palette.accent.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }.padding(5).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line)).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrendChart: View {
    @EnvironmentObject private var store: AppStore
    let items: [(String, Double)]
    @State private var selectedIndex: Int?
    private var maximum: Double { max(items.map(\.1).max() ?? 0, 0.01) }
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(items.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    Text(store.format(items[index].1, decimals: false))
                        .font(.system(size: selectedIndex == index ? 11 : 9, weight: .bold))
                        .foregroundStyle(selectedIndex == index ? Palette.text : Palette.muted)
                        .lineLimit(1).minimumScaleFactor(0.55)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Palette.primary.opacity(0.9), Palette.accent.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(height: max(items[index].1 > 0 ? 8 : 0, geo.size.height * items[index].1 / maximum)).frame(maxHeight: .infinity, alignment: .bottom)
                            .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.38)
                    }.frame(height: 150)
                    Text(items[index].0).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selectedIndex = selectedIndex == index ? nil : index } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(items[index].0)支出\(store.format(items[index].1))")
                .accessibilityHint("轻点以突出显示此柱状图")
            }
        }.animation(.easeInOut(duration: 0.3), value: items.map(\.1))
        .onChange(of: items.map(\.1)) { _, _ in selectedIndex = nil }
    }
}

struct DonutChart: View {
    let items: [(Double, Color)]
    let total: String
    let subtitle: String
    private var sum: Double { items.reduce(0) { $0 + $1.0 } }
    private var segments: [(Double, Color)] { sum == 0 ? [(1, Palette.line)] : items.map { ($0.0 / sum, $0.1) } }
    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                Circle().trim(from: start(index), to: start(index) + segments[index].0).stroke(segments[index].1, style: StrokeStyle(lineWidth: 28, lineCap: .butt)).rotationEffect(.degrees(-90))
            }
            VStack(spacing: 3) { Text(total).font(.system(size: 21, weight: .bold)).minimumScaleFactor(0.7); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }
        }.frame(width: 158, height: 158).padding(.vertical, 6)
    }
    private func start(_ index: Int) -> Double { segments.prefix(index).reduce(0) { $0 + $1.0 } }
}

struct InsightRow: View {
    let title: String, subtitle: String, tag: String
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 14, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill(tag) }
            .padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    }
}


