import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

// Added acquisition/role safety checks use the certified Recovery contract.
// Explicit testStrict239 cases and StrictPDFCompatibilityTests exercise app Strict.

final class SpecialScheduleTests: XCTestCase {

    func testParsedMergedCellRetainsRawClockButItsRemainingFragmentUsesPeriodClock() throws {
        let parsed = try SpecialScheduleParser.parse((1...6).map { examPage($0, mergedFirstTwo: $0 == 1) }, kind: .exam, digest: "fictional", name: "fictional.pdf")
        let original = try XCTUnwrap(parsed.lessons.first { $0.date == "2026-04-01" && $0.className == "1_1" && $0.period == 2 })
        XCTAssertEqual(original.spanStart, 1); XCTAssertEqual(original.spanEnd, 2)
        XCTAssertEqual(original.timeRange, "08:50〜10:20")
        let day = try XCTUnwrap(SchoolDate(iso8601: original.date))
        let row = ScheduleChange(change_date: day.iso8601, class_name: "1_1", period: "1", before_subject: "", after_subject: "架空変更科目A", teacher: "", room: "", note: "補講", raw_text: "", canonical_text: "")
        let schedule = TimetableDaySchedule(timetable: nil, changes: ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2026, parsedAt: Date(), records: [row]), events: nil, specials: [parsed], includesChanges: true)
        let fragment = try XCTUnwrap(schedule.blocks(on: day, className: "1_1", international: false).first { $0.startPeriod == 2 })
        XCTAssertEqual(schedule.cardTime(fragment, on: day, className: "1_1"), "09:50〜10:35")
        XCTAssertFalse(schedule.isInProgress(fragment, on: day, className: "1_1", now: ISO8601DateFormatter().date(from: "2026-04-01T09:00:00+09:00")!))
        XCTAssertEqual(parsed.lessons.first { $0 == original }?.timeRange, "08:50〜10:20")
    }

    func testRepeatedLowerHeaderBandBelowMergedClassBorderUsesItsOwnRule() throws {
        let original = try SpecialScheduleParser.parse([returnPageWithMergedClassHeader(includeHeadings:false)],
            kind:.examReturn,digest:"fictional",name:"fictional.pdf")
        for scale in [1.0,1.3] {
            var page = returnPageWithMergedClassHeader()
            page.glyphs = page.glyphs.map { g in
                var n=g; n.x=17+g.x*scale; n.y=9+g.y*scale; n.width*=scale; n.height*=scale; return n
            }
            page.lines = page.lines.map { PDFRule(x1:17+$0.x1*scale,y1:9+$0.y1*scale,x2:17+$0.x2*scale,y2:9+$0.y2*scale) }
            page.width=17+page.width*scale; page.height=9+page.height*scale
            let result = try SpecialScheduleParser.parse([page],kind:.examReturn,digest:"fictional",name:"fictional.pdf")
            XCTAssertEqual(result.lessons,original.lessons)
            XCTAssertEqual(result.coveredClasses,original.coveredClasses)
            XCTAssertEqual(result.periodTimes,original.periodTimes)
            let target = try XCTUnwrap(result.lessons.first { $0.className == "1_1" && $0.period == 4 })
            let recorder = PDFReturnGeometryRecorder(lesson:target)
            _ = try PDF239SpecialScheduleParser.parse([page],kind:.examReturn,digest:"fictional",name:"fictional.pdf",geometry:recorder)
            let snapshot = try XCTUnwrap(recorder.snapshot)
            XCTAssertEqual(snapshot.firstClassCell.top,9+110*scale,accuracy:0.001)
            XCTAssertEqual(snapshot.contentTop,9+120*scale,accuracy:0.001)
            let headings = Set(snapshot.periodHeadingIDs)
            XCTAssertGreaterThan(headings.count,40)
            XCTAssertTrue(snapshot.cells.flatMap(\.adoptedRows).flatMap { $0 }.allSatisfy { !headings.contains($0) })
        }
    }

    func testSingleDayPeriodWordAndPartialSeparatorDoNotMoveTheBodyBoundary() throws {
        for page in [returnPageWithMergedClassHeader(repeatedDays:false),
                     returnPageWithMergedClassHeader(fullSeparator:false),
                     returnPageWithMergedClassHeader(centerOnlySeparator:true)] {
            let result = try SpecialScheduleParser.parse([page],kind:.examReturn,digest:"fictional",name:"fictional.pdf")
            XCTAssertTrue(result.lessons.contains { $0.lines.contains("3ｺﾏ") })
            let target = try XCTUnwrap(result.lessons.first { $0.className == "1_1" && $0.period == 3 })
            let recorder = PDFReturnGeometryRecorder(lesson:target)
            _ = try PDF239SpecialScheduleParser.parse([page],kind:.examReturn,digest:"fictional",name:"fictional.pdf",geometry:recorder)
            XCTAssertEqual(recorder.snapshot?.contentTop,110)
        }
    }

    func testReturnColumnHeadingsAreExcludedWithoutChangingLessonFields() throws {
        let original = try SpecialScheduleParser.parse([returnPageWithColumnHeadings(includeHeadings: false)],
            kind: .examReturn, digest: "fictional", name: "fictional.pdf")
        for text in ["4ｺﾏ", "４コマ", "4コマ目"] {
            let page = returnPageWithColumnHeadings(text)
            let rawBox = try PDF239Grid(page: page).box(270, 132)
            XCTAssertEqual(rawBox.top, 110)
            XCTAssertTrue(try PDF239Grid(page: page).timetableText(rawBox).first?.contains(text) == true)
            let result = try SpecialScheduleParser.parse([page], kind: .examReturn,
                digest: "fictional", name: "fictional.pdf")
            XCTAssertEqual(result.lessons, original.lessons)
            XCTAssertEqual(result.coveredClasses, original.coveredClasses)
            XCTAssertEqual(result.coveredDates, original.coveredDates)
            XCTAssertEqual(result.periodTimes, original.periodTimes)
            let lesson = try XCTUnwrap(result.lessons.first {
                $0.className == "1_1" && $0.date == "2026-04-01" && $0.period == 4
            })
            XCTAssertEqual(lesson.lines, ["架空科目L", "架空教員L", "架空教室L"])
            XCTAssertNil(result.recovery)
        }
    }

    func testMatchingPeriodWordsInsideTheClassTableAreRetained() throws {
        for text in ["4ｺﾏ", "４コマ", "架空4コマ科目"] {
            var page = returnPageWithSplitCell()
            page.glyphs.append(PDFGlyph(text: text, x: 265, y: 210, width: 28, height: 6))
            let result = try SpecialScheduleParser.parse([page], kind: .examReturn,
                digest: "fictional", name: "fictional.pdf")
            let lesson = try XCTUnwrap(result.lessons.first {
                $0.className == "2_CN" && $0.date == "2026-04-01" && $0.period == 4
            })
            XCTAssertEqual(lesson.lines, [text])
        }
    }

