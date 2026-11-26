import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Both the settings summary and detail read the same existing model evidence.
@MainActor
struct AppStatusEvidence {
    let materials: MaterialsModel
    let specials: SpecialSchedulesModel
    let events: SchoolEventsModel
    let mappings: MappingModel
    let links: LinksModel
    let times: TimetableTimesModel
    let services: ServiceStatusModel
    let application: ApplicationData
    let year: Int?

    private var onlineEvents: FunctionalStatusSnapshot.EventVersion? {
        guard let year else { return nil }
        let format = events.saved[year]?.payload.format?.rawValue ?? "v2"
        return services.onlineEventVersion(year: year, format: format, at: Date())
    }

    private var publisherWaiting: Bool {
        guard let year else { return false }
        return services.eventsPresentation(events, year: year)?.updateWaiting == true
    }

    @MainActor var eventsStatus: StatusPresentation {
        guard let year else { return .init(title: "学校年度を確認してください", tone: .attention) }
        let source = services.eventsPresentation(events, year: year)
        if let source, source.updateWaiting {
            return .init(title: "更新待ち", tone: .attention, detail: source.warningMessage)
        }
        return .schoolEvents(ready: events.ready, failed: events.failed,
            checking: events.busy || events.isChecking(year: year),
            cacheFailed: events.failedCacheYears.contains(year), acquired: events.saved[year] != nil,
            source: source)
    }

    var eventsReview: StatusPresentation {
        guard let version = onlineEvents, version.reviewState == "reviewed",
              let date = version.reviewCheckedAt, date <= Date() else { return FunctionalStatusSnapshot.unknown }
        return .init(title: "確認済み", tone: .good)
    }

    var eventsRevision: StatusPresentation {
        guard let year, let saved = events.saved[year] else { return .init(title: "未取得", tone: .neutral) }
        guard let version = onlineEvents, let savedVersion = saved.dataVersion else { return FunctionalStatusSnapshot.unknown }
        if savedVersion == version.dataVersion { return .init(title: "配信版と一致", tone: .good) }
        if publisherWaiting { return .init(title: "保存済み", tone: .neutral) }
        return .init(title: "更新あり", tone: .attention)
    }

    @MainActor var linkStatus: StatusPresentation {
        .downloaded(acquired: links.saved != nil, updateAvailable: links.updateAvailable, failed: links.failed, busy: links.busy)
    }
    @MainActor var mappingStatus: StatusPresentation {
        .downloaded(acquired: mappings.current != nil, updateAvailable: mappings.updateAvailable, failed: mappings.failed, busy: mappings.busy)
    }
    @MainActor var timesStatus: StatusPresentation {
        .downloaded(acquired: times.current != nil, updateAvailable: times.updateAvailable, failed: times.failed, busy: times.busy)
    }
    @MainActor var summary: StatusPresentation {
        var values = [eventsStatus, eventsReview, eventsRevision, linkStatus, mappingStatus, timesStatus]
        values += [MaterialKind.timetable, .changes].map { materials.fileStatus($0) }
        values += SpecialScheduleKind.allCases.map { specials.fileStatus($0) }
        values += MonitoredService.allCases.map { services.cache.presentation(for: $0, at: Date()) }
        for service in MonitoredService.allCases {
            values += service.featureIDs.map { services.featureStatus($0, for: service, at: Date()) }
        }
        values += [networkStatus, storageStatus]
        if materials.lastOperationWasCancelled || specials.lastOperationWasCancelled {
            values.append(.init(title: "前回の処理を中止しました", tone: .neutral))
        }
        return .summary(values, checking: services.checking || materials.busy || specials.busy,
                        paused: materials.fileRefreshQueue.suspended || specials.fileRefreshQueue.suspended)
    }

    var networkStatus: StatusPresentation {
        guard let available = application.networkPathAvailable else { return .init(title: "未確認", tone: .unknown) }
        return .init(title: available ? "ネットワーク接続あり" : "ネットワーク接続なし", tone: available ? .neutral : .attention,
                     detail: "端末の接続状況です。APIの応答を保証するものではありません。")
    }
    var storageStatus: StatusPresentation {
        if application.retentionFailure { return .init(title: "保存データを利用できません", tone: .unavailable, detail: application.retentionFailureMessage) }
        if (!materials.ready && materials.failed) || (!specials.ready && specials.failed) || (!events.ready && events.failed) ||
            (!links.ready && links.failed) || (!mappings.ready && mappings.failed) || (!times.ready && times.failed) {
            return .init(title: "保存データを読み込めません", tone: .unavailable)
        }
        if !application.readyForCurrentPeriod || !materials.ready || !specials.ready || !events.ready || !links.ready || !mappings.ready || !times.ready {
            return .init(title: "保存データを確認中", tone: .unknown)
        }
        return .init(title: "保存先を利用可能", tone: .good)
    }

