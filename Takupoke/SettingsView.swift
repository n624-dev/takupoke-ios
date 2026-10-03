import SwiftUI

struct SettingsView: View {
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue
    @AppStorage("linkOpeningMode") private var linkOpeningMode = LinkOpeningMode.inApp.rawValue
    @AppStorage("timetableSelectedClasses") private var selectedClasses = ""
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var times: TimetableTimesModel
    @State private var showingSetup = false

    private var colorSelection: Binding<MainColor> {
        Binding(get: { MainColor(rawValue: mainColor) ?? .systemDefault },
                set: { $0.save() })
    }

    var body: some View {
        NavigationStack {
            List {
                Section("データ") {
                    NavigationLink {
                        MaterialsView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                                      mappings: mappings)
                    } label: {
                        Label("時間割ファイル", systemImage: "folder")
                    }
                    NavigationLink {
                        SchoolEventsSettingsView(model: schoolEvents)
                    } label: {
                        Label("学校行事", systemImage: "calendar")
                    }
                    NavigationLink {
                        AccountDataSettingsView()
                    } label: {
                        HStack {
                            Label("リンク・名称・授業時刻", systemImage: "arrow.down.circle")
                            Spacer()
                            if (mappings.current != nil && mappings.updateAvailable) || (links.saved != nil && links.updateAvailable) || (times.current != nil && times.updateAvailable) { Text("更新あり").font(.caption).foregroundStyle(.orange) }
                            else if mappings.failed || links.failed || times.failed { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                        }
                    }
                }
                Section("アプリ設定") {
                    NavigationLink {
                        TimetablePrimaryClassSelection(classes: TimetableSchedule.selectableClasses, value: $selectedClasses)
                    } label: {
                        LabeledContent("クラス", value: selectedClasses.isEmpty ? "未選択" :
                            TimetableDisplayText.classNames(selectedClasses.split(separator: "|").map(String.init)))
                    }
                    NavigationLink("端末内AIモデル") { RecoveryModelSettingsView() }
                    NavigationLink("通知") { NotificationSettingsView() }
                    Picker("メインカラー", selection: colorSelection) {
                        ForEach(MainColor.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("リンクの開き方", selection: $linkOpeningMode) {
                        Text("デフォルトのブラウザ").tag(LinkOpeningMode.external.rawValue)
                        Text("アプリ内で開く").tag(LinkOpeningMode.inApp.rawValue)
                    }
                    .pickerStyle(.menu)
                }
                Section("サポート") {
                    Button("初期設定") { showingSetup = true }
                    NavigationLink("使い方") { UsageHelpView() }
                    NavigationLink("このアプリについて") { AboutView() }
                }
            }
            .navigationTitle("設定")
            .fullScreenCover(isPresented: $showingSetup) {
                SetupView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                          mappings: mappings, finish: { showingSetup = false })
            }
        }
    }
}
