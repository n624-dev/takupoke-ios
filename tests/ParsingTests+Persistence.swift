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

extension ParsingTests {
    func testSameBytesFromDifferentSelectionDoNotCertifyPersonalResult() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root)
            let archive = root.appendingPathComponent("copy.xlsx")
            try write(workbook([headers, ["", "ZZ", "2032/4/1", "2"]]), to: archive)
            let bytes = try Data(contentsOf: archive)
            func select(_ name: String) throws {
                let staged = library.newStagingURL()
                try bytes.write(to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(),
                    originalName: name, byteCount: bytes.count, digest: "identical", modifiedAt: nil)
            }
            try select("one.xlsx")
            let first = try XCTUnwrap(library.state.record(for: .changes))
            let view = try library.changeEditor(year: 2032)
            try library.saveChangeEditor(view, year: 2032, expectedIdentity: try XCTUnwrap(first.source.selectionID),
                expectedDigest: first.digest, edits: [2: .init(values: [0: "2"])], manual: true, check: {})
            let analysis = try XCTUnwrap(library.state.changeAnalysis)
            XCTAssertTrue(analysis.matches(record: try XCTUnwrap(library.state.record(for: .changes)), defaultYear: 2032))
            try library.recordParseFailure(.init(code: .year, row: 2), defaultYear: 2032)
            XCTAssertNotNil(library.state.changeParseAttempt?.failure)
            try select("two.xlsx")
            XCTAssertNil(try MaterialLibrary(root: root).state.changeParseAttempt)
            let second = try XCTUnwrap(library.state.record(for: .changes))
            XCTAssertNotEqual(first.source.selectionID, second.source.selectionID)
            assertCode(.year) { try library.reanalyzeChanges(defaultYear: 2032) }
            XCTAssertEqual(library.state.changeAnalysis?.records.first?.class_name, "2_ZZ")
            XCTAssertFalse(analysis.matches(record: second, defaultYear: 2032))
            XCTAssertTrue(ChangeParseAttempt.needsAnalysis(digest: second.digest, defaultYear: 2032,
                analysis: analysis, attempt: nil, personalSourceIdentity: second.personalChangeIdentity(for: 2032)))
        }
    }
}

extension ParsingTests {
    func testUnresolvedDuplicateDecisionsBelongToChosenSheet() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root)
            let item = ["2", "ZZ", "4/1", "2"]
            var files = workbook([headers, item, item])
            files["xl/worksheets/other.xml"] = workbook([headers, item])["xl/worksheets/sheet1.xml"]
            mutate(&files, "xl/workbook.xml", "</sheets>",
                #"<sheet name="架空別表" q:id="s2"/></sheets>"#)
            mutate(&files, "xl/_rels/workbook.xml.rels", "</Relationships>",
                "<Relationship Id=\"s2\" Type=\"" + rel + "/worksheet\" Target=\"worksheets/other.xml\"/></Relationships>")
            func load(_ digest: String, reuse: Bool) throws {
                let staged = library.newStagingURL()
                try write(files, to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空.xlsx",
                    byteCount: try XCTUnwrap(staged.resourceValues(forKeys: [.fileSizeKey]).fileSize),
                    digest: digest, modifiedAt: nil, reuseUnchanged: reuse)
            }
            try load("one", reuse: false)
            let id = try XCTUnwrap(library.state.record(for: .changes)?.source.selectionID)
            let first = try library.changeEditor(year: 2032)
            try library.saveChangeEditor(first, year: 2032, expectedIdentity: id, expectedDigest: "one",
                edits: [2: .init(excluded: true)], manual: true, check: {})
            mutate(&files, "xl/worksheets/sheet1.xml", "</sheetData>", #"<row r="4"/></sheetData>"#)
            try load("two", reuse: true)
            let conflicted = try library.changeEditor(year: 2032)
            XCTAssertEqual(conflicted.conflicts, [2, 3])
            try library.reconcileChangeEdits(conflicted, year: 2032)
            XCTAssertEqual(try library.changeEditor(year: 2032).conflicts, [2, 3])
            var other = try library.changeEditor(year: 2032, sheet: "架空別表")
            XCTAssertTrue(other.conflicts.isEmpty)
            XCTAssertTrue(other.requiresLayoutConfirmation)
            other.requiresLayoutConfirmation = false
            try library.saveChangeEditor(other, year: 2032, expectedIdentity: id, expectedDigest: "two",
                edits: [:], manual: true, check: {})
            XCTAssertEqual(library.state.changeAnalysis?.records.count, 1)
        }
    }
}
