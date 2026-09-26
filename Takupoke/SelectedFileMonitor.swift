#if canImport(Darwin)
import Foundation

@MainActor
final class SelectedFileMonitor {
    private var foreground = false
    private var suspended = false
    private var sources: [String: SelectedFileSource] = [:]
    private var observations: [String: SelectedFileObservation] = [:]
    private var notifications: [String: DispatchWorkItem] = [:]
    private var generations: [String: UUID] = [:]
    private let changed: (String) -> Void

    init(changed: @escaping (String) -> Void) { self.changed = changed }

    func setForeground(_ value: Bool) {
        guard foreground != value else { return }
        FileRefreshDiagnostics.shared.record(value ? .foreground : .background)
        foreground = value
        suspended = false
        if value { for source in sources.values { start(source) } }
        else {
            for id in Array(generations.keys) { stop(id) }
        }
    }

    func suspend() {
        suspended = true
        for id in Array(generations.keys) { stop(id) }
    }

    func update(_ selected: [SelectedFileSource]) {
        let next = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
        for id in sources.keys where sources[id] != next[id] { stop(id) }
        let previous = sources
        sources = next
        guard foreground, !suspended else { return }
        for source in selected where previous[source.id] != source { start(source) }
    }

    private func start(_ source: SelectedFileSource) {
        FileRefreshDiagnostics.shared.record(.observationStart, source: .init(rawValue: source.id))
        let generation = UUID()
        generations[source.id] = generation
        // Legacy special PDFs without bookmarks still get their parser-version
        // check on foreground entry, but cannot observe the provider original.
        guard source.bookmark != nil else {
            schedule(source.id, generation: generation)
            return
        }
        let observation = SelectedFileObservation(source: source) { [weak self] in
            DispatchQueue.main.async { self?.schedule(source.id, generation: generation) }
        }
        observations[source.id] = observation
        observation.start()
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

    private func stop(_ id: String) {
        FileRefreshDiagnostics.shared.record(.observationStop, source: .init(rawValue: id))
        generations[id] = nil
        notifications.removeValue(forKey: id)?.cancel()
        observations.removeValue(forKey: id)?.stop()
    }

    deinit {
        notifications.values.forEach { $0.cancel() }
        observations.values.forEach { $0.stop() }
    }
}
#endif
