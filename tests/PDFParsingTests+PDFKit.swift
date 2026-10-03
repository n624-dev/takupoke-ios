import Foundation
import XCTest
import ZIPFoundation
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

#if canImport(PDFKit)
extension PDFParsingTests {
    func testVisibilityCollisionWorkAndCancellationAreBoundedWithinEachPaint() {
        let boxes = Array(repeating:PDFBox(left:100,top:100,right:110,bottom:110),count:1100)
        let segment = [CGPoint(x:10,y:20),CGPoint(x:30,y:20)]
        let limited = PDFPathReader(transform:PDFDisplayTransform(media:CGRect(x:0,y:0,width:300,height:400),rotation:0),verifyVisibility:true,textBoxes:boxes,check:{})
        limited.paths = Array(repeating:segment,count:1100)
        limited.paint(fill:false,stroke:true)
        XCTAssertEqual((limited.failure as? PDFParseError)?.code,.limit)
        XCTAssertTrue(limited.paths.isEmpty)
        XCTAssertTrue(limited.lines.isEmpty)

        var checks = 0
        let cancelled = PDFPathReader(transform:PDFDisplayTransform(media:CGRect(x:0,y:0,width:300,height:400),rotation:0),verifyVisibility:true,textBoxes:boxes,check:{
            checks += 1
            if checks == 2 { throw PDFParseError(code:.cancelled) }
        })
        cancelled.paths = [segment]
        cancelled.paint(fill:false,stroke:true)
        XCTAssertEqual(checks,2)
        XCTAssertEqual((cancelled.failure as? PDFParseError)?.code,.cancelled)
        XCTAssertTrue(cancelled.paths.isEmpty)
    }
    func testPDFPathPaintPreservesFilledRulesAndUniqueArrow() {
        let reader = syntheticPathReader()
        // Bounds are deliberately taken from a non-rectangular stem, too.
        let stem = [CGPoint(x: 99.7, y: 100), CGPoint(x: 100.3, y: 100),
                    CGPoint(x: 100.2, y: 149), CGPoint(x: 99.8, y: 149)]
        let triangle = [CGPoint(x: 97, y: 148), CGPoint(x: 103, y: 148),
                        CGPoint(x: 100, y: 154), CGPoint(x: 97, y: 148)]
        let horizontal = [CGPoint(x: 10, y: 200), CGPoint(x: 30, y: 200),
                          CGPoint(x: 30, y: 201), CGPoint(x: 10, y: 201)]
        reader.paths = [stem, triangle, horizontal]
        reader.paint(fill: true, stroke: false)
        XCTAssertNil(reader.failure)
        XCTAssertTrue(reader.paths.isEmpty)
        XCTAssertEqual(reader.lines.count, 2)
        XCTAssertEqual(reader.arrows.count, 1)
        XCTAssertEqual(reader.arrows.first?.x, 100)
        XCTAssertEqual(reader.arrows.first?.top, 100)
        XCTAssertEqual(reader.arrows.first?.bottom, 154)

        let ambiguous = syntheticPathReader()
        ambiguous.paths = [stem, triangle, stem]
        ambiguous.paint(fill: true, stroke: false)
        XCTAssertNil(ambiguous.failure)
        XCTAssertTrue(ambiguous.arrows.isEmpty)
        XCTAssertEqual(ambiguous.lines.count, 2)
    }

