import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    // Independent synthetic ink markers test coverage, not font recognition accuracy.
    func twoClassRasterCoverage(annotation: Bool = false, unknownAnnotation: Bool = false) throws -> (
        PDFPageLayout, RecoveryRasterGrid
    ) {
        let width = 740
        let height = 480
        var glyphs = [PDFGlyph]()
        var rules = [PDFRule]()
        var sourceLine = 0
        func text(
            _ value: String, _ x: Double, _ y: Double, _ charWidth: Double = 3, _ charHeight: Double = 6
        ) {
            for (i, c) in value.enumerated() {
                glyphs.append(
                    PDFGlyph(
                        text: String(c), x: x + Double(i) * charWidth, y: y, width: charWidth,
                        height: charHeight, sourceLine: sourceLine, sourceOrder: glyphs.count))
            }
            sourceLine += 1
        }
        text("令和14年度", 20, 8, 5, 8)
        text("前期", 80, 8, 5, 8)
        for y in [40.0, 72.0, 96.0, 148.0, 200.0] { rules.append(PDFRule(x1: 20, y1: y, x2: 720, y2: y)) }
        for x in [20.0, 44.0, 80.0] { rules.append(PDFRule(x1: x, y1: 40, x2: x, y2: 200)) }
        for p in 0...40 {
            let x = 80 + Double(p) * 16
            rules.append(PDFRule(x1: x, y1: p % 8 == 0 ? 40 : 72, x2: x, y2: 200))
        }
        for (day, label) in ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日"].enumerated() {
            text(label, 80 + Double(day) * 128 + 55, 48)
            for p in 1...8 { text(String(p), 80 + Double(day * 8 + p - 1) * 16 + 6, 78, 4, 8) }
        }
        for row in 0..<2 {
            let top = 96 + Double(row) * 52
            text(String(row + 1), 28, top + 22, 4, 8)
            text(row == 0 ? "2" : "CN", 58, top + 22, 4, 8)
            for p in 0..<40 {
                for (line, value) in ["架空科", "架空師", "架空室"].enumerated() {
                    text(value, 80 + Double(p) * 16 + 3, top + 6 + Double(line) * 16, 3, 6)
                }
            }
        }
        var gray = [UInt8](repeating: 255, count: width * height)
        for r in rules {
            if r.horizontal {
                for x in Int(r.x1)...min(width - 1, Int(r.x2)) { gray[Int(r.y1) * width + x] = 0 }
            } else {
                for y in Int(r.y1)...Int(r.y2) { gray[y * width + Int(r.x1)] = 0 }
            }
        }
        for g in glyphs { gray[Int(g.cy) * width + Int(g.cx)] = 0 }
        if annotation {
            text("架空注記", 24, 240, 4, 8)
            for g in glyphs where g.y >= 240 { gray[Int(g.cy) * width + Int(g.cx)] = 0 }
        }
        if unknownAnnotation { gray[260 * width + 24] = 0 }
        let raster = try RecoveryRasterGrid(width: width, height: height, grayscale: gray).preparingRules(
            rules)
        return (
            PDFPageLayout(width: Double(width), height: Double(height), glyphs: glyphs, lines: rules), raster
        )

    }
    func testOCRRecoveryRejectsAnEntireUnobservedClassRow() throws {
        let (original, raster) = try twoClassRasterCoverage()
        var omitted = original
        omitted.glyphs.removeAll { $0.cy >= 148 }
        XCTAssertTrue(
            try raster.hasUncoveredInk(
                RecoveryBox(x: 0, y: 0, width: original.width, height: original.height),
                text: omitted.glyphs.map {
                    RecoveryBox(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
                }, rules: original.lines, check: {}))
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [omitted], kind: .timetable, hash: String(repeating: "b", count: 64), fromOCR: [1],
                rasters: [1: raster])
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .ambiguous)
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .rasterInput)
        }
    }
    func testOCRRecoveryAccountsForBothClassRowsRulesAndKnownAnnotation() async throws {
        for annotation in [false, true] {
            let (page, raster) = try twoClassRasterCoverage(annotation: annotation)
            let doc = try RecoveryDocumentBuilder.build(
                [page], kind: .timetable, hash: String(repeating: "b", count: 64), fromOCR: [1],
                rasters: [1: raster])
            XCTAssertEqual(doc.classes, ["1_2", "2_CN"])
            XCTAssertEqual(doc.requiredSlots.count, 80)
            XCTAssertEqual(doc.annotations.count, annotation ? 1 : 0)
            let proof = try XCTUnwrap(doc.ocrCoverageProof)
            XCTAssertEqual(proof.version, 1)
            XCTAssertEqual(proof.pages.count, 1)
            XCTAssertEqual(proof.pages[0].page, 1)
            XCTAssertEqual(proof.pages[0].width, 740)
            XCTAssertEqual(proof.pages[0].height, 480)
            XCTAssertEqual(
                proof.pages[0].grayscaleSHA256,
                SHA256.hash(data: Data(raster.grayscale)).map { String(format: "%02x", $0) }.joined())
            let run = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc, result).canAdopt)
            XCTAssertEqual(result.cells.flatMap(\.lessons).count, 80)
            for lesson in result.cells.flatMap(\.lessons) {
                XCTAssertEqual(lesson.subject.value, "架空科")
                XCTAssertEqual(lesson.teacher.value, "架空師")
                XCTAssertEqual(lesson.room.value, "架空室")
            }
        }
    }
    func testOCRRecoveryRejectsUnobservedAnnotationInkOutsideRecognizedCells() throws {
        let (page, raster) = try twoClassRasterCoverage(unknownAnnotation: true)
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                [page], kind: .timetable, hash: String(repeating: "b", count: 64), fromOCR: [1],
                rasters: [1: raster])
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .rasterInput)
        }
    }
    func testVectorRecoveryDoesNotTreatUnrequestedRasterAsOCRProof() throws {
        let (page, raster) = try twoClassRasterCoverage(unknownAnnotation: true)
        let doc = try RecoveryDocumentBuilder.build(
            [page], kind: .timetable, hash: String(repeating: "b", count: 64), rasters: [1: raster])
        XCTAssertEqual(doc.requiredSlots.count, 80)
        XCTAssertFalse(doc.sources.contains { $0.fromOcr })
        XCTAssertNil(doc.ocrCoverageProof)
    }
}

