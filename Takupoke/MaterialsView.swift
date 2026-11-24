import SwiftUI

struct MaterialsView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    var setupMode = false
    @State var fileRequest: FileSelectionRequest?

    var body: some View {
        List {
            if setupMode {
                Section("ファイルを選ぶ") {
                    Text("通常時間割のPDFと時間割変更のExcelファイルを選びます。選択後、自動で解析します。")
                    Text("試験時間割・試験返却時間割のPDFは、手元にある場合に選んでください。")
                    NavigationLink("OneDriveの準備") { UsageHelpTopicView(topic: .gettingStarted) }
                }
            }
            Section("更新確認") {
                FileRefreshControls(materials: model, specials: specialSchedules)
            }
            if !model.ready && !model.busy {
                Section("保存データ") {
                    if let message = model.message { InlineWarning(message) }
                    Button("保存情報を再読み込み") { model.loadIfNeeded() }
                }
            }
            if !specialSchedules.ready && !specialSchedules.busy {
                Section("保存データ") {
                    if let message = specialSchedules.message { InlineWarning(message) }
                    Button("保存情報を再読み込み") { specialSchedules.loadIfNeeded() }
                }
            }
            Section {
                fileRows
            } header: { Text("時間割ファイル") } footer: {
                Text("選択済みの行を開くと、確認日時や解析結果、再取得・選び直しの操作を確認できます。")
            }
            if model.ready && model.failed, let message = model.message {
                Section("通常時間割・時間割変更") { InlineWarning(message) }
            }
            if specialSchedules.ready && specialSchedules.failed, let message = specialSchedules.message {
                Section("試験・返却時間割") { InlineWarning(message) }
            }

            if setupMode {
                Section {
                    NavigationLink("学校行事を取得") { SchoolEventsSettingsView(model: schoolEvents) }
                }
            }
        }
        .navigationTitle("時間割ファイル")
        .toolbar {
            if !setupMode {
                ToolbarItem(placement: .primaryAction) {
                    FileRefreshMenu(materials: model, specials: specialSchedules)
                }
            }
        }
        .task { model.loadIfNeeded() }
        .task { specialSchedules.loadIfNeeded() }
        .task { schoolEvents.loadIfNeeded() }
        .background(
            MaterialDocumentPicker(item: $fileRequest, requestID: fileRequest?.id,
                type: { $0.type }, instruction: { $0.instruction },
                selected: { request, selection in
                    switch request.target {
                    case .material(let kind): model.selectFile(selection, kind: kind)
                    case .special(let kind): specialSchedules.importPDF(selection, kind: kind)
                    }
                })
                .allowsHitTesting(false)
        )
    }

}