    func testPDFPathPaintPreservesStrokeRules() {
        let reader = syntheticPathReader()
        reader.paths = [[CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 20), CGPoint(x: 30, y: 40)]]
        reader.paint(fill: false, stroke: true)
        XCTAssertNil(reader.failure)
        XCTAssertTrue(reader.paths.isEmpty)
        XCTAssertEqual(reader.lines.count, 2)
        XCTAssertEqual(reader.lines.first?.y1, 20)
        XCTAssertEqual(reader.lines.last?.x1, 30)
    }

    func testPDFPathPaintChecksCancellationWithinFillAndStroke() {
        for (fill, stroke) in [(true, false), (false, true), (true, true)] {
            var checks = 0
            let reader = syntheticPathReader {
                checks += 1
                if checks == 2 { throw PDFParseError(code: .cancelled) }
            }
            reader.paths = [(0..<400).map { CGPoint(x: CGFloat($0), y: CGFloat($0)) }]
            reader.paint(fill: fill, stroke: stroke)
            XCTAssertEqual(checks, 2)
            XCTAssertEqual((reader.failure as? PDFParseError)?.code, .cancelled)
            XCTAssertTrue(reader.paths.isEmpty)
            // Later scanner callbacks must not overwrite the first failure.
            reader.operations = 1_000_000
            XCTAssertNil(PDFPathReader.state(Unmanaged.passUnretained(reader).toOpaque()))
            XCTAssertEqual((reader.failure as? PDFParseError)?.code, .cancelled)
        }
    }

    func testPDFPathPaintBoundsStemComparisonWork() {
        let reader = syntheticPathReader()
        let triangle = [CGPoint(x: 0, y: 10), CGPoint(x: 6, y: 10), CGPoint(x: 3, y: 16)]
        let distantStem = [CGPoint(x: 100, y: 0), CGPoint(x: 101, y: 0),
                           CGPoint(x: 101, y: 10), CGPoint(x: 100, y: 10)]
        reader.paths = Array(repeating: triangle, count: 1_100) + Array(repeating: distantStem, count: 1_100)
        reader.paint(fill: true, stroke: false)
        XCTAssertEqual((reader.failure as? PDFParseError)?.code, .limit)
        XCTAssertTrue(reader.paths.isEmpty)
        XCTAssertTrue(reader.arrows.isEmpty)
    }

    func testPDFPathPaintBudgetIsCumulativeAcrossCallbacks() {
        let reader = syntheticPathReader()
        let square = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
                      CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)]
        let paths = Array(repeating: square, count: 128)
        reader.paths = paths
        reader.paint(fill: true, stroke: false)
        XCTAssertNil(reader.failure)
        for _ in 0..<1_500 where reader.failure == nil {
            reader.paths = paths
            reader.paint(fill: true, stroke: false)
        }
        XCTAssertEqual((reader.failure as? PDFParseError)?.code, .limit)
        XCTAssertTrue(reader.paths.isEmpty)
    }

    private func syntheticPathReader(check: @escaping () throws -> Void = {}) -> PDFPathReader {
        PDFPathReader(transform: PDFDisplayTransform(media: CGRect(x: 0, y: 0, width: 300, height: 400),
                                                     rotation: 0), check: check)
    }

    func testPDFKitTextSelectionsStayAlignedAcrossSpacesLinesAndRotations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let labels: [(String, CGFloat, CGFloat)] = [("AB CD", 30, 360), ("EF GH", 150, 260), ("IJ KL", 50, 110)]
        for (text, x, y) in labels {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]) as CFAttributedString)
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }
        context.move(to: CGPoint(x: 10, y: 20))
        context.addLine(to: CGPoint(x: 290, y: 20))
        context.strokePath()
        context.endPDFPage()
        context.closePDF()
        let url = root.appendingPathComponent("synthetic-lines.pdf")
        try (data as Data).write(to: url)
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        let nativePage = try XCTUnwrap(document.page(at: 0))
        XCTAssertTrue(try XCTUnwrap(nativePage.string).contains("\n"))
        // CoreText's generated font is not a supported timetable font. The
        // strict drawn-text reader rejects it; PDFKit selection remains usable.
        XCTAssertThrowsError(try PDFKitReader.read(url, kind: .timetable)) { error in
            XCTAssertEqual((error as? PDFParseError)?.stage, .characterMapping)
        }
        for kind in [MaterialKind.events] {
            nativePage.rotation = 0
            try XCTUnwrap(document.dataRepresentation()).write(to: url)
            let original = try XCTUnwrap(PDFKitReader.read(url, kind: kind).first)
            XCTAssertEqual(PDFGrid.rows(original.glyphs).map { $0.map(\.text).joined() }, ["ABCD", "EFGH", "IJKL"])
            XCTAssertEqual(try PDFGrid.contentRows(original.glyphs).map { $0.map(\.text).joined() }, ["ABCD", "EFGH", "IJKL"])
            XCTAssertTrue(original.glyphs.allSatisfy { $0.sourceLine != nil && $0.sourceOrder != nil })
            for (text, x, y) in labels {
                let first = try XCTUnwrap(original.glyphs.first { $0.text == String(text.prefix(1)) })
                XCTAssertEqual(first.x, Double(x), accuracy: 2)
                XCTAssertTrue((Double(400 - y) - 14...Double(400 - y) + 3).contains(first.cy))
            }
            for rotation in [90, 180, 270] {
                nativePage.rotation = rotation
                try XCTUnwrap(document.dataRepresentation()).write(to: url)
                let rotated = try XCTUnwrap(PDFKitReader.read(url, kind: kind).first)
                XCTAssertEqual(rotated.glyphs.count, original.glyphs.count)
                for before in original.glyphs {
                    let after = try XCTUnwrap(rotated.glyphs.first { $0.text == before.text })
                    let expected: (Double, Double)
                    switch rotation {
                    case 90: expected = (400 - before.cy, before.cx)
                    case 180: expected = (300 - before.cx, 400 - before.cy)
                    default: expected = (before.cy, 300 - before.cx)
                    }
                    XCTAssertEqual(after.cx, expected.0, accuracy: 1)
                    XCTAssertEqual(after.cy, expected.1, accuracy: 1)
                }
            }
        }
    }
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
    func testPDFKitFullDiagnosticCollectsAllTextWhitespaceAndMultiplePages() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        var media = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        for label in ["AB CD", "EF GH"] {
            context.beginPDFPage(nil)
            let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: label,
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]) as CFAttributedString)
            context.textPosition = CGPoint(x: 30, y: 350)
            CTLineDraw(line, context)
            context.move(to: CGPoint(x: 10, y: 20)); context.addLine(to: CGPoint(x: 290, y: 20)); context.strokePath()
            context.endPDFPage()
        }
        context.closePDF()
        let url = root.appendingPathComponent("synthetic-diagnostic.pdf")
        try (data as Data).write(to: url)
        let report = PDFKitReader.diagnose(url)
        XCTAssertTrue(report.incomplete.isEmpty)
        XCTAssertEqual(report.pages.count, 2)
        for page in report.pages {
            XCTAssertEqual(page.characters.map(\.text).joined(), page.text)
            XCTAssertTrue(page.characters.contains { $0.whitespace })
            XCTAssertFalse(page.lines.isEmpty)
            XCTAssertFalse(page.rules.isEmpty)
            XCTAssertEqual(page.characters.reduce(0) { $0 + $1.range.length }, page.utf16Count)
        }
        let cancelled = PDFKitReader.diagnose(url) { throw PDFParseError(code: .cancelled) }
        XCTAssertTrue(cancelled.incomplete.contains(.cancelled))
        XCTAssertEqual(cancelled.issues.first?.code, .cancelled)
    }
