import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

final class PDFParsingTests: XCTestCase {
    // Construct new layouts from primitives, with no copied school cells or coordinates.
    func text(_ value: String, x: Double, y: Double, step: Double = 4) -> [PDFGlyph] {
        value.enumerated().map { PDFGlyph(text: String($0.element), x: x + Double($0.offset) * step, y: y - 3, width: step, height: 6) }
    }
    func h(_ y: Double, _ x1: Double = 10, _ x2: Double = 1100) -> PDFRule { PDFRule(x1: x1, y1: y, x2: x2, y2: y) }
    func v(_ x: Double, _ y1: Double = 60, _ y2: Double = 280) -> PDFRule { PDFRule(x1: x, y1: y1, x2: x, y2: y2) }
    func timetable() -> PDFPageLayout {
        var gs = text("令和14年度前期時間割", x: 200, y: 20)
        var lines = [60.0, 80, 100, 160, 220, 280].map { h($0) } + [20.0, 50, 100].map { v($0) }
        for i in 0..<40 {
            gs += text(String(i % 8 + 1), x: 108 + Double(i) * 20, y: 70)
            lines.append(v(100 + Double(i) * 20, 60, 80))
        }
        lines.append(v(900, 60, 80))
        for i in 0...20 { lines.append(v(100 + Double(i) * 40, 100, 280)) }
        for (grade, label, y) in [("1", "ZZ", 130.0), ("2", "YY", 190.0), ("AI", "3", 250.0)] {
            gs += text(grade, x: 30, y: y)
            gs += text(label, x: 70, y: y)
        }
        gs += text("架空科目Q", x: 104, y: 112)
        gs += text("架空教員Q", x: 104, y: 130)
        gs += text("架空室Q", x: 104, y: 148)
        gs += text("架空X・架空Y", x: 104, y: 172)
        gs += text("教員X・教員Y", x: 104, y: 190)
        gs += text("・架空室Y", x: 104, y: 208)
        gs += text("架空科目Z", x: 264, y: 232)
        return PDFPageLayout(width: 1100, height: 600, glyphs: gs, lines: lines)
    }
    func calendar(_ months: [Int], winter: Bool = true) -> PDFPageLayout {
        var gs = text("令和14年度行事予定表", x: 400, y: 20)
        gs += text("日", x: 18, y: 60)
        var lines = [h(40), h(70)]
        var arrows: [PDFArrow] = []
        for day in 1...31 {
            gs += text(String(day), x: day < 10 ? 18 : 16, y: 70 + Double(day) * 20 - 10)
            lines.append(h(70 + Double(day) * 20))
        }
        lines += [v(10, 40, 690), v(30, 40, 690)]
        for (i, month) in months.enumerated() {
            let x = 60 + Double(i) * 170
            gs += text("\(month)月", x: x + 40, y: 47)
            gs += text("共通", x: x + 12, y: 60)
            gs += text("高松", x: x + 52, y: 60)
            gs += text("詫間", x: x + 92, y: 60)
            lines += [x, x + 40, x + 80, x + 120].map { v($0, 40, 690) }
            gs += text("架空行事\(month)", x: x + 2, y: 100)
            gs += text("架空対象外", x: x + 42, y: 120)
            gs += text("架空交流会", x: x + 82, y: 140)
            gs += text("9", x: x + 115, y: 160) // Teaching-week counter, not an event.
            if month == 6 {
                gs += text("夏季休業(6/19まで)", x: x + 2, y: 260, step: 2)
            }
            if winter && month == 12 {
                gs += text("冬季休業", x: x + 2, y: 560)
                arrows.append(PDFArrow(x: x + 30, top: 555, bottom: 680))
            }
            if winter && month == 1 { arrows.append(PDFArrow(x: x + 30, top: 72, bottom: 150)) }
        }
        return PDFPageLayout(width: 1100, height: 800, glyphs: gs, lines: lines, arrows: arrows)
    }
    func parse(_ pages: [PDFPageLayout], kind: MaterialKind) throws -> PDFAnalysis {
        try PDFSchoolParser.parse(pages, kind: kind, digest: "synthetic-digest", name: "synthetic.pdf")
    }
    func testTimetablePeriodsParallelLessonsAndEmptyRoom() throws {
        let result = try parse([timetable()], kind: .timetable)
        XCTAssertEqual(result.schoolYear, 2032)
        XCTAssertEqual(result.term, "前期")
        XCTAssertEqual(result.lessons.count, 8)
        let parallel = result.lessons.filter { $0.className == "2_YY" }
        XCTAssertEqual(parallel.map(\.period), [1, 1, 2, 2])
        XCTAssertEqual(parallel.map(\.names.room), ["", "架空室Y", "", "架空室Y"])
        XCTAssertEqual(parallel.map(\.names.subject), ["架空X", "架空Y", "架空X", "架空Y"])
        XCTAssertTrue(parallel.allSatisfy { $0.names.roomFullName == nil && $0.sourceText.contains("・架空室Y") })
        XCTAssertEqual(result.lessons.filter { $0.className == "AI_3" }.map(\.weekday), [2, 2])
    }
    func testCalendarScopesDatesPeriodsAndYearBoundary() throws {
        let result = try parse([calendar(Array(4...9)), calendar([10, 11, 12, 1, 2, 3])], kind: .events)
        XCTAssertEqual(result.schoolYear, 2032)
        XCTAssertFalse(result.events.contains { $0.title.contains("対象外") || $0.title == "9" })
        let winter = try XCTUnwrap(result.events.first { $0.title == "冬季休業" })
        XCTAssertEqual(winter.date, "2032-12-25")
        XCTAssertEqual(winter.endDate, "2033-01-04")
        XCTAssertEqual(winter.periodEvidence, "矢印")
        XCTAssertFalse(winter.periodNeedsReview)
        let summer = try XCTUnwrap(result.events.first { $0.title.hasPrefix("夏季休業") })
        XCTAssertEqual(summer.date, "2032-06-10")
        XCTAssertEqual(summer.endDate, "2032-06-19")
        XCTAssertTrue(result.events.contains { $0.date == "2033-03-02" && $0.scope == "共通" })
    }
    func testUnknownPeriodIsExplicitAndUnsupportedInputStops() throws {
        var second = calendar([10, 11, 12, 1, 2, 3])
        second.arrows = []
        let result = try parse([calendar(Array(4...9)), second], kind: .events)
        let winter = try XCTUnwrap(result.events.first { $0.title == "冬季休業" })
        XCTAssertNil(winter.endDate)
        XCTAssertTrue(winter.periodNeedsReview)
        var ambiguous = calendar([10, 11, 12, 1, 2, 3])
        // Two continuations must not silently shorten a cross-month period.
        ambiguous.arrows?.append(PDFArrow(x: 600, top: 72, bottom: 170))
        let ambiguousResult = try parse([calendar(Array(4...9)), ambiguous], kind: .events)
        let ambiguousWinter = try XCTUnwrap(ambiguousResult.events.first { $0.title == "冬季休業" })
        XCTAssertNil(ambiguousWinter.endDate)
        XCTAssertTrue(ambiguousWinter.periodNeedsReview)
        var broken = timetable()
        broken.lines = []
        XCTAssertThrowsError(try parse([broken], kind: .timetable))
        XCTAssertThrowsError(try parse([calendar(Array(4...9)), calendar(Array(4...9))], kind: .events))
        XCTAssertThrowsError(try PDFSchoolParser.parse([timetable()], kind: .timetable, digest: "d", name: "n") {
            throw PDFParseError(code: .cancelled)
        }) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
    }
    func testConflictingPeriodAndMismatchedYearAreNotAccepted() throws {
        var first = calendar(Array(4...9))
        first.arrows?.append(PDFArrow(x: 430, top: 253, bottom: 470))
        let result = try parse([first, calendar([10, 11, 12, 1, 2, 3])], kind: .events)
        let summer = try XCTUnwrap(result.events.first { $0.title.hasPrefix("夏季休業") })
        XCTAssertNil(summer.endDate)
        XCTAssertTrue(summer.periodNeedsReview)
        var otherYear = calendar([10, 11, 12, 1, 2, 3])
        let digit = try XCTUnwrap(otherYear.glyphs.firstIndex { $0.cy == 20 && $0.text == "4" })
        otherYear.glyphs[digit].text = "5"
        XCTAssertThrowsError(try parse([first, otherYear], kind: .events))
    }
    func testDamagedClassAndUnalignedParallelFieldsStopWholeTable() throws {
        var damaged = timetable()
        let label = try XCTUnwrap(damaged.glyphs.firstIndex { $0.cx > 50 && $0.cx < 100 && $0.text == "Y" })
        damaged.glyphs[label].text = "?"
        XCTAssertThrowsError(try parse([damaged], kind: .timetable))
        var parallel = timetable()
        parallel.glyphs.removeAll { $0.cy == 208 && $0.text == "・" }
        XCTAssertThrowsError(try parse([parallel], kind: .timetable))
    }
    func testPDFFailureReplacementAndManifestRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var reject = false
        let library = try MaterialLibrary(root: root) { data, url in
            if reject { throw PDFParseError(code: .storage) }
            try data.write(to: url, options: .atomic)
        }
        func acquire(_ digest: String) throws {
            let url = library.newStagingURL()
            let data = Data("%PDF-synthetic".utf8)
            try data.write(to: url)
            try library.commit(staged: url, kind: .timetable, source: MaterialSource(), originalName: "synthetic.pdf",
                               byteCount: data.count, digest: digest, modifiedAt: nil)
        }
        try acquire("synthetic-digest")
        let good = try parse([timetable()], kind: .timetable)
        try library.savePDFAnalysis(good)
        try acquire("replacement")
        try library.recordPDFFailure(PDFParseError(code: .ambiguous), kind: .timetable)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        let manifest = root.appendingPathComponent("library.json")
        let before = try Data(contentsOf: manifest)
        var next = good; next.sourceDigest = "replacement"
        reject = true
        XCTAssertThrowsError(try library.savePDFAnalysis(next))
        XCTAssertEqual(try Data(contentsOf: manifest), before)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        reject = false
        try library.savePDFAnalysis(next)
        let reopened = try MaterialLibrary(root: root)
        XCTAssertEqual(reopened.state.pdfAnalyses?["timetable"]?.sourceDigest, "replacement")
        XCTAssertNil(reopened.state.pdfParseAttempts?["timetable"]?.failure)
    }
}

