import XCTest
@testable import TakupokeParsing

final class HomeScheduleTests: XCTestCase {
    private func clockSource(_ kind: SpecialScheduleKind, clocks: [String], joined: Bool = false) -> SpecialScheduleAnalysis {
        SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional-\(kind.rawValue)", sourceName: "fictional.pdf",
            parsedAt: Date(), schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: [fixtureClass],
            periodTimes: Dictionary(uniqueKeysWithValues: clocks.enumerated().map { ($0.offset + 1, $0.element) }),
            lessons: clocks.enumerated().map { index, clock in
                SpecialScheduleLesson(date: day.iso8601, className: fixtureClass, period: index + 1,
                    spanStart: joined ? 1 : index + 1, spanEnd: joined ? clocks.count : index + 1,
                    timeRange: joined ? clocks.first!.components(separatedBy: "〜")[0] + "〜" + clocks.last!.components(separatedBy: "〜")[1] : clock,
                    lines: ["架空特別科目A", "架空教員A"], page: 1)
            })
    }

    func testOverlappingSpecialCardsRetainIndividualClocksAndProgressWhileCommonAndChangeStayAmbiguous() throws {
        let exam = clockSource(.exam, clocks: ["09:00〜09:40"])
        let returns = clockSource(.examReturn, clocks: ["10:00〜10:20"])
        for sources in [[exam], [returns], [exam, returns], [returns, exam], [exam, clockSource(.examReturn, clocks: ["09:00〜09:40"])]] {
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: nil, events: nil, specials: sources, includesChanges: true)
            let blocks = schedule.blocks(on: day, className: fixtureClass, international: false)
            XCTAssertEqual(blocks.count, sources.count)
            for block in blocks {
                guard case .special(let item) = block.content else { return XCTFail("Expected special card") }
                XCTAssertEqual(schedule.cardTime(block, on: day, className: fixtureClass), item.timeRange)
                XCTAssertEqual(schedule.isInProgress(block, on: day, className: fixtureClass, now: date("2032-04-05T09:10:00+09:00")), item.timeRange == "09:00〜09:40")
            }
            let ambiguous = sources.count == 2 && sources[0].periodTimes != sources[1].periodTimes
            let common = schedule.commonPeriodTime(1, days: [day], classes: [fixtureClass], international: false)
            XCTAssertEqual(common, ambiguous ? nil : sources[0].periodTimes[1])
            let replacement = TimetableSchedule.GridBlock(startPeriod: 1, endPeriod: 1, content: .change(change()))
            XCTAssertEqual(schedule.cardTime(replacement, on: day, className: fixtureClass), common)
        }
    }

    func testMergedSpecialCardClocksUseOnlyTheirOwnDocumentAndNeverBorrowMissingTimes() throws {
        for joined in [false, true] {
            let exam = clockSource(.exam, clocks: ["09:00〜09:20", "09:20〜09:40"], joined: joined)
            let returns = clockSource(.examReturn, clocks: ["10:00〜10:10", "10:10〜10:20"], joined: joined)
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: nil, events: nil, specials: [exam, returns], includesChanges: true)
            let blocks = schedule.blocks(on: day, className: fixtureClass, international: false)
            XCTAssertEqual(blocks.count, 2)
            for block in blocks {
                XCTAssertEqual(block.startPeriod, 1); XCTAssertEqual(block.endPeriod, 2)
                guard case .special(let item) = block.content else { return XCTFail("Expected special card") }
                XCTAssertEqual(schedule.cardTime(block, on: day, className: fixtureClass), item.kind == .exam ? "09:00〜09:40" : "10:00〜10:20")
            }
            XCTAssertEqual(schedule.changeTimeRanges(change()), [nil])
        }
        var missing = clockSource(.exam, clocks: ["09:00〜09:40", "09:40〜10:20"])
        missing = SpecialScheduleAnalysis(kind: missing.kind, sourceDigest: missing.sourceDigest, sourceName: missing.sourceName,
            parsedAt: missing.parsedAt, schoolYear: missing.schoolYear, coveredDates: missing.coveredDates, coveredClasses: missing.coveredClasses,
            periodTimes: [:], lessons: missing.lessons.map {
                SpecialScheduleLesson(date: $0.date, className: $0.className, period: $0.period, spanStart: $0.spanStart, spanEnd: $0.spanEnd, timeRange: nil, lines: $0.lines, page: $0.page)
            })
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: nil, events: nil,
            specials: [missing, clockSource(.examReturn, clocks: ["10:00〜10:10", "10:10〜10:20"])], includesChanges: true)
        let unknown = try XCTUnwrap(schedule.blocks(on: day, className: fixtureClass, international: false).first)
        XCTAssertNil(schedule.cardTime(unknown, on: day, className: fixtureClass))
    }


    func testFragmentsOfMergedSpecialsUseOnlyVerifiedIndividualClocks() throws {
        let clocks = ["08:50〜09:35", "09:50〜10:35", "10:50〜11:35"]
        for kind in SpecialScheduleKind.allCases {
            let source = clockSource(kind, clocks: clocks, joined: true)
            for replaced in [[], [1], [3], [2], [1, 3]] as [[Int]] {
                let rows = replaced.map { period -> ScheduleChange in
                    var row = change(); row.period = String(period); return row
                }
                let changed = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: rows)
                let schedule = TimetableDaySchedule(timetable: nil, changes: changed, events: nil, specials: [source], includesChanges: true)
                for block in schedule.blocks(on: day, className: fixtureClass, international: false) {
                    let expected = clocks[block.startPeriod-1].components(separatedBy: "〜")[0] + "〜" + clocks[block.endPeriod-1].components(separatedBy: "〜")[1]
                    XCTAssertEqual(schedule.cardTime(block, on: day, className: fixtureClass), expected)
                    if block.startPeriod > 1 { XCTAssertFalse(schedule.isInProgress(block, on: day, className: fixtureClass, now: date("2032-04-05T09:00:00+09:00"))) }
                }
                XCTAssertEqual(source.lessons.map(\.timeRange), Array(repeating: "08:50〜11:35", count: 3))
            }
            let missing = SpecialScheduleAnalysis(kind: source.kind, sourceDigest: source.sourceDigest, sourceName: source.sourceName, parsedAt: source.parsedAt, schoolYear: source.schoolYear, coveredDates: source.coveredDates, coveredClasses: source.coveredClasses, periodTimes: [:], lessons: source.lessons)
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: nil, events: nil, specials: [missing], includesChanges: true)
            let fragment = TimetableSchedule.GridBlock(startPeriod: 2, endPeriod: 2, content: .special(TimetableSchedule.SpecialItem(kind: kind, lesson: missing.lessons[1], timeRange: missing.lessons[1].timeRange)))
            XCTAssertNil(schedule.cardTime(fragment, on: day, className: fixtureClass))
            XCTAssertNil(schedule.commonPeriodTime(2, days: [day], classes: [fixtureClass], international: false))
        }
    }

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

    func testChangeDetailsJoinSeparateExamSlotsAndKeepDisjointPeriodsSeparate() {
        for kind in SpecialScheduleKind.allCases {
            let source = special(kind)
            let separate = SpecialScheduleAnalysis(kind: kind, sourceDigest: source.sourceDigest,
                sourceName: source.sourceName, parsedAt: source.parsedAt, schoolYear: source.schoolYear,
                coveredDates: source.coveredDates, coveredClasses: source.coveredClasses,
                periodTimes: source.periodTimes, lessons: (1...2).map { period in
                    SpecialScheduleLesson(date: day.iso8601, className: fixtureClass,
                        period: period, spanStart: period, spanEnd: period,
                        timeRange: source.periodTimes[period], lines: ["架空科目D"], page: 1)
                })
            let schedule = TimetableDaySchedule(timetable: timetable(), changes: changes([change()]),
                events: nil, specials: [separate], includesChanges: true)
            XCTAssertEqual(schedule.changeTimeRanges(change()), ["09:10〜09:50"])
        }
        let schedule = TimetableDaySchedule(timetable: timetable(), changes: nil, events: nil,
            specials: [], includesChanges: true)
        var disjoint = change()
        disjoint.period = "1,3"
        XCTAssertNil(disjoint.gridPeriods)
        XCTAssertEqual(schedule.changeTimeRanges(disjoint), ["08:50〜09:35", "10:30〜11:15"])
        disjoint.period = "1,1"
        XCTAssertTrue(schedule.changeTimeRanges(disjoint).isEmpty)
        let missing = TimetableDaySchedule(timetable: timetable(), changes: nil,
            events: events("テスト"), specials: [], includesChanges: true)
        XCTAssertEqual(missing.changeTimeRanges(change()).count, 1)
        XCTAssertNil(missing.changeTimeRanges(change())[0])
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
        let match: (String, String, Int?) -> Bool = { subject, className, _ in subject == "架空科目A" && className == "1_ZZ" }
        XCTAssertTrue(schedule.blocks(on: day, className: fixtureClass, international: false, matchedByRule: match).isEmpty)
        XCTAssertEqual(schedule.blocks(on: day, className: fixtureClass, international: true, matchedByRule: match).count, 1)
    }
}
