import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    func recoveryTimetablePage(labeled: Bool = false) -> PDFPageLayout {
        var p = timetable()
        p.width = 1900
        p.glyphs.removeAll { $0.cy == 70 }
        p.lines.removeAll { $0.vertical && $0.y1 == 60 && $0.y2 == 80 }
        for i in 0..<40 {
            p.glyphs += text(String(i % 8 + 1), x: 108 + Double(i) * 40, y: 70)
            p.lines.append(v(100 + Double(i) * 40, 60, 80))
        }
        p.lines.append(v(1700, 60, 80))
        p.lines.removeAll { $0.vertical && $0.x1 >= 100 && $0.y1 == 100 }
        for i in 0...40 { p.lines.append(v(100 + Double(i) * 40, 100, 280)) }
        for i in p.lines.indices where p.lines[i].horizontal { p.lines[i].x2 = 1700 }
        for i in p.glyphs.indices {
            if p.glyphs[i].x == 70 && [130.0, 190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "C" }
            if p.glyphs[i].x == 74 && [130.0, 190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "N" }
            if p.glyphs[i].x == 70 && p.glyphs[i].cy == 250 { p.glyphs[i].text = "2" }
        }
        for (i, label) in ["月", "火", "水", "木", "金"].enumerated() {
            p.glyphs += text(label, x: 200 + Double(i) * 320, y: 50)
        }
        if labeled {
            p.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
            for (i, line) in ["教員:架空担当R", "教室:架空室S", "科目:架空科目T"].enumerated() {
                p.glyphs += text(line, x: 102, y: 110 + Double(i) * 18, step: 3)
            }
        }
        return p
    }
    func testLayoutRecoveryPreservesParallelLessonsAndAllSlots() async throws {
        let p = recoveryTimetablePage()
        let d = try RecoveryDocumentBuilder.build(
            [p], kind: .timetable, hash: String(repeating: "b", count: 64))
        XCTAssertEqual(d.classes.count, 3)
        XCTAssertEqual(d.cells.flatMap(\.slots).count, 120)
        XCTAssertTrue(d.cells.contains { $0.parallelCount == 2 && $0.parallelSeparators.count == 3 })
        let run = try await RecoveryEngine.run(
            d, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation)
        XCTAssertEqual(run.result?.metadata.provider, "rule")
    }
    private func recoveryTimetableReplacingParallelFields(_ fields: [String]) -> PDFPageLayout {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 160 && $0.cy < 220 }
        for (index, value) in fields.enumerated() {
            page.glyphs += text(value, x: 104, y: 172 + Double(index) * 18, step: 2)
        }
        return page
    }
    func testLayoutRecoveryCannotBypassUnalignedParallelEvidenceRefusal() {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let paired = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for unchangedRole in 0..<3 {
            var fields = paired
            fields[unchangedRole] = single[unchangedRole]
            XCTAssertThrowsError(
                try RecoveryDocumentBuilder.build(
                    [recoveryTimetableReplacingParallelFields(fields)],
                    kind: .timetable, hash: String(repeating: "b", count: 64))
            ) {
                XCTAssertEqual(($0 as? PDFParseError)?.code, .ambiguous)
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .parallelLessons)
            }
        }
    }
    func testLayoutRecoveryKeepsACompoundSingleRoleLiteralThroughRulesAndValidator() async throws {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let compound = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for compoundRole in 0..<3 {
            var fields = single
            fields[compoundRole] = compound[compoundRole]
            let doc = try RecoveryDocumentBuilder.build(
                [recoveryTimetableReplacingParallelFields(fields)],
                kind: .timetable, hash: String(repeating: "b", count: 64))
            let cell = try XCTUnwrap(
                doc.cells.first {
                    $0.slots.contains { $0.className == "2_CN" && $0.day == "1" && $0.period == 1 }
                })
            XCTAssertEqual(cell.parallelCount, 1)
            let run = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 26, foreground: true,
                providers: [], rule: { _ in nil }, check: {})
            XCTAssertEqual(run.state, .awaitingConfirmation)
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.isEmpty)
            let recovered = try XCTUnwrap(result.cells.first { $0.cellId == cell.id })
            XCTAssertEqual(recovered.lessons.count, 1)
            XCTAssertEqual(recovered.lessons[0].subject.value, fields[0])
            XCTAssertEqual(recovered.lessons[0].teacher.value, fields[1])
            XCTAssertEqual(recovered.lessons[0].room.value, fields[2])
        }
    }
    private func recoveryTimetableWithInlineFields(_ fields: [String]) -> PDFPageLayout {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        for (index, field) in fields.enumerated() {
            let label = ["科目：", "教員：", "教室："][index]
            page.glyphs += text(label + field, x: 102, y: 110 + Double(index) * 18, step: 2)
        }
        return page
    }
    func testInlineRoleScopesCannotCollapseMatchedOrMismatchedMultipleBodyRoles() {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let paired = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for unchangedRole in [-1, 0, 1, 2] {
            var fields = paired
            if unchangedRole >= 0 { fields[unchangedRole] = single[unchangedRole] }
            XCTAssertThrowsError(
                try RecoveryDocumentBuilder.build(
                    [recoveryTimetableWithInlineFields(fields)],
                    kind: .timetable, hash: String(repeating: "b", count: 64))
            ) {
                XCTAssertEqual(($0 as? PDFParseError)?.code, .ambiguous)
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .parallelLessons)
            }
        }
    }
    func testInlineRoleScopesKeepEachSingleCompoundRoleWithoutParallelInvention() async throws {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let compound = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for compoundRole in 0..<3 {
            var fields = single
            fields[compoundRole] = compound[compoundRole]
            let doc = try RecoveryDocumentBuilder.build(
                [recoveryTimetableWithInlineFields(fields)], kind: .timetable,
                hash: String(repeating: "b", count: 64))
            let cell = try XCTUnwrap(
                doc.cells.first {
                    $0.slots.contains { $0.className == "1_CN" && $0.day == "1" && $0.period == 1 }
                })
            XCTAssertEqual(cell.bindingMode, .roleProposal)
            XCTAssertEqual(cell.parallelCount, 1)
            let run = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { _ in nil }, check: {})
            XCTAssertEqual(run.state, .awaitingConfirmation)
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.isEmpty)
            let recovered = try XCTUnwrap(result.cells.first { $0.cellId == cell.id })
            XCTAssertEqual(recovered.lessons[0].subject.value, fields[0])
            XCTAssertEqual(recovered.lessons[0].teacher.value, fields[1])
            XCTAssertEqual(recovered.lessons[0].room.value, fields[2])
        }
    }
    func testReorderedInlineRolesRequireIndependentLabels() throws {
        let d = try RecoveryDocumentBuilder.build(
            [recoveryTimetablePage(labeled: true)], kind: .timetable, hash: String(repeating: "b", count: 64))
        let cell = try XCTUnwrap(d.cells.first { $0.bindingMode == .roleProposal })
        XCTAssertEqual(Set(cell.roleScopes.map(\.role)), Set(RecoveryRole.allCases))
        XCTAssertNotNil(RecoveryRules.recover(d, cell))
    }
    func testMultiCharacterTermGlyphFailsWithoutOutOfBoundsAccess() {
        var page = recoveryTimetablePage()
        let prefix = page.glyphs.firstIndex { $0.text == "前" }!
        let suffix = page.glyphs.firstIndex { $0.text == "期" }!
        page.glyphs[prefix].text = "前期"
        page.glyphs[prefix].y = 30
        page.glyphs.remove(at: suffix)
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [page], kind: .timetable, hash: String(repeating: "b", count: 64))
        ) { error in
            XCTAssertEqual((error as? PDFParseError)?.code, .ambiguous)
        }
    }
    func testPartialReorderedRoleLabelsCannotBecomeFixedOrParallelBindings() {
        for parallel in [false, true] {
            for label in RecoveryRole.teacher.labels {
                var page = recoveryTimetablePage()
                page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
                let lines = parallel ? [label + ":A・B", "C・D", "E・F"] : [label + ":A", "C", "E"]
                for (i, line) in lines.enumerated() {
                    page.glyphs += text(line, x: 102, y: 110 + Double(i) * 18, step: 3)
                }
                XCTAssertThrowsError(
                    try RecoveryDocumentBuilder.build(
                        [page], kind: .timetable, hash: String(repeating: "b", count: 64)))
            }
        }
    }
    func testTeacherOnlyCellCannotUseOutsideTableOrConflictingRoleCalibration() {
        for outside in [true, false] {
            var page = timetable()
            page.glyphs.removeAll {
                100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 && $0.cy != 130
            }
            let x = outside ? 920.0 : 144.0
            let top = outside ? 400.0 : 100.0
            if outside {
                page.lines += [
                    h(top, 920, 1040), h(top + 60, 920, 1040), v(920, top, top + 60), v(1040, top, top + 60),
                ]
            }
            for (index, line) in ["架空注記A", "架空注記B", "架空注記C"].enumerated() {
                page.glyphs += text(line, x: x + 4, y: top + 30 + Double(index) * 12)
            }
            XCTAssertThrowsError(try parse([page], kind: .timetable)) { error in
                XCTAssertEqual((error as? PDFParseError)?.stage, .lessonLines)
            }
        }
    }
    func testRecoveryCannotCalibrateTeacherOnlyCellFromOutsideTable() {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 && $0.cy != 130 }
        page.lines += [h(400, 1750, 1850), h(460, 1750, 1850), v(1750, 400, 460), v(1850, 400, 460)]
        for (index, line) in ["架空注記A", "架空注記B", "架空注記C"].enumerated() {
            page.glyphs += text(line, x: 1754, y: 430 + Double(index) * 12)
        }
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [page], kind: .timetable, hash: String(repeating: "b", count: 64)))
    }
    func testFractionalRasterCellIncludesEveryInteriorPixelCenter() {
        let box = RecoveryBox(x: 10.25, y: 10.25, width: 20.5, height: 20.5)
        for (x, y) in [(10, 15), (30, 15), (15, 10), (15, 30)] {
            var pixels = [UInt8](repeating: 255, count: 50 * 50)
            pixels[y * 50 + x] = 254
            let raster = RecoveryRasterGrid(width: 50, height: 50, grayscale: pixels)
            XCTAssertTrue(raster.hasUncoveredInk(box, text: [], rules: []))
            XCTAssertFalse(raster.isBlank(box))
        }
        let blank = RecoveryRasterGrid(
            width: 50, height: 50, grayscale: [UInt8](repeating: 255, count: 50 * 50))
        XCTAssertTrue(blank.isBlank(box))
        var outside = [UInt8](repeating: 255, count: 50 * 50)
        outside[15 * 50 + 9] = 254
        XCTAssertTrue(RecoveryRasterGrid(width: 50, height: 50, grayscale: outside).isBlank(box))
    }
    func testStrictMissingTeacherDoesNotShiftRoomIntoTeacher() throws {
        var p = timetable()
        p.glyphs.removeAll { $0.cy == 130 && $0.cx >= 100 }
        let result = try parse([p], kind: .timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.teacher, "")
        XCTAssertEqual(lesson.names.room, "架空室Q")
        p.glyphs.removeAll { $0.cy == 190 && $0.cx >= 100 }
        XCTAssertThrowsError(try parse([p], kind: .timetable))
    }
}
