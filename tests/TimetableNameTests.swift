import Foundation
import XCTest
@testable import TakupokeParsing

final class TimetableNameTests: XCTestCase {
    func testPeriodTimeUsesThreeCenteredLines() {
        XCTAssertEqual(TimetableDisplayText.periodTime("08:50〜09:35"), "08:50\n～\n09:35")
        XCTAssertEqual(TimetableDisplayText.periodTime("08:50～09:35"), "08:50\n～\n09:35")
        XCTAssertEqual(TimetableDisplayText.periodTime("08:50~09:35"), "08:50\n～\n09:35")
    }

    func testHalfwidthKatakanaChangesOnlyAtPresentationBoundary() {
        let source = "架空ｶﾞｯｺｳ・第2室(ABC)／ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ"
        XCTAssertEqual(TimetableDisplayText.kana(source), "架空ガッコウ・第2室(ABC)／パピプペポ")
        XCTAssertEqual(source, "架空ｶﾞｯｺｳ・第2室(ABC)／ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ")
        XCTAssertEqual(TimetableDisplayText.continuous("架空\nｶﾞｯｺｳ"), "架空ガッコウ")
        XCTAssertEqual(TimetableDisplayText.kana("架空科目A／架空教室B"), "架空科目A／架空教室B")
        XCTAssertEqual(TimetableDisplayText.className("1_ES"), "1-ES")
        XCTAssertEqual(TimetableDisplayText.className("AI_2"), "AI-2")
        XCTAssertEqual(TimetableDisplayText.classNames(["1_1", "1_ES"]), "1-1・1-ES")
        XCTAssertEqual(TimetableDisplayText.halfwidthKana("架空ソフト室A"), "架空ｿﾌﾄ室A")
        XCTAssertEqual(TimetableDisplayText.halfwidthKana("架空ｶﾞｯﾂ室A"), "架空ｶﾞｯﾂ室A")
    }

    func testBothFormsSurviveSavingAndDisplayWithoutChangingSource() throws {
        let names = TimetableLessonNames(
            subject: "  架空科目QⅣ  ", teacher: "（架空教員Q）", room: " 架空室Z ",
            subjectFullName: "架空科目Qの正式名称Ⅳ", teacherFullName: "架空教員Qの正式名称",
            roomFullName: "架空室Zの正式名称（架空南棟7階）")
        let restored = try JSONDecoder().decode(TimetableLessonNames.self, from: JSONEncoder().encode(names))
        XCTAssertEqual(restored, names)
        XCTAssertEqual(restored.cellSubject, "架空科目QⅣ")
        XCTAssertEqual(restored.cellTeacher, "架空教員Q")
        XCTAssertEqual(restored.cellRoom, "架空室Z")
        XCTAssertEqual(restored.detailSubject, "架空科目Qの正式名称Ⅳ")
        XCTAssertEqual(restored.detailTeacher, "架空教員Qの正式名称")
        XCTAssertEqual(restored.detailRoom, "架空室Zの正式名称（架空南棟7階）")
        XCTAssertEqual(restored.subject, "  架空科目QⅣ  ")
        XCTAssertEqual(restored.teacher, "（架空教員Q）")
        XCTAssertEqual(restored.room, " 架空室Z ")
    }

    func testPartialMappingFallsBackIndependentlyForEachField() throws {
        // A source-only record can be decoded without any full-name keys.
        let source = Data(#"{"subject":"架空科目R","teacher":"架空教員R","room":"架空室Y"}"#.utf8)
        let names = try JSONDecoder().decode(TimetableLessonNames.self, from: source)
        XCTAssertNil(names.subjectFullName)
        XCTAssertEqual(names.detailSubject, "架空科目R")
        XCTAssertEqual(names.detailTeacher, "架空教員R")
        XCTAssertEqual(names.detailRoom, "架空室Y")

        let partiallyMapped = TimetableLessonNames(
            subject: names.subject, teacher: names.teacher, room: names.room,
            subjectFullName: " \n", teacherFullName: "架空教員Rの正式名称", roomFullName: "")
        XCTAssertEqual(partiallyMapped.detailSubject, "架空科目R")
        XCTAssertEqual(partiallyMapped.detailTeacher, "架空教員Rの正式名称")
        XCTAssertEqual(partiallyMapped.detailRoom, "架空室Y")
    }

    func testIndependentLessonsKeepMissingMetadataAfterRoundTrip() throws {
        // Independently invented records; no actual timetable rows or class layout.
        let lessons = [
            TimetableLessonNames(subject: "架空科目X", room: "架空室X"),
            TimetableLessonNames(subject: "架空科目Y", teacher: "架空教員Y"),
            TimetableLessonNames(subject: "架空科目Z", room: "架空室W",
                                 roomFullName: "架空室Wの正式名称（架空北棟8階）")
        ]
        let restored = try JSONDecoder().decode([TimetableLessonNames].self, from: JSONEncoder().encode(lessons))
        XCTAssertEqual(restored, lessons)
        XCTAssertEqual(restored.map(\.cellRoom), ["架空室X", "", "架空室W"])
        XCTAssertEqual(restored.map(\.detailRoom), ["架空室X", "", "架空室Wの正式名称（架空北棟8階）"])
        XCTAssertEqual(restored.map(\.detailTeacher), ["", "架空教員Y", ""])
    }
}
