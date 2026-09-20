import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
#endif

final class PDFTextGeometryTests: XCTestCase {
    private func map(_ body: String) throws -> (bytes: Int, values: [Int: String]) {
        try PDFUnicodeMap.read(Data(body.utf8))
    }
    private func font(bytes: Int = 1) throws -> PDFTextFont {
        try PDFTextFont(unicode: [32: " ", 65: "A", 66: "B", 67: "C"], codeBytes: bytes,
                        widths: [32: 250, 65: 500, 66: 600, 67: 700],
                        defaultWidth: 1000, ascent: 800, descent: -200)
    }

    func testUnicodeCharactersRangesAndSurrogatePairs() throws {
        let decoded = try map("""
        /WMode 0 def
        1 begincodespacerange <0000> <FFFF> endcodespacerange
        2 beginbfchar <0001> <D83DDE00> <0002> <00650301> endbfchar
        2 beginbfrange <0003> <0004> <0041> <0005> <0006> [<0043> <0044>] endbfrange
        """)
        XCTAssertEqual(decoded.bytes, 2)
        XCTAssertEqual(decoded.values, [1: "😀", 2: "e\u{301}", 3: "A", 4: "B", 5: "C", 6: "D"])
    }

    func testMalformedOrUnsupportedUnicodeMapsFailClosed() throws {
        let prefix = "1 begincodespacerange <00> <FF> endcodespacerange "
        for body in [
            "1 beginbfchar <41> <D800> endbfchar",
            "2 beginbfchar <41> <0041> <41> <0042> endbfchar",
            "1 beginbfchar <0141> <0041> endbfchar",
            "1 beginbfrange <41> <43> [<0041>] endbfrange",
            "1 beginbfrange <43> <41> <0041> endbfrange",
            "1 beginbfchar <41> <000A> endbfchar",
            "/Inherited usecmap", "/WMode 1 def",
            "1 beginbfchar <41> <0041> endbfrange"
        ] {
            XCTAssertThrowsError(try map(prefix + body))
        }
    }

    func testSpacingAndTJKeepAdjacentCellsSeparate() throws {
        let engine = PDFTextGeometry()
        try engine.font(font(), size: 10)
        try engine.operation("BT")
        try engine.operation("Tm", [1, 0, 0, 1, 20, 80])
        try engine.operation("Tc", [1])
        try engine.operation("Tw", [2])
        try engine.show([65, 32, 66])
        try engine.adjust(-2000)
        try engine.show([67])
        try engine.operation("ET")
        let glyphs = try engine.finish(expectedText: "A B\nC")
        XCTAssertEqual(glyphs.map(\.text), ["A", "B", "C"])
        XCTAssertEqual(glyphs.map(\.x), [20, 31.5, 58.5])
        XCTAssertEqual(glyphs.map(\.width), [5, 6, 7])
        XCTAssertEqual(glyphs.map(\.sourceOrder), [0, 2, 3])
        XCTAssertEqual(glyphs[0].sourceLine, glyphs[2].sourceLine)
        XCTAssertTrue(glyphs.allSatisfy { $0.y == 78 && $0.height == 10 })
    }

    func testCompositeCode32DoesNotApplyWordSpacing() throws {
        let engine = PDFTextGeometry()
        try engine.font(font(bytes: 2), size: 10)
        try engine.operation("Tw", [100])
        try engine.operation("BT")
        try engine.show([0, 65, 0, 32, 0, 66])
        try engine.operation("ET")
        let glyphs = try engine.finish(expectedText: "A B")
        XCTAssertEqual(glyphs[1].x, 7.5)
    }

    func testTransformsRiseScalingAndSavedGraphicsState() throws {
        let engine = PDFTextGeometry()
        try engine.font(font(), size: 10)
        try engine.operation("q")
        try engine.operation("cm", [2, 0, 0, 3, 100, 200])
        try engine.operation("Tz", [50])
        try engine.operation("Ts", [2])
        try engine.operation("BT")
        try engine.operation("Tm", [0, 1, -1, 0, 10, 20])
        try engine.show([65])
        try engine.operation("ET")
        try engine.operation("Q")
        try engine.operation("BT")
        try engine.show([66])
        try engine.operation("ET")
        let glyphs = try engine.finish(expectedText: "AB")
        XCTAssertEqual(glyphs[0].x, 100)
        XCTAssertEqual(glyphs[0].y, 260)
        XCTAssertEqual(glyphs[0].width, 20)
        XCTAssertEqual(glyphs[0].height, 7.5)
        XCTAssertEqual(glyphs[1].x, 0)
        XCTAssertEqual(glyphs[1].width, 6)
        XCTAssertEqual(glyphs[1].y, -2)
    }

    func testLineMatrixMovesIndependentlyOfStringAdvance() throws {
        let engine = PDFTextGeometry()
        try engine.font(font(), size: 10)
        try engine.operation("BT")
        try engine.operation("Tm", [1, 0, 0, 1, 20, 80])
        try engine.show([65])
        try engine.operation("TD", [0, -12])
        try engine.show([66])
        try engine.operation("T*")
        try engine.show([67])
        try engine.operation("ET")
        let glyphs = try engine.finish(expectedText: "C\nB\nA")
        XCTAssertEqual(glyphs.map(\.x), [20, 20, 20])
        XCTAssertEqual(glyphs.map(\.y), [78, 66, 54])
        XCTAssertEqual(Set(glyphs.compactMap(\.sourceLine)).count, 3)
    }

