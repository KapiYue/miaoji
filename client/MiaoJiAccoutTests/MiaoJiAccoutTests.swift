//
//  MiaoJiAccoutTests.swift
//  MiaoJiAccoutTests
//
//  Created by 清眸 on 2026/6/9.
//

import Testing
import Foundation
import AVFoundation
@testable import MiaoJiAccout

struct MiaoJiAccoutTests {

    @Test func emailOTPValidationSupportsConfiguredLengthsAndLeadingZeros() {
        #expect(EmailOTPCode.isValid("123456"))
        #expect(EmailOTPCode.isValid("00147955"))
        #expect(EmailOTPCode.isValid("1234567890"))
        #expect(!EmailOTPCode.isValid("12345"))
        #expect(EmailOTPCode.normalized("00 147-955") == "00147955")
    }

    @Test @MainActor func aiParsedExpenseDecodesServerPayload() throws {
        let categoryID = UUID()
        let payload = """
        {"amount":45.5,"title":"午餐","category_id":"\(categoryID.uuidString)","category_name":"餐饮"}
        """.data(using: .utf8)!

        let expense = try JSONDecoder().decode(AIParsedExpense.self, from: payload)

        #expect(expense.amount == 45.5)
        #expect(expense.title == "午餐")
        #expect(expense.categoryID == categoryID)
        #expect(expense.categoryName == "餐饮")
    }

    @Test @MainActor func csvExportContainsAllLocalData() throws {
        let suiteName = "MiaoJiAccoutTests.\(UUID().uuidString)"
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

        let csvData = store.csvData(isDarkMode: false)
        #expect(csvData.starts(with: [0xEF, 0xBB, 0xBF]))
        let csv = try #require(String(data: Data(csvData.dropFirst(3)), encoding: .utf8))

        #expect(csv.hasPrefix("\"data_type\""))
        #expect(csv.contains("\"setting\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"currency\",\"usd\""))
        #expect(csv.contains("\"dark_mode\",\"false\""))
        #expect(csv.contains("\"category\",\"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\""))
        #expect(csv.contains("\"餐饮,聚会\""))
        #expect(csv.contains("\"record\",\"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\""))
        #expect(csv.contains("\"42.30\""))
        #expect(csv.contains("\"晚餐 \"\"聚会\"\"\""))
        #expect(csv.contains("\"第一行\n第二行\""))
    }

    @Test func m4aRecorderCanBeCreated() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("miaoji-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = try AVAudioRecorder(
            url: url,
            settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )

        #expect(recorder.url.pathExtension == "m4a")
    }

    @Test func incomeRecordKeepsItsType() {
        let record = ExpenseRecord(
            amount: 100,
            title: "退款",
            note: "",
            categoryID: UUID(),
            type: .income
        )

        #expect(record.recordType == .income)
    }

}
