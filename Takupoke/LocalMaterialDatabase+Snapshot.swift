import Foundation
import GRDB

extension LocalMaterialDatabase {
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

    static func currentSnapshot(_ db: Database) throws -> (MaterialLibraryState, Int64) {
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
}
