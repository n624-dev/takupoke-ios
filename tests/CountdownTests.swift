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
        XCTAssertEqual(next.progress(from: day("2032-03-29"), on: today), .hidden)
        XCTAssertEqual(next.progress(from: today, on: today), .value(0))
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

    func testCountdownRecoveryPreservesCorruptBytesAndInstallsWritableLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root, withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let dataFile = root.appendingPathComponent("Countdown.json")
        let store = CountdownStore(root:root)
        XCTAssertEqual(try store.load(),CountdownLibrary())
        let registration = CountdownRegistration(id:UUID(),target:.personal(dates("架空の予定", "2032-04-01")))
        try store.save(CountdownLibrary(registrations:[registration]))
        let corrupt = Data("{".utf8)
        try corrupt.write(to:dataFile,options:.atomic)
        let reopened = CountdownStore(root:root)
        XCTAssertThrowsError(try reopened.load()) { error in
            guard case CountdownStore.ReadError.corrupt = error else { return XCTFail("Expected corrupt content") }
        }
        XCTAssertEqual(try Data(contentsOf:dataFile),corrupt)
        try reopened.preserveCorruptFileAndReset()
        XCTAssertEqual(try reopened.load(),CountdownLibrary())
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at:root, includingPropertiesForKeys:nil)
            .first { $0.lastPathComponent.hasPrefix("Countdown-Recovery-") })
        XCTAssertEqual(try Data(contentsOf:backup),corrupt)
        try reopened.save(CountdownLibrary(registrations:[registration]))
        XCTAssertEqual(try CountdownStore(root:root).load().registrations,[registration])
        XCTAssertThrowsError(try reopened.preserveCorruptFileAndReset())
        XCTAssertEqual(try reopened.load().registrations,[registration])
    }

    func testCountdownResetRejectsTemporaryAccessFailureAndFutureFormats() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root, withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let dataFile = root.appendingPathComponent("Countdown.json")
        let stored = root.appendingPathComponent("fictional.json")
        let store = CountdownStore(root:root)
        try store.save(CountdownLibrary())
        try FileManager.default.moveItem(at:dataFile,to:stored)
        try FileManager.default.createSymbolicLink(at:dataFile,withDestinationURL:stored)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.preserveCorruptFileAndReset())
        try FileManager.default.removeItem(at:dataFile)
        try FileManager.default.moveItem(at:stored,to:dataFile)
        XCTAssertEqual(try store.load(),CountdownLibrary())
        let future = Data(#"{"version":3,"differentShape":true}"#.utf8)
        try future.write(to:dataFile,options:.atomic)
        XCTAssertThrowsError(try store.load()) { error in
            guard case CountdownStore.ReadError.unsafeFile = error else { return XCTFail("Expected unsupported format") }
        }
        XCTAssertThrowsError(try store.preserveCorruptFileAndReset())
        XCTAssertEqual(try Data(contentsOf:dataFile),future)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:root.path),["Countdown.json"])
    }
}

extension CountdownTests {
    private func announcement(_ id: String, _ first: String, title: String = "試験発表",
                              tag: String = "行事メモ", extra: [String] = []) -> CountdownPublicEvent {
        let firstDay = day(first)
        return .init(reference: .init(year: firstDay.schoolYear, eventID: id),
                     dates: .init(title: title, ranges: ([first] + extra).map {
                         CountdownRange(start: day($0), end: day($0))
                     }), tag: tag)
    }

