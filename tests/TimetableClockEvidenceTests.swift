import XCTest
@testable import TakupokeParsing

final class TimetableClockEvidenceTests: XCTestCase {
    private let day = SchoolDate(iso8601: "2032-04-05")!
    private let cls = "1_ZZ"
    private func instant(_ clock: String) -> Date { ISO8601DateFormatter().date(from: "2032-04-05T\(clock):00+09:00")! }
    private func source(_ kind: SpecialScheduleKind, recorded: String? = "08:50〜10:20", known: Bool = true) -> SpecialScheduleAnalysis {
        SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032,
            coveredDates: [day.iso8601], coveredClasses: [cls],
            periodTimes: known ? [1: "08:50〜09:35", 2: "09:50〜10:35"] : [:],
            lessons: (1...2).map { SpecialScheduleLesson(date: day.iso8601, className: cls, period: $0, spanStart: 1, spanEnd: 2,
                timeRange: recorded, lines: ["架空科目A", "架空教員A", "架空教室A"], page: 1) }, dedicatedTimeDate: kind == .examReturn ? day.iso8601 : nil)
    }
    private func schedule(_ sources: [SpecialScheduleAnalysis], periods: String, teacherOnly: Bool = false) -> TimetableDaySchedule {
        let row = ScheduleChange(change_date: day.iso8601, class_name: cls, period: periods, before_subject: "架空科目A",
            after_subject: teacherOnly ? "架空科目A" : "架空科目B", teacher: "架空教員B", room: "架空教室A", note: "変更", raw_text: "架空原文", canonical_text: "架空正規化")
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: [row])
        return TimetableDaySchedule(timetable: nil, changes: analysis, events: nil, specials: sources, includesChanges: true)
    }
    func testChangeVisualMergesRespectBreaksAndLunchWithDefaultAndCustomClocks() throws {
        let custom = TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601, periods: [
            .init(period: 2, start: "09:40", end: "10:15"), .init(period: 3, start: "10:40", end: "11:10"),
            .init(period: 4, start: "11:20", end: "12:10"), .init(period: 5, start: "12:55", end: "13:45")])])
        _ = try custom.validated()
        for times in [nil, custom] as [TimetableTimes?] {
            for kind in ["変更", "補講"] {
                for (start, end, gap) in [(2, 3, "10:25"), (4, 5, "12:25")] {
                    let row = ScheduleChange(change_date: day.iso8601, class_name: cls, period: "\(start),\(end)", before_subject: "架空科目A", after_subject: "架空科目B", teacher: "", room: "", note: "架空備考", raw_text: "架空原文", canonical_text: "架空正規化", change_kind: kind)
                    let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: [row])
                    let s = TimetableDaySchedule(timetable: nil, changes: changes, events: nil, specials: [], includesChanges: true, customTimes: times)
                    let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first)
                    XCTAssertNotNil(s.cardTime(block, on: day, className: cls))
                    XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant(gap)))
                    let first = times?.time(on: day, period: start) ?? TimetableSchedule.normalPeriodTimes[start - 1]
                    let last = times?.time(on: day, period: end) ?? TimetableSchedule.normalPeriodTimes[end - 1]
                    XCTAssertTrue(s.isInProgress(block, on: day, className: cls, now: instant(first.components(separatedBy: "〜")[0])))
                    XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant(last.components(separatedBy: "〜")[1])))
                }
            }
        }
    }

    func testIndependentSpecialCellsKeepTheirGapWhenVisuallyMerged() throws {
        for kind in SpecialScheduleKind.allCases {
            let clocks = [1: "09:00〜09:20", 2: "09:30〜09:50"]
            let independent = SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: [cls], periodTimes: clocks,
                lessons: (1...2).map { SpecialScheduleLesson(date: day.iso8601, className: cls, period: $0, spanStart: $0, spanEnd: $0, timeRange: clocks[$0], lines: ["架空科目A", "架空教員A", "架空教室A"], page: 1) }, dedicatedTimeDate: kind == .examReturn ? day.iso8601 : nil)
            let s = TimetableDaySchedule(timetable: nil, changes: nil, events: nil, specials: [independent], includesChanges: true)
            let blocks = s.blocks(on: day, className: cls, international: false); XCTAssertEqual(blocks.count, 1)
            let block = try XCTUnwrap(blocks.first)
            XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant("09:25")))
            XCTAssertTrue(s.isInProgress(block, on: day, className: cls, now: instant("09:00")))
            XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant("09:50")))
            let joined = TimetableDaySchedule(timetable: nil, changes: nil, events: nil, specials: [source(kind, recorded: "09:00〜09:50")], includesChanges: true)
            let continuous = try XCTUnwrap(joined.blocks(on: day, className: cls, international: false).first)
            XCTAssertTrue(joined.isInProgress(continuous, on: day, className: cls, now: instant("09:25")))
        }
    }

    func testHiddenSpecialLessonDoesNotRemoveTheVisibleCommonClock() throws {
        func one(_ kind: SpecialScheduleKind, _ subject: String, _ time: String) -> SpecialScheduleAnalysis {
            SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: [cls], periodTimes: [1: time], lessons: [.init(date: day.iso8601, className: cls, period: 1, spanStart: 1, spanEnd: 1, timeRange: time, lines: [subject], page: 1)], dedicatedTimeDate: kind == .examReturn ? day.iso8601 : nil)
        }
        let exam = one(.exam, "留 架空試験科目A", "09:00〜09:40")
        let returns = one(.examReturn, "架空返却科目B", "10:00〜10:20")
        for sources in [[exam, returns], [returns, exam]] {
            let s = TimetableDaySchedule(timetable: nil, changes: nil, events: nil, specials: sources, includesChanges: true)
            XCTAssertEqual(s.blocks(on: day, className: cls, international: false).count, 1)
            XCTAssertEqual(s.commonPeriodTime(1, days: [day], classes: [cls], international: false), "10:00〜10:20")
            XCTAssertNil(s.commonPeriodTime(1, days: [day], classes: [cls], international: true))
        }
    }

    func testChangeClockRemainsUnknownWhenOneRequiredSpecialKindIsMissing() throws {
        let payload = SchoolEventsPayload(version: "v1", schoolYear: 2032, sourcePdfSha256: String(repeating: "a", count: 64), sourcePdfETag: nil,
            events: ["テスト", "テスト返却"].map { .init(startDate: day.iso8601, endDate: day.iso8601, title: "架空行事", tag: $0) })
        let events = try SchoolEventsPayload.decode(JSONEncoder().encode(payload), requestedYear: 2032).projectedEvents
        let calendar = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "架空行事API", parsedAt: Date(), schoolYear: 2032, term: nil, lessons: [], events: events, notices: [])
        for sources in [[source(.exam)], [source(.examReturn)], [source(.exam), source(.examReturn)]] {
            let base = schedule(sources, periods: "1")
            let s = TimetableDaySchedule(timetable: nil, changes: base.changes, events: calendar, specials: sources, includesChanges: true)
            let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first)
            XCTAssertEqual(s.cardTime(block, on: day, className: cls), sources.count == 2 ? "08:50〜09:35" : nil)
            XCTAssertEqual(s.commonPeriodTime(1, days: [day], classes: [cls], international: false), sources.count == 2 ? "08:50〜09:35" : nil)
            if sources.count == 1 {
                XCTAssertEqual(s.changeTimeRanges(base.changes!.records[0]), [nil])
                XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant("09:00")))
                let own = TimetableDaySchedule(timetable: nil, changes: nil, events: calendar, specials: sources, includesChanges: true)
                let known = try XCTUnwrap(own.blocks(on: day, className: cls, international: false).first)
                XCTAssertNotNil(own.cardTime(known, on: day, className: cls))
            }
        }
    }

    func testWholeSpecialReplacementPreservesRecordedContinuousClockAndDetailBoundaries() throws {
        for kind in SpecialScheduleKind.allCases {
            for teacherOnly in [false, true] {
                let s = schedule([source(kind)], periods: "1,2", teacherOnly: teacherOnly)
                let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first)
                XCTAssertEqual(s.cardTime(block, on: day, className: cls), "08:50〜10:20")
                XCTAssertEqual(s.changeTimeRanges(s.changes!.records[0]), ["08:50〜10:20"])
                for (clock, active) in [("08:49", false), ("08:50", true), ("09:40", true), ("10:19", true), ("10:20", false), ("10:25", false)] {
                    XCTAssertEqual(s.isInProgress(block, on: day, className: cls, now: instant(clock)), active)
                }
                XCTAssertEqual(s.commonPeriodTime(2, days: [day], classes: [cls], international: false), "09:50〜10:35")
            }
        }
    }
    func testPartialReplacementAndUnrecordedWholeRangeUseOnlyVerifiedPeriodClocks() throws {
        for kind in SpecialScheduleKind.allCases {
            for (periods, expected) in [("1", "08:50〜09:35"), ("2", "09:50〜10:35")] {
                let s = schedule([source(kind)], periods: periods)
                let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first { if case .change = $0.content { return true }; return false })
                XCTAssertEqual(s.cardTime(block, on: day, className: cls), expected)
            }
            let s = schedule([source(kind, recorded: nil)], periods: "1,2")
            let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first)
            XCTAssertEqual(s.cardTime(block, on: day, className: cls), "08:50〜10:35")
            XCTAssertTrue(s.isInProgress(block, on: day, className: cls, now: instant("10:25")))
        }
    }
    func testWholeReplacementRequiresEveryApplicableDocumentToAgree() throws {
        for sources in [[source(.exam), source(.examReturn)],
                        [source(.exam), source(.examReturn, recorded: "08:50〜10:30")],
                        [source(.exam), source(.examReturn, recorded: nil, known: false)]] {
            let s = schedule(sources, periods: "1,2")
            let block = try XCTUnwrap(s.blocks(on: day, className: cls, international: false).first)
            let equal = sources[0].lessons[0].timeRange == sources[1].lessons[0].timeRange
            XCTAssertEqual(s.cardTime(block, on: day, className: cls), equal ? "08:50〜10:20" : nil)
            if !equal { XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant("09:00"))) }
        }
    }
    func testNormalVisualMergesRespectBreaksAndLunchWithDefaultAndDateSpecificClocks() throws {
        let defaults = TimetableSchedule.normalPeriodTimes
        let api = TimetableTimes(schemaVersion: 1, days: [.init(date: day.iso8601, periods: defaults.enumerated().map { index, value in
            let parts = value.components(separatedBy: "〜")
            func shifted(_ value: String) -> String {
                let pieces = value.split(separator: ":").map { Int($0)! }
                let minutes = pieces[0] * 60 + pieces[1] + 5
                return String(format: "%02d:%02d", minutes / 60, minutes % 60)
            }
            return .init(period: index + 1, start: shifted(parts[0]), end: shifted(parts[1]))
        })])
        _ = try api.validated()
        for custom in [nil, api] as [TimetableTimes?] {
            for (first, last, gap, expected) in [(1, 2, "09:35", true), (2, 3, "10:25", false), (4, 5, "12:25", false)] {
                for sameNames in [true, false] {
                    let lessons = [first, last].map { period in PDFLesson(className: cls, weekday: 1, period: period,
                        names: .init(subject: sameNames || period == first ? "架空科目A" : "架空科目B"), sourceText: "架空原文", page: 1) }
                    let pdf = PDFAnalysis(kind: .timetable, sourceDigest: "fictional", sourceName: "fictional.pdf", parsedAt: Date(), schoolYear: 2032, term: "前期", lessons: lessons, events: [], notices: [])
                    let s = TimetableDaySchedule(timetable: pdf, changes: nil, events: nil, specials: [], includesChanges: true, customTimes: custom)
                    let blocks = s.blocks(on: day, className: cls, international: false)
                    XCTAssertEqual(blocks.count, sameNames ? 1 : 2)
                    XCTAssertEqual(blocks.contains { s.isInProgress($0, on: day, className: cls, now: instant(gap)) }, expected)
                    if let block = blocks.first {
                        XCTAssertTrue(s.isInProgress(block, on: day, className: cls, now: instant(custom?.time(on: day, period: first)?.components(separatedBy: "〜")[0] ?? defaults[first-1].components(separatedBy: "〜")[0])))
                        XCTAssertFalse(s.isInProgress(block, on: day, className: cls, now: instant(custom?.time(on: day, period: last)?.components(separatedBy: "〜")[1] ?? defaults[last-1].components(separatedBy: "〜")[1])))
                    }
                }
            }
        }
    }
}
