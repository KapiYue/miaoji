import SwiftUI
import UIKit

enum AppTab: CaseIterable {
    case home, statistics, history, settings

    var title: String {
        switch self {
        case .home: "记账"
        case .statistics: "统计"
        case .history: "历史"
        case .settings: "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .statistics: "chart.bar"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "house.fill"
        case .statistics: "chart.bar.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }
}

enum Palette {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static let background = adaptive(light: UIColor(red: 255/255, green: 238/255, blue: 207/255, alpha: 1), dark: UIColor(red: 7/255, green: 17/255, blue: 31/255, alpha: 1))
    static let backgroundMiddle = adaptive(light: UIColor(red: 255/255, green: 211/255, blue: 192/255, alpha: 1), dark: UIColor(red: 13/255, green: 27/255, blue: 47/255, alpha: 1))
    static let background2 = adaptive(light: UIColor(red: 252/255, green: 194/255, blue: 201/255, alpha: 1), dark: UIColor(red: 20/255, green: 37/255, blue: 62/255, alpha: 1))
    static let text = adaptive(light: UIColor(red: 20/255, green: 32/255, blue: 48/255, alpha: 1), dark: UIColor(red: 244/255, green: 247/255, blue: 251/255, alpha: 1))
    static let muted = adaptive(light: UIColor(red: 90/255, green: 107/255, blue: 128/255, alpha: 1), dark: UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1))
    static let surfaceTop = adaptive(light: UIColor(red: 255/255, green: 251/255, blue: 247/255, alpha: 1), dark: UIColor(red: 18/255, green: 28/255, blue: 46/255, alpha: 1))
    static let surfaceBottom = adaptive(light: UIColor(red: 255/255, green: 244/255, blue: 244/255, alpha: 1), dark: UIColor(red: 10/255, green: 18/255, blue: 31/255, alpha: 1))
    static let soft = adaptive(light: UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.68), dark: UIColor(white: 1, alpha: 0.04))
    static let line = adaptive(light: UIColor(red: 156/255, green: 91/255, blue: 88/255, alpha: 0.13), dark: UIColor(white: 1, alpha: 0.08))
    static let primary = Color(red: 125/255, green: 211/255, blue: 252/255)
    static let accent = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let success = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let pink = Color(red: 251/255, green: 113/255, blue: 133/255)
    static let voiceActionTop = adaptive(light: UIColor(red: 103/255, green: 118/255, blue: 226/255, alpha: 1), dark: UIColor(red: 20/255, green: 36/255, blue: 61/255, alpha: 1))
    static let voiceActionBottom = adaptive(light: UIColor(red: 119/255, green: 73/255, blue: 180/255, alpha: 1), dark: UIColor(red: 18/255, green: 61/255, blue: 80/255, alpha: 1))
    static let manualActionTop = adaptive(light: UIColor(red: 226/255, green: 112/255, blue: 222/255, alpha: 1), dark: UIColor(red: 54/255, green: 24/255, blue: 50/255, alpha: 1))
    static let manualActionBottom = adaptive(light: UIColor(red: 247/255, green: 79/255, blue: 128/255, alpha: 1), dark: UIColor(red: 84/255, green: 31/255, blue: 50/255, alpha: 1))
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.background, Palette.backgroundMiddle, Palette.background2], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.primary.opacity(0.14)).frame(width: 330, height: 330).blur(radius: 60).offset(x: 170, y: -360)
            Circle().fill(Palette.accent.opacity(0.18)).frame(width: 330, height: 330).blur(radius: 70).offset(x: -170, y: 390)
            Circle().fill(Palette.pink.opacity(0.12)).frame(width: 260, height: 260).blur(radius: 70).offset(x: -190, y: 90)
        }
        .ignoresSafeArea()
    }
}

struct Screen<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) { content }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity)
        }
    }
}

