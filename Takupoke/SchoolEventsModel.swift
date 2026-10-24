import Foundation
import SwiftUI

@MainActor
final class SchoolEventsModel: ObservableObject {
    @Published private(set) var saved: [Int: SavedSchoolEvents] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    @Published private(set) var sourceCheckMessage: String?
    @Published private(set) var failedCacheYears: Set<Int> = []

    var cacheWarning: String? { SchoolEventsAvailableLoad.warning(for: failedCacheYears) }

    private var store: SchoolEventsStore?
    private var task: Task<Void, Never>?
    private var checkedAtStartup = false
    private var sourceTask: Task<Void, Never>?
    private var sourceRefreshPending = false
    private var sourceStore: SchoolEventsSourceStatusStore?
    private var sourceCache: [Int: CachedSchoolEventsSourceStatus] = [:]
    private var sourceFailures: Set<Int> = []

    func refreshAtStartup() {
        loadIfNeeded()
        guard ready else { return }
        if checkedAtStartup { refreshSourceStatus(); return }
        guard !busy else { return }
        checkedAtStartup = true
        let years = saved.keys.sorted()
        guard !years.isEmpty else { return }
        busy = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.busy = false; self.task = nil }
            var failures: [Int] = []
            var updated: [Int] = []
            for year in years {
                do {
                    if try await self.fetchOne(year: year) { updated.append(year) }
                } catch {
                    failures.append(year)
                }
            }
            if !Task.isCancelled { self.refreshSourceStatus() }
            self.failed = !failures.isEmpty
            if !failures.isEmpty {
                self.message = "\(failures.map(String.init).joined(separator: "、"))年度の学校行事を更新確認できませんでした。保存済みの結果を表示しています。"
            } else if !updated.isEmpty {
                self.message = "\(updated.map(String.init).joined(separator: "、"))年度の学校行事を更新しました。"
            }
        }
    }

    /// Status requests never hold the event-data busy state or block tab rendering.
    func refreshSourceStatus(force: Bool = false) {
        loadIfNeeded()
        guard ready, !saved.isEmpty else { return }
        if sourceTask != nil {
            if force { sourceRefreshPending = true }
            return
        }
        updateSourceMessage()
        sourceTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.sourceTask = nil
                if self.sourceRefreshPending && !Task.isCancelled {
                    self.sourceRefreshPending = false
                    self.refreshSourceStatus(force: true)
                }
            }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            for year in self.saved.keys.sorted() {
                guard !Task.isCancelled, let saved = self.saved[year] else { break }
                if !force, self.sourceCache[year]?.isFresh(for: saved, now: Date()) == true { continue }
                do {
                    let value = try await SchoolEventsSourceStatusClient.fetch(year: year, session: session)
                    try Task.checkCancellation()
                    let cached = CachedSchoolEventsSourceStatus(fetchedAt: Date(), value: value)
                    try self.sourceStore?.save(cached)
                    self.sourceCache[year] = cached
                    self.sourceFailures.remove(year)
                } catch {
                    if Task.isCancelled { break }
                    self.sourceFailures.insert(year)
                }
                self.updateSourceMessage()
            }
        }
    }

    private func updateSourceMessage() {
        sourceCheckMessage = saved.keys.sorted().map { year in
            let text: String
            if let cached = sourceCache[year], let saved = saved[year] {
                text = cached.value.message(for: saved, now: Date(), networkFailed: sourceFailures.contains(year))
            } else {
                text = sourceFailures.contains(year) ?
                    "元PDFの更新状況を確認できませんでした。保存済みの学校行事を表示しています。" :
                    "元PDFの更新状況は未確認です。"
            }
            return "\(year)年度: \(text)"
        }.joined(separator: "\n")
    }

    var analysis: PDFAnalysis? {
        guard !saved.isEmpty else { return nil }
        let values = saved.values.sorted { $0.payload.schoolYear < $1.payload.schoolYear }
        return PDFAnalysis(version: PDFAnalysis.currentVersion(for: .events), kind: .events,
                           sourceDigest: values.map(\.payload.sourcePdfSha256).joined(separator: ":"),
                           sourceName: "学校行事API", parsedAt: values.map(\.fetchedAt).max() ?? Date(),
                           schoolYear: values[0].payload.schoolYear, term: nil, lessons: [],
                           events: values.flatMap { $0.payload.projectedEvents }, notices: [])
    }

    func loadIfNeeded() {
        guard !ready else { return }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI", isDirectory: true))
            let available = try opened.loadAvailable()
            saved = available.saved
            failedCacheYears = available.failedYears
            sourceStore = SchoolEventsSourceStatusStore(root: base.appendingPathComponent("SchoolEventsSourceStatus", isDirectory: true))
            sourceCache = Dictionary(uniqueKeysWithValues: saved.keys.compactMap { year in
                sourceStore?.load(year: year).map { (year, $0) }
            })
            store = opened
            ready = true
            failed = false
            message = nil
            updateSourceMessage()
        } catch {
            failed = true
            message = "保存済みの学校行事を読み取れません。端末内の結果は削除していません。"
        }
    }

    func fetch(year: Int) {
        loadIfNeeded()
        guard ready, !busy, (1900...9998).contains(year) else { return }
        busy = true
        failed = false
        message = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let changed = try await self.fetchOne(year: year)
                self.message = changed ? "\(year)年度の学校行事を取得しました。" :
                    "\(year)年度の学校行事に更新はありません。"
            } catch {
                self.failed = true
                self.message = Task.isCancelled ? SchoolEventsError.cancelled.localizedDescription :
                    (error as? SchoolEventsError)?.localizedDescription ?? SchoolEventsError.unavailable.localizedDescription
            }
            if !Task.isCancelled { self.refreshSourceStatus(force: true) }
            self.busy = false
            self.task = nil
        }
    }

    func cancel() { sourceRefreshPending = false; task?.cancel(); sourceTask?.cancel() }

    /// Background cancellation belongs to the awaiting event-data task.
    func refreshInBackground() async -> Bool {
        guard !busy, !Task.isCancelled else { return false }
        loadIfNeeded()
        guard ready else { return false }
        busy = true
        defer { busy = false }
        var succeeded = true
        for year in saved.keys.sorted() {
            do {
                try Task.checkCancellation()
                _ = try await fetchOne(year: year)
            } catch {
                succeeded = false
                if Task.isCancelled { break }
                failed = true
                message = "学校行事を更新確認できませんでした。保存済みの結果を表示しています。"
            }
        }
        if succeeded { failed = false; message = nil }
        return succeeded && !Task.isCancelled
    }

    private func fetchOne(year: Int) async throws -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var components = URLComponents(string: "https://takupoke-api.n624.jp/events")!
        components.queryItems = [URLQueryItem(name: "schoolYear", value: String(year))]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let sentETag = saved[year]?.apiETag
        if let sentETag { request.setValue(sentETag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw SchoolEventsError.unavailable }
        let receivedETag = response.value(forHTTPHeaderField: "ETag")
        if try SchoolEventsResponse.isNotModified(status: response.statusCode, data: data,
                                                   sentETag: sentETag, receivedETag: receivedETag,
                                                   hasSavedResult: saved[year] != nil) {
            return false
        }
        if response.statusCode == 404 { throw SchoolEventsError.unsupportedYear }
        guard response.statusCode == 200,
              response.expectedContentLength <= 1_000_000,
              data.count <= 1_000_000 else { throw SchoolEventsError.unavailable }
        guard receivedETag == nil || SchoolEventsResponse.validETag(receivedETag!) else {
            throw SchoolEventsError.invalidResponse
        }
        let payload = try SchoolEventsPayload.decode(data, requestedYear: year)
        guard let store else { throw SchoolEventsError.unavailable }
        let fetchedAt = Date()
        try store.save(payload, apiETag: receivedETag, fetchedAt: fetchedAt)
        saved[year] = SavedSchoolEvents(fetchedAt: fetchedAt, payload: payload, apiETag: receivedETag)
        failedCacheYears.remove(year)
        updateSourceMessage()
        return true
    }
}
