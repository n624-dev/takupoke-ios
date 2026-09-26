import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testReferenceFixturesThroughCompressedXLSX() throws {
        let url = Bundle.module.url(forResource: "normalization", withExtension: "json", subdirectory: "fixtures")!
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        try temporary { root in
            for item in fixtures.cases {
                for shared in [false, true] {
                    let url = root.appendingPathComponent(item.id + (shared ? "-shared" : "-inline") + ".xlsx")
                    try write(workbook(item.sheetRows, shared: shared), to: url)
                    let rows = try XLSXReader.read(url)
                    if item.iosDisposition == "compare" {
                        let expected = item.expectedRecords.map { reference in
                            guard let alias = item.iosClassAliases?[reference.class_name] else { return reference }
                            var adjusted = reference
                            let prefix = reference.change_date + " | " + reference.class_name
                            XCTAssertTrue(reference.canonical_text.hasPrefix(prefix + " | "))
                            adjusted.class_name = alias
                            adjusted.canonical_text = reference.change_date + " | " + alias + reference.canonical_text.dropFirst(prefix.count)
                            return adjusted
                        }
                        XCTAssertEqual(try ChangeNormalizer.parse(rows, defaultYear: item.defaultYear), expected, item.id)
                    } else {
                        assertCode(item.id == "all-without-known-classes" ? .unknownAll : .date) {
                            _ = try ChangeNormalizer.parse(rows, defaultYear: item.defaultYear)
                        }
                    }
                }
            }
        }
    }
    func testAIClassAliasesThroughXLSXKeepRowsAndSourceText() throws {
        let rows = [["学 年", "学科・クラス", "月日", "科目"],
                    ["1", "AI", "2032/7/10", "架空科目A"],
                    ["AI", "1", "2032/7/11", "架空科目B"],
                    ["2", "AI", "2032/7/12", "架空科目C"],
                    ["AI", "2", "2032/7/13", "架空科目D"],
                    ["1～2", "ZZ,AI", "2032/7/14", "架空科目E"],
                    ["AI", "2,1", "2032/7/15", "架空科目F"],
                    ["1", "全", "2032/7/16", "架空科目G"]]
        try temporary { root in
            for shared in [false, true] {
                let url = root.appendingPathComponent("aliases-\(shared).xlsx")
                try write(workbook(rows, shared: shared), to: url)
                let records = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: nil)
                XCTAssertEqual(records.map(\.class_name), ["AI_1", "AI_1", "AI_2", "AI_2", "1_ZZ", "AI_1", "2_ZZ", "AI_2", "AI_2", "AI_1", "1_ZZ"])
                XCTAssertEqual(records[0].raw_text, "学 年:1 | 学科・クラス:AI | 月日:2032/7/10 | 科目:架空科目A")
                XCTAssertEqual(records[1].raw_text, "学 年:AI | 学科・クラス:1 | 月日:2032/7/11 | 科目:架空科目B")
                XCTAssertEqual(records[0].canonical_text, "2032-07-10 | AI_1 | 架空科目A | 学 年:1 | 学科・クラス:AI | 月日:2032/7/10 | 科目:架空科目A")
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_1" }.count, 4)
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_2" }.count, 4)
                XCTAssertEqual(try ChangeNormalizer.parse([rows[0], rows[1], rows[1]], defaultYear: nil).count, 2)
            }
        }
        for year in 1...9 {
            XCTAssertEqual(ChangeNormalizer.canonicalClassName("\(year)_AI"), "AI_\(year)")
            XCTAssertEqual(ChangeNormalizer.canonicalClassName("AI_\(year)"), "AI_\(year)")
        }
        for name in ["1_ZZ", "2_YY", "AI_ZZ", "1_AIX", "0_AI", "10_AI", "ZZ_AI", "1_AI_ZZ"] {
            XCTAssertEqual(ChangeNormalizer.canonicalClassName(name), name)
        }
    }

    func testLegacyAIClassDisplayDoesNotRewriteSavedResults() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root)
            let staged = library.newStagingURL()
            try Data("PK synthetic".utf8).write(to: staged)
            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                               byteCount: 12, digest: "source-a", modifiedAt: nil)
            let old = ScheduleChange(change_date: "2032-07-10", class_name: "1_AI", period: "1",
                before_subject: "架空科目A", after_subject: "", teacher: "架空教員A", room: "", note: "",
                raw_text: "学 年:1 | 学科・クラス:AI", canonical_text: "2032-07-10 | 1_AI | 1 | 架空科目A | 架空教員A | 学 年:1 | 学科・クラス:AI")
            var other = old
            other.class_name = "AI_1"
            other.raw_text = "学 年:AI | 学科・クラス:1"
            other.canonical_text = "2032-07-10 | AI_1 | 1 | 架空科目A | 架空教員A | 学 年:AI | 学科・クラス:1"
            let manifest = root.appendingPathComponent("library.json")
            for version in [1, 2] {
                var legacy = library.state
                legacy.changeAnalysis = ChangeAnalysis(version: version, sourceDigest: "source-a", sourceName: "架空資料.xlsx",
                    defaultYear: nil, parsedAt: Date(), records: [old, other])
                legacy.changeParseAttempt = ChangeParseAttempt(date: Date(), sourceDigest: "source-a", defaultYear: nil,
                                                               failure: ChangeParseError(code: .weekdayMismatch, row: 5))
                let original = try JSONEncoder().encode(legacy)
                try original.write(to: manifest, options: .atomic)
                let reloaded = try MaterialLibrary(root: root)
                let records = try XCTUnwrap(reloaded.state.changeAnalysis?.records)
                XCTAssertEqual(records, [old, other])
                XCTAssertEqual(Set(records.map(\.displayClassName)), ["AI_1"])
                XCTAssertEqual(records.filter { $0.displayClassName == "AI_1" }.count, 2)
                XCTAssertEqual(reloaded.state.changeAnalysis?.version, version)
                XCTAssertEqual(reloaded.state.changeParseAttempt?.failure?.code, .weekdayMismatch)
                XCTAssertEqual(try Data(contentsOf: manifest), original)
            }
        }
    }

    func testDatesAndExplicitYear() throws {
        XCTAssertEqual(try ChangeNormalizer.date("2032年2月29日", defaultYear: nil), "2032-02-29")
        XCTAssertEqual(try ChangeNormalizer.date("1/2", defaultYear: 2033), "2034-01-02")
        XCTAssertEqual(try ChangeNormalizer.date("4/1", defaultYear: 2033), "2033-04-01")
        XCTAssertEqual(try ChangeNormalizer.date("2033/1/2", defaultYear: 2033), "2033-01-02")
        XCTAssertEqual(try ChangeNormalizer.date("46119.75", defaultYear: nil), "2026-04-07")
        for value in ["2031/2/29", "2032/13/1", "2032/0/1", "2032/4/31", "7/10", "99999999999999999999", "0"] {
            assertCode(.date) { _ = try ChangeNormalizer.date(value, defaultYear: nil) }
        }
    }
    func testTableFailuresAndBounds() throws {
        assertCode(.headers) { _ = try ChangeNormalizer.parse([["架空見出し"]], defaultYear: nil) }
        assertCode(.headers) { _ = try ChangeNormalizer.parse([headers + ["月日"], example[1]], defaultYear: nil) }
        assertCode(.empty) { _ = try ChangeNormalizer.parse([headers], defaultYear: nil) }
        assertCode(.year) { _ = try ChangeNormalizer.parse([headers, ["1～99999", "ZZ", "2032/7/10"]], defaultYear: nil) }
        for grade in ["", "0", "10", "架空学年", "AI-2", "1,2"] {
            assertCode(.year) { _ = try ChangeNormalizer.parse([headers, [grade, "ZZ", "2032/7/10"]], defaultYear: nil) }
        }
        assertCode(.classes) { _ = try ChangeNormalizer.parse([headers, ["1", "", "2032/7/10"]], defaultYear: nil) }
        assertCode(.limit) { _ = try ChangeNormalizer.parse(Array(repeating: [], count: 10_001), defaultYear: nil) }
        var rows = example
        rows[1][5] = String(repeating: "架空", count: 4097)
        assertCode(.limit) { _ = try ChangeNormalizer.parse(rows, defaultYear: nil) }
    }
}
