#if canImport(Darwin)
import Foundation

protocol SelectedFileObserving: AnyObject {
    func start(requestInitialRefresh: Bool)
    func stop()
    func refreshCompleted()
}

@MainActor
final class SelectedFileMonitor {
    private var foreground = false
    private var suspended = false
    private var sources: [String: SelectedFileSource] = [:]
    enum Registration { case registering, registered, failed, timedOut, stopped }
    typealias Factory = (SelectedFileSource, @escaping () -> Void, @escaping (Bool) -> Void, @escaping () -> Void) -> SelectedFileObserving
    typealias RegistrationWait = @MainActor (String) async throws -> Void
    private var observations: [String: SelectedFileObserving] = [:]
    private(set) var registrations: [String: Registration] = [:]
    private let factory: Factory
    private var notifications: [String: DispatchWorkItem] = [:]
    private var generations: [String: UUID] = [:]
    private let changed: (String) -> Void
    private let registrationChanged: () -> Void
    private let waitForRegistration: RegistrationWait
    private var registering: [String: UUID] = [:]
    private var deadlines: [String: Task<Void, Never>] = [:]
    private var restartAfterRegistration: [String: Bool] = [:]
    private var checkAfterTimeout = Set<String>()

    var blockedSources: Set<String> { Set(registering.keys) }
    func isRegistering(_ source: String) -> Bool { registering[source] != nil }

    func timeoutStatus(_ source: String) -> StatusPresentation? {
        guard registrations[source] == .timedOut else { return nil }
        if isRegistering(source) {
            return .init(title: "監視登録が期限切れ・終了待ち", tone: .attention,
                         detail: "先の登録が終わると、このファイルを再確認できます。")
        }
        return .init(title: "監視登録が期限切れ", tone: .attention,
                     detail: "前回の結果を表示しています。更新を確認できます。")
    }

    init(registrationChanged: @escaping () -> Void = {},
         waitForRegistration: @escaping RegistrationWait = { _ in try await Task.sleep(for: .seconds(30)) },
         changed: @escaping (String) -> Void, factory: Factory? = nil) {
        self.changed = changed
        self.registrationChanged = registrationChanged
        self.waitForRegistration = waitForRegistration
        self.factory = factory ?? { SelectedFileObservation(source: $0, registered: $2, registrationEnded: $3, changed: $1) }
    }

    func setForeground(_ value: Bool) {
        guard foreground != value else { return }
        FileRefreshDiagnostics.shared.record(value ? .foreground : .background)
        foreground = value
        if value {
            suspended = false
            for source in sources.values { start(source) }
        }
        else {
            restartAfterRegistration.removeAll()
            checkAfterTimeout.removeAll()
            for id in Array(generations.keys) { stop(id) }
        }
    }

    func suspend() {
        suspended = true
        restartAfterRegistration.removeAll()
        checkAfterTimeout.removeAll()
        for id in Array(generations.keys) { stop(id) }
    }

    func resume() {
        guard suspended else { return }
        suspended = false
        if foreground { for source in sources.values { start(source) } }
    }

    func discardPendingRefreshes() {
        notifications.values.forEach { $0.cancel() }
        notifications.removeAll()
    }

    func update(_ selected: [SelectedFileSource], retryFailedFor acquired: Set<String> = []) {
        observations.values.forEach { $0.refreshCompleted() }
        let next = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
        for id in sources.keys where sources[id] != next[id] {
            checkAfterTimeout.remove(id)
            restartAfterRegistration.removeValue(forKey: id)
            stop(id)
        }
        let previous = sources
        sources = next
        guard foreground, !suspended else { return }
        for source in selected {
            if previous[source.id] != source { start(source) }
            else if acquired.contains(source.id),
                    registrations[source.id] == .failed || registrations[source.id] == .timedOut {
                stop(source.id); start(source, initialRefresh: false)
            }
        }
    }

    private func start(_ source: SelectedFileSource, initialRefresh: Bool = true) {
        if isRegistering(source.id) {
            restartAfterRegistration[source.id] = initialRefresh || restartAfterRegistration[source.id] == true
            return
        }
        FileRefreshDiagnostics.shared.record(.observationStart, source: .init(rawValue: source.id))
        let generation = UUID()
        generations[source.id] = generation
        registrations[source.id] = .registering
        // Legacy special PDFs without bookmarks still get their parser-version
        // check on foreground entry, but cannot observe the provider original.
        guard source.bookmark != nil else {
            registrations[source.id] = .stopped
            if initialRefresh { schedule(source.id, generation: generation) }
            return
        }
        let observation = factory(source, { [weak self] in
            DispatchQueue.main.async { self?.schedule(source.id, generation: generation) }
        }, { [weak self] success in
            DispatchQueue.main.async {
                guard let self, self.foreground, !self.suspended, self.generations[source.id] == generation else { return }
                self.registrations[source.id] = success ? .registered : .failed
            }
        }, { [weak self] in
            DispatchQueue.main.async { self?.registrationFinished(source.id, generation: generation) }
        })
        observations[source.id] = observation
        registering[source.id] = generation
        deadlines[source.id] = Task { [weak self, waitForRegistration] in
            do { try await waitForRegistration(source.id) } catch { return }
            guard !Task.isCancelled, let self, self.registering[source.id] == generation,
                  self.generations[source.id] == generation, self.registrations[source.id] == .registering else { return }
            if initialRefresh { self.checkAfterTimeout.insert(source.id) }
            self.stop(source.id, as: .timedOut)
            FileRefreshDiagnostics.shared.record(.registrationTimedOut, source: .init(rawValue: source.id), operationID: generation)
            self.registrationChanged()
        }
        observation.start(requestInitialRefresh: initialRefresh)
    }

    private func registrationFinished(_ id: String, generation: UUID) {
        guard registering[id] == generation else { return }
        registering[id] = nil
        deadlines.removeValue(forKey: id)?.cancel()
        let restart = restartAfterRegistration.removeValue(forKey: id)
        let needsCheck = checkAfterTimeout.remove(id) != nil
        if let restart, foreground, !suspended, let source = sources[id] {
            start(source, initialRefresh: restart)
        }
        registrationChanged()
        if needsCheck, restart == nil, foreground, !suspended, sources[id] != nil { changed(id) }
    }

    private func schedule(_ id: String, generation: UUID) {
        guard foreground, !suspended, generations[id] == generation else { return }
        FileRefreshDiagnostics.shared.record(.scheduled, source: .init(rawValue: id))
        notifications[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.foreground, self.generations[id] == generation else { return }
            self.notifications[id] = nil
            FileRefreshDiagnostics.shared.record(.delivered, source: .init(rawValue: id))
            self.changed(id)
        }
        notifications[id] = work
        // Provider metadata and content notifications often arrive together.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func stop(_ id: String, as state: Registration = .stopped) {
        FileRefreshDiagnostics.shared.record(.observationStop, source: .init(rawValue: id))
        generations[id] = nil
        registrations[id] = state
        deadlines.removeValue(forKey: id)?.cancel()
        notifications.removeValue(forKey: id)?.cancel()
        observations.removeValue(forKey: id)?.stop()
    }

    deinit {
        notifications.values.forEach { $0.cancel() }
        deadlines.values.forEach { $0.cancel() }
        observations.values.forEach { $0.stop() }
    }
}
#endif
