import SwiftUI

struct AccountDataSettingsView: View {
    @EnvironmentObject private var times: TimetableTimesModel
    @EnvironmentObject private var account: AccountDataModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var mappings: MappingModel
    var setupMode = false

    private var busy: Bool { account.busy || links.busy || mappings.busy || times.busy }

    var body: some View {
        List {
            if setupMode {
                Section("学校アカウントで取得する") {
                    Text("リンク一覧・名称データ・授業時刻をまとめて取得します。")
                }
            }
            Section {
                if busy { LoadingRow(title: "取得中⋯") }
                Button(links.saved == nil || mappings.current == nil || times.current == nil ? "学校アカウントで取得" : "更新を確認") {
                    Task { await account.refresh(mappings: mappings, links: links, times: times) }
                }
                .disabled(busy)
            }
            Section("データ") {
                NavigationLink { LinksDataDetailView() } label: {
                    AcquisitionStatusRow(title: "リンク一覧", acquired: links.saved != nil,
                                         updated: links.updateAvailable, failed: links.failed)
                }
                NavigationLink { MappingSettingsView(model: mappings) } label: {
                    AcquisitionStatusRow(title: "名称データ", acquired: mappings.current != nil,
                                         updated: mappings.updateAvailable, failed: mappings.failed)
                }
                NavigationLink { TimetableTimesDetailView() } label: {
                    AcquisitionStatusRow(title: "授業時刻", acquired: times.current != nil,
                                         updated: times.updateAvailable, failed: times.failed)
                }
            }
            if links.failed || mappings.failed || times.failed {
                Section("取得・確認のエラー") {
                    if links.failed, let message = links.message { Text(message).foregroundStyle(.orange) }
                    if mappings.failed, let message = mappings.message { Text(message).foregroundStyle(.orange) }
                    if times.failed, let message = times.message { Text(message).foregroundStyle(.orange) }
                }
            }
        }
        .navigationTitle(setupMode ? "データを取得" : "リンク・名称・授業時刻")
        .task { links.loadIfNeeded(); mappings.loadIfNeeded(); times.loadIfNeeded() }
    }
}

struct AcquisitionStatusRow: View {
    let title: String
    let acquired: Bool
    let updated: Bool
    let failed: Bool

    private var status: String {
        if failed { return "要確認" }
        if !acquired { return "未取得" }
        return updated ? "更新あり" : "取得済み"
    }

    var body: some View {
        LabeledContent(title) {
            Text(status).foregroundStyle(failed || (acquired && updated) ? Color.orange : Color.secondary)
        }
    }
}

private struct LinksDataDetailView: View {
    @EnvironmentObject private var links: LinksModel

    var body: some View {
        List {
            Section("状態") {
                AcquisitionStatusRow(title: "リンク一覧", acquired: links.saved != nil,
                                     updated: links.updateAvailable, failed: links.failed)
                if let message = links.message { Text(message).foregroundStyle(links.failed ? Color.orange : Color.secondary) }
                if !links.ready { Button("保存情報を再読み込み") { links.loadIfNeeded() } }
            }
            if let saved = links.saved {
                Section("取得情報") {
                    LabeledContent("最終取得") { Text(saved.checkedAt, format: JapaneseDateDisplay.timestamp) }
                    LabeledContent("件数", value: "\(saved.payload.categories.flatMap(\.buttons).count)件")
                }
            }
        }
        .navigationTitle("リンク一覧")
    }
}

private struct TimetableTimesDetailView: View {
    @EnvironmentObject private var times: TimetableTimesModel

    var body: some View {
        List {
            Section("状態") {
                AcquisitionStatusRow(title: "授業時刻", acquired: times.current != nil,
                                     updated: times.updateAvailable, failed: times.failed)
                if let message = times.message { Text(message).foregroundStyle(times.failed ? Color.orange : Color.secondary) }
                if !times.ready { Button("保存情報を再読み込み") { times.loadIfNeeded() } }
            }
            if let current = times.current {
                Section("取得情報") {
                    LabeledContent("最終取得") { Text(current.fetchedAt, format: JapaneseDateDisplay.timestamp) }
                    LabeledContent("件数", value: "\(current.data.days.reduce(0) { $0 + $1.periods.count })件")
                }
                ForEach(current.data.days, id: \.date) { day in
                    Section(day.date) {
                        ForEach(day.periods, id: \.period) { period in
                            LabeledContent("\(period.period)限", value: "\(period.start)〜\(period.end)")
                        }
                    }
                }
            }
        }
        .navigationTitle("授業時刻")
    }
}