#if canImport(PDFKit)
    func testReturnColumnHeadingSeparationThroughNativePDFKit() throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["TAKUPOKE_STRICT_COMPATIBILITY_FIXTURES"])
        for filename in ["heading-return.pdf","merged-class-heading-return.pdf"] {
        let pages = try PDFKitReader.readSpecial(URL(fileURLWithPath: path)
            .appendingPathComponent(filename))
        let page = try XCTUnwrap(pages.first), grid = PDF239Grid(page: page)
        let header = try grid.timetableText(PDFBox(left: 356, top: 108, right: 428, bottom: 120)).joined()
        XCTAssertEqual(PDF239SchoolParser.key(header), "4コマ")
        let result = try SpecialScheduleParser.parse(pages, kind: .examReturn,
            digest: "independent", name: "fictional.pdf")
        XCTAssertEqual(result.lessons.count, 4)
        XCTAssertEqual(result.lessons.map(\.lines), Array(repeating:
            ["架空科目甲", "架空教員乙", "仮想教室丙"], count: 4))
        XCTAssertEqual(Set(result.lessons.map { "\($0.className)/\($0.date)/\($0.period)" }),
            ["1_1/2032-04-01/1", "1_1/2032-04-01/4", "2_ES/2032-04-02/2", "AI_2/2032-04-05/8"])
        XCTAssertNil(result.recovery)
        let target = try XCTUnwrap(result.lessons.first { $0.className == "1_1" && $0.period == 4 })
        let recorder = PDFReturnGeometryRecorder(lesson:target)
        let reread = try PDF239SpecialScheduleParser.parse(pages,kind:.examReturn,digest:"independent",name:"fictional.pdf",geometry:recorder)
        XCTAssertEqual(reread.lessons,result.lessons)
        let snapshot = try XCTUnwrap(recorder.snapshot)
        XCTAssertFalse(snapshot.limited)
        if filename == "merged-class-heading-return.pdf" {
            XCTAssertEqual(snapshot.firstClassCell.top,108,accuracy:0.1)
            XCTAssertEqual(snapshot.contentTop,120,accuracy:0.1)
            XCTAssertEqual(snapshot.cells.count,2)
            XCTAssertTrue(snapshot.cells[0].adoptedRows.isEmpty)
            XCTAssertEqual(snapshot.cells[1].adoptedRows.count,3)
            XCTAssertTrue(Set(snapshot.cells.flatMap(\.adoptedRows).flatMap { $0 }).isDisjoint(with:Set(snapshot.periodHeadingIDs)))
        } else {
            XCTAssertEqual(snapshot.cells.count,1)
            XCTAssertEqual(snapshot.cells[0].adoptedRows.count,3)
        }
        XCTAssertNotNil(recorder.report())
        }
    }
