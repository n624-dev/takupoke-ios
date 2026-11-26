import SwiftUI

struct ServiceStatusView: View {
    let service: MonitoredService
    @ObservedObject var model: ServiceStatusModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var owner = UUID()

    var body: some View {
        List {
            Section {
                StatusRow(title: service.title, status: model.cache.presentation(for: service, at: Date()),
                          date: model.cache.retained[service]?.checkedAt, dateLabel: "このサービスの取得・確認")
                if model.checking { LoadingRow(title: "稼働状況を確認中⋯") }
                if model.cache.failed {
                    Text("情報を更新できませんでした。現在の状況は未確認です。")
                        .foregroundStyle(.secondary)
                }
                Link("公開ステータスページ", destination: ServiceStatusModel.pageURL)
            } footer: {
                Text("Better Stackの公開監視結果です。この端末での認証や、配信データの内容の正確さとは別の情報です。表示中は3分ごとに確認します。")
            }
            Section("機能別の状態") {
                ForEach(service.featureIDs, id: \.self) { id in
                    let feature = model.functional[service]?.feature(id)
                    StatusRow(title: FunctionalStatusSnapshot.Feature.title(for: id),
                              status: model.featureStatus(id, for: service, at: Date()),
                              date: feature?.checkedAt, dateLabel: "最終確認")
                }
            }
            if let retained = model.cache.retained[service] {
                let resource = retained.value
                Section("取得した監視結果") {
                    if !model.cache.hasCurrentResource(service, at: Date()) {
                        Text("以下は前回取得した情報です。現在の状態とは異なる場合があります。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    StatusLabel(value: resource.state.presentation)
                    if let availability = resource.availability {
                        LabeledContent("公開ページの稼働率") { Text(availability, format: .percent.precision(.fractionLength(3))) }
                    }
                    if let first = resource.history.first, let last = resource.history.last {
                        LabeledContent("履歴の対象期間", value: "\(first.date.iso8601) 〜 \(last.date.iso8601)")
                    }
                }
                if !resource.history.isEmpty {
                    Section("日別の稼働履歴") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 14), spacing: 3)], spacing: 4) {
                            ForEach(resource.history) { day in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(day.state.presentation.color)
                                    .frame(height: 20)
                                    .accessibilityLabel("\(day.date.iso8601)：\(day.state.presentation.title)")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        Text("古い日付から順に表示しています。灰色は監視対象外または未確認です。")
                            .font(.caption).foregroundStyle(.secondary)
                        DisclosureGroup("日別の内訳") {
                            ForEach(resource.history.reversed()) { day in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(day.date.iso8601).font(.subheadline)
                                    StatusLabel(value: day.state.presentation).font(.caption)
                                    if let seconds = day.downtime, seconds > 0 {
                                        Text("停止時間：\(seconds.formatted(.number.precision(.fractionLength(0))))秒")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let seconds = day.maintenance, seconds > 0 {
                                        Text("メンテナンス：\(seconds.formatted(.number.precision(.fractionLength(0))))秒")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                Section("障害情報") {
                    if resource.incidents.isEmpty {
                        Text("取得した情報に、このサービスの障害報告はありません。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(resource.incidents) { incident in
                        DisclosureGroup {
                            if let start = incident.startsAt {
                                LabeledContent("開始") { Text(start, format: JapaneseDateDisplay.timestamp) }
                            }
                            ForEach(incident.updates) { update in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(update.publishedAt, format: JapaneseDateDisplay.timestamp)
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(update.message).font(.callout)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(incident.title)
                                StatusLabel(value: incident.resolved ? .init(title: "解決済み", tone: .good) :
                                    incident.state == "downtime" ? .init(title: "停止中", tone: .unavailable) :
                                    .init(title: "詳細を確認", tone: .unknown)).font(.caption)
                            }
                        }
                    }
                }
            } else {
                Section { Text("このサービスの監視結果はまだ確認できていません。").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(service.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("稼働状況を更新", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    .disabled(model.checking)
            }
        }
        .refreshable { await model.refresh() }
        .onAppear { visible = true }
        .onDisappear { visible = false; model.endObserving(owner) }
        .task(id: visible && scenePhase == .active) {
            guard visible, scenePhase == .active else { model.endObserving(owner); return }
            model.beginObserving(owner)
            await model.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: ServiceStatusModel.refreshNanoseconds) }
                catch { break }
                guard !Task.isCancelled else { break }
                await model.refresh()
            }
        }
    }
}
