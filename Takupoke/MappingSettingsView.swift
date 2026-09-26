import SwiftUI

struct MappingSettingsView: View {
    @ObservedObject var model: MappingModel

    var body: some View {
        List {
            Section {
                if let current = model.current {
                    LabeledContent("バージョン", value: current.version)
                    LabeledContent("最終取得") {
                        Text(current.fetchedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    LabeledContent("件数", value: "\(current.rules.subjects.count + current.rules.teachers.count + current.rules.rooms.count)件")
                } else {
                    Text("未取得").foregroundStyle(.secondary)
                }
                if model.updateAvailable {
                    Label(model.current == nil ? "名称対応表を取得できます。" : "名称対応表に更新があります。",
                          systemImage: "arrow.down.circle")
                        .foregroundStyle(.orange)
                }
                if model.busy { HStack { ProgressView(); Text("確認中…") } }
                if let message = model.message {
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: model.failed ? "exclamationmark.triangle" : "info.circle")
                    }
                    .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
                if !model.ready { Button("保存情報を再読み込み") { model.loadIfNeeded() } }
                Button(model.current == nil ? "名称対応表を取得" : "更新を確認") { model.refresh() }
                    .disabled(model.busy || !model.ready)
            } header: {
                Text("名称対応表")
            } footer: {
                Text("起動時は更新の有無だけを確認します。取得時に学校アカウントで認証し、通常授業の詳細に正式名称を表示します。")
            }
        }
        .navigationTitle("名称対応表")
        .task { model.loadIfNeeded() }
    }
}
