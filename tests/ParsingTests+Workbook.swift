import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testTypedDateCellsUseTheirWrittenCalendarDateAndBomIsAccepted() throws {
        try temporary { root in
            for value in ["2032-07-10", "2032-07-10T00:00:00.000", "2032-07-10T23:59:59.123456789+14:00", "2032-07-10T00:00:00-12:00", "2032-07-10T01:02:03Z"] {
                let url = root.appendingPathComponent("fictional-typed-date-" + UUID().uuidString + ".xlsx")
                var files = workbook(example)
                let old = "<c r=\"C2\" t=\"inlineStr\"><is><t xml:space=\"preserve\">2032/7/10</t></is></c>"
                mutate(&files, "xl/worksheets/sheet1.xml", old, "<c r=\"C2\" t=\"d\"><v>\(value)</v></c>")
                for name in ["xl/workbook.xml", "xl/worksheets/sheet1.xml"] {
                    files[name] = Data([0xEF, 0xBB, 0xBF]) + files[name]!
                }
                try write(files, to: url)
                let result = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: 2032)
                XCTAssertEqual(result.first?.change_date, "2032-07-10")
                XCTAssertEqual(result.first?.before_subject, "架空科目A(架空教員A)")
            }
            for value in ["2032-07-10T24:00:00", "2032-07-10T01:60:00", "2032-07-10T01:00:60", "2032-02-30T00:00:00", "2032-07-10T01:00:00+14:01", "2032-07-10T01:00:00junk"] {
                let url = root.appendingPathComponent("fictional-invalid-date-" + UUID().uuidString + ".xlsx")
                var files = workbook(example)
                mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"C2\" t=\"inlineStr\"><is><t xml:space=\"preserve\">2032/7/10</t></is></c>", "<c r=\"C2\" t=\"d\"><v>\(value)</v></c>")
                try write(files, to: url)
                XCTAssertThrowsError(try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: 2032))
            }
        }
    }

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
    func testWorkbookChangeKindsRemainIndependentOfRemarksAndPersist() throws {
        try temporary { root in
            for shared in [false, true] {
                for kind in ["休講", "補講", "変更", ""] {
                    for remark in ["", "架空備考A", "休講"] {
                        let rows = [headers + ["備考"], ["1", "ZZ", "2032/4/5", "1", kind, "架空科目A", remark]]
                        let file = root.appendingPathComponent(UUID().uuidString + ".xlsx")
                        try write(workbook(rows, shared: shared), to: file)
                        let changes = try ChangeNormalizer.parse(XLSXReader.read(file), defaultYear: 2032)
                        let row = try XCTUnwrap(changes.first)
                        XCTAssertEqual(row.change_kind, kind)
                        XCTAssertEqual(row.note, remark.isEmpty ? kind : remark)
                        XCTAssertEqual(row.isCancellation, kind == "休講")
                        XCTAssertEqual(row.isMakeup, kind == "補講")
                        XCTAssertEqual(row.cardKindLabel, kind == "休講" || kind == "補講" ? kind : "変更")
                        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
                        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: changes)
                        let schedule = TimetableDaySchedule(timetable: nil, changes: analysis, events: nil, specials: [], includesChanges: true)
                        let block = try XCTUnwrap(schedule.blocks(on: day, className: "1_ZZ", international: false).first)
                        XCTAssertEqual(schedule.isInProgress(block, on: day, className: "1_ZZ", now: ISO8601DateFormatter().date(from: "2032-04-05T09:00:00+09:00")!), kind != "休講")
                        let dbRoot = root.appendingPathComponent(UUID().uuidString)
                        do {
                            let library = try LocalMaterialDatabase.openLibrary(root: dbRoot)
                            let bytes = try Data(contentsOf: file), staged = library.newStagingURL()
                            try bytes.write(to: staged)
                            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "fictional.xlsx", byteCount: bytes.count, digest: "fictional", modifiedAt: nil)
                            try library.saveChangeAnalysis(analysis)
                        }
                        XCTAssertEqual(try LocalMaterialDatabase.openLibrary(root: dbRoot).state.changeAnalysis?.records, changes)
                    }
                }
            }
            let rows = [headers + ["備考"], ["1", "ZZ", "2032/4/5", "1", "補講", "架空補講科目A", "架空備考A"],
                        ["1", "ZZ", "2032/4/5", "1", "休講", "架空休講科目B", "架空備考B"]]
            let file = root.appendingPathComponent("priority.xlsx")
            try write(workbook(rows), to: file)
            let changes = try ChangeNormalizer.parse(XLSXReader.read(file), defaultYear: 2032)
            XCTAssertEqual(TimetableSchedule.effectiveChange(changes)?.after_subject, "架空補講科目A")
            let legacy = ScheduleChange(change_date: "2032-04-05", class_name: "1_ZZ", period: "1", before_subject: "架空科目A", after_subject: "", teacher: "", room: "", note: "休講", raw_text: "", canonical_text: "")
            XCTAssertTrue(try JSONDecoder().decode(ScheduleChange.self, from: JSONEncoder().encode(legacy)).isCancellation)
        }
    }

    func testOoxmlEscapesDecodeOnceAcrossSharedInlineAndRichStrings() throws {
        try temporary { root in
            for form in ["inline", "shared", "rich"] {
                for (encoded, expected) in [("休講_x000D_", "休講"), ("補講_x000A_", "補講"), ("休講_x000D__x000A_", "休講")] {
                    let rows = [["学 年", "学科・クラス", "月日", "時限", "変更内容", "科目", "教員", "教室"],
                                ["1", "ZZ", "2032/4/5", "1", encoded, "架空科目_x0041_", "架空教員_x0042_", "架空室_x005F_x0043_"]]
                    var files = workbook(rows, shared: form != "inline")
                    if form == "shared" {
                        mutate(&files, "xl/sharedStrings.xml", "<si><r><t>", "<si><t>")
                        mutate(&files, "xl/sharedStrings.xml", "</t></r></si>", "</t></si>")
                    }
                    let file = root.appendingPathComponent(UUID().uuidString + ".xlsx")
                    try write(files, to: file)
                    let row = try XCTUnwrap(ChangeNormalizer.parse(XLSXReader.read(file), defaultYear: 2032).first)
                    XCTAssertEqual(row.change_kind, expected)
                    XCTAssertEqual(row.cardKindLabel, expected)
                    XCTAssertEqual(row.before_subject.isEmpty ? row.after_subject : row.before_subject, "架空科目A")
                    XCTAssertEqual(row.teacher, "架空教員B")
                    XCTAssertEqual(row.room, "架空室_x0043_")
                }
            }
            for (encoded, expected) in [("_x005F_x0041_", "_x0041_"), ("_x000Z_", "_x000Z_"), ("_X000D_", "_X000D_"), ("_xD83D__xDE00_", "😀")] {
                XCTAssertEqual(try XLSXReader.decodedString(encoded), expected)
            }
            XCTAssertThrowsError(try XLSXReader.decodedString("_xD800_"))
        }
    }

}
