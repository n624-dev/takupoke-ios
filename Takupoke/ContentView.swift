import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case home, links, timetable, settings }

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Tab = .home
    @State private var dataReady = false
    @State private var checkingPeriod = false
    @State private var loadedPeriod: SchoolDataPeriod?
    @State private var retentionFailure = false
    @State private var retentionNotice = false
    @StateObject private var materials = MaterialsModel()
    @StateObject private var specialSchedules = SpecialSchedulesModel()
    @StateObject private var schoolEvents = SchoolEventsModel()
    @StateObject private var mappings = MappingModel()
    @StateObject private var links = LinksModel()
    @StateObject private var account = AccountDataModel()
    private let boundaryCheck = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if dataReady { tabs }
            else {
                VStack(spacing: 16) {
                    if retentionFailure {
                        Text("保存データを削除できませんでした。古いデータの利用を停止しています。")
                        Button("再試行") { Task { await activate() } }
                    } else { ProgressView("保存期間を確認中⋯") }
                }.padding()
            }
        }
        .environmentObject(account)
        .environmentObject(links)
        .environmentObject(mappings)
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
        .alert("保存データを削除しました", isPresented: $retentionNotice) {
            Button("確認", role: .cancel) { }
        } message: {
            Text("保存期間の切替により、学校ファイル・解析結果・名称対応表・一覧を削除しました。ファイルを選び直し、一覧・名称対応表を認証して再取得してください。個人設定とOneDrive上の原本は保持しています。今回の更新の初回にもこの処理を行います。")
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }.tag(Tab.home)
            LinksView(model: links)
                .tabItem { Label("一覧", systemImage: "list.bullet") }.tag(Tab.links)
            TimetableView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings)
                .tabItem { Label("時間割", systemImage: "calendar") }.tag(Tab.timetable)
            SettingsView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings)
                .tabItem { Label("設定", systemImage: "gearshape") }.tag(Tab.settings)
        }
        .onChange(of: selectedTab) { tab in
            if tab == .links { Task { await links.refresh() } }
        }
    }

    @MainActor private func activate() async {
        guard !checkingPeriod else { return }
        checkingPeriod = true
        defer { checkingPeriod = false }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
            let retention = SchoolDataRetention(root: base)
            let period = SchoolDataPeriod.current()
            if (try? retention.installedPeriod()) != period {
                let hadPrivateData = SchoolDataRetention.privatePaths.contains {
                    FileManager.default.fileExists(atPath: base.appendingPathComponent($0).path)
                }
                // Remove all data-bearing views before waiting for workers/auth to stop.
                dataReady = false
                setFileMonitoring(false)
                await account.stopForRetention()
                await materials.closeForRetention()
                await specialSchedules.closeForRetention()
                mappings.resetForRetention()
                links.resetForRetention()
                try retention.replace(with: period)
                FileRefreshDiagnostics.shared.clear()
                materials.resumeAfterRetention()
                specialSchedules.resumeAfterRetention()
                retentionNotice = hadPrivateData
            }
            loadedPeriod = period
            retentionFailure = false
            dataReady = true
            materials.loadIfNeeded()
            specialSchedules.loadIfNeeded()
            schoolEvents.refreshAtStartup()
            mappings.checkAtStartup()
            if scenePhase != .background { setFileMonitoring(true) }
            await links.refresh()
        } catch {
            dataReady = false
            retentionFailure = true
        }
    }

    private func setFileMonitoring(_ foreground: Bool) {
        materials.setFileMonitoring(foreground && dataReady)
        specialSchedules.setFileMonitoring(foreground && dataReady)
    }
}
