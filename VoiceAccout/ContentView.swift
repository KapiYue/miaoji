import SwiftUI
import UIKit

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
    static let background = adaptive(light: UIColor(red: 244/255, green: 248/255, blue: 252/255, alpha: 1), dark: UIColor(red: 7/255, green: 17/255, blue: 31/255, alpha: 1))
    static let background2 = adaptive(light: UIColor(red: 226/255, green: 237/255, blue: 248/255, alpha: 1), dark: UIColor(red: 20/255, green: 37/255, blue: 62/255, alpha: 1))
    static let text = adaptive(light: UIColor(red: 20/255, green: 32/255, blue: 48/255, alpha: 1), dark: UIColor(red: 244/255, green: 247/255, blue: 251/255, alpha: 1))
    static let muted = adaptive(light: UIColor(red: 90/255, green: 107/255, blue: 128/255, alpha: 1), dark: UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1))
    static let surfaceTop = adaptive(light: .white, dark: UIColor(red: 18/255, green: 28/255, blue: 46/255, alpha: 1))
    static let surfaceBottom = adaptive(light: UIColor(red: 241/255, green: 246/255, blue: 251/255, alpha: 1), dark: UIColor(red: 10/255, green: 18/255, blue: 31/255, alpha: 1))
    static let soft = adaptive(light: UIColor(white: 0, alpha: 0.035), dark: UIColor(white: 1, alpha: 0.04))
    static let line = adaptive(light: UIColor(white: 0, alpha: 0.08), dark: UIColor(white: 1, alpha: 0.08))
    static let primary = Color(red: 125/255, green: 211/255, blue: 252/255)
    static let accent = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let success = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let pink = Color(red: 251/255, green: 113/255, blue: 133/255)
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.background, Color(red: 13/255, green: 27/255, blue: 47/255), Palette.background2], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.primary.opacity(0.2)).frame(width: 330, height: 330).blur(radius: 60).offset(x: 170, y: -360)
            Circle().fill(Palette.accent.opacity(0.16)).frame(width: 330, height: 330).blur(radius: 70).offset(x: -170, y: 390)
            Circle().fill(Palette.pink.opacity(0.1)).frame(width: 260, height: 260).blur(radius: 70).offset(x: -190, y: 90)
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
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background {
            ZStack {
                LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom)
                Circle().fill(Palette.primary.opacity(0.15)).frame(width: 170).blur(radius: 24).offset(x: -150, y: -100)
                Circle().fill(Palette.accent.opacity(0.13)).frame(width: 220).blur(radius: 28).offset(x: 150, y: 130)
            }.clipShape(RoundedRectangle(cornerRadius: 34))
        }
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(Palette.line))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 16)
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
    @State private var sheet: EntrySheet?
    var body: some View {
        Screen {
            Hero(eyebrow: "Daily capture", title: "记账", subtitle: "语音优先，手动补录，减少记录成本。", pill: "Today") {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("本月支出").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        Text("¥ 3,280.40").font(.system(size: 40, weight: .heavy)).tracking(-1)
                        Text("较上月 +6.8%，预算执行率 82%。").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 12) {
                    ActionCard(icon: "mic.fill", title: "语音输入", text: "长按录音，自动识别金额和分类。", colors: [Color(red: 20/255, green: 36/255, blue: 61/255), Color(red: 18/255, green: 61/255, blue: 80/255)]) { sheet = .voice }
                    ActionCard(icon: "square.and.pencil", title: "手动输入", text: "快速补录，适合补充备注和时间。", colors: [Color(red: 54/255, green: 24/255, blue: 50/255), Color(red: 84/255, green: 31/255, blue: 50/255)]) { sheet = .manual }
                }
            }
            VStack(spacing: 12) {
                SectionHeading(title: "今日概览", subtitle: "8 笔支出，餐饮占比最高。", trailing: "Updated 2m ago")
                MetricsRow(metrics: [("总支出", "¥ 418.20"), ("最大一笔", "¥ 128.80"), ("高频分类", "餐饮")])
            }
            VStack(spacing: 12) {
                SectionHeading(title: "最近记录", subtitle: "按时间从新到旧排列。")
                ExpenseRow(badge: "餐", color: .blue, title: "午餐", meta: "12:30 · 餐饮 · 食堂", amount: "¥ 45.00", note: "已同步")
                ExpenseRow(badge: "交", color: .green, title: "地铁", meta: "09:15 · 交通 · 通勤", amount: "¥ 6.00", note: "已同步")
                ExpenseRow(badge: "咖", color: .purple, title: "咖啡", meta: "08:45 · 餐饮 · 便利店", amount: "¥ 28.00", note: "已同步")
            }
            GlassCard {
                VStack(spacing: 14) {
                    SectionHeading(title: "预算提醒", subtitle: "本月餐饮预算已使用 68%。", trailing: "Healthy")
                    ProgressLine(title: "餐饮", value: 0.68)
                    ProgressLine(title: "交通", value: 0.42)
                }
            }
        }
        .sheet(item: $sheet) { type in EntrySheetView(type: type) }
    }
}

