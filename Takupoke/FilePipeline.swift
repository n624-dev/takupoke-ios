import Foundation

/// Provider and parser jobs never receive the live store. An expired job retains
/// its private workspace until its synchronous I/O has actually returned.
final class FilePipeline: @unchecked Sendable {
    enum Stage: String, Codable, Sendable { case queued, access, acquiring, checkingDigest, parsing, validating, saving, succeeded, unchanged, cancelled, timedOut, failed, recovering }
    enum Reason: String, Codable, Sendable { case automatic, manual, selection, background, review }
    enum Failure: Error, Equatable, LocalizedError {
        case cancelled, timedOut, recovering, stale
        var errorDescription: String? {
            switch self {
            case .cancelled: return "確認を中止しました。前回の正常結果は保持しています。"
            case .timedOut: return "更新確認が期限切れになりました。前回の正常結果は保持しています。"
            case .recovering: return "旧処理の終了を待っています。終了後に再取得できます。"
            case .stale: return "資料または保存期間が変わったため、この結果は反映しませんでした。"
            }
        }
    }
    struct Limits: Sendable {
        var access: TimeInterval = 30
        var idle: TimeInterval = 60
        var parsing: TimeInterval = 120
        var overall: TimeInterval = 240
        var retryDelay: TimeInterval = 3
        var retries = 2
    }
    struct Status: Sendable, Equatable {
        let id: UUID
        let requestID: UUID
        let reason: Reason
        var stage: Stage
        var waitingForWorker: Bool
        var attempt: Int
        let startedAt: Date
        var finishedAt: Date?
        var checkedAt: Date?
        var acquiredThisAttempt = false
        var acquiredAt: Date?
        var parsedAt: Date?