    func testCoverageRejectsDroppedDuplicatedOrChangedText() throws {
        let engine = PDFTextGeometry()
        try engine.font(font(), size: 10)
        try engine.operation("BT")
        try engine.show([65, 66])
        try engine.operation("ET")
        for expected in ["A", "ABB", "AC"] {
            XCTAssertThrowsError(try engine.finish(expectedText: expected))
        }
        XCTAssertEqual(try engine.finish(expectedText: "B\n A").count, 2)
    }

    func testUnsafeTextStateAndCancellationFailClosed() throws {
        let engine = PDFTextGeometry()
        XCTAssertThrowsError(try engine.show([65]))
        XCTAssertThrowsError(try engine.operation("Q"))
        XCTAssertThrowsError(try engine.operation("Tr", [3]))
        XCTAssertThrowsError(try engine.operation("cm", [1, 0, 0, 1, .infinity, 0]))
        try engine.font(font(bytes: 2), size: 10)
        try engine.operation("BT")
        XCTAssertThrowsError(try engine.show([0]))
        XCTAssertThrowsError(try engine.show([0, 99]))
        try engine.show([0, 65])
        XCTAssertThrowsError(try engine.finish(expectedText: "A"))
        let cancelled = PDFTextGeometry { throw PDFParseError(code: .cancelled) }
        try cancelled.font(font(), size: 10)
        try cancelled.operation("BT")
        XCTAssertThrowsError(try cancelled.show([65])) { error in
            XCTAssertEqual((error as? PDFParseError)?.code, .cancelled)
        }
    }
}

#if canImport(PDFKit)
extension PDFTextGeometryTests {
    // Entirely invented PDF, with explicit resources and text operators. This
    // checks the Core Graphics adapter rather than relying on Quartz's font choice.
    private func syntheticPDF(content: String, unicode: Bool = true) -> Data {
        func stream(_ s: String) -> String { "<< /Length \(s.utf8.count) >>\nstream\n\(s)\nendstream" }
        let cmap = """
        /CIDInit /ProcSet findresource begin 12 dict begin begincmap
        /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
        /CMapName /Synthetic def /CMapType 2 def
        1 begincodespacerange <0000> <FFFF> endcodespacerange
        1 beginbfrange <0001> <0003> <0041> endbfrange
        endcmap CMapName currentdict /CMap defineresource pop end end
        """
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Resources << /Font << /F1 4 0 R >> >> /Contents 8 0 R >>",
            "<< /Type /Font /Subtype /Type0 /BaseFont /Synthetic /Encoding /Identity-H /DescendantFonts [5 0 R] \(unicode ? "/ToUnicode 7 0 R" : "") >>",
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Synthetic /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 1000 /W [1 [500] 2 3 600] /CIDToGIDMap /Identity >>",
            "<< /Type /FontDescriptor /FontName /Synthetic /Flags 4 /FontBBox [0 -200 1000 800] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 >>",
            stream(cmap), stream(content)
        ]
        var data = Data("%PDF-1.4\n".utf8), offsets: [Int] = [0]
        for (i, object) in objects.enumerated() {
            offsets.append(data.count)
            data.append(Data("\(i + 1) 0 obj\n\(object)\nendobj\n".utf8))
        }
        let start = data.count
        var tail = "xref\n0 \(offsets.count)\n0000000000 65535 f \n"
        for offset in offsets.dropFirst() { tail += String(format: "%010d 00000 n \n", offset) }
        tail += "trailer\n<< /Size \(offsets.count) /Root 1 0 R >>\nstartxref\n\(start)\n%%EOF\n"
        data.append(Data(tail.utf8))
        return data
    }

    func testNativeResourcesAndTJThroughPDFKitBridge() throws {
        let data = syntheticPDF(content: "BT /F1 10 Tf 1 0 0 1 30 350 Tm [<0001> -1500 <0002>] TJ 0 -20 TD <0003> Tj ET 10 10 m 290 10 l S")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic-text.pdf")
        try data.write(to: url)
        let layout = try XCTUnwrap(PDFKitReader.read(url, kind: .timetable).first)
        XCTAssertEqual(layout.glyphs.map(\.text), ["A", "B", "C"])
        XCTAssertEqual(layout.glyphs.map(\.x), [30, 50, 30])
        XCTAssertEqual(layout.glyphs.map(\.y), [42, 42, 62])
        XCTAssertEqual(layout.glyphs.map(\.width), [5, 6, 6])
        XCTAssertFalse(layout.lines.isEmpty)
    }

    func testNativeMissingMappingAndReplacementContentFailClosed() throws {
        for (unicode, extra) in [(false, ""), (true, "/Span << /ActualText (Replacement) >> BDC EMC"), (true, "/Unknown Do")] {
            let data = syntheticPDF(content: "BT /F1 10 Tf <0001> Tj ET " + extra, unicode: unicode)
            let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
            let document = try XCTUnwrap(CGPDFDocument(provider))
            let page = try XCTUnwrap(document.page(at: 1))
            XCTAssertThrowsError(try PDFDrawnTextReader(check: {}).read(page, expectedText: "A")) { error in
                XCTAssertEqual((error as? PDFParseError)?.stage, .characterMapping)
            }
        }
    }
}
#endif