#endif

    func testStrict239RetainsEightCellLinesAndNonFixedSeventeenClassSet() throws {
        var pages = (1...6).map { examPage($0) }
        // A independently invented first cell with eight explicit PDF rows.
        pages[0].glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.y >= 110 && $0.y < 150 }
        for row in 0..<8 {
            for (offset, character) in "架空行\(row)".enumerated() {
                pages[0].glyphs.append(PDFGlyph(text:String(character),x:106+Double(offset)*3,
                    y:112+Double(row)*4,width:3,height:2,sourceLine:1000+row,sourceOrder:10000+row*100+offset))
            }
        }
        // 3-ES -> 3-XX is syntactically valid in 239.1; retain count/uniqueness.
        for index in pages[2].glyphs.indices where pages[2].glyphs[index].y == 70 &&
            [448.0,452.0].contains(pages[2].glyphs[index].x) {
            pages[2].glyphs[index].text = "X"
        }
        let result = try SpecialScheduleParser.parse(pages,kind:.exam,digest:"fictional",name:"fictional.pdf")
        let lesson = try XCTUnwrap(result.lessons.first { $0.date == "2026-04-01" && $0.className == "1_1" && $0.period == 1 })
        XCTAssertEqual(lesson.lines,(0..<8).map { "架空行\($0)" })
        XCTAssertEqual(result.coveredClasses.count,17)
        XCTAssertTrue(result.coveredClasses.contains("3_XX"))
        XCTAssertFalse(result.coveredClasses.contains("3_ES"))
        XCTAssertThrowsError(try SpecialScheduleParser.parseCertified(pages,kind:.exam,digest:"fictional",name:"fictional.pdf"))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-strict239-store-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store = try SpecialScheduleStore(root:root), bytes = Data("%PDF-fictional".utf8)
        let staging = store.newStagingURL()
        try bytes.write(to:staging)
        try store.save(staged:staging,analysis:result,originalName:"fictional.pdf",byteCount:bytes.count,digest:"fictional")
        XCTAssertEqual(try SpecialScheduleStore(root:root).records[.exam]?.analysis,result)
        pages[0].glyphs.append(PDFGlyph(text:"架空行8",x:106,y:146,width:15,height:1,sourceLine:1008,sourceOrder:10800))
        XCTAssertThrowsError(try SpecialScheduleParser.parse(pages,kind:.exam,digest:"fictional",name:"fictional.pdf")) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.lessonLines)
        }
    }
    func testStrict239RetainsPDFPeriodOrderAndReturnDateOrder() throws {
        let times = ["9:00~10:00","9:30~10:30","10:50~11:35","11:50~12:35","13:20~14:05","14:20~15:05"]
        let pages = (1...6).map { examPage($0,timingOverride:times) }
        let result = try SpecialScheduleParser.parse(pages,kind:.exam,digest:"fictional",name:"fictional.pdf")
        XCTAssertEqual(result.periodTimes[1],"09:00〜10:00")
        XCTAssertEqual(result.periodTimes[2],"09:30〜10:30")
        XCTAssertEqual(result.coveredClasses.count,17)
        XCTAssertNil(result.recovery)
        XCTAssertThrowsError(try SpecialScheduleParser.parseCertified(pages,kind:.exam,digest:"fictional",name:"fictional.pdf"))
        let returned = returnPageWithSplitCell(dateDays:[2,1,3,4,5])
        let returnedResult = try SpecialScheduleParser.parse([returned],kind:.examReturn,digest:"fictional",name:"fictional.pdf")
        XCTAssertEqual(returnedResult.coveredDates,["2026-04-01","2026-04-02","2026-04-03","2026-04-04","2026-04-05"])
        XCTAssertThrowsError(try SpecialScheduleParser.parseCertified([returned],kind:.examReturn,digest:"fictional",name:"fictional.pdf"))
    }

    func testRelativeSpecialSchedulesOutsideViewportCannotBecomeStrictSuccess() {
        for kind: SpecialScheduleKind in [.exam,.examReturn] {
            var pages = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            for index in pages[0].glyphs.indices { pages[0].glyphs[index].x += 3000 }
            for index in pages[0].lines.indices { pages[0].lines[index].x1 += 3000; pages[0].lines[index].x2 += 3000 }
            XCTAssertThrowsError(try SpecialScheduleParser.parseCertified(pages,kind:kind,digest:"fictional",name:"fictional.pdf")) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.rasterInput)
            }
        }
    }
    func testReturnColumnsMustBeInDateOrderBeforeSelectingFirstDayTimes() {
        for days in [[3,4,2,5,6], [1,2,6,4,5]] {
            XCTAssertThrowsError(try SpecialScheduleParser.parseCertified([returnPageWithSplitCell(dateDays:days)],kind:.examReturn,digest:"fictional",name:"fictional.pdf")) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.calendarDates)
            }
        }
    }
    func testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessons() throws {
        let result = try SpecialScheduleParser.parseCertified([returnPageWithSplitCell()], kind: .examReturn,
                                                     digest: "fictional", name: "fictional.pdf")
        let lessons = result.lessons.filter { $0.className == "3_IT" && $0.date == "2026-04-01" && $0.period == 3 }
        XCTAssertEqual(lessons.count, 2)
        XCTAssertEqual(Set(lessons.map(\.subject)), ["架空科目A", "架空科目B"])
        XCTAssertEqual(Set(lessons.map(\.teacher)), ["架空教員A", "架空教員B"])
        XCTAssertTrue(lessons.allSatisfy { $0.room.isEmpty })
        XCTAssertEqual(result.periodTime(on: "2026-04-01", period: 6), "11:10〜11:50")
        XCTAssertEqual(result.periodTime(on: "2026-04-02", period: 2), "09:35〜10:20")
        XCTAssertEqual(result.periodTime(on: "2026-04-02", period: 6), "13:35〜14:20")
        let ordinary = try XCTUnwrap(result.lessons.first { $0.className == "3_IT" &&
            $0.date == "2026-04-02" && $0.period == 2 })
        XCTAssertEqual(ordinary.timeRange, "09:35〜10:20")
        let specialPair = result.lessons.filter { $0.className == "1_1" &&
            $0.date == "2026-04-01" && [5, 6].contains($0.period) }
        XCTAssertEqual(specialPair.count, 2)
        XCTAssertTrue(specialPair.allSatisfy { $0.timeRange == "10:30〜11:50" })
        let ordinaryPair = result.lessons.filter { $0.className == "1_1" &&
            $0.date == "2026-04-02" && [5, 6].contains($0.period) }
        XCTAssertEqual(ordinaryPair.count, 2)
        XCTAssertTrue(ordinaryPair.allSatisfy { $0.timeRange == "12:50〜14:20" })
        let oldSingle = SpecialScheduleLesson(date: "2026-04-02", className: "3_IT", period: 6,
            spanStart: 6, spanEnd: 6, timeRange: "11:10〜11:50", lines: ["架空科目F"], page: 1)
        let oldPair = SpecialScheduleLesson(date: "2026-04-02", className: "3_IT", period: 5,
            spanStart: 5, spanEnd: 6, timeRange: nil, lines: ["架空科目G"], page: 1)
        // A recorded source range remains authoritative even on a later sorted date.
        XCTAssertEqual(result.timeRange(for: oldSingle), "11:10〜11:50")
        XCTAssertEqual(result.timeRange(for: oldPair), "12:50〜14:20")
    }

    func testSeventeenExamHeadingsCannotReplaceARequiredClassWithAnUnknownClass() {
        var pages = (1...6).map { examPage($0,mergedFirstTwo:$0 == 1) }
        var replaced = 0
        for glyph in pages[2].glyphs.indices where pages[2].glyphs[glyph].y == 70 && [448.0,452.0].contains(pages[2].glyphs[glyph].x) {
            pages[2].glyphs[glyph].text = "X"; replaced += 1
        }
        XCTAssertEqual(replaced,2)
        XCTAssertThrowsError(try SpecialScheduleParser.parseCertified(pages,kind:.exam,digest:"fictional",name:"fictional.pdf"))
    }

    func testSpecialSinglePeriodTimesCannotOverlapOrReversePeriodOrder() {
        for early in [["9:00~10:00", "9:30~10:30"], ["9:00~10:00", "8:00~8:30"]] {
            let times = early + ["10:50~11:35", "11:50~12:35", "13:20~14:05", "14:20~15:05"]
            let pages = (1...6).map { examPage($0,timingOverride:times) }
            XCTAssertThrowsError(try SpecialScheduleParser.parseCertified(pages,kind:.exam,digest:"fictional",name:"fictional.pdf")) {
                XCTAssertEqual(($0 as? PDFParseError)?.code,.ambiguous)
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.periodHeading)
            }
        }
        let times = ["7:00~8:00", "7:50~8:30", "8:40~9:20", "9:30~10:10", "10:30~11:10", "11:10~11:50", "12:00~12:40", "12:40~13:20"]
        XCTAssertThrowsError(try SpecialScheduleParser.parseCertified([returnPageWithSplitCell(timingOverride:times)],kind:.examReturn,digest:"fictional",name:"fictional.pdf")) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.periodHeading)
        }
    }
    func testAdjacentPeriodTimesAndIndependentConsecutiveChartRemainValid() throws {
        let times = ["8:50~9:35", "9:35~10:35", "10:50~11:35", "11:50~12:35", "13:20~14:05", "14:20~15:05"]
        let pages = (1...6).map { examPage($0,mergedFirstTwo:$0 == 1,timingOverride:times) }
        let result = try SpecialScheduleParser.parseCertified(pages,kind:.exam,digest:"fictional",name:"fictional.pdf")
        XCTAssertEqual(result.periodTimes[2],"09:35〜10:35")
        XCTAssertEqual(result.lessons.first { $0.spanEnd == 2 }?.timeRange,"08:50〜10:20")
    }
    func testExamParsesDatesClassesAndDocumentTimes() throws {
        let pages = (1...6).map { examPage($0, mergedFirstTwo: $0 == 1) }
        let result = try SpecialScheduleParser.parseCertified(pages, kind: .exam,
                                                      digest: "fictional", name: "fictional.pdf")
        XCTAssertEqual(result.lessons.count, 86)
        XCTAssertEqual(Set(result.lessons.map(\.date)).count, 5)
        XCTAssertEqual(result.coveredDates.count, 5)
        XCTAssertEqual(result.coveredClasses.count, 17)
        XCTAssertTrue(result.lessons.contains { $0.className == "AI_1" })
        XCTAssertTrue(result.lessons.contains { $0.className == "AI_2" })
        XCTAssertEqual(result.lessons.first?.subject, "架空科目A")
        XCTAssertEqual(result.periodTimes[2], "09:50〜10:35")
        XCTAssertEqual(result.periodTimes[6], "14:20〜15:05")
        let merged = result.lessons.filter { $0.date == "2026-04-01" &&
            $0.className == "1_1" && [1, 2].contains($0.period) }
        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(merged.allSatisfy { $0.spanEnd == 2 && $0.timeRange == "08:50〜10:20" })
    }

    func testSpecialLessonSeparatesDocumentSubjectTeacherAndRoom() throws {
        let pages = (1...6).map { examPage($0, metadataOnFirstCell: $0 == 1) }
        let result = try SpecialScheduleParser.parseCertified(pages, kind: .exam,
                                                     digest: "fictional", name: "fictional.pdf")
        let lesson = try XCTUnwrap(result.lessons.first { $0.date == "2026-04-01" &&
            $0.className == "1_1" && $0.period == 1 })
        XCTAssertEqual(lesson.subject, "架空科目A")
        XCTAssertEqual(lesson.teacher, "架空教員A")
        XCTAssertEqual(lesson.room, "架空教室A")
        XCTAssertEqual(lesson.lines, ["架空科目A", "架空教員A", "架空教室A"])
    }

