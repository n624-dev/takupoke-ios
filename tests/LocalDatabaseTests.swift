import Foundation
import XCTest
import GRDB
@testable import TakupokeParsing

final class LocalDatabaseTests: XCTestCase {
    private var root: URL!
    private let time = Date(timeIntervalSince1970: 2_000_000_000)
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private var legacy: URL { root.appendingPathComponent("legacy") }
    private var candidates: URL { root.appendingPathComponent("candidates") }

    private func fixture() throws -> MaterialLibraryState {
        let files = legacy.appendingPathComponent("files")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        var state = MaterialLibraryState()
        state.folder = SourceGrant(bookmark: Data([0, 1, 2]), name: "架空フォルダ", isFolder: true)
        for kind in MaterialKind.allCases {
            let bytes = Data("entirely synthetic \(kind.rawValue) bytes".utf8)
            let record = MaterialRecord(kind: kind,
                source: MaterialSource(grant: nil, childName: "架空資料", remoteURL: nil),
                originalName: "架空資料.\(kind.fileExtension)", storedName: "\(UUID().uuidString).\(kind.fileExtension)",
                byteCount: bytes.count, digest: "synthetic-\(kind.rawValue)", sourceModifiedAt: nil,
                acquiredAt: time, lastCheckedAt: time)
            try bytes.write(to: files.appendingPathComponent(record.storedName))
            state.records.append(record)
            state.attempts[kind.rawValue] = AcquisitionAttempt(date: time, failure: nil)
        }
        let lessons = ["架空科目A", "架空科目B"].map {
            PDFLesson(className: "架空組", weekday: 1, period: 1,
                names: TimetableLessonNames(subject: $0, teacher: "架空教員A", room: ""),
                sourceText: "架空原文", page: 1)
        }
        state.pdfAnalyses = [
            "timetable": PDFAnalysis(kind: .timetable, sourceDigest: "synthetic-timetable", sourceName: "架空資料.pdf",
                parsedAt: time, schoolYear: 2033, term: "前期", lessons: lessons, events: [], notices: []),
            "events": PDFAnalysis(version: 4, kind: .events, sourceDigest: "synthetic-events", sourceName: "架空行事.pdf",
                parsedAt: time, schoolYear: 2033, term: nil, lessons: [],
                events: [PDFSchoolEvent(date: "2033-04-11", scope: "共通", title: "架空行事A", page: 1)], notices: [])
        ]
        state.changeAnalysis = ChangeAnalysis(sourceDigest: "synthetic-changes", sourceName: "架空変更.xlsx",
            defaultYear: 2033, parsedAt: time, records: [ScheduleChange(change_date: "2033-04-11",
                class_name: "架空組", period: "1,2", before_subject: "架空科目A", after_subject: "架空科目C",
                teacher: "架空教員B", room: "架空室B", note: "架空備考", raw_text: "架空原文", canonical_text: "架空正規化文")])
        state.changeParseAttempt = ChangeParseAttempt(date: time, sourceDigest: "synthetic-changes",
            defaultYear: 2033, failure: ChangeParseError(code: .storage))
        state.pdfParseAttempts = ["timetable": PDFParseAttempt(date: time, sourceDigest: "synthetic-timetable", failure: nil)]
        try save(state)
        return state
    }

    private func save(_ state: MaterialLibraryState) throws {
        try LocalMaterialDatabase.encode(state).write(to: legacy.appendingPathComponent("library.json"), options: .atomic)
    }

    private func prepare() throws -> URL {
        try LegacyDatabaseMigration.prepare(legacyRoot: legacy, candidatesRoot: candidates)
    }

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
    private var runtime: URL { root.appendingPathComponent("runtime") }

    private func runtimeStore() throws -> (LocalMaterialDatabase, MaterialLibrary) {
        try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: false)
        let db = try LocalMaterialDatabase(url: runtime.appendingPathComponent("library.sqlite"), create: true)
        try db.initializeCurrentLibrary()
        return (db, try MaterialLibrary(root: runtime, persistence: db))
    }

    private func acquire(_ library: MaterialLibrary, kind: MaterialKind, suffix: String = "") throws {
        let staged = library.newStagingURL()
        let bytes = Data("entirely synthetic \(kind.rawValue) bytes \(suffix)".utf8)
        try bytes.write(to: staged)
        try library.commit(staged: staged, kind: kind,
            source: MaterialSource(grant: nil, childName: nil,
                                   remoteURL: kind == .events ? URL(string: "https://example.invalid/calendar.pdf") : nil),
            originalName: "架空資料.\(kind.fileExtension)", byteCount: bytes.count,
            digest: "synthetic-\(kind.rawValue)\(suffix)", modifiedAt: nil)
    }

    func testRuntimeRoundTripAndRecordReordering() throws {
        let example = try fixture()
        let (db, library) = try runtimeStore()
        defer { try? db.close() }
        try library.saveFolder(try XCTUnwrap(example.folder))
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
