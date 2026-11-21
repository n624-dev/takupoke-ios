import Foundation
#if canImport(SwiftUI)
import SwiftUI
import Combine
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
    func color(for scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color? {
        switch self {
        case .systemDefault: return nil
        case .blue: return .blue
        case .yellow:
            if scheme == .dark { return .yellow }
            // Keep the hue near yellow across contrast settings while
            // retaining legibility on the selected tab's light material.
            let red = contrast == .increased ? 89.0 : 102.0
            let green = contrast == .increased ? 85.0 : 97.0
            return Color(.sRGB, red: red / 255, green: green / 255, blue: 0)
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        }
    }

    // Custom text and shapes need a concrete color; use the inherited accent
    // when the user has not selected an override.
    func displayColor(for scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        color(for: scheme, contrast: contrast) ?? .accentColor
    }
    #endif
}

#if canImport(SwiftUI)
@MainActor
final class MainColorModel: ObservableObject {
    @Published private(set) var selection: MainColor
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: MainColor.storageKey)
            .flatMap(MainColor.init(rawValue:)) ?? .systemDefault
    }

    func select(_ color: MainColor) {
        color.save(in: defaults)
        selection = color
    }
}

@MainActor
struct MainColorScope: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @StateObject private var model = MainColorModel()

    func body(content: Content) -> some View {
        content.environmentObject(model).tint(model.selection.color(for: scheme, contrast: contrast))
    }
}

@available(macOS 14.0, *)
struct WeekControlAccent: ShapeStyle {
    let theme: MainColor

    func resolve(in environment: EnvironmentValues) -> Color {
        theme.displayColor(for: environment.colorScheme, contrast: environment.colorSchemeContrast)
    }
}
#endif
