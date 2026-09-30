import SwiftUI

struct MappingSettingsView: View {
    @EnvironmentObject private var account: AccountDataModel
    @ObservedObject var model: MappingModel

    var body: some View {
        List {
            Section("状態") {
                AcquisitionStatusRow(title: "名称データ", acquired: model.current != nil,
                                     updated: model.updateAvailable, failed: model.failed)
                if model.busy || account.busy { LoadingRow(title: "確認中⋯") }
                if let message = model.message {
                    Text(message).foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
                if !model.ready { Button("保存情報を再読み込み") { model.loadIfNeeded() } }
            }
            if let current = model.current {
                Section("取得情報") {
                    LabeledContent("バージョン", value: current.version)
                    LabeledContent("最終取得") {
                        Text(current.fetchedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("件数", value: "\(current.rules.subjects.count + current.rules.teachers.count + current.rules.rooms.count)件")
                }
            }
        }
        .navigationTitle("名称データ")
        .task { model.loadIfNeeded() }
    }
}
