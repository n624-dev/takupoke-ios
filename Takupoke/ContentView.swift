import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case home, links, timetable, settings }

    @State private var selectedTab: Tab = .home
    @StateObject private var materials = MaterialsModel()
    @StateObject private var specialSchedules = SpecialSchedulesModel()
    @StateObject private var schoolEvents = SchoolEventsModel()
    @StateObject private var mappings = MappingModel()
    @StateObject private var links = LinksModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(Tab.home)
            LinksView(model: links)
                .tabItem { Label("一覧", systemImage: "list.bullet") }
                .tag(Tab.links)
            TimetableView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                          mappings: mappings)
                .tabItem { Label("時間割", systemImage: "calendar") }
                .tag(Tab.timetable)
            SettingsView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                         mappings: mappings)
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { tab in
            if tab == .links { Task { await links.refresh() } }
        }
        .onChange(of: materials.ready) { ready in
            if ready { materials.checkSelectedFilesAtStartup() }
        }
        .onChange(of: specialSchedules.ready) { ready in
            if ready { specialSchedules.checkSelectedFilesAtStartup() }
        }
        .task {
            materials.loadIfNeeded()
            specialSchedules.loadIfNeeded()
            schoolEvents.refreshAtStartup()
            mappings.checkAtStartup()
        }
    }
}
