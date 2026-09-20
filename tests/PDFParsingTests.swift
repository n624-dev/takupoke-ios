import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

final class PDFParsingTests: XCTestCase {
    // Construct new layouts from primitives, with no copied school cells or coordinates.
    func text(_ value: String, x: Double, y: Double, step: Double = 4) -> [PDFGlyph] {
        value.enumerated().map { PDFGlyph(text: String($0.element), x: x + Double($0.offset) * step, y: y - 3, width: step, height: 6) }
    }
    func h(_ y: Double, _ x1: Double = 10, _ x2: Double = 1100) -> PDFRule { PDFRule(x1: x1, y1: y, x2: x2, y2: y) }
    func v(_ x: Double, _ y1: Double = 60, _ y2: Double = 280) -> PDFRule { PDFRule(x1: x, y1: y1, x2: x, y2: y2) }
    func timetable() -> PDFPageLayout {
        var gs = text("令和14年度前期時間割", x: 200, y: 20)
        var lines = [60.0, 80, 100, 160, 220, 280].map { h($0) } + [20.0, 50, 100].map { v($0) }
        for i in 0..<40 {
            gs += text(String(i % 8 + 1), x: 108 + Double(i) * 20, y: 70)
            lines.append(v(100 + Double(i) * 20, 60, 80))
        }
        lines.append(v(900, 60, 80))
        for i in 0...20 { lines.append(v(100 + Double(i) * 40, 100, 280)) }
        for (grade, label, y) in [("1", "ZZ", 130.0), ("2", "YY", 190.0), ("AI", "3", 250.0)] {
            gs += text(grade, x: 30, y: y)
            gs += text(label, x: 70, y: y)
        }
        gs += text("架空科目Q", x: 104, y: 112)
        gs += text("架空教員Q", x: 104, y: 130)
        gs += text("架空室Q", x: 104, y: 148)
        gs += text("架空X・架空Y", x: 104, y: 172)
        gs += text("教員X・教員Y", x: 104, y: 190)
        gs += text("・架空室Y", x: 104, y: 208)
        gs += text("架空科目Z", x: 264, y: 232)
        return PDFPageLayout(width: 1100, height: 600, glyphs: gs, lines: lines)
    }
    func calendar(_ months: [Int], winter: Bool = true) -> PDFPageLayout {
        var gs = text("令和14年度行事予定表", x: 400, y: 20)
        gs += text("日", x: 18, y: 60)
        var lines = [h(40), h(70)]
        var arrows: [PDFArrow] = []
        for day in 1...31 {
            gs += text(String(day), x: day < 10 ? 18 : 16, y: 70 + Double(day) * 20 - 10)
            lines.append(h(70 + Double(day) * 20))
        }
        lines += [v(10, 40, 690), v(30, 40, 690)]
        for (i, month) in months.enumerated() {
            let x = 60 + Double(i) * 170
            gs += text("\(month)月", x: x + 40, y: 47)
            gs += text("共通", x: x + 12, y: 60)
            gs += text("高松", x: x + 52, y: 60)
            gs += text("詫間", x: x + 92, y: 60)
            lines += [x, x + 40, x + 80, x + 120].map { v($0, 40, 690) }
            gs += text("架空行事\(month)", x: x + 2, y: 100)
            gs += text("架空対象外", x: x + 42, y: 120)
            gs += text("架空交流会", x: x + 82, y: 140)
            gs += text("9", x: x + 115, y: 160) // Teaching-week counter, not an event.
            if month == 6 {
                gs += text("夏季休業(6/19まで)", x: x + 2, y: 260, step: 2)
            }
            if winter && month == 12 {
                gs += text("冬季休業", x: x + 2, y: 560)
                arrows.append(PDFArrow(x: x + 30, top: 555, bottom: 680))
            }
            if winter && month == 1 { arrows.append(PDFArrow(x: x + 30, top: 72, bottom: 150)) }
        }
        return PDFPageLayout(width: 1100, height: 800, glyphs: gs, lines: lines, arrows: arrows)
    }
    func parse(_ pages: [PDFPageLayout], kind: MaterialKind) throws -> PDFAnalysis {
        try PDFSchoolParser.parse(pages, kind: kind, digest: "synthetic-digest", name: "synthetic.pdf")
    }
    func testTimetablePeriodsParallelLessonsAndEmptyRoom() throws {
        let result = try parse([timetable()], kind: .timetable)
        XCTAssertEqual(result.version, PDFAnalysis.currentVersion(for: .timetable))
        XCTAssertEqual(result.version, 6)
        XCTAssertEqual(result.schoolYear, 2032)
        XCTAssertEqual(result.term, "前期")
        XCTAssertEqual(result.lessons.count, 8)
        let parallel = result.lessons.filter { $0.className == "2_YY" }
        XCTAssertEqual(parallel.map(\.period), [1, 1, 2, 2])
        XCTAssertEqual(parallel.map(\.names.room), ["", "架空室Y", "", "架空室Y"])
        XCTAssertEqual(parallel.map(\.names.subject), ["架空X", "架空Y", "架空X", "架空Y"])
        XCTAssertTrue(parallel.allSatisfy { $0.names.roomFullName == nil && $0.sourceText.contains("・架空室Y") })
        XCTAssertEqual(result.lessons.filter { $0.className == "AI_3" }.map(\.weekday), [2, 2])
    }
    func testSourceOrderKeepsMixedSizeLessonNamesAndMetadataSeparate() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        // Same glyph centres / different heights can occur in selection bounds.
        // These fictional rows have their own reading order, unrelated to school data.
        for (row, value) in ["架空αQⅣ", "架空担当R", "架空部屋S"].enumerated() {
            for (i, character) in value.enumerated() {
                page.glyphs.append(PDFGlyph(text: String(character), x: 109, y: 110 + Double(row) * 1.5,
                    width: 5, height: i % 2 == 0 ? 7 : 3, sourceLine: row, sourceOrder: (2 - row) * 100 + i))
            }
        }
        let result = try parse([page], kind: .timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.subject, "架空αQⅣ")
        XCTAssertEqual(lesson.names.teacher, "架空担当R")
        XCTAssertEqual(lesson.names.room, "架空部屋S")
        XCTAssertEqual(lesson.sourceText, "架空αQⅣ\n架空担当R\n架空部屋S")
    }
    func testTimetableJoinsAlignedNonoverlappingLineFragments() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        for (row, value) in ["架空科目Q", "架空教員R", "架空部屋S"].enumerated() {
            for (i, character) in value.enumerated() {
                page.glyphs.append(PDFGlyph(text: String(character), x: 104 + Double(i) * 4,
                    y: 108 + Double(row) * 18, width: 4, height: 6,
                    sourceLine: row * 10 + (i < 2 ? 0 : 1), sourceOrder: (2 - row) * 100 + i))
            }
        }
        let parsed = try parse([page], kind: .timetable)
        let lesson = try XCTUnwrap(parsed.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.subject, "架空科目Q")
        XCTAssertEqual(lesson.names.teacher, "架空教員R")
        XCTAssertEqual(lesson.names.room, "架空部屋S")
    }
    func testTimetableFragmentsDoNotMergeOverlapsOrNearbyDifferentLines() throws {
        let box = PDFBox(left: 0, top: 0, right: 100, bottom: 100)
        let left = PDFGlyph(text: "架空", x: 10, y: 10, width: 8, height: 6, sourceLine: 0, sourceOrder: 2)
        var right = PDFGlyph(text: "Q", x: 19, y: 10, width: 4, height: 6, sourceLine: 1, sourceOrder: 1)
        func layout(_ glyphs: [PDFGlyph]) -> PDFGrid {
            PDFGrid(page: PDFPageLayout(width: 100, height: 100, glyphs: glyphs, lines: []))
        }
        XCTAssertEqual(try layout([right, left]).timetableText(box), ["架空Q"])
        // Calendar extraction keeps the two native lines; coalescing is timetable-only.
        XCTAssertEqual(try layout([right, left]).text(box).count, 2)
        right.x = 12
        XCTAssertThrowsError(try layout([left, right]).timetableText(box)) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .fragmentOverlap)
        }
        right.x = 19; right.y = 11.2
        XCTAssertEqual(try layout([right, left]).timetableText(box), ["架空", "Q"])
        right.y = 10; right.height = 4
        XCTAssertEqual(try layout([right, left]).timetableText(box).count, 2)
    }
    func testTimetableBoundaryOverhangRequiresForwardTextAndGeometry() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        for (row, value) in ["架空科目Q", "架空教員R", "架空部屋S"].enumerated() {
            for (i, character) in value.enumerated() {
                page.glyphs.append(PDFGlyph(text: String(character), x: 104 + Double(i) * 4,
                    y: 108 + Double(row) * 18, width: 5, height: 6,
                    sourceLine: row * 10 + (i < 3 ? 0 : 1), sourceOrder: row * 100 + i))
            }
        }
        let result = try parse([page], kind: .timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.subject, "架空科目Q")
        XCTAssertEqual(lesson.names.teacher, "架空教員R")
        XCTAssertEqual(lesson.names.room, "架空部屋S")

        // The same rectangles do not authorize overriding a contrary reading order.
        for index in page.glyphs.indices where page.glyphs[index].sourceLine == 0 {
            page.glyphs[index].sourceOrder! += 10
        }
        XCTAssertThrowsError(try parse([page], kind: .timetable)) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .fragmentOverlap)
            XCTAssertEqual(($0 as? PDFParseError)?.cell?.classRow, 1)
        }
    }
    func testCharacterBoundsKeepNeighbouringCellsOutOfTimetable() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        var actual: [CGRect] = []
        var selections: [CGRect] = []
        var content: [(String, Int)] = []
        for (row, value) in ["架空科目M", "架空教員N", "架空部屋O"].enumerated() {
            for (i, character) in value.enumerated() {
                let rect = CGRect(x: 104 + i * 4, y: 108 + row * 18, width: 4, height: 6)
                actual.append(rect)
                selections.append(rect)
                content.append((String(character), row))
            }
        }
        // Independently invented adjacent-cell character and a wide highlight.
        // The highlight centre falls in the teacher cell, but the character does not.
        actual.append(CGRect(x: 148, y: 126, width: 4, height: 6))
        selections.append(CGRect(x: 87, y: 126, width: 86, height: 6))
        content.append(("隣", 99))
        func layout(_ bounds: [CGRect]) throws -> PDFPageLayout {
            var result = page
            for (index, entry) in content.enumerated() {
                let rect = try PDFCharacterGeometry.bounds(for: NSRange(location: index, length: 1), count: content.count) { bounds[$0] }
                result.glyphs.append(PDFGlyph(text: entry.0, x: rect.minX, y: rect.minY, width: rect.width, height: rect.height,
                    sourceLine: entry.1, sourceOrder: index))
            }
            return result
        }
        XCTAssertThrowsError(try parse([layout(selections)], kind: .timetable)) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .fragmentOverlap)
        }
        let result = try parse([layout(actual)], kind: .timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" && $0.period == 1 })
        XCTAssertEqual(lesson.names.subject, "架空科目M")
        XCTAssertEqual(lesson.names.teacher, "架空教員N")
        XCTAssertEqual(lesson.names.room, "架空部屋O")
        XCTAssertFalse(lesson.sourceText.contains("隣"))
    }
    func testCharacterGeometryValidatesUTF16RangesAndDoesNotDropInvalidBounds() throws {
        let text = "Aか\u{3099}B" as NSString
        let range = text.rangeOfComposedCharacterSequence(at: 1)
        XCTAssertEqual(range, NSRange(location: 1, length: 2))
        var indices: [Int] = []
        let bounds = try PDFCharacterGeometry.bounds(for: range, count: text.length) { index in
            indices.append(index)
            return index == 1 ? CGRect(x: 10, y: 20, width: 5, height: 8) : CGRect(x: 14, y: 25, width: 2, height: 4)
        }
        XCTAssertEqual(indices, [1, 2])
        XCTAssertEqual(bounds, CGRect(x: 10, y: 20, width: 6, height: 9))
        for bad in [NSRange(location: NSNotFound, length: 1), NSRange(location: 1, length: Int.max),
                    NSRange(location: 4, length: 1), NSRange(location: 0, length: 0)] {
            XCTAssertThrowsError(try PDFCharacterGeometry.bounds(for: bad, count: text.length) { _ in
                XCTFail("Out-of-range access"); return .zero
            })
        }
        for bad in [CGRect.null, CGRect.zero, CGRect.infinite] {
            XCTAssertThrowsError(try PDFCharacterGeometry.bounds(for: range, count: text.length) { index in
                index == 1 ? CGRect(x: 10, y: 20, width: 5, height: 8) : bad
            }) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .characterMapping)
            }
        }
    }
    func testRemovingDisplayBreaksPreservesStoredLessonFields() throws {
        let source = "架空\r\n科目Q\n架空教員R\u{2028}架空部屋S"
        let lesson = PDFLesson(className: "1_ZZ", weekday: 2, period: 5,
            names: TimetableLessonNames(subject: "架空\r\n科目Q", teacher: "架空教員R", room: "架空部屋S"),
            sourceText: source, page: 1)
        XCTAssertEqual(PDFDisplayText.continuous(lesson.sourceText), "架空科目Q架空教員R架空部屋S")
        XCTAssertEqual(PDFDisplayText.continuous(lesson.names.subject), "架空科目Q")
        XCTAssertEqual(lesson.sourceText, source)
        let restored = try JSONDecoder().decode(PDFLesson.self, from: JSONEncoder().encode(lesson))
        XCTAssertEqual(restored, lesson)
    }
    func testTimetableFailureReportsLocationAndLineCountWithoutNames() throws {
        var page = timetable()
        page.glyphs += text("架空追加行", x: 104, y: 154)
        try XCTAssertThrowsError(try parse([page], kind: .timetable)) { error in
            guard let failure = error as? PDFParseError else { return XCTFail("Unexpected error type") }
            XCTAssertEqual(failure.stage, .lessonLines)
            XCTAssertEqual(failure.cell, PDFParseError.Cell(classRow: 1, weekday: 1, period: 1, detectedLines: 4))
            XCTAssertTrue(failure.localizedDescription.contains("検出4行"))
            XCTAssertFalse(failure.localizedDescription.contains("架空"))
            XCTAssertEqual(try JSONDecoder().decode(PDFParseError.self, from: JSONEncoder().encode(failure)), failure)
        }
    }
    func testTimetableGeometryReportReproducesFailureWithoutSourceText() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        page.glyphs += [
            PDFGlyph(text: "架空秘密科目", x: 108, y: 110, width: 8, height: 6, sourceLine: 800, sourceOrder: 9000),
            PDFGlyph(text: "架空秘密教員", x: 111, y: 110, width: 2, height: 6, sourceLine: 801, sourceOrder: 9010)
        ]
        var captured: PDFParseError?
        XCTAssertThrowsError(try parse([page], kind: .timetable)) { captured = $0 as? PDFParseError }
        let failure = try XCTUnwrap(captured)
        XCTAssertEqual(failure.stage, .fragmentOverlap)
        XCTAssertEqual(failure.page, 1)
        XCTAssertEqual(failure.cell?.classRow, 1)
        let geometry = try XCTUnwrap(failure.geometry)
        XCTAssertEqual(geometry.width, 40)
        XCTAssertEqual(geometry.height, 60)
        XCTAssertEqual(geometry.glyphs.map(\.line), [0, 1])
        XCTAssertEqual(geometry.glyphs.map(\.order), [0, 1])
        let report = try XCTUnwrap(failure.diagnosticReport)
        XCTAssertTrue(report.hasPrefix("TAKUPOKE-PDF-GEOMETRY-1\n"))
        for excluded in ["架空", "秘密", "synthetic.pdf", "synthetic-digest", "9000", "9010"] {
            XCTAssertFalse(report.contains(excluded))
        }
        let data = Data(report.split(separator: "\n", maxSplits: 1)[1].utf8)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["code", "page", "stage", "cell", "geometry"])
        let geometryJSON = try XCTUnwrap(json["geometry"] as? [String: Any])
        XCTAssertEqual(Set(geometryJSON.keys), ["parserVersion", "width", "height", "totalGlyphs", "glyphs"])
        let glyphJSON = try XCTUnwrap(geometryJSON["glyphs"] as? [[String: Any]])
        XCTAssertTrue(glyphJSON.allSatisfy { Set($0.keys) == ["line", "order", "x", "y", "width", "height"] })
        let restored = try JSONDecoder().decode(PDFParseError.self, from: data)
        XCTAssertEqual(restored, failure)

        // Reproduce the position/order check using placeholders only.
        let glyphs = geometry.glyphs.map {
            PDFGlyph(text: "□", x: $0.x, y: $0.y, width: $0.width, height: $0.height, sourceLine: $0.line, sourceOrder: $0.order)
        }
        let grid = PDFGrid(page: PDFPageLayout(width: geometry.width, height: geometry.height, glyphs: glyphs, lines: []))
        XCTAssertThrowsError(try grid.timetableText(PDFBox(left: 0, top: 0, right: geometry.width, bottom: geometry.height))) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, failure.stage)
        }
    }
    func testGeometryDiagnosticHasBoundedSize() throws {
        let glyphs = (0..<300).map {
            PDFGlyph(text: "架空文字", x: Double($0), y: 10, width: 2, height: 5, sourceLine: 50, sourceOrder: 1000 + $0)
        }
        let snapshot = PDFCellGeometryDiagnostic(glyphs, box: PDFBox(left: 0, top: 0, right: 700, bottom: 40))
        XCTAssertEqual(snapshot.totalGlyphs, 300)
        XCTAssertEqual(snapshot.glyphs.count, PDFCellGeometryDiagnostic.maximumGlyphs)
        XCTAssertEqual(snapshot.glyphs.last?.order, 255)
        XCTAssertLessThan(try JSONEncoder().encode(snapshot).count, 40_000)
    }
    func testCloseCalendarLinesKeepTheirOrderAndExplicitTags() throws {
        var first = calendar(Array(4...9))
        first.glyphs.removeAll { $0.x >= 62 && $0.x < 100 && $0.cy == 100 }
        for (row, value) in ["架空公開日", "【金曜日授業】"].enumerated() {
            for (i, character) in value.enumerated() {
                first.glyphs.append(PDFGlyph(text: String(character), x: 63 + Double(i) * 3,
                    y: 96 + Double(row), width: 3, height: 4, sourceLine: row, sourceOrder: 100 + row * 50 + i))
            }
        }
        let result = try parse([first, calendar([10, 11, 12, 1, 2, 3])], kind: .events)
        let event = try XCTUnwrap(result.events.first { $0.date == "2032-04-02" && $0.scope == "共通" })
        XCTAssertEqual(event.title, "架空公開日\n【金曜日授業】")
        XCTAssertEqual(event.classification?.type, .weekdayOverride)
        XCTAssertEqual(event.classification?.scheduleDay, 5)
        let winter = try XCTUnwrap(result.events.first { $0.title == "冬季休業" })
        XCTAssertEqual(winter.classification?.type, .noClass)
        XCTAssertEqual(winter.endDate, "2033-01-04")
    }
    func testAmbiguousSourceOrderStopsInsteadOfFallingBackToCoordinates() throws {
        let a = PDFGlyph(text: "架", x: 10, y: 10, width: 5, height: 6, sourceLine: 0, sourceOrder: 1)
        var b = a; b.text = "空"
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
        b.sourceOrder = nil
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
        b.sourceOrder = 2; b.sourceLine = nil
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
    }
    func testTagsUseOnlyExplicitDeclarationsAndFlagConflicts() throws {
        for title in ["休業日", "臨時休業", "夏季休業（8/8まで）", "冬季休業\n架空連絡", "春分の日", "子どもの日", "振替休日"] {
            XCTAssertEqual(PDFEventClassification.fromExplicitText(title).type, .noClass)
        }
        for title in ["架空試験", "架空式典", "休業ではありません", "冬季休業の説明会", "月曜日授業ではありません", "文化の日の説明会", "補講日の相談会", "体育大会の説明会"] {
            let result = PDFEventClassification.fromExplicitText(title)
            XCTAssertEqual(result.type, .special)
            XCTAssertNil(result.scheduleDay)
        }
        XCTAssertEqual(PDFEventClassification.fromExplicitText("補講日").type, .supplementary)
        for title in ["体育祭", "体育大会", "冬季体育大会", "文化祭", "文化祭準備日", "体育祭準備", "総合文化祭", "電波祭準備", "臨時休業\n文化祭"] {
            let tag = PDFEventClassification.fromExplicitText(title)
            XCTAssertEqual(tag.type, .schoolEventNoClass)
            XCTAssertFalse(tag.needsReview)
        }
        for title in ["休業日\n【火曜日授業】", "【火曜日授業】【金曜日授業】"] {
            let result = PDFEventClassification.fromExplicitText(title)
            XCTAssertEqual(result.type, .special)
            XCTAssertTrue(result.needsReview)
            XCTAssertNil(result.scheduleDay)
        }
        let old = try JSONDecoder().decode(PDFSchoolEvent.self,
            from: Data(#"{"date":"2032-05-06","scope":"共通","title":"架空行事","page":1,"periodNeedsReview":false}"#.utf8))
        XCTAssertNil(old.classification)
    }
    func testCalendarScopesDatesPeriodsAndYearBoundary() throws {
        let result = try parse([calendar(Array(4...9)), calendar([10, 11, 12, 1, 2, 3])], kind: .events)
        XCTAssertEqual(result.version, PDFAnalysis.currentVersion(for: .events))
        XCTAssertEqual(result.version, 4)
        XCTAssertEqual(result.schoolYear, 2032)
        XCTAssertFalse(result.events.contains { $0.title.contains("対象外") || $0.title == "9" })
        let winter = try XCTUnwrap(result.events.first { $0.title == "冬季休業" })
        XCTAssertEqual(winter.date, "2032-12-25")
        XCTAssertEqual(winter.endDate, "2033-01-04")
        XCTAssertEqual(winter.periodEvidence, "矢印")
        XCTAssertFalse(winter.periodNeedsReview)
        let summer = try XCTUnwrap(result.events.first { $0.title.hasPrefix("夏季休業") })
        XCTAssertEqual(summer.date, "2032-06-10")
        XCTAssertEqual(summer.endDate, "2032-06-19")
        XCTAssertTrue(result.events.contains { $0.date == "2033-03-02" && $0.scope == "共通" })
    }
    func testUnknownPeriodIsExplicitAndUnsupportedInputStops() throws {
        var second = calendar([10, 11, 12, 1, 2, 3])
        second.arrows = []
        let result = try parse([calendar(Array(4...9)), second], kind: .events)
        let winter = try XCTUnwrap(result.events.first { $0.title == "冬季休業" })
        XCTAssertNil(winter.endDate)
        XCTAssertTrue(winter.periodNeedsReview)
        var ambiguous = calendar([10, 11, 12, 1, 2, 3])
        // Two continuations must not silently shorten a cross-month period.
        ambiguous.arrows?.append(PDFArrow(x: 600, top: 72, bottom: 170))
        let ambiguousResult = try parse([calendar(Array(4...9)), ambiguous], kind: .events)
        let ambiguousWinter = try XCTUnwrap(ambiguousResult.events.first { $0.title == "冬季休業" })
        XCTAssertNil(ambiguousWinter.endDate)
        XCTAssertTrue(ambiguousWinter.periodNeedsReview)
        var broken = timetable()
        broken.lines = []
        XCTAssertThrowsError(try parse([broken], kind: .timetable))
        XCTAssertThrowsError(try parse([calendar(Array(4...9)), calendar(Array(4...9))], kind: .events))
        XCTAssertThrowsError(try PDFSchoolParser.parse([timetable()], kind: .timetable, digest: "d", name: "n") {
            throw PDFParseError(code: .cancelled)
        }) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
    }
    func testConflictingPeriodAndMismatchedYearAreNotAccepted() throws {
        var first = calendar(Array(4...9))
        first.arrows?.append(PDFArrow(x: 430, top: 253, bottom: 470))
        let result = try parse([first, calendar([10, 11, 12, 1, 2, 3])], kind: .events)
        let summer = try XCTUnwrap(result.events.first { $0.title.hasPrefix("夏季休業") })
        XCTAssertNil(summer.endDate)
        XCTAssertTrue(summer.periodNeedsReview)
        var otherYear = calendar([10, 11, 12, 1, 2, 3])
        let digit = try XCTUnwrap(otherYear.glyphs.firstIndex { $0.cy == 20 && $0.text == "4" })
        otherYear.glyphs[digit].text = "5"
        XCTAssertThrowsError(try parse([first, otherYear], kind: .events))
    }
    func testDamagedClassAndUnalignedParallelFieldsStopWholeTable() throws {
        var damaged = timetable()
        let label = try XCTUnwrap(damaged.glyphs.firstIndex { $0.cx > 50 && $0.cx < 100 && $0.text == "Y" })
        damaged.glyphs[label].text = "?"
        XCTAssertThrowsError(try parse([damaged], kind: .timetable))
        var parallel = timetable()
        parallel.glyphs.removeAll { $0.cy == 208 && $0.text == "・" }
        XCTAssertThrowsError(try parse([parallel], kind: .timetable))
    }
    func testFailureStagesSurvivePageWrappingAndContainNoSourceText() throws {
        func assertFailure(_ pages: [PDFPageLayout], kind: MaterialKind, page: Int,
                           stage: PDFParseError.Stage, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try parse(pages, kind: kind), file: file, line: line) { error in
                guard let failure = error as? PDFParseError else { return XCTFail("Unexpected error type", file: file, line: line) }
                XCTAssertEqual(failure.page, page, file: file, line: line)
                XCTAssertEqual(failure.stage, stage, file: file, line: line)
                XCTAssertTrue(failure.localizedDescription.contains(stage.label), file: file, line: line)
                XCTAssertFalse(failure.localizedDescription.contains("架空"), file: file, line: line)
            }
        }
        var missingYear = timetable()
        missingYear.glyphs.removeAll { $0.cy == 20 }
        assertFailure([missingYear], kind: .timetable, page: 1, stage: .yearHeading)
        var missingPeriod = timetable()
        missingPeriod.glyphs.removeAll { $0.cy == 70 }
        assertFailure([missingPeriod], kind: .timetable, page: 1, stage: .periodHeading)
        var missingGrid = timetable()
        missingGrid.lines = []
        assertFailure([missingGrid], kind: .timetable, page: 1, stage: .gridCell)
        var missingColumns = calendar([10, 11, 12, 1, 2, 3])
        missingColumns.glyphs.removeAll { $0.text == "詫" }
        assertFailure([calendar(Array(4...9)), missingColumns], kind: .events, page: 2, stage: .eventColumns)
        var missingDates = calendar([10, 11, 12, 1, 2, 3])
        missingDates.glyphs.removeAll { $0.cy > 70 && $0.x < 30 }
        assertFailure([calendar(Array(4...9)), missingDates], kind: .events, page: 2, stage: .calendarDates)
    }
    func testOldFailureDecodesAndNewFailureRetainsOnlyFixedDiagnostic() throws {
        let old = try JSONDecoder().decode(PDFParseError.self, from: Data(#"{"code":"unsupported","page":1}"#.utf8))
        XCTAssertNil(old.stage)
        XCTAssertNil(old.geometry)
        XCTAssertNil(old.diagnosticReport)
        for stage in PDFParseError.Stage.allCases {
            let failure = PDFParseError(code: .unsupported, page: 2, stage: stage)
            XCTAssertEqual(try JSONDecoder().decode(PDFParseError.self, from: JSONEncoder().encode(failure)), failure)
            XCTAssertTrue(failure.localizedDescription.contains("前回の正常な解析結果は保持しています"))
        }
    }
    func testPDFFailureReplacementAndManifestRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var reject = false
        let library = try MaterialLibrary(root: root) { data, url in
            if reject { throw PDFParseError(code: .storage) }
            try data.write(to: url, options: .atomic)
        }
        func acquire(_ digest: String) throws {
            let url = library.newStagingURL()
            let data = Data("%PDF-synthetic".utf8)
            try data.write(to: url)
            try library.commit(staged: url, kind: .timetable, source: MaterialSource(), originalName: "synthetic.pdf",
                               byteCount: data.count, digest: digest, modifiedAt: nil)
        }
        try acquire("synthetic-digest")
        let good = try parse([timetable()], kind: .timetable)
        var old = good
        old.version = 1
        try library.savePDFAnalysis(old)
        let legacy = try MaterialLibrary(root: root)
        XCTAssertEqual(legacy.state.pdfAnalyses?["timetable"]?.version, 1)
        XCTAssertEqual(legacy.state.pdfAnalyses?["timetable"]?.lessons, old.lessons)
        try acquire("replacement")
        let failure = PDFParseError(code: .ambiguous, page: 1, stage: .fragmentOverlap,
            cell: PDFParseError.Cell(classRow: 1, weekday: 2, period: 3),
            geometry: PDFCellGeometryDiagnostic([
                PDFGlyph(text: "架空秘密", x: 10, y: 10, width: 5, height: 6, sourceLine: 5, sourceOrder: 20)
            ], box: PDFBox(left: 0, top: 0, right: 40, bottom: 60)))
        try library.recordPDFFailure(failure, kind: .timetable)
        XCTAssertEqual(try MaterialLibrary(root: root).state.pdfParseAttempts?["timetable"]?.failure, failure)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        let manifest = root.appendingPathComponent("library.json")
        let before = try Data(contentsOf: manifest)
        var next = good; next.sourceDigest = "replacement"
        reject = true
        XCTAssertThrowsError(try library.savePDFAnalysis(next))
        XCTAssertEqual(try Data(contentsOf: manifest), before)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.version, 1)
        reject = false
        try library.savePDFAnalysis(next)
        let reopened = try MaterialLibrary(root: root)
        XCTAssertEqual(reopened.state.pdfAnalyses?["timetable"]?.sourceDigest, "replacement")
        XCTAssertEqual(reopened.state.pdfAnalyses?["timetable"]?.version, PDFAnalysis.parserVersion)
        XCTAssertNil(reopened.state.pdfParseAttempts?["timetable"]?.failure)
    }
}

