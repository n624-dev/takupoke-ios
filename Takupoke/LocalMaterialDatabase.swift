import Foundation
import GRDB
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Local storage for completed acquisitions and analyses. No timetable adoption or legacy fallback.
final class LocalMaterialDatabase: MaterialLibraryPersistence {
    enum StoreError: Error { case invalidDatabase, unsupportedSchema, incompleteMigration, staleState }
    static let schemaVersion = 2
    private static let applicationID = 0x544B504B // TKPK
    let queue: DatabaseQueue
    private var generation: Int64?
    private var libraryLock: LibraryLock?
    // Tests inject a failure inside the transaction, before the current state commits.
    var beforeCommit: () throws -> Void = {}

    /// Creation is explicit: opening a missing database must never silently initialize it.
    init(url: URL, create: Bool = false) throws {
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard create != exists else { throw StoreError.invalidDatabase }
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.publicStatementArguments = false
        config.prepareDatabase { db in
            if !create {
                guard try Int.fetchOne(db, sql: "PRAGMA application_id") == Self.applicationID else {
                    throw StoreError.invalidDatabase
                }
                guard try Int.fetchOne(db, sql: "PRAGMA user_version") == Self.schemaVersion else {
                    throw StoreError.unsupportedSchema
                }
                guard try String.fetchOne(db, sql: "PRAGMA journal_mode") == "delete" else {
                    throw StoreError.invalidDatabase
                }
            } else {
                try db.execute(sql: "PRAGMA journal_mode = DELETE")
            }
            try db.execute(sql: "PRAGMA synchronous = FULL")
            guard try Int.fetchOne(db, sql: "PRAGMA foreign_keys") == 1,
                  try Int.fetchOne(db, sql: "PRAGMA synchronous") == 2 else {
                throw StoreError.invalidDatabase
            }
        }
        queue = try DatabaseQueue(path: url.path, configuration: config)
        if create {
            try queue.write { db in
                try db.execute(sql: Self.schema)
                try db.execute(sql: "PRAGMA application_id = \(Self.applicationID)")
                try db.execute(sql: "PRAGMA user_version = \(Self.schemaVersion)")
            }
        }
    }

    func close() throws {
        try queue.close()
        libraryLock = nil
    }

}

