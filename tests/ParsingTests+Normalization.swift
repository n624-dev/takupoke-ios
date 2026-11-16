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
                        // The pinned reference predates the independent kind field.
                        // Keep every original field comparison; new kinds have XLSX regressions below.
                        let actual = try ChangeNormalizer.parse(rows, defaultYear: item.defaultYear).map { row in
                            var legacy = row; legacy.change_kind = nil; return legacy
                        }
                        XCTAssertEqual(actual, expected, item.id)
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
        for grade in ["", "0", "10", "架空学年", "AI-2", "1,", ",3", "1,,3", "1,2-4", "1,10", "1,1"] {
            assertCode(.year) { _ = try ChangeNormalizer.parse([headers, [grade, "ZZ", "2032/7/10"]], defaultYear: nil) }
        }
        assertCode(.classes) { _ = try ChangeNormalizer.parse([headers, ["1", "", "2032/7/10"]], defaultYear: nil) }
        assertCode(.limit) { _ = try ChangeNormalizer.parse(Array(repeating: [], count: 10_001), defaultYear: nil) }
        var rows = example
        rows[1][5] = String(repeating: "架空", count: 4097)
        assertCode(.limit) { _ = try ChangeNormalizer.parse(rows, defaultYear: nil) }
    }
}

extension ParsingTests {
    func testRowEditsRetainOriginalValuesAcrossSchoolFileUpdates() throws {
        let headers = ["学 年", "学科・クラス", "月日", "曜日", "教室", "備考"]
        let target = ["", "IT", "4/5", "不明", "架空教室A"]
        let other = ["4", "IT", "4/6", "", "架空教室B"]
        let old = ChangeEditTable(sheet: "架空", headers: headers, rows: [headers, target, other], headerRow: 1)
        var edits = old.suggestedEdits(defaultYear: 2032)
        XCTAssertTrue(edits[2]?.deriveWeekday == true)
        edits[2, default: ChangeRowEdit()].values = [0: "3", 4: "架空教室C"]
        let records = try old.records(edits: edits, defaultYear: 2032)
        XCTAssertEqual(records[0].class_name, "3_IT")
        XCTAssertEqual(records[0].room, "架空教室C")
        XCTAssertTrue(records[0].raw_text.contains("教室:架空教室A"))
        XCTAssertFalse(records[0].raw_text.contains("架空教室C"))
        let saved = try old.savedEdits(sourceIdentity: "source", digest: "one", defaultYear: 2032, edits: edits)
        let changed = ChangeEditTable(sheet: "架空", headers: headers,
            rows: [headers, ["5", "ES", "4/7"], other, [], target + [""]], headerRow: 1)
        let restored = changed.restore(saved, sourceIdentity: "source", digest: "two", defaultYear: 2032)
        XCTAssertEqual(restored.edits[5], edits[2])
        XCTAssertTrue(restored.conflicts.isEmpty)
        XCTAssertEqual(try changed.records(edits: restored.edits, defaultYear: 2032).last?.room, "架空教室C")
        var fixed = changed
        fixed.rows[4][0] = "4"
        XCTAssertNil(fixed.restore(saved, sourceIdentity: "source", digest: "three", defaultYear: 2032).edits[5])
        XCTAssertTrue(changed.restore(saved, sourceIdentity: "other", digest: "two", defaultYear: 2032).edits.isEmpty)
    }

    func testIdenticalOriginalRowsRequireUnambiguousCorrection() throws {
        let headers = ["学 年", "学科・クラス", "月日"]
        let value = ["2", "CN", "9/8"]
        let table = ChangeEditTable(sheet: "架空", headers: headers, rows: [headers, value, value], headerRow: 1)
        let skip = ChangeRowEdit(excluded: true)
        let partial = try table.savedEdits(sourceIdentity: "s", digest: "old", defaultYear: 2032, edits: [2: skip])
        XCTAssertEqual(table.restore(partial, sourceIdentity: "s", digest: "old", defaultYear: 2032).edits, [2: skip])
        var moved = table
        moved.rows.insert([], at: 1)
        let ambiguous = moved.restoreDetailed(partial, sourceIdentity: "s", digest: "new", defaultYear: 2032)
        XCTAssertTrue(ambiguous.edits.isEmpty)
        XCTAssertEqual(ambiguous.conflicts, [3, 4])
        XCTAssertEqual(ambiguous.unmatched.first?.row, 2)
        let all = try table.savedEdits(sourceIdentity: "s", digest: "old", defaultYear: 2032, edits: [2: skip, 3: skip])
        XCTAssertEqual(moved.restore(all, sourceIdentity: "s", digest: "new", defaultYear: 2032).edits, [3: skip, 4: skip])
    }

