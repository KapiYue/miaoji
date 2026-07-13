import SwiftUI

struct ContentView: View {
    @State private var selection: AppTab = .home
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        ZStack {
            AppBackground()
            Group {
                switch selection {
                case .home: HomeView()
                case .statistics: StatisticsView()
                case .history: HistoryView()
                case .settings: SettingsView(isDarkMode: $isDarkMode)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $selection)
        }
        .tint(Palette.primary)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppStore())
            .previewDisplayName("ContentView")
    }
}
