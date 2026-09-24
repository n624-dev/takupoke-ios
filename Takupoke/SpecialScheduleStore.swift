import Foundation
import GRDB

struct SpecialScheduleRecord: Codable {
    let kind: SpecialScheduleKind
    let originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    let analysis: SpecialScheduleAnalysis
}

struct SpecialScheduleSource: Codable {
    let kind: SpecialScheduleKind
    let originalName: String
    let storedName: String
    let byteCount: Int
    let digest: String
    let acquiredAt: Date
    var lastCheckedAt: Date? = nil
    var failure: PDFParseError?
    var grant: SourceGrant?
}

/// The special PDFs have their own source and parser contract. This sidecar
/// SQLite store leaves the existing material database and parser untouched.
final class SpecialScheduleStore {
    enum StoreError: Error { case invalidState }

    private let root: URL
    private let files: URL
    private let staging: URL
    private let queue: DatabaseQueue
    private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    private(set) var sources: [SpecialScheduleKind: SpecialScheduleSource] = [:]

    init(root: URL) throws {
        self.root = root
        files = root.appendingPathComponent("files", isDirectory: true)
        staging = root.appendingPathComponent("staging", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: files, withIntermediateDirectories: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var protectedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
        #endif
        #if os(iOS)
        for directory in [root, files, staging] {
            try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        }
        #endif
        var config = Configuration()
        config.publicStatementArguments = false
        queue = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path, configuration: config)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS specialSchedule (
                    kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                    payload BLOB NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS specialSource (
                    kind TEXT PRIMARY KEY NOT NULL CHECK (kind IN ('exam', 'examReturn')),
                    payload BLOB NOT NULL
                )
                """)
        }
        records = try queue.read { db in
            var result: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT kind, payload FROM specialSchedule") {
                let key: String = row["kind"]
                let data: Data = row["payload"]
                guard let kind = SpecialScheduleKind(rawValue: key),
                      let record = try? JSONDecoder().decode(SpecialScheduleRecord.self, from: data),
                      record.kind == kind, record.analysis.kind == kind,
                      record.digest == record.analysis.sourceDigest,
                      Self.valid(record.analysis),
                      record.storedName.hasSuffix(".pdf"),
                      UUID(uuidString: String(record.storedName.dropLast(4))) != nil,
                      manager.fileExists(atPath: files.appendingPathComponent(record.storedName).path) else {
                    throw StoreError.invalidState
                }
                result[kind] = record
            }
            return result
        }
        sources = try queue.read { db in
            var result: [SpecialScheduleKind: SpecialScheduleSource] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT kind, payload FROM specialSource") {
                let key: String = row["kind"]
                let data: Data = row["payload"]
                guard let kind = SpecialScheduleKind(rawValue: key),
                      let source = try? JSONDecoder().decode(SpecialScheduleSource.self, from: data),
                      source.kind == kind, source.byteCount > 0,
                      source.byteCount <= MaterialLibrary.maximumBytes,
                      source.storedName.hasSuffix(".pdf"),
                      UUID(uuidString: String(source.storedName.dropLast(4))) != nil,
                      manager.fileExists(atPath: files.appendingPathComponent(source.storedName).path) else {
                    throw StoreError.invalidState
                }
                result[kind] = source
            }
            return result
        }
        // Older installs stored the selected source together with its analysis.
        for (kind, record) in records where sources[kind] == nil {
            sources[kind] = SpecialScheduleSource(kind: kind, originalName: record.originalName,
                storedName: record.storedName, byteCount: record.byteCount, digest: record.digest,
                acquiredAt: record.acquiredAt, failure: nil, grant: nil)
        }
        try removeUnreferencedFiles()
    }

    func newStagingURL() -> URL { staging.appendingPathComponent(UUID().uuidString) }

    func discardStaging(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func savedURL(for kind: SpecialScheduleKind) -> URL? {
        records[kind].map { files.appendingPathComponent($0.storedName) }
    }

    func selectedURL(for kind: SpecialScheduleKind) -> URL? {
        sources[kind].map { files.appendingPathComponent($0.storedName) }
    }

    func saveSelection(staged: URL, kind: SpecialScheduleKind, originalName: String,
                       byteCount: Int, digest: String, grant: SourceGrant? = nil) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              byteCount > 0, byteCount <= MaterialLibrary.maximumBytes,
              !digest.isEmpty else { throw StoreError.invalidState }
        let storedName = UUID().uuidString + ".pdf"
        let destination = files.appendingPathComponent(storedName)
        try FileManager.default.moveItem(at: staged, to: destination)
        let now = Date()
        let source = SpecialScheduleSource(kind: kind, originalName: originalName,
            storedName: storedName, byteCount: byteCount, digest: digest,
            acquiredAt: now, lastCheckedAt: now, failure: nil, grant: grant)
        do {
            let payload = try JSONEncoder().encode(source)
            try queue.write { db in
                try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                               arguments: [kind.rawValue, payload])
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        sources[kind] = source
        try? removeUnreferencedFiles()
    }

    func recordSuccessfulCheck(_ kind: SpecialScheduleKind, digest: String, checkedAt: Date = Date()) throws {
        guard var source = sources[kind], source.digest == digest else { throw StoreError.invalidState }
        source.lastCheckedAt = checkedAt
        let payload = try JSONEncoder().encode(source)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [kind.rawValue, payload])
        }
        sources[kind] = source
    }

    func saveAnalysis(_ analysis: SpecialScheduleAnalysis) throws {
        guard let source = sources[analysis.kind], analysis.sourceDigest == source.digest,
              analysis.sourceName == source.originalName,
              analysis.version == SpecialScheduleAnalysis.parserVersion, Self.valid(analysis) else {
            throw StoreError.invalidState
        }
        let record = SpecialScheduleRecord(kind: analysis.kind, originalName: source.originalName,
            storedName: source.storedName, byteCount: source.byteCount, digest: source.digest,
            acquiredAt: source.acquiredAt, analysis: analysis)
        var cleared = source
        cleared.failure = nil
        let recordPayload = try JSONEncoder().encode(record)
        let sourcePayload = try JSONEncoder().encode(cleared)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO specialSchedule (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [analysis.kind.rawValue, recordPayload])
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [analysis.kind.rawValue, sourcePayload])
        }
        records[analysis.kind] = record
        sources[analysis.kind] = cleared
        try? removeUnreferencedFiles()
    }

    func recordFailure(_ failure: PDFParseError, kind: SpecialScheduleKind) throws {
        guard var source = sources[kind] else { throw StoreError.invalidState }
        source.failure = failure
        let payload = try JSONEncoder().encode(source)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO specialSource (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                           arguments: [kind.rawValue, payload])
        }
        sources[kind] = source
    }

    func save(staged: URL, analysis: SpecialScheduleAnalysis, originalName: String,
              byteCount: Int, digest: String) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              analysis.sourceDigest == digest,
              analysis.sourceName == originalName,
              analysis.version == SpecialScheduleAnalysis.parserVersion, Self.valid(analysis), byteCount > 0,
              byteCount <= MaterialLibrary.maximumBytes else {
            throw StoreError.invalidState
        }
        try saveSelection(staged: staged, kind: analysis.kind, originalName: originalName,
                          byteCount: byteCount, digest: digest)
        try saveAnalysis(analysis)
    }

    private static func valid(_ analysis: SpecialScheduleAnalysis) -> Bool {
        let count = analysis.kind == .exam ? 6 : 8
        return (4...SpecialScheduleAnalysis.parserVersion).contains(analysis.version) &&
            analysis.coveredDates.count == 5 && Set(analysis.coveredDates).count == 5 &&
            analysis.coveredClasses.count == 17 && Set(analysis.coveredClasses).count == 17 &&
            analysis.periodTimes.count == count && !analysis.lessons.isEmpty &&
            analysis.lessons.allSatisfy { (1...count).contains($0.period) &&
                (1...$0.period).contains($0.spanStart) &&
                ($0.period...count).contains($0.spanEnd) &&
                analysis.applies(date: $0.date, className: $0.className) }
    }

    private func removeUnreferencedFiles() throws {
        let manager = FileManager.default
        let keep = Set(records.values.map(\.storedName) + sources.values.map(\.storedName))
        for file in try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil) where !keep.contains(file.lastPathComponent) {
            try manager.removeItem(at: file)
        }
        for file in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: file)
        }
    }
}
