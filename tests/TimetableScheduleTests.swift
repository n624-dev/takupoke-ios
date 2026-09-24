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

    func testConsecutiveChangeNotationCoversBothPeriodsWithoutChangingSource() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        func change(_ period: String) -> ScheduleChange {
            ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: period,
                           before_subject: "架空科目A", after_subject: "架空科目B",
                           teacher: "架空教員B", room: "架空教室B", note: "", raw_text: "", canonical_text: "")
        }
        XCTAssertEqual(change("1,2").gridPeriods, [1, 2])
        XCTAssertEqual(change("1, 2").gridPeriods, [1, 2])
        XCTAssertEqual(change("１～２").gridPeriods, [1, 2])
        XCTAssertEqual(change("1〜2").gridPeriods, [1, 2])
        XCTAssertNil(change("1,3").gridPeriods)
        XCTAssertNil(change("2,1").gridPeriods)
        XCTAssertNil(change("8,9").gridPeriods)
        XCTAssertNil(change("1,").gridPeriods)
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0), records: [change("1, 2")])
        for period in 1...2 {
            let slot = TimetableSchedule.slot(on: day, period: period, className: "1_A",
                                              timetable: timetable(term: "前期"), changes: analysis,
                                              includesChanges: true)
            XCTAssertEqual(slot.changes.map(\.period), ["1, 2"])
            XCTAssertTrue(slot.displayedLessons.isEmpty)
        }
        let cards = TimetableSchedule.blocks(on: day, className: "1_A", timetable: timetable(term: "前期"),
                                              changes: analysis, includesChanges: true)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].startPeriod, 1)
        XCTAssertEqual(cards[0].endPeriod, 2)
    }

    func testMakeupWinsSharedPeriodAndOtherRowsRemainAvailable() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        func change(_ period: String, _ note: String, _ after: String) -> ScheduleChange {
            ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: period,
                           before_subject: "架空科目A", after_subject: after,
                           teacher: "", room: "", note: note, raw_text: "", canonical_text: "")
        }
        let makeup = change("1,2", "補講", "架空科目B")
        let cancellation = change("1", "休講", "")
        XCTAssertTrue(cancellation.isCancellation)
        XCTAssertTrue(change("1", " 補講 ", "架空科目B").isMakeup)
        for records in [[makeup, cancellation], [cancellation, makeup]] {
            let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                          defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0),
                                          records: records)
            let slot = TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                                              timetable: timetable(term: "前期"), changes: analysis,
                                              includesChanges: true)
            XCTAssertEqual(slot.changes.count, 2)
            let cards = TimetableSchedule.blocks(on: day, className: "1_A",
                                                  timetable: timetable(term: "前期"),
                                                  changes: analysis, includesChanges: true)
            XCTAssertEqual(cards.count, 1)
            XCTAssertEqual(cards[0].startPeriod, 1)
            XCTAssertEqual(cards[0].endPeriod, 2)
            if case .change(let selected) = cards[0].content {
                XCTAssertEqual(selected.note, "補講")
                XCTAssertEqual(selected.after_subject, "架空科目B")
            } else { XCTFail("Expected a change card") }
        }
    }

    func testLastChangeWinsWithoutMakeupAndOverlappingWinnersSplitCards() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        func change(_ period: String, _ note: String, _ after: String) -> ScheduleChange {
            ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: period,
                           before_subject: "架空科目A", after_subject: after,
                           teacher: "", room: "", note: note, raw_text: "", canonical_text: "")
        }
        let cancellation = change("1", "休講", "")
        let later = change("1", "変更", "架空科目C")
        XCTAssertEqual(TimetableSchedule.effectiveChange([cancellation, later]), later)
        XCTAssertEqual(TimetableSchedule.effectiveChange([later, cancellation]), cancellation)
        XCTAssertNil(TimetableSchedule.effectiveChange([]))

        let wide = change("1,2", "補講", "架空科目B")
        let second = change("2", "補講", "架空科目C")
        let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                                      defaultYear: nil, parsedAt: Date(timeIntervalSince1970: 0),
                                      records: [wide, second])
        let cards = TimetableSchedule.blocks(on: day, className: "1_A",
                                              timetable: timetable(term: "前期"),
                                              changes: analysis, includesChanges: true)
        XCTAssertEqual(cards.map { "\($0.startPeriod)-\($0.endPeriod)" }, ["1-1", "2-2"])
    }

    func testMatchingAdjacentNormalAndExamLessonsBecomeSpanningCards() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        var normal = timetable(term: "前期")
        normal.lessons[0].names = TimetableLessonNames(subject: "架空科目A", teacher: "架空教員A", room: "架空教室A")
        var next = normal.lessons[0]
        next.period = 2
        normal.lessons.append(next)
        let merged = TimetableSchedule.blocks(on: day, className: "1_A", timetable: normal,
                                               changes: nil, includesChanges: false)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].startPeriod, 1)
        XCTAssertEqual(merged[0].endPeriod, 2)
        normal.lessons[1].names = TimetableLessonNames(subject: "架空科目A", teacher: "架空教員B", room: "架空教室A")
        XCTAssertEqual(TimetableSchedule.blocks(on: day, className: "1_A", timetable: normal,
                                                 changes: nil, includesChanges: false).count, 2)

        func exam(_ period: Int) -> SpecialScheduleLesson {
            SpecialScheduleLesson(date: day.iso8601, className: "1_A", period: period,
                                  spanStart: period, spanEnd: period, timeRange: "09:00〜09:45",
                                  lines: ["架空科目B", "架空教員B", "架空教室B"], page: 1)
        }
        let special = SpecialScheduleAnalysis(kind: .exam, sourceDigest: "fictional", sourceName: "fictional.pdf",
                                              parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032,
                                              coveredDates: [day.iso8601], coveredClasses: ["1_A"],
                                              periodTimes: [1: "09:00〜09:45", 2: "10:00〜10:45"],
                                              lessons: [exam(1), exam(2)])
        let examCards = TimetableSchedule.blocks(on: day, className: "1_A", timetable: normal,
                                                  changes: nil, includesChanges: false, specials: [special])
        XCTAssertEqual(examCards.count, 1)
        XCTAssertEqual(examCards[0].endPeriod, 2)

        let returned = SpecialScheduleAnalysis(kind: .examReturn, sourceDigest: "fictional",
                                                sourceName: "fictional.pdf", parsedAt: Date(timeIntervalSince1970: 0),
                                                schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: ["1_A"],
                                                periodTimes: [1: "09:00〜09:45", 2: "10:00〜10:45"],
                                                lessons: [exam(1), exam(2)])
        let returnCards = TimetableSchedule.blocks(on: day, className: "1_A", timetable: normal,
                                                    changes: nil, includesChanges: false, specials: [returned])
        XCTAssertEqual(returnCards.count, 1)
        XCTAssertEqual(returnCards[0].endPeriod, 2)
        let combined = TimetableSchedule.blocks(on: day, className: "1_A", timetable: normal,
                                                 changes: nil, includesChanges: false, specials: [special, returned])
        XCTAssertEqual(combined.count, 2)
        XCTAssertEqual(combined.map(\.endPeriod), [2, 2])
    }

    func testOverlappingChangesUseSeparateLanes() {
        func change(_ period: String) -> ScheduleChange {
            ScheduleChange(change_date: "2032-04-05", class_name: "1_A", period: period,
                           before_subject: "架空科目A", after_subject: "架空科目B",
                           teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        }
        let blocks = [
            TimetableSchedule.GridBlock(startPeriod: 1, endPeriod: 2, content: .change(change("1,2"))),
            TimetableSchedule.GridBlock(startPeriod: 2, endPeriod: 2, content: .change(change("2"))),
            TimetableSchedule.GridBlock(startPeriod: 3, endPeriod: 3, content: .change(change("3")))
        ]
        XCTAssertEqual(TimetableSchedule.positioned(blocks).map(\.lane), [0, 1, 0])
    }

    func testSeventhAndEighthPeriodSpanKeepsSeparateEighthPeriodInAnotherLane() throws {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        var normal = timetable(term: "前期")
        func lesson(_ period: Int, _ subject: String) -> PDFLesson {
            PDFLesson(className: "1_A", weekday: 1, period: period,
                      names: TimetableLessonNames(subject: subject, teacher: "架空教員A", room: "架空教室A"),
                      sourceText: subject, page: 1)
        }
        normal.lessons = [lesson(7, "架空科目A"), lesson(8, "架空科目A"), lesson(8, "架空科目B")]
        let placed = TimetableSchedule.positioned(TimetableSchedule.blocks(
            on: day, className: "1_A", timetable: normal, changes: nil, includesChanges: false))
        XCTAssertEqual(placed.map { ($0.block.startPeriod, $0.block.endPeriod, $0.lane) }
            .map { "\($0.0)-\($0.1)-\($0.2)" }, ["7-8-0", "8-8-1"])
    }

    func testSelectableClassesIncludeAbsentKnownClasses() {
        XCTAssertEqual(TimetableSchedule.selectableClasses.count, 20)
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("1_ES"))
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("5_IT"))
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("AI_2"))
        XCTAssertFalse(TimetableSchedule.selectableClasses.contains("AI_IT"))
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

    func testInternationalStudentFilterUsesNormalizedSubjectPrefix() throws {
        let lesson = PDFLesson(className: "1_ZZ", weekday: 1, period: 1,
                               names: TimetableLessonNames(subject: "留 架空科目A"), sourceText: "", page: 1)
        let change = ScheduleChange(change_date: "2032-04-05", class_name: "1_ZZ", period: "1",
                                    before_subject: "架空科目A", after_subject: "留　架空科目B",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        XCTAssertFalse(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: false))
        XCTAssertFalse(TimetableSchedule.shouldDisplay(change, isInternationalStudent: false))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: true))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(change, isInternationalStudent: true))
        XCTAssertTrue(TimetableSchedule.isInternationalStudentSubject("留架空科目A"))
        XCTAssertFalse(TimetableSchedule.isInternationalStudentSubject("架空科目A 留"))
        var adjacent = lesson
        adjacent.names = TimetableLessonNames(subject: "留架空科目A")
        XCTAssertFalse(TimetableSchedule.shouldDisplay(adjacent, isInternationalStudent: false))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(adjacent, isInternationalStudent: true))
        var timetableAnalysis = timetable(term: "前期")
        timetableAnalysis.lessons = [adjacent]
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        XCTAssertTrue(TimetableSchedule.blocks(on: day, className: "1_ZZ", timetable: timetableAnalysis,
                                               changes: nil, includesChanges: false,
                                               isInternationalStudent: false).isEmpty)
        XCTAssertEqual(TimetableSchedule.blocks(on: day, className: "1_ZZ", timetable: timetableAnalysis,
                                                changes: nil, includesChanges: false,
                                                isInternationalStudent: true).count, 1)
        var adjacentChange = change
        adjacentChange.after_subject = "留架空科目B"
        XCTAssertFalse(TimetableSchedule.shouldDisplay(adjacentChange, isInternationalStudent: false))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(adjacentChange, isInternationalStudent: true))
        let special = TimetableSchedule.SpecialItem(kind: .exam,
            lesson: SpecialScheduleLesson(date: "2032-04-05", className: "1_ZZ", period: 1,
                                          spanStart: 1, spanEnd: 1, timeRange: nil,
                                          lines: ["留架空科目C"], page: 1), timeRange: nil)
        XCTAssertFalse(TimetableSchedule.shouldDisplay(special, isInternationalStudent: false))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(special, isInternationalStudent: true))
    }

    func testInternationalStudentMappingFlagHidesNonPrefixedSubjectsAcrossSources() throws {
        let matchedByRule: (String, String) -> Bool = { subject, className in
            subject == "架空科目D" && className == "1_ZZ"
        }
        let lesson = PDFLesson(className: "1_ZZ", weekday: 1, period: 1,
                               names: TimetableLessonNames(subject: "架空科目D"), sourceText: "", page: 1)
        let change = ScheduleChange(change_date: "2032-04-05", class_name: "1_ZZ", period: "1",
                                    before_subject: "架空科目A", after_subject: "架空科目D",
                                    teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        let special = TimetableSchedule.SpecialItem(kind: .examReturn,
            lesson: SpecialScheduleLesson(date: "2032-04-05", className: "1_ZZ", period: 1,
                                          spanStart: 1, spanEnd: 1, timeRange: nil,
                                          lines: ["架空科目D"], page: 1), timeRange: nil)
        XCTAssertFalse(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: false,
                                                       matchedByRule: matchedByRule))
        XCTAssertFalse(TimetableSchedule.shouldDisplay(change, isInternationalStudent: false,
                                                       matchedByRule: matchedByRule))
        XCTAssertFalse(TimetableSchedule.shouldDisplay(special, isInternationalStudent: false,
                                                       matchedByRule: matchedByRule))
        XCTAssertTrue(TimetableSchedule.shouldDisplay(lesson, isInternationalStudent: true,
                                                      matchedByRule: matchedByRule))
        var otherClass = lesson
        otherClass.className = "2_ZZ"
        XCTAssertTrue(TimetableSchedule.shouldDisplay(otherClass, isInternationalStudent: false,
                                                      matchedByRule: matchedByRule))
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
