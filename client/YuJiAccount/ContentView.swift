import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selection: AppTab = .home
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch selection {
                case .home: HomeView()
                case .statistics: StatisticsView()
                case .history: HistoryView()
                case .settings: SettingsView(isDarkMode: $isDarkMode)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $selection)
        }
        .tint(Palette.primary)
    }
}

private enum AppTab: CaseIterable {
    case home, statistics, history, settings

    var title: String {
        switch self {
        case .home: "记账"
        case .statistics: "统计"
        case .history: "历史"
        case .settings: "设置"
        }
    }
}

private enum Palette {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static let background = adaptive(light: UIColor(red: 255/255, green: 238/255, blue: 207/255, alpha: 1), dark: UIColor(red: 7/255, green: 17/255, blue: 31/255, alpha: 1))
    static let backgroundMiddle = adaptive(light: UIColor(red: 255/255, green: 211/255, blue: 192/255, alpha: 1), dark: UIColor(red: 13/255, green: 27/255, blue: 47/255, alpha: 1))
    static let background2 = adaptive(light: UIColor(red: 252/255, green: 194/255, blue: 201/255, alpha: 1), dark: UIColor(red: 20/255, green: 37/255, blue: 62/255, alpha: 1))
    static let text = adaptive(light: UIColor(red: 20/255, green: 32/255, blue: 48/255, alpha: 1), dark: UIColor(red: 244/255, green: 247/255, blue: 251/255, alpha: 1))
    static let muted = adaptive(light: UIColor(red: 90/255, green: 107/255, blue: 128/255, alpha: 1), dark: UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1))
    static let surfaceTop = adaptive(light: UIColor(red: 255/255, green: 251/255, blue: 247/255, alpha: 1), dark: UIColor(red: 18/255, green: 28/255, blue: 46/255, alpha: 1))
    static let surfaceBottom = adaptive(light: UIColor(red: 255/255, green: 244/255, blue: 244/255, alpha: 1), dark: UIColor(red: 10/255, green: 18/255, blue: 31/255, alpha: 1))
    static let soft = adaptive(light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.68), dark: UIColor(white: 1, alpha: 0.04))
    static let line = adaptive(light: UIColor(red: 156/255, green: 91/255, blue: 88/255, alpha: 0.13), dark: UIColor(white: 1, alpha: 0.08))
    static let primary = Color(red: 125/255, green: 211/255, blue: 252/255)
    static let accent = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let success = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let pink = Color(red: 251/255, green: 113/255, blue: 133/255)
    static let voiceActionTop = adaptive(light: UIColor(red: 103/255, green: 118/255, blue: 226/255, alpha: 1), dark: UIColor(red: 20/255, green: 36/255, blue: 61/255, alpha: 1))
    static let voiceActionBottom = adaptive(light: UIColor(red: 119/255, green: 73/255, blue: 180/255, alpha: 1), dark: UIColor(red: 18/255, green: 61/255, blue: 80/255, alpha: 1))
    static let manualActionTop = adaptive(light: UIColor(red: 226/255, green: 112/255, blue: 222/255, alpha: 1), dark: UIColor(red: 54/255, green: 24/255, blue: 50/255, alpha: 1))
    static let manualActionBottom = adaptive(light: UIColor(red: 247/255, green: 79/255, blue: 128/255, alpha: 1), dark: UIColor(red: 84/255, green: 31/255, blue: 50/255, alpha: 1))
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.background, Palette.backgroundMiddle, Palette.background2], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.primary.opacity(0.14)).frame(width: 330, height: 330).blur(radius: 60).offset(x: 170, y: -360)
            Circle().fill(Palette.accent.opacity(0.18)).frame(width: 330, height: 330).blur(radius: 70).offset(x: -170, y: 390)
            Circle().fill(Palette.pink.opacity(0.12)).frame(width: 260, height: 260).blur(radius: 70).offset(x: -190, y: 90)
        }
        .ignoresSafeArea()
    }
}

