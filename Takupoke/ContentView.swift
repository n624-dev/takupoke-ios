import SwiftUI
import Combine

struct ContentView: View {
    private enum Tab: Hashable { case home, links, timetable, settings }

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .home
    @State private var timetableTodayRequest: UUID?
    @StateObject private var application = ApplicationData.shared
    private var dataReady: Bool { application.ready }
    private var loadedPeriod: SchoolDataPeriod? { application.loadedPeriod }
    private var retentionFailure: Bool { application.retentionFailure }
    private var retentionNotice: Bool { application.retentionNotice }
    @AppStorage("setupPresented") private var setupPresented = false
    @State private var showingSetup = false
    @StateObject private var materials = ApplicationData.shared.materials
    @StateObject private var specialSchedules = ApplicationData.shared.specialSchedules
    @StateObject private var schoolEvents = ApplicationData.shared.schoolEvents
    @StateObject private var mappings = ApplicationData.shared.mappings
    @StateObject private var links = ApplicationData.shared.links
    @StateObject private var account = ApplicationData.shared.account
    private let boundaryCheck = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if dataReady { tabs }
            else {
                VStack(spacing: 16) {
                    if retentionFailure {
                        Text("保存データを削除できませんでした。古いデータの利用を停止しています。")
                        Button("再試行") { Task { await activate() } }
                    } else { LoadingRow(title: "読み込み中⋯") }
                }.padding()
            }
        }
        .environmentObject(account)
        .environmentObject(links)
        .environmentObject(mappings)
        .environmentObject(application.notifications)
        .environmentObject(application.times)
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await activate() } }
            else if phase == .background { setFileMonitoring(false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            setFileMonitoring(false)
        }
        .onReceive(boundaryCheck) { _ in
            if scenePhase == .active, loadedPeriod != SchoolDataPeriod.current() {
                Task { await activate() }
            }
        }
        .task { await activate() }
        .onChange(of: dataReady) { ready in
            if !ready { showingSetup = false }
        }
        .onChange(of: materials.ready) { _ in offerSetupIfNeeded() }
        .onChange(of: specialSchedules.ready) { _ in offerSetupIfNeeded() }
        .onChange(of: links.ready) { _ in offerSetupIfNeeded() }
        .onChange(of: mappings.ready) { _ in offerSetupIfNeeded() }
        .fullScreenCover(isPresented: $showingSetup) {
            SetupView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                      mappings: mappings, finish: { setupPresented = true; showingSetup = false })
                .environmentObject(account).environmentObject(links).environmentObject(mappings)
                .environmentObject(application.notifications)
                .environmentObject(application.times)
        }
        .alert("保存データを削除しました", isPresented: $application.retentionNotice) {
            Button("設定する") { showingSetup = true }
            Button("あとで", role: .cancel) { setupPresented = true }
        } message: {
            Text("保存期間が切り替わりました。ファイルの再選択とリンク一覧・名称対応表・授業時刻の再取得が必要です。")
        }
    }

    private func offerSetupIfNeeded() {
        guard dataReady, !retentionNotice, !setupPresented,
              materials.ready, specialSchedules.ready, links.ready, mappings.ready else { return }
        let hasFiles = materials.state.record(for: .timetable) != nil ||
            materials.state.record(for: .changes) != nil || !specialSchedules.sources.isEmpty
        if !hasFiles && links.saved == nil && mappings.current == nil { showingSetup = true }
        else { setupPresented = true }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents) {
                timetableTodayRequest = UUID()
                selectedTab = .timetable
            }
                .tabItem { Label("ホーム", systemImage: "house") }.tag(Tab.home)
            LinksView(model: links)
                .tabItem { Label("一覧", systemImage: "list.bullet") }.tag(Tab.links)
            TimetableView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings, todayRequest: $timetableTodayRequest)
                .tabItem { Label("時間割", systemImage: "calendar") }.tag(Tab.timetable)
            SettingsView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings)
                .tabItem { Label("設定", systemImage: "gearshape") }.tag(Tab.settings)
        }
        .onChange(of: selectedTab) { tab in
            if tab == .links, !account.busy { Task { await links.refresh() } }
        }
    }

    @MainActor private func activate() async {
        await application.activate()
    }

    private func setFileMonitoring(_ foreground: Bool) {
        application.setFileMonitoring(foreground)
        if !foreground { BackgroundRefresh.schedule() }
    }
}
