import Foundation
import Combine

enum ScreenshotVoiceState: String {
    case ready, recording, analyzing, drafts, saved
}

enum ScreenshotConfiguration {
    static var voiceState: ScreenshotVoiceState? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--screenshot-demo-data"),
              let flagIndex = arguments.firstIndex(of: "--screenshot-voice-state"),
              arguments.indices.contains(flagIndex + 1)
        else { return nil }
        return ScreenshotVoiceState(rawValue: arguments[flagIndex + 1])
    }
}

struct ExpenseCategory: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var colorIndex: Int
    var budget: Double?

    init(id: UUID = UUID(), name: String, icon: String, colorIndex: Int, budget: Double? = nil) {
        self.id = id; self.name = name; self.icon = icon; self.colorIndex = colorIndex; self.budget = budget
    }
}

enum RecordType: String, Codable, CaseIterable { case expense = "支出", income = "收入" }

struct ExpenseRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var amount: Double
    var title: String
    var note: String
    var categoryID: UUID
    var date: Date = .now
    var type: RecordType?
    var recordType: RecordType { type ?? .expense }

    init(id: UUID = UUID(), amount: Double, title: String, note: String, categoryID: UUID, date: Date = .now, type: RecordType = .expense) {
        self.id = id; self.amount = amount; self.title = title; self.note = note; self.categoryID = categoryID; self.date = date; self.type = type
    }
}

extension Array where Element == ExpenseRecord {
    func sortedByNewestRecord() -> [ExpenseRecord] {
        enumerated().sorted { lhs, rhs in
            if lhs.element.date != rhs.element.date {
                return lhs.element.date > rhs.element.date
            }
            // When records share the same timestamp, the one appended later is newer.
            return lhs.offset > rhs.offset
        }.map { $0.element }
    }
}

enum AppCurrency: String, Codable, CaseIterable, Identifiable {
    case cny, usd, eur, jpy, gbp
    var id: String { rawValue }
    var code: String { rawValue.uppercased() }
    var name: String {
        switch self { case .cny: "人民币"; case .usd: "美元"; case .eur: "欧元"; case .jpy: "日元"; case .gbp: "英镑" }
    }
    var symbol: String {
        switch self { case .cny: "¥"; case .usd: "$"; case .eur: "€"; case .jpy: "¥"; case .gbp: "£" }
    }
}

struct StoredData: Codable, Equatable {
    var records: [ExpenseRecord]
    var categories: [ExpenseCategory]
    var currency: AppCurrency
    var voiceRecognition: Bool
    var budgetReminder: Bool
    var monthlyBudget: Double?
    var updatedAt: Date? = nil
}

enum CloudSyncState: Equatable {
    case notConfigured
    case signedOut
    case syncing
    case synced(Date)
    case failed(String)
}

private enum CloudReconciliationPolicy: Equatable {
    case cloud
    case local
}

@MainActor
final class AppStore: ObservableObject {
    @Published var records: [ExpenseRecord] = [] { didSet { save() } }
    @Published var categories: [ExpenseCategory] = [] { didSet { save() } }
    @Published var currency: AppCurrency = .cny { didSet { save() } }
    @Published var voiceRecognition = true { didSet { save() } }
    @Published var budgetReminder = false { didSet { save() } }
    @Published var monthlyBudget = 4000.0 { didSet { save() } }
    @Published private(set) var cloudAccountEmail: String?
    @Published private(set) var cloudSyncState: CloudSyncState

