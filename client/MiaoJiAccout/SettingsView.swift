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
    @State private var showCategoryManager = false
    @State private var showCloudLogin = false
    @State private var cloudActionError: String?
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    var body: some View {
        Screen {
            Hero(eyebrow: "系统设置", title: "设置", subtitle: "管理货币、分类、同步和隐私。", pill: "个人", showsContainer: false) {
                GlassCard {
                    HStack(spacing: 14) {
                        Badge(text: "妙", color: .cyan, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("妙记").font(.system(size: 18, weight: .heavy))
                            Text(store.cloudSyncDescription).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
                        }
                        Spacer()
                        Pill(store.isCloudSignedIn ? "已登录" : "本地模式")
                    }
                }
            }
            SettingsCard(title: "货币", subtitle: "支持多币种和显示格式切换。") {
                Button { showCurrency = true } label: { HStack { Badge(text: store.currency.symbol, color: .blue); VStack(alignment: .leading, spacing: 3) { Text(store.currency.name).font(.system(size: 15, weight: .bold)); Text("\(store.currency.code) · 当前使用").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(Palette.muted) }.softRow() }.buttonStyle(.plain)
            }
            SettingsCard(title: "常用选项", subtitle: "使用开关控制自动化和体验偏好。") {
                ToggleRow(title: "深色主题", subtitle: "关闭后切换为明亮主题。", isOn: $isDarkMode)
                ToggleRow(title: "每日预算提醒", subtitle: "当支出接近上限时进行提示。", isOn: $store.budgetReminder)
                HStack { VStack(alignment: .leading, spacing: 4) { Text("每月总预算").font(.system(size: 14, weight: .bold)); Text("用于首页预算执行率核算").font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Text(store.currency.symbol).foregroundStyle(Palette.muted); TextField("0", value: $store.monthlyBudget, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100) }.softRow()
            }
            GlassCard {
                VStack(spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("分类管理").font(.system(size: 18, weight: .bold))
                            Text("常用分类与本地记录数量").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button("管理") { showCategoryManager = true }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.primary)
                            .buttonStyle(.plain)
                    }
                    ForEach(store.categories.prefix(4)) { category in
                        Button { editingCategory = category } label: {
                            ManageRow(
                                icon: category.icon,
                                color: .from(category.colorIndex),
                                title: category.name,
                                subtitle: "\(store.records.filter { $0.categoryID == category.id }.count) 笔记录"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if store.categories.count > 4 {
                        Text("还有 \(store.categories.count - 4) 个分类")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            SettingsCard(title: "Supabase 云同步", subtitle: "使用同一邮箱登录后，可在更换设备后恢复完整账本。") {
                if !store.isCloudConfigured {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.accent)
                        Text("请先在 MiaoJiConfig.xcconfig 中配置 SUPABASE_URL 和 SUPABASE_PUBLISHABLE_KEY。")
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                    }
                    .softRow()
                } else if let email = store.cloudAccountEmail {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.success)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(email).font(.system(size: 14, weight: .bold)).lineLimit(1)
                            Text(store.cloudSyncDescription).font(.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                    }
                    .softRow()
                    Button("立即同步到 Supabase") {
                        Task {
                            do { try await store.syncNow() }
                            catch { cloudActionError = error.localizedDescription }
                        }
                    }
                    .buttonStyle(GradientButtonStyle())
                    Button("退出云同步账号") { Task { await store.signOutCloudAccount() } }
                        .buttonStyle(SoftButtonStyle(fullWidth: true))
                    Button("永久删除账号与数据") { showDeleteAccountConfirmation = true }
                        .buttonStyle(DangerButtonStyle())
                        .disabled(isDeletingAccount)
                } else {
                    Button("登录并开启云同步") { showCloudLogin = true }
                        .buttonStyle(GradientButtonStyle())
                }
            }
            SettingsCard(title: "数据与隐私", subtitle: "导出、备份和清除数据的高风险操作应清晰区分。") {
                Button("导出 CSV") { exporting = true }.buttonStyle(GradientButtonStyle())
                Button("清除全部记账记录") { showClearConfirmation = true }.buttonStyle(DangerButtonStyle())
            }
            SettingsCard(title: "关于", subtitle: "版本信息、隐私和服务协议。") {
                Button { aboutPage = .version } label: { AboutRow(title: "版本", subtitle: AppMetadata.versionDescription) }.buttonStyle(.plain)
                Button { aboutPage = .privacy } label: { AboutRow(title: "隐私政策", subtitle: "查看数据收集和存储说明") }.buttonStyle(.plain)
                Button { aboutPage = .agreement } label: { AboutRow(title: "用户协议", subtitle: "查看使用条款") }.buttonStyle(.plain)
                if let supportURL = AppMetadata.supportURL {
                    Link(destination: supportURL) { AboutRow(title: "支持与联系", subtitle: "打开支持页面") }
                        .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showCurrency) { CurrencyPicker() }
        .sheet(item: $editingCategory) { CategoryEditor(category: $0) }
        .sheet(isPresented: $showCategoryManager) { CategoryManagementView() }
        .sheet(isPresented: $showCloudLogin) { CloudLoginView() }
        .sheet(item: $aboutPage) { AboutDetail(page: $0) }
        .fileExporter(isPresented: $exporting, document: CSVDocument(data: store.csvData(isDarkMode: isDarkMode)), contentType: .commaSeparatedText, defaultFilename: "voice-account-\(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
        .confirmationDialog("确定清除全部记账记录？", isPresented: $showClearConfirmation, titleVisibility: .visible) { Button("清除全部记账记录", role: .destructive) { store.records.removeAll() }; Button("取消", role: .cancel) {} } message: { Text("开启云同步时，这次删除也会同步到 Supabase。分类和偏好设置会保留。") }
        .confirmationDialog("永久删除账号？", isPresented: $showDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("永久删除账号与全部数据", role: .destructive) { deleteAccount() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会永久删除 Supabase 登录账号、云端账本和本机账本，且无法撤销。")
        }
        .alert("云同步操作失败", isPresented: Binding(get: { cloudActionError != nil }, set: { if !$0 { cloudActionError = nil } })) {
            Button("知道了") { cloudActionError = nil }
        } message: {
            Text(cloudActionError ?? "")
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            defer { isDeletingAccount = false }
            do {
                try await store.deleteCloudAccountAndLocalData()
            } catch {
                cloudActionError = error.localizedDescription
            }
        }
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

struct CloudLoginView: View {
    private enum LoginMethod: String, CaseIterable, Identifiable {
        case code = "邮箱验证码"
        case password = "邮箱密码"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var loginMethod: LoginMethod = .code
    @State private var codeSent = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var acceptedTerms = false
    @State private var acceptedCrossBorderTransfer = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("登录方式", selection: $loginMethod) {
                        ForEach(LoginMethod.allCases) { method in Text(method.rawValue).tag(method) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: loginMethod) { _, _ in
                        codeSent = false
                        code = ""
                        password = ""
                    }
                }

                Section {
                    TextField("name@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    if loginMethod == .code && codeSent {
                        TextField("6–10 位验证码", text: $code)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .onChange(of: code) { _, value in
                                let normalized = EmailOTPCode.normalized(value)
                                if normalized != value { code = normalized }
                            }
                    } else if loginMethod == .password {
                        SecureField("密码", text: $password)
                            .textContentType(.password)
                    }
                } header: {
                    Text(loginMethod == .password ? "邮箱密码登录" : (codeSent ? "输入邮箱验证码" : "云同步账号"))
                } footer: {
                    if loginMethod == .password {
                        Text("密码登录适用于已设置密码的账号；新用户请使用邮箱验证码。")
                    } else {
                        Text(codeSent ? "验证码已发送到 \(email)。" : "新邮箱会自动创建 Supabase 账号；换机后使用相同邮箱即可恢复账本。")
                    }
                }

                Section {
                    Toggle("我已阅读并同意隐私政策和用户协议", isOn: $acceptedTerms)
                    HStack(spacing: 18) {
                        if let privacyURL = AppMetadata.privacyPolicyURL {
                            Link("隐私政策", destination: privacyURL)
                        }
                        if let termsURL = AppMetadata.termsURL {
                            Link("用户协议", destination: termsURL)
                        }
                    }
                    Toggle(
                        "我单独同意将邮箱、账号标识、账本和使用语音记账时提交的录音传输至新加坡的 Supabase 服务",
                        isOn: $acceptedCrossBorderTransfer
                    )
                } header: {
                    Text("授权与跨境传输")
                } footer: {
                    Text("用于账号、云同步及录音临时存储。录音随后发送至中国大陆的阿里云百炼解析。你可以不同意并继续使用本地手动记账；此时云同步和语音记账不可用。")
                }

                Section {
                    if loginMethod == .password {
                        Button("登录并开始同步") { signInWithPassword() }
                            .disabled(isWorking || !hasRequiredConsent || !isValidEmail || password.count < 8)
                    } else if codeSent {
                        Button("验证并开始同步") { verifyCode() }
                            .disabled(isWorking || !hasRequiredConsent || !EmailOTPCode.isValid(code))
                        Button("重新发送验证码") { requestCode() }
                            .disabled(isWorking || !hasRequiredConsent)
                    } else {
                        Button("发送验证码") { requestCode() }
                            .disabled(isWorking || !hasRequiredConsent || !isValidEmail)
                    }
                }
            }
            .navigationTitle("登录 Supabase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .overlay { if isWorking { ProgressView().controlSize(.large) } }
            .alert("登录失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("知道了") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var isValidEmail: Bool {
        email.contains("@") && email.split(separator: "@").last?.contains(".") == true
    }

    private var hasRequiredConsent: Bool {
        acceptedTerms && acceptedCrossBorderTransfer
    }

    private func requestCode() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.requestCloudLoginCode(email: email)
                codeSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func verifyCode() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.verifyCloudLoginCode(email: email, code: EmailOTPCode.normalized(code))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithPassword() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.signInToCloud(email: email, password: password)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CategoryManagementView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingCategory: ExpenseCategory?
    @State private var categoryToDelete: ExpenseCategory?
    @State private var blockedDeleteMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("我的分类").font(.title2.bold())
                                Text("编辑图标、颜色与预算，AI 会从这些分类中自动选择。")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 2)

                        ForEach(store.categories) { category in
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 46, height: 46)
                                    .background(LinearGradient(colors: BadgeColor.from(category.colorIndex).colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category.name).font(.system(size: 15, weight: .bold))
                                    let count = store.records.filter { $0.categoryID == category.id }.count
                                    Text("\(count) 笔记录" + (category.budget.map { " · 月预算 \(store.format($0, decimals: false))" } ?? ""))
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Button { editingCategory = category } label: {
                                    Image(systemName: "pencil").frame(width: 34, height: 34)
                                }
                                .buttonStyle(.plain).foregroundStyle(Palette.primary)
                                Button(role: .destructive) { requestDelete(category) } label: {
                                    Image(systemName: "trash").frame(width: 34, height: 34)
                                }
                                .buttonStyle(.plain)
                            }
                            .softRow()
                        }

                        Button {
                            editingCategory = ExpenseCategory(name: "", icon: "tag.fill", colorIndex: store.categories.count % 6)
                        } label: {
                            Label("添加新分类", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(GradientButtonStyle())
                    }
                    .padding(16)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .sheet(item: $editingCategory) { CategoryEditor(category: $0) }
        .confirmationDialog(
            "删除“\(categoryToDelete?.name ?? "")”？",
            isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除分类", role: .destructive) {
                guard let categoryToDelete else { return }
                store.categories.removeAll { $0.id == categoryToDelete.id }
                self.categoryToDelete = nil
            }
            Button("取消", role: .cancel) { categoryToDelete = nil }
        } message: {
            Text("删除后，AI 不会再使用这个分类。")
        }
        .alert(
            "暂时无法删除",
            isPresented: Binding(get: { blockedDeleteMessage != nil }, set: { if !$0 { blockedDeleteMessage = nil } })
        ) {
            Button("知道了") { blockedDeleteMessage = nil }
        } message: {
            Text(blockedDeleteMessage ?? "")
        }
    }

    private func requestDelete(_ category: ExpenseCategory) {
        let usedCount = store.records.filter { $0.categoryID == category.id }.count
        if usedCount > 0 {
            blockedDeleteMessage = "“\(category.name)”仍有 \(usedCount) 笔记录。请先修改这些记录的分类，再删除。"
        } else if store.categories.count == 1 {
            blockedDeleteMessage = "至少保留一个分类，AI 才能为记账明细选择分类。"
        } else {
            categoryToDelete = category
        }
    }
}

struct CategoryEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var category: ExpenseCategory
    private let icons = ["fork.knife", "tram.fill", "bag.fill", "cross.case.fill", "cart.fill", "house.fill", "gamecontroller.fill", "heart.fill", "book.fill", "tag.fill", "ellipsis.circle.fill"]
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

enum AboutPage: String, Identifiable {
    case version = "版本", privacy = "隐私政策", agreement = "用户协议"
    var id: String { rawValue }
    var externalURL: URL? {
        switch self {
        case .version: nil
        case .privacy: AppMetadata.privacyPolicyURL
        case .agreement: AppMetadata.termsURL
        }
    }
}

enum AppMetadata {
    static var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "妙记 v\(version)（\(build)）"
    }

    static let privacyPolicyURL = configuredURL(for: "PRIVACY_POLICY_URL")
    static let termsURL = configuredURL(for: "TERMS_OF_SERVICE_URL")
    static let supportURL = configuredURL(for: "SUPPORT_URL")

    private static func configuredURL(for key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value),
              url.scheme == "https" else { return nil }
        return url
    }
}

struct AboutDetail: View {
    let page: AboutPage
    @Environment(\.dismiss) private var dismiss
    var text: String {
        switch page {
        case .version:
            "\(AppMetadata.versionDescription)\n\n账目保留本地离线缓存；登录后可同步到 Supabase。"
        case .privacy:
            "账目、分类和设置默认保存在设备本地。登录云同步后，邮箱地址、账号标识和账本会存入 Supabase。使用语音记账时，录音会经妙记服务端临时存储，并发送给阿里云百炼用于生成记账草稿；每次解析尝试结束后服务端会删除临时录音，本机会删除已成功解析或已取消的录音。妙记不进行广告跟踪，也不出售个人数据。你可以导出账本、清除记录，或在设置中永久删除账号及关联数据。"
        case .agreement:
            "使用本应用即表示你同意自行核对记账信息。语音与 AI 生成的内容可能不准确；应用提供记录与统计工具，不构成财务、税务或投资建议。"
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(text).frame(maxWidth: .infinity, alignment: .leading)
                    if let url = page.externalURL {
                        Link("查看完整\(page.rawValue)", destination: url)
                    }
                }
                .padding()
            }
            .navigationTitle(page.rawValue)
            .toolbar { Button("完成") { dismiss() } }
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
