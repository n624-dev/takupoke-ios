import SafariServices
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

private struct LinkSearchHit: Identifiable {
    let item: LinkItem
    let category: String
    let score: Int
    let position: Int
    var id: String { item.id }
}

private struct VisibleLinkCategory: Identifiable {
    let category: LinkCategory
    let items: [LinkItem]
    var id: String { category.id }
}

struct LinksView: View {
    @ObservedObject var model: LinksModel
    @State private var safariPage: SafariPage?
    @State private var query = ""

    private var visibleCategories: [VisibleLinkCategory] {
        (model.saved?.payload.categories ?? []).compactMap { category in
            let items = category.buttons.filter { $0.visible && !model.isHidden($0.id) }
            return items.isEmpty ? nil : VisibleLinkCategory(category: category, items: items)
        }
    }

    private var favorites: [LinkItem] {
        visibleCategories.flatMap(\.items).filter { model.isFavorite($0.id) }
    }

    private var searchHits: [LinkSearchHit] {
        var position = 0
        return visibleCategories.flatMap { entry in
            entry.items.compactMap { item -> LinkSearchHit? in
                defer { position += 1 }
                let score = LinkSearch.score(terms: item.searchTerms, query: query)
                return score < 0 ? nil : LinkSearchHit(item: item, category: entry.category.label,
                                                       score: score, position: position)
            }
        }.sorted { $0.score == $1.score ? $0.position < $1.position : $0.score > $1.score }
    }

    var body: some View {
        NavigationStack {
            List {
                if let message = model.message {
                    Section {
                        Label(message, systemImage: model.failed ? "exclamationmark.triangle" : "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                    }
                }
                if model.saved == nil {
                    Section {
                        if model.busy { ProgressView("一覧を取得中…") }
                        else {
                            Text(model.failed ? "一覧を取得できませんでした。" : "一覧はまだ取得されていません。")
                                .foregroundStyle(.secondary)
                            Button("再試行") { Task { await model.refresh(force: true) } }
                        }
                    }
                } else if LinkSearch.normalize(query).isEmpty {
                    if !favorites.isEmpty {
                        Section("お気に入り") {
                            ForEach(favorites) { item in
                                LinkRow(item: item, model: model) { safariPage = SafariPage(url: $0) }
                            }
                        }
                    }
                    ForEach(visibleCategories) { entry in
                        Section(entry.category.label) {
                            ForEach(entry.items) { item in
                                LinkRow(item: item, model: model) { safariPage = SafariPage(url: $0) }
                            }
                        }
                    }
                    if visibleCategories.isEmpty {
                        Section { Text("表示できるリンクがありません。").foregroundStyle(.secondary) }
                    }
                } else {
                    Section("検索結果") {
                        if searchHits.isEmpty {
                            Text("該当するリンクがありません。").foregroundStyle(.secondary)
                        } else {
                            ForEach(searchHits) { hit in
                                LinkRow(item: hit.item, subtitle: hit.category, model: model) {
                                    safariPage = SafariPage(url: $0)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("一覧")
            .searchable(text: $query, prompt: "リンクを検索")
            .refreshable { await model.refresh(force: true) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        HiddenLinksView(model: model)
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .accessibilityLabel("非表示のリンク")
                }
            }
            .fullScreenCover(item: $safariPage) { page in
                SafariLinkView(url: page.url) { safariPage = nil }
                    .ignoresSafeArea()
            }
        }
    }
}

private struct SafariPage: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariLinkView: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss()
        }
    }
}

private struct LinkRow: View {
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

private struct HiddenLinksView: View {
    @ObservedObject var model: LinksModel

    private var hidden: [LinkItem] {
        (model.saved?.payload.categories ?? []).flatMap(\.buttons)
            .filter { $0.visible && model.isHidden($0.id) }
    }

    var body: some View {
        List {
            if hidden.isEmpty {
                Text("非表示のリンクはありません。").foregroundStyle(.secondary)
            } else {
                ForEach(hidden) { item in
                    HStack {
                        Text(item.label)
                        Spacer()
                        Button("再表示") { model.restore(item.id) }
                            .disabled(!model.preferencesReady)
                    }
                }
            }
        }
        .navigationTitle("非表示のリンク")
    }
}