extension LocalMaterialDatabase {
    /// Called by the single acquisition worker, before any jobs or PDF views exist.
    /// Publish a complete empty store with a directory rename. Never initialize an
    /// existing store, even if its database is missing, locked, or unreadable.
    static func openLibrary(root: URL) throws -> MaterialLibrary {
        let manager = FileManager.default
        let lockURL = root.deletingLastPathComponent().appendingPathComponent(root.lastPathComponent + ".lock")
        let lease = try LibraryLock(url: lockURL)
        try protect(lockURL)
        let pending = root.deletingLastPathComponent()
            .appendingPathComponent(root.lastPathComponent + ".initializing", isDirectory: true)
        if manager.fileExists(atPath: pending.path) {
            try manager.removeItem(at: pending) // Only this initializer owns this sibling.
        }
        if !manager.fileExists(atPath: root.path) {
            try manager.createDirectory(at: pending, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: pending) }
            try protect(pending)
            for name in ["files", "staging"] {
                let directory = pending.appendingPathComponent(name, isDirectory: true)
                try manager.createDirectory(at: directory, withIntermediateDirectories: false)
                try protect(directory)
            }
            let url = pending.appendingPathComponent("library.sqlite")
            let database = try LocalMaterialDatabase(url: url, create: true)
            do {
                try database.initializeCurrentLibrary()
                try database.close()
            } catch {
                try? database.close()
                throw error
            }
            try protect(url)
            let verified = try LocalMaterialDatabase(url: url)
            do {
                _ = try verified.load()
                try verified.close()
            } catch {
                try? verified.close()
                throw error
            }
            try manager.moveItem(at: pending, to: root)
        }
        do {
            let database = try LocalMaterialDatabase(url: root.appendingPathComponent("library.sqlite"))
            database.libraryLock = lease
            return try MaterialLibrary(root: root, persistence: database)
        } catch {
            // Do not expose SQL or payloads in a user-visible acquisition error.
            throw MaterialError.invalidState
        }
    }

    private static func protect(_ url: URL) throws {
        #if os(iOS) || os(macOS)
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try target.setResourceValues(values)
        #endif
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }

    func initializeCurrentLibrary() throws {
        try queue.write { db in
            guard try Int.fetchOne(db, sql: "SELECT count(*) FROM library") == 0,
                  try Int.fetchOne(db, sql: "SELECT count(*) FROM original") == 0 else {
                throw StoreError.invalidDatabase
            }
            try db.execute(sql: "INSERT INTO currentLibrary (id, generation) VALUES (1, 0)")
        }
    }

    func load() throws -> MaterialLibraryState {
        let (state, revision) = try queue.read { db in
            guard try String.fetchOne(db, sql: "PRAGMA quick_check") == "ok",
                  try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty else {
                throw StoreError.invalidDatabase
            }
            return try Self.currentSnapshot(db)
        }
        generation = revision
        return state
    }

    private static func currentSnapshot(_ db: Database) throws -> (MaterialLibraryState, Int64) {
        guard let library = try Row.fetchOne(db, sql: "SELECT * FROM currentLibrary WHERE id = 1"),
              try Int.fetchOne(db, sql: "SELECT count(*) FROM library") == 0 else {
            throw StoreError.invalidDatabase
        }
        var state = MaterialLibraryState()
        if let folder: Data = library["folder"] { state.folder = try decode(SourceGrant.self, folder) }
        for row in try Row.fetchAll(db, sql: """
            SELECT c.record AS currentPayload, c.kind AS currentKind, o.*, s.settings
            FROM currentRecord c JOIN original o ON o.id = c.originalID
            JOIN source s ON s.id = o.sourceID ORDER BY c.position
            """) {
            let record = try decode(MaterialRecord.self, row["currentPayload"])
            let original = try decode(MaterialRecord.self, row["record"])
            // A 304 response may update HTTP validators and lastCheckedAt only.
            var comparable = record
            comparable.source = original.source
            comparable.lastCheckedAt = original.lastCheckedAt
            guard try encode(comparable) == encode(original),
                  row["currentKind"] as String == record.kind.rawValue,
                  row["kind"] as String == record.kind.rawValue,
                  row["storedName"] as String == record.storedName,
                  row["digest"] as String == record.digest,
                  row["originalName"] as String == record.originalName,
                  row["settings"] as Data == (try encode(original.source)) else {
                throw StoreError.invalidDatabase
            }
            state.records.append(record)
        }
        guard state.records.count == (try Int.fetchOne(db, sql: "SELECT count(*) FROM currentRecord")) else {
            throw StoreError.invalidDatabase
        }
        // Only the most recent attempt of each operation is retained in this phase.
        for row in try Row.fetchAll(db, sql: "SELECT * FROM attempt ORDER BY id") {
            let kind: String = row["kind"]
            let data: Data = row["payload"]
            let date: Date
            let succeeded: Bool
            if row["operation"] as String == "acquire" {
                let attempt = try decode(AcquisitionAttempt.self, data)
                state.attempts[kind] = attempt
                date = attempt.date; succeeded = attempt.failure == nil
            } else if kind == "changes" {
                let attempt = try decode(ChangeParseAttempt.self, data)
                state.changeParseAttempt = attempt
                date = attempt.date; succeeded = attempt.failure == nil
            } else {
                let attempt = try decode(PDFParseAttempt.self, data)
                if state.pdfParseAttempts == nil { state.pdfParseAttempts = [:] }
                state.pdfParseAttempts?[kind] = attempt
                date = attempt.date; succeeded = attempt.failure == nil
            }
            guard row["finishedAt"] as Double == date.timeIntervalSince1970,
                  row["succeeded"] as Bool == succeeded else { throw StoreError.invalidDatabase }
        }
        let analyses = try Row.fetchAll(db, sql: """
            SELECT a.*, o.digest FROM currentAnalysis c
            JOIN analysis a ON a.id = c.analysisID AND a.kind = c.kind
            JOIN original o ON o.id = a.originalID AND o.kind = a.kind
            """)
        guard analyses.count == (try Int.fetchOne(db, sql: "SELECT count(*) FROM currentAnalysis")) else {
            throw StoreError.invalidDatabase
        }
        try readAnalyses(db, rows: analyses, state: &state)
        return (try MaterialLibrary.decodeLegacyManifest(encode(state)), library["generation"])
    }

    func save(_ state: MaterialLibraryState) throws {
        _ = try MaterialLibrary.decodeLegacyManifest(Self.encode(state))
        guard let expected = generation else { throw StoreError.staleState }
        try queue.write { db in
            let (previous, actual) = try Self.currentSnapshot(db)
            guard actual == expected else { throw StoreError.staleState }
            var currentRecords: [(MaterialRecord, String)] = []
            for record in state.records {
                let originalID: String
                if let old = previous.record(for: record.kind), old.storedName == record.storedName {
                    var comparable = record
                    comparable.source = old.source
                    comparable.lastCheckedAt = old.lastCheckedAt
                    guard try Self.encode(comparable) == Self.encode(old),
                          let id = try String.fetchOne(db, sql: "SELECT originalID FROM currentRecord WHERE kind = ?",
                                                       arguments: [record.kind.rawValue]) else {
                        throw StoreError.invalidDatabase
                    }
                    originalID = id
                } else {
                    originalID = UUID().uuidString
                    let sourceID = UUID().uuidString
                    try db.execute(sql: "INSERT INTO source (id, kind, settings) VALUES (?, ?, ?)",
                        arguments: [sourceID, record.kind.rawValue, try Self.encode(record.source)])
                    try db.execute(sql: """
                        INSERT INTO original (id, sourceID, kind, digest, originalName, storedName, record, legacyPosition)
                        VALUES (?, ?, ?, ?, ?, ?, ?, (SELECT coalesce(max(legacyPosition), -1) + 1 FROM original))
                        """, arguments: [originalID, sourceID, record.kind.rawValue, record.digest,
                            record.originalName, record.storedName, try Self.encode(record)])
                }
                currentRecords.append((record, originalID))
            }
            try db.execute(sql: "DELETE FROM currentRecord")
            for (position, entry) in currentRecords.enumerated() {
                try db.execute(sql: "INSERT INTO currentRecord (kind, originalID, record, position) VALUES (?, ?, ?, ?)",
                    arguments: [entry.0.kind.rawValue, entry.1, try Self.encode(entry.0), position])
            }
            // Ordinary library operations cannot silently delete stored records/results.
            guard Set(previous.records.map(\.kind)).isSubset(of: Set(state.records.map(\.kind))) else {
                throw StoreError.invalidDatabase
            }
            for kind in MaterialKind.allCases {
                let old: Data?
                let next: Data?
                let digest: String?
                if kind == .changes {
                    old = try previous.changeAnalysis.map(Self.encode)
                    next = try state.changeAnalysis.map(Self.encode)
                    digest = state.changeAnalysis?.sourceDigest
                } else {
                    old = try previous.pdfAnalyses?[kind.rawValue].map(Self.encode)
                    next = try state.pdfAnalyses?[kind.rawValue].map(Self.encode)
                    digest = state.pdfAnalyses?[kind.rawValue]?.sourceDigest
                }
                if old == next { continue }
                guard next != nil, digest == state.record(for: kind)?.digest,
                      let original = try String.fetchOne(db, sql: "SELECT originalID FROM currentRecord WHERE kind = ?",
                                                         arguments: [kind.rawValue]) else {
                    throw StoreError.invalidDatabase
                }
                let id: String
                if kind == .changes, let analysis = state.changeAnalysis {
                    id = try Self.writeChanges(db, analysis, original: original)
                } else if let analysis = state.pdfAnalyses?[kind.rawValue] {
                    id = try Self.writePDF(db, analysis, original: original)
                } else { throw StoreError.invalidDatabase }
                try db.execute(sql: "INSERT OR REPLACE INTO currentAnalysis (kind, analysisID) VALUES (?, ?)",
                               arguments: [kind.rawValue, id])
            }
            for (kind, attempt) in state.attempts {
                if try previous.attempts[kind].map(Self.encode) != Self.encode(attempt) {
                    try Self.insertAttempt(db, kind: kind, operation: "acquire", date: attempt.date,
                                           succeeded: attempt.failure == nil, payload: Self.encode(attempt))
                }
            }
            if let attempt = state.changeParseAttempt,
               try previous.changeParseAttempt.map(Self.encode) != Self.encode(attempt) {
                try Self.insertAttempt(db, kind: "changes", operation: "parse", date: attempt.date,
                                       succeeded: attempt.failure == nil, payload: Self.encode(attempt))
            }
            for (kind, attempt) in state.pdfParseAttempts ?? [:] {
                if try previous.pdfParseAttempts?[kind].map(Self.encode) != Self.encode(attempt) {
                    try Self.insertAttempt(db, kind: kind, operation: "parse", date: attempt.date,
                                           succeeded: attempt.failure == nil, payload: Self.encode(attempt))
                }
            }
            try db.execute(sql: "UPDATE currentLibrary SET generation = generation + 1, folder = ? WHERE id = 1",
                           arguments: [try state.folder.map(Self.encode)])
            // Keep current acquisitions and every original used by the last good
            // analyses. No age/count heuristic, no deletion of referenced versions.
            try db.execute(sql: """
                DELETE FROM lesson WHERE analysisID NOT IN (SELECT analysisID FROM currentAnalysis);
                DELETE FROM changeRow WHERE analysisID NOT IN (SELECT analysisID FROM currentAnalysis);
                DELETE FROM analysis WHERE id NOT IN (SELECT analysisID FROM currentAnalysis);
                DELETE FROM original WHERE id NOT IN (SELECT originalID FROM currentRecord)
                    AND id NOT IN (SELECT originalID FROM analysis);
                DELETE FROM source WHERE id NOT IN (SELECT sourceID FROM original WHERE sourceID IS NOT NULL);
                DELETE FROM attempt WHERE id NOT IN (SELECT max(id) FROM attempt GROUP BY kind, operation);
                """)
            let (restored, _) = try Self.currentSnapshot(db)
            guard try Self.encode(restored) == Self.encode(state) else { throw StoreError.invalidDatabase }
            try beforeCommit()
        }
        generation = expected + 1
    }

    func retainedStoredNames() throws -> Set<String> {
        try queue.read { db in
            // Validate names before letting them influence the file collector.
            let records = try Data.fetchAll(db, sql: "SELECT record FROM original WHERE record IS NOT NULL")
                .map { try Self.decode(MaterialRecord.self, $0) }
            for record in records {
                var check = MaterialLibraryState()
                check.records = [record]
                _ = try MaterialLibrary.decodeLegacyManifest(Self.encode(check))
            }
            return Set(records.map(\.storedName))
        }
    }
}

/// Keep acquisition, startup collection and PDF-view lifetimes in one owner.
/// A second worker/process must fail before touching staging or initialization.
private final class LibraryLock {
    private let descriptor: Int32

    init(url: URL) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR, mode_t(0o600))
        guard descriptor >= 0 else { throw MaterialError.invalidState }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            _ = close(descriptor)
            throw MaterialError.invalidState
        }
    }

    deinit {
        _ = flock(descriptor, LOCK_UN)
        _ = close(descriptor)
    }
}