    func testExamAnnouncementUsesClampedCalendarMonthAndFirstDay() {
        let exam = day("2032-03-31")
        let lower = announcement("lower", "2032-02-29")
        let candidates = [
            announcement("too-early", "2032-02-28"),
            lower,
            announcement("same-day", "2032-03-31"),
            announcement("stronger-sounding", "2032-03-30", title: "国家試験発表"),
            announcement("return", "2032-03-29", title: "試験返却日"),
            announcement("after", "2032-04-01"),
        ]
        XCTAssertEqual(exam.previousMonth(), day("2032-02-29"))
        XCTAssertEqual(day("2031-03-31").previousMonth(), day("2031-02-28"))
        XCTAssertEqual(day("2032-01-31").previousMonth(), day("2031-12-31"))
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: candidates, completeYears: [2031]),
                       .announcement(lower.dates.start, lower.reference))
        let recent = announcement("tie-a", "2032-03-21", title: " \n試験発表\t", extra: ["2032-03-24"])
        let tie = announcement("tie-b", "2032-03-21")
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: candidates + [tie, recent],
                                                             completeYears: [2031]),
                       .announcement(day("2032-03-21"), recent.reference))
    }

    func testExamAnnouncementDistinguishesUnconfirmedYearsAndCompleteAbsence() {
        let exam = day("2032-04-15")
        let older = announcement("early", "2032-03-25")
        let recent = announcement("late", "2032-04-09")
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [older], completeYears: [2031]),
                       .pending)
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [older], completeYears: [2031],
                                                             unconfirmedYear: { _ in .checking }), .checking)
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [older], completeYears: [2031],
                                                             unconfirmedYear: { _ in .unavailable }), .unavailable)
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [], completeYears: [2032]), .pending)
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [], completeYears: [2031, 2032]), .unset)
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: exam, events: [older, recent], completeYears: [2032]),
                       .announcement(recent.dates.start, recent.reference))
        XCTAssertEqual(CountdownProgressOrigin.announcement(before: day("2032-04-01"), events: [older], completeYears: [2031]),
                       .announcement(older.dates.start, older.reference))
    }

    func testClassProgressSharesOnlyAnUnambiguousExamPeriod() {
        let scope = String(repeating: "a", count: 64)
        let otherScope = String(repeating: "b", count: 64)
        let exam = announcement("exam", "2032-06-01", title: "架空の前期試験", tag: "テスト", extra: ["2032-06-04"])
        let overlap = announcement("overlap", "2032-06-04", title: "架空の別試験", tag: "テスト")
        let first = CountdownExamProgressKey.forClass(scope: scope, day: day("2032-06-01"), events: [exam])
        let later = CountdownExamProgressKey.forClass(scope: scope, day: day("2032-06-04"), events: [exam])
        XCTAssertEqual(first.0, later.0)
        XCTAssertEqual(later.1, first.1)
        XCTAssertNotEqual(later.0, CountdownExamProgressKey.forClass(scope: otherScope,
                                                                      day: day("2032-06-04"), events: [exam]).0)
        for (date, events) in [("2032-06-02", [exam]), ("2032-06-04", [exam, overlap])] {
            let target = day(date)
            let fallback = CountdownExamProgressKey.forClass(scope: scope, day: target, events: events)
            XCTAssertEqual(fallback.0, .classDay(scope: scope, day: target))
            XCTAssertEqual(fallback.1, target)
        }
    }

    func testAutomaticProgressMigrationBindsOnlyTheSuppliedTargetAndKeepsPreferences() throws {
        let first = CountdownExamProgressKey.school(.init(year: 2032, eventID: "exam-a"))
        let second = CountdownExamProgressKey.school(.init(year: 2032, eventID: "exam-b"))
        let date = day("2032-05-01")
        var legacy = CountdownLibrary(version: 1)
        legacy.automatic.preferences.progressStart = date
        legacy.automatic.preferences.notifications = true
        legacy.automatic.preferences.lookahead = .month
        let old = try JSONDecoder().decode(CountdownLibrary.self, from: JSONEncoder().encode(legacy))
        XCTAssertFalse(old.canMigrateProgress(availability: .loading))
        XCTAssertTrue(old.canMigrateProgress(availability: .available))
        XCTAssertTrue(old.canMigrateProgress(availability: nil))
        var migrated = old
        XCTAssertNil(migrated.migrateProgress(to: first))
        XCTAssertFalse(migrated.canMigrateProgress(availability: .available))
        XCTAssertEqual(migrated.automatic.customOrigins, [.init(key: first, date: date)])
        XCTAssertTrue(migrated.automatic.preferences.showsProgress)
        XCTAssertNil(migrated.automatic.preferences.progressStart)
        XCTAssertEqual(migrated.automatic.preferences.lookahead, .month)
        XCTAssertTrue(migrated.automatic.preferences.notifications)
        XCTAssertNil(migrated.migrateProgress(to: second))
        XCTAssertEqual(migrated.automatic.customOrigins?.first?.key, first)

        var unresolved = old
        XCTAssertNil(unresolved.migrateProgress(to: nil))
        XCTAssertNil(unresolved.migrateProgress(to: second))
        XCTAssertEqual(unresolved.automatic.unlinkedProgressStart, date)
        XCTAssertNil(unresolved.automatic.customOrigins)
        var disabled = CountdownLibrary(version: 1)
        XCTAssertNil(disabled.migrateProgress(to: first))
        XCTAssertFalse(disabled.automatic.preferences.showsProgress)
    }

    func testClassProgressKeepsReadableSettingsWhenAnotherStoredDateIsDamaged() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CountdownStore(root: root)
        let period = SchoolDataPeriod(day: day("2032-10-05"))
        let first = CountdownCustomProgress(key: .classDay(scope: String(repeating: "a", count: 64), day: day("2032-10-20")), date: day("2032-10-15"))
        let second = CountdownCustomProgress(key: .classDay(scope: String(repeating: "b", count: 64), day: day("2032-10-21")), date: day("2032-10-16"))
        let saved = try store.save(CountdownLibrary(), with: .init(period: period, entries: [first, second]))
        let id = try XCTUnwrap(saved.classProgressFile)
        let file = root.appendingPathComponent(SchoolDataRetention.countdownProgressDirectory).appendingPathComponent(id.uuidString + ".json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        entries[1]["date"] = "fictional damaged date"
        object["entries"] = entries
        let damaged = try JSONSerialization.data(withJSONObject: object)
        try damaged.write(to: file, options: .atomic)
        let restored = try store.loadClassProgress(file: id, period: period)
        XCTAssertEqual(restored.entries, [first])
        XCTAssertEqual(try Data(contentsOf: file), damaged)
        let replacement = try store.save(saved, with: .init(period: period, entries: [first]))
        XCTAssertEqual(try store.loadClassProgress(file: replacement.classProgressFile, period: period).entries, [first])
        store.discardUnusedClassProgress(keeping: replacement.classProgressFile)
        XCTAssertEqual(try Data(contentsOf: file), damaged)
    }

    func testCountdownClassProgressStorageCommitsAtomicallyAndExpiresWithPrivateData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CountdownStore(root: root)
        let start = day("2032-05-02")
        let period = SchoolDataPeriod(day: start)
        let nextPeriod = SchoolDataPeriod(day: day("2032-10-01"))
        let scope = String(repeating: "a", count: 64)
        let entry = CountdownCustomProgress(key: .classDay(scope: scope, day: day("2032-05-15")), date: start)
        let progress = CountdownClassProgress(period: period, entries: [entry])
        var original = CountdownLibrary(version: 1)
        original.automatic.preferences.progressStart = start
        let migrated = try XCTUnwrap(original.migrateProgress(to: entry.key))
        XCTAssertEqual(migrated, entry)
        original.automatic.preferences.progressLabel = "試験まで"
        let committed = try store.save(original, with: progress)
        let reference = try XCTUnwrap(committed.classProgressFile)
        XCTAssertEqual(try store.load(), committed)
        XCTAssertEqual(try store.loadClassProgress(file: reference, period: period), progress)
        XCTAssertEqual(try store.loadClassProgress(file: reference, period: nextPeriod).entries, [])
        let publicFile = root.appendingPathComponent("Countdown.json")
        XCTAssertFalse(try String(contentsOf: publicFile, encoding: .utf8).contains(scope))
        var tooLarge = committed
        tooLarge.automatic.preferences.progressLabel = String(repeating: "a", count: 2_000_000)
        XCTAssertThrowsError(try store.save(tooLarge, with: progress))
        XCTAssertEqual(try store.load(), committed)
        XCTAssertEqual(try store.loadClassProgress(file: reference, period: period), progress)
        let directory = root.appendingPathComponent(SchoolDataRetention.countdownProgressDirectory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
        try SchoolDataRetention(root: root).replace(with: nextPeriod)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(try store.load().automatic.preferences.displayedProgressLabel, "試験まで")
        XCTAssertEqual(try store.loadClassProgress(file: reference, period: nextPeriod).entries, [])
    }

    func testClassMigrationKeepsOldDateAndPublicEditsWhenPrivateSnapshotCannotBeWritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent(SchoolDataRetention.countdownProgressDirectory)
        let obstruction = Data("fixture".utf8)
        try obstruction.write(to: directory)
        let store = CountdownStore(root: root)
        let start = day("2032-05-02")
        let exam = day("2032-05-15")
        let scope = String(repeating: "a", count: 64)
        var legacy = CountdownLibrary(version: 1)
        legacy.automatic.mode = .selectedClass
        legacy.automatic.preferences.progressStart = start
        legacy.automatic.preferences.notifications = true
        try JSONEncoder().encode(legacy).write(to: root.appendingPathComponent("Countdown.json"))

        var migrated = try store.saveMigratingProgress(store.load(), to: .classDay(scope: scope, day: exam),
                                                        classProgress: .init(period: SchoolDataPeriod(day: exam)))
        XCTAssertEqual(try store.load(), migrated)
        XCTAssertEqual(migrated.version, CountdownLibrary.currentVersion)
        XCTAssertEqual(migrated.automatic.unlinkedProgressStart, start)
        XCTAssertNil(migrated.automatic.preferences.progressStart)
        XCTAssertTrue(migrated.automatic.preferences.showsProgress)
        XCTAssertTrue(migrated.automatic.preferences.notifications)
        XCTAssertNil(migrated.classProgressFile)
        XCTAssertEqual(try Data(contentsOf: directory), obstruction)

        migrated.automatic.preferences.progressLabel = "架空の進捗"
        try store.save(migrated)
        XCTAssertEqual(try store.load(), migrated)
    }

    func testProgressLabelDistinguishesDefaultAndWhitespaceAcrossStorage() throws {
        var value = CountdownPreferences(progressStart: day("2032-04-02"))
        XCTAssertEqual(value.displayedProgressLabel, CountdownPreferences.defaultProgressLabel)
        value.progressEnabled = false
        value.progressLabel = " \t"
        let restored = try JSONDecoder().decode(CountdownPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertFalse(restored.showsProgress)
        XCTAssertEqual(restored.progressStart, value.progressStart)
        XCTAssertEqual(restored.displayedProgressLabel, "")
    }

    func testCustomOriginFollowsExamIdentityWithoutChangingNotificationDates() {
        let first = CountdownExamProgressKey.school(.init(year: 2032, eventID: "exam-a"))
        let second = CountdownExamProgressKey.school(.init(year: 2032, eventID: "exam-b"))
        let origin = day("2032-05-10")
        let entries = CountdownCustomProgress.replacing(first, with: origin, in: [])
        XCTAssertEqual(entries.first { $0.key == first }?.date, origin)
        XCTAssertNil(entries.first { $0.key == second })

        let moved = day("2032-06-03")
        var card = CountdownCard(id: CountdownAutomatic.identity, title: "架空の試験", dates: .init(title: "架空の試験",
            ranges: [.init(start: moved, end: moved)]), preferences: .init(notifications: true, progressEnabled: true),
            availability: .available)
        let target = card.noticeTarget
        let reminders = card.preferences.reminders
        card.examProgress = .init(key: first, goal: moved, origin: .custom(origin))
        XCTAssertEqual(card.progress(on: origin), .value(0))
        XCTAssertEqual(card.progress(on: moved), .value(1))
        XCTAssertEqual(card.noticeTarget, target)
        XCTAssertEqual(card.dates?.start, moved)
        XCTAssertEqual(card.preferences.reminders, reminders)
    }
}

