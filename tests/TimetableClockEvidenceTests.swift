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
