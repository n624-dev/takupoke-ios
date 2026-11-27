import Foundation
import SwiftUI
import CryptoKit

@MainActor
final class SchoolEventsModel: ObservableObject {
    @Published private(set) var saved: [Int: SavedSchoolEvents] = [:] {
        didSet {
            let changed = saved.count != oldValue.count || saved.contains { year, value in
                guard let previous = oldValue[year] else { return true }
                if let version = value.dataVersion, let oldVersion = previous.dataVersion { return version != oldVersion }
                return value.payload != previous.payload
            }
            if changed {
                let next = projectedAnalysis()
                if !TimetableSchedule.sameProjection(cachedAnalysis, next) { scheduleGeneration = UUID() }
                cachedAnalysis = next
            }
        }
    }
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var failed = false
    @Published private(set) var message: String?
    @Published private(set) var failedCacheYears: Set<Int> = []
    @Published private(set) var sourceStatuses: [Int: SavedSchoolEventsSourceStatus] = [:]
    @Published private(set) var sourceErrors: [Int: String] = [:]
    @Published private(set) var sourcePresentationRevision = 0

    private var cachedAnalysis: PDFAnalysis?
    private(set) var projectionBuildCount = 0
    private(set) var scheduleGeneration = UUID()
    private let storeRoot: URL?
    private let eventsEndpoint: URL
    private let preferredFormat: SchoolEventsFormat
    private let makeSession: () -> URLSession
    private let now: () -> Date
    private let waitForSourceExpiry: (TimeInterval) async throws -> Void
    private let waitForSourceRetry: (TimeInterval) async throws -> Void
    private let canAccessData: () -> Bool

    private enum Demand { case automatic, source, forcedSource, manual }
    private struct Request {
        let id: UUID
        let background: Bool
        let checksBody: Bool
        let checksSource: Bool
        let task: Task<Bool, Never>
    }
    private var requests: [Int: Request] = [:]
    private var states: [Int: SchoolEventsRefreshState] = [:]
    private var failedBodyYears = Set<Int>()
    private var store: SchoolEventsStore?
    private var active: Bool
    private var reachable = true
    private var automaticEnabled = false
    private var wakeup: Task<Void, Never>?
    private var wakeupAt: Date?
    private var wakeupID = UUID()
    private var manualYear: Int?
    private var manualCancelled = false
    private var pausedYears = Set<Int>()
    private var backgroundActive = false

    init(storeRoot: URL? = nil, eventsEndpoint: URL = URL(string: "https://takupoke-api.n624.jp/events")!,
         preferredFormat: SchoolEventsFormat = .v2, makeSession: (() -> URLSession)? = nil,
         now: @escaping () -> Date = Date.init,
         waitForSourceExpiry: @escaping (TimeInterval) async throws -> Void = { seconds in
             try await Task.sleep(nanoseconds: UInt64(min(max(seconds, 0), 86_400) * 1_000_000_000))
         }, waitForSourceRetry: @escaping (TimeInterval) async throws -> Void = { seconds in
             try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
         }, canAccessData: @escaping () -> Bool = { true }, startsActive: Bool = true) {
        self.storeRoot = storeRoot; self.eventsEndpoint = eventsEndpoint
        self.preferredFormat = preferredFormat
        self.makeSession = makeSession ?? { Self.eventsSession() }; self.now = now
        self.waitForSourceExpiry = waitForSourceExpiry; self.waitForSourceRetry = waitForSourceRetry
        self.canAccessData = canAccessData
        self.active = startsActive
    }

    var cacheWarning: String? { SchoolEventsAvailableLoad.warning(for: failedCacheYears) }

    var sourceCheckMessage: String? {
        let warnings = saved.keys.sorted().compactMap { year -> String? in
            sourcePresentation(year: year)?.warningMessage.map { "\(year)年度：\($0)" }
        }
        return warnings.isEmpty ? nil : warnings.joined(separator: "\n")
    }

