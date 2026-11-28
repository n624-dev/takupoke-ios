import XCTest
@testable import TakupokeParsing

final class TimetableScheduleTests: XCTestCase {
    func testWeekRangeRetainsBothDatesAtNarrowWidths() throws {
        for (start, full, compact) in [("2026-11-23", "11/23〜11/29", "11/23〜29"),
                                        ("2026-11-30", "11/30〜12/6", "11/30〜12/6"),
                                        ("2026-12-28", "12/28〜1/3", "12/28〜1/3")] {
            let day = try XCTUnwrap(SchoolDate(iso8601: start))
            let end = try XCTUnwrap(day.addingDays(6))
            XCTAssertEqual(day.weekRangeLabel(ending: end, compact: false), full)
            XCTAssertEqual(day.weekRangeLabel(ending: end, compact: true), compact)
        }
    }

    func testWeekPullCentersOnVisibleLessonsAndContinuesFromNativeEdge() {
        let top = CGRect(x: 0, y: 0, width: 340, height: 420)
        let lower = CGRect(x: 0, y: 240, width: 340, height: 400)
        XCTAssertEqual(WeekEdgePull.badgeCenter(visible: top, headerHeight: 60), 240)
        XCTAssertEqual(WeekEdgePull.badgeCenter(visible: lower, headerHeight: 60), 440)
        XCTAssertEqual(WeekEdgePull.badgeCenter(visible: CGRect(x: 0, y: 0, width: 300, height: 40),
                                                headerHeight: 55), 20)
        // The visible gaps are 42 and 31pt; the travel that qualified the pull can be much larger.
        XCTAssertEqual(WeekEdgePull.incomingOffset(viewportWidth: 340, offset: -42, scrollRange: 90, days: -7), -298)
        XCTAssertEqual(WeekEdgePull.incomingOffset(viewportWidth: 340, offset: 121, scrollRange: 90, days: 7), 309)
        XCTAssertEqual(WeekEdgePull.incomingOffset(viewportWidth: 340, offset: 0, scrollRange: 0, days: 7), 340)
    }

    func testWeekBadgeHasClearanceOnBothEdgesAndInShortOrScrolledBodies() {
        for visible in [CGRect(x: 0, y: 0, width: 340, height: 128),
                        CGRect(x: 0, y: 250, width: 340, height: 380)] {
            for previous in [false, true] {
                for preferredY in [visible.minY, visible.midY, visible.maxY] {
                    let frame = WeekEdgePull.badgeFrame(visible: visible, preferredY: preferredY,
                        size: CGSize(width: 118, height: 68), previous: previous, margin: 10)
                    // Check the four physical edges without relying on corelibs
                    // CGRect.contains for a translated viewport. The required
                    // clearance is still 10pt on every side.
                    XCTAssertGreaterThanOrEqual(frame.minX, visible.minX + 10)
                    XCTAssertGreaterThanOrEqual(frame.minY, visible.minY + 10)
                    XCTAssertLessThanOrEqual(frame.maxX, visible.maxX - 10)
                    XCTAssertLessThanOrEqual(frame.maxY, visible.maxY - 10)
                    XCTAssertEqual(previous ? frame.minX - visible.minX : visible.maxX - frame.maxX, 10)
                }
            }
        }
    }

    func testLivePageHandoffPreservesTheReleasedContentPosition() {
        for range: CGFloat in [0, 90, 500] {
            for offset in [-42, CGFloat(0), range / 2, range, range + 31] {
                let translation = WeekEdgePull.rubberBandOffset(offset: offset, scrollRange: range)
                let edge = offset + translation
                XCTAssertGreaterThanOrEqual(edge, 0)
                XCTAssertLessThanOrEqual(edge, range)
                // Compare actual content coordinates before and after normalizing the scroll.
                for contentX: CGFloat in [0, 58, 184] {
                    XCTAssertEqual(contentX - offset, contentX - edge + translation, accuracy: 0.001)
                }
            }
        }
    }

