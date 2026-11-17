import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum MainColor: String, CaseIterable, Identifiable {
    case systemDefault = "default"
    case blue, green, yellow, orange, red, pink, purple

    static let storageKey = "mainColor"

    func save(in defaults: UserDefaults = .standard) {
        if self == .systemDefault {
            defaults.removeObject(forKey: Self.storageKey)
        } else {
            defaults.set(rawValue, forKey: Self.storageKey)
        }
    }

    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemDefault: return "デフォルト"
        case .blue: return "青"
        case .yellow: return "黄色"
        case .green: return "緑"
        case .orange: return "オレンジ"
        case .red: return "赤"
        case .pink: return "ピンク"
        case .purple: return "紫"
        }
    }
    #if canImport(SwiftUI)
    var color: Color? {
        switch self {
        case .systemDefault: return nil
        case .blue: return .blue
        case .yellow: return .yellow
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        }
    }

    // Custom text and shapes need a concrete color; use the inherited accent
    // when the user has not selected an override.
    var displayColor: Color { color ?? .accentColor }
    #endif
}

#if canImport(SwiftUI)
@available(macOS 14.0, *)
struct WeekControlAccent: ShapeStyle {
    let theme: MainColor

    func resolve(in environment: EnvironmentValues) -> Color {
        color(in: environment, increasedContrast: environment.colorSchemeContrast == .increased)
    }

    func color(in environment: EnvironmentValues, increasedContrast: Bool) -> Color {
        let value = theme.displayColor.resolve(in: environment)
        let red = Double(value.linearRed), green = Double(value.linearGreen), blue = Double(value.linearBlue)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let ratio = increasedContrast ? 7.0 : 4.5
        let dark = environment.colorScheme == .dark
        // Allow for the neutral glass being darker than white or lighter than black.
        let surface = dark ? 0.06 : 0.75
        let limit = dark ? (surface + 0.05) * ratio - 0.05 : (surface + 0.05) / ratio - 0.05
        let weight: Double
        if dark && luminance < limit { weight = (limit - luminance) / (1 - luminance) }
        else if !dark && luminance > limit { weight = 1 - limit / luminance }
        else { return theme.displayColor }
        let target: Double = dark ? 1 : 0
        func adjusted(_ component: Double) -> Double { component + (target - component) * weight }
        return Color(.sRGBLinear, red: adjusted(red), green: adjusted(green), blue: adjusted(blue))
    }
}
#endif
