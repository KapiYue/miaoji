import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""
    @State private var showFilters = false
    @State private var selectedCategory: UUID?
    @State private var minimumAmount = ""
    @State private var editingRecord: ExpenseRecord?
    @State private var dateScope = 0
    private var filtered: [ExpenseRecord] {
        store.records.filter { record in
            let category = store.category(for: record.categoryID)?.name ?? ""
            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesText = query.isEmpty || record.title.localizedCaseInsensitiveContains(query) || record.note.localizedCaseInsensitiveContains(query) || category.localizedCaseInsensitiveContains(query)
            let matchesCategory = selectedCategory == nil || record.categoryID == selectedCategory
            let matchesAmount = Double(minimumAmount).map { record.amount >= $0 } ?? true
            let matchesDate = dateScope == 0 || (dateScope == 1 && Calendar.current.isDateInToday(record.date)) || (dateScope == 2 && Calendar.current.isDate(record.date, equalTo: .now, toGranularity: .weekOfYear))
            return matchesText && matchesCategory && matchesAmount && matchesDate
        }.sorted { $0.date > $1.date }
    }
    private var grouped: [(Date, [ExpenseRecord])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }.map { ($0.key, $0.value.sorted { $0.date > $1.date }) }.sorted { $0.0 > $1.0 }
    }
    private var peakHour: String {
        let counts = Dictionary(grouping: filtered, by: { Calendar.current.component(.hour, from: $0.date) }).mapValues(\.count)
        guard let hour = counts.max(by: { $0.value < $1.value })?.key else { return "暂无" }
        return String(format: "%02d:00", hour)
    }
    private var mostFrequentCategory: String {
        let counts = Dictionary(grouping: filtered, by: \.categoryID).mapValues(\.count)
        guard let id = counts.max(by: { $0.value < $1.value })?.key else { return "暂无" }
        return store.category(for: id)?.name ?? "未分类"
    }
    private var averageDailyCount: String {
        guard !grouped.isEmpty else { return "0 笔" }
        return "\((Double(filtered.count) / Double(grouped.count)).formatted(.number.precision(.fractionLength(1)))) 笔"
    }
    var body: some View {
        Screen {
            Hero(eyebrow: "时间线", title: "历史", subtitle: "按日期聚合，重点记录一眼可扫。", pill: "筛选") {
                HStack(spacing: 10) {
                    TextField("搜索标题、分类、备注...", text: $search).padding(13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                    Button("筛选") { showFilters = true }.buttonStyle(GradientButtonStyle(compact: true))
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "快捷筛选", subtitle: "分类和金额段。")
                    HStack { Button("今天") { dateScope = 1 }.buttonStyle(SoftButtonStyle()); Button("本周") { dateScope = 2 }.buttonStyle(SoftButtonStyle()); if let first = store.categories.first { Button(first.name) { selectedCategory = first.id }.buttonStyle(SoftButtonStyle()) } }
                    HStack { Button("大于 100") { minimumAmount = "100" }.buttonStyle(SoftButtonStyle()); Button("清除") { dateScope = 0; selectedCategory = nil; minimumAmount = "" }.buttonStyle(SoftButtonStyle()) }
                }
            }
            if grouped.isEmpty { Text(search.isEmpty ? "暂无本地记录。" : "没有匹配的记录。").foregroundStyle(Palette.muted).softRow() }
            ForEach(grouped, id: \.0) { day, records in
                VStack(spacing: 12) {
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) { Text(dayTitle(day)).font(.title3.bold()); Text("\(store.formatDate(day)) · \(store.formatWeekday(day))").font(.caption).foregroundStyle(Palette.muted) }
                            Spacer(); VStack(alignment: .trailing, spacing: 3) { Text(store.format(records.reduce(0) { $0 + ($1.recordType == .income ? -$1.amount : $1.amount) })).font(.system(size: 16, weight: .bold)); Text("\(records.count) 笔").font(.caption).foregroundStyle(Palette.muted) }
                        }
                    }
                    ForEach(records) { record in Button { editingRecord = record } label: { RecordRow(record: record, showsFullDate: !Calendar.current.isDate(record.date, equalTo: .now, toGranularity: .year)) }.buttonStyle(.plain) }
                }
            }
            GlassCard {
                VStack(spacing: 14) {
                    SectionHeading(title: "记录密度", subtitle: "帮助快速发现高频记录习惯。", trailing: "密度")
                    MetricsRow(metrics: [("高峰时段", peakHour), ("最多分类", mostFrequentCategory), ("日均记录", averageDailyCount)])
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                Form {
                    Picker("日期", selection: $dateScope) { Text("全部日期").tag(0); Text("今天").tag(1); Text("本周").tag(2) }
                    Picker("分类", selection: $selectedCategory) {
                        Text("全部分类").tag(UUID?.none)
                        ForEach(store.categories) { Text($0.name).tag(Optional($0.id)) }
                    }
                    HStack { Text(store.currency.symbol).foregroundStyle(.secondary); TextField("最低金额（\(store.currency.name)）", text: $minimumAmount).keyboardType(.decimalPad) }
                    Button("清除筛选") { dateScope = 0; selectedCategory = nil; minimumAmount = "" }
                }.navigationTitle("筛选记录").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showFilters = false } } }
            }.presentationDetents([.medium])
        }
        .fullScreenCover(item: $editingRecord) { EntrySheetView(type: .edit($0)) }
    }
    private func dayTitle(_ date: Date) -> String { if Calendar.current.isDateInToday(date) { return "今天" }; if Calendar.current.isDateInYesterday(date) { return "昨天" }; return store.formatDate(date) }
}

struct FlowPills: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) { ForEach(items.prefix(4), id: \.self) { Pill($0, primary: $0 == items.first) } }
            if items.count > 4 { Pill(items[4]) }
        }
    }
}

struct HistoryGroup: View {
    typealias Row = (String, BadgeColor, String, String, String, String)
    let day: String, date: String, total: String, count: String
    let rows: [Row]
    var body: some View {
        VStack(spacing: 12) {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text(day).font(.title3.bold()); Text(date).font(.caption).foregroundStyle(Palette.muted) }
                    Spacer(); VStack(alignment: .trailing, spacing: 3) { Text(total).font(.system(size: 16, weight: .bold)); Text(count).font(.caption).foregroundStyle(Palette.muted) }
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                ExpenseRow(badge: row.0, color: row.1, title: row.2, meta: row.3, amount: row.4, note: row.5)
            }
        }
    }
}


