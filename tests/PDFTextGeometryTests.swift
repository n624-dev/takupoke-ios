import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif
#endif

final class PDFTextGeometryTests: XCTestCase {
    func testOnlyFilledTextModeHasAnIndependentGlyphExtentProof() throws {
        let engine = PDFTextGeometry()
        XCTAssertNoThrow(try engine.operation("Tr",[0]))
        for mode in 1...7 { XCTAssertThrowsError(try engine.operation("Tr",[Double(mode)])) }
        XCTAssertThrowsError(try engine.operation("Tr",[0.5]))
    }
    func testViewportChecksWholeGlyphsRulesAndFiniteEndpointSums() throws {
        let glyph = PDFGlyph(text:"A",x:0,y:0,width:10,height:10)
        let rule = PDFRule(x1:0,y1:100,x2:100,y2:100)
        let visible = PDFPageLayout(width:100,height:100,glyphs:[glyph],lines:[rule])
        XCTAssertNoThrow(try visible.requireVisibleBounds())
        for (x,y,w,h) in [(-0.1,0.0,10.0,10.0),(95,0,10,10),(0,-0.1,10,10),(0,95,10,10),(0,0,Double.infinity,10)] {
            var page = visible; page.glyphs = [PDFGlyph(text:"A",x:x,y:y,width:w,height:h)]
            XCTAssertThrowsError(try page.requireVisibleBounds())
        }
        var outsideRule = visible; outsideRule.lines[0].x2 = 100.1
        XCTAssertThrowsError(try outsideRule.requireVisibleBounds())
        var overflow = visible; overflow.width = Double.greatestFiniteMagnitude
        overflow.glyphs[0].x = Double.greatestFiniteMagnitude; overflow.glyphs[0].width = Double.greatestFiniteMagnitude
        XCTAssertThrowsError(try overflow.requireVisibleBounds())
    }
    func testStrictStrokeWidthBoundsIncludeTransformsAndHairlines() {
        XCTAssertNotNil(PDFTextVisibility.strokePad(1,a:1,b:0,c:0,d:1))
        XCTAssertEqual(PDFTextVisibility.strokePad(0,a:1,b:0,c:0,d:1),0.5)
        XCTAssertNil(PDFTextVisibility.strokePad(25,a:1,b:0,c:0,d:1))
        XCTAssertNil(PDFTextVisibility.strokePad(1,a:2,b:0,c:0,d:2))
        XCTAssertNil(PDFTextVisibility.strokePad(1,a:1,b:2,c:0,d:1))
        XCTAssertNil(PDFTextVisibility.strokePad(-1,a:1,b:0,c:0,d:1))
        XCTAssertNil(PDFTextVisibility.strokePad(1,a:Double.infinity,b:0,c:0,d:1))
    }
    func testStrictDeviceColorsRequireVisibleBlackComponents() {
        XCTAssertTrue(PDFTextVisibility.blackColor([0],count:1))
        XCTAssertTrue(PDFTextVisibility.blackColor([0,0,0],count:3))
        XCTAssertTrue(PDFTextVisibility.blackColor([0,0,0,1],count:4))
        for (components,count) in [([1.0],1),([1,1,1],3),([1,0,0],3),([0,0,0,0],4),([Double.nan],1),([Double.infinity],1),([-1.0],1),([0.0,0],1)] {
            XCTAssertFalse(PDFTextVisibility.blackColor(components,count:count))
        }
    }

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
    private final class NativeFontProbe {
        let reader = PDFDrawnTextReader(check:{})
        var failure: Error?
    }
    func testNativeExplicitFontAndUnicodeResourcesDecodeIndependently() throws {
        for simple in [true,false] {
            let data = syntheticPDF(content:simple ? "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET" : "BT /F1 10 Tf 1 0 0 1 30 350 Tm <00010002> Tj ET",simpleFont:simple)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            var resources: CGPDFDictionaryRef?, fonts: CGPDFDictionaryRef?, font: CGPDFDictionaryRef?, map: CGPDFStreamRef?
            XCTAssertTrue(CGPDFDictionaryGetDictionary(page.dictionary,"Resources",&resources))
            XCTAssertTrue(CGPDFDictionaryGetDictionary(try XCTUnwrap(resources),"Font",&fonts))
            XCTAssertTrue(CGPDFDictionaryGetDictionary(try XCTUnwrap(fonts),"F1",&font))
            XCTAssertTrue(CGPDFDictionaryGetStream(try XCTUnwrap(font),"ToUnicode",&map))
            var format = CGPDFDataFormat.raw
            let unicode = try XCTUnwrap(CGPDFStreamCopyData(try XCTUnwrap(map),&format))
            XCTAssertEqual(format,.raw)
            let decoded = try PDFUnicodeMap.read(unicode as Data)
            XCTAssertEqual(decoded.bytes,simple ? 1:2)
            XCTAssertEqual(decoded.values[simple ? 65:1],"A")
            var metrics = try XCTUnwrap(font)
            var subtype: UnsafePointer<CChar>?
            XCTAssertTrue(CGPDFDictionaryGetName(metrics,"Subtype",&subtype))
            XCTAssertEqual(String(cString:try XCTUnwrap(subtype)),simple ? "Type1":"Type0")
            if simple {
                var first: CGPDFReal = 0, last: CGPDFReal = 0, widths: CGPDFArrayRef?
                XCTAssertTrue(CGPDFDictionaryGetNumber(metrics,"FirstChar",&first))
                XCTAssertTrue(CGPDFDictionaryGetNumber(metrics,"LastChar",&last))
                XCTAssertEqual(first,65); XCTAssertEqual(last,67)
                XCTAssertTrue(CGPDFDictionaryGetArray(metrics,"Widths",&widths))
                XCTAssertEqual(CGPDFArrayGetCount(try XCTUnwrap(widths)),3)
            } else {
                var descendants: CGPDFArrayRef?, descendant: CGPDFDictionaryRef?
                XCTAssertTrue(CGPDFDictionaryGetArray(metrics,"DescendantFonts",&descendants))
                XCTAssertTrue(CGPDFArrayGetDictionary(try XCTUnwrap(descendants),0,&descendant))
                metrics = try XCTUnwrap(descendant)
            }
            var descriptor: CGPDFDictionaryRef?, ascent: CGPDFReal = 0, descent: CGPDFReal = 0
            XCTAssertTrue(CGPDFDictionaryGetDictionary(metrics,"FontDescriptor",&descriptor))
            XCTAssertTrue(CGPDFDictionaryGetNumber(try XCTUnwrap(descriptor),"Ascent",&ascent))
            XCTAssertTrue(CGPDFDictionaryGetNumber(try XCTUnwrap(descriptor),"Descent",&descent))
            XCTAssertEqual(ascent,800); XCTAssertEqual(descent,-200)
            let probe = NativeFontProbe()
            let table = try XCTUnwrap(CGPDFOperatorTableCreate()); defer { CGPDFOperatorTableRelease(table) }
            CGPDFOperatorTableSetCallback(table,"Tf") { scanner, info in
                guard let info else { return }
                let probe = Unmanaged<NativeFontProbe>.fromOpaque(info).takeUnretainedValue()
                do { try probe.reader.font(scanner) } catch { probe.failure = error }
            }
            let stream = CGPDFContentStreamCreateWithPage(page); defer { CGPDFContentStreamRelease(stream) }
            let scanner = CGPDFScannerCreate(stream,table,Unmanaged.passUnretained(probe).toOpaque()); defer { CGPDFScannerRelease(scanner) }
            XCTAssertTrue(CGPDFScannerScan(scanner))
            XCTAssertNil(probe.failure,"Native font resource decode must succeed independently of content visibility")
            XCTAssertEqual(probe.reader.fonts.count,1)
        }
    }
    // Entirely invented PDF, with explicit resources and text operators. This
    // checks the Core Graphics adapter rather than relying on Quartz's font choice.
    private func syntheticPDF(content: String, unicode: Bool = true, graphicsState: String = "", simpleFont: Bool = false, crop: String = "") -> Data {
        func stream(_ s: String) -> String { "<< /Length \(s.utf8.count) >>\nstream\n\(s)\nendstream" }
        let simpleMap = """
        /CIDInit /ProcSet findresource begin 12 dict begin begincmap
        /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
        /CMapName /Synthetic def /CMapType 2 def
        1 begincodespacerange <00> <FF> endcodespacerange
        3 beginbfchar <41> <0041> <42> <0042> <43> <0043> endbfchar
        endcmap CMapName currentdict /CMap defineresource pop end end
        """
        let cmap = simpleFont ? simpleMap : """
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
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] \(crop) /Resources << /Font << /F1 4 0 R >> /ExtGState << /Visibility << \(graphicsState) >> >> >> /Contents 8 0 R >>",
            simpleFont ? "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding /FirstChar 65 /LastChar 67 /Widths [667 667 667] /FontDescriptor 6 0 R \(unicode ? "/ToUnicode 7 0 R" : "") >>" : "<< /Type /Font /Subtype /Type0 /BaseFont /Synthetic /Encoding /Identity-H /DescendantFonts [5 0 R] \(unicode ? "/ToUnicode 7 0 R" : "") >>",
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Synthetic /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 1000 /W [1 [500] 2 3 600] /CIDToGIDMap /Identity >>",
            "<< /Type /FontDescriptor /FontName \(simpleFont ? "Helvetica" : "Synthetic") /Flags \(simpleFont ? 32:4) /FontBBox [0 -200 1000 800] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 >>",
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

    private func paintedInk(_ data: Data) throws -> Int {
        let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
        var pixels = [UInt8](repeating:255,count:300*400)
        return try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data:buffer.baseAddress,width:300,height:400,bitsPerComponent:8,bytesPerRow:300,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue))
            context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:300,height:400))
            context.drawPDFPage(page)
            return buffer.reduce(0) { $0 + ($1 == 255 ? 0:1) }
        }
    }
#if canImport(AppKit)
    private func thumbnailPixels(_ data: Data, box: PDFDisplayBox) throws -> (width: Int, height: Int, pixels: [UInt8]) {
        let document = try XCTUnwrap(PDFDocument(data:data)), page = try XCTUnwrap(document.page(at:0))
        let bounds = page.bounds(for:box)
        // The same PDFKit thumbnail API and display box used by the production
        // recognition path, with no OCR threshold or layout interpretation.
        let image = page.thumbnail(of:bounds.size,for:box)
        let cg = try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
        var pixels = [UInt8](repeating:255,count:cg.width*cg.height)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data:buffer.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue))
            context.setFillColor(CGColor(gray:1,alpha:1))
            let frame = CGRect(x:0,y:0,width:CGFloat(cg.width),height:CGFloat(cg.height))
            context.fill(frame)
            context.draw(cg,in:frame)
        }
        return (cg.width,cg.height,pixels)
    }
#endif
    func testNativeWhiteTextAndOpaqueRepaintUseRasterInsteadOfSelectableText() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let black = syntheticPDF(content:"0 g "+text,simpleFont:true)
        XCTAssertGreaterThan(try paintedInk(black),0)
        let white = syntheticPDF(content:"1 g "+text,simpleFont:true)
        let repaint = syntheticPDF(content:"0 g "+text+" 1 g 0 0 300 400 re f",simpleFont:true)
        XCTAssertEqual(try paintedInk(white),0); XCTAssertEqual(try paintedInk(repaint),0)
        let cases = [white,repaint,
            syntheticPDF(content:"1 1 1 rg "+text,simpleFont:true),
            syntheticPDF(content:"0 0 0 0 k "+text,simpleFont:true),
            syntheticPDF(content:"1 0 0 rg "+text,simpleFont:true),
            syntheticPDF(content:"0 g 0 0 300 400 re f "+text,simpleFont:true),
            syntheticPDF(content:"0 g "+text+" 0 g 0 0 300 400 re f",simpleFont:true),
            syntheticPDF(content:"0 g "+text+" 0 G 25 w 20 355 m 70 355 l S",simpleFont:true),
            syntheticPDF(content:"0 g "+text+" /Visibility gs 20 355 m 70 355 l S",graphicsState:"/LW 25",simpleFont:true)]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-color-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for data in cases {
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertThrowsError(try PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{}).read(page))
            let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
                else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
                XCTAssertFalse(capture.complete); XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data:black as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
        XCTAssertEqual(try PDFDrawnTextReader(check:{}).read(page,expectedText:"AB").map(\.text).joined(),"AB")
        let visible = syntheticPDF(content:"0 g "+text+" 10 10 m 290 10 l S",simpleFont:true)
        let url = root.appendingPathComponent("visible.pdf"); try visible.write(to:url)
        for special in [false,true] {
            let capture = RecoveryReadCapture()
            let pages: [PDFPageLayout]
            if special { pages = try PDFKitReader.readSpecial(url,capture:capture) }
            else { pages = try PDFKitReader.read(url,kind:.timetable,capture:capture) }
            XCTAssertTrue(capture.complete); XCTAssertEqual(pages.first?.glyphs.map(\.text).joined(),"AB")
        }
    }
    func testNativeCroppedOutBodyCannotBecomeCompleteInput() throws {
        let content = "0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (A) Tj 1 0 0 1 30 50 Tm (B) Tj ET 10 10 m 290 10 l S"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-crop-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for crop in ["", "/CropBox [0 0 300 400]", "/CropBox [0 300 300 400]"] {
            let data = syntheticPDF(content:content,simpleFont:true,crop:crop), url = root.appendingPathComponent("fictional.pdf")
            try data.write(to:url)
            let cropped = crop.contains("[0 300")
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if cropped {
                    if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
                    else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
                    XCTAssertFalse(capture.complete); XCTAssertTrue(capture.pages.allSatisfy { $0.state == .rasterOnly })
                } else {
                    if special { _ = try PDFKitReader.readSpecial(url,capture:capture) }
                    else { _ = try PDFKitReader.read(url,kind:.timetable,capture:capture) }
                    XCTAssertTrue(capture.complete)
                }
            }
            if cropped {
                let document = try XCTUnwrap(PDFDocument(data:data)), page = try XCTUnwrap(document.page(at:0))
                XCTAssertEqual(page.bounds(for:.cropBox).height,100)
                XCTAssertEqual(page.bounds(for:.mediaBox).height,400)
#if canImport(AppKit)
                let header = "0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (A) Tj ET"
                let reference = syntheticPDF(content:header,simpleFont:true,crop:crop)
                let cropImage = try thumbnailPixels(data,box:.cropBox)
                let cropReference = try thumbnailPixels(reference,box:.cropBox)
                XCTAssertEqual(cropImage.width,cropReference.width)
                XCTAssertEqual(cropImage.height,cropReference.height)
                XCTAssertEqual(cropImage.pixels,cropReference.pixels,"The hidden footer must not enter the OCR raster")
                XCTAssertTrue(cropImage.pixels.contains { $0 < 255 },"The visible header remains rendered")
                let fullImage = try thumbnailPixels(data,box:.mediaBox)
                let fullReference = try thumbnailPixels(reference,box:.mediaBox)
                XCTAssertEqual(fullImage.width,cropImage.width)
                XCTAssertEqual(fullImage.height,cropImage.height*4)
                XCTAssertEqual(fullImage.height,fullReference.height)
                XCTAssertNotEqual(fullImage.pixels,fullReference.pixels,"The full-page control must expose the omitted footer")
                XCTAssertGreaterThan(fullImage.pixels.filter { $0 < 255 }.count,fullReference.pixels.filter { $0 < 255 }.count)
#endif
            }
        }
    }
    func testNativeOffCanvasSelectableTextCannotBecomeCompleteInput() throws {
        let content = "0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-offcanvas-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (x,y) in [(600,0),(-600,0),(0,600),(0,-600)] {
            let data = syntheticPDF(content:"q 1 0 0 1 \(x) \(y) cm "+content+" Q",simpleFont:true)
            XCTAssertEqual(try paintedInk(data),0,"The entire shifted table is outside the displayed page")
            let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
                else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
                XCTAssertFalse(capture.complete); XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
    }
    func testNativeThinStrokeCannotCrossAcquiredGlyphs() throws {
        let data = syntheticPDF(content:"0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 0 G 1 w 20 355 m 70 355 l S",simpleFont:true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-thin-stroke-"+UUID().uuidString+".pdf")
        defer { try? FileManager.default.removeItem(at:url) }; try data.write(to:url)
        for special in [false,true] {
            let capture = RecoveryReadCapture()
            if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
            else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
            XCTAssertFalse(capture.complete); XCTAssertFalse(capture.pages.contains { $0.state == .complete })
        }
    }
    func testNativeOutlinedTextUsesCompositedRasterInsteadOfSelectionBounds() throws {
        for mode in [1,2] {
            let data = syntheticPDF(content:"0 g 0 G 25 w BT /F1 12 Tf \(mode) Tr 1 0 0 1 30 350 Tm (AB) Tj ET",simpleFont:true)
            XCTAssertGreaterThan(try paintedInk(data),0,"The outline is painted, but its extent is not the glyph advance box")
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            let reader = PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{})
            XCTAssertThrowsError(try reader.read(page)) { XCTAssertEqual(($0 as? PDFParseError)?.stage,.vectorObjects) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-outline-"+UUID().uuidString+".pdf")
            defer { try? FileManager.default.removeItem(at:url) }; try data.write(to:url)
            let capture = RecoveryReadCapture()
            XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture))
            XCTAssertFalse(capture.complete); XCTAssertFalse(capture.pages.contains { $0.state == .complete })
        }
    }
    func testNativeSpecialVisibilityScanRejectsHiddenAndUnverifiedText() throws {
        let variants: [(String,String)] = [("/BM /Multiply", "/Visibility gs"), ("/BM [/Normal /Multiply]", "/Visibility gs"), ("/ca 0", "/Visibility gs"), ("/CA 0", "/Visibility gs"), ("/SMask /None", "/Visibility gs"), ("/TR /Identity", "/Visibility gs"), ("/TR2 /Identity", "/Visibility gs"), ("", "3 Tr"), ("", "4 Tr"), ("", "0 0 10 10 re W n"), ("", "/Artifact BMC"), ("", "/Span << /ActualText (Different) >> BDC")]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-visibility-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (state,prefix) in variants {
            let textMode = prefix.hasSuffix(" Tr") ? prefix : ""
            let graphics = textMode.isEmpty ? prefix : ""
            let endMarked = prefix.hasSuffix("BMC") || prefix.hasSuffix("BDC") ? "EMC" : ""
            let content = "\(graphics) BT /F1 10 Tf \(textMode) 1 0 0 1 30 350 Tm <00010002> Tj ET \(endMarked) 10 10 m 290 10 l S"
            let data = syntheticPDF(content:content,graphicsState:state)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            let reader = PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{})
            XCTAssertThrowsError(try reader.read(page),prefix) { error in
                XCTAssertEqual((error as? PDFParseError)?.code,.unsupported)
                XCTAssertEqual((error as? PDFParseError)?.stage,.vectorObjects)
            }
            XCTAssertThrowsError(try PDFDrawnTextReader(check:{}).read(page,expectedText:"AB"),prefix)
            let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
            let capture = RecoveryReadCapture()
            XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture),prefix)
            XCTAssertFalse(capture.complete); XCTAssertFalse(capture.readerCompleted)
            XCTAssertFalse(capture.pages.contains { $0.state == .complete })
        }
    }
    func testNativeSpecialVisibilityScanAllowsOpaqueTextAndRules() throws {
        let data = syntheticPDF(content:"/Visibility gs BT /F1 10 Tf 0 Tr 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S",graphicsState:"/ca 1 /CA 1 /BM /Normal",simpleFont:true)
        let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
        let reader = PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{})
        XCTAssertEqual(try reader.read(page).count,1)
        XCTAssertEqual(try PDFDrawnTextReader(check:{}).read(page,expectedText:"AB").map(\.text).joined(),"AB")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-opaque-"+UUID().uuidString+".pdf")
        defer { try? FileManager.default.removeItem(at:url) }; try data.write(to:url)
        let capture = RecoveryReadCapture(), pages = try PDFKitReader.readSpecial(url,capture:capture)
        XCTAssertTrue(capture.complete); XCTAssertEqual(pages.first?.glyphs.map(\.text).joined(),"AB")
    }
    func testNativeResourcesAndTJThroughPDFKitBridge() throws {
        // Standard Helvetica is actually drawable without an embedded font.
        // The separate resource probe covers two-byte CID decoder interop.
        let data = syntheticPDF(content: "BT /F1 10 Tf 1 0 0 1 30 350 Tm [<41> -1500 <42>] TJ 0 -20 TD <43> Tj ET 10 10 m 290 10 l S",simpleFont:true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("synthetic-text.pdf")
        try data.write(to: url)
        let layout = try XCTUnwrap(PDFKitReader.read(url, kind: .timetable).first)
        XCTAssertEqual(layout.glyphs.map(\.text), ["A", "B", "C"])
        for (actual,expected) in zip(layout.glyphs.map(\.x),[30.0,51.67,30]) { XCTAssertEqual(actual,expected,accuracy:0.001) }
        XCTAssertEqual(layout.glyphs.map(\.y), [42, 42, 62])
        for width in layout.glyphs.map(\.width) { XCTAssertEqual(width,6.67,accuracy:0.001) }
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
