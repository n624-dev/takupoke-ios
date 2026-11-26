import Foundation

/// Only fixed event codes and elapsed times; no URLs, bookmarks, names or hashes.
final class FileRefreshDiagnostics: @unchecked Sendable {
    enum Source: String, Codable, CaseIterable { case timetable, changes, exam, examReturn }
    enum Step: String, Codable {
        case foreground, background, observationStart, observationStop
        case registrationComplete, registrationFailure, initialRefresh
        case providerChange, providerMove, providerDelete
        case metadataUnavailable, metadataChanged, metadataUnchanged
        case coordinatorMatched, coordinatorUnmatched, scheduled, delivered
        case refreshStarted, hashSame, hashChanged, refreshFailed, cancelled
        case readVersionRecorded, readVersionUnavailable
        case pipelineStage, pipelineFinished
    }
    struct Entry: Codable {
        let sequence: Int
        let elapsedMilliseconds: Int
        let step: Step
        let source: Source?
        var operationID: UUID? = nil
        var reason: FilePipeline.Reason? = nil
        var stage: FilePipeline.Stage? = nil
        var attempt: Int? = nil
    }
    struct Snapshot: Codable {
        let schemaVersion: Int
        let totalEntries: Int
        let omittedEntries: Int
        let entries: [Entry]
    }
    static let shared = FileRefreshDiagnostics()
    private let lock = NSLock()
    private let now: @Sendable () -> TimeInterval
    private let started: TimeInterval
    private let limit: Int
    private var total = 0
    private var entries: [Entry] = []

    init(limit: Int = 512, now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.limit = max(2, min(512, limit))
        self.now = now
        started = now()
    }

    func record(_ step: Step, source: Source? = nil, operationID: UUID? = nil, reason: FilePipeline.Reason? = nil, stage: FilePipeline.Stage? = nil, attempt: Int? = nil) {
        lock.lock()
        defer { lock.unlock() }
        total += 1
        let entry = Entry(sequence: total,
            elapsedMilliseconds: Int(max(0, now() - started) * 1000),
            step: step, source: source, operationID: operationID, reason: reason, stage: stage, attempt: attempt)
        // Keep the initial registration and the latest feedback cycle.
        if entries.count == limit { entries.remove(at: min(32, limit / 2)) }
        entries.append(entry)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        total = 0; entries.removeAll()
    }

    var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(schemaVersion: 1, totalEntries: total,
                        omittedEntries: total - entries.count, entries: entries)
    }

    var report: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot),
              let text = String(data: data, encoding: .utf8) else { return "TAKUPOKE-REFRESH-TRACE-1\n{}" }
        return "TAKUPOKE-REFRESH-TRACE-1\n" + text
    }
}