    func sourcePresentation(year: Int) -> SchoolEventsSourcePresentation? {
        guard let current = saved[year] else { return nil }
        let state = states[year]
        let retry = state?.targetMismatch == true ? Self.mismatchMessage : state?.source.retryAt != nil && state?.followUpAt == nil
            ? "元PDFの状態を確認できません。後で自動確認します。" : nil
        return .make(saved: current, cached: sourceStatuses[year], error: sourceErrors[year] ?? retry, now: now(),
                     firstFailureAt: state?.source.firstFailureAt, checking: isChecking(year: year))
    }

    func isChecking(year: Int) -> Bool { runningRequest(year: year) != nil }

    func didFailBodyCheck(year: Int) -> Bool {
        failedBodyYears.contains(year) || states[year]?.body.firstFailureAt != nil
    }

    private func runningRequest(year: Int) -> Request? {
        guard let request = requests[year], !request.task.isCancelled else { return nil }
        return request
    }

    func countdownSourceState(year: Int, at date: Date) -> CountdownAvailability {
        guard let current = saved[year], let cached = sourceStatuses[year], cached.matches(current),
              let observation = cached.successfulResponse,
              let time = SchoolEventsSourceStatus.date(observation.lastSuccessAt), time <= cached.receivedAt else {
            return countdownUnconfirmedSource(year: year)
        }
        if observation.lastSuccessfulStatus == .source_differs { return .sourceDifference }
        guard states[year]?.targetMismatch != true, observation.lastSuccessfulStatus == .matched,
              !cached.response.stale, time <= date, date.timeIntervalSince(time) < 86_400 else {
            return countdownUnconfirmedSource(year: year)
        }
        return .available
    }

    private func countdownUnconfirmedSource(year: Int) -> CountdownAvailability {
        if runningRequest(year: year)?.checksSource == true || sourcePresentation(year: year)?.evidence == .checking {
            return .sourceChecking
        }
        if sourceErrors[year] != nil { return .sourceCheckFailed }
        return .sourcePending
    }

    func countdownAnnouncementCoverage(year: Int) -> CountdownAnnouncementCoverage {
        if runningRequest(year: year)?.checksBody == true || (!ready && !failed) { return .checking }
        if failedCacheYears.contains(year) || didFailBodyCheck(year: year) || (!ready && failed) { return .unavailable }
        return .missing
    }

    func loadIfNeeded() {
        guard !ready, canAccessData() else { return }
        do {
            let base = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let opened = try SchoolEventsStore(root: base.appendingPathComponent("SchoolEventsAPI", isDirectory: true))
            let available = try opened.loadAvailable()
            saved = available.saved
            failedCacheYears = available.failedYears
            store = opened
            for (year, current) in saved {
                do { sourceStatuses[year] = try opened.loadSourceStatus(year: year) }
                catch { sourceErrors[year] = "保存済みの元PDF確認結果を読み取れません。学校行事は表示しています。" }
                if let state = try? opened.loadRefreshState(year: year),
                   state.target == SchoolEventsSourceTarget(current), state.requestedBodyFormat == preferredFormat {
                    states[year] = state
                } else {
                    states[year] = SchoolEventsRefreshState(target: SchoolEventsSourceTarget(current),
                                                            requestedBodyFormat: preferredFormat)
                }
            }
            ready = true
            failed = false
            message = nil
            scheduleWakeup()
        } catch {
            failed = true
            message = "保存済みの学校行事を読み取れません。端末内の結果は削除していません。"
        }
    }

    func refreshAtStartup() {
        automaticEnabled = true
        reevaluate()
    }

    func setSourceChecksActive(_ active: Bool) {
        guard active != self.active else { return }
        self.active = active
        if active {
            pausedYears.removeAll()
            reevaluate()
        }
        else {
            cancelWakeup()
            for request in requests.values where !request.background { request.task.cancel() }
        }
    }

    func setNetworkReachable(_ reachable: Bool) {
        guard reachable != self.reachable else { return }
        self.reachable = reachable
        if reachable { reevaluate() }
        else { scheduleWakeup() }
    }

