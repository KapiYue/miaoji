//
//  VoiceAccoutTests.swift
//  VoiceAccoutTests
//
//  Created by 清眸 on 2026/6/9.
//

import Testing
import Foundation
@testable import VoiceAccout

struct VoiceAccoutTests {

    @Test @MainActor func csvExportContainsAllLocalData() throws {
        let suiteName = "VoiceAccoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppStore(defaults: defaults)
        let category = ExpenseCategory(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "餐饮,聚会", icon: "fork.knife", colorIndex: 2, budget: 888.5
        )
        let record = ExpenseRecord(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            amount: 42.3, title: "晚餐 \"聚会\"", note: "第一行\n第二行", categoryID: category.id,
            date: Date(timeIntervalSince1970: 0), type: .expense
        )
        store.categories = [category]
        store.records = [record]
        store.currency = .usd
        store.voiceRecognition = false
        store.budgetReminder = true
        store.monthlyBudget = 3210.5

        let csv = try #require(String(data: store.csvData(isDarkMode: false), encoding: .utf8))

        #expect(csv.hasPrefix("\u{FEFF}\"data_type\""))
        #expect(csv.contains("\"setting\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"currency\",\"usd\""))
        #expect(csv.contains("\"dark_mode\",\"false\""))
        #expect(csv.contains("\"category\",\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\""))
        #expect(csv.contains("\"餐饮,聚会\""))
        #expect(csv.contains("\"record\",\"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\""))
        #expect(csv.contains("\"42.30\""))
        #expect(csv.contains("\"晚餐 \"\"聚会\"\"\""))
        #expect(csv.contains("\"第一行\n第二行\""))
    }

}