extension PDFParsingTests {
    private func coverageOrderScene(unknown: Bool) throws -> (RecoveryRasterGrid, [PDFRule]) {
        let size = 64
        var pixels = [UInt8](repeating: 255, count: size * size)
        for coordinate in 8...55 {
            pixels[8 * size + coordinate] = 0
            pixels[55 * size + coordinate] = 0
            pixels[coordinate * size + 8] = 0
            pixels[coordinate * size + 55] = 0
        }
        for y in 20..<28 { for x in 20..<28 { pixels[y * size + x] = 0 } }
        if unknown { pixels[7 * size + 32] = 254 }  // Faint ink beside a rail is not a continuous rail.
        let rules = [
            PDFRule(x1: 8, y1: 8, x2: 55, y2: 8), PDFRule(x1: 8, y1: 55, x2: 55, y2: 55),
            PDFRule(x1: 8, y1: 8, x2: 8, y2: 55), PDFRule(x1: 55, y1: 8, x2: 55, y2: 55),
        ]
        return (
            try RecoveryRasterGrid(width: size, height: size, grayscale: pixels).preparingRules(rules), rules
        )
    }
    func testRasterCoverageMaskFirstKeepsUnionAndFractionalPixelSemantics() throws {
        for unknown in [false, true] {
            let (raster, rules) = try coverageOrderScene(unknown: unknown)
            let ink = RecoveryBox(x: 20, y: 20, width: 8, height: 8)
            let outside = RecoveryBox(x: 100, y: 100, width: 8, height: 8)
            for boxes in [[ink], [outside, ink], [ink, outside], [ink, ink], [outside]] {
                for query in [
                    RecoveryBox(x: 0, y: 0, width: 64, height: 64),
                    RecoveryBox(x: 0.25, y: 0.25, width: 63.5, height: 63.5),
                ] {
                    XCTAssertEqual(
                        try raster.hasUncoveredInk(query, text: boxes, rules: rules, check: {}),
                        unknown || !boxes.contains(ink))
                }
            }
        }
    }
    func testRasterCoveragePreparedMaskCannotHideInkWhenRulesChange() throws {
        let (raster, rules) = try coverageOrderScene(unknown: false)
        let query = RecoveryBox(x: 0, y: 0, width: 64, height: 64)
        let ink = RecoveryBox(x: 20, y: 20, width: 8, height: 8)
        XCTAssertFalse(
            try raster.hasUncoveredInk(query, text: [ink], rules: Array(rules.reversed()), check: {}))
        XCTAssertTrue(
            try raster.hasUncoveredInk(query, text: [ink], rules: Array(rules.dropFirst()), check: {}))
        XCTAssertTrue(try raster.hasUncoveredInk(query, text: [ink], rules: [], check: {}))
    }
    func testRasterCoverageRulePixelsDoNotSpendTheTextComparisonBudget() throws {
        let width = 640
        let height = 128
        var pixels = [UInt8](repeating: 255, count: width * height)
        for y in 0..<100 { for x in 0..<width { pixels[y * width + x] = 0 } }
        let rules = (0..<100).map { PDFRule(x1: 0, y1: Double($0), x2: 639, y2: Double($0)) }
        let raster = try RecoveryRasterGrid(width: width, height: height, grayscale: pixels).preparingRules(
            rules)
        let outside = RecoveryBox(x: 1000, y: 1000, width: 10, height: 10)
        let boxes = Array(repeating: outside, count: 548)
        XCTAssertFalse(
            try raster.hasUncoveredInk(
                RecoveryBox(x: 0, y: 0, width: 640, height: 128), text: boxes, rules: rules, check: {}))
        pixels[110 * width + 300] = 254
        let unknown = try RecoveryRasterGrid(width: width, height: height, grayscale: pixels).preparingRules(
            rules)
        XCTAssertTrue(
            try unknown.hasUncoveredInk(
                RecoveryBox(x: 0, y: 0, width: 640, height: 128), text: boxes, rules: rules, check: {}))
    }
    func testRasterCoverageMaskFirstStillBoundsUnmaskedTextSearch() {
        let size = 128
        let box = RecoveryBox(x: 0, y: 0, width: 128, height: 128)
        let raster = RecoveryRasterGrid(
            width: size, height: size, grayscale: [UInt8](repeating: 0, count: size * size))
        let outside = RecoveryBox(x: 200, y: 200, width: 10, height: 10)
        XCTAssertThrowsError(
            try raster.hasUncoveredInk(
                box, text: Array(repeating: outside, count: 2000) + [box], rules: [], check: {})
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .limit)
        }
    }
    func testRasterCoverageMaskFirstChecksCancellationOnCertifiedRailPixels() throws {
        let width = 640
        let height = 128
        let pixels = [UInt8](repeating: 0, count: width * height)
        let rules = (0..<height).map { PDFRule(x1: 0, y1: Double($0), x2: 639, y2: Double($0)) }
        let raster = try RecoveryRasterGrid(width: width, height: height, grayscale: pixels).preparingRules(
            rules)
        var checks = 0
        XCTAssertThrowsError(
            try raster.hasUncoveredInk(
                RecoveryBox(x: 0, y: 0, width: 640, height: 128), text: [], rules: rules,
                check: {
                    checks += 1
                    if checks == 3 { throw PDFParseError(code: .cancelled) }
                })
        ) { XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled) }
        XCTAssertEqual(checks, 3)
    }
}