    func reevaluate() {
        guard active else { return }
        loadIfNeeded()
        sourcePresentationRevision += 1
        if automaticEnabled {
            for year in saved.keys.sorted() { start(year: year, demand: .automatic) }
        } else {
            for (year, state) in states where state.followUpAt != nil { start(year: year, demand: .source) }
        }
        scheduleWakeup()
    }

    @discardableResult
    func checkSource(year: Int, force: Bool = false) -> Task<Bool, Never>? {
        start(year: year, demand: force ? .forcedSource : .source)?.task
    }

    func fetch(year: Int) {
        loadIfNeeded()
        guard ready, manualYear == nil, (1900...9998).contains(year) else { return }
        failed = false
        message = nil
        guard let request = start(year: year, demand: .manual) else {
            failedBodyYears.insert(year)
            failed = true; message = SchoolEventsError.unavailable.localizedDescription
            sourcePresentationRevision += 1
            return
        }
        manualYear = year
        manualCancelled = false
        busy = true
        Task { [weak self] in
            var succeeded = await request.task.value
            guard let self else { return }
            defer { self.busy = false; self.manualYear = nil }
            guard !self.manualCancelled else { return }
            if !request.checksBody && !request.task.isCancelled, self.message == nil,
               let combined = self.start(year: year, demand: .manual) {
                succeeded = await combined.task.value
            } else if !request.checksSource && !request.task.isCancelled,
                      let source = self.start(year: year, demand: .forcedSource) {
                let confirmed = await source.task.value
                succeeded = succeeded && confirmed
            }
            guard !self.manualCancelled else { return }
            if !succeeded && self.message == nil {
                self.failed = true
                self.message = request.task.isCancelled ? SchoolEventsError.cancelled.localizedDescription
                    : SchoolEventsError.unavailable.localizedDescription
            }
        }
    }

    func cancel() {
        let years: Set<Int>
        if let manualYear {
            years = [manualYear]
            manualCancelled = true
            failed = true
            message = SchoolEventsError.cancelled.localizedDescription
        } else {
            years = Set(requests.keys).union(states.compactMap { $0.value.followUpAt == nil ? nil : $0.key })
        }
        pausedYears.formUnion(years)
        for year in years {
            requests[year]?.task.cancel()
            if var state = states[year], state.followUpAt != nil {
                state.followUpAt = nil; state.followUpsRemaining = nil
                record(state)
            }
        }
        cancelWakeup()
        if manualYear != nil { scheduleWakeup() }
    }

    /// No timer or repeated source request is owned by a background execution.
    func refreshInBackground() async -> Bool {
        guard !backgroundActive, !Task.isCancelled, canAccessData() else { return false }
        loadIfNeeded()
        guard ready else { return false }
        backgroundActive = true
        defer { backgroundActive = false }
        var succeeded = true
        for year in saved.keys.sorted() {
            guard !Task.isCancelled, canAccessData() else { return false }
            let existing = runningRequest(year: year)
            guard let request = start(year: year, demand: .automatic, background: true) else { continue }
            let result = await withTaskCancellationHandler {
                await request.task.value
            } onCancel: {
                if existing == nil { request.task.cancel() }
            }
            if !result { succeeded = false }
        }
        return succeeded && !Task.isCancelled
    }

    private func nextBodyCheck(_ current: SavedSchoolEvents, state: SchoolEventsRefreshState, at date: Date) -> Date {
        let last = current.payload.format == preferredFormat ? current.lastEventsCheckedAt : nil
        let regular = last.flatMap { $0 <= date ? $0.addingTimeInterval(3_600) : nil } ?? date
        return max(regular, state.body.retryAt ?? .distantPast)
    }