private struct Screen<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) { content }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct Hero<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let pill: String
    var showsContainer = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(showsContainer ? 18 : 0)
        .background {
            if showsContainer {
                ZStack {
                    LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom)
                    Circle().fill(Palette.primary.opacity(0.15)).frame(width: 170).blur(radius: 24).offset(x: -150, y: -100)
                    Circle().fill(Palette.accent.opacity(0.13)).frame(width: 220).blur(radius: 28).offset(x: 150, y: 130)
                }.clipShape(RoundedRectangle(cornerRadius: 34))
            }
        }
        .overlay { if showsContainer { RoundedRectangle(cornerRadius: 34).stroke(Palette.line) } }
        .shadow(color: .black.opacity(showsContainer ? 0.35 : 0), radius: 30, y: 16)
    }
}

private struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(padding)
            .background(LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.line))
            .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

private struct SectionHeading: View {
    let title: String
    let subtitle: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if let trailing { Pill(trailing) }
        }
    }
}

private struct Pill: View {
    let text: String
    var primary: Bool = false
    init(_ text: String, primary: Bool = false) { self.text = text; self.primary = primary }
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.text.opacity(0.92))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(primary ? Palette.primary.opacity(0.14) : Palette.soft)
            .clipShape(Capsule()).overlay(Capsule().stroke(Palette.line))
    }
}

private struct MetricsRow: View {
    let metrics: [(String, String)]
    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.0).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Text(metric.1).font(.system(size: 16, weight: .bold)).lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 13)
                .background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
            }
        }
    }
}

private enum BadgeColor { case blue, green, purple, amber, pink, cyan
    static func from(_ index: Int) -> BadgeColor { [.blue, .green, .purple, .amber, .pink, .cyan][abs(index) % 6] }
    var colors: [Color] {
        switch self {
        case .blue: [Color(red: 56/255, green: 189/255, blue: 248/255), Color(red: 37/255, green: 99/255, blue: 235/255)]
        case .green: [Palette.success, Color(red: 5/255, green: 150/255, blue: 105/255)]
        case .purple: [Color(red: 167/255, green: 139/255, blue: 250/255), Color(red: 124/255, green: 58/255, blue: 237/255)]
        case .amber: [Palette.accent, Color(red: 249/255, green: 115/255, blue: 22/255)]
        case .pink: [Palette.pink, Color(red: 190/255, green: 24/255, blue: 93/255)]
        case .cyan: [Color(red: 34/255, green: 211/255, blue: 238/255), Color(red: 15/255, green: 118/255, blue: 110/255)]
        }
    }
}

private struct Badge: View {
    let text: String
    let color: BadgeColor
    var size: CGFloat = 42
    var body: some View {
        Text(text).font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(.white).frame(width: size, height: size)
            .background(LinearGradient(colors: color.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: size / 3))
    }
}

private struct ExpenseRow: View {
    let badge: String
    let color: BadgeColor
    let title: String
    let meta: String
    let amount: String
    let note: String
    var body: some View {
        HStack(spacing: 12) {
            Badge(text: badge, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(meta).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount).font(.system(size: 16, weight: .bold))
                Text(note).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
        }
        .padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    }
}

private struct HomeView: View {
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
        .sheet(item: $sheet) { type in EntrySheetView(type: type) }
    }
}

private enum EntrySheet: Identifiable, Hashable { case voice, manual, edit(ExpenseRecord); var id: String { switch self { case .voice: "voice"; case .manual: "manual"; case .edit(let record): record.id.uuidString } } }

private struct ActionCard: View {
    let icon: String, title: String, text: String, colors: [Color]
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).frame(width: 42, height: 42).background(.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 14))
                Text(title).font(.system(size: 16, weight: .bold))
                Text(text).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.78)).multilineTextAlignment(.center)
            }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 122, alignment: .center).padding(16)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08)))
        }.buttonStyle(.plain)
    }
}

private struct ProgressLine: View {
    let title: String, value: Double
    var body: some View {
        VStack(spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int(value * 100))%") }.font(.system(size: 12)).foregroundStyle(Palette.muted)
            GeometryReader { geo in
                Capsule().fill(Palette.line).overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }.frame(height: 10)
        }
    }
}

