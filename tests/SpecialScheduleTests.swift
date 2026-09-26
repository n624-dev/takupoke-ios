import Foundation
import XCTest
import ZIPFoundation
import GRDB
@testable import TakupokeParsing

final class SpecialScheduleTests: XCTestCase {
    func testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessons() throws {
        let result = try SpecialScheduleParser.parse([returnPageWithSplitCell()], kind: .examReturn,
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

    func testExamParsesDatesClassesAndDocumentTimes() throws {
        let pages = (1...6).map { examPage($0, mergedFirstTwo: $0 == 1) }
        let result = try SpecialScheduleParser.parse(pages, kind: .exam,
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
        let result = try SpecialScheduleParser.parse(pages, kind: .exam,
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