    private func nextSourceCheck(_ current: SavedSchoolEvents, state: SchoolEventsRefreshState, at date: Date) -> Date {
        // A fresh checking response owns its bounded follow-up schedule.
        // A failure in that cycle clears the follow-up before setting backoff.
        if let followUp = state.followUpAt { return followUp }
        let cached = sourceStatuses[current.payload.schoolYear].flatMap { $0.matches(current) ? $0 : nil }
        let regular: Date
        if let cached, cached.receivedAt <= date, !cached.response.checking, !cached.response.stale,
           cached.response.status == .matched || cached.response.status == .source_differs {
            regular = cached.nextRegularCheck
        } else if let cached, cached.response.checking, cached.receivedAt <= date, state.source.retryAt == nil {
            regular = cached.receivedAt.addingTimeInterval(60)
        } else {
            regular = date
        }
        let serverWait: Date?
        if let cached, cached.response.status == .unavailable, !cached.response.checking, state.source.retryAt != nil,
           let upcoming = SchoolEventsSourceStatus.date(cached.response.nextAttemptAt),
           upcoming.timeIntervalSince(date) <= 8 * 86_400 {
            serverWait = upcoming
        } else { serverWait = nil }
        return max(regular, state.source.retryAt ?? .distantPast, serverWait ?? .distantPast)
    }

    private func cancelWakeup() {
        wakeup?.cancel()
        wakeup = nil; wakeupAt = nil; wakeupID = UUID()
    }

    private func scheduleWakeup() {
        guard active, ready else { cancelWakeup(); return }
        let date = now()
        var candidates: [(Date, Bool)] = []
        for (year, current) in saved {
            guard let state = states[year] else { continue }
            if !pausedYears.contains(year) && !isChecking(year: year) && reachable && canAccessData() {
                if automaticEnabled {
                    candidates.append((nextBodyCheck(current, state: state, at: date), false))
                    candidates.append((nextSourceCheck(current, state: state, at: date), state.followUpAt != nil))
                } else if state.followUpAt != nil {
                    candidates.append((nextSourceCheck(current, state: state, at: date), true))
                }
            }
            let cached = sourceStatuses[year].flatMap { $0.matches(current) ? $0 : nil }
            if let cached {
                let expires = cached.receivedAt.addingTimeInterval(cached.response.checking ? 60 : 43_200)
                if expires > date { candidates.append((expires, state.followUpAt == expires)) }
            }
            let success = SchoolEventsSourceStatus.date(cached?.successfulResponse?.lastSuccessAt)
            if let expiry = success?.addingTimeInterval(86_400), expiry > date {
                candidates.append((expiry, false))
            }
            if state.source.firstFailureAt != nil, let anchor = success ?? state.source.firstFailureAt {
                let expires = anchor.addingTimeInterval(48 * 3_600)
                if expires > date { candidates.append((expires, false)) }
            }
        }
        guard let (deadline, followUp) = candidates.min(by: { $0.0 < $1.0 }) else { cancelWakeup(); return }
        if wakeupAt == deadline { return }
        cancelWakeup()
        wakeupAt = deadline
        let id = wakeupID, wait = followUp ? waitForSourceRetry : waitForSourceExpiry
        wakeup = Task { [weak self] in
            do { try await wait(max(0, deadline.timeIntervalSince(date))) } catch { return }
            guard !Task.isCancelled, let self, self.wakeupID == id else { return }
            self.wakeup = nil; self.wakeupAt = nil
            self.reevaluate()
        }
    }

