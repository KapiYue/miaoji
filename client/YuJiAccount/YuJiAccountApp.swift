//
//  YuJiAccountApp.swift
//  YuJiAccount
//
//  Created by 清眸 on 2026/6/9.
//

import SwiftUI

@main
struct YuJiAccountApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