#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
    func testFullCopyIncludesSpecialKindContentAndFailure() throws {
        var full = PDFFullReadDiagnostic()
        var page = PDFFullReadDiagnostic.Page(number: 1)
        page.text = "架空科目A\n架空教員A"
        page.lines = [.init(text: "架空科目A", ranges: [],
                            bounds: .init(CGRect(x: 1, y: 2, width: 3, height: 4)))]
        full.pages = [page]
        let failure = PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
        let recorder = PDFDiagnosticRecorder(parserVersion: SpecialScheduleAnalysis.parserVersion)
        recorder.record(.parse)
        for kind in SpecialScheduleKind.allCases {
            let report = try XCTUnwrap(SpecialScheduleDiagnosticReport.make(full, kind: kind,
                sourceName: "fictional.pdf", succeeded: false, failure: failure,
                trace: recorder.snapshot))
            XCTAssertTrue(report.hasPrefix("TAKUPOKE-PDF-FULL-ZIP-1\n"))
            let encoded = String(report.split(separator: "\n", maxSplits: 1)[1])
            let bytes = try XCTUnwrap(Data(base64Encoded: encoded, options: .ignoreUnknownCharacters))
            let archive = try Archive(data: bytes, accessMode: .read)
            let entry = try XCTUnwrap(archive["diagnostic.json"])
            var json = Data()
            _ = try archive.extract(entry) { json.append($0) }
            let restored = try JSONDecoder().decode(PDFFullReadDiagnostic.self, from: json)
            XCTAssertEqual(restored.materialKind, kind.rawValue)
            XCTAssertEqual(restored.parserVersion, SpecialScheduleAnalysis.parserVersion)
            XCTAssertEqual(restored.pages[0].text, "架空科目A\n架空教員A")
            XCTAssertEqual(restored.pages[0].lines[0].bounds.x, 1)
            XCTAssertEqual(restored.attemptFailure?.stage, .periodHeading)
            XCTAssertEqual(restored.trace?.parserVersion, SpecialScheduleAnalysis.parserVersion)
        }
    }