    func testWeekPullConsumesHiddenColumnsAndUsesTheFinalFingerPosition() throws {
        let horizontal = CGPoint(x: 250, y: 3)
        let narrow = try XCTUnwrap(WeekEdgePull(velocity: horizontal, offset: 0, scrollRange: 0))
        let wide = try XCTUnwrap(WeekEdgePull(velocity: horizontal, offset: 70, scrollRange: 260))
        XCTAssertNil(WeekEdgePull(velocity: CGPoint(x: 3, y: 80), offset: 0, scrollRange: 0))
        XCTAssertEqual(narrow.distance(for: CGPoint(x: 120, y: 150)), 0)
        XCTAssertEqual(wide.distance(for: CGPoint(x: -190, y: 2)), 0)
        XCTAssertEqual(wide.distance(for: CGPoint(x: 70, y: 2)), 0)
        XCTAssertEqual(wide.distance(for: CGPoint(x: -305, y: 2)), -115)
        XCTAssertEqual(wide.distance(for: CGPoint(x: 185, y: 2)), 115)
        func release(_ x: CGFloat, previous: Bool = true, next: Bool = true) -> Int {
            WeekEdgePull.weekOffset(onRelease: narrow.distance(for: CGPoint(x: x, y: 0)), previous: previous, next: next)
        }
        XCTAssertEqual([35, 130, 70].map { release($0) }, [0, -7, 0])
        XCTAssertEqual([-130, -70].map { release($0) }, [7, 0])
        XCTAssertEqual(release(350), -7)
        XCTAssertEqual(release(-350), 7)
        XCTAssertEqual(release(350, previous: false), 0)
        XCTAssertEqual(release(-350, next: false), 0)
    }