private enum EntrySheet: Identifiable { case voice, manual; var id: Self { self } }

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
                    Capsule().fill(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * value)
                }
            }.frame(height: 10)
        }
    }
}

private struct EntrySheetView: View {
    let type: EntrySheet
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var title = ""
    @State private var note = ""
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type == .voice ? "语音输入" : "添加支出").font(.title3.bold())
                        Text(type == .voice ? "长按开始录音，松开发送识别结果。" : "保留完整金额、分类和备注字段。").font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer(); Button("关闭") { dismiss() }.buttonStyle(SoftButtonStyle())
                }
                if type == .voice {
                    GlassCard {
                        VStack(spacing: 16) { Badge(text: "V", color: .cyan, size: 84); Text("识别示例：午餐 45 元，餐饮，12:30").font(.caption).foregroundStyle(Palette.muted) }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    Button("开始录音") { }.buttonStyle(GradientButtonStyle())
                } else {
                    DarkField(label: "金额", placeholder: "0.00", text: $amount)
                    DarkField(label: "标题", placeholder: "例如：午餐 / 咖啡 / 打车", text: $title)
                    DarkField(label: "备注", placeholder: "可选：商户、地点或付款方式", text: $note)
                    Button("保存") { dismiss() }.buttonStyle(GradientButtonStyle())
                }
                Spacer()
            }.padding(18).padding(.top, 12).frame(maxWidth: 430)
        }.presentationDetents(type == .voice ? [.medium] : [.large]).presentationDragIndicator(.visible)
    }
}

private struct DarkField: View {
    let label: String, placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(Palette.muted)
            TextField(placeholder, text: $text).padding(13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
        }
    }
}

private struct HistoryView: View {
    @State private var search = ""
    var body: some View {
        Screen {
            Hero(eyebrow: "Timeline", title: "历史", subtitle: "按日期聚合，重点记录一眼可扫。", pill: "Filters") {
                HStack(spacing: 10) {
                    TextField("搜索标题、分类、备注...", text: $search).padding(13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
                    Button("筛选") { }.buttonStyle(GradientButtonStyle(compact: true))
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "快捷筛选", subtitle: "日期、分类和金额段。")
                    FlowPills(items: ["今天", "本周", "餐饮", "交通", "大于 100 元"])
                }
            }
            HistoryGroup(day: "今天", date: "1 月 15 日 · 星期一", total: "¥ 79.00", count: "3 笔", rows: [
                ("餐", .blue, "午餐", "12:30 · 餐饮 · 支付宝", "¥ 45.00", "食堂"),
                ("咖", .purple, "咖啡", "08:45 · 餐饮 · 便利店", "¥ 28.00", "自提"),
                ("交", .green, "地铁", "08:15 · 交通 · 通勤", "¥ 6.00", "已记")])
            HistoryGroup(day: "昨天", date: "1 月 14 日 · 星期日", total: "¥ 156.50", count: "5 笔", rows: [
                ("影", .pink, "电影票", "19:30 · 娱乐 · 商城", "¥ 58.00", "双人"),
                ("餐", .blue, "晚餐", "18:15 · 餐饮 · 餐厅", "¥ 85.50", "含小食"),
                ("公", .green, "公交", "17:45 · 交通 · 公交卡", "¥ 2.00", "刷卡"),
                ("购", .amber, "购物", "15:20 · 购物 · 商超", "¥ 128.80", "已记")])
            GlassCard {
                VStack(spacing: 14) { SectionHeading(title: "记录密度", subtitle: "帮助快速发现高频日期。", trailing: "Heatmap"); MetricsRow(metrics: [("高峰时段", "12:00"), ("最多分类", "餐饮"), ("补录率", "11%")]) }
            }
        }
    }
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
    @State private var period = 0
    private let sets = [[0.34, 0.61, 0.48, 0.72, 0.57, 0.83, 0.66], [0.52, 0.75, 0.64, 0.88, 0.72, 0.58, 0.94], [0.46, 0.55, 0.69, 0.78, 0.88, 0.74, 0.96]]
    var body: some View {
        Screen {
            Hero(eyebrow: "Analytics", title: "统计", subtitle: "用更少的图表，呈现更关键的消费变化。", pill: "Month") {
                SegmentedPicker(items: ["月", "季度", "年"], selection: $period)
            }
            MetricsRow(metrics: [("本月支出", "¥ 3,280"), ("日均支出", "¥ 109"), ("节省率", "12.4%")])
            GlassCard {
                VStack(spacing: 16) {
                    SectionHeading(title: "支出趋势", subtitle: "切换维度后，柱状高度会更新。", trailing: "Trend")
                    TrendChart(values: sets[period])
                }
            }
            GlassCard {
                VStack(spacing: 16) {
                    SectionHeading(title: "分类分布", subtitle: "用圆环图概括消费结构。", trailing: "Mix")
                    DonutChart()
                    ExpenseRow(badge: "", color: .blue, title: "餐饮", meta: "44% · 预算最容易超支", amount: "¥ 1,445", note: "43.9%")
                    ExpenseRow(badge: "", color: .green, title: "交通", meta: "19% · 日常通勤", amount: "¥ 620", note: "18.9%")
                    ExpenseRow(badge: "", color: .purple, title: "购物", meta: "15% · 计划性消费", amount: "¥ 495", note: "15.1%")
                    ExpenseRow(badge: "", color: .amber, title: "娱乐", meta: "12% · 周末开销", amount: "¥ 392", note: "11.9%")
                }
            }
            GlassCard {
                VStack(spacing: 14) {
                    SectionHeading(title: "关键结论", subtitle: "用摘要卡片替代冗长说明。")
                    InsightRow(title: "餐饮连续 3 周上升", subtitle: "建议在工作日午餐设置上限。", tag: "Alert")
                    InsightRow(title: "交通成本较上月下降", subtitle: "通勤结构稳定，变化不大。", tag: "Good")
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
    let values: [Double]
    let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(values.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Palette.primary.opacity(0.9), Palette.accent.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                            .frame(height: max(16, geo.size.height * values[index])).frame(maxHeight: .infinity, alignment: .bottom)
                    }.frame(height: 150)
                    Text(labels[index]).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity)
            }
        }.animation(.easeInOut(duration: 0.3), value: values)
    }
}