    private let key = "MiaoJiAccout.localData.v1"
    private let pendingCloudChangesKey = "MiaoJiAccout.pendingCloudChanges.v1"
    private let localDataOwnerKey = "MiaoJiAccout.localDataOwner.v1"
    private static let guestDataOwner = "guest"
    private let defaults: UserDefaults
    private let syncService: (any SupabaseSyncServicing)?
    private let isDemoMode: Bool
    private var isLoading = true
    private var isApplyingCloudData = false
    private var hasLocalData = false
    private var hasPendingCloudChanges: Bool
    private var localDataOwner: String?
    private var localUpdatedAt = Date.distantPast
    private var cloudUploadTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        syncService: (any SupabaseSyncServicing)? = nil,
        demoData: Bool = false
    ) {
        self.defaults = defaults
        self.syncService = syncService
        isDemoMode = demoData
        hasPendingCloudChanges = defaults.bool(forKey: pendingCloudChangesKey)
        localDataOwner = defaults.string(forKey: localDataOwnerKey)
        cloudSyncState = syncService == nil ? .notConfigured : .signedOut
        if demoData {
            localUpdatedAt = .now
            categories = Self.defaultCategories
            records = Self.demoRecords(categories: categories)
            if ScreenshotConfiguration.voiceState == .saved {
                records.append(contentsOf: Self.demoVoiceRecords(categories: categories))
            }
            currency = .cny
            monthlyBudget = 7_200
        } else if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(StoredData.self, from: data) {
            hasLocalData = true
            localUpdatedAt = value.updatedAt ?? .distantPast
            records = value.records
            categories = value.categories
            currency = value.currency
            voiceRecognition = value.voiceRecognition
            budgetReminder = value.budgetReminder
            monthlyBudget = value.monthlyBudget ?? 4000
        } else {
            localUpdatedAt = .now
            categories = Self.defaultCategories
        }
        isLoading = false
        if hasLocalData { persistLocalData() }
        if syncService != nil {
            Task { await restoreCloudSession() }
        }
    }

    var isCloudConfigured: Bool { syncService != nil || isDemoMode }
    var isCloudSignedIn: Bool { cloudAccountEmail != nil }
    var cloudSyncDescription: String {
        switch cloudSyncState {
        case .notConfigured: isDemoMode ? "登录后可开启云同步" : "未配置云同步"
        case .signedOut: "登录后可跨设备查看账本"
        case .syncing: "正在同步…"
        case .synced(let date): "已同步 · \(formatDate(date, dateStyle: .none, timeStyle: .short))"
        case .failed(let message): "同步失败：\(message)"
        }
    }

    func requestCloudLoginCode(email: String) async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        try await syncService.requestEmailOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func verifyCloudLoginCode(email: String, code: String) async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        try await completeCloudLogin {
            try await syncService.verifyEmailOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                token: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    func signInToCloud(email: String, password: String) async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        try await completeCloudLogin {
            try await syncService.signInWithPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    /// Runs an explicit login and the steps that must succeed with it. A failure
    /// before the account is established leaves the app in its signed-out state
    /// rather than showing a lingering "sync failed" banner for a session that
    /// never existed.
    private func completeCloudLogin(_ authenticate: () async throws -> String) async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        cloudSyncState = .syncing
        do {
            cloudAccountEmail = try await authenticate()
            do {
                try await recordPrivacyConsentAllowingOneRetry(using: syncService)
            } catch {
                await syncService.signOut()
                cloudAccountEmail = nil
                throw SupabaseSyncError.server(
                    "登录成功，但同意记录未能保存，已退出登录。请检查网络后重试。"
                )
            }
            prepareLocalDataForExplicitLogin(email: cloudAccountEmail)
            try await reconcileWithCloud(policy: .cloud)
        } catch {
            if cloudAccountEmail == nil {
                cloudSyncState = .signedOut
            } else {
                cloudSyncState = .failed(error.localizedDescription)
            }
            throw error
        }
    }

    /// Consent must be recorded server-side before the ledger syncs, but a
    /// single transient network failure should not undo a successful sign-in.
    private func recordPrivacyConsentAllowingOneRetry(using syncService: SupabaseSyncServicing) async throws {
        do {
            try await syncService.recordPrivacyConsent()
        } catch {
            try await Task.sleep(for: .milliseconds(800))
            try await syncService.recordPrivacyConsent()
        }
    }

    func syncNow() async throws {
        guard syncService != nil else { throw SupabaseSyncError.notConfigured }
        guard isCloudSignedIn else { throw SupabaseSyncError.notSignedIn }
        cloudUploadTask?.cancel()
        do {
            try await reconcileWithCloud(policy: hasPendingCloudChanges ? .local : .cloud)
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func refreshFromCloud() async {
        guard isCloudSignedIn else { return }
        do {
            try await reconcileWithCloud(policy: hasPendingCloudChanges ? .local : .cloud)
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
        }
    }

    func signOutCloudAccount() async {
        cloudUploadTask?.cancel()
        // A signed-out device must not continue displaying or reusing the last
        // account's ledger. The cloud snapshot remains available on next login.
        clearLocalData()
        cloudAccountEmail = nil
        cloudSyncState = syncService == nil ? .notConfigured : .signedOut
        await syncService?.signOut()
    }

    func voiceAuthorizationToken() async throws -> String {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        guard isCloudSignedIn else { throw SupabaseSyncError.notSignedIn }
        return try await syncService.accessToken()
    }

    func deleteCloudAccountAndLocalData() async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        guard isCloudSignedIn else { throw SupabaseSyncError.notSignedIn }
        cloudUploadTask?.cancel()
        cloudSyncState = .syncing
        do {
            try await syncService.deleteAccount()
            clearLocalData()
            cloudAccountEmail = nil
            cloudSyncState = .signedOut
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func category(for id: UUID) -> ExpenseCategory? { categories.first { $0.id == id } }

    func format(_ amount: Double, decimals: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.symbol
        formatter.minimumFractionDigits = decimals ? 2 : 0
        formatter.maximumFractionDigits = decimals ? 2 : 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.symbol)\(amount)"
    }

    func formatDate(_ date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    func csvData(isDarkMode: Bool) -> Data {
        let header = ["data_type", "id", "date", "record_type", "amount", "currency", "title", "note", "category_id", "category_name", "category_icon", "category_color_index", "category_budget", "setting_key", "setting_value"]
        var rows = [header]

        let settings: [(String, String)] = [
            ("currency", currency.rawValue),
            ("voice_recognition", String(voiceRecognition)),
            ("budget_reminder", String(budgetReminder)),
            ("monthly_budget", Self.decimalString(monthlyBudget)),
            ("dark_mode", String(isDarkMode))
        ]
        rows.append(contentsOf: settings.map { key, value in
            ["setting", "", "", "", "", "", "", "", "", "", "", "", "", key, value]
        })

        for category in categories.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) {
            rows.append([
                "category", category.id.uuidString, "", "", "", "", "", "", "", category.name,
                category.icon, String(category.colorIndex), category.budget.map { Self.decimalString($0) } ?? "", "", ""
            ])
        }

        let formatter = ISO8601DateFormatter()
        for record in records.sorted(by: { $0.date < $1.date }) {
            rows.append([
                "record", record.id.uuidString, formatter.string(from: record.date), record.recordType.rawValue,
                Self.decimalString(record.amount, fractionDigits: 2), currency.code, record.title, record.note,
                record.categoryID.uuidString, category(for: record.categoryID)?.name ?? "", "", "", "", "", ""
            ])
        }
        let csv = rows.map { $0.map(Self.csvEscape).joined(separator: ",") }.joined(separator: "\r\n")
        return ("\u{FEFF}" + csv).data(using: .utf8) ?? Data()
    }

    private static func csvEscape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func decimalString(_ value: Double, fractionDigits: Int? = nil) -> String {
        if let fractionDigits {
            return String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), fractionDigits, value)
        }
        return String(value)
    }

    private func save() {
        guard !isLoading else { return }
        guard !isDemoMode else { return }
        guard !isApplyingCloudData else { return }
        hasLocalData = true
        localUpdatedAt = .now
        if localDataOwner == nil {
            setLocalDataOwner(cloudAccountEmail.map(Self.accountDataOwner) ?? Self.guestDataOwner)
        }
        persistLocalData()
        guard isCloudSignedIn else { return }
        setHasPendingCloudChanges(true)
        scheduleCloudUpload()
    }

    private var storedData: StoredData {
        StoredData(
            records: records,
            categories: categories,
            currency: currency,
            voiceRecognition: voiceRecognition,
            budgetReminder: budgetReminder,
            monthlyBudget: monthlyBudget,
            updatedAt: localUpdatedAt
        )
    }

    private func restoreCloudSession() async {
        guard let syncService else { return }
        do {
            guard let email = try await syncService.restoreSession() else {
                cloudSyncState = .signedOut
                return
            }
            cloudAccountEmail = email
            prepareLocalDataForRestoredSession(email: email)
            // A completed previous sync makes Supabase authoritative after an
            // app restart. Only a known unsent local edit may remain local-first.
            try await reconcileWithCloud(policy: hasPendingCloudChanges ? .local : .cloud)
        } catch {
            cloudAccountEmail = nil
            cloudSyncState = .failed(error.localizedDescription)
        }
    }

    private func reconcileWithCloud(policy: CloudReconciliationPolicy) async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        cloudSyncState = .syncing
        if let cloudData = try await syncService.fetchSnapshot() {
            if policy == .cloud || !hasLocalData {
                applyCloudData(cloudData)
            } else {
                try await syncService.uploadSnapshot(storedData)
            }
        } else {
            try await syncService.uploadSnapshot(storedData)
        }
        setHasPendingCloudChanges(false)
        cloudSyncState = .synced(.now)
    }

    private func applyCloudData(_ data: StoredData) {
        isApplyingCloudData = true
        localUpdatedAt = data.updatedAt ?? .now
        hasLocalData = true
        records = data.records
        categories = data.categories
        currency = data.currency
        voiceRecognition = data.voiceRecognition
        budgetReminder = data.budgetReminder
        monthlyBudget = data.monthlyBudget ?? 4000
        isApplyingCloudData = false
        persistLocalData()
    }

    private func persistLocalData() {
        if let encoded = try? JSONEncoder().encode(storedData) { defaults.set(encoded, forKey: key) }
    }

    private func scheduleCloudUpload() {
        guard let syncService else { return }
        cloudUploadTask?.cancel()
        cloudUploadTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(650))
                guard let self, !Task.isCancelled else { return }
                self.cloudSyncState = .syncing
                try await syncService.uploadSnapshot(self.storedData)
                guard !Task.isCancelled else { return }
                self.setHasPendingCloudChanges(false)
                self.cloudSyncState = .synced(.now)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.cloudSyncState = .failed(error.localizedDescription)
            }
        }
    }

    private func setHasPendingCloudChanges(_ value: Bool) {
        hasPendingCloudChanges = value
        defaults.set(value, forKey: pendingCloudChangesKey)
    }

    private func prepareLocalDataForExplicitLogin(email: String?) {
        guard let email else { return }
        let accountOwner = Self.accountDataOwner(email)
        // Guest data created by this version may be adopted by its first cloud
        // account. Account-owned or legacy-unmarked data must never cross users.
        if localDataOwner != Self.guestDataOwner && localDataOwner != accountOwner {
            clearLocalData()
        }
        setLocalDataOwner(accountOwner)
    }

    private func prepareLocalDataForRestoredSession(email: String) {
        let accountOwner = Self.accountDataOwner(email)
        // An unmarked legacy cache can safely follow a restored Keychain session:
        // the session proves which account was active when the app last ran.
        if let localDataOwner,
           localDataOwner != Self.guestDataOwner,
           localDataOwner != accountOwner {
            clearLocalData()
        }
        setLocalDataOwner(accountOwner)
    }

    private static func accountDataOwner(_ email: String) -> String {
        "account:\(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func setLocalDataOwner(_ owner: String) {
        localDataOwner = owner
        defaults.set(owner, forKey: localDataOwnerKey)
    }

    private func clearLocalData() {
        isApplyingCloudData = true
        records = []
        categories = Self.defaultCategories
        currency = .cny
        voiceRecognition = true
        budgetReminder = false
        monthlyBudget = 4_000
        isApplyingCloudData = false
        hasLocalData = false
        localUpdatedAt = .now
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: localDataOwnerKey)
        localDataOwner = nil
        setHasPendingCloudChanges(false)
    }

    private static var defaultCategories: [ExpenseCategory] {
        [
            ExpenseCategory(name: "餐饮", icon: "fork.knife", colorIndex: 0, budget: 1200),
            ExpenseCategory(name: "交通", icon: "tram.fill", colorIndex: 1, budget: 500),
            ExpenseCategory(name: "购物", icon: "bag.fill", colorIndex: 2, budget: 1000),
            ExpenseCategory(name: "医疗", icon: "cross.case.fill", colorIndex: 4),
            ExpenseCategory(name: "娱乐", icon: "gamecontroller.fill", colorIndex: 3),
            ExpenseCategory(name: "其他", icon: "ellipsis.circle.fill", colorIndex: 5)
        ]
    }

    private static func demoRecords(categories: [ExpenseCategory], now: Date = .now) -> [ExpenseRecord] {
        let calendar = Calendar(identifier: .gregorian)
        func categoryID(_ name: String) -> UUID {
            categories.first(where: { $0.name == name })?.id ?? categories[0].id
        }
        func date(monthOffset: Int = 0, day: Int, hour: Int) -> Date {
            let shifted = calendar.date(byAdding: .month, value: monthOffset, to: now) ?? now
            let parts = calendar.dateComponents([.year, .month], from: shifted)
            return calendar.date(
                from: DateComponents(year: parts.year, month: parts.month, day: day, hour: hour)
            ) ?? shifted
        }
        let today = max(1, calendar.component(.day, from: now))
        let yesterday = max(1, today - 1)
        var records = [
            ExpenseRecord(amount: 12_800, title: "本月收入", note: "虚构演示收入", categoryID: categoryID("其他"), date: date(day: 1, hour: 9), type: .income),
            ExpenseRecord(amount: 28.8, title: "晨间咖啡", note: "开启轻松的一天", categoryID: categoryID("餐饮"), date: date(day: today, hour: 8)),
            ExpenseRecord(amount: 46, title: "午间简餐", note: "工作日套餐", categoryID: categoryID("餐饮"), date: date(day: today, hour: 12)),
            ExpenseRecord(amount: 8, title: "城市地铁", note: "绿色通勤", categoryID: categoryID("交通"), date: date(day: today, hour: 18)),
            ExpenseRecord(amount: 88, title: "晚间花束", note: "给生活一点颜色", categoryID: categoryID("购物"), date: date(day: today, hour: 19)),
            ExpenseRecord(amount: 236.5, title: "超市采购", note: "一周新鲜食材", categoryID: categoryID("购物"), date: date(day: yesterday, hour: 19)),
            ExpenseRecord(amount: 3, title: "共享单车", note: "最后一公里", categoryID: categoryID("交通"), date: date(day: yesterday, hour: 20)),
            ExpenseRecord(amount: 96, title: "周末电影", note: "双人电影票", categoryID: categoryID("娱乐"), date: date(day: max(1, today - 2), hour: 20)),
            ExpenseRecord(amount: 128, title: "瑜伽体验", note: "舒展与放松", categoryID: categoryID("其他"), date: date(day: max(1, today - 2), hour: 10)),
            ExpenseRecord(amount: 328.6, title: "生活用品", note: "月度安心补货", categoryID: categoryID("购物"), date: date(day: max(1, today - 4), hour: 16)),
            ExpenseRecord(amount: 268, title: "朋友聚餐", note: "周末好好见面", categoryID: categoryID("餐饮"), date: date(day: max(1, today - 5), hour: 19)),
            ExpenseRecord(amount: 188, title: "城际出行", note: "短途往返", categoryID: categoryID("交通"), date: date(day: max(1, today - 6), hour: 9)),
            ExpenseRecord(amount: 86, title: "常用药品", note: "补充家庭药箱", categoryID: categoryID("医疗"), date: date(day: max(1, today - 7), hour: 11)),
            ExpenseRecord(amount: 78, title: "纸质书", note: "周末慢慢读", categoryID: categoryID("娱乐"), date: date(day: max(1, today - 8), hour: 15)),
            ExpenseRecord(amount: 560, title: "轻便外套", note: "换季添置", categoryID: categoryID("购物"), date: date(day: max(1, today - 9), hour: 15)),
            ExpenseRecord(amount: 199, title: "早餐月卡", note: "规律早餐计划", categoryID: categoryID("餐饮"), date: date(day: max(1, today - 10), hour: 8)),
            ExpenseRecord(amount: 168, title: "植物养护", note: "阳台焕新", categoryID: categoryID("其他"), date: date(day: max(1, today - 11), hour: 16)),
            ExpenseRecord(amount: 128, title: "周末早午餐", note: "慢下来享受周末", categoryID: categoryID("餐饮"), date: date(day: max(1, today - 12), hour: 11)),
            ExpenseRecord(amount: 268, title: "桌面台灯", note: "温暖阅读角", categoryID: categoryID("购物"), date: date(day: max(1, today - 13), hour: 18)),
            ExpenseRecord(amount: 120, title: "通勤充值", note: "本月交通余额", categoryID: categoryID("交通"), date: date(day: max(1, today - 14), hour: 9))
        ]

        let historicalMonths: [(offset: Int, amounts: [Double])] = [
            (-1, [980, 1_120, 420, 380, 180, 260]),
            (-2, [920, 980, 360, 310, 170, 240]),
            (-3, [1_080, 1_260, 450, 420, 190, 220]),
            (-4, [960, 1_030, 390, 350, 160, 260]),
            (-5, [1_020, 1_180, 430, 390, 180, 280]),
            (-6, [940, 1_050, 400, 360, 170, 290])
        ]
        let historicalCategories = ["餐饮", "购物", "交通", "娱乐", "医疗", "其他"]
        let historicalTitles = ["日常餐饮", "居家添置", "通勤出行", "休闲娱乐", "健康用品", "生活杂项"]
        let historicalDays = [5, 8, 12, 16, 20, 24]

        for month in historicalMonths {
            for index in historicalCategories.indices {
                records.append(
                    ExpenseRecord(
                        amount: month.amounts[index],
                        title: historicalTitles[index],
                        note: "虚构历史趋势数据",
                        categoryID: categoryID(historicalCategories[index]),
                        date: date(monthOffset: month.offset, day: historicalDays[index], hour: 12 + index)
                    )
                )
            }
        }
        return records
    }

    private static func demoVoiceRecords(categories: [ExpenseCategory], now: Date = .now) -> [ExpenseRecord] {
        func categoryID(_ name: String) -> UUID {
            categories.first(where: { $0.name == name })?.id ?? categories[0].id
        }
        return [
            ExpenseRecord(
                amount: 45,
                title: "午餐",
                note: "AI 语音解析",
                categoryID: categoryID("餐饮"),
                date: now.addingTimeInterval(-60)
            ),
            ExpenseRecord(
                amount: 28,
                title: "打车",
                note: "AI 语音解析",
                categoryID: categoryID("交通"),
                date: now
            )
        ]
    }
}
