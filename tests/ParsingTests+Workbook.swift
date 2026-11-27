import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    func testWorkbookVerificationUsesFrozenEditsAndHonorsCancellationDuringReview() throws {
        let headers = ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目"]
        let rows = [headers] + (0..<1_200).map { index in
            ["3", "IT", "2032/4/5", "月", "1", "休講", "架空科目\(index)"]
        }
        let table = ChangeEditTable(sheet: "架空", headers: headers, rows: rows, headerRow: 1)
        let layout = ChangeColumnLayout(sheet: "架空", headerRow: 1, original: headers, headers: headers)
        let review = ChangeWorkbookReview(sheets: ["架空"], table: table, layout: layout, requiresLayoutConfirmation: false)
        let original = try ChangeWorkbookVerification.evaluate(review, edits: [:], year: 2032, check: {})
        XCTAssertTrue(original.viable)
        let edited = [2: ChangeRowEdit(values: [2: "架空の不正日付"])]
        let invalid = try ChangeWorkbookVerification.evaluate(review, edits: edited, year: 2032, check: {})
        XCTAssertFalse(invalid.viable)
        XCTAssertNotNil(invalid.issues[2])
        XCTAssertTrue(original.issues.isEmpty)
        var checks = 0
        XCTAssertThrowsError(try ChangeWorkbookVerification.evaluate(review, edits: [:], year: 2032, check: {
            checks += 1
            if checks >= 60 { throw CancellationError() }
        })) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testFormulaRangeCannotSupplyUnverifiedChangeCells() throws {
        try temporary { root in
            let rows = [["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目"],
                        ["3", "IT", "2032/4/5", "月", "1", "休講", "架空科目A"]]
            let sheet = "xl/worksheets/sheet1.xml"
            let original = #"<c r="D2" t="inlineStr"><is><t xml:space="preserve">月</t></is></c>"#
            for kind in ["array", "dataTable"] {
                var files = workbook(rows)
                mutate(&files, sheet, original,
                       #"<c r="D2" t="str"><f t=""# + kind + #"" ref="D2:G2">A2</f><v>月</v></c>"#)
                let url = root.appendingPathComponent(kind + ".xlsx")
                try write(files, to: url)
                assertCode(.formula) { _ = try XLSXReader.read(url, defaultYear: 2032) }
                let editor = try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
                for column in 4...6 { XCTAssertEqual(editor.cellIssues[2]?[column], .formula) }
                mutate(&files, sheet, #" ref="D2:G2""#, "")
                let missing = root.appendingPathComponent(kind + "-missing-range.xlsx")
                try write(files, to: missing)
                assertCode(.invalidXML) { _ = try XLSXReader.read(missing, defaultYear: 2032) }
            }
            var direct = workbook(rows)
            mutate(&direct, sheet, original, #"<c r="D2" t="str"><f>A2</f><v>月</v></c>"#)
            let safe = root.appendingPathComponent("direct-weekday.xlsx")
            try write(direct, to: safe)
            XCTAssertEqual(try XLSXReader.read(safe, defaultYear: 2032).count, 2)
            var saved = ChangeAnalysis(sourceDigest:"fictional",sourceName:"fictional.xlsx",defaultYear:2032,parsedAt:Date(),records:[])
            saved.version = 13
            XCTAssertTrue(ChangeParseAttempt.needsAnalysis(digest:saved.sourceDigest,defaultYear:2032,analysis:saved,attempt:nil))
        }
    }

    func testFormulaRangeStartingBeforeHeaderStillMarksAffectedTableCells() throws {
        try temporary { root in
            let rows = [["", "", "", "", "架空計算"],
                        ["学 年", "学科・クラス", "月日", "曜日", "時限", "科目"],
                        ["3", "IT", "2032/4/5", "月", "1", "架空科目A"]]
            let sheet = "xl/worksheets/sheet1.xml"
            let original = #"<c r="E1" t="inlineStr"><is><t xml:space="preserve">架空計算</t></is></c>"#
            for (range, rejects) in [("E1:E3", true), ("E1:E6", true), ("E1:E1", false)] {
                var files = workbook(rows)
                mutate(&files, sheet, original, #"<c r="E1"><f t="array" ref=""# + range + #"">A1</f><v>0</v></c>"#)
                let url = root.appendingPathComponent("range-\(range.replacingOccurrences(of: ":", with: "-")).xlsx")
                try write(files, to: url)
                if rejects { assertCode(.formula) { _ = try XLSXReader.read(url, defaultYear: 2032) } }
                else { XCTAssertEqual(try XLSXReader.read(url, defaultYear: 2032).count, 3) }
            }
        }
    }

    func testLeadingZeroGradesFromWorkbookProduceSelectableCanonicalClasses() throws {
        try temporary { root in
            for grade in ["1", "01", "001", "００１", "1.0", "01.0", "０１．０"] {
                let rows = [["学 年", "学科・クラス", "月日", "時限", "変更後"],
                            [grade, "CN", "2032/7/10", "1", "架空科目A"],
                            ["1", "全", "2032/7/11", "2", "架空科目B"]]
                let url = root.appendingPathComponent("fictional-grade-" + UUID().uuidString + ".xlsx")
                try write(workbook(rows), to: url)
                let changes = try ChangeNormalizer.parse(XLSXReader.read(url), defaultYear: 2032)
                XCTAssertEqual(changes.map(\.class_name), ["1_CN", "1_CN"], grade)
            }
            XCTAssertEqual(try ChangeNormalizer.years("01～03"), ["1", "2", "3"])
            XCTAssertEqual(try ChangeNormalizer.years("03～01"), ["3", "2", "1"])
        }
    }

    func testOnlyExplicitWholeWorkbookExclusionCanBeSavedAsZeroChanges() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "時限", "変更内容", "科目"]
            let libraryRoot = root.appendingPathComponent("fictional-library", isDirectory: true)
            let library = try MaterialLibrary(root: libraryRoot)
            let original = library.newStagingURL()
            try write(workbook([header, ["3", "IT", "2032/7/10", "1", "休講", "架空科目"]]), to: original)
            let size = try XCTUnwrap(original.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            try library.commit(staged: original, kind: .changes, source: MaterialSource(), originalName: "fictional.xlsx",
                byteCount: size, digest: "fictional-one-change", modifiedAt: nil)
            try library.reanalyzeChanges(defaultYear: 2032)
            let before = try LocalMaterialDatabase.encode(library.state)
            XCTAssertEqual(library.state.changeAnalysis?.records.count, 1)
            let record = try XCTUnwrap(library.state.record(for: .changes))
            let review = try library.changeEditor(year: 2032)
            let identity = record.source.selectionID ?? record.storedName
            let excluded = [2: ChangeRowEdit(excluded: true)]
            let verified = try ChangeWorkbookVerification.evaluate(review, edits: excluded, year: 2032, check: {})
            XCTAssertTrue(verified.viable)
            XCTAssertEqual(verified.recordCount, 0)
            assertCode(.staleConfirmation) {
                try library.saveChangeEditor(review, year: 2032, expectedIdentity: identity,
                    expectedDigest: record.digest, edits: excluded, manual: false, check: {})
            }
            XCTAssertEqual(try LocalMaterialDatabase.encode(library.state), before)
            try library.saveChangeEditor(review, year: 2032, expectedIdentity: identity,
                expectedDigest: record.digest, edits: excluded, manual: true, check: {})
            let reopened = try MaterialLibrary(root: libraryRoot)
            let accepted = try XCTUnwrap(reopened.state.changeAnalysis)
            XCTAssertTrue(accepted.records.isEmpty)
            XCTAssertEqual(accepted.excludedSourceRowCount, 1)
            var unproved = reopened.state
            unproved.changeAnalysis?.excludedSourceRowCount = nil
            XCTAssertThrowsError(try MaterialLibrary.decodeLegacyManifest(LocalMaterialDatabase.encode(unproved)))
            XCTAssertTrue(accepted.matches(record: try XCTUnwrap(reopened.state.record(for: .changes)), defaultYear: 2032))
            XCTAssertEqual(try reopened.changeEditor(year: 2032).edits, excluded)
            let headerOnly = root.appendingPathComponent("fictional-no-rows.xlsx")
            try write(workbook([header]), to: headerOnly)
            assertCode(.empty) {
                _ = try ChangeNormalizer.parse(XLSXReader.read(headerOnly, defaultYear: 2032), defaultYear: 2032)
            }
            let headerReview = try XLSXReader.editableWorkbook(headerOnly, layout: nil, check: {})
            assertCode(.empty) { _ = try headerReview.table.records(edits: excluded, defaultYear: 2032) }
        }
    }

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
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"2\"/><sheets>")
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

extension ParsingTests {
    func testUnconfirmedTimestampKeepsOriginalAndDoesNotBlockLessonInEitherReadPath() throws {
        let header = ["学 年", "学科・クラス", "月日", "変更後", "更新日時"]
        let cases = [("n", "46343"), ("d", "2026-02-30"), ("e", "#VALUE!")]
        try temporary { root in
            let url = root.appendingPathComponent("fictional-optional-date.xlsx")
            var files = workbook([header] + cases.map { _ in ["2", "ES", "2026/11/17", "架空科目A", "架空日時"] })
            for (offset, cell) in cases.enumerated() {
                let ref = "E\(offset + 2)"
                mutate(&files, "xl/worksheets/sheet1.xml",
                       "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">架空日時</t></is></c>",
                       "<c r=\"\(ref)\" t=\"\(cell.0)\"><v>\(cell.1)</v></c>")
            }
            try write(files, to: url)
            let preview = try XLSXReader.readForPreview(url, defaultYear: 2026)
            let table = try XCTUnwrap(preview.workbook)
            let accepted = try preview.acceptedRows(defaultYear: 2026)
            let strict = try ChangeNormalizer.parse(accepted, defaultYear: 2026, sourceRows: table.rows, workbook: table)
            let editor = try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            let edited = try editor.records(edits: [:], defaultYear: 2026)
            for records in [strict, edited] {
                XCTAssertEqual(records.map(\.sourceRow), [2, 3, 4])
                for (record, cell) in zip(records, cases) {
                    XCTAssertNil(record.updated)
                    XCTAssertEqual(record.after_subject, "架空科目A")
                    XCTAssertTrue(record.originalForDisplay.contains("更新日時:" + cell.1))
                }
            }
        }
    }
}
