import Foundation
import XCTest
@testable import TakupokeParsing

final class CountdownTests: XCTestCase {
    private func day(_ value: String) -> SchoolDate { SchoolDate(iso8601: value)! }

    private func dates(_ title: String = "架空予定", _ first: String, _ last: String? = nil) -> CountdownDates {
        .init(title: title, ranges: [.init(start: day(first), end: day(last ?? first))])
    }

    func testJapaneseCalendarPhaseCoversLeapDayYearBoundaryAndSplitRanges() throws {
        let dates = CountdownDates(title: "架空の分割試験", ranges: [
            .init(start: day("2032-02-27"), end: day("2032-02-27")),
            .init(start: day("2032-03-01"), end: day("2032-03-02"))
        ])
        XCTAssertTrue(dates.valid)
        let before = try XCTUnwrap(day("2032-02-26").dateInJapan(hour: 23, minute: 59))
        XCTAssertEqual(dates.phase(on: TimetableDaySchedule.schoolDay(at: before)), .upcoming(1))
        XCTAssertEqual(dates.phase(on: TimetableDaySchedule.schoolDay(at: before.addingTimeInterval(60))), .firstDay)
        XCTAssertEqual(dates.phase(on: day("2032-02-29")), .inProgress)
        XCTAssertFalse(dates.ranges.contains { $0.start <= day("2032-02-29") && day("2032-02-29") <= $0.end })
        XCTAssertEqual(dates.phase(on: day("2032-03-02")), .lastDay)
        XCTAssertEqual(dates.phase(on: day("2032-03-03")), .finished)
        XCTAssertEqual(self.dates("架空予定", "2032-04-01").phase(on: day("2032-03-31")), .upcoming(1))
        XCTAssertEqual(self.dates("架空予定", "2032-01-01").phase(on: day("2032-01-01")), .today)
        XCTAssertEqual(day("2031-12-31").days(until: day("2032-01-02")), 2)
    }

    func testHomeFilteringAndProgressDoNotDependOnReservation() {
        let today = day("2032-03-26")
        var options = CountdownPreferences(showsOnHome: false, lookahead: .week, notifications: true)
        let hidden = CountdownCard(id: UUID(), title: "非表示", dates: dates("非表示", "2032-04-04"),
                                   preferences: options, availability: .available)
        options.showsOnHome = true
        let active = CountdownCard(id: UUID(), title: "期間中", dates: dates("期間中", "2032-03-25", "2032-03-28"),
                                   preferences: options, availability: .available)
        let upcoming = (1...4).map { offset in
            let start = today.addingDays(offset)!
            return CountdownCard(id: UUID(), title: "架空\(offset)", dates: .init(title: "架空\(offset)", ranges: [.init(start: start, end: start)]),
                                 preferences: options, availability: .available)
        }
        XCTAssertEqual(CountdownCard.home(upcoming.reversed() + [hidden, active], today: today).map(\.id),
                       [active.id, upcoming[0].id, upcoming[1].id])
        let time = day("2032-03-26").dateInJapan()!
        XCTAssertTrue(CountdownNotice.planned(for: [hidden] + upcoming, at: time).contains { $0.targetID == hidden.id })
        let next = dates("架空予定", "2032-04-01")
        XCTAssertEqual(next.progress(from: nil, on: today), .hidden)
        XCTAssertEqual(next.progress(from: next.start, on: today), .invalid)
        XCTAssertEqual(next.progress(from: day("2032-03-21"), on: today), .value(5.0 / 11))
        XCTAssertEqual(next.progress(from: today, on: next.start), .value(1))
        XCTAssertEqual(next.progress(from: day("2032-03-29"), on: today), .value(0))
    }

    func testNotificationDeadlineAndSourcePauseApplyOnlyToTheirOwnTargets() throws {
        let target = dates("架空予定", "2032-10-01")
        let options = CountdownPreferences(notifications: true,
            reminders: [.init(daysBefore: 0, hour: 20, minute: 0), .init(daysBefore: 1, hour: 20, minute: 0)])
        let expiry = try XCTUnwrap(SchoolDataPeriod(day: day("2032-09-20")).endsAt)
        XCTAssertEqual(expiry, day("2032-10-01").dateInJapan())
        let restricted = CountdownCard(id: UUID(), title: target.title, dates: target, preferences: options,
            availability: .available, expiry: expiry, evidence: "opaque")
        let difference = CountdownCard(id: UUID(), title: target.title, dates: target, preferences: options,
            availability: .sourceDifference, reference: .init(year: 2032, eventID: "fictional"))
        let personal = CountdownCard(id: UUID(), title: target.title, dates: target, preferences: options, availability: .available)
        let now = day("2032-09-25").dateInJapan()!
        let plan = CountdownNotice.planned(for: [restricted, difference, personal], at: now)
        XCTAssertEqual(plan.filter { $0.targetID == personal.id }.count, 2)
        let privateNotices = plan.filter { $0.targetID == restricted.id }
        XCTAssertEqual(privateNotices.map(\.fireAt), [day("2032-09-30").dateInJapan(hour: 20)!])
        XCTAssertTrue(privateNotices.allSatisfy { $0.identifier.hasPrefix(CountdownNotice.privatePrefix) })
        XCTAssertFalse(plan.contains { $0.targetID == difference.id })
        XCTAssertEqual(CountdownNotice.planned(for: [personal, difference, restricted], at: now), plan)
        XCTAssertTrue(CountdownNotice.planned(for: [personal], at: target.start.dateInJapan(hour: 20)!).isEmpty)
    }

