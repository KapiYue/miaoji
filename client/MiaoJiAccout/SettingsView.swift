import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
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

struct SettingsCard<Content: View>: View {
    let title: String, subtitle: String
    @ViewBuilder let content: Content
    var body: some View { GlassCard { VStack(spacing: 12) { SectionHeading(title: title, subtitle: subtitle); content } } }
}

struct ToggleRow: View {
    let title: String, subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 14, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }; Spacer(); Toggle("", isOn: $isOn).labelsHidden() }.softRow()
    }
}

struct ManageRow: View {
    let icon: String, color: BadgeColor, title: String, subtitle: String
    var body: some View { HStack { Image(systemName: icon).foregroundStyle(.white).frame(width: 42, height: 42).background(LinearGradient(colors: color.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 14)); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.muted) }.softRow() }
}

struct AboutRow: View {
    let title: String, subtitle: String
    var body: some View { HStack { VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 15, weight: .bold)); Text(subtitle).font(.caption).foregroundStyle(Palette.muted) }; Spacer() }.softRow() }
}

struct CurrencyPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List(AppCurrency.allCases) { currency in Button { store.currency = currency; dismiss() } label: { HStack { Text(currency.symbol).frame(width: 32); Text(currency.name); Spacer(); Text(currency.code).foregroundStyle(.secondary); if store.currency == currency { Image(systemName: "checkmark") } } } }.navigationTitle("选择货币").toolbar { Button("关闭") { dismiss() } } } }
}

struct CategoryEditor: View {
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

enum AboutPage: String, Identifiable { case version = "版本", privacy = "隐私政策", agreement = "用户协议"; var id: String { rawValue } }
struct AboutDetail: View {
    let page: AboutPage
    @Environment(\.dismiss) private var dismiss
    var text: String { switch page { case .version: "语音记账 v2.0\n数据保存在本机。"; case .privacy: "所有账目、分类和设置均保存在设备本地。应用不会主动上传或出售个人数据。导出文件由用户自行保管。"; case .agreement: "使用本应用即表示你同意自行核对记账信息。应用提供记录与统计工具，不构成财务建议。" } }
    var body: some View { NavigationStack { ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle(page.rawValue).toolbar { Button("完成") { dismiss() } } } }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}


