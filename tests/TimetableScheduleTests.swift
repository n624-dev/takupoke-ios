import XCTest
@testable import TakupokeParsing

final class TimetableScheduleTests: XCTestCase {
    func testAcceptedSourceIndexMatchesOriginalSelectorsAndBlocksAcrossScopes() throws {
        let start = try XCTUnwrap(SchoolDate(iso8601:"2032-04-05"))
        var normal = timetable(term:"前期")
        normal.lessons = (1...5).flatMap { weekday in (1...8).flatMap { period in
            ["1_A","1_CN","1_1"].map { name in
                PDFLesson(className:name,weekday:weekday,period:period,names:.init(subject:period == 3 ? "留架空科目":"架空科目A",teacher:"架空教員A"),sourceText:"架空本文",page:1)
            }
        } }
        var parallel = normal.lessons[0]; parallel.names = .init(subject:"架空並記",teacher:"架空教員B")
        normal.lessons.insert(parallel,at:1)
        func change(_ date:String,_ period:String,_ note:String) -> ScheduleChange {
            ScheduleChange(change_date:date,class_name:"1_A",period:period,before_subject:"架空科目A",after_subject:"架空変更",teacher:"架空教員C",room:"架空室",note:note,raw_text:"架空原文",canonical_text:"")
        }
        let changes = ChangeAnalysis(sourceDigest:"fictional-changes",sourceName:"fictional.xlsx",defaultYear:2032,
            parsedAt:normal.parsedAt,records:[change(start.iso8601,"1,2","休講"),change(start.iso8601,"1,2","補講"),
                change(start.iso8601,"1,3",""),change("2032-4-06","1","")])
        var calendar = [PDFSchoolEvent]()
        for (offset,type) in [(0,PDFEventClassification.EventType.noClass),(1,.weekdayOverride),(2,.supplementary)] {
            calendar.append(PDFSchoolEvent(date:start.addingDays(offset)!.iso8601,scope:"共通",title:"架空行事\(offset)",page:1,
                classification:.init(type:type,scheduleDay:type == .weekdayOverride ? 1:nil)))
        }
        calendar.append(.init(date:start.addingDays(3)!.iso8601,scope:"共通",title:"架空API授業なし",page:1,classification:.init(type:.noClass),apiTag:"授業なし"))
        var review = PDFSchoolEvent(date:start.addingDays(4)!.iso8601,scope:"共通",title:"架空範囲確認",page:1)
        review.endDate = start.addingDays(30)!.iso8601; review.periodNeedsReview = true; calendar.append(review)
        var range = review; range.title = "架空期間"; range.periodNeedsReview = false
        range.endDate = start.addingDays(9)!.iso8601; calendar.append(range)
        let events = PDFAnalysis(kind:.events,sourceDigest:"fictional-events",sourceName:"fictional.json",parsedAt:normal.parsedAt,
            schoolYear:2032,term:nil,lessons:[],events:calendar,notices:[])
        let lesson = SpecialScheduleLesson(date:start.addingDays(5)!.iso8601,className:"1_A",period:2,spanStart:2,spanEnd:2,timeRange:nil,lines:["架空特殊科目"],page:1)
        let special = SpecialScheduleAnalysis(kind:.exam,sourceDigest:"fictional-special",sourceName:"fictional.pdf",parsedAt:normal.parsedAt,
            schoolYear:2032,coveredDates:[],coveredClasses:["1_A"],periodTimes:[2:"09:50〜10:35"],lessons:[lesson])
        let sources = [special,special] // Duplicate evidence remains duplicated.
        let index = TimetableSchedule.SourceIndex(timetable:normal,changes:changes,events:events,specials:sources)
        let matched: (String,String,Int?) -> Bool = { subject,name,_ in subject == "架空変更" && name == "1_A" }
        for offset in -7...28 {
            let day = start.addingDays(offset)!
            XCTAssertEqual(index.plan(on:day),TimetableSchedule.dayPlan(on:day,events:events))
            for includes in [false,true] { for name in ["1_A","1_CN","fictional-absent"] {
                for period in 1...8 {
                    XCTAssertEqual(index.slot(on:day,period:period,className:name,includesChanges:includes),
                        TimetableSchedule.slot(on:day,period:period,className:name,timetable:normal,changes:changes,includesChanges:includes,events:events,specials:sources))
                }
                for international in [false,true] {
                    let original = TimetableSchedule.blocks(on:day,className:name,timetable:normal,changes:changes,includesChanges:includes,
                        events:events,specials:sources,isInternationalStudent:international,matchedByRule:matched)
                    let indexed = TimetableSchedule.blocks(on:day,className:name,timetable:normal,changes:changes,includesChanges:includes,
                        events:events,specials:sources,isInternationalStudent:international,matchedByRule:matched,sourceIndex:index)
                    XCTAssertEqual(indexed,original)
                }
            } }
        }
        for offset in 0..<520 {
            for period in 1...8 { _ = index.slot(on:start.addingDays(offset)!,period:period,className:"1_A",includesChanges:true) }
        }
        XCTAssertLessThanOrEqual(index.cachedPlanCount,512); XCTAssertLessThanOrEqual(index.cachedSlotCount,4096)
    }

    @MainActor func testProjectionCacheUsesGenerationAndSuspendsBeforeRebuilding() async throws {
        let normal = timetable(term:"前期"), cache = TimetableProjectionCache()
        let key = TimetableProjectionCache.Key(materials:UUID(),specials:UUID(),events:UUID())
        var builds = 0
        func build() -> TimetableSchedule.SourceIndex {
            builds += 1; return .init(timetable:normal,changes:nil,events:nil,specials:[])
        }
        let first = cache.sourceIndex(for:key,make:build)
        XCTAssertTrue(first === cache.sourceIndex(for:key,make:build)); XCTAssertEqual(builds,1)
        cache.suspend()
        let hidden = cache.sourceIndex(for:key,make:build)
        XCTAssertEqual(builds,1)
        XCTAssertTrue(hidden.slot(on:SchoolDate(iso8601:"2032-04-05")!,period:1,className:"1_A",includesChanges:true).baseLessons.isEmpty)
        cache.resume()
        XCTAssertFalse(first === cache.sourceIndex(for:key,make:build)); XCTAssertEqual(builds,2)
        let next = TimetableProjectionCache.Key(materials:UUID(),specials:key.specials,events:key.events)
        _ = cache.sourceIndex(for:next,make:build); XCTAssertEqual(builds,3)
        var remapped = normal
        remapped.lessons[0].names = .init(subject:"架空科目A",subjectFullName:"架空正式名称")
        XCTAssertFalse(TimetableSchedule.sameProjection(normal,remapped))
        remapped = normal; remapped.notices.append("架空読み込み状態")
        XCTAssertTrue(TimetableSchedule.sameProjection(normal,remapped))
    }
    func timetable(term: String?) -> PDFAnalysis {
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

    func testSelectableClassesIncludeAbsentKnownClasses() {
        XCTAssertEqual(TimetableSchedule.selectableClasses.count, 20)
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("1_ES"))
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("5_IT"))
        XCTAssertTrue(TimetableSchedule.selectableClasses.contains("AI_2"))
        XCTAssertFalse(TimetableSchedule.selectableClasses.contains("AI_IT"))
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
        let matchedByRule: (String, String, Int?) -> Bool = { subject, className, _ in
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

}
