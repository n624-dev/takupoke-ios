import SwiftUI

enum MainColor: String, CaseIterable, Identifiable {
    case blue, green, yellow, orange, red, pink, purple

    var id: String { rawValue }
    var title: String {
        switch self {
        case .blue: return "青"
        case .yellow: return "黄色"
        case .green: return "緑"
        case .orange: return "オレンジ"
        case .red: return "赤"
        case .pink: return "ピンク"
        case .purple: return "紫"
        }
    }
    var color: Color {
        switch self {
        case .blue: return .blue
        case .yellow: return .yellow
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .purple: return .purple
        }
    }
}
