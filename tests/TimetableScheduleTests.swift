import XCTest
@testable import TakupokeParsing

final class TimetableScheduleTests: XCTestCase {
    private func timetable(term: String?) -> PDFAnalysis {
        PDFAnalysis(kind: .timetable, sourceDigest: "fictional", sourceName: "fictional.pdf",
                    parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: term,
                    lessons: [PDFLesson(className: "1_A", weekday: 1, period: 1,
                                        names: TimetableLessonNames(subject: "架空科目A"), sourceText: "架空科目A", page: 1)],
                    events: [], notices: [])
    }

    func testTermBoundariesAndUnknownTermNeverReuseOldLessons() throws {
        let first = timetable(term: "前期")
        XCTAssertEqual(TimetableSchedule.termRange(for: first)?.start.iso8601, "2032-04-01")
        XCTAssertTrue(try XCTUnwrap(TimetableSchedule.termRange(for: first)).contains(
            try XCTUnwrap(SchoolDate(iso8601: "2032-09-30"))))
        XCTAssertFalse(try XCTUnwrap(TimetableSchedule.termRange(for: first)).contains(
            try XCTUnwrap(SchoolDate(iso8601: "2032-10-01"))))
        let second = timetable(term: "後期")
        XCTAssertEqual(TimetableSchedule.termRange(for: second)?.endExclusive.iso8601, "2033-04-01")
        XCTAssertTrue(try XCTUnwrap(TimetableSchedule.termRange(for: second)).contains(
            try XCTUnwrap(SchoolDate(iso8601: "2033-03-31"))))
        let monday = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        XCTAssertEqual(TimetableSchedule.lessons(on: monday, className: "1_A", analysis: first).count, 1)
        XCTAssertTrue(TimetableSchedule.lessons(on: monday, className: "1_A", analysis: timetable(term: nil)).isEmpty)
    }

    func testChangeRangesUseDatesWithoutDiscardingPastRows() throws {
        func change(_ date: String) -> ScheduleChange {
            ScheduleChange(change_date: date, class_name: "1_A", period: "1", before_subject: "架空科目A",
                           after_subject: "架空科目B", teacher: "架空教員A", room: "架空教室A",
                           note: "", raw_text: "", canonical_text: "")
        }
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0),
                                      records: [change("2032-04-04"), change("2032-04-06"), change("2032-04-12")])
        let today = try XCTUnwrap(SchoolDate(iso8601: "2032-04-06"))
        let weekStart = today.monday
        XCTAssertEqual(TimetableSchedule.changes(in: analysis, className: "1_A", range: .today,
                                                 today: today, weekStart: weekStart).count, 2)
        XCTAssertEqual(TimetableSchedule.changes(in: analysis, className: "1_A", range: .week,
                                                 today: today, weekStart: weekStart).count, 1)
        XCTAssertEqual(TimetableSchedule.changes(in: analysis, className: "1_A", range: .all,
                                                 today: today, weekStart: weekStart).count, 3)
    }

    func testMergedSlotReplacesPeriodButRetainsOriginalForDetails() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        let change = ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: "1",
                                    before_subject: "別の記載", after_subject: "架空科目B",
                                    teacher: "架空教員B", room: "架空教室B", note: "", raw_text: "", canonical_text: "")
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change])
        let base = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                          timetable: timetable(term: "前期"), changes: analysis,
                                          includesChanges: false)
        XCTAssertEqual(base.displayedLessons.map(\.names.cellSubject), ["架空科目A"])
        let merged = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                            timetable: timetable(term: "前期"), changes: analysis,
                                            includesChanges: true)
        XCTAssertTrue(merged.displayedLessons.isEmpty)
        XCTAssertEqual(merged.changes.map(\.after_subject), ["架空科目B"])
        XCTAssertEqual(merged.baseLessons.map(\.names.detailSubject), ["架空科目A"])
    }
}
