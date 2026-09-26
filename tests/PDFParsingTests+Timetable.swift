import Foundation
import XCTest
import ZIPFoundation
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

extension PDFParsingTests {
    func testTimetablePeriodsParallelLessonsAndEmptyRoom() throws {
        let result = try parse([timetable()], kind: .timetable)
        XCTAssertEqual(result.version, PDFAnalysis.currentVersion(for: .timetable))
        XCTAssertEqual(result.version, 8)
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
    func testTimetableRoomCollapsesOnlyRepeatedHalfwidthVoicingMarks() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        page.glyphs += text("架空科目ｶﾞﾞ", x: 104, y: 112)
        page.glyphs += text("架空担当ﾊﾟﾟ", x: 104, y: 130)
        page.glyphs += text("架空室ｶﾞﾞとﾊﾟﾟ", x: 104, y: 148)
        let parsed = try parse([page], kind: .timetable)
        let lesson = try XCTUnwrap(parsed.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.subject, "架空科目ｶﾞﾞ")
        XCTAssertEqual(lesson.names.teacher, "架空担当ﾊﾟﾟ")
        XCTAssertEqual(lesson.names.room, "架空室ｶﾞとﾊﾟ")
        XCTAssertEqual(lesson.sourceText, "架空科目ｶﾞﾞ\n架空担当ﾊﾟﾟ\n架空室ｶﾞﾞとﾊﾟﾟ")

        for (input, expected) in [
            ("架空室ｶﾞﾞﾞ", "架空室ｶﾞ"),
            ("架空室ﾊﾟﾟ", "架空室ﾊﾟ"),
            ("架空室ﾞﾞ", "架空室ﾞﾞ"),
            ("架空室ｶﾞﾟﾟ", "架空室ｶﾞﾟﾟ"),
            ("架空室ｶﾞXﾞﾞ", "架空室ｶﾞXﾞﾞ"),
            ("架空室か\u{3099}\u{3099}", "架空室か\u{3099}\u{3099}"),
        ] {
            XCTAssertEqual(PDFTimetableRoomText.collapsingRepeatedVoicingMarks(input), expected)
        }
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
    func testAmbiguousSourceOrderStopsInsteadOfFallingBackToCoordinates() throws {
        let a = PDFGlyph(text: "架", x: 10, y: 10, width: 5, height: 6, sourceLine: 0, sourceOrder: 1)
        var b = a; b.text = "空"
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
        b.sourceOrder = nil
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
        b.sourceOrder = 2; b.sourceLine = nil
        XCTAssertThrowsError(try PDFGrid.contentRows([a, b]))
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
}
