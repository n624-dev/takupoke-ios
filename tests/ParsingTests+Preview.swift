import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    var skipRowsFixture: [[String]] {
        [["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
         ["1", "ZZ", "2032/7/10", "土", "1", "休講", "架空科目A(架空教員A)"],
         ["1", "ZZ", "2032/7/11", "月", "2", "補講", "架空科目B(架空教員B)"],
         ["", "", "", "火"],
         ["1", "ZZ", "2032/7/12", "月", "3", "補講", "架空科目C(架空教員C)"]]
    }

    func testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow() throws {
        try temporary { root in
            for shared in [false, true] {
                let url = root.appendingPathComponent("skip-\(shared).xlsx")
                var rows = skipRowsFixture; rows[2][0] = "1～2"; rows[2][1] = "ZZ,YY"
                try write(workbook(rows, shared: shared), to: url)
                assertCode(.weekdayMismatch) { _ = try XLSXReader.read(url, defaultYear: 2032) }
                let preview = try XLSXReader.readForPreview(url, defaultYear: 2032)
                XCTAssertEqual(preview.reviewRows.map(\.id), [3, 4])
                XCTAssertEqual(preview.warnings.map(\.code), [.weekdayMismatch, .weekdayOnly])
                XCTAssertEqual(preview.reviewRows[0].fields.first?.value, "1～2")
                assertCode(.weekdayOnly) { _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [3]) }
                assertCode(.weekdayMismatch) { _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [4]) }
                for excluded: Set<Int> in [[1, 3, 4], [2, 3, 4], [3, 4, 99]] {
                    assertCode(.unsupported) { _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: excluded) }
                }
                let filtered = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4])
                XCTAssertEqual(filtered.count, 5); XCTAssertEqual(filtered[2], []); XCTAssertEqual(filtered[3], [])
                let changes = try ChangeNormalizer.parse(filtered, defaultYear: 2032)
                XCTAssertEqual(changes.map(\.change_date), ["2032-07-10", "2032-07-12"])
                XCTAssertEqual(changes.map(\.period), ["1", "3"])
                XCTAssertEqual(changes.map(\.after_subject), ["", "架空科目C(架空教員C)"])
            }
        }
    }

    func testExcludedClassCannotBecomeEvidenceForRemainingAllRow() throws {
        try temporary { root in
            let url = root.appendingPathComponent("all-classes.xlsx")
            var rows = skipRowsFixture; rows[1][1] = "YY"; rows[4][1] = "全"
            try write(workbook(rows), to: url)
            let changes = try ChangeNormalizer.parse(XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032)
            XCTAssertEqual(changes.map(\.class_name), ["1_YY", "1_YY"])
            let missing = root.appendingPathComponent("all-without-evidence.xlsx")
            rows[1] = []; try write(workbook(rows), to: missing)
            assertCode(.unknownAll) {
                _ = try ChangeNormalizer.parse(XLSXReader.read(missing, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032)
            }
        }
    }

    func testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped() throws {
        try temporary { root in
            for cached in [nil, "火", ""] as [String?] {
                var files = workbook(skipRowsFixture)
                let formula = "<c r=\"D4\" t=\"str\"><f>TEXT(A4,&quot;aaa&quot;)</f>" + (cached.map { "<v>\($0)</v>" } ?? "") + "</c>"
                mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"D4\" t=\"inlineStr\"><is><t xml:space=\"preserve\">火</t></is></c>", formula)
                let url = root.appendingPathComponent("formula-\(UUID().uuidString).xlsx")
                try write(files, to: url)
                let table = try XLSXReader.readForPreview(url, defaultYear: 2032)
                XCTAssertEqual(table.warnings.last?.code, .weekdayOnly)
                assertCode(.weekdayOnly) { _ = try XLSXReader.read(url, defaultYear: 2032, dateDerivedWeekdays: true) }
                XCTAssertEqual(try ChangeNormalizer.parse(XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032).count, 2)
            }
        }
    }

    func testRowSkipsCannotHideDateClassFormulaOrStructuralErrors() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            for (column, value, code) in [(2, "2032/2/30", ChangeParseError.Code.date), (0, "", .year), (1, "", .classes)] {
                var rows = skipRowsFixture; rows[2][column] = value
                variants.append((workbook(rows), code))
            }
            var rows = skipRowsFixture; rows[3].append(contentsOf: ["", "", "", "見出し外の架空値"])
            variants.append((workbook(rows), .headers))
            var files = workbook(skipRowsFixture)
            mutate(&files, "xl/worksheets/sheet1.xml", "</worksheet>", "<mergeCells><mergeCell ref=\"A3:B3\"/></mergeCells></worksheet>")
            variants.append((files, .mergedCells))
            files = workbook(skipRowsFixture)
            mutate(&files, "xl/worksheets/sheet1.xml", "<c r=\"E3\" t=\"inlineStr\"><is>", "<c r=\"E3\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            // A normal populated row with a missing weekday cache stays outside this feature.
            files = weekdayWorkbook(cached: nil); variants.append((files, .unsupported))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("blocked-\(index).xlsx"); try write(variant.0, to: url)
                assertCode(variant.1) { _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: variant.1 == .unsupported ? [5] : [3, 4]) }
            }
        }
    }

    func testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root.appendingPathComponent("library"))
            func acquire(_ digest: String, reuse: Bool = true) throws {
                let staged = library.newStagingURL(); try write(workbook(skipRowsFixture), to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "完全架空変更.xlsx",
                    byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: digest, modifiedAt: nil, reuseUnchanged: reuse)
            }
            try acquire("first")
            try library.recordParseFailure(ChangeParseError(code: .weekdayMismatch, row: 3), defaultYear: 2032)
            let preview = try library.previewChanges()
            try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032)
            let consent = try XCTUnwrap(library.state.record(for: .changes)?.source.rowSkipConsent)
            XCTAssertEqual(library.state.changeAnalysis?.rowSkipConsent, consent)
            XCTAssertEqual(library.state.changeAnalysis?.records.count, 2)
            XCTAssertFalse(ChangeParseAttempt.needsAnalysis(digest: "first", defaultYear: 2032, analysis: library.state.changeAnalysis,
                attempt: library.state.changeParseAttempt, rowSkipConsent: consent))
            XCTAssertTrue(ChangeParseAttempt.needsAnalysis(digest: "first", defaultYear: 2033, analysis: library.state.changeAnalysis,
                attempt: library.state.changeParseAttempt, rowSkipConsent: consent))
            XCTAssertFalse(consent.matches(sourceIdentity: consent.sourceIdentity, digest: "first", defaultYear: 2033))
            var old = consent; old.parserVersion -= 1
            XCTAssertFalse(old.matches(sourceIdentity: consent.sourceIdentity, digest: "first", defaultYear: 2032))
            try acquire("first")
            let reopened = try MaterialLibrary(root: root.appendingPathComponent("library"))
            XCTAssertEqual(reopened.state.record(for: .changes)?.source.rowSkipConsent, consent)
            try acquire("second"); XCTAssertNil(library.state.record(for: .changes)?.source.rowSkipConsent)
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032) }
            try acquire("first"); XCTAssertNil(library.state.record(for: .changes)?.source.rowSkipConsent)
            XCTAssertEqual(library.state.changeAnalysis?.rowSkipConsent, consent) // Last successful result is kept.
            try acquire("first", reuse: false)
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032) }
        }
    }

    func testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root.appendingPathComponent("library"))
            let staged = library.newStagingURL(); try write(workbook(skipRowsFixture), to: staged)
            try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "完全架空変更.xlsx",
                byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: "first", modifiedAt: nil)
            try library.recordParseFailure(ChangeParseError(code: .weekdayMismatch, row: 3), defaultYear: 2032)
            let preview = try library.previewChanges()
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let before = try encoder.encode(library.state)
            var changed = preview; changed.reviewRows[0].fields[0].value = "架空の別値"
            assertCode(.cancelled) { try library.applyRowSkips(changed, rows: [3, 4], defaultYear: 2032) }
            changed = preview; changed.parserVersion -= 1
            assertCode(.cancelled) { try library.applyRowSkips(changed, rows: [3, 4], defaultYear: 2032) }
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2033) }
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032, check: { throw ChangeParseError(code: .cancelled) }) }
            XCTAssertEqual(try encoder.encode(library.state), before)
            let only = root.appendingPathComponent("only.xlsx")
            try write(workbook([skipRowsFixture[0], ["", "", "", "火"]]), to: only)
            assertCode(.weekdayOnly) { _ = try XLSXReader.read(only, defaultYear: 2032) }
            assertCode(.empty) { _ = try ChangeNormalizer.parse(XLSXReader.read(only, defaultYear: 2032, skippingRows: [2]), defaultYear: 2032) }
        }
    }

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

    func testLiteralWeekdayNeedsExplicitCorrectionAndKeepsOriginalText() throws {
        try temporary { root in
            for (index, printed) in ["日", "（日）", "架空曜日"].enumerated() {
                let url = root.appendingPathComponent("literal-\(index).xlsx")
                let rows = [["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
                            ["1", "ZZ", "2032/7/10", printed, "1", "休講", "架空科目A(架空教員A)"]]
                try write(workbook(rows), to: url)
                assertCode(.weekdayMismatch) { _ = try XLSXReader.read(url) }
                let warning = try XCTUnwrap(XLSXReader.readForPreview(url).warnings.first)
                XCTAssertEqual(warning.canCorrectWeekday, printed != "架空曜日")
                if warning.canCorrectWeekday {
                    let changes = try ChangeNormalizer.parse(XLSXReader.read(url, dateDerivedWeekdays: true), defaultYear: nil)
                    XCTAssertEqual(changes.first?.change_date, "2032-07-10")
                    XCTAssertTrue(changes.first?.raw_text.contains(ChangeNormalizer.text(printed)) == true)
                } else { assertCode(.weekdayMismatch) { _ = try XLSXReader.read(url, dateDerivedWeekdays: true) } }
            }
            let url = root.appendingPathComponent("no-cache.xlsx")
            try write(weekdayWorkbook(cached: nil), to: url)
            assertCode(.formulaCache) { _ = try XLSXReader.read(url, dateDerivedWeekdays: true) }
        }
    }
    func testWeekdayConsentIsAtomicAndLimitedToSelectedContent() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root.appendingPathComponent("consent-library"))
            func acquire(_ digest: String, reuse: Bool) throws {
                let staged = library.newStagingURL(); try write(weekdayWorkbook(cached: "日"), to: staged)
                try library.commit(staged: staged, kind: .changes, source: MaterialSource(), originalName: "架空資料.xlsx",
                    byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: digest, modifiedAt: nil, reuseUnchanged: reuse)
            }
            try acquire("first", reuse: false)
            let consent = ChangeWeekdayConsent(digest: "first", defaultYear: 2032, parserVersion: ChangeAnalysis.parserVersion)
            var analysis = ChangeAnalysis(sourceDigest: "first", sourceName: "架空資料.xlsx", defaultYear: 2032, parsedAt: Date(), records: try ChangeNormalizer.parse(example, defaultYear: nil))
            analysis.weekdayConsent = consent
            assertCode(.storage) { try library.saveChangeAnalysis(analysis) }
            XCTAssertNil(library.state.record(for: .changes)?.source.weekdayConsent)
            try library.saveChangeAnalysis(analysis, authorizeWeekdayCorrection: true)
            let selection = library.state.record(for: .changes)?.source.selectionID
            try acquire("first", reuse: true)
            XCTAssertEqual(library.state.record(for: .changes)?.source.weekdayConsent, consent)
            XCTAssertEqual(library.state.record(for: .changes)?.source.selectionID, selection)
            let reopened = try MaterialLibrary(root: root.appendingPathComponent("consent-library"))
            XCTAssertEqual(reopened.state.record(for: .changes)?.source.weekdayConsent, consent)
            try acquire("second", reuse: true); XCTAssertNil(library.state.record(for: .changes)?.source.weekdayConsent)
            try acquire("first", reuse: true); XCTAssertNil(library.state.record(for: .changes)?.source.weekdayConsent)
            XCTAssertEqual(library.state.changeAnalysis?.sourceDigest, "first")
            try acquire("first", reuse: false); XCTAssertNotEqual(library.state.record(for: .changes)?.source.selectionID, selection)
        }
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
                XCTAssertEqual(preview.warnings, [ChangeParseError(code: cached == nil ? .formulaCache : .weekdayMismatch, row: 5, printedWeekday: cached, calculatedWeekday: cached == nil ? nil : "土")])
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
