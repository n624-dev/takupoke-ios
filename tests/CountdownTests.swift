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

    func testAutomaticClassExamReservesEveryDayWithoutReplacingTodaysCard() throws {
        let expiry = try XCTUnwrap(day("2032-10-01").dateInJapan())
        let reminders = [
            CountdownReminder(daysBefore: 7, hour: 20, minute: 0),
            CountdownReminder(daysBefore: 1, hour: 20, minute: 0),
            CountdownReminder(daysBefore: 0, hour: 8, minute: 0)
        ]
        let exams = ["2032-06-07", "2032-06-08", "2032-06-09"].map { date in
            CountdownCard(id: CountdownAutomatic.identity, title: "架空試験", dates: dates("架空試験", date),
                preferences: CountdownPreferences(notifications: true, reminders: reminders),
                availability: .available, expiry: expiry, evidence: "fictional-\(date)")
        }
        let firstPlan = CountdownAutomaticCards(exams)
        let early = try XCTUnwrap(day("2032-05-31").dateInJapan(hour: 19))
        let firstNotices = CountdownNotice.planned(for: firstPlan.notificationTargets, at: early)
        XCTAssertEqual(firstNotices.count, 9)
        XCTAssertEqual(Set(firstNotices.map(\.identifier)).count, 9)
        XCTAssertEqual(Set(firstNotices.map(\.target)), Set(exams.map(\.noticeTarget)))
        XCTAssertTrue(firstNotices.allSatisfy { $0.identifier.hasPrefix(CountdownNotice.privatePrefix) })
        for (index, exam) in exams.enumerated() {
            let start = try XCTUnwrap(exam.dates?.start)
            XCTAssertEqual(firstNotices.filter { $0.target == exam.noticeTarget }.map(\.fireAt),
                           reminders.compactMap { $0.fireDate(start: start) })
            let evening = try XCTUnwrap(start.dateInJapan(hour: 19))
            let todayPlan = CountdownAutomaticCards(Array(exams.dropFirst(index)))
            XCTAssertEqual(todayPlan.displayed, exam)
            let upcoming = CountdownNotice.planned(for: todayPlan.notificationTargets, at: evening)
            if index + 1 < exams.count {
                XCTAssertTrue(upcoming.contains {
                    $0.target == exams[index + 1].noticeTarget && $0.fireAt == start.dateInJapan(hour: 20)
                })
            }
        }
        let changed = CountdownCard(id: CountdownAutomatic.identity, title: exams[1].title, dates: exams[1].dates,
            preferences: exams[1].preferences, availability: .available, expiry: expiry, evidence: "fictional-changed")
        let updated = CountdownNotice.planned(for: CountdownAutomaticCards([exams[0], changed]).notificationTargets, at: early)
        XCTAssertEqual(Set(updated.map(\.target)), [exams[0].noticeTarget, changed.noticeTarget])
        XCTAssertTrue(Set(updated.map(\.identifier)).isDisjoint(with: firstNotices.filter { $0.target != exams[0].noticeTarget }.map(\.identifier)))
    }

    func testSchoolAutomaticPlansLaterPeriodsAndHonorsFixedAndUnconfirmedEvents() throws {
        let date = day("2032-06-03")
        let prefs = CountdownPreferences(notifications: true)
        func event(_ key: String, _ start: String, _ end: String, _ availability: CountdownAvailability = .available) -> CountdownCard {
            .init(id: CountdownAutomatic.identity, title: "架空試験期間", dates: dates("架空試験期間", start, end),
                  preferences: prefs, availability: availability, reference: .init(year: date.schoolYear, eventID: key))
        }
        let active = event("fictional-active", "2032-06-01", "2032-06-07")
        let next = event("fictional-next", "2032-06-10", "2032-06-12")
        let fixedEvent = event("fictional-fixed", "2032-06-16", "2032-06-17")
        let pending = event("fictional-pending", "2032-06-24", "2032-06-25", .sourcePending)
        let fixed = CountdownCard(id: UUID(), title: fixedEvent.title, dates: fixedEvent.dates,
                                  preferences: CountdownPreferences(notifications: false), availability: .available,
                                  reference: fixedEvent.reference)
        let assessment = CountdownAutomaticCards([active, next, fixedEvent, pending], fixedReferences: Set([try XCTUnwrap(fixed.reference)]))
        XCTAssertEqual(assessment.displayed, active)
        let now = try XCTUnwrap(date.dateInJapan(hour: 19))
        let notices = CountdownNotice.planned(for: assessment.notificationTargets + [fixed], at: now)
        XCTAssertEqual(notices.map(\.target), [next.noticeTarget, next.noticeTarget])
        XCTAssertEqual(notices.first?.fireAt, date.dateInJapan(hour: 20))
        XCTAssertTrue(notices.allSatisfy { !$0.identifier.hasPrefix(CountdownNotice.privatePrefix) })
        let fixedFirst = CountdownAutomaticCards([active, next],
            fixedReferences: Set([try XCTUnwrap(active.reference)]))
        XCTAssertNil(fixedFirst.displayed)
        XCTAssertEqual(fixedFirst.notificationTargets, [next])
    }

    func testStartupHoldsOnlyExistingAutomaticClassReservationsForTheSameSelection() throws {
        let start = day("2032-06-07")
        let classCard = CountdownCard(id: CountdownAutomatic.identity, title: "架空試験", dates: dates("架空試験", start.iso8601),
            preferences: CountdownPreferences(notifications: true), availability: .available,
            expiry: day("2032-10-01").dateInJapan(), evidence: "fictional-exam", classScope: "fictional-current-class")
        let personal = CountdownCard(id: UUID(), title: classCard.title, dates: classCard.dates,
            preferences: classCard.preferences, availability: .available)
        let now = try XCTUnwrap(day("2032-05-31").dateInJapan(hour: 19))
        let notices = CountdownNotice.planned(for: [classCard, personal], at: now)
        let planned = try XCTUnwrap(notices.first { $0.target == classCard.noticeTarget })
        let other = try XCTUnwrap(notices.first { $0.target == personal.noticeTarget })
        XCTAssertEqual(planned.classScope, "fictional-current-class")
        let active = Set(CountdownReminder.defaults.map(\.key))
        XCTAssertTrue(CountdownNotice.holdsWhileLoading(identifier: planned.identifier, storedScope: planned.classScope,
            currentScope: "fictional-current-class", activeReminderKeys: active, acceptsLegacy: false))
        XCTAssertFalse(CountdownNotice.holdsWhileLoading(identifier: planned.identifier, storedScope: planned.classScope,
            currentScope: "fictional-current-class", activeReminderKeys: ["1-20-0"], acceptsLegacy: false))
        XCTAssertFalse(CountdownNotice.holdsWhileLoading(identifier: planned.identifier, storedScope: planned.classScope,
            currentScope: "fictional-other-class", activeReminderKeys: active, acceptsLegacy: true))
        XCTAssertFalse(CountdownNotice.holdsWhileLoading(identifier: other.identifier, storedScope: nil,
            currentScope: "fictional-current-class", activeReminderKeys: active, acceptsLegacy: true))
        let legacyID = CountdownNotice.privatePrefix + CountdownAutomatic.identity.uuidString + ".7-20-0"
        XCTAssertTrue(CountdownNotice.holdsWhileLoading(identifier: legacyID, storedScope: nil,
            currentScope: "fictional-current-class", activeReminderKeys: active, acceptsLegacy: true))
        XCTAssertFalse(CountdownNotice.holdsWhileLoading(identifier: legacyID, storedScope: nil,
            currentScope: "fictional-other-class", activeReminderKeys: active, acceptsLegacy: false))
    }

    func testReminderDayEditingRequiresACompleteInRangeValue() {
        let locale = Locale(identifier: "ja_JP")
        var edits = CountdownReminderDayEdits()
        for input in ["", " ", "7a", "77.2", "111,2", "365001", "-1", String(repeating: "9", count: 30)] {
            XCTAssertNil(edits.enter(input, at: 0, locale: locale), input)
            edits.endEditing(at: 0)
            XCTAssertEqual(edits.text(at: 0), input)
            XCTAssertTrue(edits.hasInvalidInput)
        }
        for (input, days) in [("0", 0), ("7", 7), ("７", 7), ("365000", 365_000), ("365,000", 365_000)] {
            XCTAssertEqual(edits.enter(input, at: 0, locale: locale), days)
            XCTAssertEqual(edits.text(at: 0), input)
            XCTAssertFalse(edits.hasInvalidInput)
            edits.endEditing(at: 0)
            XCTAssertNil(edits.text(at: 0))
        }
        let arabic = Locale(identifier: "ar_EG")
        let grouped = 365_000.formatted(.number.locale(arabic))
        XCTAssertEqual(edits.enter(grouped, at: 0, locale: arabic), 365_000)
    }

    func testRemovingReminderKeepsTheOtherRowsOwnUnfinishedText() {
        var edits = CountdownReminderDayEdits()
        XCTAssertEqual(edits.enter("0", at: 0), 0)
        XCTAssertNil(edits.enter("", at: 1))
        XCTAssertEqual(edits.enter("7", at: 2), 7)
        edits.remove(at: 0)
        XCTAssertEqual(edits.text(at: 0), "")
        XCTAssertEqual(edits.text(at: 1), "7")
        XCTAssertNil(edits.text(at: 2))
        XCTAssertTrue(edits.hasInvalidInput)
        edits.remove(at: 0)
        XCTAssertEqual(edits.text(at: 0), "7")
        XCTAssertFalse(edits.hasInvalidInput)
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
    func testClassExamDistinguishesAbsentUnloadedAndUnconfirmedChanges() {
        var state = MaterialLibraryState()
        func issue(ready: Bool, failed: Bool = false, year: Int = 2032) -> CountdownAvailability? {
            CountdownAvailability.classExamChangeIssue(in: state, ready: ready, failed: failed, schoolYear: year)
        }
        XCTAssertEqual(issue(ready: false), .loading)
        XCTAssertEqual(issue(ready: false, failed: true), .changesUnavailable)
        XCTAssertNil(issue(ready: true))
        state.records = [.init(kind: .changes, source: .init(grant: nil, childName: nil, selectionID: "fictional"),
            originalName: "fictional.xlsx", storedName: "fictional.xlsx", byteCount: 10, digest: "fictional",
            sourceModifiedAt: nil, acquiredAt: Date())]
        XCTAssertEqual(issue(ready: true), .changesUnconfirmed)
        state.changeAnalysis = .init(sourceDigest: "fictional", sourceName: "fictional.xlsx",
            defaultYear: 2032, parsedAt: Date(), records: [])
        XCTAssertNil(issue(ready: true, failed: true))
        XCTAssertEqual(issue(ready: true, year: 2033), .changesUnconfirmed)
        XCTAssertFalse(CountdownAvailability.changesUnavailable.allowsNotification)
        XCTAssertFalse(CountdownAvailability.changesUnconfirmed.allowsNotification)
        XCTAssertTrue(CountdownAvailability.changesUnconfirmed.presentsDatesOnHome)
    }

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
