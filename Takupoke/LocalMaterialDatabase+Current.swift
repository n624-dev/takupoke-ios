import Foundation
import GRDB

extension LocalMaterialDatabase {
    func initializeCurrentLibrary() throws {
        try queue.write { db in
            guard try Int.fetchOne(db, sql: "SELECT count(*) FROM library") == 0,
                  try Int.fetchOne(db, sql: "SELECT count(*) FROM original") == 0 else {
                throw StoreError.invalidDatabase
            }
            try db.execute(sql: "INSERT INTO currentLibrary (id, generation) VALUES (1, 0)")
        }
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