struct Hero<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let pill: String
    var showsContainer = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(showsContainer ? 18 : 0)
        .background {
            if showsContainer {
                ZStack {
                    LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom)
                    Circle().fill(Palette.primary.opacity(0.15)).frame(width: 170).blur(radius: 24).offset(x: -150, y: -100)
                    Circle().fill(Palette.accent.opacity(0.13)).frame(width: 220).blur(radius: 28).offset(x: 150, y: 130)
                }.clipShape(RoundedRectangle(cornerRadius: 34))
            }
        }
        .overlay { if showsContainer { RoundedRectangle(cornerRadius: 34).stroke(Palette.line) } }
        .shadow(color: .black.opacity(showsContainer ? 0.35 : 0), radius: 30, y: 16)
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(padding)
            .background(LinearGradient(colors: [Palette.surfaceTop, Palette.surfaceBottom], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.line))
            .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if let trailing { Pill(trailing) }
        }
    }
}

struct Pill: View {
    let text: String
    var primary: Bool = false
    init(_ text: String, primary: Bool = false) { self.text = text; self.primary = primary }
    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.text.opacity(0.92))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(primary ? Palette.primary.opacity(0.14) : Palette.soft)
            .clipShape(Capsule()).overlay(Capsule().stroke(Palette.line))
    }
}

struct MetricsRow: View {
    let metrics: [(String, String)]
    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.0).font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Text(metric.1).font(.system(size: 16, weight: .bold)).lineLimit(1).minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 13)
                .background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
            }
        }
    }
}

enum BadgeColor { case blue, green, purple, amber, pink, cyan
    static func from(_ index: Int) -> BadgeColor { [.blue, .green, .purple, .amber, .pink, .cyan][abs(index) % 6] }
    var colors: [Color] {
        switch self {
        case .blue: [Color(red: 56/255, green: 189/255, blue: 248/255), Color(red: 37/255, green: 99/255, blue: 235/255)]
        case .green: [Palette.success, Color(red: 5/255, green: 150/255, blue: 105/255)]
        case .purple: [Color(red: 167/255, green: 139/255, blue: 250/255), Color(red: 124/255, green: 58/255, blue: 237/255)]
        case .amber: [Palette.accent, Color(red: 249/255, green: 115/255, blue: 22/255)]
        case .pink: [Palette.pink, Color(red: 190/255, green: 24/255, blue: 93/255)]
        case .cyan: [Color(red: 34/255, green: 211/255, blue: 238/255), Color(red: 15/255, green: 118/255, blue: 110/255)]
        }
    }
}

struct Badge: View {
    let text: String
    let color: BadgeColor
    var size: CGFloat = 42
    var body: some View {
        Text(text).font(.system(size: size * 0.36, weight: .heavy)).foregroundStyle(.white).frame(width: size, height: size)
            .background(LinearGradient(colors: color.colors, startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: size / 3))
    }
}

struct ExpenseRow: View {
    let badge: String
    let color: BadgeColor
    let title: String
    let meta: String
    let amount: String
    let note: String
    var body: some View {
        HStack(spacing: 12) {
            Badge(text: badge, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(meta).font(.system(size: 12)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount).font(.system(size: 16, weight: .bold))
                Text(note).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
        }
        .padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    }
}


extension View {
    func softRow() -> some View { self.padding(14).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line)) }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(LinearGradient(colors: [Palette.primary, Palette.accent.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                                    .shadow(color: Palette.primary.opacity(0.25), radius: 8, y: 3)
                            }
                            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(isSelected ? Color(red: 5/255, green: 17/255, blue: 29/255) : Palette.muted)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .frame(width: 44, height: 27)

                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? Palette.text : Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(.ultraThinMaterial).background(Palette.surfaceTop.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line)).shadow(color: .black.opacity(0.18), radius: 20, y: 10)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4).frame(maxWidth: 430)
    }
}

struct GradientButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(red: 5/255, green: 17/255, blue: 29/255)).frame(maxWidth: compact ? nil : .infinity).padding(.horizontal, compact ? 14 : 16).padding(.vertical, 13)
            .background(LinearGradient(colors: [Palette.primary, Palette.accent], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 18)).opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var fullWidth = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.text).frame(maxWidth: fullWidth ? .infinity : nil).padding(.horizontal, 16).padding(.vertical, 13).background(Palette.soft).clipShape(RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 13).background(LinearGradient(colors: [Color(red: 248/255, green: 113/255, blue: 113/255), Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

