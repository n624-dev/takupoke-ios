import SwiftUI

struct SettingsView: View {
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue
    @AppStorage("linkOpeningMode") private var linkOpeningMode = LinkOpeningMode.inApp.rawValue
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var times: TimetableTimesModel
    @State private var showingSetup = false

    var body: some View {
        NavigationStack {
            List {
                Section("データ取得") {
                    NavigationLink {
                        MaterialsView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents,
                                      mappings: mappings)
                    } label: {
                        Label("ファイル選択", systemImage: "folder")
                    }
                    NavigationLink {
                        AccountDataSettingsView()
                    } label: {
                        HStack {
                            Label("学校アカウントのデータ", systemImage: "text.book.closed")
                            Spacer()
                            if mappings.updateAvailable || links.updateAvailable || times.updateAvailable { Text("更新あり").font(.caption).foregroundStyle(.orange) }
                            else if mappings.failed || links.failed || times.failed { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                        }
                    }
                }
                Section("外観") {
                    Picker("メインカラー", selection: $mainColor) {
                        ForEach(MainColor.allCases) { choice in
                            Text(choice.title).tag(choice.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("通知") {
                    NavigationLink("通知設定") { NotificationSettingsView() }
                }
                Section("リンク一覧") {
                    Picker("リンクの開き方", selection: $linkOpeningMode) {
                        Text("外部で開く").tag(LinkOpeningMode.external.rawValue)
                        Text("アプリ内で開く").tag(LinkOpeningMode.inApp.rawValue)
                    }
                }
                Section("サポート") {
                    Button("セットアップ") { showingSetup = true }
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
