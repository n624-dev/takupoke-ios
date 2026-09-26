import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var links: LinksModel
    @State private var safariPage: SafariPage?

    var body: some View {
        NavigationStack {
            List {
                if !links.visibleFavorites.isEmpty {
                    Section("お気に入り") {
                        ForEach(links.visibleFavorites) { item in
                            LinkRow(item: item, model: links) { safariPage = SafariPage(url: $0) }
                        }
                    }
                }
            }
            .navigationTitle("たくポケ")
            .fullScreenCover(item: $safariPage) { page in
                SafariLinkView(url: page.url) { safariPage = nil }.ignoresSafeArea()
            }
        }
    }
}
