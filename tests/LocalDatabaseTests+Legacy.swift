import Foundation
import XCTest
import GRDB
@testable import TakupokeParsing

extension LocalDatabaseTests {
    func testMigrationRoundTripRetainsParallelLessonsAndUnknownApplicability() throws {
        let state = try fixture()
        let originalJSON = try Data(contentsOf: legacy.appendingPathComponent("library.json"))
        let candidate = try prepare()
        let database = try LocalMaterialDatabase(url: candidate.appendingPathComponent("library.sqlite"))
        defer { try? database.close() }
        XCTAssertEqual(try LocalMaterialDatabase.encode(database.legacySnapshot()), try LocalMaterialDatabase.encode(state))
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("library.json")), originalJSON)
        for record in state.records {
            XCTAssertEqual(try Data(contentsOf: candidate.appendingPathComponent("files/\(record.storedName)")),
                           try Data(contentsOf: legacy.appendingPathComponent("files/\(record.storedName)")))
        }
        let raw = try DatabaseQueue(path: candidate.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM lesson WHERE weekday = 1 AND period = 1"), 2)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM analysis WHERE applicability = 'unknown'"), 3)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM changeRow WHERE sourceRow IS NULL AND period = '1,2'"), 1)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM attempt WHERE succeeded = 0"), 1)
        }
    }

    func testOldAnalysisKeepsMissingOriginalInsteadOfNewFile() throws {
        var state = try fixture()
        state.pdfAnalyses?["timetable"]?.sourceDigest = "synthetic-old-timetable"
        try save(state)
        let candidate = try prepare()
        let raw = try DatabaseQueue(path: candidate.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.read { db in
            let row = try XCTUnwrap(Row.fetchOne(db, sql: """
                SELECT o.digest, o.storedName, o.sourceID FROM analysis a JOIN original o ON o.id = a.originalID
                WHERE a.kind = 'timetable'
                """))
            XCTAssertEqual(row["digest"] as String, "synthetic-old-timetable")
            XCTAssertNil(row["storedName"] as String?)
            XCTAssertNil(row["sourceID"] as String?)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM original"), 4)
        }
    }

    func testInterruptedPreparationOnlyRemovesOwnedCandidate() throws {
        _ = try fixture()
        try FileManager.default.createDirectory(at: candidates, withIntermediateDirectories: true)
        let unrelated = candidates.appendingPathComponent("another-operation")
        try Data([1]).write(to: unrelated)
        let originalJSON = try Data(contentsOf: legacy.appendingPathComponent("library.json"))
        enum Interrupted: Error { case simulated }
        for interrupted in [LegacyDatabaseMigration.Stage.copiedOriginal, .imported, .reopened] {
            XCTAssertThrowsError(try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: candidates) { stage in
                if stage == interrupted { throw Interrupted.simulated }
            })
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: candidates.path), ["another-operation"])
            XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("library.json")), originalJSON)
        }
        XCTAssertNoThrow(try prepare())
    }

    func testImportTransactionRollsBackAndCanRetry() throws {
        let state = try fixture()
        let database = try LocalMaterialDatabase(url: root.appendingPathComponent("library.sqlite"), create: true)
        defer { try? database.close() }
        enum Interrupted: Error { case simulated }
        XCTAssertThrowsError(try database.importLegacy(state) { throw Interrupted.simulated })
        XCTAssertThrowsError(try database.legacySnapshot())
        try database.importLegacy(state)
        XCTAssertEqual(try LocalMaterialDatabase.encode(database.legacySnapshot()), try LocalMaterialDatabase.encode(state))
        XCTAssertThrowsError(try database.importLegacy(state))
        XCTAssertEqual(try database.legacySnapshot().records.count, state.records.count)
    }

    func testUnreadableManifestIsNotReplacedOrInitialized() throws {
        _ = try fixture()
        let manifest = legacy.appendingPathComponent("library.json")
        let invalid = Data("not JSON".utf8)
        try invalid.write(to: manifest)
        XCTAssertThrowsError(try prepare())
        XCTAssertEqual(try Data(contentsOf: manifest), invalid)
        XCTAssertFalse(FileManager.default.fileExists(atPath: candidates.path))
    }

    func testMissingFileAndTraversalFailWithoutDeletingLegacyCopies() throws {
        var state = try fixture()
        let preserved = legacy.appendingPathComponent("files/\(state.records[1].storedName)")
        let bytes = try Data(contentsOf: preserved)
        state.records[0].storedName = "../outside.pdf"
        try save(state)
        XCTAssertThrowsError(try prepare())
        state.records[0].storedName = "\(UUID().uuidString).pdf"
        try save(state)
        XCTAssertThrowsError(try prepare())
        XCTAssertEqual(try Data(contentsOf: preserved), bytes)
    }

    func testSymlinkOriginalAndOverlappingRootsRejected() throws {
        let state = try fixture()
        XCTAssertThrowsError(try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: legacy))
        XCTAssertThrowsError(try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: legacy.appendingPathComponent("new")))
        let file = legacy.appendingPathComponent("files/\(state.records[0].storedName)")
        let outside = root.appendingPathComponent("outside.pdf")
        try FileManager.default.moveItem(at: file, to: outside)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
        XCTAssertThrowsError(try prepare())
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testSourceChangedDuringPreparationIsNotReportedReady() throws {
        var state = try fixture()
        XCTAssertThrowsError(try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: candidates) { stage in
            if stage == .reopened {
                state.attempts["changes"] = AcquisitionAttempt(date: self.time, failure: "架空の失敗")
                try self.save(state)
            }
        })
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: candidates.path).isEmpty)
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("library.json")), try LocalMaterialDatabase.encode(state))
    }

    func testDatabaseOpenDoesNotCreateMissingOrOverwriteFutureSchema() throws {
        let url = root.appendingPathComponent("library.sqlite")
        XCTAssertThrowsError(try LocalMaterialDatabase(url: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let database = try LocalMaterialDatabase(url: url, create: true)
        try database.close()
        let raw = try DatabaseQueue(path: url.path)
        try raw.write { try $0.execute(sql: "PRAGMA user_version = 999") }
        try raw.close()
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try LocalMaterialDatabase(url: url))
        XCTAssertThrowsError(try LocalMaterialDatabase(url: url, create: true))
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testConstraintsRejectWrongKindMutationAndReferencedOriginalDeletion() throws {
        _ = try fixture()
        let candidate = try prepare()
        let raw = try DatabaseQueue(path: candidate.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.write { db in
            XCTAssertThrowsError(try db.execute(sql: """
                INSERT INTO lesson SELECT id, 'timetable', 0, '架空組', 1, 1, payload
                FROM analysis WHERE kind = 'events'
                """))
            XCTAssertThrowsError(try db.execute(sql: "UPDATE lesson SET period = 2"))
            XCTAssertThrowsError(try db.execute(sql: "UPDATE original SET digest = 'different'"))
            XCTAssertThrowsError(try db.execute(sql: "DELETE FROM original"))
        }
    }

    func testReparseIdentityIncludesParserAndInputConditions() throws {
        _ = try fixture()
        let candidate = try prepare()
        let raw = try DatabaseQueue(path: candidate.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.write { db in
            let insert = """
                INSERT INTO analysis (id, originalID, kind, parserVersion, conditions, parsedAt, payload)
                SELECT ?, originalID, kind, ?, ?, parsedAt, payload FROM analysis WHERE kind = 'changes' LIMIT 1
                """
            let row = try XCTUnwrap(Row.fetchOne(db, sql: "SELECT * FROM analysis WHERE kind = 'changes'"))
            let version: Int = row["parserVersion"]
            let conditions: Data = row["conditions"]
            XCTAssertThrowsError(try db.execute(sql: insert, arguments: ["duplicate", version, conditions]))
            try db.execute(sql: insert, arguments: ["new-parser", version + 1, conditions])
            try db.execute(sql: insert, arguments: ["new-year", version, Data("different-input-conditions".utf8)])
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM analysis WHERE kind = 'changes'"), 3)
        }
        let database = try LocalMaterialDatabase(url: candidate.appendingPathComponent("library.sqlite"))
        defer { try? database.close() }
        XCTAssertThrowsError(try database.legacySnapshot())
    }

    func testVerificationRejectsMissingRowsAndInconsistentProjection() throws {
        _ = try fixture()
        for corruption in ["DELETE FROM lesson WHERE ordinal = 0",
                           "DROP TRIGGER lesson_immutable; UPDATE lesson SET period = 2"] {
            let candidate = try prepare()
            let raw = try DatabaseQueue(path: candidate.appendingPathComponent("library.sqlite").path)
            try raw.write { try $0.execute(sql: corruption) }
            try raw.close()
            let database = try LocalMaterialDatabase(url: candidate.appendingPathComponent("library.sqlite"))
            defer { try? database.close() }
            XCTAssertThrowsError(try database.legacySnapshot())
        }
    }

    func testEmptyArchiveMigratesWithoutPretendingThereAreNoChanges() throws {
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        var state = MaterialLibraryState()
        state.pdfAnalyses = [:]
        state.pdfParseAttempts = [:]
        try save(state)
        let candidate = try prepare()
        let database = try LocalMaterialDatabase(url: candidate.appendingPathComponent("library.sqlite"))
        defer { try? database.close() }
        XCTAssertNil(try database.legacySnapshot().changeAnalysis)
        state.changeAnalysis = ChangeAnalysis(sourceDigest: "synthetic", sourceName: "架空.xlsx", defaultYear: nil,
                                             parsedAt: time, records: [])
        try save(state)
        XCTAssertThrowsError(try prepare())
    }
}