#if canImport(PDFKit)
extension PDFParsingTests {
    func testPDFKitBridgeRecognizesFilledArrowGeometry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Synthetic",
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]) as CFAttributedString)
        context.textPosition = CGPoint(x: 10, y: 380)
        CTLineDraw(line, context)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.addRect(CGRect(x: 99.7, y: 251, width: 0.6, height: 49))
        context.move(to: CGPoint(x: 97, y: 252))
        context.addLine(to: CGPoint(x: 100, y: 246))
        context.addLine(to: CGPoint(x: 103, y: 252))
        context.closePath()
        context.fillPath()
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic-arrow.pdf")
        try (data as Data).write(to: url)
        let result = try PDFKitReader.read(url)
        let arrow = try XCTUnwrap(result.first?.arrows?.first)
        XCTAssertEqual(arrow.x, 100, accuracy: 0.1)
        XCTAssertEqual(arrow.top, 100, accuracy: 0.1)
        XCTAssertEqual(arrow.bottom, 154, accuracy: 0.1)
    }
    func testPDFKitBridgeReadsSyntheticPDFAndRotation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let page = timetable()
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: page.width, height: page.height)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        context.setStrokeColor(CGColor(gray: 0, alpha: 1))
        context.setLineWidth(0.4)
        for line in page.lines {
            context.move(to: CGPoint(x: line.x1, y: page.height - line.y1))
            context.addLine(to: CGPoint(x: line.x2, y: page.height - line.y2))
            context.strokePath()
        }
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 6, nil)
        for glyph in page.glyphs {
            let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph.text, attributes: attributes) as CFAttributedString)
            context.textPosition = CGPoint(x: glyph.x, y: page.height - glyph.cy - 2)
            CTLineDraw(line, context)
        }
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic.pdf")
        try (data as Data).write(to: url)
        let normal = try PDFKitReader.read(url)
        XCTAssertEqual(try parse(normal, kind: .timetable).lessons.count, 8)
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        try XCTUnwrap(document.page(at: 0)).rotation = 90
        try XCTUnwrap(document.dataRepresentation()).write(to: url)
        let rotated = try PDFKitReader.read(url)
        XCTAssertEqual(rotated[0].width, normal[0].height, accuracy: 0.1)
        XCTAssertEqual(rotated[0].height, normal[0].width, accuracy: 0.1)
        let before = try XCTUnwrap(normal[0].glyphs.first { $0.text == "令" })
        let after = try XCTUnwrap(rotated[0].glyphs.first { $0.text == "令" })
        XCTAssertEqual(after.cx, normal[0].height - before.cy, accuracy: 1)
        XCTAssertEqual(after.cy, before.cx, accuracy: 1)
        XCTAssertFalse(rotated[0].lines.isEmpty)
    }
}
#endif
