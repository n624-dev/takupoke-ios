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
}