#endif
}

extension SpecialScheduleTests {
    func testReturnPositionsExportUsesExactAdoptedRowsAndContainsOnlyNumbers() throws {
        let page = returnPageWithColumnHeadings()
        let analysis = try SpecialScheduleParser.parse([page],kind:.examReturn,digest:"secret-digest",name:"private-name.pdf")
        let lesson = try XCTUnwrap(analysis.lessons.first { $0.className == "1_1" && $0.period == 4 })
        let recorder = PDFReturnGeometryRecorder(lesson:lesson)
        let direct = try PDF239SpecialScheduleParser.parse([page],kind:.examReturn,digest:"secret-digest",name:"private-name.pdf",geometry:recorder)
        XCTAssertEqual(direct.lessons,analysis.lessons)
        let snapshot = try XCTUnwrap(recorder.snapshot)
        XCTAssertEqual(snapshot.classRow,1); XCTAssertEqual(snapshot.contentTop,120)
        let cell = try XCTUnwrap(snapshot.cells.first)
        XCTAssertLessThan(cell.original.top,cell.content.top)
        XCTAssertEqual(cell.content.top,120)
        let ids = cell.adoptedRows.flatMap { $0 }
        XCTAssertFalse(ids.isEmpty)
        XCTAssertEqual(Set(ids).count,ids.count)
        XCTAssertTrue(Set(ids).isSubset(of:Set(snapshot.contextGlyphs.map(\.id))))
        XCTAssertFalse(snapshot.limited)
        let report = try XCTUnwrap(recorder.report())
        for value in ["secret-digest","private-name.pdf","架空科目","架空教員","架空教室","3ｺﾏ","4ｺﾏ","1_1",lesson.date] {
            XCTAssertFalse(report.contains(value))
        }
        let json = try JSONSerialization.jsonObject(with:Data(report.split(separator:"\n",maxSplits:1)[1].utf8))
        func check(_ value: Any) {
            if let object = value as? [String:Any] { object.values.forEach(check) }
            else if let array = value as? [Any] { array.forEach(check) }
            else { XCTAssertTrue(value is NSNumber || value is NSNull,"Unexpected serialized value") }
        }
        check(json)
        // A diagnostic request does not change any parse result or add a filter.
        let ordinary = try SpecialScheduleParser.parse([page],kind:.examReturn,digest:"secret-digest",name:"private-name.pdf")
        XCTAssertEqual(ordinary.lessons,analysis.lessons)
    }

