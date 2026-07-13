import Foundation
import Combine

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
    private let defaults: UserDefaults
    private let syncService: SupabaseSyncService?
    private var isLoading = true
    private var isApplyingCloudData = false
    private var hasLocalData = false
    private var localUpdatedAt = Date.distantPast
    private var cloudUploadTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, syncService: SupabaseSyncService? = nil) {
        self.defaults = defaults
        self.syncService = syncService
        cloudSyncState = syncService == nil ? .notConfigured : .signedOut
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(StoredData.self, from: data) {
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
            categories = [
                ExpenseCategory(name: "餐饮", icon: "fork.knife", colorIndex: 0, budget: 1200),
                ExpenseCategory(name: "交通", icon: "tram.fill", colorIndex: 1, budget: 500),
                ExpenseCategory(name: "购物", icon: "bag.fill", colorIndex: 2, budget: 1000),
                ExpenseCategory(name: "医疗", icon: "cross.case.fill", colorIndex: 4),
                ExpenseCategory(name: "娱乐", icon: "gamecontroller.fill", colorIndex: 3),
                ExpenseCategory(name: "其他", icon: "ellipsis.circle.fill", colorIndex: 5)
            ]
        }
        isLoading = false
        persistLocalData()
        if syncService != nil {
            Task { await restoreCloudSession() }
        }
    }

    var isCloudConfigured: Bool { syncService != nil }
    var isCloudSignedIn: Bool { cloudAccountEmail != nil }
    var cloudSyncDescription: String {
        switch cloudSyncState {
        case .notConfigured: "未配置 Supabase"
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
        cloudSyncState = .syncing
        do {
            cloudAccountEmail = try await syncService.verifyEmailOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                token: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try await reconcileWithCloud()
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func syncNow() async throws {
        guard syncService != nil else { throw SupabaseSyncError.notConfigured }
        guard isCloudSignedIn else { throw SupabaseSyncError.notSignedIn }
        cloudUploadTask?.cancel()
        do {
            try await reconcileWithCloud()
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
            throw error
        }
    }

    func refreshFromCloud() async {
        guard isCloudSignedIn else { return }
        do {
            try await reconcileWithCloud()
        } catch {
            cloudSyncState = .failed(error.localizedDescription)
        }
    }

    func signOutCloudAccount() async {
        cloudUploadTask?.cancel()
        await syncService?.signOut()
        cloudAccountEmail = nil
        cloudSyncState = syncService == nil ? .notConfigured : .signedOut
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
        guard !isApplyingCloudData else { return }
        hasLocalData = true
        localUpdatedAt = .now
        persistLocalData()
        guard isCloudSignedIn else { return }
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
            try await reconcileWithCloud()
        } catch {
            cloudAccountEmail = nil
            cloudSyncState = .failed(error.localizedDescription)
        }
    }

    private func reconcileWithCloud() async throws {
        guard let syncService else { throw SupabaseSyncError.notConfigured }
        cloudSyncState = .syncing
        if let cloudData = try await syncService.fetchSnapshot() {
            let cloudUpdatedAt = cloudData.updatedAt ?? .distantPast
            if !hasLocalData || cloudUpdatedAt >= localUpdatedAt {
                applyCloudData(cloudData)
            } else {
                try await syncService.uploadSnapshot(storedData)
            }
        } else {
            try await syncService.uploadSnapshot(storedData)
        }
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
                self.cloudSyncState = .synced(.now)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.cloudSyncState = .failed(error.localizedDescription)
            }
        }
    }
}
