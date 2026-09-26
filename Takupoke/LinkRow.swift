import SwiftUI

private enum LinkPalette {
    static let names: [(id: String, label: String)] = [
        ("sky", "スカイ"), ("blue", "ブルー"), ("emerald", "エメラルド"),
        ("green", "グリーン"), ("amber", "アンバー"), ("yellow", "イエロー"),
        ("orange", "オレンジ"), ("rose", "ローズ"), ("red", "レッド"),
        ("indigo", "インディゴ"), ("purple", "パープル"), ("pink", "ピンク"),
        ("teal", "ティール"), ("slate", "スレート"), ("gray", "グレー")
    ]

    static func color(_ id: String) -> Color {
        switch id {
        case "sky": return Color(red: 0.08, green: 0.65, blue: 0.91)
        case "blue": return .blue
        case "emerald": return Color(red: 0.02, green: 0.64, blue: 0.43)
        case "green": return .green
        case "amber": return Color(red: 0.85, green: 0.50, blue: 0.03)
        case "yellow": return .yellow
        case "orange": return .orange
        case "rose": return Color(red: 0.88, green: 0.25, blue: 0.38)
        case "red": return .red
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "slate": return Color(red: 0.38, green: 0.44, blue: 0.54)
        default: return .gray
        }
    }
}

struct LinkRow: View {
    let item: LinkItem
    var subtitle: String? = nil
    @ObservedObject var model: LinksModel
    let openInApp: (URL) -> Void
    @AppStorage("linkOpeningMode") private var linkOpeningMode = LinkOpeningMode.external.rawValue
    @Environment(\.openURL) private var openURL
    @State private var openFailed = false

    private var preferredMode: LinkOpeningMode {
        LinkOpeningMode(rawValue: linkOpeningMode) ?? .external
    }

    private func open(opposite: Bool = false) {
        guard let url = item.url else { openFailed = true; return }
        switch preferredMode.destination(for: url, opposite: opposite) {
        case .inApp:
            openInApp(url)
        case .external:
            openURL(url) { accepted in
                if !accepted { DispatchQueue.main.async { openFailed = true } }
            }
        }
    }

    var body: some View {
        Button { open() } label: {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(LinkPalette.color(model.color(for: item)), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 4)
                if model.isFavorite(item.id) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel("お気に入り")
                }
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if item.url?.scheme?.lowercased() == "https" {
                Button {
                    open(opposite: true)
                } label: {
                    Label(preferredMode == .external ? "アプリ内で開く" : "外部で開く",
                          systemImage: preferredMode == .external ? "safari" : "arrow.up.right.square")
                }
            }
            if model.preferencesReady {
                Button {
                    model.toggleFavorite(item.id)
                } label: {
                    Label(model.isFavorite(item.id) ? "お気に入りを解除" : "お気に入りに追加",
                          systemImage: model.isFavorite(item.id) ? "star.slash" : "star")
                }
                Menu {
                    ForEach(LinkPalette.names.indices, id: \.self) { index in
                        let entry = LinkPalette.names[index]
                        Button(entry.label) { model.setColor(entry.id, for: item.id) }
                    }
                    if model.preferences.colorOverrides[item.id] != nil {
                        Button("既定色に戻す") { model.setColor(nil, for: item.id) }
                    }
                } label: {
                    Label("色を変更", systemImage: "paintpalette")
                }
                Button(role: .destructive) { model.hide(item.id) } label: {
                    Label("非表示", systemImage: "eye.slash")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if model.preferencesReady {
                Button(role: .destructive) { model.hide(item.id) } label: {
                    Label("非表示", systemImage: "eye.slash")
                }
                Button {
                    model.toggleFavorite(item.id)
                } label: {
                    Label(model.isFavorite(item.id) ? "解除" : "お気に入り",
                          systemImage: model.isFavorite(item.id) ? "star.slash" : "star")
                }
                .tint(.yellow)
            }
        }
        .alert("リンクを開けませんでした", isPresented: $openFailed) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("対応するアプリが入っているか確認してください。")
        }
    }
}
