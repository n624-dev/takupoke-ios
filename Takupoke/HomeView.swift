import SwiftUI

struct HomeView: View {
    private enum Destination: Hashable { case accountData }
    @EnvironmentObject private var times: TimetableTimesModel
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    let openTimetable: () -> Void
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var mappings: MappingModel
    @State private var safariPage: SafariPage?

    var body: some View {
        NavigationStack {
            List {
                if let notice = updateNotice {
                    Section {
                        NavigationLink(value: Destination.accountData) {
                            Label(notice, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
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
            .navigationDestination(for: Destination.self) { _ in AccountDataSettingsView() }
            .fullScreenCover(item: $safariPage) { page in
                SafariLinkView(url: page.url) { safariPage = nil }.ignoresSafeArea()
            }
        }
    }

    private var updateNotice: String? {
        let linksUpdated = links.saved != nil && links.updateAvailable
        let mappingsUpdated = mappings.current != nil && mappings.updateAvailable
        if times.updateAvailable {
            let names = [(linksUpdated, "一覧"), (mappingsUpdated, "名称データ"), (true, "授業時刻")]
                .filter { $0.0 }.map { $0.1 }.joined(separator: "・")
            return "\(names)に更新があります"
        }
        switch (linksUpdated, mappingsUpdated) {
        case (true, true): return "一覧・名称データに更新があります"
        case (true, false): return "一覧に更新があります"
        case (false, true): return "名称データに更新があります"
        case (false, false): return nil
        }
    }
}