    @discardableResult
    private func start(year: Int, demand: Demand, background: Bool = false) -> Request? {
        let explicit = demand == .manual || demand == .forcedSource
        guard ready, (active || background), reachable, canAccessData(),
              demand == .manual || saved[year] != nil, explicit || !pausedYears.contains(year) else { return nil }
        if explicit { pausedYears.remove(year) }
        if let request = runningRequest(year: year) { return request }
        let date = now()
        var dueBody = demand == .manual
        var dueSource = demand == .manual || demand == .forcedSource
        if let current = saved[year], var state = states[year] {
            let previous = state
            state.adjustClock(at: date)
            if state != previous { record(state) }
            if demand == .automatic { dueBody = nextBodyCheck(current, state: state, at: date) <= date }
            dueSource = dueSource || nextSourceCheck(current, state: state, at: date) <= date
        }
        guard dueBody || dueSource else { return nil }
        let id = UUID()
        let task = Task { [weak self] in
            guard let self else { return false }
            let result = await self.refresh(year: year, body: dueBody, source: dueSource, demand: demand, background: background)
            if self.requests[year]?.id == id {
                self.requests[year] = nil
                self.sourcePresentationRevision += 1
                self.scheduleWakeup()
            }
            return result
        }
        let request = Request(id: id, background: background, checksBody: dueBody, checksSource: dueSource, task: task)
        requests[year] = request
        sourcePresentationRevision += 1
        return request
    }

    private func record(_ value: SchoolEventsRefreshState) {
        if states[value.target.year] == value { return }
        // Also observe the deadline within this process if the metadata write fails.
        states[value.target.year] = value
        do { try store?.saveRefreshState(value) }
        catch { /* No confirmed observation or body timestamp depends on this write. */ }
    }

    private func refresh(year: Int, body: Bool, source: Bool, demand: Demand, background: Bool) async -> Bool {
        var checkedBody = false
        var bodySucceeded = true
        let retryAllowsReconciliation = states[year]?.body.retryAt.map { $0 <= now() } ?? true
        if body || (source && states[year]?.deferredReconciliation == true && retryAllowsReconciliation) {
            checkedBody = true
            bodySucceeded = await confirmBody(year: year, manual: demand == .manual)
        }
        guard !Task.isCancelled, canAccessData(), let current = saved[year], var state = states[year] else {
            return bodySucceeded && !Task.isCancelled
        }
        if checkedBody && state.deferredReconciliation { state.deferredReconciliation = false; record(state) }
        guard source || checkedBody && nextSourceCheck(current, state: state, at: now()) <= now() else { return bodySucceeded }

        if state.followUpAt != nil {
            if let remaining = state.followUpsRemaining, remaining > 0 {
                state.followUpsRemaining = remaining - 1
                // Record request consumption before waiting on the response.
                state.followUpAt = now().addingTimeInterval(60)
                record(state)
            } else if demand == .automatic || demand == .source {
                recordSourceFailure(state, message: "元PDFの確認結果をまだ取得できません。後で自動確認します。")
                return false
            } else {
                state.followUpAt = nil; state.followUpsRemaining = nil
                record(state)
            }
        }

        do {
            let status = try await readSource(year: year, format: state.target.format ?? .v1)
            guard !Task.isCancelled, canAccessData() else { return false }
            let differs = status.matches(current) && status.lastSuccessfulStatus == .source_differs &&
                SchoolEventsSourceStatus.date(status.lastSuccessAt).map { $0 <= now() && $0 > (state.differenceCheckedAt ?? .distantPast) } == true
            if status.matches(current) {
                try acceptSource(status, targeted: current)
                if differs, var updated = states[year] {
                    updated.differenceCheckedAt = SchoolEventsSourceStatus.date(status.lastSuccessAt)
                    record(updated)
                }
            } else if var updated = states[year] {
                updated.targetMismatch = true
                record(updated)
            }
            guard !status.matches(current) || differs else { return bodySucceeded }
            if background {
                if !checkedBody, var updated = states[year] {
                    updated.deferredReconciliation = true
                    record(updated)
                }
                if !status.matches(current), let updated = states[year] { recordSourceFailure(updated, message: Self.mismatchMessage) }
                return bodySucceeded && status.matches(current)
            }

            if !checkedBody && !retryAllowsReconciliation {
                if var updated = states[year] {
                    updated.deferredReconciliation = true
                    record(updated)
                    if !status.matches(current) { recordSourceFailure(updated, message: Self.mismatchMessage) }
                }
                return false
            }
            if !checkedBody { bodySucceeded = await confirmBody(year: year, manual: false) }
            guard !Task.isCancelled, canAccessData(), let updated = saved[year] else { return false }
            if current.payload.format == updated.payload.format, status.matches(updated) {
                if !status.matches(current) { try acceptSource(status, targeted: updated) }
                return bodySucceeded
            }
            // One recheck after the body recovery. Never re-enter this path for its response.
            let rechecked = try await readSource(year: year, format: SchoolEventsSourceTarget(updated).format ?? .v1)
            guard !Task.isCancelled, canAccessData() else { return false }
            guard rechecked.matches(updated) else {
                if let state = states[year] { recordSourceFailure(state, message: Self.mismatchMessage) }
                return false
            }
            try acceptSource(rechecked, targeted: updated)
            return bodySucceeded
        } catch {
            guard !Task.isCancelled, canAccessData(), let latest = states[year] else { return false }
            let information = (error as? BoundedHTTPResponse.Failure)?.localizedDescription ?? "元PDFの状態を確認できません。"
            recordSourceFailure(latest, message: information + "後で自動確認します。保存済みの結果を表示しています。")
            return false
        }
    }

