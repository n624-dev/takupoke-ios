import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testPersistenceFailureAndNewSourceKeepLastGoodResult() throws {
        try temporary { root in
            var fail = false
            let library = try MaterialLibrary(root: root) { data, url in
                if fail { throw ChangeParseError(code: .storage) }
                try data.write(to: url, options: .atomic)
            }
            func acquire(_ digest: String) throws {
                let staged = library.newStagingURL()
                try Data("PK synthetic".utf8).write(to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                                   byteCount: 12, digest: digest, modifiedAt: nil)
            }
            try acquire("source-a")
            let records = try ChangeNormalizer.parse(example, defaultYear: nil)
            let good = ChangeAnalysis(sourceDigest: "source-a", sourceName: "架空資料.xlsx", defaultYear: nil, parsedAt: Date(), records: records)
            try library.saveChangeAnalysis(good)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.records, records)
            try acquire("source-b")
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            try library.recordParseFailure(ChangeParseError(code: .date, row: 2), defaultYear: 2032)
            XCTAssertEqual(library.state.changeAnalysis?.records, records)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeParseAttempt?.failure?.code, .date)
            fail = true
            var next = good
            next.sourceDigest = "source-b"
            XCTAssertThrowsError(try library.saveChangeAnalysis(next))
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "source-a")
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-a")
            fail = false
            try library.saveChangeAnalysis(next)
            XCTAssertNil(library.state.changeParseAttempt?.failure)
            XCTAssertEqual(try MaterialLibrary(root: root).state.changeAnalysis?.sourceDigest, "source-b")
            var legacy = library.state
            legacy.changeAnalysis?.version = 1
            legacy.changeParseAttempt?.failure = ChangeParseError(code: .unsupported, row: 3)
            try JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("library.json"), options: .atomic)
            let reopened = try MaterialLibrary(root: root)
            XCTAssertEqual(reopened.state.changeAnalysis?.version, 1)
            XCTAssertEqual(reopened.state.changeAnalysis?.records, records)
            XCTAssertEqual(reopened.state.changeParseAttempt?.failure?.code, .unsupported)
        }
    }
    func testInvalidYearCannotReplaceAcceptedSqliteDatesAndFreshnessUsesYearAndConsents() throws {
        try temporary { root in
            let rows = [headers, ["1", "ZZ", "7/10", "1", "補講", "架空科目A"], ["1", "ZZ", "1/10", "2", "休講", "架空科目B"]]
            let file = root.appendingPathComponent("fictional.xlsx")
            try write(workbook(rows), to: file)
            let table = try XLSXReader.read(file)
            do {
            let library = try LocalMaterialDatabase.openLibrary(root: root.appendingPathComponent("db"))
            let staged = library.newStagingURL(), bytes = try Data(contentsOf: file)
            try bytes.write(to: staged)
            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "fictional.xlsx", byteCount: bytes.count, digest: "fictional", modifiedAt: nil)
            let records = try ChangeNormalizer.parse(table, defaultYear: 2032)
            let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: records)
            try library.saveChangeAnalysis(analysis)
            for invalid in [203, 1899, 9999] {
                assertCode(.defaultYear) { try library.reanalyzeChanges(defaultYear: invalid) }
                XCTAssertEqual(library.state.changeAnalysis?.records.map(\.change_date), ["2032-07-10", "2033-01-10"])
            }
            let source = try XCTUnwrap(library.state.record(for: .changes))
            XCTAssertTrue(analysis.matches(record: source, defaultYear: 2032))
            XCTAssertFalse(analysis.matches(record: source, defaultYear: 2033))
            XCTAssertFalse(analysis.matches(record: source, defaultYear: nil))
            var changed = source; changed.digest = "other"
            XCTAssertFalse(analysis.matches(record: changed, defaultYear: 2032))
            changed = source; changed.source.weekdayConsent = ChangeWeekdayConsent(digest: source.digest, defaultYear: 2032, parserVersion: ChangeAnalysis.parserVersion)
            XCTAssertFalse(analysis.matches(record: changed, defaultYear: 2032))
            var stale = analysis; stale.version -= 1
            XCTAssertFalse(stale.matches(record: source, defaultYear: 2032))
            }
            XCTAssertEqual(try LocalMaterialDatabase.openLibrary(root: root.appendingPathComponent("db")).state.changeAnalysis?.records.map(\.change_date), ["2032-07-10", "2033-01-10"])
        }
    }


    func testPersonalCorrectionSurvivesInsertedRowsAndYieldsToSchoolCorrection() throws {
        try temporary { root in
            let directory = root.appendingPathComponent("personal")
            let library = try MaterialLibrary(root: directory)
            let blank = ["", "IT", "2032/7/10", "3", "変更", "架空科目A"]
            let other = ["2", "CN", "2032/7/11", "2", "変更", "架空科目B"]
            func acquire(_ rows: [[String]], _ digest: String, reuse: Bool) throws {
                let staged = library.newStagingURL()
                try write(workbook([headers] + rows), to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                    byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: digest,
                    modifiedAt: nil, reuseUnchanged: reuse)
            }
            try acquire([blank], "a", reuse: false)
            let id = try XCTUnwrap(library.state.record(for: .changes)?.source.selectionID)
            var view = try library.changeEditor(year: 2032)
            XCTAssertEqual(try view.table.review(edits: [:], defaultYear: 2032)[2]?.first?.code, .year)
            try library.saveChangeEditor(view, year: 2032, expectedIdentity: id, expectedDigest: "a",
                edits: [2: ChangeRowEdit(values: [0:"3"])], manual: true, check: {})
            try acquire([other, blank], "b", reuse: true)
            assertCode(.staleConfirmation) {
                try library.saveChangeEditor(view, year: 2032, expectedIdentity: id, expectedDigest: "a", edits: [:], manual: true, check: {})
            }
            view = try library.changeEditor(year: 2032)
            XCTAssertEqual(view.edits[3]?.values[0], "3")
            try library.saveChangeEditor(view, year: 2032, expectedIdentity: id, expectedDigest: "b", edits: view.edits, manual: false, check: {})
            let reopened = try MaterialLibrary(root: directory)
            XCTAssertEqual(reopened.state.changeAnalysis?.records.map(\.class_name), ["2_CN", "3_IT"])
            XCTAssertEqual(try reopened.changeEditor(year: 2032).edits[3]?.values[0], "3")
            var official = blank
            official[0] = "2"
            try acquire([other, official], "c", reuse: true)
            view = try library.changeEditor(year: 2032)
            XCTAssertTrue(view.edits.isEmpty)
            XCTAssertEqual(view.previous.count, 1)
            try library.saveChangeEditor(view, year: 2032, expectedIdentity: id, expectedDigest: "c", edits: [:], manual: false, check: {})
            XCTAssertEqual(library.state.changeAnalysis?.records.last?.class_name, "2_IT")
            try acquire([blank], "d", reuse: true)
            XCTAssertTrue(try library.changeEditor(year: 2032).edits.isEmpty)
        }
    }
}
