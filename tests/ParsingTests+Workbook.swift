import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testUnsupportedAndMalformedWorkbooks() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            var files = workbook(example)
            mutate(&files, "xl/workbook.xml", "時間割変更", "架空別表")
            variants.append((files, .missingSheet))
            files = workbook(example)
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"1\"/><sheets>")
            variants.append((files, .dateSystem))
            files = workbook(example)
            mutate(&files, "xl/_rels/workbook.xml.rels", "Target=", "TargetMode=\"External\" Target=")
            variants.append((files, .unsupported))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"A2\"", "<c r=\"B2\"")
            variants.append((files, .invalidXML))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "</worksheet>", "<mergeCells><mergeCell ref=\"A2:B2\"/></mergeCells></worksheet>")
            variants.append((files, .mergedCells))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"A2\" t=\"inlineStr\"><is>", "<c r=\"A2\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            files = workbook(example, shared: true)
            mutate(&files, "xl/worksheets/sheet1.xml", "<v>0</v>", "<v>-1</v>")
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["xl/workbook.xml"] = Data("<!DOCTYPE workbook [<!ENTITY x SYSTEM 'https://example.invalid/never'>]><workbook>&x;</workbook>".utf8)
            variants.append((files, .unsupported))
            files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<sheetData>", "<sheetData/><sheetData>")
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["xl/workbook.xml"] = Data("<workbook>".utf8)
            variants.append((files, .invalidXML))
            files = workbook(example)
            files["../outside.xml"] = Data("架空".utf8)
            variants.append((files, .invalidArchive))
            files = workbook(example)
            files["xl/workbook.xml"] = Data(repeating: 32, count: XLSXReader.maximumXMLBytes + 1)
            variants.append((files, .limit))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("invalid-\(index).xlsx")
                try write(variant.0, to: url)
                assertCode(variant.1) { _ = try XLSXReader.read(url) }
            }
        }
    }
    func testSharedStringsExpansionLimit() throws {
        try temporary { root in
            var files = workbook(example, shared: true)
            files["xl/sharedStrings.xml"] = Data(("<sst xmlns=\"\(ns)\"><si><t>" + String(repeating: "A", count: 4096) + "</t></si></sst>").utf8)
            let rows = (1...4097).map { "<row r=\"\($0)\"><c r=\"A\($0)\" t=\"s\"><v>0</v></c></row>" }.joined()
            files["xl/worksheets/sheet1.xml"] = Data("<worksheet xmlns=\"\(ns)\"><sheetData>\(rows)</sheetData></worksheet>".utf8)
            let url = root.appendingPathComponent("repeated.xlsx")
            try write(files, to: url)
            assertCode(.limit) { _ = try XLSXReader.read(url) }
        }
    }

    func testCancellationAndCorruption() throws {
        try temporary { root in
            let url = root.appendingPathComponent("test.xlsx")
            try write(workbook(example), to: url, compression: .none)
            var calls = 0
            assertCode(.cancelled) {
                _ = try XLSXReader.read(url) {
                    calls += 1
                    if calls > 4 { throw ChangeParseError(code: .cancelled) }
                }
            }
            var bytes = try Data(contentsOf: url)
            // Alter a stored XML byte without changing the recorded CRC.
            let needle = Data("時間割変更".utf8)
            let range = bytes.range(of: needle)!
            bytes[range.lowerBound] ^= 1
            try bytes.write(to: url)
            assertCode(.invalidArchive) { _ = try XLSXReader.read(url) }
            try Data("not a workbook".utf8).write(to: url)
            assertCode(.invalidArchive) { _ = try XLSXReader.read(url) }
        }
    }
    func testRichTextNumericDatesAndSparseCells() throws {
        try temporary { root in
            var files = workbook(example)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"C2\" t=\"inlineStr\"><is><t xml:space=\"preserve\">2032/7/10</t></is></c>", "<c r=\"C2\"><v>46119</v></c>")
            mutate(&files, "xl/worksheets/sheet1.xml", "<t xml:space=\"preserve\">架空科目A(架空教員A)</t>", "<r><t>架空科目</t></r><r><t>A</t></r><rPh><t>架空読み</t></rPh>")
            let url = root.appendingPathComponent("rich.xlsx")
            try write(files, to: url)
            let records = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: nil)
            XCTAssertEqual(records[0].change_date, "2026-04-07")
            XCTAssertEqual(records[0].before_subject, "架空科目A")
        }
    }
}