private struct EntrySheetView: View {
    @EnvironmentObject private var store: AppStore
    let type: EntrySheet
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var title: String
    @State private var note: String
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var recordType: RecordType
    @State private var showsDateEditor = false
    init(type: EntrySheet) {
        self.type = type
        if case .edit(let record) = type {
            _amount = State(initialValue: String(format: "%.2f", record.amount)); _title = State(initialValue: record.title); _note = State(initialValue: record.note); _categoryID = State(initialValue: record.categoryID); _date = State(initialValue: record.date); _recordType = State(initialValue: record.recordType)
        } else {
            _amount = State(initialValue: ""); _title = State(initialValue: ""); _note = State(initialValue: ""); _categoryID = State(initialValue: nil); _date = State(initialValue: .now); _recordType = State(initialValue: .expense)
        }
    }
    private var isVoice: Bool { if case .voice = type { true } else { false } }
    private var editingRecord: ExpenseRecord? { if case .edit(let record) = type { record } else { nil } }
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isVoice ? "语音输入" : editingRecord == nil ? "添加支出" : "编辑支出").font(.title3.bold())
                        Text(isVoice ? "长按开始录音，松开发送识别结果。" : "保留完整金额、分类、时间和备注字段。").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(); Button("关闭") { dismiss() }.buttonStyle(SoftButtonStyle())
                }
                if isVoice {
                    GlassCard {
                        VStack(spacing: 16) { Badge(text: "语", color: .cyan, size: 84); Text("识别示例：午餐 45 元，餐饮，12:30").font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    Button("开始录音") { }.buttonStyle(GradientButtonStyle())
                } else {
                    if editingRecord != nil {
                        Picker("类型", selection: $recordType) { ForEach(RecordType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    }
                    DarkField(label: "金额", placeholder: "0.00", text: $amount, keyboard: .decimalPad)
                    DarkField(label: "标题", placeholder: "例如：午餐 / 咖啡 / 打车", text: $title)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类").font(.caption).foregroundStyle(Palette.muted)
                        Menu {
                            ForEach(store.categories) { category in
                                Button {
                                    categoryID = category.id
                                } label: {
                                    if categoryID == category.id {
                                        Label(category.name, systemImage: "checkmark")
                                    } else {
                                        Text(category.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(categoryID.flatMap { store.category(for: $0)?.name } ?? "请选择分类")
                                    .foregroundStyle(categoryID == nil ? Palette.muted : Palette.text)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Palette.muted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 13).frame(maxWidth: .infinity).frame(height: 48)
                        .background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("时间").font(.caption).foregroundStyle(Palette.muted)
                        Button { showsDateEditor = true } label: {
                            HStack {
                                Text(Self.dateTimeFormatter.string(from: date)).foregroundStyle(Palette.text)
                                Spacer()
                                Image(systemName: "calendar.badge.clock").foregroundStyle(Palette.muted)
                            }.contentShape(Rectangle())
                        }
                            .buttonStyle(.plain).padding(.horizontal, 13).frame(height: 48)
                            .background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                    }
                    DarkTextEditor(label: "备注", placeholder: "可选：商户、地点或付款方式", text: $note)
                    HStack(spacing: 12) {
                        Button("取消") { dismiss() }.buttonStyle(SoftButtonStyle(fullWidth: true))
                        Button("保存", action: save).buttonStyle(GradientButtonStyle())
                            .disabled(!canSave).opacity(canSave ? 1 : 0.55)
                    }
                }
                Spacer()
            }
            .padding(18).padding(.top, 12).frame(maxWidth: 430)
            .background(LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Palette.line))
            .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
            .padding(18)
        }
        .presentationDetents(isVoice ? [.medium] : [.height(editingRecord == nil ? 660 : 710)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .sheet(isPresented: $showsDateEditor) { DateTimeEditor(date: $date) }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var canSave: Bool {
        guard let value = Double(amount), value > 0 else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && categoryID != nil
    }

    private func save() {
        guard canSave, let value = Double(amount), let categoryID else { return }
        if let editingRecord, let index = store.records.firstIndex(where: { $0.id == editingRecord.id }) {
            store.records[index] = ExpenseRecord(id: editingRecord.id, amount: value, title: title, note: note, categoryID: categoryID, date: date, type: recordType)
        } else {
            store.records.append(ExpenseRecord(amount: value, title: title, note: note, categoryID: categoryID, date: date, type: .expense))
        }
        dismiss()
    }
}

private struct DateTimeEditor: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar.current

    private var hour: Binding<Int> { componentBinding(.hour) }
    private var minute: Binding<Int> { componentBinding(.minute) }
    private var second: Binding<Int> { componentBinding(.second) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                HStack(spacing: 8) {
                    timeColumn("时", selection: hour, range: 0..<24)
                    Text(":").font(.title2.bold()).padding(.top, 8)
                    timeColumn("分", selection: minute, range: 0..<60)
                    Text(":").font(.title2.bold()).padding(.top, 8)
                    timeColumn("秒", selection: second, range: 0..<60)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .navigationTitle("选择日期和时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func timeColumn(_ title: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity, maxHeight: 120).clipped()
        }
    }

    private func componentBinding(_ component: Calendar.Component) -> Binding<Int> {
        Binding(
            get: { calendar.component(component, from: date) },
            set: { value in
                if let updated = calendar.date(bySetting: component, value: value, of: date) { date = updated }
            }
        )
    }
}

private struct RecordRow: View {
    @EnvironmentObject private var store: AppStore
    let record: ExpenseRecord
    var showsFullDate = false
    var body: some View {
        let category = store.category(for: record.categoryID)
        ExpenseRow(badge: String(category?.name.prefix(1) ?? "?"), color: record.recordType == .income ? .green : BadgeColor.from(category?.colorIndex ?? 0), title: record.title, meta: "\(store.formatDate(record.date, dateStyle: showsFullDate ? .short : .none, timeStyle: .short)) · \(record.recordType.rawValue) · \(category?.name ?? "未分类")", amount: (record.recordType == .income ? "+" : "") + store.format(record.amount), note: record.note.isEmpty ? "本地" : record.note)
    }
}

private struct DarkField: View {
    let label: String, placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            TextField(placeholder, text: $text).keyboardType(keyboard).padding(13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        }
    }
}

private struct DarkTextEditor: View {
    let label: String, placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            ZStack(alignment: .topLeading) {
                if text.isEmpty { Text(placeholder).foregroundStyle(Palette.muted).padding(.horizontal, 4).padding(.vertical, 8).allowsHitTesting(false) }
                TextEditor(text: $text).scrollContentBackground(.hidden).frame(minHeight: 72, maxHeight: 72)
            }
            .padding(.horizontal, 9).padding(.vertical, 5).background(Palette.soft)
            .clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        }
    }
}

private struct HistoryView: View {
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
        .sheet(item: $editingRecord) { EntrySheetView(type: .edit($0)) }
    }
    private func dayTitle(_ date: Date) -> String { if Calendar.current.isDateInToday(date) { return "今天" }; if Calendar.current.isDateInYesterday(date) { return "昨天" }; return store.formatDate(date) }
}

private struct FlowPills: View {
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) { ForEach(items.prefix(4), id: \.self) { Pill($0, primary: $0 == items.first) } }
            if items.count > 4 { Pill(items[4]) }
        }
    }
}

