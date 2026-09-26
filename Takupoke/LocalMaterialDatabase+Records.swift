import Foundation
import GRDB

extension LocalMaterialDatabase {
    static func writeChanges(_ db: Database, _ analysis: ChangeAnalysis, original: String? = nil) throws -> String {
        let id = try Self.insertAnalysis(db, kind: .changes, digest: analysis.sourceDigest,
            name: analysis.sourceName, version: analysis.version,
            conditions: Self.encode(Conditions(defaultYear: analysis.defaultYear)),
            parsedAt: analysis.parsedAt, payload: Self.encode(analysis), original: original)
        for (ordinal, change) in analysis.records.enumerated() {
            // Ordinal is array order, never an invented spreadsheet row number.
            try db.execute(sql: """
                INSERT INTO changeRow (analysisID, kind, ordinal, actualDate, className, period, payload)
                VALUES (?, 'changes', ?, ?, ?, ?, ?)
                """, arguments: [id, ordinal, change.change_date, change.class_name,
                                  change.period, try Self.encode(change)])
        }
        return id
    }

    static func writePDF(_ db: Database, _ analysis: PDFAnalysis, original: String? = nil) throws -> String {
        let id = try Self.insertAnalysis(db, kind: analysis.kind, digest: analysis.sourceDigest,
            name: analysis.sourceName, version: analysis.version,
            conditions: Self.encode(Conditions(defaultYear: nil)),
            parsedAt: analysis.parsedAt, payload: Self.encode(analysis), original: original)
        for (ordinal, lesson) in analysis.lessons.enumerated() {
            try db.execute(sql: """
                INSERT INTO lesson (analysisID, kind, ordinal, className, weekday, period, payload)
                VALUES (?, 'timetable', ?, ?, ?, ?, ?)
                """, arguments: [id, ordinal, lesson.className, lesson.weekday,
                                  lesson.period, try Self.encode(lesson)])
        }
        // Keep the existing event payload intact; calendar semantics are frozen.
        return id
    }

    private struct Conditions: Encodable {
        let defaultYear: Int?
        // Existing parser contract; no external name-mapping input is supported.
        // Keep the persisted identifier compatible with the foundation tests.
        let contract = "legacy-v1"
    }

    static func insertAttempt(_ db: Database, kind: String, operation: String,
                                      date: Date, succeeded: Bool, payload: Data) throws {
        try db.execute(sql: """
            INSERT INTO attempt (kind, operation, finishedAt, succeeded, payload) VALUES (?, ?, ?, ?, ?)
            """, arguments: [kind, operation, date.timeIntervalSince1970, succeeded, payload])
    }

    private static func insertAnalysis(_ db: Database, kind: MaterialKind, digest: String,
                                       name: String, version: Int, conditions: Data,
                                       parsedAt: Date, payload: Data, original: String? = nil) throws -> String {
        guard !digest.isEmpty else { throw StoreError.invalidDatabase }
        let originalID: String
        if let original {
            originalID = original
        } else if let found = try String.fetchOne(db, sql: "SELECT id FROM original WHERE kind = ? AND digest = ?",
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
    static func readAnalyses(_ db: Database, rows: [Row], state: inout MaterialLibraryState) throws {
        for row in rows {
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
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
