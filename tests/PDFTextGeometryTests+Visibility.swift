import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
#endif

extension PDFTextGeometryTests {
    func testUnusedDevicePaintDoesNotRejectBlackTextAndSavedColorRestores() throws {
        let font = try PDFTextFont(unicode:[65:"A"],codeBytes:1,widths:[65:667],defaultWidth:667,ascent:800,descent:-200)
        for setup in ["unused", "restored"] {
            let engine = PDFTextGeometry()
            try engine.operation("G",[1])
            try engine.operation("g",[1])
            if setup == "restored" {
                try engine.operation("g",[0]); try engine.operation("q")
                try engine.operation("g",[1]); try engine.operation("Q")
            } else { try engine.operation("g",[0]) }
            try engine.operation("BT"); try engine.font(font,size:10)
            try engine.operation("Tm",[1,0,0,1,30,350]); try engine.show([65]); try engine.operation("ET")
            XCTAssertEqual(try engine.finish(expectedText:"A").map(\.text),["A"])
        }
        for components in [[1.0], [1.0,0,0], [0.0,0,0,0]] {
            let engine = PDFTextGeometry()
            try engine.operation(components.count == 1 ? "g" : components.count == 3 ? "rg" : "k",components)
            try engine.operation("BT"); try engine.font(font,size:10)
            XCTAssertThrowsError(try engine.show([65]))
        }
    }

    func testClipContainmentHasNoToleranceAndPreservesLimitsAndCancellation() throws {
        let box = PDFBox(left:10,top:20,right:30,bottom:40)
        try PDFClipValidation.requireContains([box],clips:[box],check:{})
        for clip in [PDFBox(left:10.0.nextUp,top:20,right:30,bottom:40),
                     PDFBox(left:10,top:20,right:30.0.nextDown,bottom:40),
                     PDFBox(left:0,top:0,right:.infinity,bottom:100)] {
            XCTAssertThrowsError(try PDFClipValidation.requireContains([box],clips:[clip],check:{}))
        }
        XCTAssertThrowsError(try PDFClipValidation.requireContains([box],clips:Array(repeating:box,count:129),check:{})) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
        XCTAssertThrowsError(try PDFClipValidation.requireContains([box],clips:[box],check:{ throw PDFParseError(code:.cancelled) })) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled)
        }
    }

#if canImport(PDFKit)
    func testNativeInertTagsContainedClipsDeviceSpacesAndUnusedStylesPreserveDirectAcquisition() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rule = " 10 10 m 290 10 l S"
        let reference = syntheticPDF(content:text+rule,simpleFont:true)
        let variants = [
            "1 G 25 w 0 G 1 w "+text+rule,
            "1 g 0 g "+text+rule,
            "q 1 g Q "+text+rule,
            "1 g 0 0 300 400 re f 0 g "+text+rule,
            "/DeviceRGB cs 0 0 0 sc /DeviceRGB CS 0 0 0 SC "+text+rule,
            "/TextRGB cs 0 0 0 sc /TextCMYK CS 0 0 0 1 SCN "+text+rule,
            "/DeviceCMYK cs 0 0 0 1 scn "+text+rule,
            "/Artifact BMC "+text+rule+" EMC",
            "/Span << /MCID 0 /Lang (en) >> BDC "+text+rule+" EMC",
            "q 0 0 300 400 re W n "+text+rule+" Q",
            "q -1 -1 302 402 re W* n /Span << /MCID 0 >> BDC "+text+rule+" EMC Q"
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-inert-visibility-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (index, content) in variants.enumerated() {
            let data = syntheticPDF(content:content,simpleFont:true,colorSpaces:"/TextRGB /DeviceRGB /TextCMYK /DeviceCMYK /DefaultRGB /DeviceRGB")
            #if canImport(AppKit)
            XCTAssertEqual(try thumbnailPixels(data,box:.mediaBox).pixels,try thumbnailPixels(reference,box:.mediaBox).pixels,"variant \(index)")
            #endif
            let provider = try XCTUnwrap(CGDataProvider(data:data as CFData))
            let document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
            XCTAssertEqual(try PDFDrawnTextReader(check:{}).read(page,expectedText:"AB").map(\.text).joined(),"AB")
            let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                let pages: [PDFPageLayout]
                if special { pages = try PDFKitReader.readSpecial(url,capture:capture) }
                else { pages = try PDFKitReader.read(url,kind:.timetable,capture:capture) }
                XCTAssertTrue(capture.complete,"variant \(index), special \(special)")
                XCTAssertEqual(pages[0].glyphs.map(\.text).joined(),"AB")
                XCTAssertEqual(pages[0].lines.count,1)
            }
        }
    }

    func testNativeConcealingClipsOptionalReplacementAndUnbalancedTagsRemainRejected() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S"
        let variants = [
            "q 0 0 20 400 re W n "+text+" Q",
            "q 20 340 40 30 re W n "+text+" Q", // Text fits, but the rule is cut off.
            "q 1 1 298 398 re W* n "+text+" Q", // Metrics cannot certify outlines inside a smaller clip.
            "q 0 0 300 400 re 10 10 20 20 re W* n "+text+" Q", // A hole is not a single rectangle.
            "/OC BMC "+text+" EMC",
            "/Span << /ActualText (Other) >> BDC "+text+" EMC",
            "/Span << /MCID -1 >> BDC "+text+" EMC",
            "/Artifact BMC "+text,
            text+" EMC",
            "/ICCBased cs "+text
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-concealing-visibility-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (index, content) in variants.enumerated() {
            let url = root.appendingPathComponent("fictional.pdf")
            try syntheticPDF(content:content,simpleFont:true).write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture),"variant \(index)") }
                else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture),"variant \(index)") }
                XCTAssertFalse(capture.complete)
                XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
        for (prefix, resources) in [("", "/DefaultRGB [/ICCBased 4 0 R]"),
                                    ("", "/DefaultGray [/CalGray << /WhitePoint [1 1 1] >>]"),
                                    ("/Cycle cs ", "/Cycle /Cycle")] {
            let url = root.appendingPathComponent("fictional.pdf")
            try syntheticPDF(content:prefix+text,simpleFont:true,colorSpaces:resources).write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
                else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
                XCTAssertFalse(capture.complete)
            }
        }
    }
#endif
}