        var canRetryMonitorRegistration: Bool {
            guard acquiredThisAttempt, !waitingForWorker else { return false }
            // A committed provider acquisition is usable for monitoring even
            // when the subsequently reported error is a parse failure.
            return [.succeeded, .unchanged, .failed].contains(stage)
        }
    }
    final class Ticket: @unchecked Sendable {
        let id = UUID()
        let requestID: UUID
        let source: FileRefreshDiagnostics.Source
        let reason: Reason
        let attempt: Int
        let period: SchoolDataPeriod
        private let lock = NSLock()
        private let now: @Sendable () -> TimeInterval
        private let limits: Limits
        private let started: TimeInterval
        private var phaseStarted: TimeInterval
        private var progressAt: TimeInterval
        private var phase = Stage.access
        private var stopped: Failure?
        private var committing = false
        private var explicitlyCancelled = false
        private var abort: (() -> Void)?
        private var acknowledgements: [() -> Void] = []
        private var acquisitionDate: Date?
        private var analysisDate: Date?
        private var committed = false
        private var sameContent = false
        func unchanged() { lock.lock(); sameContent = true; lock.unlock() }
        var completionStage: Stage { lock.lock(); defer { lock.unlock() }; return sameContent && analysisDate == nil ? .unchanged : .succeeded }
        func acquired() { lock.lock(); acquisitionDate = Date(); lock.unlock() }
        func parsed() { lock.lock(); analysisDate = Date(); lock.unlock() }
        var successDates: (checked: Date?, acquired: Date?, parsed: Date?) {
            lock.lock(); defer { lock.unlock() }
            return committed ? (acquisitionDate, acquisitionDate, analysisDate) : (nil, nil, nil)
        }
        func afterCommit(_ body: @escaping () -> Void) { lock.lock(); acknowledgements.append(body); lock.unlock() }
        func didCommit() {
            lock.lock(); committed = true; let callbacks = acknowledgements; acknowledgements.removeAll(); lock.unlock()
            if !callbacks.isEmpty { DispatchQueue.global(qos: .utility).async { callbacks.forEach { $0() } } }
        }
        init(source: FileRefreshDiagnostics.Source, reason: Reason, period: SchoolDataPeriod, limits: Limits, attempt: Int = 0, requestID: UUID? = nil,
             now: @escaping @Sendable () -> TimeInterval) {
            self.requestID = requestID ?? id
            self.source = source; self.reason = reason; self.attempt = attempt; self.period = period; self.limits = limits; self.now = now
            let tick = now(); started = tick; phaseStarted = tick; progressAt = tick
        }
        private func evaluateLocked() {
            guard !committing, stopped == nil else { return }
            let tick = now()
            if tick - started >= limits.overall ||
                (phase == .access && tick - phaseStarted >= limits.access) ||
                (phase == .acquiring && tick - progressAt >= limits.idle) ||
                (phase == .parsing && tick - phaseStarted >= limits.parsing) { stopped = .timedOut }
        }
        func enter(_ stage: Stage) {
            lock.lock(); evaluateLocked()
            let advance = stopped == nil && phase != stage
            if advance { phase = stage; phaseStarted = now(); progressAt = phaseStarted }
            lock.unlock()
            if advance { FileRefreshDiagnostics.shared.record(.pipelineStage, source: source, operationID: requestID, reason: reason, stage: stage, attempt: attempt) }
        }
        func progress() {
            lock.lock(); evaluateLocked()
            if stopped == nil { progressAt = now() }
            lock.unlock()
        }
        func onAbort(_ body: (() -> Void)?) {
            lock.lock()
            if stopped == nil { abort = body; lock.unlock() }
            else { abort = nil; lock.unlock(); if let body { DispatchQueue.global(qos: .utility).async(execute: body) } }
        }
        @discardableResult
        func cancel() -> Bool {
            lock.lock()
            explicitlyCancelled = true
            let canStop = !committing
            if canStop { stopped = .cancelled }
            let callback = canStop ? abort : nil
            if callback != nil { abort = nil }
            lock.unlock()
            if let callback { DispatchQueue.global(qos: .utility).async(execute: callback) }
            return canStop
        }
        var permitsRetry: Bool { lock.lock(); defer { lock.unlock() }; return !explicitlyCancelled && period == .current() }
        var stage: Stage { lock.lock(); defer { lock.unlock() }; return phase }
        func check() throws {
            lock.lock(); evaluateLocked()
            let failure = stopped
            let callback = failure != nil ? abort : nil
            if callback != nil { abort = nil }
            lock.unlock()
            if let callback { DispatchQueue.global(qos: .utility).async(execute: callback) }
            if let failure { throw failure }
        }
        /// Linearization point: cancellation before this point rejects the commit;
        /// cancellation after it cannot undo an atomic store transaction.
        func beginCommit(period: SchoolDataPeriod) throws {
            lock.lock(); defer { lock.unlock() }
            evaluateLocked()
            if let stopped { throw stopped }
            guard self.period == period else { throw Failure.stale }
            committing = true
            phase = .saving
        }
    }
    private final class ResultBox<T>: @unchecked Sendable {
        let lock = NSLock()
        var value: Result<T, Error>?
        func put(_ result: Result<T, Error>) { lock.lock(); value = result; lock.unlock() }
        func take() -> Result<T, Error>? { lock.lock(); defer { lock.unlock() }; return value }
    }
    private final class PendingCleanup: @unchecked Sendable {
        private let lock = NSLock()
        private var action: (() -> Void)?
        init(_ action: @escaping () -> Void) { self.action = action }
        func run() {
            lock.lock(); let action = self.action; self.action = nil; lock.unlock()
            action?()
        }
    }
    static let shared = FilePipeline()
    private let lock = NSLock()
    private var intents: [FileRefreshDiagnostics.Source: UInt64] = [:]
    private var active: [FileRefreshDiagnostics.Source: Ticket] = [:]
    private var states: [FileRefreshDiagnostics.Source: Status] = [:]
    private var backoffs: [FileRefreshDiagnostics.Source: (id: UUID, started: TimeInterval, timer: DispatchSourceTimer, cleanup: () -> Void)] = [:]
    private let now: @Sendable () -> TimeInterval
    let limits: Limits
    init(limits: Limits = Limits(), now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.limits = limits; self.now = now
    }
    var intentSnapshot: [String: UInt64] {
        lock.lock(); defer { lock.unlock() }
        return Dictionary(uniqueKeysWithValues: FileRefreshDiagnostics.Source.allCases.map { ($0.rawValue, intents[$0, default: 0]) })
    }
    var activeSources: Set<FileRefreshDiagnostics.Source> { lock.lock(); defer { lock.unlock() }; return Set(active.keys) }
    var snapshot: [FileRefreshDiagnostics.Source: Status] {
        lock.lock(); defer { lock.unlock() }
        expireBackoffsLocked()
        return states
    }
    func cancel(_ rawSource: String) {
        if let source = FileRefreshDiagnostics.Source(rawValue: rawSource) { cancel([source]) }
    }
    func cancel(_ sources: [FileRefreshDiagnostics.Source]) {
        lock.lock()
        for source in sources {
            intents[source, default: 0] &+= 1
            guard let ticket = active[source] else { continue }
            let stopped = ticket.cancel()
            if let pending = backoffs[source], pending.id == ticket.id {
                pending.timer.cancel(); backoffs.removeValue(forKey: source); active.removeValue(forKey: source)
                states[source]?.waitingForWorker = false
                DispatchQueue.global(qos: .utility).async(execute: pending.cleanup)
            }
            if stopped, states[source]?.id == ticket.id { states[source]?.stage = .cancelled }
        }
        lock.unlock()
    }
    func clearTerminalStatus(_ source: FileRefreshDiagnostics.Source) {
        lock.lock()
        intents[source, default: 0] &+= 1
        active[source]?.cancel()
        if let pending = backoffs.removeValue(forKey: source) {
            pending.timer.cancel()
            if active[source]?.id == pending.id { active.removeValue(forKey: source) }
            DispatchQueue.global(qos: .utility).async(execute: pending.cleanup)
        }
        states.removeValue(forKey: source)
        lock.unlock()
    }
    func clearStatuses(_ sources: [FileRefreshDiagnostics.Source]) {
        lock.lock(); for source in sources { states.removeValue(forKey: source) }; lock.unlock()
    }
    func isRecovering(_ rawSource: String) -> Bool {
        FileRefreshDiagnostics.Source(rawValue: rawSource).map { isRecovering($0) } ?? false
    }
    func isRecovering(_ source: FileRefreshDiagnostics.Source) -> Bool {
        lock.lock(); defer { lock.unlock() }; return active[source] != nil
    }
    /// Called on a serial storage queue, never MainActor. Work and cleanup own
    /// only an isolated library. A stuck work item cannot occupy this queue forever.
    func run<T>(source: FileRefreshDiagnostics.Source, reason: Reason, period: SchoolDataPeriod,
                cancelled: @escaping () throws -> Void, registerCancellation: @escaping (Ticket) -> Void = { _ in }, work: @escaping (Ticket) throws -> T,
                cleanup releaseWorkspace: @escaping () -> Void, retryQueue: DispatchQueue? = nil,
                attempt: Int = 0, requestID: UUID? = nil, budgetStartedAt: TimeInterval? = nil, expectedIntent: UInt64? = nil, replacing: Ticket? = nil,
                commit: @escaping (T, Ticket) throws -> Void) throws {
        let cleanup = PendingCleanup(releaseWorkspace).run
        guard period == SchoolDataPeriod.current() else {
            DispatchQueue.global(qos: .utility).async(execute: cleanup); throw Failure.stale
        }
        let budgetStartedAt = budgetStartedAt ?? now()
        var remainingLimits = limits
        remainingLimits.overall = max(0, limits.overall - (now() - budgetStartedAt))
        let ticket = Ticket(source: source, reason: reason, period: period, limits: remainingLimits, attempt: attempt, requestID: requestID, now: now)
        lock.lock()
        let expectedIntent = expectedIntent ?? intents[source, default: 0]
        guard expectedIntent == intents[source, default: 0] else {
            if let replacing, active[source]?.id == replacing.id { active.removeValue(forKey: source) }
            lock.unlock(); DispatchQueue.global(qos: .utility).async(execute: cleanup); throw Failure.stale
        }
        if let replacing {
            guard active[source]?.id == replacing.id else { lock.unlock(); DispatchQueue.global(qos: .utility).async(execute: cleanup); throw Failure.stale }
            guard replacing.permitsRetry else {
                active.removeValue(forKey: source)
                if states[source]?.id == replacing.id { states[source]?.stage = .cancelled; states[source]?.waitingForWorker = false }
                lock.unlock(); DispatchQueue.global(qos: .utility).async(execute: cleanup); throw Failure.cancelled
            }
        } else if active[source] != nil { lock.unlock(); DispatchQueue.global(qos: .utility).async(execute: cleanup); throw Failure.recovering }
        if let pending = backoffs.removeValue(forKey: source) { pending.timer.cancel() }
        active[source] = ticket
        let old = states[source]
        states[source] = Status(id: ticket.id, requestID: ticket.requestID, reason: reason, stage: .access, waitingForWorker: false, attempt: attempt,
                                startedAt: Date(), checkedAt: old?.checkedAt, acquiredAt: old?.acquiredAt, parsedAt: old?.parsedAt)
        lock.unlock()
        let signal = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        var result: Result<T, Error>?
        var launched = false
        do {
            registerCancellation(ticket)
            try cancelled(); try ticket.check()
            launched = true
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try ticket.check(); return try work(ticket) }
                box.put(result); signal.signal()
            }
            while result == nil {
                do { try cancelled() } catch { ticket.cancel(); throw error }
                try ticket.check()
                update(source, ticket: ticket, stage: ticket.stage)
                if signal.wait(timeout: .now() + 0.05) == .success { result = box.take() }
            }
            let value = try result!.get()
            try ticket.check()
            try cancelled()
            update(source, ticket: ticket, stage: .saving)
            try commit(value, ticket)
            finish(source, ticket: ticket, stage: ticket.completionStage, waiting: false)
            DispatchQueue.global(qos: .utility).async(execute: cleanup)
        } catch {
            let terminal: Stage = (error as? Failure) == .timedOut ? .timedOut :
                (FileOperationOutcome.isCancellation(error) || (error as? Failure) == .cancelled || (error as? Failure) == .stale ? .cancelled : .failed)
            let waiting = launched && box.take() == nil
            let transient = Self.isTransient(error, stage: ticket.stage)
            let mayRetry = transient && reason != .background && reason != .review && attempt < limits.retries && retryQueue != nil
            finish(source, ticket: ticket, stage: terminal, waiting: waiting || mayRetry)
            // Reserve the lane throughout retry waiting. Both cleanup and commit
            // stay owned; the old provider must exit before a fresh attempt starts.
            let afterExit: @Sendable () -> Void = { [self] in
                if mayRetry, let retryQueue,
                   scheduleBackoffExpiry(source, ticket: ticket, started: budgetStartedAt, cleanup: cleanup) {
                    retryQueue.asyncAfter(deadline: .now() + limits.retryDelay) { [self] in
                        guard ticket.permitsRetry else {
                            DispatchQueue.global(qos: .utility).async(execute: cleanup)
                            finish(source, ticket: ticket, stage: .cancelled, waiting: false, recordCompletion: false); return
                        }
                        do {
                            try run(source: source, reason: reason, period: period, cancelled: cancelled,
                                    registerCancellation: registerCancellation, work: work, cleanup: cleanup, retryQueue: retryQueue,
                                    attempt: attempt + 1, requestID: ticket.requestID, budgetStartedAt: budgetStartedAt, expectedIntent: expectedIntent, replacing: ticket, commit: commit)
                        } catch { /* Each attempt publishes its typed terminal state. */ }
                    }
                } else {
                    let terminal: Stage = mayRetry && ticket.permitsRetry ? .timedOut :
                        (ticket.permitsRetry ? terminal : .cancelled)
                    finish(source, ticket: ticket, stage: terminal, waiting: false, recordCompletion: false)
                    DispatchQueue.global(qos: .utility).async(execute: cleanup)
                }
                NotificationCenter.default.post(name: .filePipelineChanged, object: nil)
            }
            if waiting {
                DispatchQueue.global(qos: .utility).async { signal.wait(); afterExit() }
            } else { afterExit() }
            throw error
        }
    }
    private func scheduleBackoffExpiry(_ source: FileRefreshDiagnostics.Source, ticket: Ticket,
                                       started: TimeInterval, cleanup: @escaping () -> Void) -> Bool {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + max(0, limits.overall - (now() - started)), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.expireBackoffsLocked(); self.lock.unlock()
        }
        lock.lock()
        if active[source]?.id == ticket.id, ticket.permitsRetry, now() - started + limits.retryDelay < limits.overall {
            if states[source]?.id == ticket.id { states[source]?.stage = .queued; states[source]?.waitingForWorker = false }
            backoffs[source] = (ticket.id, started, timer, cleanup)
            lock.unlock(); timer.resume(); return true
        } else { lock.unlock(); timer.setEventHandler {}; timer.resume(); timer.cancel(); return false }
    }
    private func expireBackoffsLocked() {
        let expired = backoffs.filter { now() - $0.value.started >= limits.overall }
        for (source, pending) in expired {
            pending.timer.cancel(); backoffs.removeValue(forKey: source)
            if active[source]?.id == pending.id {
                active[source]?.cancel(); active.removeValue(forKey: source)
                if states[source]?.id == pending.id {
                    states[source]?.stage = .timedOut; states[source]?.waitingForWorker = false
                    states[source]?.finishedAt = Date()
                }
            }
            DispatchQueue.global(qos: .utility).async(execute: pending.cleanup)
        }
    }
    static func isTransient(_ error: Error, stage: Stage) -> Bool {
        if (error as? Failure) == .timedOut { return [.access, .acquiring].contains(stage) }
        if case MaterialError.providerReadFailed = error { return true }
        return (error as? URLError).map { [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost].contains($0.code) } == true
    }
    private func update(_ source: FileRefreshDiagnostics.Source, ticket: Ticket, stage: Stage) {
        lock.lock(); if states[source]?.id == ticket.id { states[source]?.stage = stage }; lock.unlock()
    }
    private func finish(_ source: FileRefreshDiagnostics.Source, ticket: Ticket, stage: Stage, waiting: Bool,
                        recordCompletion: Bool = true) {
        let dates = ticket.successDates
        lock.lock()
        if states[source]?.id == ticket.id && !(stage == .cancelled && states[source]?.stage == .timedOut && active[source]?.id != ticket.id) {
            if let date = dates.checked { states[source]?.checkedAt = date }
            states[source]?.acquiredThisAttempt = dates.acquired != nil
            if let date = dates.acquired { states[source]?.acquiredAt = date }
            if let date = dates.parsed { states[source]?.parsedAt = date }
            states[source]?.stage = stage; states[source]?.waitingForWorker = waiting; states[source]?.finishedAt = Date()
        }
        if !waiting, active[source]?.id == ticket.id { active.removeValue(forKey: source) }
        lock.unlock()
        if recordCompletion {
            FileRefreshDiagnostics.shared.record(.pipelineFinished, source: source, operationID: ticket.requestID, reason: ticket.reason, stage: stage, attempt: ticket.attempt)
        }
        NotificationCenter.default.post(name: .filePipelineChanged, object: nil)
    }
}
extension Notification.Name { static let filePipelineChanged = Notification.Name("filePipelineChanged") }
