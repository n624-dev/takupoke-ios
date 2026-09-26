import SafariServices
import SwiftUI

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
