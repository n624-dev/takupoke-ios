import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    private func genericRuledOriginals() throws -> [(
        record: [String: Any], pages: [PDFPageLayout], rasters: [Int: RecoveryRasterGrid]
    )] {
        let url = Bundle.module.url(
            forResource: "recovery-generic-ruled-original-two", withExtension: "json",
            subdirectory: "fixtures")!
        let bytes = try Data(contentsOf: url)
        XCTAssertEqual(
            SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
            "7a87ca9355ee2577fb3fab05cfc9dc86ab5d870a8e49f2119b54ef70d260a54c")
        let root = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        return try (root["cases"] as! [[String: Any]]).map { record in
            var pages = [PDFPageLayout]()
            var rasters = [Int: RecoveryRasterGrid]()
            for p in record["pages"] as! [[String: Any]] {
                let n = p["page"] as! Int
                let w = p["width"] as! Int
                let h = p["height"] as! Int
                let encoded = Array(Data(base64Encoded: p["rgbaRunsBase64"] as! String)!)
                let limit = w * h * 4
                guard (1...2048).contains(w), (1...2048).contains(h), encoded.count % 8 == 0 else {
                    throw PDFParseError(code: .limit)
                }
                var rgba = [UInt8]()
                rgba.reserveCapacity(limit)
                for i in stride(from: 0, to: encoded.count, by: 8) {
                    let count = (0..<4).reduce(0) { $0 | Int(encoded[i + $1]) << (8 * $1) }
                    guard count > 0, count <= (limit - rgba.count) / 4 else {
                        throw PDFParseError(code: .limit)
                    }
                    for _ in 0..<count { rgba.append(contentsOf: encoded[(i + 4)..<(i + 8)]) }
                }
                guard rgba.count == limit else { throw PDFParseError(code: .unreadable) }
                XCTAssertEqual(
                    SHA256.hash(data: Data(rgba)).map { String(format: "%02x", $0) }.joined(),
                    p["rgbaSHA256"] as? String)
                let raster = try RecoveryRasterGrid.fromRGBA(width: w, height: h, pixels: rgba)
                let rules = try raster.rules(check: {})
                let glyphs = (p["textsAndInk"] as! [[String: Any]]).enumerated().map { i, t -> PDFGlyph in
                    let b = (t["bbox"] as! [NSNumber]).map(\.doubleValue)
                    return PDFGlyph(
                        text: t["text"] as! String, x: b[0], y: b[1], width: b[2] - b[0], height: b[3] - b[1],
                        sourceLine: (t["y"] as! NSNumber).intValue, sourceOrder: i)
                }
                pages.append(PDFPageLayout(width: Double(w), height: Double(h), glyphs: glyphs, lines: rules))
                rasters[n] = raster
            }
            return (record, pages, rasters)
        }
    }
    func testGenericRuledRecoveryPreservesOriginalTwoFortySlotFormalOracles() async throws {
        for original in try genericRuledOriginals() {
            let digest = original.record["originalPDFSHA256"] as! String
            let doc = try RecoveryDocumentBuilder.build(
                original.pages, kind: .timetable, hash: digest, fromOCR: Set(original.rasters.keys),
                rasters: original.rasters)
            XCTAssertEqual(doc.requiredSlots.count, 40)
            XCTAssertTrue(RecoveryValidator.inputErrors(doc).isEmpty)
            let run = try await RecoveryEngine.run(
                doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
            XCTAssertEqual(run.state, .awaitingConfirmation, run.errors.joined(separator: ","))
            let result = try XCTUnwrap(run.result)
            XCTAssertEqual(result.metadata.provider, "rule")
            XCTAssertTrue(RecoveryValidator.validate(doc, result).canAdopt)
            let period = SchoolDataPeriod(
                day: SchoolDate(iso8601: "\(doc.schoolYear)-\(doc.term == "前期" ? "04" : "10")-01")!)
            let source = RecoverySelectedSource(
                kind: .timetable, url: URL(fileURLWithPath: "/fictional.pdf"), digest: digest,
                originalName: "fictional.pdf", storedName: "fictional.pdf", period: period)
            let formal = try RecoveryConversion.timetable(
                RecoveryPreview(document: doc, result: result, source: source))
            // Independent literal oracle is used only after production conversion.
            let oracle = original.record["oracle"] as! [String: Any]
            let table = oracle["timetable"] as! [String: Any]
            XCTAssertEqual(formal.schoolYear, oracle["schoolYear"] as? Int)
            XCTAssertEqual(formal.term, table["term"] as? String)
            let actual = formal.lessons.map {
                [
                    "className": $0.className, "weekday": $0.weekday, "period": $0.period,
                    "names": [
                        "subject": $0.names.subject, "teacher": $0.names.teacher, "room": $0.names.room,
                    ],
                ] as [String: Any]
            }
            XCTAssertTrue(
                NSDictionary(dictionary: ["lessons": actual]).isEqual(to: ["lessons": table["lessons"]!]))
            let expectedSlots = oracle["requiredSlotSet"] as! [[String: Any]]
            XCTAssertEqual(
                Set(doc.requiredSlots.map { "\($0.className):\($0.day):\($0.period)" }),
                Set(expectedSlots.map { "\($0["className"]!):\($0["day"]!):\($0["period"]!)" }))
        }
    }
    func testGenericRuledRecoveryRejectsIncompleteDaysDuplicateSlotsAndConflictingHeadings() throws {
        let original = try genericRuledOriginals()[0]
        func rejects(_ pages: [PDFPageLayout], _ reason: String, rasters: [Int: RecoveryRasterGrid]? = nil) {
            let pixels = rasters ?? original.rasters
            XCTAssertThrowsError(
                try RecoveryDocumentBuilder.build(
                    pages, kind: .timetable, hash: String(repeating: "a", count: 64),
                    fromOCR: Set(pixels.keys), rasters: pixels), reason)
        }
        rejects(Array(original.pages.dropLast()), "missing weekday")
        var duplicate = original.pages
        duplicate[4] = duplicate[0]
        rejects(duplicate, "duplicate slots")
        var conflicting = original.pages
        let yearIndex = conflicting[1].glyphs.firstIndex { $0.text == "7" && $0.y < 30 }!
        conflicting[1].glyphs[yearIndex].text = "8"
        rejects(conflicting, "conflicting years")
        var missingPeriod = original.pages
        missingPeriod[0].glyphs.removeAll { $0.text == "8" && $0.y > 60 && $0.y < 90 }
        rejects(missingPeriod, "missing period")
        var brokenEdge = original.pages
        let period = brokenEdge[0].glyphs.first { $0.text == "1" && $0.y > 60 && $0.y < 90 }!
        let header = try PDFGrid(page: brokenEdge[0]).box(period.cx, period.cy, check: {})
        brokenEdge[0].lines.removeAll { $0.vertical && abs($0.x1 - header.right) < 0.3 }
        rejects(brokenEdge, "missing physical edge")
    }
    func testGenericRuledRecoveryRejectsNeighbourBodyUnrecognizedInkAndUnprovedBlank() throws {
        let original = try genericRuledOriginals()[1]
        func rejects(_ pages: [PDFPageLayout], _ rasters: [Int: RecoveryRasterGrid]) {
            XCTAssertThrowsError(
                try RecoveryDocumentBuilder.build(
                    pages, kind: .timetable, hash: String(repeating: "a", count: 64),
                    fromOCR: Set(rasters.keys), rasters: rasters))
        }
        var crossing = original.pages
        let bodyIndex = crossing[0].glyphs.firstIndex { $0.text == "架" && $0.y > 90 }!
        crossing[0].glyphs[bodyIndex].width = 100
        rejects(crossing, original.rasters)
        var unknownInk = original.rasters
        var raster = unknownInk[1]!
        raster = RecoveryRasterGrid(width: raster.width, height: raster.height, grayscale: raster.grayscale)
        var pixels = raster.grayscale
        pixels[190 * raster.width + 500] = 0
        unknownInk[1] = RecoveryRasterGrid(width: raster.width, height: raster.height, grayscale: pixels)
        rejects(original.pages, unknownInk)
        var blankInk = original.rasters
        pixels = raster.grayscale
        pixels[130 * raster.width + 160] = 0
        blankInk[1] = RecoveryRasterGrid(width: raster.width, height: raster.height, grayscale: pixels)
        rejects(original.pages, blankInk)
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                original.pages, kind: .timetable, hash: String(repeating: "a", count: 64),
                fromOCR: Set(original.rasters.keys), rasters: [:]))
    }
    func testGenericRuledRecoveryCancellationRemainsTerminal() throws {
        let original = try genericRuledOriginals()[0]
        var checks = 0
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                original.pages, kind: .timetable, hash: String(repeating: "a", count: 64),
                fromOCR: Set(original.rasters.keys), rasters: original.rasters,
                check: {
                    checks += 1
                    if checks == 30 { throw PDFParseError(code: .cancelled) }
                })
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .cancelled)
        }
        XCTAssertEqual(checks, 30)
    }
    func testGenericRuledRecoveryKeepsOriginalTopologyWorkLimit() throws {
        var original = try genericRuledOriginals()[0]
        let rules = original.pages[0].lines
        original.pages[0].lines = (0..<1_100_000).map { rules[$0 % rules.count] }
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                original.pages, kind: .timetable, hash: String(repeating: "a", count: 64))
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.code, .limit)
        }
    }
    func testGenericRuledRecoveryCannotDiscardAnUnknownPhysicalClassRow() throws {
        var pages = try genericRuledOriginals()[0].pages
        // A separate negative source control, leaving the original fixture intact:
        // divide a blank day's class/table band into one known and one unknown row.
        let old = pages[1]
        let period = old.glyphs.first { $0.text == "8" && $0.y > 60 && $0.y < 90 }!
        let right = try PDFGrid(page: old).box(period.cx, period.cy, check: {}).right
        pages[1].lines.append(PDFRule(x1: 0, y1: 128, x2: right, y2: 128))
        for i in pages[1].glyphs.indices where pages[1].glyphs[i].x < 90 && pages[1].glyphs[i].y > 90 {
            pages[1].glyphs[i].y -= 23
        }
        let originalClass = old.glyphs.filter { $0.x < 90 && $0.y > 90 }
        pages[1].glyphs += originalClass.enumerated().map { i, g in
            var next = g
            next.text = ["9", "_", "Z", "Z"][i]
            next.y += 20
            next.sourceOrder = 1000 + i
            next.sourceLine = 1000
            return next
        }
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(
                pages, kind: .timetable, hash: String(repeating: "a", count: 64))
        ) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, .classLabel)
        }
    }
}
