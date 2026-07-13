//
//  MiaoJiAccoutApp.swift
//  MiaoJiAccout
//
//  Created by 清眸 on 2026/6/9.
//

import SwiftUI

@main
struct MiaoJiAccoutApp: App {
    @StateObject private var store = AppStore(syncService: SupabaseSyncService.configured())
    @Environment(\.scenePhase) private var scenePhase
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
