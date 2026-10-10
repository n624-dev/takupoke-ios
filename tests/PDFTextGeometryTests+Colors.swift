import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
#endif

extension PDFTextGeometryTests {
    func testPDFPaintNumbersExpandExponentsWithoutRoundingSmallValues() {
        for value in [0.0,1,0.000001,Double.leastNonzeroMagnitude,Double.greatestFiniteMagnitude,-1e200,-Double.leastNonzeroMagnitude] {
            let literal = PDFPaintNumber.literal(value)
            XCTAssertFalse(literal.lowercased().contains("e"))
            XCTAssertEqual(Double(literal),value)
            XCTAssertLessThan(literal.count,350)
        }
    }
    func testVisibleDeviceColorsKeepOriginalGlyphOrderAndCoordinates() throws {
        let font = try PDFTextFont(unicode:[65:"A",66:"B"],codeBytes:1,
            widths:[65:667,66:667],defaultWidth:667,ascent:800,descent:-200)
        for values in [[0.0], [0.5], [1.0,0,0], [0.0,0,1], [0.0,1,1,0]] {
            let engine = PDFTextGeometry()
            try engine.operation(values.count == 1 ? "g" : values.count == 3 ? "rg" : "k",values)
            try engine.operation("BT"); try engine.font(font,size:10)
            try engine.operation("Tm",[1,0,0,1,30,350]); try engine.show([65,66]); try engine.operation("ET")
            let glyphs = try engine.finish(expectedText:"AB")
            XCTAssertEqual(glyphs.map(\.text),["A","B"])
            XCTAssertEqual(glyphs.map(\.sourceOrder),[0,1])
            XCTAssertEqual(glyphs[0].x,30); XCTAssertEqual(glyphs[1].x,36.67,accuracy:0.0001)
        }
    }

#if canImport(PDFKit)
    func testNativeDeviceColorAssignmentsKeepOperationLimitAndCancellation() throws {
        let data = syntheticPDF(content:String(repeating:"0 g\n",count:1_000_001) +
            "BT /F1 10 Tf 30 350 Td (AB) Tj ET",simpleFont:true)
        let provider = try XCTUnwrap(CGDataProvider(data:data as CFData))
        let document = try XCTUnwrap(CGPDFDocument(provider)), page = try XCTUnwrap(document.page(at:1))
        XCTAssertThrowsError(try PDFDrawnTextReader(check:{}).read(page,expectedText:"AB")) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
        var checks = 0
        XCTAssertThrowsError(try PDFDrawnTextReader(check:{
            checks += 1; if checks == 17 { throw PDFParseError(code:.cancelled) }
        }).read(page,expectedText:"AB")) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,17)
    }

    private func assertVisibleColorAcquisition(_ data: Data, rulesOnly: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        // The independent PDF renderer must show additional text ink beyond
        // the rule alone. A black rule cannot hide white or invisible text.
        XCTAssertGreaterThan(try paintedInk(data),try paintedInk(rulesOnly),file:file,line:line)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-visible-color-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
        let reference = syntheticPDF(content:"BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S",simpleFont:true)
        let referenceURL = root.appendingPathComponent("reference.pdf"); try reference.write(to:referenceURL)
        let expected = try PDFKitReader.read(referenceURL,kind:.timetable)[0]
        for special in [false,true] {
            let capture = RecoveryReadCapture()
            let pages = special ? try PDFKitReader.readSpecial(url,capture:capture)
                : try PDFKitReader.read(url,kind:.timetable,capture:capture)
            XCTAssertTrue(capture.complete,file:file,line:line)
            XCTAssertEqual(pages[0].glyphs.map(\.text),expected.glyphs.map(\.text),file:file,line:line)
            XCTAssertEqual(pages[0].glyphs.map(\.sourceOrder),expected.glyphs.map(\.sourceOrder),file:file,line:line)
            XCTAssertEqual(pages[0].glyphs.map(\.x),expected.glyphs.map(\.x),file:file,line:line)
            XCTAssertEqual(pages[0].glyphs.map(\.y),expected.glyphs.map(\.y),file:file,line:line)
            XCTAssertEqual(pages[0].lines.count,1,file:file,line:line)
            XCTAssertEqual(pages[0].lines[0].x1,expected.lines[0].x1,file:file,line:line)
            XCTAssertEqual(pages[0].lines[0].x2,expected.lines[0].x2,file:file,line:line)
        }
    }
    func testNativeVisibleDeviceCalibratedAndUnusedUnknownColorsPreserveAcquisition() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rule = " 10 10 m 290 10 l S"
        let calibrated = "/RGB [/CalRGB << /WhitePoint [0.9505 1 1.089] /Gamma [1 1 1] >>] /Gray [/CalGray << /WhitePoint [0.9505 1 1.089] >>]"
        for (setup, resources) in [
            ("1 0 0 rg 0 0 1 RG ", ""), ("0.5 g 0.5 G ", ""),
            ("0 1 1 0 k 1 1 0 0 K ", ""),
            ("/RGB cs 1 0 0 sc /RGB CS 0 0 1 SC ", calibrated),
            ("/Gray cs 0.5 sc /Gray CS 0.5 SC ", calibrated),
            ("1 0 0 rg 0 0 1 RG ","/DefaultRGB [/CalRGB << /WhitePoint [0.9505 1 1.089] >>]"),
            ("/Unknown cs 0.2 0.3 0.4 scn 0 g ","/Unknown [/Lab << /WhitePoint [1 1 1] >>]"),
            ("q /Unknown cs 0.2 0.3 0.4 scn Q ","/Unknown [/Lab << /WhitePoint [1 1 1] >>]")
        ] {
            try assertVisibleColorAcquisition(syntheticPDF(content:setup+text+rule,simpleFont:true,colorSpaces:resources),
                rulesOnly:syntheticPDF(content:setup+rule,simpleFont:true,colorSpaces:resources))
        }
    }

    func testNativeTrustedSRGBProfileSupportsExplicitAndDefaultColors() throws {
        // The OS supplies this profile independently of the target PDF. It
        // supplies only color interpretation, never Unicode or text answers.
        let space = try XCTUnwrap(CGColorSpace(name:CGColorSpace.sRGB))
        let profile = try XCTUnwrap(space.copyICCData()) as Data
        var stream = Data("<< /N 3 /Length \(profile.count) >>\nstream\n".utf8)
        stream.append(profile); stream.append(Data("\nendstream".utf8))
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rule = " 10 10 m 290 10 l S"
        for (setup, resources) in [
            ("/Profile cs 1 0 0 sc /Profile CS 0 0 1 SC ","/Profile [/ICCBased 9 0 R]"),
            ("1 0 0 rg 0 0 1 RG ","/DefaultRGB [/ICCBased 9 0 R]")
        ] {
            for intent in ["Perceptual","RelativeColorimetric","Saturation","AbsoluteColorimetric"] {
                let prefix = "/\(intent) ri "+setup
                try assertVisibleColorAcquisition(syntheticPDF(content:prefix+text+rule,simpleFont:true,
                    colorSpaces:resources,additionalObjects:[stream]),
                    rulesOnly:syntheticPDF(content:prefix+rule,simpleFont:true,colorSpaces:resources,additionalObjects:[stream]))
            }
        }
    }

    func testNativeInvalidUsedColorAndWhiteCalibratedTextRemainRejected() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let cases = [
            ("/RGB cs 1 1 1 sc ","/RGB [/CalRGB << /WhitePoint [0.9505 1 1.089] >>]"),
            ("/Gray cs 1 sc ","/Gray [/CalGray << /WhitePoint [0.9505 1 1.089] >>]"),
            ("/Bad cs 0 0 0 sc ","/Bad [/CalRGB << /WhitePoint [1 0 1] >>]"),
            ("/Bad cs 0 0 0 sc ","/Bad [/CalRGB << /WhitePoint [1 1 1] /Gamma [-1 1 1] >>]"),
            ("/Unknown cs 0.2 0.3 0.4 scn ","/Unknown [/Lab << /WhitePoint [1 1 1] >>]")
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-invalid-color-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (setup, resources) in cases {
            let url = root.appendingPathComponent("fictional.pdf")
            try syntheticPDF(content:setup+text,simpleFont:true,colorSpaces:resources).write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url,capture:capture)
                    : PDFKitReader.read(url,kind:.timetable,capture:capture)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.stage,.paintVisibility)
                }
                XCTAssertFalse(capture.complete)
            }
        }
    }

    func testNativeMalformedMismatchedAndWhiteICCColorsDoNotCertifyText() throws {
        let profile = try XCTUnwrap(try XCTUnwrap(CGColorSpace(name:CGColorSpace.sRGB)).copyICCData()) as Data
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-invalid-icc-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (bytes, count, color, parameters) in [(profile,1,"0",""), (Data("invented-invalid-profile".utf8),3,"0 0 0",""),
            (profile,3,"1 1 1",""), (profile,3,"0 0 0","/Range [1 1 1 1 1 1]"),
            (profile,3,"0 0 0","/Alternate /DeviceCMYK")] {
            var stream = Data("<< /N \(count) /Length \(bytes.count) \(parameters) >>\nstream\n".utf8)
            stream.append(bytes); stream.append(Data("\nendstream".utf8))
            let url = root.appendingPathComponent("fictional.pdf")
            try syntheticPDF(content:"/Profile cs \(color) sc "+text,simpleFont:true,
                colorSpaces:"/Profile [/ICCBased 9 0 R]",additionalObjects:[stream]).write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url,capture:capture)
                    : PDFKitReader.read(url,kind:.timetable,capture:capture)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.stage,.paintVisibility)
                }
                XCTAssertFalse(capture.complete)
            }
        }
    }
    func testNativeCMYKVisibilityMatchesFictionalRenderedTextIncludingFaintInk() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-faint-ink-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for color in ["0 0 0 0", "0 0.000001 0 0", "0 0 0 0.000001", "0.5 0 0 0"] {
            let textOnly = syntheticPDF(content:color+" k "+text,simpleFont:true)
            let visible = try paintedInk(textOnly) > 0
            if color == "0 0 0 0" { XCTAssertFalse(visible) }
            let url = root.appendingPathComponent("fictional.pdf")
            try syntheticPDF(content:color+" k "+text+" 10 10 m 290 10 l S",simpleFont:true).write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                if visible {
                    let pages = special ? try PDFKitReader.readSpecial(url,capture:capture)
                        : try PDFKitReader.read(url,kind:.timetable,capture:capture)
                    XCTAssertTrue(capture.complete); XCTAssertEqual(pages[0].glyphs.map(\.text).joined(),"AB")
                } else {
                    XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url,capture:capture)
                        : PDFKitReader.read(url,kind:.timetable,capture:capture))
                    XCTAssertFalse(capture.complete)
                }
            }
        }
    }
#endif
}
