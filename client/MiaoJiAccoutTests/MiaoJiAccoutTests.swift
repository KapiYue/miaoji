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

    @Test func voiceTranscriptParsesAmountTitleAndCategory() throws {
        let foodID = UUID()
        let categories = [
            ExpenseCategory(id: foodID, name: "餐饮", icon: "fork.knife", colorIndex: 0),
            ExpenseCategory(name: "交通", icon: "tram.fill", colorIndex: 1)
        ]

        let draft = VoiceEntryParser.parse("午餐花了45.5元，餐饮", categories: categories)

        #expect(draft.amount == 45.5)
        #expect(draft.title == "午餐")
        #expect(draft.categoryID == foodID)
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

    @Test func m4aRecorderCanBePrepared() throws {
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

        #expect(recorder.prepareToRecord())
        #expect(recorder.url.pathExtension == "m4a")
    }

}
