import XCTest
@testable import TakupokeParsing

extension TimetableScheduleTests {
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

    func testFullDayEventCardAppearsOnlyWhenNoLessonIsDisplayed() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        let noClass = PDFSchoolEvent(date: day.iso8601, scope: "全クラス", title: "架空休業A", page: 0,
                                     classification: .init(type: .noClass), apiTag: "授業なし")
        let another = PDFSchoolEvent(date: day.iso8601, scope: "全クラス", title: "架空休業B", page: 0,
                                     classification: .init(type: .schoolEventNoClass), apiTag: "行事（授業なし）")
        let events = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional",
                                 parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil,
                                 lessons: [], events: [noClass, another], notices: [])
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        XCTAssertEqual(TimetableSchedule.fullDayEventTitle(plan: plan, layouts: [[], []]), "架空休業A・架空休業B")

        let change = ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: "1",
                                    before_subject: "架空科目A", after_subject: "架空科目B",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        let changed = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                     defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change])
        let blocks = TimetableSchedule.positioned(TimetableSchedule.blocks(
            on: day, className: "1_A", timetable: timetable(term: "前期"), changes: changed,
            includesChanges: true, events: events))
        XCTAssertEqual(blocks.count, 1)
        XCTAssertNil(TimetableSchedule.fullDayEventTitle(plan: plan, layouts: [blocks, []]))

        let exam = SpecialScheduleAnalysis(kind: .exam, sourceDigest: "fictional", sourceName: "fictional.pdf",
                                           parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032,
                                           coveredDates: [day.iso8601], coveredClasses: ["1_A"], periodTimes: [:],
                                           lessons: [SpecialScheduleLesson(date: day.iso8601, className: "1_A", period: 2,
                                                                           spanStart: 2, spanEnd: 2, timeRange: nil,
                                                                           lines: ["架空科目C", "架空教員C", "架空教室C"], page: 1)])
        let examBlocks = TimetableSchedule.positioned(TimetableSchedule.blocks(
            on: day, className: "1_A", timetable: timetable(term: "前期"), changes: nil,
            includesChanges: true, events: events, specials: [exam]))
        XCTAssertEqual(examBlocks.count, 1)
        XCTAssertNil(TimetableSchedule.fullDayEventTitle(plan: plan, layouts: [examBlocks]))
    }
}
