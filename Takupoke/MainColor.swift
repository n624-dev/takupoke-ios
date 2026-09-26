import SwiftUI

enum MainColor: String, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green

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

struct MainColorSelectionView: View {
    @AppStorage("mainColor") private var selectedValue = MainColor.blue.rawValue

    var body: some View {
        List(MainColor.allCases) { choice in
            let selected = (MainColor(rawValue: selectedValue) ?? .blue) == choice
            Button {
                selectedValue = choice.rawValue
            } label: {
                HStack(spacing: 12) {
                    Circle().fill(choice.color).frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    Text(choice.title).foregroundStyle(.primary)
                    Spacer()
                    if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                }
                .contentShape(Rectangle())
            }
            .accessibilityAddTraits(selected ? [.isSelected] : [])
        }
        .navigationTitle("メインカラー")
    }
}