    func testRegistrationStoreRejectsInvalidWritesAndSurvivesSchoolDataRetention() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CountdownStore(root: root)
        let target = CountdownRegistration.Target.school(.init(year: 2032, eventID: "stable-1"),
            lastSaved: dates("架空の学校行事", "2032-10-01"), alias: "自分用")
        let personal = CountdownRegistration(id: UUID(), target: .personal(dates("自分の入力", "2032-03-31", "2032-04-02")))
        var library = CountdownLibrary(registrations: [.init(id: UUID(), target: target), personal])
        library.automatic.enabled = true; library.automatic.mode = .selectedClass
        try store.save(library)
        XCTAssertEqual(try store.load(), library)
        var invalid = library
        invalid.registrations.append(.init(id: UUID(), target: target))
        XCTAssertThrowsError(try store.save(invalid))
        try SchoolDataRetention(root: root).replace(with: SchoolDataPeriod(day: day("2032-10-01")))
        XCTAssertEqual(try store.load(), library)
    }
}

extension CountdownTests {
    func testClassExamUsesAcceptedSlotsVisibilityAndAppliedChanges() throws {
        let schoolDay = day("2032-05-24")
        let date = schoolDay.iso8601
        func exam(_ name: String, _ period: Int, _ subject: String) -> SpecialScheduleLesson {
            SpecialScheduleLesson(date: date, className: name, period: period, spanStart: period, spanEnd: period,
                                  timeRange: nil, lines: [subject, "架空教員", "架空教室"], page: 1)
        }
        let examSource = SpecialScheduleAnalysis(kind: .exam, sourceDigest: "fictional-exam", sourceName: "fictional.pdf",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, coveredDates: [date],
            coveredClasses: ["1_1", "1_IT"], periodTimes: [:],
            lessons: [exam("1_1", 1, "架空取消科目"), exam("1_IT", 2, "架空変更前"),
                      exam("1_IT", 3, "架空限定科目"), exam("1_1", 4, "架空通常試験")])
        let returnSource = SpecialScheduleAnalysis(kind: .examReturn, sourceDigest: "fictional-return", sourceName: "fictional.pdf",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, coveredDates: [date],
            coveredClasses: ["1_1"], periodTimes: [:], lessons: [exam("1_1", 5, "架空返却科目")])
        let changes = ChangeAnalysis(sourceDigest: "fictional-change", sourceName: "fictional.xlsx", defaultYear: 2032,
            parsedAt: Date(timeIntervalSince1970: 0), records: [
                ScheduleChange(change_date: date, class_name: "1_1", period: "1", before_subject: "架空取消科目",
                    after_subject: "", teacher: "", room: "", note: "休講", raw_text: "", canonical_text: ""),
                ScheduleChange(change_date: date, class_name: "1_IT", period: "2", before_subject: "架空変更前",
                    after_subject: "架空変更後", teacher: "", room: "", note: "", raw_text: "", canonical_text: ""),
            ])
        let schedule = TimetableDaySchedule(timetable: nil, changes: changes, events: nil,
            specials: [examSource, returnSource], includesChanges: true)
        let rule: (String, String, Int?) -> Bool = { subject, _, _ in subject == "架空限定科目" }
        XCTAssertEqual(schedule.examSubjects(on: schoolDay, classes: ["1_1", "1_IT"], international: false, matchedByRule: rule),
                       ["架空通常試験", "架空変更後"])
        XCTAssertEqual(schedule.examSubjects(on: schoolDay, classes: ["1_IT"], international: true, matchedByRule: rule),
                       ["架空変更後", "架空限定科目"])
        XCTAssertTrue(schedule.examSubjects(on: schoolDay, classes: ["2_IT"], international: false).isEmpty)
    }
}
