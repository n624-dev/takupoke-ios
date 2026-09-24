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

    func testChangePeriodDisplayKeepsCombinedSourceValue() {
        func change(period: String) -> ScheduleChange {
            ScheduleChange(change_date: "2032-04-06", class_name: "1_A", period: period,
                           before_subject: "架空科目A", after_subject: "架空科目B",
                           teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        }
        XCTAssertEqual(change(period: "1").displayPeriod, "1限")
        XCTAssertEqual(change(period: "1,2").displayPeriod, "1,2")
        XCTAssertEqual(change(period: "1〜2").displayPeriod, "1〜2")
        XCTAssertEqual(change(period: "").displayPeriod, "記載なし")
        XCTAssertEqual(change(period: "1,2").period, "1,2")
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

    func testSpecialDocumentsMergeBySlotAndChangesRetainBothOriginals() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        func special(_ kind: SpecialScheduleKind, _ period: Int, _ subject: String) -> SpecialScheduleAnalysis {
            SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf",
                                    parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032,
                                    coveredDates: [day.iso8601], coveredClasses: ["1_A"],
                                    periodTimes: [1: "08:50〜09:35", 2: "09:50〜10:35"],
                                    lessons: [SpecialScheduleLesson(date: day.iso8601, className: "1_A",
                                                                    period: period, spanStart: period,
                                                                    spanEnd: period,
                                                                    timeRange: "08:50〜09:35",
                                                                    lines: [subject], page: 1)])
        }
        let exam = special(.exam, 1, "架空科目B")
        let returned = special(.examReturn, 1, "架空科目C")
        let base = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                          timetable: timetable(term: "前期"), changes: nil,
                                          includesChanges: false, specials: [exam, returned])
        XCTAssertTrue(base.displayedLessons.isEmpty)
        XCTAssertEqual(Set(base.displayedSpecialLessons.map(\.lesson.subject)), ["架空科目B", "架空科目C"])
        XCTAssertEqual(Set(base.displayedSpecialLessons.compactMap(\.timeRange)), ["08:50〜09:35"])
        let blank = TimetableSchedule.slot(on: day, period: 2, className: "1_A",
                                           timetable: timetable(term: "前期"), changes: nil,
                                           includesChanges: false, specials: [exam, returned])
        XCTAssertTrue(blank.displayedLessons.isEmpty)
        let change = ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: "1",
                                    before_subject: "架空科目B", after_subject: "架空科目D",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change])
        let merged = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                            timetable: timetable(term: "前期"), changes: analysis,
                                            includesChanges: true, specials: [exam, returned])
        XCTAssertTrue(merged.displayedSpecialLessons.isEmpty)
        XCTAssertEqual(merged.changes.map(\.after_subject), ["架空科目D"])
        XCTAssertEqual(merged.specialLessons.count, 2)
    }

    func testOnlyFixedFirstYearPairCanBeAdded() {
        let room = TimetableSchedule.firstYearHomerooms.sorted()[0]
        let department = TimetableSchedule.firstYearDepartments.sorted()[0]
        XCTAssertTrue(TimetableSchedule.compatibleAdditionalClass(department, with: room))
        XCTAssertTrue(TimetableSchedule.compatibleAdditionalClass(room, with: department))
        XCTAssertFalse(TimetableSchedule.compatibleAdditionalClass("1_ZZ", with: room))
        XCTAssertFalse(TimetableSchedule.compatibleAdditionalClass("1_ZZ", with: department))
    }

    func testInternationalStudentFilterUsesNormalizedSubjectPrefix() {
        let lesson = PDFLesson(className: "1_ZZ", weekday: 1, period: 1,
                               names: TimetableLessonNames(subject: "留 架空科目A"), sourceText: "", page: 1)
        let change = ScheduleChange(change_date: "2032-04-05", class_name: "1_ZZ", period: "1",
                                    before_subject: "架空科目A", after_subject: "留　架空科目B",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        XCTAssertFalse(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: false))
        XCTAssertFalse(TimetableSchedule.shouldDisplay(change, isInternationalStudent: false))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: true))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(change, isInternationalStudent: true))
        XCTAssertFalse(TimetableSchedule.isInternationalStudentSubject("留架空科目A"))
    }

    func testExplicitCalendarTagsAffectWeekWithoutChangingParsedEvents() throws {
        let monday = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        var base = timetable(term: "前期")
        let holiday = PDFSchoolEvent(date: monday.iso8601, scope: "共通", title: "架空休業A", page: 1,
                                     classification: PDFEventClassification(type: .noClass))
        var eventAnalysis = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional.pdf",
                                        parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil,
                                        lessons: [], events: [holiday], notices: [])
        let closed = TimetableSchedule.slot(on: monday, period: 1, className: "1_A",
                                            timetable: base, changes: nil, includesChanges: false,
                                            events: eventAnalysis)
        XCTAssertTrue(closed.displayedLessons.isEmpty)
        XCTAssertEqual(TimetableSchedule.dayPlan(on: monday, events: eventAnalysis).noClassLabels, ["架空休業A"])

        var override = holiday
        override.classification = PDFEventClassification(type: .weekdayOverride, scheduleDay: 2)
        eventAnalysis.events = [override]
        XCTAssertTrue(TimetableSchedule.slot(on: monday, period: 1, className: "1_A",
                                             timetable: base, changes: nil, includesChanges: false,
                                             events: eventAnalysis).displayedLessons.isEmpty)
        base.lessons[0].weekday = 2
        XCTAssertEqual(TimetableSchedule.slot(on: monday, period: 1, className: "1_A",
                                              timetable: base, changes: nil, includesChanges: false,
                                              events: eventAnalysis).displayedLessons.count, 1)
        override.classification?.needsReview = true
        eventAnalysis.events = [override]
        XCTAssertTrue(TimetableSchedule.slot(on: monday, period: 1, className: "1_A",
                                             timetable: base, changes: nil, includesChanges: false,
                                             events: eventAnalysis).displayedLessons.isEmpty)
    }

    func testUncertainEventRangeOnlyAffectsKnownStartDay() throws {
        let start = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        var holiday = PDFSchoolEvent(date: start.iso8601, scope: "共通", title: "架空休業A", page: 1,
                                     endDate: "2032-04-07", classification: PDFEventClassification(type: .noClass))
        let analysis = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional.pdf",
                                   parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil,
                                   lessons: [], events: [holiday], notices: [])
        XCTAssertEqual(TimetableSchedule.events(on: start.addingDays(2)!, analysis: analysis).count, 1)
        holiday.periodNeedsReview = true
        var uncertain = analysis
        uncertain.events = [holiday]
        XCTAssertEqual(TimetableSchedule.events(on: start, analysis: uncertain).count, 1)
        XCTAssertTrue(TimetableSchedule.events(on: start.addingDays(1)!, analysis: uncertain).isEmpty)
    }

    func testAcademicHalfNavigationUsesMondayAndKnownWeekData() throws {
        let september = try XCTUnwrap(SchoolDate(iso8601: "2032-09-27"))
        let october = try XCTUnwrap(SchoolDate(iso8601: "2032-10-04"))
        XCTAssertFalse(TimetableSchedule.isSameAcademicHalf(september, october))
        XCTAssertTrue(TimetableSchedule.isSameAcademicHalf(october, october.addingDays(7)!))
        XCTAssertFalse(TimetableSchedule.hasWeekData(start: october, classes: ["1_A"],
                                                   timetable: timetable(term: "前期"), changes: nil,
                                                   events: nil, includesChanges: false))
        let change = ScheduleChange(change_date: october.iso8601, class_name: "1_A", period: "1",
                                    before_subject: "架空科目A", after_subject: "架空科目B",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change])
        XCTAssertTrue(TimetableSchedule.hasWeekData(start: october, classes: ["1_A"],
                                                    timetable: timetable(term: "前期"), changes: analysis,
                                                    events: nil, includesChanges: true))
    }

    func testPreviousWeekCanCrossBoundaryWhenPartOfWeekIsInCurrentHalf() throws {
        let october = try XCTUnwrap(SchoolDate(iso8601: "2026-10-05"))
        let previous = try XCTUnwrap(SchoolDate(iso8601: "2026-09-28"))
        XCTAssertTrue(TimetableSchedule.weekOverlapsAcademicHalf(start: previous, containing: october))
        XCTAssertFalse(TimetableSchedule.weekOverlapsAcademicHalf(
            start: try XCTUnwrap(SchoolDate(iso8601: "2026-09-21")), containing: october))
        let april = try XCTUnwrap(SchoolDate(iso8601: "2027-04-05"))
        XCTAssertTrue(TimetableSchedule.weekOverlapsAcademicHalf(
            start: try XCTUnwrap(SchoolDate(iso8601: "2027-03-29")), containing: april))
    }

    func testOctoberOpeningKeepsSeptemberBoundaryWhenPickingAnotherWeek() throws {
        let opening = try XCTUnwrap(SchoolDate(iso8601: "2026-10-01"))
        let bounds = TimetableSchedule.reachableWeekBounds(containing: opening, classes: [],
                                                            timetable: nil, changes: nil, events: nil,
                                                            includesChanges: false)
        XCTAssertEqual(bounds.lowerBound.iso8601, "2026-09-28")
        XCTAssertEqual(bounds.upperBound.iso8601, "2027-03-29")
        XCTAssertTrue(bounds.contains(try XCTUnwrap(SchoolDate(iso8601: "2026-10-12"))))
        XCTAssertFalse(bounds.contains(try XCTUnwrap(SchoolDate(iso8601: "2026-09-21"))))
    }

    func testReachableWeeksExtendThroughConsecutiveSavedWeeksAndAllowReturning() throws {
        let opening = try XCTUnwrap(SchoolDate(iso8601: "2026-09-24"))
        func change(_ date: String) -> ScheduleChange {
            ScheduleChange(change_date: date, class_name: "1_A", period: "1",
                           before_subject: "架空科目A", after_subject: "架空科目B",
                           teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        }
        let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                     defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0),
                                     records: [change("2026-10-05"), change("2026-10-12"),
                                               change("2026-10-26")])
        let bounds = TimetableSchedule.reachableWeekBounds(containing: opening, classes: ["1_A"],
                                                            timetable: nil, changes: changes, events: nil,
                                                            includesChanges: true)
        XCTAssertEqual(bounds.lowerBound.iso8601, "2026-03-30")
        XCTAssertEqual(bounds.upperBound.iso8601, "2026-10-12")
        XCTAssertTrue(bounds.contains(try XCTUnwrap(SchoolDate(iso8601: "2026-10-05"))))
        XCTAssertFalse(bounds.contains(try XCTUnwrap(SchoolDate(iso8601: "2026-10-26"))))
        let withoutChanges = TimetableSchedule.reachableWeekBounds(containing: opening, classes: ["1_A"],
                                                                   timetable: nil, changes: changes, events: nil,
                                                                   includesChanges: false)
        XCTAssertEqual(withoutChanges.upperBound.iso8601, "2026-09-28")
    }

    func testApiNoClassKeepsChangesWhileExamTagSuppressesOrdinaryLessons() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        let change = ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: "1",
                                    before_subject: "架空科目A", after_subject: "架空科目B",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        let changed = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                     defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change])
        let noClass = PDFSchoolEvent(date: day.iso8601, scope: "全クラス", title: "架空休業A", page: 0,
                                     classification: .init(type: .noClass), apiTag: "授業なし")
        var events = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional",
                                 parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil,
                                 lessons: [], events: [noClass], notices: [])
        let slot = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                          timetable: timetable(term: "前期"), changes: changed,
                                          includesChanges: true, events: events)
        XCTAssertTrue(slot.baseLessons.isEmpty)
        XCTAssertEqual(slot.changes.map(\.after_subject), ["架空科目B"])

        events.events = [PDFSchoolEvent(date: day.iso8601, scope: "全クラス", title: "架空試験A", page: 0,
                                        classification: .init(type: .special), apiTag: "テスト")]
        let missingExam = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                                 timetable: timetable(term: "前期"), changes: nil,
                                                 includesChanges: false, events: events)
        XCTAssertTrue(missingExam.displayedLessons.isEmpty)
        XCTAssertTrue(TimetableSchedule.dayPlan(on: day, events: events).apiTest)
    }
}
