import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sheet: EntrySheet?
    private var monthRecords: [ExpenseRecord] { store.records.filter { $0.recordType == .expense && Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) } }
    private var previousMonthRecords: [ExpenseRecord] {
        let date = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        return store.records.filter { $0.recordType == .expense && Calendar.current.isDate($0.date, equalTo: date, toGranularity: .month) }
    }
    private var todayRecords: [ExpenseRecord] { store.records.filter { $0.recordType == .expense && Calendar.current.isDateInToday($0.date) } }
    private var recentRecords: [ExpenseRecord] { Array(store.records.sorted(by: { $0.date > $1.date }).prefix(5)) }
    private var monthTotal: Double { monthRecords.reduce(0) { $0 + $1.amount } }
    private var previousMonthTotal: Double { previousMonthRecords.reduce(0) { $0 + $1.amount } }
    private var comparisonText: String {
        guard previousMonthTotal > 0 else { return "较上月暂无可比数据" }
        let change = (monthTotal - previousMonthTotal) / previousMonthTotal * 100
        return "较上月 \(change >= 0 ? "+" : "")\(change.formatted(.number.precision(.fractionLength(1))))%"
    }
    private var topTodayCategory: String {
        let grouped = Dictionary(grouping: todayRecords, by: \.categoryID).mapValues { $0.reduce(0) { $0 + $1.amount } }
        guard let id = grouped.max(by: { $0.value < $1.value })?.key else { return "暂无" }
        return store.category(for: id)?.name ?? "未分类"
    }
    var body: some View {
        Screen {
            Hero(eyebrow: "每日记录", title: "记账", subtitle: "语音优先，手动补录，减少记录成本。", pill: "今天", showsContainer: false) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("本月支出").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        Text(store.format(monthTotal)).font(.system(size: 40, weight: .heavy)).tracking(-1)
                        Text("\(comparisonText)，预算执行率 \(Int(monthTotal / max(store.monthlyBudget, 0.01) * 100))%。").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    ActionCard(icon: "mic.fill", title: "语音输入", text: "长按录音，自动识别金额和分类。", colors: [Palette.voiceActionTop, Palette.voiceActionBottom]) { sheet = .voice }
                    ActionCard(icon: "square.and.pencil", title: "手动输入", text: "快速补录，适合补充备注和时间。", colors: [Palette.manualActionTop, Palette.manualActionBottom]) { sheet = .manual }
                }
            }
            VStack(spacing: 12) {
                SectionHeading(title: "今日概览", subtitle: "\(todayRecords.count) 笔支出，\(topTodayCategory)占比最高。")
                MetricsRow(metrics: [("总支出", store.format(todayRecords.reduce(0) { $0 + $1.amount })), ("最大一笔", store.format(todayRecords.map(\.amount).max() ?? 0)), ("高频分类", topTodayCategory)])
            }
            VStack(spacing: 12) {
                SectionHeading(title: "最近记录", subtitle: "按时间从新到旧排列。")
                if store.records.isEmpty { Text("暂无记录，点击手动输入添加第一笔支出。").font(.caption).foregroundStyle(Palette.muted).softRow() }
                ForEach(recentRecords.indices, id: \.self) { index in
                    let record = recentRecords[index]
                    let isOldYear = !Calendar.current.isDate(record.date, equalTo: .now, toGranularity: .year)
                    let startsOldDay = isOldYear && (index == 0 || !Calendar.current.isDate(record.date, inSameDayAs: recentRecords[index - 1].date))
                    if startsOldDay {
                        let sameDay = store.records.filter { Calendar.current.isDate($0.date, inSameDayAs: record.date) }
                        HStack { VStack(alignment: .leading, spacing: 3) { Text(store.formatDate(record.date)).font(.system(size: 15, weight: .bold)); Text(store.formatWeekday(record.date)).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); VStack(alignment: .trailing) { Text(store.format(sameDay.reduce(0) { $0 + ($1.recordType == .income ? -$1.amount : $1.amount) })).bold(); Text("\(sameDay.count) 笔").font(.caption).foregroundStyle(Palette.muted) } }.softRow()
                    }
                    RecordRow(record: record, showsFullDate: isOldYear)
                }
            }
            GlassCard {
                VStack(spacing: 14) {
                    let budgeted = store.categories.compactMap { category -> (ExpenseCategory, Double)? in guard let budget = category.budget, budget > 0 else { return nil }; return (category, budget) }
                    let highest = budgeted.map { item in (item.0, monthRecords.filter { $0.categoryID == item.0.id }.reduce(0) { $0 + $1.amount } / item.1) }.max { $0.1 < $1.1 }
                    SectionHeading(title: "预算提醒", subtitle: highest.map { "本月\($0.0.name)预算已使用 \(Int($0.1 * 100))%。" } ?? "在分类管理中设置分类预算。", trailing: (highest?.1 ?? 0) > 1 ? "已超支" : "正常")
                    ForEach(Array(budgeted.prefix(3)), id: \.0.id) { category, budget in
                        let spent = monthRecords.filter { $0.categoryID == category.id }.reduce(0) { $0 + $1.amount }
                        ProgressLine(title: category.name, value: spent / budget)
                    }
                }
            }
        }
        .fullScreenCover(item: $sheet) { type in EntrySheetView(type: type) }
    }
}
