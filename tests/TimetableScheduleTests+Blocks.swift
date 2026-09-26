import XCTest
@testable import TakupokeParsing

extension TimetableScheduleTests {
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
}
