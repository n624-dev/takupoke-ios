import XCTest
@testable import TakupokeParsing

extension TimetableScheduleTests {
    private func hiddenChangeFixture() throws -> (SchoolDate, PDFAnalysis, ScheduleChange) {
        let day = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        var normal = timetable(term: "前期")
        normal.lessons = (1...2).map { period in
            PDFLesson(className: "1_A", weekday: 1, period: period,
                names: TimetableLessonNames(subject: "架空科目A", teacher: "架空教員A"),
                sourceText: "", page: 1)
        }
        let cancellation = ScheduleChange(change_date: day.iso8601, class_name: "1_A", period: "1,2",
            before_subject: "留架空科目B", after_subject: "", teacher: "", room: "",
            note: "休講", raw_text: "", canonical_text: "")
        return (day, normal, cancellation)
    }

    func testHiddenInternationalCancellationPreservesOrdinaryLessonsAndClock() throws {
        let (day, normal, cancellation) = try hiddenChangeFixture()
        let mapped: (String, String, Int?) -> Bool = { subject, className, _ in subject == "架空科目C" && className == "1_A" }
        var nonPrefixed = cancellation
        nonPrefixed.before_subject = "架空科目C"
        for (row, match) in [(cancellation, nil), (nonPrefixed, Optional(mapped))] {
            let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                defaultYear: 2032, parsedAt: Date(timeIntervalSince1970: 0), records: [row])
            let schedule = TimetableDaySchedule(timetable: normal, changes: analysis,
                events: nil, specials: [], includesChanges: true)
            for date in [day, try XCTUnwrap(day.addingDays(7))] {
                let blocks = schedule.blocks(on: date, className: "1_A", international: false,
                    matchedByRule: match)
                XCTAssertEqual(blocks.count, 1)
                let block = try XCTUnwrap(blocks.first)
                guard case .normal(let lesson) = block.content else { return XCTFail("Expected ordinary lesson") }
                XCTAssertEqual(lesson.names.subject, "架空科目A")
                XCTAssertEqual(block.startPeriod, 1)
                XCTAssertEqual(block.endPeriod, 2)
                XCTAssertEqual(schedule.cardTime(block, on: date, className: "1_A"), "08:50〜10:20")
                XCTAssertEqual(schedule.commonPeriodTime(1, days: [date], classes: ["1_A"],
                    international: false, matchedByRule: match), "08:50〜09:35")
            }
            let included = schedule.blocks(on: day, className: "1_A", international: true,
                matchedByRule: match)
            guard case .change(let visible) = try XCTUnwrap(included.first).content else {
                return XCTFail("Expected the explicit international display to include the cancellation")
            }
            XCTAssertEqual(visible, row)
            // Filtering is a projection; every original row remains available for details.
            XCTAssertEqual(TimetableSchedule.changes(on: day, className: "1_A", analysis: analysis), [row])
            XCTAssertEqual(analysis.records, [row])
        }
    }

    func testHiddenChangesDoNotOverrideVisibleCancellationOrMakeupPriority() throws {
        let (day, normal, hiddenCancellation) = try hiddenChangeFixture()
        var hiddenMakeup = hiddenCancellation
        hiddenMakeup.note = "補講"
        hiddenMakeup.after_subject = "留架空科目B"
        var visibleCancellation = hiddenCancellation
        visibleCancellation.before_subject = "架空科目A"
        var visibleMakeup = visibleCancellation
        visibleMakeup.note = "補講"
        visibleMakeup.after_subject = "架空科目D"
        for records in [[hiddenCancellation, visibleMakeup], [visibleMakeup, hiddenCancellation],
                        [hiddenMakeup, visibleCancellation], [visibleCancellation, hiddenMakeup]] {
            let analysis = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                defaultYear: 2032, parsedAt: Date(timeIntervalSince1970: 0), records: records)
            let schedule = TimetableDaySchedule(timetable: normal, changes: analysis,
                events: nil, specials: [], includesChanges: true)
            let cards = schedule.blocks(on: day, className: "1_A", international: false)
            XCTAssertEqual(cards.count, 1)
            guard case .change(let selected) = try XCTUnwrap(cards.first).content else {
                return XCTFail("Expected an ordinary change to remain authoritative")
            }
            XCTAssertEqual(selected, records.contains(visibleMakeup) ? visibleMakeup : visibleCancellation)
            XCTAssertEqual(cards.first?.endPeriod, 2)
            XCTAssertEqual(TimetableSchedule.slot(on: day, period: 1, className: "1_A",
                timetable: normal, changes: analysis, includesChanges: true).changes, records)
        }
    }

    func testHiddenCancellationPreservesSpecialLessonsWithoutFillingSpecialBlanks() throws {
        let (day, normal, cancellation) = try hiddenChangeFixture()
        let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
            defaultYear: 2032, parsedAt: Date(timeIntervalSince1970: 0), records: [cancellation])
        for kind in SpecialScheduleKind.allCases {
            let source = SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional",
                sourceName: "fictional.pdf", parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032,
                coveredDates: [day.iso8601], coveredClasses: ["1_A"],
                periodTimes: [1: "09:00〜09:40", 2: "10:00〜10:40"],
                lessons: [SpecialScheduleLesson(date: day.iso8601, className: "1_A", period: 1,
                    spanStart: 1, spanEnd: 1, timeRange: "09:00〜09:40", lines: ["架空科目E"], page: 1)])
            let schedule = TimetableDaySchedule(timetable: normal, changes: changes,
                events: nil, specials: [source], includesChanges: true)
            let cards = schedule.blocks(on: day, className: "1_A", international: false)
            XCTAssertEqual(cards.count, 1)
            guard case .special(let item) = try XCTUnwrap(cards.first).content else {
                return XCTFail("Expected the special document to keep its precedence")
            }
            XCTAssertEqual(item.kind, kind)
            XCTAssertEqual(item.lesson.subject, "架空科目E")
            XCTAssertEqual(cards.first?.endPeriod, 1)
            XCTAssertEqual(schedule.commonPeriodTime(1, days: [day], classes: ["1_A"],
                international: false), "09:00〜09:40")
            XCTAssertNil(schedule.commonPeriodTime(2, days: [day], classes: ["1_A"], international: false))
        }
    }

    func testHiddenCancellationKeepsWeekendWithWeekdayOverrideVisible() throws {
        let (monday, normal, cancellation) = try hiddenChangeFixture()
        let saturday = try XCTUnwrap(monday.addingDays(5))
        var row = cancellation
        row.change_date = saturday.iso8601
        let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
            defaultYear: 2032, parsedAt: Date(timeIntervalSince1970: 0), records: [row])
        let events = PDFAnalysis(kind: .events, sourceDigest: "fictional", sourceName: "fictional",
            parsedAt: Date(timeIntervalSince1970: 0), schoolYear: 2032, term: nil, lessons: [],
            events: [PDFSchoolEvent(date: saturday.iso8601, scope: "共通", title: "架空曜日振替A", page: 0,
                classification: .init(type: .weekdayOverride, scheduleDay: 1))], notices: [])
        let days = TimetableSchedule.displayedDays(weekStart: monday, classes: ["1_A"], timetable: normal,
            changes: changes, events: events, includesChanges: true, isInternationalStudent: false)
        XCTAssertTrue(days.contains(saturday))
        let cards = TimetableSchedule.blocks(on: saturday, className: "1_A", timetable: normal,
            changes: changes, includesChanges: true, events: events)
        XCTAssertEqual(cards.count, 1)
        guard case .normal = try XCTUnwrap(cards.first).content else { return XCTFail("Expected weekday override lesson") }
        XCTAssertEqual(cards.first?.endPeriod, 2)
        // Without a weekday override there is no normal Saturday lesson to invent.
        XCTAssertFalse(TimetableSchedule.displayedDays(weekStart: monday, classes: ["1_A"], timetable: normal,
            changes: changes, events: nil, includesChanges: true, isInternationalStudent: false).contains(saturday))
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
        XCTAssertEqual(makeup.cardKindLabel, "補講")
        XCTAssertEqual(cancellation.cardKindLabel, "休講")
        XCTAssertEqual(change("1", "連絡", "架空科目C").cardKindLabel, "変更")
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
}