extension CountdownTests {
    func testClassExamDistinguishesAbsentUnloadedAndUnconfirmedChanges() {
        var state = MaterialLibraryState()
        func issue(ready: Bool, failed: Bool = false, year: Int = 2032, rejectedExamRecovery: Bool = false) -> CountdownAvailability? {
            CountdownAvailability.classExamInputIssue(in: state, ready: ready, failed: failed, schoolYear: year,
                                                      rejectedExamRecovery: rejectedExamRecovery)
        }
        XCTAssertEqual(issue(ready: false), .loading)
        XCTAssertEqual(issue(ready: false, rejectedExamRecovery: true), .analysisFailed)
        XCTAssertFalse(CountdownAvailability.analysisFailed.allowsNotification)
        XCTAssertFalse(CountdownAvailability.analysisFailed.presentsDatesOnHome)
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

    func testClassExamHoldsAfterFailedFirstChangeAcquisitionAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let unavailable = MaterialError.providerReadFailed.localizedDescription
        let oldCancellation = MaterialError.cancelled.localizedDescription
        func issue(after message: String? = nil, cancelled: Bool? = nil) throws -> CountdownAvailability? {
            let root = directory.appendingPathComponent(UUID().uuidString,isDirectory:true)
            do {
                let library = try LocalMaterialDatabase.openLibrary(root:root)
                if let message { try library.recordFailure(.changes,message:message,cancelled:cancelled) }
            }
            let state = try LocalMaterialDatabase.openLibrary(root:root).state
            XCTAssertNil(state.record(for:.changes))
            return CountdownAvailability.classExamInputIssue(in:state,ready:true,failed:false,schoolYear:2032)
        }

        XCTAssertNil(try issue())
        XCTAssertEqual(try issue(after:unavailable),.changesUnavailable)
        XCTAssertNil(try issue(after:oldCancellation))
        XCTAssertEqual(try issue(after:oldCancellation,cancelled:false),.changesUnavailable)
        XCTAssertNil(try issue(after:"fictional-cancellation",cancelled:true))

        let root = directory.appendingPathComponent("retry",isDirectory:true)
        do {
            let library = try LocalMaterialDatabase.openLibrary(root:root)
            try library.recordFailure(.changes,message:unavailable,cancelled:false)
        }
        do {
            let library = try LocalMaterialDatabase.openLibrary(root:root)
            try library.recordFailure(.changes,message:oldCancellation,cancelled:true)
        }
        do {
            let retry = try LocalMaterialDatabase.openLibrary(root:root)
            XCTAssertEqual(retry.state.attempts[MaterialKind.changes.rawValue]?.failure,unavailable)
            XCTAssertEqual(CountdownAvailability.classExamInputIssue(in:retry.state,ready:true,failed:false,schoolYear:2032),
                           .changesUnavailable)

            let staged = retry.newStagingURL()
            let fictionalBytes = Data([0x50,0x4b,0x03,0x04])
            try fictionalBytes.write(to:staged)
            try retry.commit(staged:staged,kind:.changes,source:.init(grant:nil,childName:nil),
                originalName:"fictional.xlsx",byteCount:fictionalBytes.count,digest:String(repeating:"a",count:64),modifiedAt:nil)
        }
        let acquired = try LocalMaterialDatabase.openLibrary(root:root).state
        XCTAssertNil(acquired.attempts[MaterialKind.changes.rawValue]?.failure)
        XCTAssertEqual(CountdownAvailability.classExamInputIssue(in:acquired,ready:true,failed:false,schoolYear:2032),
                       .changesUnconfirmed)
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
