import SwiftUI

struct MappingSettingsView: View {
    @EnvironmentObject private var account: AccountDataModel
    @ObservedObject var model: MappingModel

    var body: some View {
        List {
            Section("状態") {
                AcquisitionStatusRow(title: "名称データ", status: model.acquisitionStatus)
                if let date = model.revisionConfirmation?.lastSuccess?.checkedAt {
                    LabeledContent("最終確認成功") { Text(date, format: JapaneseDateDisplay.timestamp) }
                }
                if model.busy || account.busy { LoadingRow(title: "確認中⋯") }
                if let message = model.message {
                    if model.failed { InlineWarning(message) }
                    else { Text(message).foregroundStyle(.secondary) }
                }
                if !model.ready { Button("保存情報を再読み込み") { model.loadIfNeeded() } }
            }
            if let current = model.current {
                Section("取得情報") {
                    LabeledContent("バージョン", value: current.version)
                    LabeledContent("最終取得") {
                        Text(current.fetchedAt, format: JapaneseDateDisplay.timestamp)
                    }
                    LabeledContent("件数", value: "\(current.rules.subjects.count + current.rules.teachers.count + current.rules.rooms.count + current.rules.teacherContexts.count)件")
                }
            }
        }
        .navigationTitle("名称データ")
        .task { model.loadIfNeeded() }
    }
}