private struct DonutChart: View {
    let segments: [(Double, Color)] = [(0.44, .cyan), (0.19, Palette.success), (0.15, .purple), (0.13, Palette.accent), (0.09, Palette.pink)]
    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                Circle().trim(from: start(index), to: start(index) + segments[index].0).stroke(segments[index].1, style: StrokeStyle(lineWidth: 28, lineCap: .butt)).rotationEffect(.degrees(-90))
            }
            VStack(spacing: 3) { Text("¥ 3,280").font(.system(size: 21, weight: .bold)); Text("本月总支出").font(.caption).foregroundStyle(Palette.muted) }
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
    @Binding var isDarkMode: Bool
    @State private var voice = true
    @State private var budget = false
    var body: some View {
        Screen {
            Hero(eyebrow: "System", title: "设置", subtitle: "管理货币、分类、同步和隐私。", pill: "Profile") {
                GlassCard {
                    HStack(spacing: 14) { Badge(text: "U", color: .cyan, size: 56); VStack(alignment: .leading, spacing: 4) { Text("清眸").font(.system(size: 18, weight: .heavy)); Text("语音记账 Pro · 已同步到本地库").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill("Premium") }
                }
            }
            SettingsCard(title: "货币", subtitle: "支持多币种和显示格式切换。") {
                HStack { Badge(text: "¥", color: .blue); VStack(alignment: .leading, spacing: 3) { Text("人民币").font(.system(size: 15, weight: .bold)); Text("CNY · 当前使用").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill("Edit") }.softRow()
            }
            SettingsCard(title: "常用选项", subtitle: "使用开关控制自动化和体验偏好。") {
                ToggleRow(title: "语音自动识别", subtitle: "录音后自动生成金额、标题和分类。", isOn: $voice)
                ToggleRow(title: "深色主题", subtitle: "关闭后切换为明亮主题。", isOn: $isDarkMode)
                ToggleRow(title: "每日预算提醒", subtitle: "当支出接近上限时进行提示。", isOn: $budget)
            }
            SettingsCard(title: "分类管理", subtitle: "按颜色和图标区分消费语义。") {
                ManageRow(badge: "餐", color: .blue, title: "餐饮", subtitle: "156 笔记录")
                ManageRow(badge: "交", color: .green, title: "交通", subtitle: "89 笔记录")
                ManageRow(badge: "购", color: .purple, title: "购物", subtitle: "43 笔记录")
            }
            SettingsCard(title: "数据与隐私", subtitle: "导出、备份和清除数据的高风险操作应清晰区分。") {
                Button("导出 CSV") { }.buttonStyle(GradientButtonStyle())
                Button("同步到 iCloud") { }.buttonStyle(SoftButtonStyle(fullWidth: true))
                Button("清除全部数据") { }.buttonStyle(DangerButtonStyle())
            }
            SettingsCard(title: "关于", subtitle: "版本信息、隐私和服务协议。") {
                AboutRow(title: "版本", subtitle: "语音记账 PRD v2.0", tag: "Latest")
                AboutRow(title: "隐私政策", subtitle: "查看数据收集和存储说明", tag: "Open")
                AboutRow(title: "用户协议", subtitle: "查看使用条款", tag: "Open")
            }
        }
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
    let badge: String, color: BadgeColor, title: String, subtitle: String
    var body: some View { HStack { Badge(text: badge, color: color); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill("Manage") }.softRow() }
}

private struct AboutRow: View {
    let title: String, subtitle: String, tag: String
    var body: some View { HStack { VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Pill(tag) }.softRow() }
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
    static var previews: some View { ContentView() }
}
