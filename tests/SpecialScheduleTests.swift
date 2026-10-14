import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

// Added acquisition/role safety checks use the certified Recovery contract.
// Explicit testStrict239 cases and StrictPDFCompatibilityTests exercise app Strict.

final class SpecialScheduleTests: XCTestCase {
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
        let pages = try PDFKitReader.readSpecial(URL(fileURLWithPath: path)
            .appendingPathComponent("heading-return.pdf"))
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
        XCTAssertEqual(result.timeRange(for: oldSingle), "13:35〜14:20")
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