    static func selectedYear(_ value: String, today: SchoolDate) -> Int? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return today.schoolYear }
        guard value.count == 4, let year = Int(value), (1900...9998).contains(year) else { return nil }
        return year
    }
}

struct AppStatusSummaryRow: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var times: TimetableTimesModel
    @ObservedObject private var services = ApplicationData.shared.serviceStatus
    @ObservedObject private var application = ApplicationData.shared
    @AppStorage("eventsSelectedSchoolYear") private var yearValue = ""

    var body: some View {
        let value = AppStatusEvidence(materials: materials, specials: specialSchedules, events: schoolEvents,
            mappings: mappings, links: links, times: times, services: services, application: application,
            year: AppStatusEvidence.selectedYear(yearValue, today: SchoolDate.today())).summary
        VStack(alignment: .leading, spacing: 4) {
            StatusLabel(value: value)
            Text("データ・ファイル・サービスの状況").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AppStatusView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @EnvironmentObject private var links: LinksModel
    @EnvironmentObject private var times: TimetableTimesModel
    @EnvironmentObject private var account: AccountDataModel
    @ObservedObject private var application = ApplicationData.shared
    @ObservedObject private var services = ApplicationData.shared.serviceStatus
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("eventsSelectedSchoolYear") private var yearValue = ""
    @State private var visible = false
    @State private var owner = UUID()
    @State private var copiedDiagnostic = false

    private var evidence: AppStatusEvidence {
        .init(materials: materials, specials: specialSchedules, events: schoolEvents, mappings: mappings,
              links: links, times: times, services: services, application: application,
              year: AppStatusEvidence.selectedYear(yearValue, today: SchoolDate.today()))
    }

    private var canRefreshDistributedData: Bool {
        visible && scenePhase == .active && application.readyForCurrentPeriod && !account.busy
    }

    var body: some View {
        List {
            Section {
                StatusRow(title: "現在の状態", status: evidence.summary)
                if let checked = services.cache.checkedAt {
                    LabeledContent("稼働情報の取得・確認") { Text(checked, format: JapaneseDateDisplay.timestamp) }
                        .font(.caption)
                }
            } footer: {
                Text("確認日時は項目ごとに異なります。未確認の状態は正常と判定しません。")
            }
            distributedData
            fileData
            Section("サービス稼働状況") {
                ForEach(MonitoredService.allCases) { service in
                    NavigationLink {
                        ServiceStatusView(service: service, model: services)
                    } label: {
                        StatusRow(title: service.title, status: services.cache.presentation(for: service, at: Date()))
                    }.accessibilityIdentifier("status-service-\(service.id)")
                }
                Link("公開ステータスページ", destination: ServiceStatusModel.pageURL)
                if services.checking { LoadingRow(title: "稼働状況を確認中⋯") }
                if services.cache.failed {
                    Text("稼働情報を取得できませんでした。サービスの停止を示すものではありません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            deviceData
            Section {
                Button("更新確認の記録をコピー", systemImage: "doc.on.doc") {
                    UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: FileRefreshDiagnostics.shared.report]],
                        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(600)])
                    copiedDiagnostic = true
                }
                if copiedDiagnostic { Text("更新確認の記録をコピーしました。").font(.footnote).foregroundStyle(.secondary) }
            } footer: {
                Text("更新確認の処理記録だけをコピーします。ファイル名・本文・認証情報は含めず、自動送信もしません。")
            }
        }
        .navigationTitle("ステータス")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("稼働・配信状況を更新", systemImage: "arrow.clockwise") {
                    Task { await refreshPublicData() }
                }.disabled(services.checking || account.busy)
            }
        }
        .refreshable { await refreshPublicData() }
        .onAppear { visible = true }
        .onDisappear { visible = false; services.endObserving(owner) }
        .task(id: visible && scenePhase == .active) {
            guard visible, scenePhase == .active else { services.endObserving(owner); return }
            services.beginObserving(owner)
            await services.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: ServiceStatusModel.refreshNanoseconds) }
                catch { break }
                guard !Task.isCancelled else { break }
                await services.refresh()
            }
        }
        .task(id: canRefreshDistributedData) {
            await refreshDistributedData()
        }
    }

    private var distributedData: some View {
        Section {
            NavigationLink { SchoolEventsSettingsView(model: schoolEvents) } label: {
                StatusRow(title: "学校行事", status: evidence.eventsStatus,
                          subtitle: evidence.year.map { "\($0)年度" },
                          date: evidence.year.flatMap { schoolEvents.saved[$0]?.lastEventsCheckedAt }, dateLabel: "行事データの更新確認")
            }.accessibilityIdentifier("status-events")
            NavigationLink { LinksDataDetailView() } label: {
                StatusRow(title: "リンク一覧", status: evidence.linkStatus, date: links.saved?.checkedAt, dateLabel: "最終取得")
            }.accessibilityIdentifier("status-links")
            NavigationLink { MappingSettingsView(model: mappings) } label: {
                StatusRow(title: "名称データ", status: evidence.mappingStatus, date: mappings.current?.fetchedAt, dateLabel: "最終取得")
            }.accessibilityIdentifier("status-mappings")
            NavigationLink { TimetableTimesDetailView() } label: {
                StatusRow(title: "授業時刻", status: evidence.timesStatus, date: times.current?.fetchedAt, dateLabel: "最終取得")
            }.accessibilityIdentifier("status-times")
            NavigationLink("学校アカウントで取得・更新") { AccountDataSettingsView() }
            StatusRow(title: "行事の内容レビュー", status: evidence.eventsReview)
            StatusRow(title: "端末に保存した行事", status: evidence.eventsRevision)
        } header: { Text("配信データ") } footer: {
            Text("元PDFとの照合、配信元のレビュー、端末保存版の確認結果をそれぞれ表示します。")
        }
    }

    private var fileData: some View {
        Section("時間割ファイル") {
            ForEach([MaterialKind.timetable, .changes]) { kind in
                if let record = materials.state.record(for: kind) {
                    NavigationLink {
                        if kind == .changes { ChangeAnalysisView(model: materials, mappings: mappings) }
                        else { PDFAnalysisView(model: materials, mappings: mappings, kind: kind) }
                    } label: {
                        StatusRow(title: kind.title, status: materials.fileStatus(kind), subtitle: record.originalName,
                                  date: record.lastCheckedAt)
                    }
                } else {
                    NavigationLink { materialSettings } label: {
                        StatusRow(title: kind.title, status: materials.fileStatus(kind))
                    }
                }
            }
            ForEach(SpecialScheduleKind.allCases) { kind in
                if specialSchedules.sources[kind] != nil || specialSchedules.records[kind] != nil {
                    NavigationLink { SpecialScheduleAnalysisView(model: specialSchedules, kind: kind) } label: {
                        StatusRow(title: kind.title, status: specialSchedules.fileStatus(kind),
                                  subtitle: specialSchedules.sources[kind]?.originalName ?? specialSchedules.records[kind]?.originalName,
                                  date: specialSchedules.sources[kind]?.lastCheckedAt)
                    }
                } else {
                    NavigationLink { materialSettings } label: {
                        StatusRow(title: kind.title, status: specialSchedules.fileStatus(kind))
                    }
                }
            }
            NavigationLink("ファイルの更新・自動確認を管理") { materialSettings }
        }
    }

    private var materialSettings: some View {
        MaterialsView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents, mappings: mappings)
    }

    private var deviceData: some View {
        Section("この端末") {
            StatusRow(title: "ネットワーク", status: evidence.networkStatus)
            NavigationLink { AccountDataSettingsView() } label: {
                StatusRow(title: "学内認証", status: .init(title: account.busy ? "取得・認証中" : "データ取得時に認証", tone: account.busy ? .checking : .neutral),
                          subtitle: "保存済みデータの有無と、現在の認証状態は別に扱います。")
            }
            NavigationLink { materialSettings } label: {
                StatusRow(title: "ファイルの自動確認", status: .init(
                    title: materials.fileRefreshQueue.suspended || specialSchedules.fileRefreshQueue.suspended ? "一時停止中" : "有効",
                    tone: .neutral))
            }
            StatusRow(title: "ローカル保存データ", status: evidence.storageStatus)
            NavigationLink { materialSettings } label: {
                StatusRow(title: "選択ファイルへのアクセス", status: .init(title: "各ファイルの確認結果を参照", tone: .neutral))
            }
        }
    }

    private func refreshPublicData() async {
        guard !Task.isCancelled, visible, scenePhase == .active else { return }
        async let serviceCheck: Void = services.refresh()
        await refreshDistributedData()
        await serviceCheck
    }

    private func refreshDistributedData() async {
        guard !Task.isCancelled, canRefreshDistributedData else { return }
        schoolEvents.reevaluate()
        async let linkCheck: Void = links.refresh(force: true)
        async let mappingCheck: Void = mappings.checkInBackground()
        async let timesCheck: Void = times.check()
        _ = await (linkCheck, mappingCheck, timesCheck)
    }
}
