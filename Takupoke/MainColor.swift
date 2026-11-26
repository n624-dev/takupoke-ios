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