#endif
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
        let result = try PDFKitReader.read(url, kind: .events)
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
        // CoreText's synthetic PDF is intentionally outside the strict
        // drawn-text subset; a separate explicit-ToUnicode fixture covers it.
        XCTAssertThrowsError(try PDFKitReader.read(url, kind: .timetable)) { error in
            XCTAssertEqual((error as? PDFParseError)?.stage, .characterMapping)
        }
        // This test covers the legacy PDFKit selection bridge, whose generated
        // CoreText color spaces/fonts are outside the school visibility subset.
        let normal = try PDFKitReader.read(url,kind:.events)
        let parsed = try parse(normal, kind: .timetable)
        XCTAssertEqual(parsed.lessons.count, 8)
        XCTAssertEqual(Set(parsed.lessons.map(\.names.subject)), ["架空科目Q", "架空X", "架空Y", "架空科目Z"])
        let independent = try XCTUnwrap(parsed.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(independent.names.teacher, "架空教員Q")
        XCTAssertEqual(independent.names.room, "架空室Q")
        let document = try XCTUnwrap(PDFDocument(data: data as Data))
        try XCTUnwrap(document.page(at: 0)).rotation = 90
        try XCTUnwrap(document.dataRepresentation()).write(to: url)
        let rotated = try PDFKitReader.read(url,kind:.events)
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
