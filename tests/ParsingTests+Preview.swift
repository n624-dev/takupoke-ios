import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func weekdayWorkbook(date: String = "2032/7/10", cached: String? = "土") -> [String: Data] {
        let rows = [["架空の確認表"], [], [],
                    ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
                    ["1", "ZZ", date, "架空置換欄", "1", "休講", "架空科目A(架空教員A)"]]
        var files = workbook(rows)
        let path = "xl/worksheets/sheet1.xml"
        mutate(&files, path, "<row r=\"3\"></row>", "<row r=\"3\"><c r=\"G3\"><f>TODAY()</f><v>48000</v></c></row>")
        let formula = "<f>TEXT(架空表[[#This Row],[月日]], &quot;aaa&quot;)</f>"
        let value = cached.map { "<v>\(escape($0))</v>" } ?? ""
        mutate(&files, path, "<c r=\"D5\" t=\"inlineStr\"><is><t xml:space=\"preserve\">架空置換欄</t></is></c>",
               "<c r=\"D5\" t=\"str\">\(formula)\(value)</c>")
        mutate(&files, path, "</worksheet>", "<mergeCells><mergeCell ref=\"A1:G1\"/></mergeCells></worksheet>")
        return files
    }

    func testMetadataAndValidatedWeekdayFormulas() throws {
        try temporary { root in
            for (index, value) in ["土", "土曜", "土曜日", "（土）"].enumerated() {
                let url = root.appendingPathComponent("weekday-\(index).xlsx")
                try write(weekdayWorkbook(cached: value), to: url)
                let rows = try XLSXReader.read(url)
                XCTAssertEqual(rows[2][6], "") // Metadata formula is outside the table.
                let result = try ChangeNormalizer.parse(rows, defaultYear: nil)
                XCTAssertEqual(result.count, 1)
                XCTAssertEqual(result[0].before_subject, "架空科目A(架空教員A)")
                XCTAssertTrue(result[0].raw_text.contains("曜日:" + ChangeNormalizer.text(value)))
            }
            let url = root.appendingPathComponent("yearless.xlsx")
            try write(weekdayWorkbook(date: "7/10"), to: url)
            assertCode(.date) { _ = try XLSXReader.read(url) }
            XCTAssertEqual(try ChangeNormalizer.parse(XLSXReader.read(url, defaultYear: 2032), defaultYear: 2032).count, 1)
        }
    }

    func testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula() throws {
        try temporary { root in
            for (index, pair) in [(nil, ChangeParseError.Code.formulaCache), ("日", .weekdayMismatch), ("架空文字", .weekdayMismatch)].enumerated() {
                let url = root.appendingPathComponent("bad-weekday-\(index).xlsx")
                try write(weekdayWorkbook(cached: pair.0), to: url)
                assertCode(pair.1) { _ = try XLSXReader.read(url) }
            }
            var files = weekdayWorkbook()
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"G5\" t=\"inlineStr\"><is>",
                   "<c r=\"G5\" t=\"inlineStr\"><f>1+1</f><is>")
            let url = root.appendingPathComponent("major-formula.xlsx")
            try write(files, to: url)
            assertCode(.formula) { _ = try XLSXReader.read(url) }
        }
    }

    func testWarningPreviewKeepsSuccessAndFailureUnchanged() throws {
        try temporary { root in
            for (index, cached) in [nil, "金"].enumerated() {
                let directory = root.appendingPathComponent("library-\(index)")
                let library = try MaterialLibrary(root: directory)
                func acquire(_ files: [String: Data], digest: String) throws {
                    let staged = library.newStagingURL()
                    try write(files, to: staged)
                    let count = try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!
                    try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                                       byteCount: count, digest: digest, modifiedAt: nil)
                }
                try acquire(weekdayWorkbook(), digest: "good")
                let good = ChangeAnalysis(sourceDigest: "good", sourceName: "架空資料.xlsx", defaultYear: nil,
                    parsedAt: Date(), records: try ChangeNormalizer.parse(example, defaultYear: nil))
                try library.saveChangeAnalysis(good)
                try acquire(weekdayWorkbook(date: "7/10", cached: cached), digest: "warning")
                assertCode(.unsupported) { _ = try library.previewChanges() } // No failed weekday check yet.
                do {
                    _ = try XLSXReader.read(library.localURL(for: .changes)!, defaultYear: 2032)
                    XCTFail("Strict parsing must reject a weekday warning")
                } catch let failure as ChangeParseError {
                    XCTAssertTrue(failure.permitsPreview)
                    try library.recordParseFailure(failure, defaultYear: 2032)
                }
                let manifest = directory.appendingPathComponent("library.json")
                let previousBytes = try Data(contentsOf: manifest)
                let preview = try library.previewChanges()
                XCTAssertEqual(preview.defaultYear, 2032)
                XCTAssertEqual(preview.records.count, 1)
                XCTAssertEqual(preview.records[0].change_date, "2032-07-10")
                XCTAssertEqual(preview.records[0].before_subject, "架空科目A(架空教員A)")
                XCTAssertEqual(preview.warnings, [ChangeParseError(code: cached == nil ? .formulaCache : .weekdayMismatch, row: 5)])
                XCTAssertEqual(try Data(contentsOf: manifest), previousBytes)
                let reopened = try MaterialLibrary(root: directory)
                XCTAssertEqual(reopened.state.changeAnalysis?.records, good.records)
                XCTAssertEqual(reopened.state.changeAnalysis?.sourceDigest, "good")
                XCTAssertTrue(reopened.state.changeParseAttempt?.failure?.permitsPreview == true)
                assertCode(.cancelled) { _ = try library.previewChanges { throw ChangeParseError(code: .cancelled) } }
                XCTAssertEqual(try Data(contentsOf: manifest), previousBytes)
                try acquire(weekdayWorkbook(cached: cached), digest: "another-source")
                assertCode(.unsupported) { _ = try library.previewChanges() } // A new source needs a new check.
            }
        }
    }

    func testPreviewDoesNotBypassOtherErrors() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            variants.append((weekdayWorkbook(date: "2032/2/30", cached: nil), .date))
            var files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"G5\" t=\"inlineStr\"><is>",
                   "<c r=\"G5\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/worksheets/sheet1.xml", "A1:G1", "A5:B5")
            variants.append((files, .mergedCells))
            files = weekdayWorkbook(cached: "金")
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"1\"/><sheets>")
            variants.append((files, .dateSystem))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("blocked-preview-\(index).xlsx")
                try write(variant.0, to: url)
                assertCode(variant.1) { _ = try XLSXReader.readForPreview(url) }
                XCTAssertFalse(ChangeParseError(code: variant.1).permitsPreview)
            }
        }
    }
}