    func testSpecialFirstYearMovesOnlyTheLessonAndKeepsSeventeenSourceClasses() throws {
        for kind: SpecialScheduleKind in [.exam,.examReturn] {
            let pages = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            var analysis = try SpecialScheduleParser.parse(pages,kind:kind,digest:"fictional",name:"fictional.pdf")
            let original = try XCTUnwrap(analysis.lessons.first { $0.className == "1_1" })
            let marked = SpecialScheduleLesson(date:original.date,className:original.className,period:original.period,
                spanStart:original.spanStart,spanEnd:original.spanEnd,timeRange:original.timeRange,
                lines:["架空科目（CN）","架空教員IT","架空教室ES"],page:original.page)
            let assigned = PDFClassAssignment.assign(marked)
            XCTAssertEqual(assigned.className,"1_CN"); XCTAssertEqual(assigned.sourceClassName,"1_1")
            XCTAssertEqual(assigned.lines,marked.lines)
            analysis.lessons = [assigned]
            XCTAssertEqual(analysis.coveredClasses.count,17)
            XCTAssertTrue(analysis.applies(date:original.date,className:"1_CN"))
            XCTAssertNotNil(analysis.timeRange(for:assigned))
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            let store = try SpecialScheduleStore(root:root), staged = store.newStagingURL()
            let bytes = Data("%PDF-fictional".utf8); try bytes.write(to:staged)
            try store.save(staged:staged,analysis:analysis,originalName:"fictional.pdf",byteCount:bytes.count,digest:"fictional")
            let saved = try XCTUnwrap(SpecialScheduleStore(root:root).records[kind]?.analysis)
            XCTAssertEqual(saved.lessons,[assigned]); XCTAssertFalse(saved.lessons.contains { $0.className == "1_1" })
            // Blank special cells suppress ordinary lessons for both affiliations.
            let day = try XCTUnwrap(SchoolDate(iso8601:original.date))
            let names = ["1_1","1_CN","1_ES","1_IT"]
            let base = PDFAnalysis(kind:.timetable,sourceDigest:"t",sourceName:"fictional.pdf",parsedAt:Date(),schoolYear:2026,term:"前期",lessons:names.map {
                PDFLesson(className:$0,weekday:day.schoolWeekday,period:8,names:TimetableLessonNames(subject:"架空通常",teacher:"",room:""),sourceText:"架空通常",page:1)
            },events:[],notices:[])
            for name in names {
                let ordinary = TimetableSchedule.slot(on:day,period:8,className:name,timetable:base,changes:nil,includesChanges:false)
                XCTAssertEqual(ordinary.baseLessons.count,1)
                let slot = TimetableSchedule.slot(on:day,period:8,className:name,timetable:base,changes:nil,includesChanges:false,specials:[saved])
                XCTAssertTrue(slot.baseLessons.isEmpty); XCTAssertTrue(slot.specialLessons.isEmpty)
            }
            var invalid = saved
            invalid.lessons = [SpecialScheduleLesson(date:assigned.date,className:"1_IT",period:assigned.period,spanStart:assigned.spanStart,spanEnd:assigned.spanEnd,timeRange:assigned.timeRange,lines:assigned.lines,page:assigned.page,sourceClassName:"1_1")]
            XCTAssertThrowsError(try store.saveAnalysis(invalid))
            XCTAssertEqual(try SpecialScheduleStore(root:root).records[kind]?.analysis.lessons,[assigned])
        }
    }
    func testReturnColumnClockDateSurvivesSortedDatesCardsChangesAndPersistence() throws {
        let dedicated = ["07:00〜07:40", "07:50〜08:30", "08:40〜09:20", "09:30〜10:10", "10:30〜11:10", "11:10〜11:50", "12:00〜12:40", "12:40〜13:20"]
        let ordinary = ["08:50〜09:35", "09:35〜10:20", "10:30〜11:15", "11:15〜12:00", "12:50〜13:35", "13:35〜14:20", "14:30〜15:15", "15:15〜16:00"]
        for order in [[1,2,3,4,5], [2,1,3,4,5]] {
            let result = try SpecialScheduleParser.parse([returnPageWithSplitCell(dateDays: order)], kind: .examReturn, digest: "fictional", name: "fictional.pdf")
            XCTAssertEqual(result.dedicatedTimeDate, "2026-04-0\(order[0])")
            XCTAssertEqual(result.coveredDates, (1...5).map { "2026-04-0\($0)" })
            let restored = try JSONDecoder().decode(SpecialScheduleAnalysis.self, from: JSONEncoder().encode(result))
            XCTAssertEqual(restored, result)
            for date in restored.coveredDates {
                let first = date == "2026-04-0\(order[0])"
                let day = try XCTUnwrap(SchoolDate(iso8601: date))
                let schedule = TimetableDaySchedule(timetable: nil, changes: nil, events: nil, specials: [restored], includesChanges: true)
                for period in 1...8 {
                    let expected = (first ? dedicated : ordinary)[period - 1]
                    XCTAssertEqual(restored.periodTime(on: date, period: period), expected)
                    let empty = ScheduleChange(change_date: date, class_name: "2_CN", period: String(period), before_subject: "", after_subject: "架空変更科目A", teacher: "", room: "", note: "変更", raw_text: "", canonical_text: "")
                    XCTAssertEqual(schedule.changeTimeRanges(empty), [expected])
                }
                if ["2026-04-01", "2026-04-02"].contains(date) {
                    let block = try XCTUnwrap(schedule.blocks(on: day, className: "1_1", international: false).first { $0.startPeriod == 5 && $0.endPeriod == 6 })
                    XCTAssertEqual(schedule.cardTime(block, on: day, className: "1_1"), first ? "10:30〜11:50" : "12:50〜14:20")
                    let now = try XCTUnwrap(ISO8601DateFormatter().date(from: date + "T10:45:00+09:00"))
                    XCTAssertEqual(schedule.isInProgress(block, on: day, className: "1_1", now: now), first)
                    let row = try XCTUnwrap(restored.lessons.first { $0.date == date && $0.className == "1_1" && $0.period == 5 })
                    XCTAssertEqual(restored.timeRange(for: row), row.timeRange)
                    let fragment = TimetableSchedule.GridBlock(startPeriod: 6, endPeriod: 6, content: block.content)
                    XCTAssertEqual(schedule.cardTime(fragment, on: day, className: "1_1"), first ? "11:10〜11:50" : "13:35〜14:20")
                }
            }
        }
    }

}
