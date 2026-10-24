import Foundation
import SwiftUI
import CryptoKit

@MainActor
final class SchoolEventsModel: ObservableObject {
    @Published private(set) var saved: [Int: SavedSchoolEvents] = [:] {
        didSet {
            let next = projectedAnalysis()
            if !TimetableSchedule.sameProjection(cachedAnalysis,next) { scheduleGeneration = UUID() }
            cachedAnalysis = next
        }
    }
    private var cachedAnalysis: PDFAnalysis?
    private(set) var projectionBuildCount = 0
    private(set) var scheduleGeneration = UUID()
    private let storeRoot: URL?
    private let eventsEndpoint: URL
    private let makeSession: () -> URLSession
    private let now: () -> Date
    init(storeRoot:URL? = nil,eventsEndpoint:URL = URL(string:"https://takupoke-api.n624.jp/events")!,
         makeSession:(() -> URLSession)? = nil, now: @escaping () -> Date = Date.init) {
        self.storeRoot = storeRoot; self.eventsEndpoint = eventsEndpoint
        self.makeSession = makeSession ?? { Self.eventsSession() }; self.now = now
    }
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    @Published private(set) var sourceStatuses: [Int: SavedSchoolEventsSourceStatus] = [:]
    @Published private(set) var sourceErrors: [Int: String] = [:]

    var sourceCheckMessage: String? {
        let warnings = saved.keys.sorted().compactMap { year -> String? in
            guard let value = sourcePresentation(year: year), value.warning else { return nil }
            return "\(year)年度：\(value.message)"
        }
        return warnings.isEmpty ? nil : warnings.joined(separator: "\n")
    }

    func sourcePresentation(year: Int) -> SchoolEventsSourcePresentation? {
        guard let value = saved[year] else { return nil }
        return .make(saved: value, cached: sourceStatuses[year], error: sourceErrors[year], now: now())
    }
    @Published private(set) var failedCacheYears: Set<Int> = []

    var cacheWarning: String? { SchoolEventsAvailableLoad.warning(for: failedCacheYears) }

    private var store: SchoolEventsStore?
    private var task: Task<Void, Never>?
    private var checkedAtStartup = false
    private typealias SourceBinding = SchoolEventsSourceTarget
    private struct SourceRequest {
        let id: UUID
        let binding: SourceBinding
        let task: Task<Void, Never>
    }
    private var sourceRequests: [Int: SourceRequest] = [:]

    func refreshAtStartup() {
        loadIfNeeded()
        guard ready else { return }
        // Foreground checks consult their own TTL even after the annual startup
        // conditional GET has already run. They never own the data busy state.
        for year in saved.keys.sorted() { checkSource(year: year) }
        guard !checkedAtStartup, !busy else { return }
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
            if !Task.isCancelled { for year in years { self.checkSource(year: year) } }
            self.failed = !failures.isEmpty
            if !failures.isEmpty {
                self.message = "\(failures.map(String.init).joined(separator: "、"))年度の学校行事を更新確認できませんでした。保存済みの結果を表示しています。"
            } else if !updated.isEmpty {
                self.message = "\(updated.map(String.init).joined(separator: "、"))年度の学校行事を更新しました。"
            }
        }
    }

    /// Starts an independently owned metadata request without delaying tab
    /// presentation or annual data fetching. Repeated callers join one year.
    @discardableResult
    func checkSource(year: Int, force: Bool = false) -> Task<Void, Never>? {
        guard ready, let savedValue = saved[year] else { return nil }
        let binding = SourceBinding(savedValue)
        if let running = sourceRequests[year], running.binding == binding { return running.task }
        if !force, let cached = sourceStatuses[year], cached.canReuse(for: savedValue, at: now()) { return nil }
        sourceRequests[year]?.task.cancel()
        let id = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.sourceRequests[year]?.id == id { self.sourceRequests[year] = nil }
            }
            let session = self.makeSession()
            defer { session.invalidateAndCancel() }
            do {
                var components = URLComponents(url: self.eventsEndpoint.appendingPathComponent("source-status"),
                                               resolvingAgainstBaseURL: false)!
                components.queryItems = [.init(name: "schoolYear", value: String(year))]
                var request = URLRequest(url: components.url!)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      response.expectedContentLength <= 16_384 else { throw SchoolEventsError.unavailable }
                let status = try SchoolEventsSourceStatus.decode(data, year: year)
                guard self.sourceRequests[year]?.id == id, let current = self.saved[year],
                      SourceBinding(current) == binding else { return }
                let cached = SavedSchoolEventsSourceStatus(receivedAt: self.now(), response: status,
                                                          requestedTarget: binding,
                                                          previous: self.sourceStatuses[year])
                guard let store = self.store else { throw SchoolEventsError.unavailable }
                try store.saveSourceStatus(cached)
                self.sourceStatuses[year] = cached
                self.sourceErrors[year] = nil
            } catch {
                guard !Task.isCancelled, self.sourceRequests[year]?.id == id,
                      self.saved[year].map(SourceBinding.init) == binding else { return }
                self.sourceErrors[year] = "元PDFの状態APIを確認できませんでした。保存済み行事と前回の確認結果を保持しています。"
            }
        }
        sourceRequests[year] = SourceRequest(id: id, binding: binding, task: task)
        return task
    }

    var analysis: PDFAnalysis? { cachedAnalysis }
    private func projectedAnalysis() -> PDFAnalysis? {
        projectionBuildCount += 1
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
            let base = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI", isDirectory: true))
            let available = try opened.loadAvailable()
            saved = available.saved
            failedCacheYears = available.failedYears
            store = opened
            for year in saved.keys.sorted() {
                do { sourceStatuses[year] = try opened.loadSourceStatus(year: year) }
                catch { sourceErrors[year] = "保存済みの元PDF確認結果を読み取れません。学校行事は表示しています。" }
            }
            ready = true
            failed = false
            message = nil
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
            self.busy = false
            self.task = nil
            if !Task.isCancelled { self.checkSource(year: year, force: true) }
        }
    }

    func cancel() {
        task?.cancel()
        for value in sourceRequests.values { value.task.cancel() }
        sourceRequests.removeAll()
    }

    /// Reuse the conditional API fetch without making another school PDF HEAD
    /// request. Background cancellation must belong to the awaiting task.
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

    private static func eventsSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        return URLSession(configuration: configuration)
    }

    private func fetchOne(year: Int) async throws -> Bool {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var components = URLComponents(url:eventsEndpoint,resolvingAgainstBaseURL:false)!
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
        let fetchedAt = now()
        let dataVersion = "sha256-" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try store.save(payload, apiETag: receivedETag, fetchedAt: fetchedAt, responseDataVersion: dataVersion)
        saved[year] = SavedSchoolEvents(fetchedAt: fetchedAt, payload: payload, apiETag: receivedETag,
                                      responseDataVersion: dataVersion)
        failedCacheYears.remove(year)
        return true
    }
}
