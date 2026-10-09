import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    func testDenseCalibrationIgnoresOutsideTextWithoutExhaustingWorkBudget() throws {
        var glyphs = [PDFGlyph]()
        var references = [PDFBox]()
        var targets = [PDFBox]()
        for row in 0..<34 {
            for column in 0..<20 {
                let x = 10 + Double(column) * 85
                let y = 10 + Double(row) * 60
                let target = PDFBox(left: x, top: y, right: x + 40, bottom: y + 60)
                targets.append(target)
                glyphs += text("架空A", x: x + 4, y: y + 12)
                references.append(PDFBox(left: x + 40, top: y, right: x + 80, bottom: y + 60))
                for (i, line) in ["架空B", "担当B", "室B"].enumerated() {
                    glyphs += text(line, x: x + 44, y: y + 12 + Double(i) * 18)
                }
            }
        }
        glyphs += Array(repeating: PDFGlyph(text: "x", x: 1800, y: 2100, width: 1, height: 1), count: 74000)
        XCTAssertLessThan(glyphs.count, 100000)
        let grid = PDFGrid(page: PDFPageLayout(width: 2200, height: 2200, glyphs: glyphs, lines: []))
        for target in targets {
            XCTAssertEqual(
                try grid.lessonFields(target, lines: ["架空A"], referenceBoxes: references), ["架空A", "", ""])
            XCTAssertEqual(try grid.glyphs(in: target, check: {}).map(\.text).joined(), "架空A")
        }
    }
    func testCalibrationSourceScanCancelsAndDoesNotCacheAPartialReference() throws {
        let target = PDFBox(left: 10, top: 10, right: 50, bottom: 70)
        let reference = PDFBox(left: 60, top: 10, right: 100, bottom: 70)
        var glyphs = text("架空科目A", x: 14, y: 22)
        for (i, line) in ["架空科目B", "架空教員B", "架空室B"].enumerated() {
            glyphs += text(line, x: 64, y: 22 + Double(i) * 18)
        }
        glyphs += Array(repeating: PDFGlyph(text: "x", x: 110, y: 100, width: 1, height: 1), count: 99900)
        let grid = PDFGrid(page: PDFPageLayout(width: 120, height: 120, glyphs: glyphs, lines: []))
        var checks = 0
        XCTAssertThrowsError(
            try grid.lessonFields(
                target, lines: ["架空科目A"], referenceBoxes: [reference],
                check: {
                    checks += 1
                    if checks == 50 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 50)
        XCTAssertEqual(
            try grid.lessonFields(target, lines: ["架空科目A"], referenceBoxes: [reference]), ["架空科目A", "", ""])
        XCTAssertEqual(
            try grid.lessonFields(target, lines: ["架空科目A"], referenceBoxes: [reference]), ["架空科目A", "", ""])
    }
    func testCalibrationReferenceInventoryChargesHeightMismatchAndCancels() throws {
        let box = PDFBox(left: 10, top: 10, right: 50, bottom: 70)
        let grid = PDFGrid(
            page: PDFPageLayout(width: 100, height: 100, glyphs: text("架空A", x: 14, y: 22), lines: []))
        let references = (0..<10001).map {
            PDFBox(left: Double($0), top: 0, right: Double($0) + 1, bottom: 1)
        }
        XCTAssertThrowsError(try grid.lessonFields(box, lines: ["架空A"], referenceBoxes: references)) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .limit)
        }
        var checks = 0
        XCTAssertThrowsError(
            try grid.lessonFields(
                box, lines: ["架空A"], referenceBoxes: references,
                check: {
                    checks += 1
                    if checks == 3 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 3)
    }
    func testBuilderNeverConvertsCancelledCalibrationIntoStructureRecovery() {
        var checks = 0
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [recoveryTimetablePage()], kind: .timetable, hash: String(repeating: "b", count: 64),
                check: {
                    checks += 1
                    if checks == 8 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 8)
    }
    func testMalformedAnnualNumericColumnsCannotHideBehindAValidYear() throws {
        for malformed in [
            "令和100年度", "令和0年度", "12026年度", "202年度", "10000年度", "999999999999999999999999年度", "令和①⓪⓪年度",
            "１２０２６年度", "令 和 1 0 0 年 度", "1 2 0 2 6 年 度", "令和Ⅸ年度", "ⅯⅯⅩⅩⅥ年度", "令和ⅰ年度", "令和9年度", "㋿9年度",
            "令和Ⅸ年度", "𝟚𝟘𝟚𝟟年度", "令和九年度", "令和年度",
        ] {
            XCTAssertThrowsError(try PDFSchoolParser.uniqueTitleYear("令和8年度" + malformed + "前期時間割")) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .yearHeading)
            }
        }
        for title in [
            "令和8年度令和８年度", "２０２６年度令和8年度", "令和⑧年度2026年度", "令 和 8 年 度2 0 2 6 年 度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度",
        ] {
            let markers = try PDFSchoolParser.yearMarkers(title)
            XCTAssertEqual(markers.count, 2)
            XCTAssertTrue(markers.allSatisfy { $0.year == 2026 })
            XCTAssertEqual(try PDFSchoolParser.uniqueTitleYear(title), 2026)
            XCTAssertEqual(markers.map { String(title[$0.range]) }.joined(), title)
        }
    }

    func testOrdinaryTitleYearMustBeUniqueWhileRepeatedEquivalentYearsRemainValid() throws {
        func page(_ title: String) -> PDFPageLayout {
            var value = timetable()
            value.glyphs.removeAll { $0.cy == 20 }
            value.glyphs += text(title, x: 200, y: 20)
            return value
        }
        for title in [
            "令和14年度令和14年度前期時間割", "2032年度令和14年度前期時間割", "令 和 1 4 年 度2 0 3 2 年 度前期時間割", "㋿14年度2032年度前期時間割",
        ] {
            XCTAssertEqual(try parse([page(title)], kind: .timetable).schoolYear, 2032)
        }
        for title in [
            "令和13年度令和14年度前期時間割", "令和14年度令和13年度前期時間割",
            "令和14年度令和100年度前期時間割", "令和14年度12032年度前期時間割",
            "令和14年度令和0年度前期時間割", "令和14年度99999999999999999999年度前期時間割", "令和14年度令 和 1 0 0 年 度前期時間割",
            "令和14年度令和Ⅸ年度前期時間割", "令和14年度令和15年度前期時間割", "令和14年度㋿15年度前期時間割", "令和14年度令和九年度前期時間割",
            "令和14年度令和年度前期時間割",
        ] {
            XCTAssertThrowsError(try parse([page(title)], kind: .timetable)) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .yearHeading)
            }
        }
    }
    func testRecoveryTitleYearEvidenceMustIncludeEveryEquivalentMarker() async throws {
        func page(_ title: String) -> PDFPageLayout {
            var value = recoveryTimetablePage()
            value.glyphs.removeAll { $0.cy == 20 }
            value.glyphs += text(title, x: 200, y: 20)
            return value
        }
        for title in ["令和14年度令和14年度前期時間割", "2032年度令和14年度前期時間割", "㋿14年度2032年度前期時間割"] {
            let doc = try RecoveryDocumentBuilder.build(
                [page(title)], kind: .timetable, hash: String(repeating: "b", count: 64))
            XCTAssertEqual(doc.schoolYear, 2032)
            XCTAssertEqual(doc.yearEvidence.count, 2)
            let run = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
            XCTAssertEqual(run.state, .awaitingConfirmation)
        }
        for title in [
            "令和13年度令和14年度前期時間割", "令和14年度令和13年度前期時間割",
            "令和14年度令和100年度前期時間割", "令和14年度12032年度前期時間割",
            "令和14年度令和0年度前期時間割", "令和14年度99999999999999999999年度前期時間割", "令和14年度令 和 1 0 0 年 度前期時間割",
            "令和14年度令和Ⅸ年度前期時間割", "令和14年度令和15年度前期時間割", "令和14年度㋿15年度前期時間割", "令和14年度令和九年度前期時間割",
            "令和14年度令和年度前期時間割",
        ] {
            do {
                let doc = try RecoveryDocumentBuilder.build(
                    [page(title)], kind: .timetable, hash: String(repeating: "b", count: 64))
                let run = try await RecoveryEngine.run(
                    doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil },
                    check: {})
                XCTFail("Invalid annual marker reached \(run.state.rawValue): \(run.errors)")
            } catch let error as PDFParseError { XCTAssertEqual(error.stage, .yearHeading) }

        }
        let spaced = try RecoveryDocumentBuilder.build(
            [page("令 和 1 4 年 度2 0 3 2 年 度前期時間割")], kind: .timetable, hash: String(repeating: "b", count: 64))
        XCTAssertEqual(spaced.schoolYear, 2032)
        XCTAssertEqual(spaced.yearEvidence.count, 2)
        let run = try await RecoveryEngine.run(
            spaced, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
    }
    func testSourceIdentityIndexPreservesDuplicateAmbiguityAndCancellation() throws {
        let a = PDFGlyph(text: "A", x: 10, y: 20, width: 4, height: 8, sourceOrder: 0)
        let b = PDFGlyph(text: "A", x: 10, y: 20, width: 4, height: 8, sourceOrder: 1)
        let c = PDFGlyph(text: "A", x: 20, y: 20, width: 4, height: 8, sourceOrder: 0)
        let index = try RecoveryGlyphIndex([a, b, a, c], check: {})
        XCTAssertEqual(try index.indices(for: [a], check: {}), [0, 2])
        XCTAssertEqual(try index.indices(for: [b, c], check: {}), [1, 3])
        XCTAssertEqual(try index.indices(for: [a, a], check: {}), [0, 2])
        var checks = 0
        XCTAssertThrowsError(
            try RecoveryGlyphIndex(
                Array(repeating: a, count: 100000),
                check: {
                    checks += 1
                    if checks == 2 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 2)
        let dense = try RecoveryGlyphIndex(Array(repeating: a, count: 100000), check: {})
        checks = 0
        XCTAssertThrowsError(
            try dense.indices(
                for: [a],
                check: {
                    checks += 1
                    if checks == 2 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 2)
    }
    func testRasterRuleGraphStopsAtItsComparisonBudgetAndChecksCancellationInsidePass() {
        let lines = (0..<1100).map { PDFRule(x1: 10, y1: Double($0) * 4, x2: 50, y2: Double($0) * 4) }
        XCTAssertThrowsError(try RecoveryRasterGrid.connectedRules(lines, check: {})) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .limit)
        }
        var checks = 0
        XCTAssertThrowsError(
            try RecoveryRasterGrid.connectedRules(
                lines,
                check: {
                    checks += 1
                    if checks == 2 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 2)
        let covered = RecoveryBox(x: 0, y: 0, width: 128, height: 128)
        let dense = RecoveryRasterGrid(
            width: 128, height: 128, grayscale: [UInt8](repeating: 0, count: 128 * 128))
        let outside = RecoveryBox(x: 200, y: 200, width: 10, height: 10)
        XCTAssertThrowsError(
            try dense.hasUncoveredInk(
                covered, text: Array(repeating: outside, count: 2000) + [covered], rules: [], check: {})
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .limit)
        }
    }
    func testRasterInkAndRuleMaskCheckCancellationInsideTheirPixelLoops() throws {
        let size = 512
        let pixels = [UInt8](repeating: 0, count: size * size)
        let raster = RecoveryRasterGrid(width: size, height: size, grayscale: pixels)
        let rules = [PDFRule(x1: 0, y1: 20, x2: 511, y2: 20)]
        var checks = 0
        XCTAssertThrowsError(
            try raster.preparingRules(
                rules,
                check: {
                    checks += 1
                    if checks == 2 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 2)
        checks = 0
        let box = RecoveryBox(x: 0, y: 0, width: 512, height: 512)
        XCTAssertThrowsError(
            try raster.hasUncoveredInk(
                box, text: [box], rules: [],
                check: {
                    checks += 1
                    if checks == 2 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 2)
    }
    func testOffscreenRecoveryLayoutFailsBeforeSourceBindingOrAI() {
        var page = recoveryTimetablePage()
        for index in page.glyphs.indices { page.glyphs[index].x += 3000 }
        for index in page.lines.indices {
            page.lines[index].x1 += 3000
            page.lines[index].x2 += 3000
        }
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [page], kind: .timetable, hash: String(repeating: "b", count: 64))
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .rasterInput)
        }
    }
}
