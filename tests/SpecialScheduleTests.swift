import Foundation
import XCTest
import ZIPFoundation
@testable import TakupokeParsing

final class SpecialScheduleTests: XCTestCase {
    private func examPage(_ number: Int, omitLastTime: Bool = false,
                          mergedFirstTwo: Bool = false) -> PDFPageLayout {
        var glyphs: [PDFGlyph] = []
        var lines: [PDFRule] = []
        var sourceLine = 0
        var order = 0
        func write(_ value: String, x: Double, y: Double, step: Double = 4) {
            for (index, character) in value.enumerated() {
                glyphs.append(PDFGlyph(text: String(character), x: x + Double(index) * step,
                                       y: y, width: step, height: 8,
                                       sourceLine: sourceLine, sourceOrder: order))
                order += 1
            }
            sourceLine += 1
        }
        let columns = number == 6 ? 2 : 3
        let labels: [String]
        switch number {
        case 1: labels = ["1-1", "1-2", "1-3"]
        case 2: labels = ["2-CN", "2-ES", "2-IT"]
        case 3: labels = ["3-CN", "3-ES", "3-IT"]
        case 4: labels = ["4-CN", "4-ES", "4-IT"]
        case 5: labels = ["5-CN", "5-ES", "5-IT"]
        default: labels = ["1年", "2年"]
        }
        write("令和8年度 試験時間割", x: 20, y: 20)
        for column in 0..<columns {
            write(labels[column], x: 200 + Double(column) * 240, y: 70)
            for period in 0..<6 {
                write("\(period + 1)", x: 118 + Double(column * 6 + period) * 40, y: 100)
            }
        }
        for index in 0...columns * 6 {
            let x = 100 + Double(index) * 40
            lines.append(PDFRule(x1: x, y1: mergedFirstTwo && index == 1 ? 150 : 110,
                                 x2: x, y2: 350))
        }
        lines.append(PDFRule(x1: 0, y1: 110, x2: 0, y2: 350))
        for index in 0...6 {
            let y = 110 + Double(index) * 40
            lines.append(PDFRule(x1: 0, y1: y, x2: 100 + Double(columns * 6) * 40, y2: y))
        }
        for index in 0..<5 {
            write("4月\(index + 1)日", x: 16, y: 126 + Double(index) * 40)
            for column in 0..<columns {
                write("架空科目A", x: 106 + Double(column) * 240,
                      y: 126 + Double(index) * 40, step: 6)
            }
        }
        let times = ["8:50~9:35", "9:50~10:35", "10:50~11:35",
                     "11:50~12:35", "13:20~14:05", "14:20~15:05"]
        for (index, time) in times.enumerated() where !omitLastTime || index != 5 {
            write("\(index + 1)時限目\(time)", x: 20, y: 470 + Double(index) * 15)
        }
        write("1・2時限連続8:50~10:20", x: 300, y: 470)
        return PDFPageLayout(width: 850, height: 600, glyphs: glyphs, lines: lines)
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

    func testIncompleteSpecialTimesDoNotReplacePreviousStoreResult() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SpecialScheduleStore(root: root)
        let good = try SpecialScheduleParser.parse((1...6).map { examPage($0) },
                                                   kind: .exam, digest: "fictional",
                                                   name: "fictional.pdf")
        let staged = store.newStagingURL()
        let data = Data("%PDF-fictional".utf8)
        try data.write(to: staged)
        try store.save(staged: staged, analysis: good, originalName: "fictional.pdf",
                       byteCount: data.count, digest: "fictional")
        let oldURL = try XCTUnwrap(store.savedURL(for: .exam))
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertThrowsError(try SpecialScheduleParser.parse(
            (1...6).map { examPage($0, omitLastTime: $0 == 3) },
            kind: .exam, digest: "different", name: "different.pdf"))
        let reopened = try SpecialScheduleStore(root: root)
        XCTAssertEqual(reopened.records[.exam]?.analysis, good)
        XCTAssertEqual(reopened.savedURL(for: .exam), oldURL)
    }

    func testFullCopyIncludesSpecialKindContentAndFailure() throws {
        var full = PDFFullReadDiagnostic()
        var page = PDFFullReadDiagnostic.Page(number: 1)
        page.text = "架空科目A\n架空教員A"
        page.lines = [.init(text: "架空科目A", ranges: [],
                            bounds: .init(CGRect(x: 1, y: 2, width: 3, height: 4)))]
        full.pages = [page]
        let failure = PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
        for kind in SpecialScheduleKind.allCases {
            let report = try XCTUnwrap(SpecialScheduleDiagnosticReport.make(full, kind: kind,
                sourceName: "fictional.pdf", succeeded: false, failure: failure, trace: nil))
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
        }
    }
}
