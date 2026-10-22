import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

extension SpecialScheduleTests {
    func testMissingDatabaseOrTablesPreserveRetainedPDFCopies() throws {
        for missing in ["database", "specialSchedule", "specialSource"] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let bytes = Data("%PDF-fictional-preserved".utf8)
            let selected: URL
            do {
                let store = try SpecialScheduleStore(root: root)
                let staged = store.newStagingURL(); try bytes.write(to: staged)
                try store.saveSelection(staged: staged, kind: .exam, originalName: "fictional.pdf",
                    byteCount: bytes.count, digest: "fictional")
                selected = try XCTUnwrap(store.selectedURL(for: .exam))
            }
            let database = root.appendingPathComponent("specials.sqlite")
            if missing == "database" { try FileManager.default.removeItem(at: database) }
            else {
                let db = try DatabaseQueue(path: database.path)
                try db.write { try $0.execute(sql: "DROP TABLE \(missing)") }
            }
            XCTAssertThrowsError(try SpecialScheduleStore(root: root))
            XCTAssertEqual(try Data(contentsOf: selected), bytes)
            if missing == "database" { XCTAssertFalse(FileManager.default.fileExists(atPath: database.path)) }
        }
    }

    func testFreshStoreCollectsOrphansOnlyAfterValidMetadataAndUpgradesLegacyRecords() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-fictional-legacy".utf8)
        let selected: URL
        do {
            let store = try SpecialScheduleStore(root: root)
            XCTAssertTrue(store.sources.isEmpty); XCTAssertTrue(store.records.isEmpty)
            let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) }, kind: .exam,
                digest: "fictional", name: "fictional.pdf")
            let staged = store.newStagingURL(); try bytes.write(to: staged)
            try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
            selected = try XCTUnwrap(store.savedURL(for: .exam))
        }
        do {
            let db = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
            try db.write { try $0.execute(sql: "DROP TABLE specialSource") }
        }
        do {
            let legacy = try SpecialScheduleStore(root: root)
            XCTAssertEqual(legacy.selectedURL(for: .exam), selected)
            XCTAssertEqual(try Data(contentsOf: selected), bytes)
        }
        let orphan = root.appendingPathComponent("files").appendingPathComponent(UUID().uuidString + ".pdf")
        let staged = root.appendingPathComponent("staging").appendingPathComponent(UUID().uuidString)
        try bytes.write(to: orphan); try bytes.write(to: staged)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.selectedURL(for: .exam), selected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: selected), bytes)
    }

    func testIncompleteSpecialTimesDoNotReplacePreviousStoreResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let good = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                   kind: .exam, digest: "fictional",
                                                   name: "fictional.pdf")
        let staged = store.newStagingURL()
        let data = Data("%PDF-fictional".utf8)
        try data.write(to: staged)
        try store.save(staged: staged, analysis: good, originalName: "fictional.pdf",
                       byteCount: data.count, digest: "fictional")
        let oldURL = try XCTUnwrap(store.savedURL(for: .exam))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertThrowsError(try SpecialScheduleParser.parse(
            (1...6).map { examPage($0, omitLastTime: $0 == 3) },
            kind: .exam, digest: "different", name: "different.pdf"))
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.records[.exam]?.analysis, good)
        XCTAssertEqual(reopened.savedURL(for: .exam), oldURL)
    }

    func testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let previous = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "previous",
                                                       name: "fictional-old.pdf")
        let oldStaging = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: oldStaging)
        try store.save(staged: oldStaging, analysis: previous, originalName: "fictional-old.pdf",
                       byteCount: bytes.count, digest: "previous")
        let previousURL = try XCTUnwrap(store.savedURL(for: .exam))

        let selectedStaging = store.newStagingURL()
        try bytes.write(to: selectedStaging)
        try store.saveSelection(staged: selectedStaging, kind: .exam,
                                originalName: "fictional-new.pdf", byteCount: bytes.count,
                                digest: "current", grant: SourceGrant(bookmark: Data("fictional-bookmark".utf8),
                                                                      name: "fictional-new.pdf", isFolder: false))
        let failure = PDFParseError(code: .unsupported, stage: .characterMapping)
        try store.recordFailure(failure, kind: .exam)
        try store.recordAcquisitionFailure(kind: .exam)
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName, "fictional-new.pdf")
        XCTAssertEqual(reopened.sources[.exam]?.grant?.bookmark, Data("fictional-bookmark".utf8))
        XCTAssertEqual(reopened.sources[.exam]?.failure?.stage, .characterMapping)
        XCTAssertEqual(reopened.sources[.exam]?.recoveryJob?.state, .pending)
        XCTAssertNotNil(reopened.sources[.exam]?.acquisitionFailure)
        XCTAssertEqual(reopened.records[.exam]?.analysis, previous)
        XCTAssertNotEqual(reopened.selectedURL(for: .exam), previousURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: previousURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(reopened.selectedURL(for: .exam)).path))

        let current = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                      kind: .exam, digest: "current",
                                                      name: "fictional-new.pdf")
        try reopened.saveAnalysis(current)
        let final = try SpecialScheduleStore(root: root)
        XCTAssertEqual(final.records[.exam]?.analysis, current)
        XCTAssertNil(final.sources[.exam]?.failure)
        XCTAssertEqual(final.selectedURL(for: .exam), final.savedURL(for: .exam))
        XCTAssertFalse(FileManager.default.fileExists(atPath: previousURL.path))
    }

    func testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "fictional",
                                                       name: "fictional.pdf")
        let staged = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: staged)
        try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf",
                       byteCount: bytes.count, digest: "fictional")
        let source = try XCTUnwrap(store.sources[.exam])
        let selectedURL = try XCTUnwrap(store.selectedURL(for: .exam))
        let checkedAt = Date(timeIntervalSince1970: 2_000_000_000)
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        legacyJSON.removeValue(forKey: "lastCheckedAt")
        let legacySource = try JSONDecoder().decode(SpecialScheduleSource.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertNil(legacySource.lastCheckedAt)

        XCTAssertThrowsError(try store.recordSuccessfulCheck(.exam, digest: "different", checkedAt: checkedAt))
        XCTAssertEqual(store.sources[.exam]?.lastCheckedAt, source.lastCheckedAt)
        try store.recordSuccessfulCheck(.exam, digest: "fictional", checkedAt: checkedAt)

        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.lastCheckedAt, checkedAt)
        XCTAssertEqual(reopened.sources[.exam]?.acquiredAt, source.acquiredAt)
        XCTAssertEqual(reopened.selectedURL(for: .exam), selectedURL)
        XCTAssertEqual(reopened.records[.exam]?.analysis, analysis)
    }

    func testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = try SpecialScheduleStore(root:root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },kind:.exam,digest:"fictional",name:"fictional.pdf")
        let staged = store.newStagingURL(), bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to:staged)
        try store.save(staged:staged,analysis:analysis,originalName:"fictional.pdf",byteCount:bytes.count,digest:"fictional")
        try store.recordFailure(PDFParseError(code:.ambiguous),kind:.exam)
        let storedName = try XCTUnwrap(store.sources[.exam]?.storedName),job = store.sources[.exam]?.recoveryJob
        try store.recordSuccessfulCheck(.exam,digest:"fictional",originalName:"fictional-renamed.pdf")
        let reopened = try SpecialScheduleStore(root:root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName,"fictional-renamed.pdf")
        XCTAssertEqual(reopened.sources[.exam]?.storedName,storedName)
        XCTAssertEqual(reopened.sources[.exam]?.recoveryJob,job)
        XCTAssertEqual(reopened.sources[.exam]?.failure?.code,.ambiguous)
        XCTAssertEqual(reopened.records[.exam]?.analysis,analysis)
        XCTAssertEqual(reopened.records[.exam]?.originalName,"fictional.pdf")
    }
    func testPreviousVersionAnalysisStillProvidesSelectedSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let analysis = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                       kind: .exam, digest: "fictional",
                                                       name: "fictional.pdf")
        let staged = store.newStagingURL()
        let bytes = Data("%PDF-fictional".utf8)
        try bytes.write(to: staged)
        try store.save(staged: staged, analysis: analysis,
                       originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
        let db = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
        let current = try XCTUnwrap(store.records[.exam])
        var oldAnalysis = current.analysis
        oldAnalysis.version = 4
        let old = SpecialScheduleRecord(kind: current.kind, originalName: current.originalName,
                                        storedName: current.storedName, byteCount: current.byteCount,
                                        digest: current.digest, acquiredAt: current.acquiredAt,
                                        analysis: oldAnalysis)
        try db.write {
            try $0.execute(sql: "UPDATE specialSchedule SET payload = ? WHERE kind = 'exam'",
                           arguments: [JSONEncoder().encode(old)])
            try $0.execute(sql: "DELETE FROM specialSource")
        }

        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName, "fictional.pdf")
        XCTAssertEqual(reopened.selectedURL(for: .exam), reopened.savedURL(for: .exam))
        XCTAssertEqual(reopened.records[.exam]?.analysis.version, 4)
    }
    func testReturnClockDateAndLegacyRawTimesSurviveSqliteReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("%PDF-fictional-return".utf8)
        let analysis = try SpecialScheduleParser.parse([returnPageWithSplitCell(dateDays: [2,1,3,4,5])], kind: .examReturn, digest: "fictional", name: "fictional.pdf")
        do {
            let store = try SpecialScheduleStore(root: root)
            let staged = store.newStagingURL(); try bytes.write(to: staged)
            try store.save(staged: staged, analysis: analysis, originalName: "fictional.pdf", byteCount: bytes.count, digest: "fictional")
        }
        let reopened = try SpecialScheduleStore(root: root)
        let current = try XCTUnwrap(reopened.records[.examReturn])
        XCTAssertEqual(current.analysis.dedicatedTimeDate, "2026-04-02")
        XCTAssertEqual(current.analysis.periodTime(on: "2026-04-02", period: 5), "10:30〜11:10")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any])
        var saved = try XCTUnwrap(legacy["analysis"] as? [String: Any])
        saved.removeValue(forKey: "dedicatedTimeDate"); saved["version"] = 32
        var oldLessons = try XCTUnwrap(saved["lessons"] as? [[String: Any]])
        oldLessons[0].removeValue(forKey: "timeRange")
        saved["lessons"] = oldLessons
        legacy["analysis"] = saved
        let oldBytes = try JSONSerialization.data(withJSONObject: legacy)
        let queue = try DatabaseQueue(path: root.appendingPathComponent("specials.sqlite").path)
        try queue.write { try $0.execute(sql: "UPDATE specialSchedule SET payload=? WHERE kind='examReturn'", arguments: [oldBytes]) }
        let old = try SpecialScheduleStore(root: root)
        let retained = try XCTUnwrap(old.records[.examReturn]?.analysis)
        XCTAssertNil(retained.dedicatedTimeDate)
        XCTAssertNil(retained.periodTime(on: "2026-04-01", period: 5))
        XCTAssertNil(retained.periodTime(on: "2026-04-02", period: 5))
        let joined = try XCTUnwrap(retained.lessons.first { $0.date == "2026-04-02" && $0.period == 5 && $0.className == "1_1" })
        XCTAssertEqual(retained.timeRange(for: joined), "10:30〜11:50")
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(old.savedURL(for: .examReturn))), bytes)
        XCTAssertEqual(try queue.read { try Data.fetchOne($0, sql: "SELECT payload FROM specialSchedule WHERE kind='examReturn'") }, oldBytes)
    }

}
