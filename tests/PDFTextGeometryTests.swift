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
    func testCollisionIndexMatchesInclusiveBruteForceAcrossWidthsPadsAndBoundaryContacts() throws {
        var boxes = [PDFBox(left:-200,top:-90,right:100,bottom:10),PDFBox(left:20,top:30,right:20,bottom:30)]
        for i in 0..<80 {
            let x = Double((i*37)%211-100), y = Double((i*53)%193-90)
            boxes.append(PDFBox(left:x,top:y,right:x+Double(i%17),bottom:y+Double(i%23)))
        }
        let index = try PDFTextCollisionIndex(boxes,work:{})
        for i in 0..<150 {
            let x = Double((i*31)%251-125), y = Double((i*47)%229-115)
            let query = PDFBox(left:x,top:y,right:x+Double(i%29),bottom:y+Double(i%31))
            for pad in [0.0,0.5,2.25] {
                let expected = boxes.contains { $0.left <= query.right+pad && query.left-pad <= $0.right && $0.top <= query.bottom+pad && query.top-pad <= $0.bottom }
                XCTAssertEqual(try index.overlaps(query,pad:pad,work:{}),expected)
            }
        }
        XCTAssertTrue(try index.overlaps(PDFBox(left:100,top:10,right:101,bottom:11),pad:0,work:{}))
        XCTAssertTrue(try index.overlaps(PDFBox(left:20,top:30,right:20,bottom:30),pad:0,work:{}))
        for left in [0.1,1e-200,1e100] {
            let right = left+max(left.ulp*3,abs(left)*0.2)
            let box = PDFBox(left:left,top:left,right:right,bottom:right)
            let boundaryIndex = try PDFTextCollisionIndex([box],work:{})
            XCTAssertTrue(try boundaryIndex.overlaps(PDFBox(left:right,top:right,right:right,bottom:right),pad:0,work:{}))
        }
    }
    func testCollisionIndexKeepsDenseDisjointTableSearchInsideOneOriginalPaintBudget() throws {
        var boxes = [PDFBox]()
        for row in 0..<17 { for column in 0..<40 { for glyph in 0..<18 {
            let x = Double(column*72+12+(glyph%6)*7), y = Double(row*48+8+(glyph/6)*13)
            boxes.append(PDFBox(left:x,top:y,right:x+4,bottom:y+6))
        } } }
        var work = 0
        let charge = { work += 1; if work > 1000000 { throw PDFParseError(code:.limit) } }
        let index = try PDFTextCollisionIndex(boxes,work:charge)
        for row in 0..<17 { for column in 0...40 {
            let x = Double(column*72), y = Double(row*48)
            XCTAssertFalse(try index.overlaps(PDFBox(left:x,top:y,right:x,bottom:y+48),pad:0.275,work:charge))
        } }
        for row in 0...17 {
            let y = Double(row*48)
            XCTAssertFalse(try index.overlaps(PDFBox(left:0,top:y,right:2880,bottom:y),pad:0.275,work:charge))
        }
        XCTAssertLessThan(work,1000000)
    }
    func testCollisionIndexChargesConstructionSearchAndPreservesThrownCancellation() throws {
        let boxes: [PDFBox] = (0..<100).map { value in
            let coordinate = Double(value)
            return PDFBox(left:coordinate,top:coordinate,right:coordinate+1,bottom:coordinate+1)
        }
        for stop in [1,101] {
            var visits = 0
            XCTAssertThrowsError(try PDFTextCollisionIndex(boxes,work:{ visits += 1; if visits == stop { throw PDFParseError(code:.cancelled) } })) {
                XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled)
            }
            XCTAssertEqual(visits,stop)
        }
        let index = try PDFTextCollisionIndex(boxes,work:{})
        var visits = 0
        XCTAssertThrowsError(try index.overlaps(PDFBox(left:20,top:20,right:21,bottom:21),pad:0,work:{ visits += 1; if visits == 3 { throw PDFParseError(code:.limit) } })) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
        XCTAssertEqual(visits,3)
        XCTAssertThrowsError(try PDFTextCollisionIndex([PDFBox(left:0,top:0,right:.infinity,bottom:1)],work:{}))
        XCTAssertThrowsError(try index.overlaps(PDFBox(left:.nan,top:0,right:1,bottom:1),pad:0,work:{}))
    }
    func testStrokePaddingRequiresAnExactAnglePreservingTransform() {
        for m in [[1.0,0,0,1],[0,1,-1,0],[0.5,0,0,0.5],[1,0,0,-1],[0.5,0.5,-0.5,0.5]] {
            XCTAssertTrue(PDFTextVisibility.similarStrokeTransform(a:m[0],b:m[1],c:m[2],d:m[3]))
        }
        for m in [[2.0,0,0,1],[1,0,0.1,1],[0,0,0,0],[Double.nan,0,0,1],[Double.infinity,0,0,1]] {
            XCTAssertFalse(PDFTextVisibility.similarStrokeTransform(a:m[0],b:m[1],c:m[2],d:m[3]))
        }
    }
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

    func testRecoveryRetainsDrawnSpacesWithoutChangingStrictGlyphs() throws {
        for width in [250.0,0.0] {
            let font=try PDFTextFont(unicode:[32:" ",65:"A",66:"B"],codeBytes:1,
                widths:[32:width,65:500,66:500],defaultWidth:1000,ascent:800,descent:-200)
            let engine=PDFTextGeometry();try engine.operation("BT");try engine.font(font,size:10)
            try engine.show(Array("A B".utf8));try engine.operation("ET")
            XCTAssertEqual(try engine.finish(expectedText:"A B").map(\.text).joined(),"AB")
            XCTAssertEqual(engine.recoveryComplete,width>0)
            XCTAssertEqual(engine.recoveryGlyphs.count,width>0 ? 3:2)
            if width>0 {
                XCTAssertEqual(engine.recoveryGlyphs.map(\.text).joined(),"A B")
                XCTAssertEqual(engine.recoveryGlyphs.map(\.sourceOrder),[0,1,2])
                XCTAssertEqual(engine.recoveryGlyphs[1].width,2.5)
            }
        }
    }

    func testFullTwoByteSingletonCodeDomainRemainsBoundedAndCancellable() throws {
        let codes = (0...65535).map { String(format:"<%04X>",$0) }
        let spaces = codes.map { $0+$0 }.joined()
        let entries = codes.map { $0+"<0041>" }.joined()
        let data = Data(("65536 begincodespacerange "+spaces+" endcodespacerange 65536 beginbfchar "+entries+" endbfchar").utf8)
        XCTAssertLessThan(data.count,2_000_000)
        let decoded = try PDFUnicodeMap.read(data)
        XCTAssertEqual(decoded.bytes,2); XCTAssertEqual(decoded.values.count,65536)
        XCTAssertEqual(decoded.values[0],"A"); XCTAssertEqual(decoded.values[65535],"A")
        var checks = 0
        XCTAssertThrowsError(try PDFUnicodeMap.read(data,check:{
            checks += 1; if checks == 3 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,3)
        XCTAssertThrowsError(try map("2 begincodespacerange <0000><00FF><00FF><01FF> endcodespacerange 1 beginbfchar <0000><0041> endbfchar"))
        XCTAssertThrowsError(try map("1 begincodespacerange <0000><00FF> endcodespacerange 1 beginbfchar <0100><0041> endbfchar"))
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
            "/Inherited usecmap", "/WMode 1 def",
            "1 beginbfchar <41> <0041> endbfrange"
        ] {
            XCTAssertThrowsError(try map(prefix + body))
        }
    }

    func testUnusedControlMappingsAreMetadataButDrawingThemFailsClosed() throws {
        let decoded = try map("1 begincodespacerange <00> <FF> endcodespacerange 3 beginbfchar <00> <0000> <41> <0041> <42> <000A> endbfchar")
        let mapped = try PDFTextFont(unicode: decoded.values, codeBytes: decoded.bytes,
                                    widths: [0: 500, 65: 500, 66: 500], defaultWidth: 1000,
                                    ascent: 800, descent: -200)
        let readable = PDFTextGeometry()
        try readable.operation("BT"); try readable.font(mapped, size: 10)
        try readable.show([65]); try readable.operation("ET")
        XCTAssertEqual(try readable.finish(expectedText: "A").map(\.text), ["A"])
        for code: UInt8 in [0, 66] {
            let used = PDFTextGeometry()
            try used.operation("BT"); try used.font(mapped, size: 10)
            XCTAssertThrowsError(try used.show([code])) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .characterMapping)
            }
            XCTAssertTrue(used.glyphs.isEmpty)
        }
    }

    func testUnusedUnsupportedFontStateAndGraphicsRestorePreserveReadableGlyphs() throws {
        let engine = PDFTextGeometry()
        try engine.operation("BT"); try engine.font(nil, size: 12); try engine.operation("ET")
        try engine.font(font(), size: 10)
        try engine.operation("q"); try engine.font(nil, size: 12); try engine.operation("Q")
        try engine.operation("BT"); try engine.show([65]); try engine.operation("ET")
        XCTAssertEqual(try engine.finish(expectedText: "A").map(\.text), ["A"])
        let used = PDFTextGeometry()
        try used.operation("BT"); try used.font(font(), size: 10); try used.font(nil, size: 12)
        XCTAssertThrowsError(try used.show([65]))
        for size in [0.0, -1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try PDFTextGeometry().font(nil, size: size))
        }
    }

    func testEmptyShowRequiresSelectedValidTextStateAndRetainsCancellation() throws {
        let engine = PDFTextGeometry()
        XCTAssertThrowsError(try engine.show([]))
        try engine.operation("BT")
        XCTAssertThrowsError(try engine.show([]))
        try engine.font(nil, size: 12)
        XCTAssertNoThrow(try engine.show([]))
        try engine.operation("Tz", [0])
        XCTAssertThrowsError(try engine.show([]))
        let cancelled = PDFTextGeometry { throw PDFParseError(code: .cancelled) }
        try cancelled.operation("BT"); try cancelled.font(nil, size: 12)
        XCTAssertThrowsError(try cancelled.show([])) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled)
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
            XCTAssertTrue(CGPDFDictionaryGetDictionary(try XCTUnwrap(page.dictionary),"Resources",&resources))
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
            var descriptorName: UnsafePointer<CChar>?
            XCTAssertTrue(CGPDFDictionaryGetName(try XCTUnwrap(descriptor),"FontName",&descriptorName))
            XCTAssertEqual(String(cString:try XCTUnwrap(descriptorName)),simple ? "Helvetica":"Synthetic")
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
    private func syntheticPDF(content: String, unicode: Bool = true, graphicsState: String = "", simpleFont: Bool = false, crop: String = "", unusedFont: Bool = false, unusedFontEntry: String = "") -> Data {
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
        var objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] \(crop) /Resources << /Font << /F1 4 0 R \(unusedFont ? "/FU 9 0 R" : "") >> /ExtGState << /Visibility << \(graphicsState) >> >> >> /Contents 8 0 R >>",
            simpleFont ? "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding /FirstChar 65 /LastChar 67 /Widths [667 667 667] /FontDescriptor 6 0 R \(unicode ? "/ToUnicode 7 0 R" : "") >>" : "<< /Type /Font /Subtype /Type0 /BaseFont /Synthetic /Encoding /Identity-H /DescendantFonts [5 0 R] \(unicode ? "/ToUnicode 7 0 R" : "") >>",
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Synthetic /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 6 0 R /DW 1000 /W [1 [500] 2 3 600] /CIDToGIDMap /Identity >>",
            "<< /Type /FontDescriptor /FontName /\(simpleFont ? "Helvetica" : "Synthetic") /Flags \(simpleFont ? 32:4) /FontBBox [0 -200 1000 800] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 >>",
            stream(cmap), stream(content)
        ]
        if unusedFont { objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding \(unusedFontEntry) >>") }
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

    private func paintedInk(_ data: Data,minimumX: Int = 0) throws -> Int {
        let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
        var pixels = [UInt8](repeating:255,count:300*400)
        return try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data:buffer.baseAddress,width:300,height:400,bitsPerComponent:8,bytesPerRow:300,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue))
            context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:300,height:400))
            context.drawPDFPage(page)
            return buffer.enumerated().reduce(0) { $0 + ($1.offset % 300 >= minimumX && $1.element != 255 ? 1:0) }
        }
    }
    func testNativeNearAxisMiterAndNonSimilarStrokeCannotCertifyPaintBounds() throws {
        let text = "BT /F1 12 Tf 1 0 0 1 120 114 Tm (A) Tj ET"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let transform = PDFDisplayTransform(media:CGRect(x:0,y:0,width:300,height:400),rotation:0)
        let textData = syntheticPDF(content:text,simpleFont:true)
        let hairpin = syntheticPDF(content:text+" 2 w 0 J 0 j 100 M 10 120 m 81.1 120 l 78.1 120.19 l S",simpleFont:true)
        XCTAssertGreaterThan(try paintedInk(hairpin),try paintedInk(textData))
        // The native Quartz diagnostic measured 40 pixels beyond x=85 for
        // this M100 join, versus zero for the otherwise identical M10 path.
        let bevelControl = syntheticPDF(content:text+" 2 w 0 J 0 j 10 M 10 120 m 81.1 120 l 78.1 120.19 l S",simpleFont:true)
        XCTAssertGreaterThan(try paintedInk(hairpin,minimumX:85),try paintedInk(bevelControl,minimumX:85))
        let negatives = [hairpin,
            syntheticPDF(content:text+" q 2 0 0 1 0 0 cm 0.1 w 20 20 m 40 20 l S Q",simpleFont:true),
            syntheticPDF(content:text+" q 1 0 0.1 1 0 0 cm 0.1 w 20 20 m 40 20 l S Q",simpleFont:true)]
        for (index,data) in negatives.enumerated() {
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertThrowsError(try PDFPathReader(transform:transform,verifyVisibility:true,check:{}).read(page)) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.vectorObjects)
            }
            let url = root.appendingPathComponent("fictional-\(index).pdf"); try data.write(to:url)
            let normal = RecoveryReadCapture(), special = RecoveryReadCapture()
            XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:normal))
            XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:special))
            XCTAssertFalse(normal.complete); XCTAssertFalse(special.complete)
        }
        for matrix in ["1 0 0 1", "0.5 0 0 0.5", "0 1 -1 0"] {
            let data = syntheticPDF(content:text+" q \(matrix) 100 100 cm 0.1 w 20 20 m 40 20 l S Q",simpleFont:true)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertEqual(try PDFPathReader(transform:transform,verifyVisibility:true,check:{}).read(page).count,1)
        }
    }
    func testNativeCrossedOrRetracedThinFillIsNotARectangularBorder() throws {
        let transform = PDFDisplayTransform(media:CGRect(x:0,y:0,width:300,height:400),rotation:0)
        for path in ["10 10 m 11 40 l 10 40 l 11 10 l h f", "10 10 m 11 10 l 10 10 l 10 40 l h f"] {
            let data = syntheticPDF(content:path,simpleFont:true)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertThrowsError(try PDFPathReader(transform:transform,verifyVisibility:true,check:{}).read(page)) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.vectorObjects)
            }
        }
        for path in ["10 10 1 30 re f", "10 10 m 11 10 l 11 40 l 10 40 l h f"] {
            let data = syntheticPDF(content:path,simpleFont:true)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertGreaterThan(try paintedInk(data),0)
            XCTAssertEqual(try PDFPathReader(transform:transform,verifyVisibility:true,check:{}).read(page).count,1)
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
    func testNativeDashedGhostRulesCannotBecomeACompleteTable() throws {
        let text = "0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let textOnlyInk = try paintedInk(syntheticPDF(content:text,simpleFont:true))
        XCTAssertGreaterThan(textOnlyInk,0)
        for (state,operatorText) in [("","[1 1000] 1 d"),("/D [[1 1000] 1]","/Visibility gs")] {
            let data = syntheticPDF(content:text+" "+operatorText+" 0 J 10 10 m 290 10 l S",graphicsState:state,simpleFont:true)
            let ink = try paintedInk(data)
            if state.isEmpty { XCTAssertEqual(ink,textOnlyInk,"The direct dash is entirely in its gap: \(operatorText)") }
            else {
                // Quartz may render ExtGState dash differently. The raw style
                // remains unsupported, whether the preview shows gaps or solid ink.
                XCTAssertGreaterThanOrEqual(ink,textOnlyInk,"ExtGState dash must retain the visible reference text")
            }
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            let reader = PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{})
            XCTAssertThrowsError(try reader.read(page)) { XCTAssertEqual(($0 as? PDFParseError)?.stage,.vectorObjects) }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-dash-"+UUID().uuidString+".pdf")
            defer { try? FileManager.default.removeItem(at:url) }; try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
                else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
                XCTAssertFalse(capture.complete); XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
        for (state,operatorText) in [("","[] 0 d"),("/D [[] 0]","/Visibility gs")] {
            let data = syntheticPDF(content:text+" "+operatorText+" 10 10 m 290 10 l S",graphicsState:state,simpleFont:true)
            XCTAssertGreaterThan(try paintedInk(data),textOnlyInk)
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            let reader = PDFPathReader(transform:PDFDisplayTransform(media:page.getBoxRect(.mediaBox),rotation:0),verifyVisibility:true,check:{})
            XCTAssertEqual(try reader.read(page).count,1)
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

    func testNativeUnusedUnsupportedFontSetupAllowsCompleteReadableTextButUseRejects() throws {
        let supported = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S"
        for setup in ["BT /FU 12 Tf 14.4 TL ET ", "BT /FU 12 Tf () Tj ET ", "BT /F1 10 Tf ET q BT /FU 12 Tf ET Q "] {
            let data = syntheticPDF(content: setup + supported, simpleFont: true, unusedFont: true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-unused-font-"+UUID().uuidString+".pdf")
            defer { try? FileManager.default.removeItem(at: url) }; try data.write(to: url)
            let capture = RecoveryReadCapture()
            XCTAssertEqual(try PDFKitReader.read(url, kind: .timetable, capture: capture).first?.glyphs.map(\.text), ["A", "B"])
            XCTAssertTrue(capture.complete)
        }
        let data = syntheticPDF(content: "BT /FU 12 Tf (A) Tj ET " + supported, simpleFont: true, unusedFont: true)
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData)), document = try XCTUnwrap(CGPDFDocument(provider))
        XCTAssertThrowsError(try PDFDrawnTextReader(check: {}).read(try XCTUnwrap(document.page(at: 1)), expectedText: "AAB")) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .characterMapping)
        }
        for (selection, entry) in [("FU", "/ToUnicode (broken)"), ("Missing", "")] {
            let malformed = syntheticPDF(content: "BT /\(selection) 12 Tf ET " + supported,
                                         simpleFont: true, unusedFont: true, unusedFontEntry: entry)
            let provider = try XCTUnwrap(CGDataProvider(data: malformed as CFData)), document = try XCTUnwrap(CGPDFDocument(provider))
            XCTAssertThrowsError(try PDFDrawnTextReader(check: {}).read(try XCTUnwrap(document.page(at: 1)), expectedText: "AB"))
        }
    }
}
#endif
