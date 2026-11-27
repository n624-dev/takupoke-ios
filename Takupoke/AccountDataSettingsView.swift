import SwiftUI

extension LinksModel {
    var acquisitionStatus: StatusPresentation {
        .downloaded(acquired: saved != nil, updateAvailable: updateAvailable, failed: failed, busy: busy,
                    confirmation: revisionConfirmation)
    }
}

extension MappingModel {
    var acquisitionStatus: StatusPresentation {
        .downloaded(acquired: current != nil, updateAvailable: updateAvailable, failed: failed, busy: busy,
                    confirmation: revisionConfirmation)
    }
}

extension TimetableTimesModel {
    var acquisitionStatus: StatusPresentation {
        .downloaded(acquired: current != nil, updateAvailable: updateAvailable, failed: failed, busy: busy,
                    confirmation: revisionConfirmation)
    }
}

struct AccountDataSettingsView: View {
    @EnvironmentObject private var times: TimetableTimesModel
    @EnvironmentObject private var account: AccountDataModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var mappings: MappingModel
    var setupMode = false
    @State private var selectedData: AccountDataSelection = .all

    private var busy: Bool { account.busy || links.busy || mappings.busy || times.busy }

    var body: some View {
        List {
            if setupMode {
                Section("学校アカウントで取得する") {
                    Text("リンク一覧・名称データ・授業時刻をまとめて取得します。")
                }
            }
            Section {
                Toggle("リンク一覧", isOn: selectionBinding(.links)).disabled(busy)
                Toggle("名称データ", isOn: selectionBinding(.mappings)).disabled(busy)
                Toggle("授業時刻", isOn: selectionBinding(.times)).disabled(busy)
                Text(selectedData == .links
                     ? "一覧だけ取得します。学内ネットワークではMicrosoft認証を省略できます。"
                     : "名称データ・授業時刻には学校アカウントでの認証が必要です。選択したデータを1回の認証で取得します。")
                    .font(.caption).foregroundStyle(.secondary)
                if busy {
                    LoadingRow(title: account.busy ? "取得中⋯" : "更新情報を確認中⋯",
                        cancel: account.busy ? { account.cancel() } : nil)
                }
                Button(links.saved == nil || mappings.current == nil || times.current == nil ? "学校アカウントで取得" : "更新を確認") {
                    let selection = selectedData
                    Task { await account.refresh(mappings: mappings, links: links, times: times, selection: selection) }
                }
                .disabled(busy || selectedData.isEmpty)
            }
            Section("データ") {
                NavigationLink { LinksDataDetailView() } label: {
                    AcquisitionStatusRow(title: "リンク一覧", status: links.acquisitionStatus)
                }
                NavigationLink { MappingSettingsView(model: mappings) } label: {
                    AcquisitionStatusRow(title: "名称データ", status: mappings.acquisitionStatus)
                }
                NavigationLink { TimetableTimesDetailView() } label: {
                    AcquisitionStatusRow(title: "授業時刻", status: times.acquisitionStatus)
                }
            }
            LinksPreferencesWarning(model: links)
            if links.failed || mappings.failed || times.failed {
                Section("取得・確認のエラー") {
                    if links.failed, let message = links.message { InlineWarning(message) }
                    if mappings.failed, let message = mappings.message { InlineWarning(message) }
                    if times.failed, let message = times.message { InlineWarning(message) }
                }
            }
        }
        .navigationTitle(setupMode ? "データを取得" : "リンク・名称・授業時刻")
        .task { links.loadIfNeeded(); mappings.loadIfNeeded(); times.loadIfNeeded() }
    }

    private func selectionBinding(_ item: AccountDataSelection) -> Binding<Bool> {
        Binding(get: { selectedData.contains(item) }, set: { selected in
            if selected { selectedData.insert(item) } else { selectedData.remove(item) }
        })
    }
}

struct AcquisitionStatusRow: View {
    let title: String
    let status: StatusPresentation

    var body: some View {
        LabeledContent(title) {
            Text(status.title).foregroundStyle(status.color)
        }
    }
}

struct LinksDataDetailView: View {
    @EnvironmentObject private var links: LinksModel

    var body: some View {
        List {
            LinksPreferencesWarning(model: links)
            Section("状態") {
                AcquisitionStatusRow(title: "リンク一覧", status: links.acquisitionStatus)
                if let date = links.revisionConfirmation?.lastSuccess?.checkedAt {
                    LabeledContent("最終確認成功") { Text(date, format: JapaneseDateDisplay.timestamp) }
                }
                if let message = links.message {
                    if links.failed { InlineWarning(message) }
                    else { Text(message).foregroundStyle(.secondary) }
                }
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

struct TimetableTimesDetailView: View {
    @EnvironmentObject private var times: TimetableTimesModel

    var body: some View {
        List {
            Section("状態") {
                AcquisitionStatusRow(title: "授業時刻", status: times.acquisitionStatus)
                if let date = times.revisionConfirmation?.lastSuccess?.checkedAt {
                    LabeledContent("最終確認成功") { Text(date, format: JapaneseDateDisplay.timestamp) }
                }
                if let message = times.message {
                    if times.failed { InlineWarning(message) }
                    else { Text(message).foregroundStyle(.secondary) }
                }
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