    func testWeekPreparationIncludesTheWeekBeyondArrivalAndStaysBounded() throws {
        let first = try XCTUnwrap(SchoolDate(iso8601: "2026-11-02"))
        let weeks = try (0..<6).map { index in try XCTUnwrap(first.addingDays(index * 7)) }
        let bounds = weeks[0]...weeks[5]
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[2], arriving: nil, within: bounds), Array(weeks[1...3]))
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[2], arriving: weeks[5], within: bounds), Array(weeks[1...3]))
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[2], arriving: weeks[3], within: bounds), Array(weeks[1...4]))
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[3], arriving: weeks[2], within: bounds), Array(weeks[1...4]))
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[1], arriving: weeks[0], within: bounds), Array(weeks[0...2]))
        XCTAssertEqual(WeekEdgePull.preparedWeeks(selected: weeks[4], arriving: weeks[5], within: bounds), Array(weeks[3...5]))
    }

    func testEachWeekPullWaitsForItsOwnReadyPageAndCommitsOnce() throws {
        let first = try XCTUnwrap(SchoolDate(iso8601: "2026-11-02"))
        let weeks = try (0..<5).map { index in try XCTUnwrap(first.addingDays(index * 7)) }
        let bounds = weeks[0]...weeks[4]
        var releases = WeekPullReleases()
        releases.append(from: weeks[0], distance: 125, within: bounds)
        releases.append(from: weeks[0], distance: -114, within: bounds)
        XCTAssertTrue(releases.isEmpty)
        releases.append(from: weeks[0], distance: -125, within: bounds)
        releases.append(from: weeks[0], distance: -180, within: bounds)
        releases.append(from: weeks[1], distance: -125, within: bounds)
        releases.append(from: weeks[2], distance: -125, within: bounds)
        releases.append(from: weeks[3], distance: 125, within: bounds)
        XCTAssertEqual(releases.lastDestination, weeks[2])
        XCTAssertEqual(weeks.filter(releases.containsDestination), Array(weeks[1...3]))

        let onlyFirst = Set(weeks.prefix(1))
        XCTAssertNil(releases.consume(from: weeks[0], isReady: onlyFirst.contains))
        XCTAssertNil(releases.consume(from: weeks[1], isReady: { _ in true }))
        XCTAssertTrue(releases.containsDestination(weeks[2]))
        for (source, target, keepsWeekTwo) in [(0, 1, true), (1, 2, true), (2, 3, true), (3, 2, false)] {
            XCTAssertEqual(releases.consume(from: weeks[source], isReady: { _ in true }),
                           .init(source: weeks[source], destination: weeks[target]))
            XCTAssertEqual(releases.containsDestination(weeks[2]), keepsWeekTwo)
        }
        XCTAssertFalse(releases.containsDestination(weeks[2]))
        XCTAssertNil(releases.consume(from: weeks[2], isReady: { _ in true }))
        releases.append(from: weeks[2], distance: 125, within: bounds)
        XCTAssertTrue(releases.containsDestination(weeks[1]))
        releases.cancel()
        XCTAssertFalse(weeks.contains(where: releases.containsDestination))
        XCTAssertNil(releases.consume(from: weeks[2], isReady: { _ in true }))
    }

    func testEarlyContactsKeepTheirDisplacementsWhileTheNextScrollViewPrepares() throws {
        let current = try XCTUnwrap(SchoolDate(iso8601: "2026-11-02"))
        let upcoming = try XCTUnwrap(current.addingDays(7))
        var contacts = WeekDeferredPulls()
        contacts.append(.init(week: current, start: nil, translation: CGPoint(x: -160, y: 4)))
        contacts.append(.init(week: nil, start: nil, translation: CGPoint(x: 160, y: 0)))
        XCTAssertNil(contacts.consume(on: upcoming, startingPosition: { .init(offset: 0, range: 0) }))
        XCTAssertNil(contacts.consume(on: current, startingPosition: { nil }))

        let first = try XCTUnwrap(contacts.consume(on: current, startingPosition: { .init(offset: 0, range: 40) }))
        XCTAssertEqual(first.start.offset(after: first.translation), 40)
        XCTAssertEqual(first.start.pullDistance(after: first.translation), -120)

        let second = try XCTUnwrap(contacts.consume(on: upcoming, startingPosition: { .init(offset: 55, range: 120) }))
        XCTAssertEqual(second.start.offset(after: second.translation), 0)
        XCTAssertEqual(second.start.pullDistance(after: second.translation), 105, "Use the arriving week’s hidden columns")
        XCTAssertTrue(contacts.isEmpty)

        contacts.append(.init(week: upcoming, start: .init(offset: 4, range: 20), translation: CGPoint(x: -160, y: 1)))
        let measured = try XCTUnwrap(contacts.consume(on: upcoming, startingPosition: { nil }))
        XCTAssertEqual(measured.start.pullDistance(after: measured.translation), -144)
        contacts.append(.init(week: upcoming, start: nil, translation: CGPoint(x: -190, y: 4)))
        contacts.cancel()
        XCTAssertNil(contacts.consume(on: upcoming, startingPosition: { .init(offset: 0, range: 40) }))
    }

    @MainActor func testBoundedRenderingMemoKeepsNilAndExactUnicodeInputs() async throws {
        let memo = TimetableBoundedMemo<TimetableRenderedText,String?>(limit:2)
        var calls = 0
        func query(_ text:String) -> String? {
            memo.value(for:.init(value:text)) { calls += 1; return nil }
        }
        XCTAssertNil(query("Aé")); XCTAssertNil(query("Aé")); XCTAssertEqual(calls,1)
        XCTAssertNil(query("Ae\u{301}")); XCTAssertNil(query("Ae\u{301}")); XCTAssertEqual(calls,2)
        XCTAssertEqual(memo.count,2)
        XCTAssertNil(query("架空本文")); XCTAssertEqual(memo.count,1)
        XCTAssertNil(query("Aé")); XCTAssertEqual(calls,4)
        memo.removeAll(); XCTAssertEqual(memo.count,0)
        XCTAssertNil(query("Aé")); XCTAssertEqual(calls,5)
    }
    @MainActor func testCommonClockCacheSeparatesDisplayScopeAndStopsAtRetentionBoundary() async throws {
        let cache = TimetableProjectionCache(), normal = timetable(term:"前期")
        let generation = TimetableProjectionCache.Key(materials:UUID(),specials:UUID(),events:UUID())
        let index = cache.sourceIndex(for:generation) { .init(timetable:normal,changes:nil,events:nil,specials:[]) }
        let day = SchoolDate(iso8601:"2032-04-05")!
        func key(period:Int = 1,days:[SchoolDate]? = nil,classes:[String] = [],changes:Bool = false,
                 international:Bool = false,mapping:String = "",times:String = "") -> TimetableProjectionCache.ClockKey {
            .init(period:period,days:days ?? [day],classes:classes,includesChanges:changes,international:international,
                mappingRevision:mapping,timesRevision:times)
        }
        var computations = 0
        func clock(_ key:TimetableProjectionCache.ClockKey) -> String? {
            cache.periodTime(for:key,index:index) { computations += 1; return nil }
        }
        XCTAssertNil(clock(key())); XCTAssertNil(clock(key())); XCTAssertEqual(computations,1)
        for different in [key(period:2),key(days:[day.addingDays(1)!]),key(classes:["1_A"]),key(changes:true),
                          key(international:true),key(mapping:"fictional-mapping"),key(times:"fictional-times")] {
            XCTAssertNil(clock(different))
        }
        XCTAssertEqual(computations,8)
        cache.suspend(); XCTAssertNil(clock(key())); XCTAssertEqual(computations,8)
        cache.resume()
        _ = cache.sourceIndex(for:generation) { .init(timetable:normal,changes:nil,events:nil,specials:[]) }
        XCTAssertNil(clock(key())); XCTAssertEqual(computations,8) // The old index may not repopulate a new lifetime.
    }
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

    @MainActor func testReachableWeekCacheUsesCurrentSourcesAndDisplayScope() async throws {
        let cache = TimetableProjectionCache()
        let start = try XCTUnwrap(SchoolDate(iso8601: "2032-04-05"))
        let other = try XCTUnwrap(start.addingDays(7))
        let normal = timetable(term: "前期")
        let original = TimetableProjectionCache.Key(materials: UUID(), specials: UUID(), events: UUID())
        let key = TimetableProjectionCache.WeekBoundsKey(anchor: start, classes: ["1_A"], includesChanges: true)
        func build() -> TimetableSchedule.SourceIndex { .init(timetable: normal, changes: nil, events: nil, specials: []) }
        let firstIndex = cache.sourceIndex(for: original, make: build)
        let first = cache.reachableWeeks(for: key, index: firstIndex) { start...start }
        XCTAssertEqual(cache.reachableWeeks(for: key, index: firstIndex) { other...other }, first)
        for distinct in [
            TimetableProjectionCache.WeekBoundsKey(anchor: other, classes: key.classes, includesChanges: true),
            TimetableProjectionCache.WeekBoundsKey(anchor: start, classes: ["1_B"], includesChanges: true),
            TimetableProjectionCache.WeekBoundsKey(anchor: start, classes: key.classes, includesChanges: false)
        ] {
            XCTAssertEqual(cache.reachableWeeks(for: distinct, index: firstIndex) { other...other }, other...other)
        }
        let changed = TimetableProjectionCache.Key(materials: original.materials, specials: original.specials, events: UUID())
        let currentIndex = cache.sourceIndex(for: changed, make: build)
        XCTAssertEqual(cache.reachableWeeks(for: key, index: currentIndex) { other...other }, other...other)
        XCTAssertEqual(cache.reachableWeeks(for: key, index: firstIndex) { start...start }, start...start)
        XCTAssertEqual(cache.reachableWeeks(for: key, index: currentIndex) { start...start }, other...other)
        cache.suspend()
        XCTAssertEqual(cache.reachableWeeks(for: key, index: currentIndex) { start...start }, start...start)
        cache.resume()
        let newPeriodIndex = cache.sourceIndex(for: changed, make: build)
        XCTAssertEqual(cache.reachableWeeks(for: key, index: newPeriodIndex) { start...start }, start...start)
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

    func testWeekSlideClockKeepsNormalDurationAndLimitsSingleFrameCatchup() {
        let duration = 0.25
        for rate in [30.0, 60.0, 120.0] {
            var clock = WeekSlideClock()
            let interval = 1 / rate
            for frame in 1...Int(ceil(duration * rate)) {
                let start = Double(frame - 1) * interval
                let target = Double(frame) * interval
                XCTAssertEqual(clock.progress(timestamp: start, target: target, duration: duration),
                               min(1, target / duration), accuracy: 0.000001)
            }
        }

        var delayed = WeekSlideClock()
        let first = delayed.progress(timestamp: 0, target: 1.0 / 60, duration: duration)
        let afterStall = delayed.progress(timestamp: 0.100, target: 7.0 / 60, duration: duration)
        let next = delayed.progress(timestamp: 7.0 / 60, target: 8.0 / 60, duration: duration)
        XCTAssertEqual(first, (1.0 / 60) / duration, accuracy: 0.000001)
        XCTAssertEqual(afterStall - first, (1.0 / 30) / duration, accuracy: 0.000001)
        XCTAssertEqual(next - afterStall, (1.0 / 60) / duration, accuracy: 0.000001)
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

        let index = TimetableSchedule.SourceIndex(timetable: nil, changes: changes, events: nil, specials: [])
        for (includesChanges, expected) in [(true, bounds), (false, withoutChanges)] {
            XCTAssertEqual(TimetableSchedule.reachableWeekBounds(
                containing: opening, classes: ["1_A"], timetable: nil, changes: changes,
                events: nil, includesChanges: includesChanges, sourceIndex: index), expected)
        }
    }

}
