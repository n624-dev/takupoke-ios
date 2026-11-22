import SafariServices
import SwiftUI

private struct VisibleLinkCategory: Identifiable {
    let category: LinkCategory
    let items: [LinkItem]
    var id: String { category.id }
}

struct LinksView: View {
    private struct SearchRequest: Equatable {
        let query: String
        let revision: UUID
        let hidden: Set<String>
    }

    @EnvironmentObject private var account: AccountDataModel
    @EnvironmentObject private var mappings: MappingModel
    @ObservedObject var model: LinksModel
    @State private var safariPage: SafariPage?
    @State private var linkActionOwner = UUID()
    @State private var query = ""
    @State private var completedSearch: (request: SearchRequest, hits: [LinkSearch.Hit])?

    private var visibleCategories: [VisibleLinkCategory] {
        (model.saved?.payload.categories ?? []).compactMap { category in
            let items = category.buttons.filter { $0.visible && !model.isHidden($0.id) }
            return items.isEmpty ? nil : VisibleLinkCategory(category: category, items: items)
        }
    }

    var body: some View {
        let request = SearchRequest(query:LinkSearch.normalize(query),revision:model.searchRevision,
                                    hidden:model.preferences.hiddenIDs)
        NavigationStack {
            List {
                LinksPreferencesWarning(model: model)
                if model.saved == nil {
                    Section {
                        if model.busy || account.busy { LoadingRow(title: "一覧を取得中⋯") }
                        else {
                            if model.failed {
                                InlineWarning("一覧を取得できませんでした。")
                            } else {
                                Text("一覧はまだ取得されていません。").foregroundStyle(.secondary)
                            }
                            NavigationLink("リンク一覧を取得") { AccountDataSettingsView() }
                        }
                    }
                } else if request.query.isEmpty {
                    ForEach(visibleCategories) { entry in
                        Section(entry.category.label) {
                            ForEach(entry.items) { item in
                                LinkRow(item: item, model: model, actionOwner: linkActionOwner) { safariPage = SafariPage(url: $0) }.equatable()
                            }
                        }
                    }
                    if visibleCategories.isEmpty {
                        Section { Text("表示できるリンクがありません。").foregroundStyle(.secondary) }
                    }
                } else {
                    Section("検索結果") {
                        if let completedSearch, completedSearch.request == request {
                            if completedSearch.hits.isEmpty {
                                Text("該当するリンクがありません。").foregroundStyle(.secondary)
                            } else {
                                ForEach(completedSearch.hits) { hit in
                                    LinkRow(item: hit.item, subtitle: hit.category, model: model, actionOwner: linkActionOwner) {
                                        safariPage = SafariPage(url: $0)
                                    }.equatable()
                                }
                            }
                        } else {
                            ProgressView("検索中⋯")
                        }
                    }
                }
            }
            .navigationTitle("一覧")
            .searchable(text: $query, prompt: "リンクを検索")
            .task(id:request) {
                guard !request.query.isEmpty else { completedSearch = nil; return }
                guard completedSearch?.request != request else { return }
                guard let hits = await model.search(normalizedQuery:request.query,revision:request.revision,excluding:request.hidden),
                      !Task.isCancelled else { return }
                completedSearch = (request, hits)
            }
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

struct LinksPreferencesWarning: View {
    @ObservedObject var model: LinksModel
    var body: some View {
        if let message = model.preferencesError {
            Section("一覧の個人設定") {
                InlineWarning(message)
                Button("一覧の個人設定を再読み込み") { model.reloadPreferences() }
            }
        }
    }
}
