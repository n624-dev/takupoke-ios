import Foundation
import XCTest
@testable import TakupokeParsing

#if canImport(PDFKit)
final class StrictPDFCompatibilityTests: XCTestCase {
    private let classes = ["1_1", "1_2", "1_3", "2_CN", "2_ES", "2_IT",
                           "3_CN", "3_ES", "3_IT", "4_CN", "4_ES", "4_IT",
                           "5_CN", "5_ES", "5_IT", "AI_1", "AI_2"]
    private let fields = ["架空科目甲", "架空教員乙", "仮想教室丙"]

    private func files(_ kind: String) throws -> [URL] {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["TAKUPOKE_STRICT_COMPATIBILITY_FIXTURES"])
        let root = URL(fileURLWithPath:path)
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent(".strict-compatibility-owned").path))
        return (0...2).flatMap { mode in
            ["", "-before", "-after", "-background"].map { root.appendingPathComponent("\(kind)-\(mode)\($0).pdf") }
        }
    }

    func testNormalDocumentModesPreserveEveryLessonTuple() throws {
        for url in try files("normal") {
            let pages = try PDFKitReader.read(url,kind:.timetable)
            let result = try PDFSchoolParser.parse(pages,kind:.timetable,digest:"independent",name:"fictional.pdf")
            XCTAssertEqual(result.schoolYear,2032); XCTAssertEqual(result.term,"前期")
            XCTAssertEqual(result.lessons.count,3)
            let keys = result.lessons.map { "\($0.className)/\($0.weekday)/\($0.period)" }.sorted()
            XCTAssertEqual(keys,["1_1/1/1","2_CN/2/2","AI_1/3/3"])
            for lesson in result.lessons {
                XCTAssertEqual([lesson.names.subject,lesson.names.teacher,lesson.names.room],fields)
                XCTAssertEqual(lesson.sourceText,fields.joined(separator:"\n"))
                XCTAssertEqual(lesson.page,1)
            }
        }
    }

    func testSixExamPagesPreserveClassesDatesTimesAndEveryLessonTuple() throws {
        for url in try files("exam") {
            let pages = try PDFKitReader.readSpecial(url)
            let result = try SpecialScheduleParser.parse(pages,kind:.exam,digest:"independent",name:"fictional.pdf")
            XCTAssertEqual(result.schoolYear,2032)
            XCTAssertEqual(result.coveredClasses,classes.sorted())
            XCTAssertEqual(result.coveredDates,(1...5).map { "2032-04-0\($0)" })
            XCTAssertEqual(result.periodTimes,Dictionary(uniqueKeysWithValues:(1...6).map {
                ($0,String(format:"%02d:00〜%02d:40",7+$0,7+$0))
            }))
            XCTAssertEqual(result.lessons.count,17)
            let keys = result.lessons.map { "\($0.className)/\($0.date)/\($0.period)/\($0.page)" }.sorted()
            let expected = classes.enumerated().map { index, name in
                "\(name)/2032-04-0\(index%3+1)/\(index%3+1)/\(index/3+1)"
            }.sorted()
            XCTAssertEqual(keys,expected)
            for lesson in result.lessons {
                XCTAssertEqual(lesson.lines,fields)
                XCTAssertEqual(lesson.spanStart,lesson.period); XCTAssertEqual(lesson.spanEnd,lesson.period)
                XCTAssertEqual(lesson.timeRange,String(format:"%02d:00〜%02d:40",7+lesson.period,7+lesson.period))
            }
        }
    }

    func testReturnDocumentPreservesFirstDayAndOrdinaryDayTimes() throws {
        for url in try files("return") {
            let pages = try PDFKitReader.readSpecial(url)
            let result = try SpecialScheduleParser.parse(pages,kind:.examReturn,digest:"independent",name:"fictional.pdf")
            XCTAssertEqual(result.schoolYear,2032); XCTAssertEqual(result.coveredClasses,classes.sorted())
            XCTAssertEqual(result.coveredDates,(1...5).map { "2032-04-0\($0)" })
            XCTAssertEqual(result.lessons.count,3)
            let keys = result.lessons.map { "\($0.className)/\($0.date)/\($0.period)/\($0.timeRange ?? "")" }.sorted()
            XCTAssertEqual(keys,["1_1/2032-04-01/1/08:00〜08:40",
                                 "2_ES/2032-04-02/2/09:35〜10:20",
                                 "AI_2/2032-04-05/8/15:15〜16:00"])
            for lesson in result.lessons {
                XCTAssertEqual(lesson.lines,fields); XCTAssertEqual(lesson.page,1)
                XCTAssertEqual(lesson.spanStart,lesson.period); XCTAssertEqual(lesson.spanEnd,lesson.period)
            }
        }
    }
}
#endif