    func testCorrectionReviewIncludesMultipleFieldsAndEmptyFormulaRows() throws {
        let headers = ["学 年", "学科・クラス", "月日", "曜日", "教室"]
        let table = ChangeEditTable(sheet: "架空", headers: headers,
            rows: [headers, ["", "全", "2/30"], [], ["3", "IT", "8/1"]], headerRow: 1,
            cellIssues: [3: [4: .formula]], cellSources: [3: [4: "架空数式"]])
        let issues = try table.review(edits: [:], defaultYear: 2032)
        XCTAssertEqual(Set(issues[2]?.map(\.code) ?? []), [.year, .date])
        XCTAssertEqual(Set(issues[3]?.map(\.code) ?? []), [.formula, .year, .classes, .date])
        let edits = [2: ChangeRowEdit(values: [0: "3", 2: "8/1"], deriveWeekday: true),
                     3: ChangeRowEdit(excluded: true)]
        let fixed = try table.records(edits: edits, defaultYear: 2032)
        XCTAssertEqual(fixed.map(\.class_name), ["3_IT", "3_IT"])
        XCTAssertThrowsError(try table.records(edits: [2: edits[2]!, 3: edits[3]!, 4: ChangeRowEdit(excluded: true)], defaultYear: 2032))
        let old = ChangeEditTable(sheet: "架空", headers: headers, rows: [headers, ["3", "IT", "8/1", "月"], ["", "", "", "金"]], headerRow: 1)
        let weekday = ChangeNormalizer.weekday("2032-08-01")
        let migrated = old.legacyEdits(weekday: true, excluded: [3], defaultYear: 2032)
        XCTAssertEqual(migrated[2]?.deriveWeekday == true, weekday != "月")
        XCTAssertTrue(migrated[3]?.excluded == true)
    }
}

