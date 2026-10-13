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
        for components in [[1.0], [1.0,1,1], [0.0,0,0,0]] {
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
    func testNativeBoundedOutlinesAndSingletonNormalBlendPreserveDirectText() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-outline-compatibility-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("fictional.pdf")
        for (mode,fill) in [(1,0),(1,1),(2,0),(2,1)] {
            let spacing = mode == 2 && fill == 1 ? "10 Tc" : "0 Tc"
            let content = "/Visibility gs \(fill) g 0 G 0.5 w 1 j BT /F1 10 Tf \(mode) Tr \(spacing) 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S"
            let data = syntheticPDF(content:content,graphicsState:"/BM [/Normal] /ca 1 /CA 1",simpleFont:true)
            XCTAssertGreaterThan(try paintedInk(data),0)
            try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                let pages = try special ? PDFKitReader.readSpecial(url,capture:capture)
                    : PDFKitReader.read(url,kind:.timetable,capture:capture)
                XCTAssertEqual(pages.count,1); XCTAssertEqual(pages[0].glyphs.map(\.text).joined(),"AB")
                XCTAssertEqual(pages[0].lines.count,1); XCTAssertTrue(capture.complete)
                XCTAssertTrue(pages[0].glyphs.allSatisfy { $0.sourceLine != nil && $0.sourceOrder != nil })
            }
        }
    }

    func testNativeOutlineFontBoundsCannotCrossGridOutsideTheAdvanceBox() throws {
        // Advance ends at 43.34; the declared outline bound reaches 46.67 before padding.
        let content = "0.5 w 1 j BT /F1 10 Tf 1 Tr 1 0 0 1 30 350 Tm (AB) Tj ET 46 340 m 46 365 l S"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-outline-boundary-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("fictional.pdf")
        try syntheticPDF(content:content,simpleFont:true).write(to:url)
        for special in [false,true] {
            let capture = RecoveryReadCapture()
            if special { XCTAssertThrowsError(try PDFKitReader.readSpecial(url,capture:capture)) }
            else { XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture)) }
            XCTAssertFalse(capture.complete)
        }
    }

    func testNativeDiscardedCurvesUnusedDashAndRestoredDashKeepTheVisibleTable() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rule = " 10 10 m 290 10 l S"
        let variants: [(String,String)] = [
            ("", "0 0 m 1 1 2 2 3 3 c n "+text+rule),
            ("", "[1 3] 0 d "+text+" [] 0 d"+rule),
            ("/D [[1 3] 0]", "q /Visibility gs "+text+" Q"+rule),
            ("", "[] 7 d "+text+rule)
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-unused-style-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let reference = syntheticPDF(content:text+rule,simpleFont:true)
        for (state,content) in variants {
            let data = syntheticPDF(content:content,graphicsState:state,simpleFont:true)
            #if canImport(AppKit)
            XCTAssertEqual(try thumbnailPixels(data,box:.mediaBox).pixels,try thumbnailPixels(reference,box:.mediaBox).pixels)
            #endif
            let url = root.appendingPathComponent("fictional.pdf"); try data.write(to:url)
            for special in [false,true] {
                let capture = RecoveryReadCapture()
                let pages = try special ? PDFKitReader.readSpecial(url,capture:capture)
                    : PDFKitReader.read(url,kind:.timetable,capture:capture)
                XCTAssertEqual(pages[0].glyphs.map(\.text).joined(),"AB")
                XCTAssertEqual(pages[0].lines.count,1); XCTAssertTrue(capture.complete)
            }
        }
    }

    func testNativeVerifiedFilledArrowRetainsItsOriginalGeometryInStrictReaders() throws {
        let content = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET 10 10 m 290 10 l S "
            + "100 250 1 30 re 97.5 250 m 103.5 250 l 100.5 244 l h f"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-strict-arrow-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("fictional.pdf")
        try syntheticPDF(content:content,simpleFont:true).write(to:url)
        for special in [false,true] {
            let capture = RecoveryReadCapture()
            let pages = try special ? PDFKitReader.readSpecial(url,capture:capture)
                : PDFKitReader.read(url,kind:.timetable,capture:capture)
            let arrows = try XCTUnwrap(pages[0].arrows)
            let arrow = try XCTUnwrap(arrows.first)
            XCTAssertEqual(arrows.count,1); XCTAssertEqual(arrow.x,100.5)
            XCTAssertEqual(arrow.top,120); XCTAssertEqual(arrow.bottom,156)
            XCTAssertTrue(capture.complete)
        }
    }

    func testNativeDisjointFilledRulesAndDecorationsPreserveTextAndGeometryInEitherPaintOrder() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rules = [
            "10 10 280 1 re f 10 10 1 280 re f",
            "10 10 m 290 10 l 290 11 l 10 11 l h f 10 10 1 280 re f",
            "10 10 280 1 re f 10 10 1 280 re f 0.2 0.35 0.6 rg 150 150 40 40 re f 0 g",
            "10 10 280 1 re f 10 10 1 280 re f 150 150 2 2 re f"
        ]
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-filled-rule-order-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for rule in rules {
            for special in [false, true] {
                var originalGlyphs: Data?
                for content in [rule + " " + text, text + " " + rule] {
                    try syntheticPDF(content: content, simpleFont: true).write(to: url)
                    let capture = RecoveryReadCapture()
                    let pages: [PDFPageLayout]
                    if special { pages = try PDFKitReader.readSpecial(url, capture: capture) }
                    else { pages = try PDFKitReader.read(url, kind: .timetable, capture: capture) }
                    let page = try XCTUnwrap(pages.first)
                    XCTAssertEqual(pages.count, 1)
                    XCTAssertEqual(page.glyphs.map(\.text).joined(), "AB")
                    XCTAssertEqual(page.lines.count, 2)
                    XCTAssertEqual(page.lines[0].y1, 389.5)
                    XCTAssertEqual(page.lines[1].x1, 10.5)
                    XCTAssertTrue(capture.complete)
                    let glyphs = try encoder.encode(page.glyphs)
                    if let originalGlyphs { XCTAssertEqual(glyphs, originalGlyphs) }
                    else { originalGlyphs = glyphs }
                }
            }
        }
    }

    func testNativeOverlappingFilledRulesNeverCompleteDeferredCapture() throws {
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-filled-rule-overlap-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        // Both thin rules and broad rectangles through text fail in either
        // order; none may turn partial extraction into a complete capture.
        let contents = [
            text + " 20 350 70 1 re f",
            "20 350 70 1 re f " + text,
            text + " 20 345 70 20 re f",
            "20 345 70 20 re f " + text
        ]
        for content in contents {
            try syntheticPDF(content: content, simpleFont: true).write(to: url)
            for special in [false, true] {
                let capture = RecoveryReadCapture()
                if special {
                    XCTAssertThrowsError(try PDFKitReader.readSpecial(url, capture: capture))
                } else {
                    XCTAssertThrowsError(try PDFKitReader.read(url, kind: .timetable, capture: capture))
                }
                XCTAssertFalse(capture.complete)
                XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
    }

    func testNativeLightBackgroundBeforeTextPreservesAcquisitionAndRejectsOverpaint() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-background-contrast-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        let background = "q 0.85 0.9 1 rg 20 335 75 40 re f Q "
        let rule = " 10 10 m 290 10 l S"
        for mode in [0, 1, 2] {
            let text = "0 g 0 G 0.5 w 1 j BT /F1 10 Tf \(mode) Tr 1 0 0 1 30 350 Tm (AB) Tj ET"
            for special in [false, true] {
                try syntheticPDF(content: text + rule, simpleFont: true).write(to: url)
                let reference = try special ? PDFKitReader.readSpecial(url)
                    : PDFKitReader.read(url, kind: .timetable)
                try syntheticPDF(content: background + text + rule, simpleFont: true).write(to: url)
                let capture = RecoveryReadCapture()
                let pages = try special ? PDFKitReader.readSpecial(url, capture: capture)
                    : PDFKitReader.read(url, kind: .timetable, capture: capture)
                XCTAssertEqual(pages[0].glyphs.map(\.text), reference[0].glyphs.map(\.text))
                XCTAssertEqual(pages[0].glyphs.map(\.x), reference[0].glyphs.map(\.x))
                XCTAssertEqual(pages[0].glyphs.map(\.y), reference[0].glyphs.map(\.y))
                XCTAssertEqual(pages[0].glyphs.map(\.sourceOrder), reference[0].glyphs.map(\.sourceOrder))
                XCTAssertEqual(pages[0].lines.count, 1)
                XCTAssertTrue(capture.complete)
                try syntheticPDF(content: text + background + rule, simpleFont: true).write(to: url)
                let rejected = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url, capture: rejected)
                    : PDFKitReader.read(url, kind: .timetable, capture: rejected)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.branch, .b265)
                }
                XCTAssertFalse(rejected.complete)
            }
        }
    }

    func testNativeBackgroundContrastCannotCertifyHiddenLowContrastOrLateBackgroundText() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-background-rejection-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let light = "q 0.9 g 20 335 75 40 re f Q "
        let cases: [(String, PDFParseError.Branch)] = [
            ("q 0 g 20 335 75 40 re f Q " + text, .b267),
            (light + "0.9 g " + text, .b267),
            (light + "0.8 g " + text, .b267),
            (text + " " + light + text, .b265),
            ("0.9 g 20 350 75 1 re f 0 g " + text, .b265),
            ("/Visibility gs " + light + text, .b144),
            (light + "0 g " + text + " 0.9 g " + text, .b267),
            (light + "q 0.1 g 20 335 75 40 re f Q 0 g " + text, .b267),
            ("0 g 20 335 75 40 re 20 335 75 40 re f* 0.8 g " + text, .b270),
            ("0 g 20 335 75 40 re 20 375 75 -40 re f 0.8 g " + text, .b270),
            ("q 0 g 30 345 4 20 re f Q 0.9 g " + text, .b267)
        ]
        for (content, branch) in cases {
            try syntheticPDF(content: content + " 10 10 m 290 10 l S",
                graphicsState: "/ca 0.5", simpleFont: true).write(to: url)
            for special in [false, true] {
                let capture = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url, capture: capture)
                    : PDFKitReader.read(url, kind: .timetable, capture: capture)) {
                    // Normal text reads ExtGState before the path scan; the
                    // special reader rejects it at the path scan instead.
                    let expected = branch == .b144 && !special ? PDFParseError.Branch.b067 : branch
                    XCTAssertEqual(($0 as? PDFParseError)?.branch, expected)
                }
                XCTAssertFalse(capture.complete)
                XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
    }

    func testNativeBackgroundCannotEraseOrHideStructuralRules() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-background-grid-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        let background = "q 0.9 g 0 0 300 400 re f Q "
        let text = "0 g BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let cases: [(String, PDFParseError.Branch)] = [
            ("10 10 m 290 10 l S " + background + text, .b268),
            ("10 10 280 1 re f " + background + text, .b268),
            (background + "0.9 G 10 10 m 290 10 l S " + text, .b269),
            (background + "0.9 g 10 10 280 1 re f " + text, .b269),
            (background + "0.9 g 100 250 1 30 re 97.5 250 m 103.5 250 l 100.5 244 l h f " + text, .b269)
        ]
        for (content, branch) in cases {
            try syntheticPDF(content: content, simpleFont: true).write(to: url)
            for special in [false, true] {
                let capture = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url, capture: capture)
                    : PDFKitReader.read(url, kind: .timetable, capture: capture)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.branch, branch)
                }
                XCTAssertFalse(capture.complete)
                XCTAssertFalse(capture.pages.contains { $0.state == .complete })
            }
        }
    }

    func testNativeBackgroundOverprintRequiresKnownNormalCompositingAndRestoresGraphicsState() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("takupoke-background-overprint-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fictional.pdf")
        let background = "q 0.9 g 20 335 75 40 re f Q "
        let text = "BT /F1 10 Tf 1 0 0 1 30 350 Tm (AB) Tj ET"
        let rule = " 10 10 m 290 10 l S"
        for state in ["/OP true", "/op true /OPM 1", "/op /Unknown"] {
            for special in [false, true] {
                try syntheticPDF(content: "/Visibility gs " + background + text + rule,
                    graphicsState: state, simpleFont: true).write(to: url)
                let capture = RecoveryReadCapture()
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url, capture: capture)
                    : PDFKitReader.read(url, kind: .timetable, capture: capture)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.branch, .b271)
                }
                XCTAssertFalse(capture.complete)
                try syntheticPDF(content: "q /Visibility gs Q " + background + text + rule,
                    graphicsState: state, simpleFont: true).write(to: url)
                let restored = try special ? PDFKitReader.readSpecial(url)
                    : PDFKitReader.read(url, kind: .timetable)
                XCTAssertEqual(restored[0].glyphs.map(\.text).joined(), "AB")
                try syntheticPDF(content: background + "/Visibility gs " + text + rule,
                    graphicsState: state, simpleFont: true).write(to: url)
                XCTAssertThrowsError(try special ? PDFKitReader.readSpecial(url)
                    : PDFKitReader.read(url, kind: .timetable)) {
                    XCTAssertEqual(($0 as? PDFParseError)?.branch, .b267)
                }
                for content in [
                    "/Visibility gs /Disabled gs " + background + text + rule,
                    background + "/Visibility gs /Disabled gs " + text + rule,
                    background + "/Visibility gs /Disabled gs " + rule + " " + text
                ] {
                    try syntheticPDF(content: content, graphicsState: state, simpleFont: true,
                        extraGraphicsStates: "/Disabled << /OP false /op false >>").write(to: url)
                    let cleared = RecoveryReadCapture()
                    let pages = try special ? PDFKitReader.readSpecial(url, capture: cleared)
                        : PDFKitReader.read(url, kind: .timetable, capture: cleared)
                    XCTAssertEqual(pages[0].glyphs.map(\.text).joined(), "AB")
                    XCTAssertEqual(pages[0].lines.count, 1)
                    XCTAssertTrue(cleared.complete)
                }
            }
        }
        try syntheticPDF(content: "/Visibility gs " + background + text + rule,
            graphicsState: "/OP false /op false /OPM 1", simpleFont: true).write(to: url)
        XCTAssertEqual(try PDFKitReader.read(url, kind: .timetable)[0].lines.count, 1)
        XCTAssertEqual(try PDFKitReader.readSpecial(url)[0].lines.count, 1)
    }

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
            "q -1 -1 302 402 re W* n /Span << /MCID 0 >> BDC "+text+rule+" EMC Q",
            text+rule // An unsupported but unused DefaultRGB must not reject DeviceGray ink.
        ]
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-inert-visibility-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        for (index, content) in variants.enumerated() {
            let resources = index == variants.count-1 ? "/DefaultRGB [/ICCBased 4 0 R]"
                : "/TextRGB /DeviceRGB /TextCMYK /DeviceCMYK /DefaultRGB /DeviceRGB"
            let data = syntheticPDF(content:content,simpleFont:true,colorSpaces:resources)
            #if canImport(AppKit)
            // DeviceCMYK's rendered black differs from DeviceGray. Independent
            // references use canonical operators for that same paint, without
            // aliases or unused state; every pixel must still match exactly.
            let comparison: Data
            if index == 5 {
                comparison = syntheticPDF(content:text+" /DeviceCMYK CS 0 0 0 1 SCN "+rule,simpleFont:true)
            } else if index == 6 {
                comparison = syntheticPDF(content:"/DeviceCMYK cs 0 0 0 1 scn "+text+rule,simpleFont:true)
            } else { comparison = reference }
            XCTAssertTrue(try thumbnailPixels(data,box:.mediaBox).pixels == thumbnailPixels(comparison,box:.mediaBox).pixels,"variant \(index)")
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
        for (prefix, resources) in [("/DeviceRGB cs 0 0 0 sc ", "/DefaultRGB [/ICCBased 4 0 R]"),
                                    ("", "/DefaultGray [/CalGray << /WhitePoint [1 0 1] >>]"),
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
