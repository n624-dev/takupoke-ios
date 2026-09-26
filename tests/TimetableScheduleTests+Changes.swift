import XCTest
@testable import TakupokeParsing

extension TimetableScheduleTests {
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