extension ParsingTests {
    func testEditorUsesRecognizedAliasesInsteadOfAddingShadowColumns() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "校時", "種別", "変更前 科目", "変更先", "担任", "場所", "メモ", "科目（担当教員）"]
            let row = ["2", "ZZ", "4/1", "3", "補講", "架空前", "架空後", "架空教員", "架空教室", "架空連絡", "架空科目"]
            let url = root.appendingPathComponent("aliases.xlsx")
            try write(workbook([header, row]), to: url)
            let view = try XLSXReader.editableWorkbook(url, layout: nil, check: {})
            XCTAssertEqual(view.table.headers, header)
            let record = try XCTUnwrap(view.table.records(edits: [2: .init(values: [3: "5", 8: "架空新教室"])], defaultYear: 2032).first)
            XCTAssertEqual(record.period, "5")
            XCTAssertEqual(record.room, "架空新教室")
            XCTAssertEqual(record.teacher, "架空教員")
        }
    }

    func testChangedFormulaWithSameCachedErrorDoesNotRestoreCorrection() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "備考"]
            func table(_ name: String, _ formula: String) throws -> ChangeEditTable {
                var files = workbook([header, ["2", "ZZ", "4/1", "架空備考"]])
                mutate(&files, "xl/worksheets/sheet1.xml",
                       #"<c r="D2" t="inlineStr"><is><t xml:space="preserve">架空備考</t></is></c>"#,
                       "<c r=\"D2\" t=\"e\"><f>" + formula + "</f><v>#VALUE!</v></c>")
                let url = root.appendingPathComponent(name + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            }
            let previous = try table("before", "A2+B2")
            let changed = try table("after", "A2-B2")
            let saved = try previous.savedEdits(sourceIdentity: "selection", digest: "before", defaultYear: 2032,
                                                edits: [2: ChangeRowEdit(values: [3: "架空訂正"])])
            XCTAssertEqual(previous.rows[1][3], "#VALUE!")
            XCTAssertEqual(previous.cellIssues[2]?[3], .cellType)
            XCTAssertNotEqual(previous.original(at: 2), changed.original(at: 2))
            XCTAssertTrue(changed.restore(saved, sourceIdentity: "selection", digest: "after", defaultYear: 2032).edits.isEmpty)
            XCTAssertEqual(previous.restore(saved, sourceIdentity: "selection", digest: "other", defaultYear: 2032).edits[2]?.values[3], "架空訂正")
        }
    }

    func testSharedFormulaFollowerMatchesOnlyAnUnchangedMaster() throws {
        try temporary { root in
            func table(_ name: String, master: String?) throws -> ChangeEditTable {
                let rows = [["学 年", "学科・クラス", "月日", "備考"], ["2", "ZZ", "4/1", "架空元"], ["2", "ZZ", "4/2", "架空下"]]
                var files = workbook(rows)
                for (row, literal) in [(2, "架空元"), (3, "架空下")] {
                    let formula = row == 2 ? master.map { "<f t=\"shared\" si=\"0\" ref=\"D2:D3\">" + $0 + "</f>" } ?? "" : #"<f t="shared" si="0"/>"#
                    mutate(&files, "xl/worksheets/sheet1.xml",
                           "<c r=\"D\(row)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">" + literal + "</t></is></c>",
                           "<c r=\"D\(row)\" t=\"e\">" + formula + "<v>#VALUE!</v></c>")
                }
                let url = root.appendingPathComponent(name + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            }
            let original = try table("old", master: "A2+B2")
            let changed = try table("changed", master: "A2-B2")
            let missing = try table("missing", master: nil)
            let edit = ChangeRowEdit(values: [3: "架空訂正"])
            for (before, after, shouldRestore) in [(original, original, true), (original, changed, false), (missing, missing, false)] {
                let saved = try before.savedEdits(sourceIdentity: "source", digest: "old", defaultYear: 2032, edits: [3: edit])
                let restored = after.restore(saved, sourceIdentity: "source", digest: "updated", defaultYear: 2032)
                XCTAssertEqual(restored.edits[3], shouldRestore ? edit : nil)
            }
        }
    }

    func testArrayFormulaIdentityAndTrailingFormattedBlanks() throws {
        try temporary { root in
            func table(_ name: String, expression: String) throws -> ChangeEditTable {
                var files = workbook([["学 年", "学科・クラス", "月日", "備考"], ["2", "ZZ", "4/1", "架空元"], ["2", "ZZ", "4/2", "架空下"]])
                let sheet = "xl/worksheets/sheet1.xml"
                mutate(&files, sheet, #"<c r="D2" t="inlineStr"><is><t xml:space="preserve">架空元</t></is></c>"#,
                       #"<c r="D2"><f t="array" ref="D2:D3">"# + expression + "</f><v>1</v></c>")
                mutate(&files, sheet, #"<c r="D3" t="inlineStr"><is><t xml:space="preserve">架空下</t></is></c>"#, #"<c r="D3"><v>2</v></c>"#)
                mutate(&files, sheet, "</sheetData>", #"<row r="4"><c r="A4" s="1"/></row></sheetData>"#)
                let url = root.appendingPathComponent(name + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            }
            let old = try table("old", expression: "A2:A3+1")
            let changed = try table("changed", expression: "A2:A3-1")
            XCTAssertEqual(old.rowIDs, [2, 3])
            XCTAssertNotEqual(old.original(at: 3), changed.original(at: 3))
            let edit = ChangeRowEdit(values: [3: "架空訂正"])
            let saved = try old.savedEdits(sourceIdentity: "source", digest: "old", defaultYear: 2032, edits: [3: edit])
            XCTAssertEqual(old.restore(saved, sourceIdentity: "source", digest: "updated", defaultYear: 2032).edits[3], edit)
            XCTAssertNil(changed.restore(saved, sourceIdentity: "source", digest: "updated", defaultYear: 2032).edits[3])
            XCTAssertEqual(try old.records(edits: [2: edit, 3: edit], defaultYear: 2032).count, 2)
        }
    }

    func testBlankDateKeepsPersonalCorrectionWhenOnlyFormattingChangesIn1904Workbook() throws {
        try temporary { root in
            func table(_ name: String, formatted: Bool) throws -> ChangeEditTable {
                var files = workbook([["学 年", "学科・クラス", "月日"], ["2", "ZZ", "架空仮値"]])
                mutate(&files, "xl/workbook.xml", "<sheets>", #"<workbookPr date1904="1"/><sheets>"#)
                mutate(&files, "xl/worksheets/sheet1.xml", #"<c r="C2" t="inlineStr"><is><t xml:space="preserve">架空仮値</t></is></c>"#,
                       formatted ? #"<c r="C2" s="1"/>"# : "")
                let url = root.appendingPathComponent(name + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            }
            let missing = try table("missing", formatted: false)
            let formatted = try table("formatted", formatted: true)
            let edit = ChangeRowEdit(values: [2: "2032/4/1"])
            let saved = try missing.savedEdits(sourceIdentity: "source", digest: "old", defaultYear: 2032, edits: [2: edit])
            XCTAssertEqual(missing.original(at: 2), formatted.original(at: 2))
            XCTAssertEqual(formatted.restore(saved, sourceIdentity: "source", digest: "new", defaultYear: 2032).edits[2], edit)
        }
    }

    func testEditorPreserves1904SerialAndConvertsOnlyTheMappedDate() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "時限", "曜日"]
            var files = workbook([header, ["1", "ZZ", "0", "2", "?"]])
            mutate(&files, "xl/workbook.xml", "<sheets>", "<workbookPr date1904=\"1\"/><sheets>")
            let sheet = "xl/worksheets/sheet1.xml"
            for (coordinate, number) in [("C2", 0), ("D2", 2)] {
                mutate(&files, sheet, "<c r=\"\(coordinate)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(number)</t></is></c>",
                       "<c r=\"\(coordinate)\"><v>\(number)</v></c>")
            }
            let url = root.appendingPathComponent("dates.xlsx")
            try write(files, to: url)
            var table = try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            let original = table.original(at: 2)
            XCTAssertEqual(original.values, ["1", "ZZ", "0", "2", "?"])
            XCTAssertEqual(table.values(at: 2, defaultYear: 2032)[2], "0")
            let edit = try XCTUnwrap(table.suggestedEdits(defaultYear: 2032)[2])
            let record = try XCTUnwrap(table.records(edits: [2: edit], defaultYear: 2032).first)
            XCTAssertEqual(record.change_date, "1904-01-01")
            XCTAssertEqual(record.period, "2")
            XCTAssertTrue(record.raw_text.contains("月日:0"))
            XCTAssertEqual(table.values(at: 2, edit: edit, defaultYear: 2032)[4], "金")
            table.headers.swapAt(2, 3)
            let remapped = try XCTUnwrap(table.records(edits: [2: edit], defaultYear: 2032).first)
            XCTAssertEqual(remapped.change_date, "1904-01-03")
            XCTAssertEqual(remapped.period, "0")
            XCTAssertEqual(table.original(at: 2), original)
        }
    }

    func testEmptyFirstSheetAllowsSelectingOtherSheet() throws {
        try temporary { root in
            var files = workbook(example)
            files["xl/worksheets/empty.xml"] = Data("<worksheet xmlns=\"\(ns)\"><sheetData/></worksheet>".utf8)
            mutate(&files, "xl/workbook.xml", "<sheets><sheet name=\"時間割変更\"", "<sheets><sheet name=\"空欄\" q:id=\"s0\"/><sheet name=\"架空変更\"")
            mutate(&files, "xl/_rels/workbook.xml.rels", "<Relationship Id=", "<Relationship Id=\"s0\" Type=\"\(rel)/worksheet\" Target=\"worksheets/empty.xml\"/><Relationship Id=")
            let url = root.appendingPathComponent("sheets.xlsx")
            try write(files, to: url)
            let empty = try XLSXReader.editableWorkbook(url, layout: nil, check: {})
            XCTAssertEqual(empty.sheets, ["空欄", "架空変更"])
            XCTAssertTrue(empty.requiresLayoutConfirmation)
            XCTAssertThrowsError(try empty.table.records(edits: [:], defaultYear: 2032))
            let selected = try XLSXReader.editableWorkbook(url, layout: nil, sheet: "架空変更", check: {})
            XCTAssertEqual(try selected.table.records(edits: [:], defaultYear: 2032).count, 1)
        }
    }

    func testTurningOffWeekdayCompletionSurvivesSameRowRefresh() throws {
        let header = ["学 年", "学科・クラス", "月日", "曜日"]
        let row = ["2", "ZZ", "4/1", ""]
        let old = ChangeEditTable(sheet: "時間割変更", headers: header, rows: [header, row], headerRow: 1)
        var edit = try XCTUnwrap(old.suggestedEdits(defaultYear: 2032)[2])
        edit.chooseDateDerivedWeekday(false)
        let saved = try old.savedEdits(sourceIdentity: "one", digest: "before", defaultYear: 2032, edits: [2: edit])
        let new = ChangeEditTable(sheet: old.sheet, headers: header, rows: [header, [], row], headerRow: 1)
        let restored = try XCTUnwrap(new.restore(saved, sourceIdentity: "one", digest: "after", defaultYear: 2032).edits[3])
        XCTAssertEqual(restored.keepPrintedWeekday, true)
        XCTAssertFalse(restored.deriveWeekday)
        XCTAssertEqual(new.values(at: 3, edit: restored, defaultYear: 2032)[3], "")
    }

    func testOpenEditorRejectsAnotherPersonalEditToSameDigest() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root)
            let staged = library.newStagingURL()
            try write(workbook(example), to: staged)
            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空.xlsx",
                byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: "same", modifiedAt: nil)
            let selection = try XCTUnwrap(library.state.record(for: .changes)?.source.selectionID)
            let first = try library.changeEditor(year: 2032)
            let second = try library.changeEditor(year: 2032)
            try library.saveChangeEditor(first, year: 2032, expectedIdentity: selection, expectedDigest: "same",
                edits: [2: .init(values: [3: "4"])], manual: true, check: {})
            assertCode(.staleConfirmation) {
                try library.saveChangeEditor(second, year: 2032, expectedIdentity: selection, expectedDigest: "same",
                    edits: [2: .init(values: [3: "5"])], manual: true, check: {})
            }
            XCTAssertEqual(library.state.changeAnalysis?.records.first?.period, "4")
            XCTAssertEqual(try library.changeEditor(year: 2032).edits[2]?.values[3], "4")
        }
    }
}

