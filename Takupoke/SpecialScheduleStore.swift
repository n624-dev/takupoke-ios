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

/// The special PDFs have their own source and parser contract. This sidecar
/// SQLite store leaves the existing material database and parser untouched.
final class SpecialScheduleStore {
    enum StoreError: Error { case invalidState }

    private let root: URL
    private let files: URL
    private let staging: URL
    private let queue: DatabaseQueue
    private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]

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

    func save(staged: URL, analysis: SpecialScheduleAnalysis, originalName: String,
              byteCount: Int, digest: String) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              analysis.sourceDigest == digest,
              Self.valid(analysis), byteCount > 0,
              byteCount <= MaterialLibrary.maximumBytes else {
            throw StoreError.invalidState
        }
        let storedName = UUID().uuidString + ".pdf"
        let destination = files.appendingPathComponent(storedName)
        try FileManager.default.moveItem(at: staged, to: destination)
        let record = SpecialScheduleRecord(kind: analysis.kind, originalName: originalName,
                                           storedName: storedName, byteCount: byteCount,
                                           digest: digest, acquiredAt: Date(), analysis: analysis)
        do {
            let payload = try JSONEncoder().encode(record)
            try queue.write { db in
                try db.execute(sql: "INSERT INTO specialSchedule (kind, payload) VALUES (?, ?) ON CONFLICT(kind) DO UPDATE SET payload = excluded.payload",
                               arguments: [analysis.kind.rawValue, payload])
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        records[analysis.kind] = record
        try? removeUnreferencedFiles()
    }

    private static func valid(_ analysis: SpecialScheduleAnalysis) -> Bool {
        let count = analysis.kind == .exam ? 6 : 8
        return analysis.version == SpecialScheduleAnalysis.parserVersion &&
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
        let keep = Set(records.values.map(\.storedName))
        for file in try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil) where !keep.contains(file.lastPathComponent) {
            try manager.removeItem(at: file)
        }
        for file in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: file)
        }
    }
}
