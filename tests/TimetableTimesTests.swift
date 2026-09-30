import XCTest
@testable import TakupokeParsing

final class TimetableTimesTests: XCTestCase {
    private let day = SchoolDate(iso8601: "2032-04-05")!
    private func custom() -> TimetableTimes {
        TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601, periods: (1...8).map {
            .init(period: $0, start: String(format: "%02d:00", $0 + 7), end: String(format: "%02d:40", $0 + 7))
        })])
    }
    private func schedule(specials: [SpecialScheduleAnalysis] = []) -> TimetableDaySchedule {
        let pdf = PDFAnalysis(kind: .timetable, sourceDigest: "synthetic", sourceName: "fictional.pdf", parsedAt: Date(),
            schoolYear: 2032, term: "前期", lessons: (1...5).flatMap { weekday in
                (1...2).map { PDFLesson(className: "3_XY", weekday: weekday, period: $0,
                    names: .init(subject: "架空科目A"), sourceText: "", page: 1) }
            }, events: [], notices: [])
        return TimetableDaySchedule(timetable: pdf, changes: nil, events: nil, specials: specials,
                                    includesChanges: true, customTimes: custom())
    }
    func testDateSpecificTimeAndContinuousRange() throws {
        _ = try custom().validated()
        let s = schedule()
        XCTAssertEqual(s.normalTime(from: 1, to: 2, on: day), "08:00〜09:40")
        XCTAssertEqual(s.normalTime(from: 1, to: 1, on: day.addingDays(1)!), "08:50〜09:35")
        let block = s.blocks(on: day, className: "3_XY", international: false).first!
        XCTAssertEqual(s.cardTime(block, on: day, className: "3_XY"), "08:00〜09:40")
    }
    func testWeekColumnHidesConflictingClockAndIgnoresEmptyDays() {
        let s = schedule()
        XCTAssertEqual(s.commonPeriodTime(1, days: [day], classes: ["3_XY"], international: false), "08:00〜08:40")
        XCTAssertNil(s.commonPeriodTime(1, days: [day, day.addingDays(1)!], classes: ["3_XY"], international: false))
        XCTAssertEqual(s.commonPeriodTime(1, days: [day, day.addingDays(5)!], classes: ["3_XY"], international: false), "08:00〜08:40")
        XCTAssertNil(s.commonPeriodTime(8, days: [day], classes: ["3_XY"], international: false))
    }
    func testPDFClockHasPriorityOverAPIClock() {
        let lesson = SpecialScheduleLesson(date: day.iso8601, className: "3_XY", period: 1, spanStart: 1, spanEnd: 1,
            timeRange: "12:00〜12:30", lines: ["架空試験A"], page: 1)
        let pdf = SpecialScheduleAnalysis(kind: .exam, sourceDigest: "synthetic", sourceName: "fictional.pdf", parsedAt: Date(),
            schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: ["3_XY"],
            periodTimes: [1: "12:00〜12:30"], lessons: [lesson])
        let s = schedule(specials: [pdf])
        let slot = TimetableSchedule.slot(on: day, period: 1, className: "3_XY", timetable: s.timetable,
            changes: nil, includesChanges: true, events: nil, specials: [pdf])
        XCTAssertEqual(s.slotTime(slot, on: day, className: "3_XY", period: 1), "12:00〜12:30")
    }
    func testMalformedTimesAreRejected() {
        XCTAssertThrowsError(try TimetableTimes(schemaVersion: 2, days: []).validated())
        XCTAssertThrowsError(try TimetableTimes(schemaVersion: 1, days: [.init(date: "2032-02-30", periods: custom().days[0].periods)]).validated())
        XCTAssertThrowsError(try TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601, periods: [])]).validated())
        var periods = custom().days[0].periods
        periods[1] = .init(period: 2, start: "08:10", end: "08:20")
        XCTAssertThrowsError(try TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601, periods: periods)]).validated())
    }
}