extension ParsingTests {
    func testPhysicalHeaderWidthAndHeaderEvidenceSurviveSourceRefresh() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日"]
            let sheet = "xl/worksheets/sheet1.xml"
            func inspect(_ name: String, rows: [[String]], old: ChangeColumnLayout? = nil,
                         modify: (inout [String: Data]) -> Void = { _ in }) throws -> ChangeWorkbookReview {
                var files = workbook(rows)
                modify(&files)
                let url = root.appendingPathComponent(name + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: old, check: {})
            }
            let rows = [header, ["2", "ZZ", "4/1"]]
            let old = try inspect("old", rows: rows)
            let edited = try old.table.savedEdits(sourceIdentity: "s", digest: "a", defaultYear: 2032,
                edits: [2: .init(values: [0: "3", 3: "2"])])
            let style = try inspect("style", rows: rows, old: old.layout) { files in
                mutate(&files, sheet, #"</row><row r="2">"#, #"<c r="D1" s="1"/></row><row r="2">"#)
            }
            XCTAssertFalse(style.requiresLayoutConfirmation)
            XCTAssertEqual(style.table.restore(edited, sourceIdentity: "s", digest: "b", defaultYear: 2032).edits[2]?.values[0], "3")
            var newColumn = try inspect("column", rows: rows + [["3", "ZZ", "4/2", "架空教室"]], old: old.layout)
            XCTAssertTrue(newColumn.requiresLayoutConfirmation)
            XCTAssertEqual(newColumn.table.headers[3], "列4")
            let shiftedPeriod = try XCTUnwrap(newColumn.table.headers.firstIndex(of: "時限"))
            let carried = newColumn.table.restore(edited, sourceIdentity: "s", digest: "c", defaultYear: 2032)
            XCTAssertEqual(carried.edits[2]?.values, [0: "3", shiftedPeriod: "2"])
            XCTAssertNil(carried.edits[3])
            let syntheticRoom = try XCTUnwrap(newColumn.table.headers.firstIndex(of: "教室"))
            newColumn.table.headers.swapAt(3, syntheticRoom)
            let record = try XCTUnwrap(newColumn.table.records(edits: [:], defaultYear: 2032).last)
            XCTAssertEqual(record.room, "架空教室")
            XCTAssertTrue(record.raw_text.contains("列4:架空教室"))
            let formula = try inspect("formula", rows: rows, old: old.layout) { files in
                mutate(&files, sheet, #"<c r="A1" t="inlineStr"><is><t xml:space="preserve">学 年</t></is></c>"#,
                       #"<c r="A1" t="str"><f>J1</f><v>学 年</v></c>"#)
            }
            XCTAssertTrue(formula.requiresLayoutConfirmation)
            XCTAssertTrue(formula.table.restore(edited, sourceIdentity: "s", digest: "c", defaultYear: 2032).edits.isEmpty)
        }
    }

