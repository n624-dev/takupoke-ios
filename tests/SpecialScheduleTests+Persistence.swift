import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

extension SpecialScheduleTests {
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
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.sources[.exam]?.originalName, "fictional-new.pdf")
        XCTAssertEqual(reopened.sources[.exam]?.grant?.bookmark, Data("fictional-bookmark".utf8))
        XCTAssertEqual(reopened.sources[.exam]?.failure?.stage, .characterMapping)
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
}
