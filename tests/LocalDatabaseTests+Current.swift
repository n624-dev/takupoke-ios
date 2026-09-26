import Foundation
import XCTest
import GRDB
@testable import TakupokeParsing

extension LocalDatabaseTests {
    func testRuntimeRoundTripAndRecordReordering() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        for kind in MaterialKind.allCases { try acquire(library, kind: kind) }
        for analysis in try XCTUnwrap(example.pdfAnalyses).values { try library.savePDFAnalysis(analysis) }
        try library.saveChangeAnalysis(try XCTUnwrap(example.changeAnalysis))
        try library.recordParseFailure(ChangeParseError(code: .storage), defaultYear: 2033)
        try library.recordPDFFailure(PDFParseError(code: .storage), kind: .timetable)
        try library.recordFailure(.events, message: "架空の失敗")
        // Replacement moves timetable to the end, preserving both other kinds.
        try acquire(library, kind: .timetable, suffix: "new")
        let reopened = try LocalMaterialDatabase(url: runtime.appendingPathComponent("library.sqlite"))
        defer { try? reopened.close() }
        XCTAssertEqual(try LocalMaterialDatabase.encode(reopened.load()), try LocalMaterialDatabase.encode(library.state))
        XCTAssertEqual(library.state.records.last?.kind, .timetable)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.lessons.count, 2)
    }

    func testRuntimeKeepsOriginalForPreviousGoodAnalysisAndCollectsOnlyAfterRestart() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .timetable)
        let oldFile = try XCTUnwrap(library.localURL(for: .timetable))
        try library.savePDFAnalysis(try XCTUnwrap(example.pdfAnalyses?["timetable"]))
        try acquire(library, kind: .timetable, suffix: "new")
        try library.recordPDFFailure(PDFParseError(code: .storage), kind: .timetable)
        XCTAssertTrue(try db.retainedStoredNames().contains(oldFile.lastPathComponent))
        var next = try XCTUnwrap(example.pdfAnalyses?["timetable"])
        next.sourceDigest += "new"
        next.parsedAt = time.addingTimeInterval(1)
        try library.savePDFAnalysis(next)
        XCTAssertFalse(try db.retainedStoredNames().contains(oldFile.lastPathComponent))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldFile.path)) // A view may still use it.
        try db.close()
        let restarted = try LocalMaterialDatabase.openLibrary(root: runtime)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        XCTAssertEqual(restarted.state.pdfAnalyses?["timetable"]?.sourceDigest, next.sourceDigest)
    }

    func testRuntimeAcquisitionRollbackKeepsMemoryDatabaseAndOriginal() throws {
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .timetable)
        let before = try LocalMaterialDatabase.encode(library.state)
        let oldFile = try XCTUnwrap(library.localURL(for: .timetable))
        db.beforeCommit = { throw MaterialError.cancelled }
        XCTAssertThrowsError(try acquire(library, kind: .timetable, suffix: "failed"))
        XCTAssertEqual(try LocalMaterialDatabase.encode(library.state), before)
        XCTAssertEqual(try LocalMaterialDatabase.encode(db.load()), before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: runtime.appendingPathComponent("files").path),
                       [oldFile.lastPathComponent])
        db.beforeCommit = {}
        try acquire(library, kind: .timetable, suffix: "retry")
        XCTAssertEqual(library.state.record(for: .timetable)?.digest, "synthetic-timetableretry")
    }

    func testRuntimeAnalysisRollbackPreservesLastGoodRows() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .timetable)
        var analysis = try XCTUnwrap(example.pdfAnalyses?["timetable"])
        try library.savePDFAnalysis(analysis)
        let before = try LocalMaterialDatabase.encode(library.state)
        analysis.parsedAt = time.addingTimeInterval(1)
        analysis.lessons.removeLast()
        db.beforeCommit = { throw MaterialError.cancelled }
        XCTAssertThrowsError(try library.savePDFAnalysis(analysis))
        XCTAssertEqual(try LocalMaterialDatabase.encode(library.state), before)
        XCTAssertEqual(try LocalMaterialDatabase.encode(db.load()), before)
    }

    func testRuntimeRejectsStaleWriter() throws {
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        let other = try LocalMaterialDatabase(url: runtime.appendingPathComponent("library.sqlite"))
        defer { try? other.close() }
        var stale = try other.load()
        try acquire(library, kind: .timetable)
        stale.attempts["changes"] = AcquisitionAttempt(date: time, failure: "架空の失敗")
        XCTAssertThrowsError(try other.save(stale)) {
            guard case LocalMaterialDatabase.StoreError.staleState = $0 else { return XCTFail("wrong error") }
        }
        XCTAssertEqual(try db.load().record(for: .timetable)?.digest, "synthetic-timetable")
    }

    func testRuntimeReparseAndChangedYearPreserveDistinctInputConditions() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .changes)
        var analysis = try XCTUnwrap(example.changeAnalysis)
        try library.saveChangeAnalysis(analysis)
        analysis.parsedAt = time.addingTimeInterval(1)
        try library.saveChangeAnalysis(analysis)
        analysis.defaultYear = 2034
        analysis.parsedAt = time.addingTimeInterval(2)
        try library.saveChangeAnalysis(analysis)
        XCTAssertEqual(try db.load().changeAnalysis?.defaultYear, 2034)
        XCTAssertEqual(try db.load().changeAnalysis?.parsedAt, analysis.parsedAt)
    }

    func testRuntimeUnchangedResponseUpdatesValidatorsWithoutReplacingOriginal() throws {
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .events)
        let old = try XCTUnwrap(library.state.record(for: .events))
        var source = old.source
        source.remoteETag = "synthetic-etag"
        try library.recordUnchanged(.events, source: source)
        let current = try XCTUnwrap(db.load().record(for: .events))
        XCTAssertEqual(current.storedName, old.storedName)
        XCTAssertEqual(current.acquiredAt, old.acquiredAt)
        XCTAssertEqual(current.source.remoteETag, source.remoteETag)
        XCTAssertNotNil(current.lastCheckedAt)
    }

    func testFreshSQLiteCutoverIgnoresLegacyAndReopensWithoutReset() throws {
        _ = try fixture()
        let legacyBytes = try Data(contentsOf: legacy.appendingPathComponent("library.json"))
        do {
            let library = try LocalMaterialDatabase.openLibrary(root: runtime)
            XCTAssertTrue(library.state.records.isEmpty)
            try acquire(library, kind: .changes)
        }
        let restarted = try LocalMaterialDatabase.openLibrary(root: runtime)
        XCTAssertEqual(restarted.state.record(for: .changes)?.digest, "synthetic-changes")
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("library.json")), legacyBytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtime.appendingPathComponent("library.json").path))
    }

    func testIncompleteInitializationAndOrphanFilesAreRecovered() throws {
        let pending = root.appendingPathComponent("runtime.initializing")
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: false)
        try Data("interrupted initializer".utf8).write(to: pending.appendingPathComponent("library.sqlite"))
        do { _ = try LocalMaterialDatabase.openLibrary(root: runtime) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
        let staged = runtime.appendingPathComponent("staging/owned-interrupted-copy")
        let orphan = runtime.appendingPathComponent("files/\(UUID().uuidString).pdf")
        try Data([1]).write(to: staged)
        try Data([2]).write(to: orphan)
        _ = try LocalMaterialDatabase.openLibrary(root: runtime)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testMissingOrCorruptCurrentDatabaseDoesNotResetOrCollectFiles() throws {
        try FileManager.default.createDirectory(at: runtime.appendingPathComponent("files"), withIntermediateDirectories: true)
        let file = runtime.appendingPathComponent("files/\(UUID().uuidString).pdf")
        try Data([1, 2]).write(to: file)
        XCTAssertThrowsError(try LocalMaterialDatabase.openLibrary(root: runtime))
        let url = runtime.appendingPathComponent("library.sqlite")
        let corrupt = Data("corrupt synthetic database".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try LocalMaterialDatabase.openLibrary(root: runtime))
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        XCTAssertEqual(try Data(contentsOf: file), Data([1, 2]))
    }

    func testRuntimeRejectsMissingCurrentOriginalWithoutErasingAnalysis() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        try acquire(library, kind: .timetable)
        try library.savePDFAnalysis(try XCTUnwrap(example.pdfAnalyses?["timetable"]))
        try FileManager.default.removeItem(at: XCTUnwrap(library.localURL(for: .timetable)))
        try db.close()
        XCTAssertThrowsError(try LocalMaterialDatabase.openLibrary(root: runtime))
        let saved = try LocalMaterialDatabase(url: runtime.appendingPathComponent("library.sqlite"))
        defer { try? saved.close() }
        XCTAssertEqual(try saved.load().pdfAnalyses?["timetable"]?.lessons.count, 2)
    }

    func testSecondRuntimeOwnerCannotCollectActiveStaging() throws {
        let library = try LocalMaterialDatabase.openLibrary(root: runtime)
        let staged = library.newStagingURL()
        try Data([1, 2, 3]).write(to: staged)
        XCTAssertThrowsError(try LocalMaterialDatabase.openLibrary(root: runtime))
        XCTAssertEqual(try Data(contentsOf: staged), Data([1, 2, 3]))
        library.discardStaging(staged)
    }

    func testRuntimeBindsReparseToExactAcquisitionEvenWhenBytesMatch() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .timetable)
        var analysis = try XCTUnwrap(example.pdfAnalyses?["timetable"])
        try library.savePDFAnalysis(analysis)
        try acquire(library, kind: .timetable) // Same digest, different acquisition/file.
        analysis.parsedAt = time.addingTimeInterval(1)
        try library.savePDFAnalysis(analysis)
        let raw = try DatabaseQueue(path: runtime.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.read { connection in
            let name = try String.fetchOne(connection, sql: """
                SELECT o.storedName FROM currentAnalysis c
                JOIN analysis a ON a.id = c.analysisID JOIN original o ON o.id = a.originalID
                WHERE c.kind = 'timetable'
                """)
            XCTAssertEqual(name, library.state.record(for: .timetable)?.storedName)
            XCTAssertEqual(try Int.fetchOne(connection, sql: "SELECT count(*) FROM analysis"), 1)
            XCTAssertEqual(try Int.fetchOne(connection, sql: "SELECT count(*) FROM original"), 1)
        }
    }

    func testRuntimeProjectionCorruptionRefusesLoadAndWrite() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try acquire(library, kind: .timetable)
        try library.savePDFAnalysis(try XCTUnwrap(example.pdfAnalyses?["timetable"]))
        let raw = try DatabaseQueue(path: runtime.appendingPathComponent("library.sqlite").path)
        defer { try? raw.close() }
        try raw.write { connection in
            try connection.execute(sql: "DELETE FROM lesson WHERE ordinal = 0")
        }
        XCTAssertThrowsError(try db.load())
        XCTAssertThrowsError(try library.recordFailure(.timetable, message: "架空の失敗"))
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.lessons.count, 2)
    }
}
