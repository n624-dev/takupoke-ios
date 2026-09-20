import Foundation
import GRDB

/// Storage foundation. No acquisition, parsing, adoption, or legacy fallback occurs here.
/// The application still uses MaterialLibrary until cutover has been implemented.
final class LocalMaterialDatabase {
    enum StoreError: Error { case invalidDatabase, unsupportedSchema, incompleteMigration }
    static let schemaVersion = 1
    private static let applicationID = 0x544B504B // TKPK
    private let queue: DatabaseQueue

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

    func close() throws { try queue.close() }

    /// A receipt means the import is complete, not that its timetable can be adopted.
    /// The caller must first copy and verify original files outside the transaction.
    func importLegacy(_ state: MaterialLibraryState, checkpoint: () throws -> Void = {}) throws {
        _ = try MaterialLibrary.decodeLegacyManifest(Self.encode(state))
        try queue.write { db in
            guard try Int.fetchOne(db, sql: "SELECT count(*) FROM library") == 0 else {
                throw StoreError.invalidDatabase
            }
            try db.execute(sql: "INSERT INTO library (id, folder) VALUES (1, ?)",
                           arguments: [try state.folder.map(Self.encode)])
            for (index, record) in state.records.enumerated() {
                let sourceID = UUID().uuidString
                let originalID = UUID().uuidString
                try db.execute(sql: "INSERT INTO source (id, kind, settings) VALUES (?, ?, ?)",
                               arguments: [sourceID, record.kind.rawValue, try Self.encode(record.source)])
                try db.execute(sql: """
                    INSERT INTO original (id, sourceID, kind, digest, originalName, storedName, record, legacyPosition)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [originalID, sourceID, record.kind.rawValue, record.digest,
                                      record.originalName, record.storedName, try Self.encode(record), index])
            }
            for (kind, attempt) in state.attempts {
                guard MaterialKind(rawValue: kind) != nil else { throw StoreError.invalidDatabase }
                try Self.insertAttempt(db, kind: kind, operation: "acquire", date: attempt.date,
                                       succeeded: attempt.failure == nil, payload: Self.encode(attempt))
            }
            if let attempt = state.changeParseAttempt {
                try Self.insertAttempt(db, kind: "changes", operation: "parse", date: attempt.date,
                                       succeeded: attempt.failure == nil, payload: Self.encode(attempt))
            }
            for (kind, attempt) in state.pdfParseAttempts ?? [:] {
                guard ["timetable", "events"].contains(kind) else { throw StoreError.invalidDatabase }
                try Self.insertAttempt(db, kind: kind, operation: "parse", date: attempt.date,
                                       succeeded: attempt.failure == nil, payload: Self.encode(attempt))
            }
            if let analysis = state.changeAnalysis {
                let id = try Self.insertAnalysis(db, kind: .changes, digest: analysis.sourceDigest,
                    name: analysis.sourceName, version: analysis.version,
                    conditions: Self.encode(Conditions(defaultYear: analysis.defaultYear)),
                    parsedAt: analysis.parsedAt, payload: Self.encode(analysis))
                for (ordinal, change) in analysis.records.enumerated() {
                    // Ordinal is array order, never an invented spreadsheet row number.
                    try db.execute(sql: """
                        INSERT INTO changeRow (analysisID, kind, ordinal, actualDate, className, period, payload)
                        VALUES (?, 'changes', ?, ?, ?, ?, ?)
                        """, arguments: [id, ordinal, change.change_date, change.class_name,
                                          change.period, try Self.encode(change)])
                }
            }
            for analysis in (state.pdfAnalyses ?? [:]).values {
                let id = try Self.insertAnalysis(db, kind: analysis.kind, digest: analysis.sourceDigest,
                    name: analysis.sourceName, version: analysis.version,
                    conditions: Self.encode(Conditions(defaultYear: nil)),
                    parsedAt: analysis.parsedAt, payload: Self.encode(analysis))
                for (ordinal, lesson) in analysis.lessons.enumerated() {
                    try db.execute(sql: """
                        INSERT INTO lesson (analysisID, kind, ordinal, className, weekday, period, payload)
                        VALUES (?, 'timetable', ?, ?, ?, ?, ?)
                        """, arguments: [id, ordinal, lesson.className, lesson.weekday,
                                          lesson.period, try Self.encode(lesson)])
                }
                // Keep the existing event payload intact; calendar semantics are frozen.
            }
            try checkpoint()
            try db.execute(sql: "UPDATE library SET migrationComplete = 1 WHERE id = 1")
        }
    }

    private struct Conditions: Encodable {
        let defaultYear: Int?
        // Legacy storage has no identifier for an external name mapping.
        let contract = "legacy-v1"
    }

    private static func insertAttempt(_ db: Database, kind: String, operation: String,
                                      date: Date, succeeded: Bool, payload: Data) throws {
        try db.execute(sql: """
            INSERT INTO attempt (kind, operation, finishedAt, succeeded, payload) VALUES (?, ?, ?, ?, ?)
            """, arguments: [kind, operation, date.timeIntervalSince1970, succeeded, payload])
    }

    private static func insertAnalysis(_ db: Database, kind: MaterialKind, digest: String,
                                       name: String, version: Int, conditions: Data,
                                       parsedAt: Date, payload: Data) throws -> String {
        guard !digest.isEmpty else { throw StoreError.invalidDatabase }
        let originalID: String
        if let found = try String.fetchOne(db, sql: "SELECT id FROM original WHERE kind = ? AND digest = ?",
                                          arguments: [kind.rawValue, digest]) {
            originalID = found
        } else {
            // The old successful analysis can predate the retained current original.
            // Keep its provenance without inventing a file, size, source, or acquisition date.
            originalID = UUID().uuidString
            try db.execute(sql: "INSERT INTO original (id, kind, digest, originalName) VALUES (?, ?, ?, ?)",
                           arguments: [originalID, kind.rawValue, digest, name])
        }
        let id = UUID().uuidString
        try db.execute(sql: """
            INSERT INTO analysis (id, originalID, kind, parserVersion, conditions, parsedAt, payload)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, arguments: [id, originalID, kind.rawValue, version, conditions,
                              parsedAt.timeIntervalSince1970, payload])
        return id
    }

    /// Verification of a one-time legacy import, not a current/adopted-data query.
    /// Reject multiple analyses per kind instead of choosing an arbitrary version.
    /// One read transaction: never assemble different observations of the database.
    func legacySnapshot() throws -> MaterialLibraryState {
        try queue.read { db in
            guard let library = try Row.fetchOne(db, sql: "SELECT * FROM library WHERE id = 1"),
                  library["migrationComplete"] as Bool else { throw StoreError.incompleteMigration }
            guard try String.fetchOne(db, sql: "PRAGMA quick_check") == "ok",
                  try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty else {
                throw StoreError.invalidDatabase
            }
            guard try Row.fetchAll(db, sql: "SELECT kind FROM analysis GROUP BY kind HAVING count(*) > 1").isEmpty else {
                throw StoreError.invalidDatabase
            }
            var state = MaterialLibraryState()
            if let data: Data = library["folder"] { state.folder = try Self.decode(SourceGrant.self, data) }
            for row in try Row.fetchAll(db, sql: """
                SELECT o.*, s.settings FROM original o JOIN source s ON s.id = o.sourceID
                WHERE o.record IS NOT NULL ORDER BY o.legacyPosition
                """) {
                let record = try Self.decode(MaterialRecord.self, row["record"])
                guard row["kind"] as String == record.kind.rawValue,
                      row["digest"] as String == record.digest,
                      row["storedName"] as String == record.storedName,
                      row["originalName"] as String == record.originalName,
                      row["settings"] as Data == (try Self.encode(record.source)) else {
                    throw StoreError.invalidDatabase
                }
                state.records.append(record)
            }
            for row in try Row.fetchAll(db, sql: "SELECT kind, operation, payload FROM attempt ORDER BY id") {
                let kind: String = row["kind"]
                let data: Data = row["payload"]
                if row["operation"] as String == "acquire" {
                    state.attempts[kind] = try Self.decode(AcquisitionAttempt.self, data)
                } else if kind == "changes" {
                    state.changeParseAttempt = try Self.decode(ChangeParseAttempt.self, data)
                } else {
                    if state.pdfParseAttempts == nil { state.pdfParseAttempts = [:] }
                    state.pdfParseAttempts?[kind] = try Self.decode(PDFParseAttempt.self, data)
                }
            }
            for row in try Row.fetchAll(db, sql: "SELECT a.*, o.digest FROM analysis a JOIN original o ON o.id = a.originalID") {
                let id: String = row["id"]
                let kind: String = row["kind"]
                let data: Data = row["payload"]
                if kind == "changes" {
                    let analysis = try Self.decode(ChangeAnalysis.self, data)
                    let records = try Data.fetchAll(db, sql: "SELECT payload FROM changeRow WHERE analysisID = ? ORDER BY ordinal", arguments: [id])
                        .map { try Self.decode(ScheduleChange.self, $0) }
                    guard records == analysis.records,
                          row["digest"] as String == analysis.sourceDigest,
                          row["parserVersion"] as Int == analysis.version,
                          row["conditions"] as Data == (try Self.encode(Conditions(defaultYear: analysis.defaultYear))),
                          row["parsedAt"] as Double == analysis.parsedAt.timeIntervalSince1970 else {
                        throw StoreError.invalidDatabase
                    }
                    let projections = try Row.fetchAll(db, sql: "SELECT * FROM changeRow WHERE analysisID = ? ORDER BY ordinal", arguments: [id])
                    for (ordinal, projection) in projections.enumerated() {
                        let change = records[ordinal]
                        guard projection["ordinal"] as Int == ordinal,
                              projection["actualDate"] as String == change.change_date,
                              projection["className"] as String == change.class_name,
                              projection["period"] as String == change.period,
                              projection["sourceRow"] as Int? == nil else { throw StoreError.invalidDatabase }
                    }
                    state.changeAnalysis = analysis
                } else {
                    let analysis = try Self.decode(PDFAnalysis.self, data)
                    let lessons = try Data.fetchAll(db, sql: "SELECT payload FROM lesson WHERE analysisID = ? ORDER BY ordinal", arguments: [id])
                        .map { try Self.decode(PDFLesson.self, $0) }
                    guard lessons == analysis.lessons, kind == analysis.kind.rawValue,
                          row["digest"] as String == analysis.sourceDigest,
                          row["parserVersion"] as Int == analysis.version,
                          row["conditions"] as Data == (try Self.encode(Conditions(defaultYear: nil))),
                          row["parsedAt"] as Double == analysis.parsedAt.timeIntervalSince1970 else {
                        throw StoreError.invalidDatabase
                    }
                    let projections = try Row.fetchAll(db, sql: "SELECT * FROM lesson WHERE analysisID = ? ORDER BY ordinal", arguments: [id])
                    for (ordinal, projection) in projections.enumerated() {
                        let lesson = lessons[ordinal]
                        guard projection["ordinal"] as Int == ordinal,
                              projection["className"] as String == lesson.className,
                              projection["weekday"] as Int == lesson.weekday,
                              projection["period"] as Int == lesson.period else { throw StoreError.invalidDatabase }
                    }
                    if state.pdfAnalyses == nil { state.pdfAnalyses = [:] }
                    state.pdfAnalyses?[kind] = analysis
                }
            }
            return try MaterialLibrary.decodeLegacyManifest(Self.encode(state))
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    private static let schema = """
        CREATE TABLE library (
            id INTEGER PRIMARY KEY CHECK (id = 1), folder BLOB,
            migrationComplete INTEGER NOT NULL DEFAULT 0 CHECK (migrationComplete IN (0, 1))
        );
        CREATE TABLE source (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            settings BLOB NOT NULL, UNIQUE (id, kind)
        );
        CREATE TABLE original (
            id TEXT PRIMARY KEY NOT NULL, sourceID TEXT,
            kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            digest TEXT NOT NULL CHECK (length(digest) > 0), originalName TEXT NOT NULL,
            storedName TEXT UNIQUE, record BLOB, legacyPosition INTEGER UNIQUE,
            UNIQUE (id, kind),
            FOREIGN KEY (sourceID, kind) REFERENCES source (id, kind),
            CHECK ((record IS NULL AND storedName IS NULL AND legacyPosition IS NULL) OR
                   (record IS NOT NULL AND storedName IS NOT NULL AND legacyPosition IS NOT NULL))
        );
        CREATE INDEX original_content ON original (kind, digest);
        CREATE TABLE analysis (
            id TEXT PRIMARY KEY NOT NULL, originalID TEXT NOT NULL, kind TEXT NOT NULL,
            parserVersion INTEGER NOT NULL CHECK (parserVersion > 0), conditions BLOB NOT NULL,
            parsedAt REAL NOT NULL, payload BLOB NOT NULL,
            applicability TEXT NOT NULL DEFAULT 'unknown' CHECK (applicability = 'unknown'),
            UNIQUE (id, kind), UNIQUE (originalID, kind, parserVersion, conditions),
            FOREIGN KEY (originalID, kind) REFERENCES original (id, kind)
        );
        CREATE TABLE lesson (
            analysisID TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind = 'timetable'),
            ordinal INTEGER NOT NULL CHECK (ordinal >= 0), className TEXT NOT NULL,
            weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 5),
            period INTEGER NOT NULL CHECK (period BETWEEN 1 AND 8), payload BLOB NOT NULL,
            PRIMARY KEY (analysisID, ordinal),
            FOREIGN KEY (analysisID, kind) REFERENCES analysis (id, kind)
        );
        CREATE INDEX lesson_slot ON lesson (analysisID, className, weekday, period);
        CREATE TABLE changeRow (
            analysisID TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind = 'changes'),
            ordinal INTEGER NOT NULL CHECK (ordinal >= 0), actualDate TEXT NOT NULL,
            className TEXT NOT NULL, period TEXT NOT NULL, sourceRow INTEGER,
            payload BLOB NOT NULL, PRIMARY KEY (analysisID, ordinal),
            FOREIGN KEY (analysisID, kind) REFERENCES analysis (id, kind)
        );
        CREATE INDEX change_day ON changeRow (analysisID, actualDate, className);
        CREATE TABLE attempt (
            id INTEGER PRIMARY KEY, kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            operation TEXT NOT NULL CHECK (operation IN ('acquire', 'parse')),
            finishedAt REAL NOT NULL, succeeded INTEGER NOT NULL CHECK (succeeded IN (0, 1)), payload BLOB NOT NULL
        );
        CREATE TRIGGER original_immutable BEFORE UPDATE ON original BEGIN SELECT RAISE(ABORT, 'immutable original'); END;
        CREATE TRIGGER analysis_immutable BEFORE UPDATE ON analysis BEGIN SELECT RAISE(ABORT, 'immutable analysis'); END;
        CREATE TRIGGER lesson_immutable BEFORE UPDATE ON lesson BEGIN SELECT RAISE(ABORT, 'immutable lesson'); END;
        CREATE TRIGGER change_immutable BEFORE UPDATE ON changeRow BEGIN SELECT RAISE(ABORT, 'immutable change'); END;
        """
}