#if canImport(PDFKit)
extension PDFParsingTests {
    func testPDFKitTextSelectionsStayAlignedAcrossSpacesLinesAndRotations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let labels: [(String, CGFloat, CGFloat)] = [("AB CD", 30, 360), ("EF GH", 150, 260), ("IJ KL", 50, 110)]
        for (text, x, y) in labels {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]) as CFAttributedString)
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }
        context.move(to: CGPoint(x: 10, y: 20))
        context.addLine(to: CGPoint(x: 290, y: 20))
        context.strokePath()
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic-lines.pdf")
        try (data as Data).write(to: url)
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        let nativePage = try XCTUnwrap(document.page(at: 0))
        XCTAssertTrue(try XCTUnwrap(nativePage.string).contains("\n"))
        for kind in [MaterialKind.timetable, .events] {
            nativePage.rotation = 0
            try XCTUnwrap(document.dataRepresentation()).write(to: url)
            let original = try XCTUnwrap(PDFKitReader.read(url, kind: kind).first)
            XCTAssertEqual(PDFGrid.rows(original.glyphs).map { $0.map(\.text).joined() }, ["ABCD", "EFGH", "IJKL"])
            XCTAssertEqual(try PDFGrid.contentRows(original.glyphs).map { $0.map(\.text).joined() }, ["ABCD", "EFGH", "IJKL"])
            XCTAssertTrue(original.glyphs.allSatisfy { $0.sourceLine != nil && $0.sourceOrder != nil })
            for (text, x, y) in labels {
                let first = try XCTUnwrap(original.glyphs.first { $0.text == String(text.prefix(1)) })
                XCTAssertEqual(first.x, Double(x), accuracy: 2)
                XCTAssertTrue((Double(400 - y) - 14...Double(400 - y) + 3).contains(first.cy))
            }
            for rotation in [90, 180, 270] {
                nativePage.rotation = rotation
                try XCTUnwrap(document.dataRepresentation()).write(to: url)
                let rotated = try XCTUnwrap(PDFKitReader.read(url, kind: kind).first)
                XCTAssertEqual(rotated.glyphs.count, original.glyphs.count)
                for before in original.glyphs {
                    let after = try XCTUnwrap(rotated.glyphs.first { $0.text == before.text })
                    let expected: (Double, Double)
                    switch rotation {
                    case 90: expected = (400 - before.cy, before.cx)
                    case 180: expected = (300 - before.cx, 400 - before.cy)
                    default: expected = (before.cy, 300 - before.cx)
                    }
                    XCTAssertEqual(after.cx, expected.0, accuracy: 1)
                    XCTAssertEqual(after.cy, expected.1, accuracy: 1)
                }
            }
        }
    }
    func testPDFKitBridgeRecognizesFilledArrowGeometry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Synthetic",
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]) as CFAttributedString)
        context.textPosition = CGPoint(x: 10, y: 380)
        CTLineDraw(line, context)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.addRect(CGRect(x: 99.7, y: 251, width: 0.6, height: 49))
        context.move(to: CGPoint(x: 97, y: 252))
        context.addLine(to: CGPoint(x: 100, y: 246))
        context.addLine(to: CGPoint(x: 103, y: 252))
        context.closePath()
        context.fillPath()
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic-arrow.pdf")
        try (data as Data).write(to: url)
        let result = try PDFKitReader.read(url, kind: .events)
        let arrow = try XCTUnwrap(result.first?.arrows?.first)
        XCTAssertEqual(arrow.x, 100, accuracy: 0.1)
        XCTAssertEqual(arrow.top, 100, accuracy: 0.1)
        XCTAssertEqual(arrow.bottom, 154, accuracy: 0.1)
    }
    func testPDFKitBridgeReadsSyntheticPDFAndRotation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let page = timetable()
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: page.width, height: page.height)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(0.4)
        for line in page.lines {
            context.move(to: CGPoint(x: line.x1, y: page.height - line.y1))
            context.addLine(to: CGPoint(x: line.x2, y: page.height - line.y2))
            context.strokePath()
        }
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 6, nil)
        for glyph in page.glyphs {
            let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph.text, attributes: attributes) as CFAttributedString)
            context.textPosition = CGPoint(x: glyph.x, y: page.height - glyph.cy - 2)
            CTLineDraw(line, context)
        }
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic.pdf")
        try (data as Data).write(to: url)
        let normal = try PDFKitReader.read(url, kind: .timetable)
        let parsed = try parse(normal, kind: .timetable)
        XCTAssertEqual(parsed.lessons.count, 8)
        XCTAssertEqual(Set(parsed.lessons.map(\.names.subject)), ["架空科目Q", "架空X", "架空Y", "架空科目Z"])
        let independent = try XCTUnwrap(parsed.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(independent.names.teacher, "架空教員Q")
        XCTAssertEqual(independent.names.room, "架空室Q")
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        try XCTUnwrap(document.page(at: 0)).rotation = 90
        try XCTUnwrap(document.dataRepresentation()).write(to: url)
        let rotated = try PDFKitReader.read(url, kind: .timetable)
        XCTAssertEqual(rotated[0].width, normal[0].height, accuracy: 0.1)
        XCTAssertEqual(rotated[0].height, normal[0].width, accuracy: 0.1)
        let before = try XCTUnwrap(normal[0].glyphs.first { $0.text == "令" })
        let after = try XCTUnwrap(rotated[0].glyphs.first { $0.text == "令" })
        XCTAssertEqual(after.cx, normal[0].height - before.cy, accuracy: 1)
        XCTAssertEqual(after.cy, before.cx, accuracy: 1)
        XCTAssertFalse(rotated[0].lines.isEmpty)
    }
}
#endif