    func testNumericPersonalDateIsInvalidatedByChangedEpoch() throws {
        let header = ["学 年", "学科・クラス", "月日"]
        var old = ChangeEditTable(sheet: "時間割変更", headers: header, rows: [header, ["2", "ZZ", ""]], headerRow: 1)
        old.uses1904 = true
        let edits = [2: ChangeRowEdit(values: [2: "45000"])]
        let saved = try old.savedEdits(sourceIdentity: "s", digest: "a", defaultYear: 2032, edits: edits)
        var new = old
        new.uses1904 = false
        XCTAssertNotEqual(try old.records(edits: edits, defaultYear: 2032).first?.change_date,
                          try new.records(edits: edits, defaultYear: 2032).first?.change_date)
        let result = new.restoreDetailed(saved, sourceIdentity: "s", digest: "b", defaultYear: 2032)
        XCTAssertTrue(result.edits.isEmpty)
        XCTAssertEqual(result.unmatched.first?.edit, edits[2])
    }

    func testMergedFollowersTrackSchoolAnchorIncludingImplicitLastRow() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日"]
            func table(_ grade: String) throws -> ChangeEditTable {
                var files = workbook([header, [grade, "ZZ", "4/1"], ["", "ZZ", "4/2"]])
                mutate(&files, "xl/worksheets/sheet1.xml", "</worksheet>",
                       #"<mergeCells><mergeCell ref="A2:A4"/></mergeCells></worksheet>"#)
                let url = root.appendingPathComponent(grade + ".xlsx")
                try write(files, to: url)
                return try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            }
            let old = try table("2"), new = try table("3")
            XCTAssertEqual(old.rowIDs, [2, 3, 4])
            let saved = try old.savedEdits(sourceIdentity: "s", digest: "a", defaultYear: 2032,
                edits: [3: .init(values: [0: "2"])])
            XCTAssertNil(new.restore(saved, sourceIdentity: "s", digest: "b", defaultYear: 2032).edits[3])
        }
    }

    func testReviewValidatesWeekdayAliasUniquenessAndMigratesMatchingCachedFormula() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "曜日"]
            let day = try XCTUnwrap(ChangeNormalizer.weekday("2032-04-01"))
            var files = workbook([header, ["2", "ZZ", "4/1", day], ["", "", "", "金"]])
            mutate(&files, "xl/worksheets/sheet1.xml",
                "<c r=\"D2\" t=\"inlineStr\"><is><t xml:space=\"preserve\">" + day + "</t></is></c>",
                "<c r=\"D2\" t=\"str\"><f>A1</f><v>" + day + "</v></c>")
            let url = root.appendingPathComponent("weekdays.xlsx")
            try write(files, to: url)
            let original = try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            let skip = original.legacyEdits(weekday: false, excluded: [3], defaultYear: 2032)
            XCTAssertNil(skip[2])
            XCTAssertNil(original.suggestedEdits(defaultYear: 2032)[2])
            XCTAssertEqual(try original.records(edits: skip, defaultYear: 2032).first?.class_name, "2_ZZ")
            var duplicate = original
            duplicate.headers.append("曜")
            assertCode(.headers) { _ = try duplicate.records(edits: skip, defaultYear: 2032) }
        }
    }
}