    private static let mismatchMessage = "APIと保存済み行事の配信版または元PDFが一致しません。後で自動確認します。"

    private func recordSourceFailure(_ value: SchoolEventsRefreshState, message: String) {
        var state = value
        state.followUpAt = nil; state.followUpsRemaining = nil
        state.source.fail(at: now())
        record(state)
        sourceErrors[value.target.year] = message
    }

    private func acceptSource(_ status: SchoolEventsSourceStatus, targeted current: SavedSchoolEvents) throws {
        guard let store, var state = states[status.schoolYear], state.target == SchoolEventsSourceTarget(current) else {
            throw SchoolEventsError.unavailable
        }
        let date = now()
        let observation = SchoolEventsSourceStatus.date(status.lastSuccessAt)
        guard observation.map({ $0 <= date }) != false else { throw SchoolEventsError.invalidResponse }
        let previous = sourceStatuses[status.schoolYear]
        let cached = SavedSchoolEventsSourceStatus(receivedAt: date, response: status, requestedTarget: state.target, previous: previous)
        try store.saveSourceStatus(cached)
        let eligible = !status.checking && !status.stale && cached.previousSuccess == nil &&
            (status.status == .matched || status.status == .source_differs) &&
            SchoolEventsSourceStatus.date(status.nextAttemptAt).map { $0 > date } != false &&
            observation.map { date.timeIntervalSince($0) >= 0 && date.timeIntervalSince($0) < 86_400 } == true
        let afterFailure = state.source.firstFailureAt
        if eligible && (afterFailure == nil || observation.map { $0 >= afterFailure! } == true) {
            state.source = SchoolEventsRetry()
            state.followUpAt = nil; state.followUpsRemaining = nil
            state.targetMismatch = false
            record(state)
            sourceErrors.removeValue(forKey: status.schoolYear)
        } else if status.checking && !status.stale && state.followUpsRemaining != 0 {
            if state.followUpsRemaining == nil { state.followUpsRemaining = 3 }
            state.followUpAt = date.addingTimeInterval(60)
            record(state)
            sourceErrors.removeValue(forKey: status.schoolYear)
        } else {
            let pending = status.checking ? "元PDFの確認結果をまだ取得できません。後で自動確認します。"
                : "元PDFの現在の更新状況は未確認です。後で自動確認します。"
            recordSourceFailure(state, message: pending)
        }
        sourceStatuses[status.schoolYear] = cached
    }

    private func readSource(year: Int, format: SchoolEventsFormat) async throws -> SchoolEventsSourceStatus {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var components = URLComponents(url: eventsEndpoint.appendingPathComponent("source-status"), resolvingAgainstBaseURL: false)!
        components.queryItems = Self.eventsQuery(year: year, format: format)
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await BoundedHTTPResponse.read(request, using: session, maximum: 16_384)
        try Task.checkCancellation()
        guard response.statusCode == 200 else { throw SchoolEventsError.unavailable }
        return try SchoolEventsSourceStatus.decode(data, year: year)
    }

