import XCTest
@testable import TakupokeParsing

final class HomeScheduleTests: XCTestCase {
    private let day = SchoolDate(iso8601: "2032-04-05")!
    private let fixtureClass = "1_ZZ"

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func timetable(term: String? = "前期") -> PDFAnalysis {
        PDFAnalysis(kind: .timetable, sourceDigest: "fictional", sourceName: "fictional.pdf",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: term,
            lessons: (1...2).map { PDFLesson(className: fixtureClass, weekday: 1, period: $0,
                names: TimetableLessonNames(subject: "架空科目A", teacher: "架空教員A", room: "架空教室A"),
                sourceText: "", page: 1) }, events: [], notices: [])
    }
    private func events(_ tag: String) -> PDFAnalysis {
        PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil, lessons: [],
            events: [PDFSchoolEvent(date: day.iso8601, scope: "全クラス", title: "架空行事A", page: 0,
                classification: .init(type: tag == "授業なし" ? .noClass : .special), apiTag: tag)], notices: [])
    }
    private func change(note: String = "補講") -> ScheduleChange {
        ScheduleChange(change_date: day.iso8601, class_name: fixtureClass, period: "1,2",
            before_subject: "架空科目A", after_subject: "架空科目B", teacher: "架空教員B",
            room: "架空教室B", note: note, raw_text: "", canonical_text: "")
    }
    private func changes(_ rows: [ScheduleChange]) -> ChangeAnalysis {
        ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032,
                       parsedAt: Date(timeIntervalSince1970: 0), records: rows)
    }
    private func special(_ kind: SpecialScheduleKind) -> SpecialScheduleAnalysis {
        SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032,
            coveredDates: [day.iso8601, day.addingDays(1)!.iso8601], coveredClasses: [fixtureClass],
            periodTimes: [1: "09:10〜09:30", 2: "09:30〜09:50"],
            lessons: (1...2).map { SpecialScheduleLesson(date: day.iso8601, className: fixtureClass,
                period: $0, spanStart: 1, spanEnd: 2, timeRange: "09:10〜09:50",
                lines: ["架空科目C", "架空教員C", "架空教室C"], page: 1) })
    }

    func testJapaneseDayAtMidnightAndWeekendWeek() {
        XCTAssertEqual(TimetableDaySchedule.schoolDay(at: date("2032-04-04T14:59:59Z")).iso8601, "2032-04-04")
        XCTAssertEqual(TimetableDaySchedule.schoolDay(at: date("2032-04-04T15:00:00Z")), day)
        let sunday = SchoolDate(iso8601: "2032-04-11")!
        XCTAssertEqual(sunday.monday, day)
        XCTAssertNotEqual(sunday.monday, sunday.displayWeekStart)
    }

    func testAllDayKeepsEndedMergedLessonsAndChecksExactClockBoundaries() throws {
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([]), events: nil,
                                            specials: [], includesChanges: true)
        let blocks = schedule.blocks(on: day, className: fixtureClass, international: false)
        XCTAssertEqual(blocks.count, 1)
        let block = try XCTUnwrap(blocks.first)
        XCTAssertEqual(block.endPeriod, 2)
        XCTAssertEqual(schedule.cardTime(block, on: day, className: fixtureClass), "08:50〜10:20")
        for (time, expected) in [("08:49:59", false), ("08:50:00", true), ("10:19:59", true), ("10:20:00", false)] {
            XCTAssertEqual(schedule.isInProgress(block, on: day, className: fixtureClass,
                now: date("2032-04-05T\(time)+09:00")), expected)
        }
        XCTAssertFalse(schedule.isInProgress(block, on: day, className: fixtureClass,
            now: date("2032-04-06T09:00:00+09:00")))
        XCTAssertEqual(schedule.blocks(on: day, className: fixtureClass, international: false).count, 1)
    }

    func testChangesWinAndCancellationIsNeverInProgress() throws {
        let cancelled = change(note: "休講")
        let makeup = change()
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([cancelled, makeup]),
                                            events: nil, specials: [], includesChanges: true)
        let block = try XCTUnwrap(schedule.blocks(on: day, className: fixtureClass, international: false).first)
        guard case .change(let visible) = block.content else { return XCTFail("Expected change") }
        XCTAssertEqual(visible, makeup)
        XCTAssertTrue(schedule.isInProgress(block, on: day, className: fixtureClass,
                                            now: date("2032-04-05T09:00:00+09:00")))
        let cancellation = TimetableSchedule.GridBlock(startPeriod: 1, endPeriod: 2, content: .change(cancelled))
        XCTAssertFalse(schedule.isInProgress(cancellation, on: day, className: fixtureClass,
                                             now: date("2032-04-05T09:00:00+09:00")))
        let normalMode = TimetableDaySchedule(timetable: timetable(), changes: changes([makeup]), events: nil,
                                              specials: [], includesChanges: false)
        guard case .normal = try XCTUnwrap(normalMode.blocks(on: day, className: fixtureClass, international: false).first).content
        else { return XCTFail("Expected normal mode to remain independent") }
    }

    func testExamAndReturnKeepOwnTimesIncludingReplacements() throws {
        for kind in SpecialScheduleKind.allCases {
            let source = special(kind)
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([]), events: nil,
                                                specials: [source], includesChanges: true)
            let block = try XCTUnwrap(schedule.blocks(on: day, className: fixtureClass, international: false).first)
            XCTAssertEqual(block.endPeriod, 2)
            XCTAssertEqual(schedule.cardTime(block, on: day, className: fixtureClass), "09:10〜09:50")
            let updated = TimetableDaySchedule(timetable: timetable(), changes: changes([change()]), events: nil,
                                               specials: [source], includesChanges: true)
            let replacement = try XCTUnwrap(updated.blocks(on: day, className: fixtureClass, international: false).first)
            XCTAssertEqual(updated.cardTime(replacement, on: day, className: fixtureClass), "09:10〜09:50")
            XCTAssertFalse(updated.isInProgress(replacement, on: day, className: fixtureClass,
                                                now: date("2032-04-05T09:00:00+09:00")))
        }
        let returnSource = special(.examReturn)
        XCTAssertEqual(returnSource.periodTime(on: day.addingDays(1)!.iso8601, period: 1), "08:50〜09:35")
    }

    func testMissingExamNeverBorrowsNormalClockAndWarnsEvenWithChanges() throws {
        for tag in ["テスト", "テスト返却"] {
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([change()]),
                                                events: events(tag), specials: [], includesChanges: true)
            let block = try XCTUnwrap(schedule.blocks(on: day, className: fixtureClass, international: false).first)
            XCTAssertNil(schedule.cardTime(block, on: day, className: fixtureClass))
            XCTAssertFalse(schedule.isInProgress(block, on: day, className: fixtureClass,
                                                now: date("2032-04-05T09:00:00+09:00")))
            XCTAssertEqual(schedule.missingMessages(on: day, className: fixtureClass).count, 1)
        }
    }

    func testMissingTermClassAndNoClassEventAreDistinct() {
        for source in [nil, timetable(term: nil), timetable(term: "後期")] {
            let schedule = TimetableDaySchedule(timetable: source, changes: changes([]), events: nil,
                                                specials: [], includesChanges: true)
            XCTAssertFalse(schedule.missingMessages(on: day, className: fixtureClass).isEmpty)
        }
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([]), events: nil,
                                            specials: [], includesChanges: true)
        XCTAssertFalse(schedule.missingMessages(on: day, className: "2_ZZ").isEmpty)
        let holiday = TimetableDaySchedule(timetable: nil, changes: changes([]), events: events("授業なし"),
                                           specials: [], includesChanges: true)
        XCTAssertTrue(holiday.missingMessages(on: day, className: fixtureClass).isEmpty)
        XCTAssertTrue(holiday.blocks(on: day, className: fixtureClass, international: false).isEmpty)
    }

    func testMappedInternationalSubjectFilterIsShared() {
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([]), events: nil,
                                            specials: [], includesChanges: true)
        let match: (String, String) -> Bool = { $0 == "架空科目A" && $1 == "1_ZZ" }
        XCTAssertTrue(schedule.blocks(on: day, className: fixtureClass, international: false, matchedByRule: match).isEmpty)
        XCTAssertEqual(schedule.blocks(on: day, className: fixtureClass, international: true, matchedByRule: match).count, 1)
    }
}
