import SwiftUI

struct ContentView: View {
    @State private var selection: AppTab
    @AppStorage("isDarkMode") private var isDarkMode = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requestedTab: AppTab
        if let flagIndex = arguments.firstIndex(of: "--screenshot-tab"), arguments.indices.contains(flagIndex + 1) {
            switch arguments[flagIndex + 1] {
            case "statistics": requestedTab = .statistics
            case "history": requestedTab = .history
            case "settings": requestedTab = .settings
            default: requestedTab = .home
            }
        } else {
            requestedTab = .home
        }
        _selection = State(initialValue: requestedTab)
    }

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
