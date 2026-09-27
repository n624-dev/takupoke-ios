import SwiftUI

struct HomeView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    let openTimetable: () -> Void
    @EnvironmentObject private var links: LinksModel
    @State private var safariPage: SafariPage?

    var body: some View {
        NavigationStack {
            List {
                HomeTodayView(materials: materials, specialSchedules: specialSchedules,
                              schoolEvents: schoolEvents, openTimetable: openTimetable)
                if !links.visibleFavorites.isEmpty {
                    Section("お気に入り") {
                        ForEach(links.visibleFavorites) { item in
                            LinkRow(item: item, model: links) { safariPage = SafariPage(url: $0) }
                        }
                    }
                }
                if !links.visibleRecommendations.isEmpty {
                    Section("おすすめ") {
                        ForEach(links.visibleRecommendations) { item in
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