    private func confirmBody(year: Int, manual: Bool) async -> Bool {
        do {
            let changed = try await fetchOne(year: year)
            failedBodyYears.remove(year)
            if var state = states[year] { state.body = SchoolEventsRetry(); record(state) }
            if manualYear == year || manual {
                message = changed ? "\(year)年度の学校行事を取得しました。" : "\(year)年度の学校行事に更新はありません。"
            }
            return true
        } catch {
            guard !Task.isCancelled, canAccessData() else { return false }
            failedBodyYears.insert(year)
            if var state = states[year] { state.body.fail(at: now()); record(state) }
            if manualYear == year || manual {
                failed = true
                message = (error as? BoundedHTTPResponse.Failure)?.localizedDescription ??
                    (error as? SchoolEventsError)?.localizedDescription ?? SchoolEventsError.unavailable.localizedDescription
            }
            return false
        }
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

    private static func eventsQuery(year: Int, format: SchoolEventsFormat) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "schoolYear", value: String(year))]
        if format == .v2 { items.append(URLQueryItem(name: "format", value: format.rawValue)) }
        return items
    }

    private func fetchOne(year: Int) async throws -> Bool {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        var components = URLComponents(url:eventsEndpoint,resolvingAgainstBaseURL:false)!
        components.queryItems = Self.eventsQuery(year: year, format: preferredFormat)
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let stored = saved[year].flatMap { $0.payload.format == preferredFormat ? $0 : nil }
        let sentETag = stored?.apiETag
        if let sentETag { request.setValue(sentETag, forHTTPHeaderField: "If-None-Match") }
        let (data, response) = try await BoundedHTTPResponse.read(request, using: session, maximum: 1_000_000)
        try Task.checkCancellation()
        guard canAccessData(), let store else { throw SchoolEventsError.unavailable }
        let receivedETag = response.value(forHTTPHeaderField: "ETag")
        let date = now()
        if try SchoolEventsResponse.isNotModified(status: response.statusCode, data: data,
                                                   sentETag: sentETag, receivedETag: receivedETag,
                                                   hasSavedResult: stored != nil) {
            guard let stored else { throw SchoolEventsError.invalidResponse }
            let confirmed = SavedSchoolEvents(fetchedAt: stored.fetchedAt, payload: stored.payload,
                apiETag: stored.apiETag, responseDataVersion: stored.responseDataVersion, lastEventsCheckedAt: date)
            try store.save(confirmed)
            saved[year] = confirmed
            return false
        }
        if response.statusCode == 404 { throw SchoolEventsError.unsupportedYear }
        guard response.statusCode == 200 else { throw SchoolEventsError.unavailable }
        guard receivedETag == nil || SchoolEventsResponse.validETag(receivedETag!) else {
            throw SchoolEventsError.invalidResponse
        }
        let payload = try SchoolEventsPayload.decode(data, requestedYear: year, requestedFormat: preferredFormat)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if preferredFormat == .v2, receivedETag != "W/\"\(hash)\"", receivedETag != "\"\(hash)\"" {
            throw SchoolEventsError.invalidResponse
        }
        let dataVersion = "sha256-" + hash
        let changed = stored.map { $0.dataVersion.map { $0 != dataVersion } ?? ($0.payload != payload) } ?? true
        let accepted = SavedSchoolEvents(fetchedAt: changed ? date : (stored?.fetchedAt ?? date),
            payload: payload, apiETag: receivedETag, responseDataVersion: dataVersion, lastEventsCheckedAt: date)
        try store.save(accepted)
        let target = SchoolEventsSourceTarget(accepted)
        if states[year]?.target != target {
            record(SchoolEventsRefreshState(target: target, requestedBodyFormat: preferredFormat))
            sourceErrors.removeValue(forKey: year)
        }
        saved[year] = accepted
        failedCacheYears.remove(year)
        return changed
    }
}