extension ParsingTests {
    func testGroupedWorkbookCorrectionsUseOnlySelectedRowsAndKeepRawEvidence() throws {
        try temporary { root in
            let header = ["学 年", "学科・クラス", "月日", "曜日", "備考"]
            var files = workbook([header, ["１，３", "ZZ", "46343", "?"], ["1,2", "ZZ", "46344", "?"],
                ["", "ZZ", "7/12", "月"], ["", "ZZ", "7/10", "土"], ["", "", "", "土"],
                ["", "", "", "土"], ["", "", "", "土"], ["", "", "", "土", "架空数式"]])
            let xml = "xl/worksheets/sheet1.xml"
            for row in [7,8] {
                mutate(&files, xml, "<c r=\"D\(row)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">土</t></is></c>",
                    "<c r=\"D\(row)\" t=\"str\"><f>FAKE()</f><v>土</v></c>")
            }
            mutate(&files, xml, "<c r=\"E9\" t=\"inlineStr\"><is><t xml:space=\"preserve\">架空数式</t></is></c>", "<c r=\"E9\"><f>FAKE()</f></c>")
            let url = root.appendingPathComponent("架空一括.xlsx")
            try write(files, to: url)
            let table = try XLSXReader.editableWorkbook(url, layout: nil, check: {}).table
            var edits: [Int: ChangeRowEdit] = [:]
            let review = try table.review(edits: edits, defaultYear: 2032)
            let groups = ChangeIssueGroup.groups(review, table: table)
            XCTAssertEqual(groups.filter { $0.code == .weekdayOnly }.map(\.rows), [[6], [7, 8]])
            XCTAssertEqual(review[7]?.map(\.code), [.weekdayOnly])
            XCTAssertEqual(Set(review[9]?.map(\.code) ?? []), [.formula, .date, .year, .classes])
            let weekdays = try XCTUnwrap(groups.first { $0.code == .weekdayMismatch })
            XCTAssertEqual(weekdays.rows, [2,3])
            weekdays.apply(.weekday, selecting: [2,3,6], headers: table.headers, edits: &edits)
            XCTAssertNil(edits[6])
            let grades = try XCTUnwrap(groups.first { $0.code == .year })
            grades.apply(.value("2"), selecting: [4], headers: table.headers, edits: &edits)
            XCTAssertNil(edits[5])
            XCTAssertEqual(try table.review(edits: edits, defaultYear: 2032)[5]?.map(\.code), [.year])
            grades.apply(.value("3"), selecting: [5], headers: table.headers, edits: &edits)
            for group in groups where group.code == .weekdayOnly {
                group.apply(.exclude, selecting: Set(group.rows), headers: table.headers, edits: &edits)
            }
            edits[9] = ChangeRowEdit(excluded: true)
            let savedGroups = ChangeIssueGroup.savedGroups(edits)
            let exclusions = try XCTUnwrap(savedGroups.first { $0.saved == .excluded })
            XCTAssertEqual(exclusions.rows, [6,7,8,9])
            var undone = edits
            exclusions.apply(.undo, selecting: [7, 42], headers: table.headers, edits: &undone)
            XCTAssertEqual(try table.review(edits: undone, defaultYear: 2032)[7]?.map(\.code), [.weekdayOnly])
            XCTAssertEqual(undone[8]?.excluded, true)
            XCTAssertNil(undone[42])
            XCTAssertEqual(savedGroups.first { $0.saved == .derived }?.rows, [2,3])
            let values = try table.records(edits: edits, defaultYear: 2032)
            XCTAssertEqual(values.map(\.class_name), ["1_ZZ","3_ZZ","1_ZZ","2_ZZ","2_ZZ","3_ZZ"])
            for (row, record) in [(2, values[0]), (3, values[2])] {
                XCTAssertEqual(table.values(at: row, edit: edits[row]!, defaultYear: 2032)[3], ChangeNormalizer.weekday(record.change_date))
                XCTAssertTrue(table.summary(row: row, edit: edits[row]!, year: 2032).contains("月日 " + record.change_date))
            }
            XCTAssertTrue(values[0].raw_text.contains("月日:46343"))
            var moved = table
            moved.rows.swapAt(3, 4)
            let saved = try table.savedEdits(sourceIdentity: "s", digest: "old", defaultYear: 2032, edits: edits)
            XCTAssertEqual(moved.restore(saved, sourceIdentity: "s", digest: "new", defaultYear: 2032).edits[5], edits[4])
            var damaged = table
            damaged.cellIssues[2] = [3: .mergedCells]
            damaged.cellIssues[3] = [2: .formula]
            let blocked = try damaged.review(edits: edits, defaultYear: 2032)
            XCTAssertEqual(blocked[2]?.first?.code, .mergedCells)
            XCTAssertTrue(blocked[3]?.contains(where: { $0.column == 2 && $0.code == .formula }) == true)
            XCTAssertNil(damaged.suggestedEdits(defaultYear: 2032)[2])
            XCTAssertNil(damaged.suggestedEdits(defaultYear: 2032)[3])
        }
    }
}
