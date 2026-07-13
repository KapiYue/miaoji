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

private struct StoredData: Codable {
    var records: [ExpenseRecord]
    var categories: [ExpenseCategory]
    var currency: AppCurrency
    var voiceRecognition: Bool
    var budgetReminder: Bool
    var monthlyBudget: Double?
}

@MainActor
final class AppStore: ObservableObject {
    @Published var records: [ExpenseRecord] = [] { didSet { save() } }
    @Published var categories: [ExpenseCategory] = [] { didSet { save() } }
    @Published var currency: AppCurrency = .cny { didSet { save() } }
    @Published var voiceRecognition = true { didSet { save() } }
    @Published var budgetReminder = false { didSet { save() } }
    @Published var monthlyBudget = 4000.0 { didSet { save() } }

    private let key = "YuJiAccount.localData.v1"
    private let defaults: UserDefaults
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(StoredData.self, from: data) {
            records = value.records
            categories = value.categories
            currency = value.currency
            voiceRecognition = value.voiceRecognition
            budgetReminder = value.budgetReminder
            monthlyBudget = value.monthlyBudget ?? 4000
        } else {
            categories = [
                ExpenseCategory(name: "餐饮", icon: "fork.knife", colorIndex: 0, budget: 1200),
                ExpenseCategory(name: "交通", icon: "tram.fill", colorIndex: 1, budget: 500),
                ExpenseCategory(name: "购物", icon: "bag.fill", colorIndex: 2, budget: 1000)
            ]
        }
        isLoading = false
        save()
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
        let value = StoredData(records: records, categories: categories, currency: currency, voiceRecognition: voiceRecognition, budgetReminder: budgetReminder, monthlyBudget: monthlyBudget)
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