private struct HistoryGroup: View {
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

private struct StatisticsView: View {
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

private struct SegmentedPicker: View {
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

private struct TrendChart: View {
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

private struct DonutChart: View {
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

private struct InsightRow: View {
    let title: String, subtitle: String, tag: String
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 14, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill(tag) }
            .padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var isDarkMode: Bool
    @State private var showCurrency = false
    @State private var editingCategory: ExpenseCategory?
    @State private var exporting = false
    @State private var showClearConfirmation = false
    @State private var aboutPage: AboutPage?
    var body: some View {
        Screen {
            Hero(eyebrow: "系统设置", title: "设置", subtitle: "管理货币、分类、同步和隐私。", pill: "个人", showsContainer: false) {
                GlassCard {
                    HStack(spacing: 14) { Badge(text: "清", color: .cyan, size: 56); VStack(alignment: .leading, spacing: 4) { Text("清眸").font(.system(size: 18, weight: .heavy)); Text("语音记账专业版 · 已同步到本地库").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill("专业版") }
                }
            }
            SettingsCard(title: "货币", subtitle: "支持多币种和显示格式切换。") {
                Button { showCurrency = true } label: { HStack { Badge(text: store.currency.symbol, color: .blue); VStack(alignment: .leading, spacing: 3) { Text(store.currency.name).font(.system(size: 15, weight: .bold)); Text("\(store.currency.code) · 当前使用").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.muted) }.softRow() }.buttonStyle(.plain)
            }
            SettingsCard(title: "常用选项", subtitle: "使用开关控制自动化和体验偏好。") {
                ToggleRow(title: "语音自动识别", subtitle: "录音后自动生成金额、标题和分类。", isOn: $store.voiceRecognition)
                ToggleRow(title: "深色主题", subtitle: "关闭后切换为明亮主题。", isOn: $isDarkMode)
                ToggleRow(title: "每日预算提醒", subtitle: "当支出接近上限时进行提示。", isOn: $store.budgetReminder)
                HStack { VStack(alignment: .leading, spacing: 4) { Text("每月总预算").font(.system(size: 14, weight: .bold)); Text("用于首页预算执行率核算").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Text(store.currency.symbol).foregroundStyle(Palette.muted); TextField("0", value: $store.monthlyBudget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100) }.softRow()
            }
            SettingsCard(title: "分类管理", subtitle: "按颜色和图标区分消费语义。") {
                ForEach(store.categories) { category in
                    Button { editingCategory = category } label: { ManageRow(icon: category.icon, color: .from(category.colorIndex), title: category.name, subtitle: "\(store.records.filter { $0.categoryID == category.id }.count) 笔记录") }.buttonStyle(.plain)
                }
                Button("添加新分类") { editingCategory = ExpenseCategory(name: "", icon: "tag.fill", colorIndex: 0) }.buttonStyle(SoftButtonStyle(fullWidth: true))
            }
            SettingsCard(title: "数据与隐私", subtitle: "导出、备份和清除数据的高风险操作应清晰区分。") {
                Button("导出 CSV") { exporting = true }.buttonStyle(GradientButtonStyle())
                Button("同步到 iCloud") { }.buttonStyle(SoftButtonStyle(fullWidth: true))
                Button("清除全部数据") { showClearConfirmation = true }.buttonStyle(DangerButtonStyle())
            }
            SettingsCard(title: "关于", subtitle: "版本信息、隐私和服务协议。") {
                Button { aboutPage = .version } label: { AboutRow(title: "版本", subtitle: "语音记账 v2.0") }.buttonStyle(.plain)
                Button { aboutPage = .privacy } label: { AboutRow(title: "隐私政策", subtitle: "查看数据收集和存储说明") }.buttonStyle(.plain)
                Button { aboutPage = .agreement } label: { AboutRow(title: "用户协议", subtitle: "查看使用条款") }.buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showCurrency) { CurrencyPicker() }
        .sheet(item: $editingCategory) { CategoryEditor(category: $0) }
        .sheet(item: $aboutPage) { AboutDetail(page: $0) }
        .fileExporter(isPresented: $exporting, document: CSVDocument(data: store.csvData(isDarkMode: isDarkMode)), contentType: .commaSeparatedText, defaultFilename: "voice-account-\(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
        .confirmationDialog("确定清除全部本地记录？", isPresented: $showClearConfirmation, titleVisibility: .visible) { Button("清除全部数据", role: .destructive) { store.records.removeAll() }; Button("取消", role: .cancel) {} }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String, subtitle: String
    @ViewBuilder let content: Content
    var body: some View { GlassCard { VStack(spacing: 12) { SectionHeading(title: title, subtitle: subtitle); content } } }
}

private struct ToggleRow: View {
    let title: String, subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 14, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }; Spacer(); Toggle("", isOn: $isOn).labelsHidden() }.softRow()
    }
}

private struct ManageRow: View {
    let icon: String, color: BadgeColor, title: String, subtitle: String
    var body: some View { HStack { Image(systemName: icon).foregroundStyle(.white).frame(width: 42, height: 42).background(LinearGradient(colors: color.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.muted) }.softRow() }
}

private struct AboutRow: View {
    let title: String, subtitle: String
    var body: some View { HStack { VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer() }.softRow() }
}

private struct CurrencyPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List(AppCurrency.allCases) { currency in Button { store.currency = currency; dismiss() } label: { HStack { Text(currency.symbol).frame(width: 32); Text(currency.name); Spacer(); Text(currency.code).foregroundStyle(.secondary); if store.currency == currency { Image(systemName: "checkmark") } } } }.navigationTitle("选择货币").toolbar { Button("关闭") { dismiss() } } } }
}

private struct CategoryEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var category: ExpenseCategory
    private let icons = ["fork.knife", "tram.fill", "bag.fill", "cart.fill", "house.fill", "gamecontroller.fill", "heart.fill", "book.fill", "tag.fill", "ellipsis.circle.fill"]
    var body: some View {
        NavigationStack { Form {
            TextField("分类名称", text: $category.name)
            HStack { Text(store.currency.symbol).foregroundStyle(.secondary); TextField("每月分类预算（\(store.currency.name)）", value: $category.budget, format: .number).keyboardType(.decimalPad) }
            Section("选择图标") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(icons, id: \.self) { icon in
                        Button { category.icon = icon } label: {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .contentShape(Rectangle())
                                .background(category.icon == icon ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("图标背景色") {
                HStack(spacing: 12) {
                    ForEach(0..<6) { index in
                        Button { category.colorIndex = index } label: {
                            Circle()
                                .fill(LinearGradient(colors: BadgeColor.from(index).colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .contentShape(Circle())
                                .overlay { if category.colorIndex == index { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) } }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }.navigationTitle(category.name.isEmpty ? "新分类" : "编辑分类").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { guard !category.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; if let index = store.categories.firstIndex(where: { $0.id == category.id }) { store.categories[index] = category } else { store.categories.append(category) }; dismiss() } } } }
    }
}

private enum AboutPage: String, Identifiable { case version = "版本", privacy = "隐私政策", agreement = "用户协议"; var id: String { rawValue } }
private struct AboutDetail: View {
    let page: AboutPage
    @Environment(\.dismiss) private var dismiss
    var text: String { switch page { case .version: "语音记账 v2.0\n数据保存在本机。"; case .privacy: "所有账目、分类和设置均保存在设备本地。应用不会主动上传或出售个人数据。导出文件由用户自行保管。"; case .agreement: "使用本应用即表示你同意自行核对记账信息。应用提供记录与统计工具，不构成财务建议。" } }
    var body: some View { NavigationStack { ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle(page.rawValue).toolbar { Button("完成") { dismiss() } } } }
}

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private extension View {
    func softRow() -> some View { self.padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line)) }
}

private struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { withAnimation(.easeOut(duration: 0.18)) { selection = tab } } label: {
                    VStack(spacing: 6) { Circle().fill(selection == tab ? Palette.text : Palette.muted.opacity(0.9)).frame(width: 8, height: 8); Text(tab.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(selection == tab ? Palette.text : Palette.muted) }
                        .frame(maxWidth: .infinity).padding(.vertical, 11).background(selection == tab ? Palette.primary.opacity(0.09) : .clear)
                }.buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial).background(Palette.surfaceTop.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line)).shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4).frame(maxWidth: 430)
    }
}

private struct GradientButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(red: 5/255, green: 17/255, blue: 29/255)).frame(maxWidth: compact ? nil : .infinity).padding(.horizontal, compact ? 14 : 16).padding(.vertical, 13)
            .background(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 18)).opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct SoftButtonStyle: ButtonStyle {
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.text).frame(maxWidth: fullWidth ? .infinity : nil).padding(.horizontal, 16).padding(.vertical, 13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }
}

private struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(LinearGradient(colors: [Color(red: 248/255, green: 113/255, blue: 113/255), Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppStore())
    }
}
