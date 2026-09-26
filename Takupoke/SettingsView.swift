import SwiftUI

struct SettingsView: View {
    @AppStorage("linkOpeningMode") private var linkOpeningMode = LinkOpeningMode.external.rawValue
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel

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
                        MappingSettingsView(model: mappings)
                    } label: {
                        HStack {
                            Label("名称対応表", systemImage: "text.book.closed")
                            Spacer()
                            if mappings.updateAvailable { Text("更新あり").font(.caption).foregroundStyle(.orange) }
                            else if mappings.failed { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                        }
                    }
                }
                Section("一覧") {
                    Picker("リンクの開き方", selection: $linkOpeningMode) {
                        Text("外部で開く").tag(LinkOpeningMode.external.rawValue)
                        Text("アプリ内で開く").tag(LinkOpeningMode.inApp.rawValue)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}
