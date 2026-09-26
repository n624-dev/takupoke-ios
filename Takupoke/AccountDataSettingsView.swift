import SwiftUI

struct AccountDataSettingsView: View {
    @EnvironmentObject private var account: AccountDataModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var mappings: MappingModel

    private var busy: Bool { account.busy || links.busy || mappings.busy }

    var body: some View {
        List {
            Section {
                if busy { LoadingRow(title: "取得中⋯") }
                Button(links.saved == nil || mappings.current == nil ? "学校アカウントで取得" : "更新を確認") {
                    Task { await account.refresh(mappings: mappings, links: links) }
                }
                .disabled(busy)
            }
            Section("一覧") {
                LabeledContent("状態", value: links.saved == nil ? "未取得" : "取得済み")
                if let saved = links.saved {
                    LabeledContent("最終取得") {
                        Text(saved.checkedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                }
                if let message = links.message {
                    Text(message).foregroundStyle(links.failed ? Color.orange : Color.secondary)
                }
            }
            Section("名称対応表") {
                LabeledContent("状態", value: mappings.current == nil ? "未取得" : "取得済み")
                if let message = mappings.message {
                    Text(message).foregroundStyle(mappings.failed ? Color.orange : Color.secondary)
                }
                NavigationLink("詳細を見る") { MappingSettingsView(model: mappings) }
            }
        }
        .navigationTitle("一覧・名称対応表")
        .task { links.loadIfNeeded(); mappings.loadIfNeeded() }
    }
}
