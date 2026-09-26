import Foundation
import GRDB

extension LocalMaterialDatabase {
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
            if let analysis = state.changeAnalysis { _ = try Self.writeChanges(db, analysis) }
            for analysis in (state.pdfAnalyses ?? [:]).values { _ = try Self.writePDF(db, analysis) }
            try checkpoint()
            try db.execute(sql: "UPDATE library SET migrationComplete = 1 WHERE id = 1")
        }
    }

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
            try Self.readAnalyses(db, rows: Row.fetchAll(db, sql: "SELECT a.*, o.digest FROM analysis a JOIN original o ON o.id = a.originalID"), state: &state)
            return try MaterialLibrary.decodeLegacyManifest(Self.encode(state))
        }
    }
}
