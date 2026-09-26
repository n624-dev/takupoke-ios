import Foundation

/// Only fixed event codes and elapsed times; no URLs, bookmarks, names or hashes.
final class FileRefreshDiagnostics: @unchecked Sendable {
    enum Source: String, Codable { case timetable, changes, exam, examReturn }
    enum Step: String, Codable {
        case foreground, background, observationStart, observationStop
        case registrationComplete, registrationFailure, initialRefresh
        case providerChange, providerMove, providerDelete
        case metadataUnavailable, metadataChanged, metadataUnchanged
        case coordinatorMatched, coordinatorUnmatched, scheduled, delivered
        case refreshStarted, hashSame, hashChanged, refreshFailed, cancelled
    }
    struct Entry: Codable {
        let sequence: Int
        let elapsedMilliseconds: Int
        let step: Step
        let source: Source?
    }
    struct Snapshot: Codable {
        let schemaVersion: Int
        let totalEntries: Int
        let omittedEntries: Int
        let entries: [Entry]
    }
    static let shared = FileRefreshDiagnostics()
    private let lock = NSLock()
    private let started = Date()
    private let limit: Int
    private var total = 0
    private var entries: [Entry] = []

    init(limit: Int = 512) { self.limit = max(2, min(512, limit)) }

    func record(_ step: Step, source: Source? = nil) {
        lock.lock()
        defer { lock.unlock() }
        total += 1
        let entry = Entry(sequence: total,
            elapsedMilliseconds: Int(max(0, Date().timeIntervalSince(started)) * 1000),
            step: step, source: source)
        // Keep the initial registration and the latest feedback cycle.
        if entries.count == limit { entries.remove(at: min(32, limit / 2)) }
        entries.append(entry)
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
