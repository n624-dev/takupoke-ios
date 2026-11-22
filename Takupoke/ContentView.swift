import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    private enum Tab: Hashable { case home, links, timetable, settings }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var mainColor: MainColorModel
    @State private var selectedTab: Tab = .home
    @State private var timetableTodayRequest: UUID?
    @StateObject private var application = ApplicationData.shared
    private var dataReady: Bool { application.ready }
    private var loadedPeriod: SchoolDataPeriod? { application.loadedPeriod }
    private var retentionFailure: Bool { application.retentionFailure }
    private var retentionNotice: Bool { application.retentionNotice }
    @AppStorage("setupPresented") private var setupPresented = false
    @State private var showingSetup = false
    @State private var confirmingRetentionRecovery = false
    @ObservedObject private var notifications = ApplicationData.shared.notifications
    private let materials = ApplicationData.shared.materials
    private let specialSchedules = ApplicationData.shared.specialSchedules
    private let schoolEvents = ApplicationData.shared.schoolEvents
    private let mappings = ApplicationData.shared.mappings
    private let links = ApplicationData.shared.links
    private let account = ApplicationData.shared.account
    private let boundaryCheck = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if dataReady { tabs }
            else {
                VStack(spacing: 16) {
                    if retentionFailure {
                        InlineWarning(application.retentionFailureMessage)
                        if application.canRecoverRetention {
                            Button("保存期間の管理情報を復旧") { confirmingRetentionRecovery = true }
                                .buttonStyle(.bordered)
                        }
                        Button("再試行") { Task { await activate() } }
                    } else { LoadingRow(title: "読み込み中⋯") }
                }.padding()
            }
        }
        .confirmationDialog("学校データを初期化して復旧しますか？", isPresented: $confirmingRetentionRecovery, titleVisibility: .visible) {
            Button("学校データを初期化して復旧", role: .destructive) { Task { await application.recoverRetention() } }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("破損した管理情報を隔離し、保存済みの学校データを削除して保存期間を設定し直します。個人設定・公開行事・OneDriveなどの元ファイルは保持します。資料の再選択と再取得が必要です。")
        }
        .environmentObject(account)
        .environmentObject(links)
        .environmentObject(mappings)
        .environmentObject(application.notifications)
        .environmentObject(application.countdown)
        .environmentObject(application.times)
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await activate() } }
            else if phase == .background { setFileMonitoring(false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            setFileMonitoring(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            if scenePhase == .active { schoolEvents.reevaluate(); application.updateCountdown() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            if scenePhase == .active { Task { await activate() } }
        }
        .onReceive(boundaryCheck) { _ in
            if scenePhase == .active, loadedPeriod != SchoolDataPeriod.current() {
                Task { await activate() }
            }
        }
        .task { await activate() }
        .sheet(item: Binding(get: { dataReady ? notifications.openedCountdown : nil },
                             set: { notifications.openedCountdown = $0 })) { destination in
            NavigationStack {
                CountdownNotificationDestination(destination: destination, events: schoolEvents)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { notifications.openedCountdown = nil } } }
            }
        }
        .onChange(of: dataReady) { ready in
            if !ready { showingSetup = false }
        }
        .onReceive(setupReadiness) { ready in
            if ready {
                // Published emits before the final model assignment.
                Task { @MainActor in offerSetupIfNeeded() }
            }
        }
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
            Text("保存期間が切り替わりました。ファイルの再選択とリンク一覧・名称データ・授業時刻の再取得が必要です。")
        }
    }

    private var setupReadiness: AnyPublisher<Bool,Never> {
        Publishers.CombineLatest4(materials.$ready,specialSchedules.$ready,links.$ready,mappings.$ready)
            .map { $0 && $1 && $2 && $3 }.removeDuplicates().eraseToAnyPublisher()
    }

    private func offerSetupIfNeeded() {
        guard dataReady, !retentionNotice, !setupPresented,
              materials.ready, specialSchedules.ready, links.ready, mappings.ready else { return }
        let hasFiles = materials.state.record(for: .timetable) != nil ||
            materials.state.record(for: .changes) != nil || !specialSchedules.sources.isEmpty
        if !hasFiles && links.saved == nil && mappings.current == nil { showingSetup = true }
        else { setupPresented = true }
    }

    private var tabContentTint: Color? {
        mainColor.selection.color(for: colorScheme, contrast: colorSchemeContrast)
    }

    @ViewBuilder private func tabLabel(_ title: LocalizedStringKey, symbol: String, tab: Tab,
                                      selectedSymbol: String? = nil) -> some View {
        if selectedTab == tab, mainColor.selection.usesLightYellowIcons(in: colorScheme),
           let image = UIImage(systemName: selectedSymbol ?? symbol) {
            Label {
                Text(title)
            } icon: {
                // Preserve this foreground when the native tab applies its title tint.
                Image(uiImage: image.withTintColor(UIColor(MainColor.lightYellowIcon), renderingMode: .alwaysOriginal))
                    .renderingMode(.original)
            }
        } else {
            Label(title, systemImage: symbol)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            HomeView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents) {
                timetableTodayRequest = UUID()
                selectedTab = .timetable
            }
                .tint(tabContentTint)
                .tabItem { tabLabel("ホーム", symbol: "house", tab: .home, selectedSymbol: "house.fill") }.tag(Tab.home)
            LinksView(model: links)
                .tint(tabContentTint)
                .tabItem { tabLabel("一覧", symbol: "list.bullet", tab: .links) }.tag(Tab.links)
            TimetableView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings, todayRequest: $timetableTodayRequest)
                .tint(tabContentTint)
                .tabItem { tabLabel("時間割", symbol: "calendar", tab: .timetable) }.tag(Tab.timetable)
            SettingsView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings)
                .tint(tabContentTint)
                .tabItem { tabLabel("設定", symbol: "gearshape", tab: .settings, selectedSymbol: "gearshape.fill") }.tag(Tab.settings)
        }
        .tint(mainColor.selection.tabTitleTint(for: colorScheme, contrast: colorSchemeContrast))
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
