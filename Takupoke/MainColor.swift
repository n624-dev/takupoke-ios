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
    @StateObject private var model = MainColorModel()

    func body(content: Content) -> some View {
        content.environmentObject(model).tint(model.selection.color)
    }
}

@available(macOS 14.0, *)
struct WeekControlAccent: ShapeStyle {
    let theme: MainColor

    func resolve(in environment: EnvironmentValues) -> Color {
        // Preserve the selected system color, including its appearance and contrast
        // variants. A guessed glass luminance must not turn orange into brown.
        theme.displayColor
    }
}
#endif
