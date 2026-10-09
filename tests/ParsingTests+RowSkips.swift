import XCTest
import Foundation
import ZIPFoundation
@testable import TakupokeParsing

extension ParsingTests {
    var skipRowsFixture: [[String]] {
        [
            ["学 年", "学科・クラス", "月日", "曜日", "時限", "変更内容", "科目(担当教員)"],
            ["1", "ZZ", "2032/7/10", "土", "1", "休講", "架空科目A(架空教員A)"],
            ["1", "ZZ", "2032/7/11", "月", "2", "補講", "架空科目B(架空教員B)"],
            ["", "", "", "火"],
            ["1", "ZZ", "2032/7/12", "月", "3", "補講", "架空科目C(架空教員C)"],
        ]
    }

    func testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow() throws {
        try temporary { root in
            for shared in [false, true] {
                let url = root.appendingPathComponent("skip-\(shared).xlsx")
                var rows = skipRowsFixture
                rows[2][0] = "1～2"
                rows[2][1] = "ZZ,YY"
                try write(workbook(rows, shared: shared), to: url)
                assertCode(.weekdayMismatch) { _ = try XLSXReader.read(url, defaultYear: 2032) }
                let preview = try XLSXReader.readForPreview(url, defaultYear: 2032)
                XCTAssertEqual(preview.reviewRows.map(\.id), [3, 4])
                XCTAssertEqual(preview.warnings.map(\.code), [.weekdayMismatch, .weekdayOnly])
                XCTAssertEqual(preview.reviewRows[0].fields.first?.value, "1～2")
                assertCode(.weekdayOnly) {
                    _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [3])
                }
                assertCode(.weekdayMismatch) {
                    _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [4])
                }
                for excluded: Set<Int> in [[1, 3, 4], [2, 3, 4], [3, 4, 99]] {
                    assertCode(.unsupported) {
                        _ = try XLSXReader.read(url, defaultYear: 2032, skippingRows: excluded)
                    }
                }
                let filtered = try XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4])
                XCTAssertEqual(filtered.count, 5)
                XCTAssertEqual(filtered[2], [])
                XCTAssertEqual(filtered[3], [])
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
            var rows = skipRowsFixture
            rows[1][1] = "YY"
            rows[4][1] = "全"
            try write(workbook(rows), to: url)
            let changes = try ChangeNormalizer.parse(
                XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032)
            XCTAssertEqual(changes.map(\.class_name), ["1_YY", "1_YY"])
            let missing = root.appendingPathComponent("all-without-evidence.xlsx")
            rows[1] = []
            try write(workbook(rows), to: missing)
            assertCode(.unknownAll) {
                _ = try ChangeNormalizer.parse(
                    XLSXReader.read(missing, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032)
            }
        }
    }

    func testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped() throws {
        try temporary { root in
            for cached in [nil, "火", ""] as [String?] {
                var files = workbook(skipRowsFixture)
                let formula =
                    "<c r=\"D4\" t=\"str\"><f>TEXT(A4,&quot;aaa&quot;)</f>"
                    + (cached.map { "<v>\($0)</v>" } ?? "") + "</c>"
                mutate(
                    &files, "xl/worksheets/sheet1.xml",
                    "<c r=\"D4\" t=\"inlineStr\"><is><t xml:space=\"preserve\">火</t></is></c>", formula)
                let url = root.appendingPathComponent("formula-\(UUID().uuidString).xlsx")
                try write(files, to: url)
                let table = try XLSXReader.readForPreview(url, defaultYear: 2032)
                XCTAssertEqual(table.warnings.last?.code, .weekdayOnly)
                assertCode(.weekdayOnly) {
                    _ = try XLSXReader.read(url, defaultYear: 2032, dateDerivedWeekdays: true)
                }
                XCTAssertEqual(
                    try ChangeNormalizer.parse(
                        XLSXReader.read(url, defaultYear: 2032, skippingRows: [3, 4]), defaultYear: 2032
                    ).count, 2)
            }
        }
    }

    func testRowSkipsCannotHideDateClassFormulaOrStructuralErrors() throws {
        try temporary { root in
            var variants: [([String: Data], ChangeParseError.Code)] = []
            for (column, value, code) in [
                (2, "2032/2/30", ChangeParseError.Code.date), (0, "", .year), (1, "", .classes),
            ] {
                var rows = skipRowsFixture
                rows[2][column] = value
                variants.append((workbook(rows), code))
            }
            var rows = skipRowsFixture
            rows[3].append(contentsOf: ["", "", "", "見出し外の架空値"])
            variants.append((workbook(rows), .headers))
            var files = workbook(skipRowsFixture)
            mutate(
                &files, "xl/worksheets/sheet1.xml", "</worksheet>",
                "<mergeCells><mergeCell ref=\"A3:B3\"/></mergeCells></worksheet>")
            variants.append((files, .mergedCells))
            files = workbook(skipRowsFixture)
            mutate(
                &files, "xl/worksheets/sheet1.xml", "<c r=\"E3\" t=\"inlineStr\"><is>",
                "<c r=\"E3\" t=\"inlineStr\"><f>1+1</f><is>")
            variants.append((files, .formula))
            // A normal populated row with a missing weekday cache stays outside this feature.
            files = weekdayWorkbook(cached: nil)
            variants.append((files, .unsupported))
            for (index, variant) in variants.enumerated() {
                let url = root.appendingPathComponent("blocked-\(index).xlsx")
                try write(variant.0, to: url)
                assertCode(variant.1) {
                    _ = try XLSXReader.read(
                        url, defaultYear: 2032, skippingRows: variant.1 == .unsupported ? [5] : [3, 4])
                }
            }
        }
    }

    func testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root.appendingPathComponent("library"))
            func acquire(_ digest: String, reuse: Bool = true) throws {
                let staged = library.newStagingURL()
                try write(workbook(skipRowsFixture), to: staged)
                try library.commit(
                    staged: staged, kind: .changes, source: MaterialSource(), originalName: "完全架空変更.xlsx",
                    byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: digest,
                    modifiedAt: nil, reuseUnchanged: reuse)
            }
            try acquire("first")
            try library.recordParseFailure(
                ChangeParseError(code: .weekdayMismatch, row: 3), defaultYear: 2032)
            let preview = try library.previewChanges()
            try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032)
            let consent = try XCTUnwrap(library.state.record(for: .changes)?.source.rowSkipConsent)
            XCTAssertEqual(library.state.changeAnalysis?.rowSkipConsent, consent)
            XCTAssertEqual(library.state.changeAnalysis?.records.count, 2)
            XCTAssertFalse(
                ChangeParseAttempt.needsAnalysis(
                    digest: "first", defaultYear: 2032, analysis: library.state.changeAnalysis,
                    attempt: library.state.changeParseAttempt, rowSkipConsent: consent))
            XCTAssertTrue(
                ChangeParseAttempt.needsAnalysis(
                    digest: "first", defaultYear: 2033, analysis: library.state.changeAnalysis,
                    attempt: library.state.changeParseAttempt, rowSkipConsent: consent))
            XCTAssertFalse(
                consent.matches(sourceIdentity: consent.sourceIdentity, digest: "first", defaultYear: 2033))
            var old = consent
            old.parserVersion -= 1
            XCTAssertFalse(
                old.matches(sourceIdentity: consent.sourceIdentity, digest: "first", defaultYear: 2032))
            try acquire("first")
            let reopened = try MaterialLibrary(root: root.appendingPathComponent("library"))
            XCTAssertEqual(reopened.state.record(for: .changes)?.source.rowSkipConsent, consent)
            try acquire("second")
            XCTAssertNil(library.state.record(for: .changes)?.source.rowSkipConsent)
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032) }
            try acquire("first")
            XCTAssertNil(library.state.record(for: .changes)?.source.rowSkipConsent)
            XCTAssertEqual(library.state.changeAnalysis?.rowSkipConsent, consent)  // Last successful result is kept.
            try acquire("first", reuse: false)
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2032) }
        }
    }

    func testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving() throws {
        try temporary { root in
            let library = try MaterialLibrary(root: root.appendingPathComponent("library"))
            let staged = library.newStagingURL()
            try write(workbook(skipRowsFixture), to: staged)
            try library.commit(
                staged: staged, kind: .changes, source: MaterialSource(), originalName: "完全架空変更.xlsx",
                byteCount: try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize!, digest: "first",
                modifiedAt: nil)
            try library.recordParseFailure(
                ChangeParseError(code: .weekdayMismatch, row: 3), defaultYear: 2032)
            let preview = try library.previewChanges()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let before = try encoder.encode(library.state)
            var changed = preview
            changed.reviewRows[0].fields[0].value = "架空の別値"
            assertCode(.cancelled) { try library.applyRowSkips(changed, rows: [3, 4], defaultYear: 2032) }
            changed = preview
            changed.parserVersion -= 1
            assertCode(.cancelled) { try library.applyRowSkips(changed, rows: [3, 4], defaultYear: 2032) }
            assertCode(.cancelled) { try library.applyRowSkips(preview, rows: [3, 4], defaultYear: 2033) }
            assertCode(.cancelled) {
                try library.applyRowSkips(
                    preview, rows: [3, 4], defaultYear: 2032,
                    check: { throw ChangeParseError(code: .cancelled) })
            }
            XCTAssertEqual(try encoder.encode(library.state), before)
            let only = root.appendingPathComponent("only.xlsx")
            try write(workbook([skipRowsFixture[0], ["", "", "", "火"]]), to: only)
            assertCode(.weekdayOnly) { _ = try XLSXReader.read(only, defaultYear: 2032) }
            assertCode(.empty) {
                _ = try ChangeNormalizer.parse(
                    XLSXReader.read(only, defaultYear: 2032, skippingRows: [2]), defaultYear: 2032)
            }
        }
    }

}
