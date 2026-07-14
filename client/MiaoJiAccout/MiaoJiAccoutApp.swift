//
//  MiaoJiAccoutApp.swift
//  MiaoJiAccout
//
//  Created by 清眸 on 2026/6/9.
//

import SwiftUI

@main
struct MiaoJiAccoutApp: App {
    @StateObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let screenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshot-demo-data")
        if screenshotMode { UserDefaults.standard.set(false, forKey: "isDarkMode") }
        _store = StateObject(
            wrappedValue: AppStore(
                syncService: screenshotMode ? nil : SupabaseSyncService.configured(),
                demoData: screenshotMode
            )
        )
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refreshFromCloud() }
        }
    }
}
