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

    private let key = "VoiceAccount.localData.v1"
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
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

    func csvData() -> Data {
        var lines = ["id,date,type,amount,currency,title,category,note"]
        let formatter = ISO8601DateFormatter()
        for record in records.sorted(by: { $0.date < $1.date }) {
            let values = [record.id.uuidString, formatter.string(from: record.date), record.recordType.rawValue, String(format: "%.2f", record.amount), currency.code, record.title, category(for: record.categoryID)?.name ?? "", record.note]
            lines.append(values.map(Self.csvEscape).joined(separator: ","))
        }
        return ("\u{FEFF}" + lines.joined(separator: "\r\n")).data(using: .utf8) ?? Data()
    }

    private static func csvEscape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func save() {
        guard !isLoading else { return }
        let value = StoredData(records: records, categories: categories, currency: currency, voiceRecognition: voiceRecognition, budgetReminder: budgetReminder, monthlyBudget: monthlyBudget)
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}
