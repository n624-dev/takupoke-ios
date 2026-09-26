import Foundation
import XCTest
import ZIPFoundation
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText
#endif

extension PDFParsingTests {
    func testTimetableFailureReportsLocationAndLineCountWithoutNames() throws {
        var page = timetable()
        page.glyphs += text("架空追加行", x: 104, y: 154)
        try XCTAssertThrowsError(try parse([page], kind: .timetable)) { error in
            guard let failure = error as? PDFParseError else { return XCTFail("Unexpected error type") }
            XCTAssertEqual(failure.stage, .lessonLines)
            XCTAssertEqual(failure.cell, PDFParseError.Cell(classRow: 1, weekday: 1, period: 1, detectedLines: 4))
            XCTAssertTrue(failure.localizedDescription.contains("検出4行"))
            XCTAssertFalse(failure.localizedDescription.contains("架空"))
            let encoded = try? JSONEncoder().encode(failure)
            let decoded = encoded.flatMap { try? JSONDecoder().decode(PDFParseError.self, from: $0) }
            XCTAssertEqual(decoded, failure)
        }
    }
    func testTimetableGeometryReportReproducesFailureWithoutSourceText() throws {
        var page = timetable()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        page.glyphs += [
            PDFGlyph(text: "架空秘密科目", x: 108, y: 110, width: 8, height: 6, sourceLine: 800, sourceOrder: 9000),
            PDFGlyph(text: "架空秘密教員", x: 111, y: 110, width: 2, height: 6, sourceLine: 801, sourceOrder: 9010)
        ]
        var captured: PDFParseError?
        XCTAssertThrowsError(try parse([page], kind: .timetable)) { captured = $0 as? PDFParseError }
        let failure = try XCTUnwrap(captured)
        XCTAssertEqual(failure.stage, .fragmentOverlap)
        XCTAssertEqual(failure.page, 1)
        XCTAssertEqual(failure.cell?.classRow, 1)
        let geometry = try XCTUnwrap(failure.geometry)
        XCTAssertEqual(geometry.width, 40)
        XCTAssertEqual(geometry.height, 60)
        XCTAssertEqual(geometry.glyphs.map(\.line), [0, 1])
        XCTAssertEqual(geometry.glyphs.map(\.order), [0, 1])
        let report = try XCTUnwrap(failure.diagnosticReport)
        XCTAssertTrue(report.hasPrefix("TAKUPOKE-PDF-GEOMETRY-1\n"))
        for excluded in ["架空", "秘密", "synthetic.pdf", "synthetic-digest", "9000", "9010"] {
            XCTAssertFalse(report.contains(excluded))
        }
        let data = Data(report.split(separator: "\n", maxSplits: 1)[1].utf8)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["code", "page", "stage", "cell", "geometry"])
        let geometryJSON = try XCTUnwrap(json["geometry"] as? [String: Any])
        XCTAssertEqual(Set(geometryJSON.keys), ["parserVersion", "width", "height", "totalGlyphs", "glyphs"])
        let glyphJSON = try XCTUnwrap(geometryJSON["glyphs"] as? [[String: Any]])
        XCTAssertTrue(glyphJSON.allSatisfy { Set($0.keys) == ["line", "order", "x", "y", "width", "height"] })
        let restored = try JSONDecoder().decode(PDFParseError.self, from: data)
        XCTAssertEqual(restored, failure)

        // Reproduce the position/order check using placeholders only.
        let glyphs = geometry.glyphs.map {
            PDFGlyph(text: "□", x: $0.x, y: $0.y, width: $0.width, height: $0.height, sourceLine: $0.line, sourceOrder: $0.order)
        }
        let grid = PDFGrid(page: PDFPageLayout(width: geometry.width, height: geometry.height, glyphs: glyphs, lines: []))
        XCTAssertThrowsError(try grid.timetableText(PDFBox(left: 0, top: 0, right: geometry.width, bottom: geometry.height))) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage, failure.stage)
        }
    }
    func testGeometryDiagnosticHasBoundedSize() throws {
        let glyphs = (0..<300).map {
            PDFGlyph(text: "架空文字", x: Double($0), y: 10, width: 2, height: 5, sourceLine: 50, sourceOrder: 1000 + $0)
        }
        let snapshot = PDFCellGeometryDiagnostic(glyphs, box: PDFBox(left: 0, top: 0, right: 700, bottom: 40))
        XCTAssertEqual(snapshot.totalGlyphs, 300)
        XCTAssertEqual(snapshot.glyphs.count, PDFCellGeometryDiagnostic.maximumGlyphs)
        XCTAssertEqual(snapshot.glyphs.last?.order, 255)
        XCTAssertLessThan(try JSONEncoder().encode(snapshot).count, 40_000)
    }
    func testTraceCoversP01AndAllFailureStagesWithInvalidRectangles() throws {
        let recorder = PDFDiagnosticRecorder()
        recorder.record(.start)
        recorder.record(.selection, page: 1, index: 2, length: 1, values: [1, 1],
                        bounds: CGRect(x: 10, y: 20, width: 5, height: 7))
        var captured: Error?
        XCTAssertThrowsError(try PDFCharacterGeometry.bounds(for: NSRange(location: 2, length: 1), count: 4) { index in
            recorder.record(.characterBounds, page: 1, index: index, bounds: .null)
            return .null
        }) { captured = $0 }
        let failure = recorder.attaching(to: try XCTUnwrap(captured))
        XCTAssertEqual(failure.stage, .characterMapping)
        XCTAssertEqual(failure.trace?.entries.last?.step, .failure)
        XCTAssertEqual(failure.trace?.entries.first { $0.step == .characterBounds }?.bounds?.state, .null)
        let copied = try XCTUnwrap(failure.diagnosticReport)
        XCTAssertTrue(copied.hasPrefix("TAKUPOKE-PDF-TRACE-1\n"))
        let restored = try JSONDecoder().decode(PDFParseError.self,
            from: Data(copied.split(separator: "\n", maxSplits: 1)[1].utf8))
        XCTAssertEqual(restored, failure)
        for stage in PDFParseError.Stage.allCases {
            XCTAssertNotNil(PDFDiagnosticRecorder().attaching(to: PDFParseError(code: .unsupported, stage: stage)).diagnosticReport)
        }
        for code in [PDFParseError.Code.unreadable, .limit, .cancelled, .storage] {
            XCTAssertNotNil(PDFDiagnosticRecorder().attaching(to: PDFParseError(code: code)).diagnosticReport)
        }
    }
    func testTraceLimitsKeepStartupAndFinalFailureAndEncodeInvalidNumbers() throws {
        let recorder = PDFDiagnosticRecorder(limit: 8)
        for i in 0..<20 { recorder.record(.characterBounds, index: i, values: [.nan], bounds: .infinite) }
        let failure = recorder.attaching(to: PDFParseError(code: .storage))
        let trace = try XCTUnwrap(failure.trace)
        XCTAssertEqual(trace.totalEntries, 21)
        XCTAssertEqual(trace.omittedEntries, 13)
        XCTAssertEqual(trace.entries.map(\.sequence), [0, 1, 2, 3, 17, 18, 19, 20])
        XCTAssertEqual(trace.entries.last?.code, .storage)
        XCTAssertEqual(trace.entries.first?.bounds?.state, .infinite)
        XCTAssertNil(trace.entries.first?.values.first ?? nil)
        XCTAssertNotNil(failure.diagnosticReport)
    }
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
    func testFullDiagnosticCopyPreservesAllTextAndGeometryLosslessly() throws {
        var full = PDFFullReadDiagnostic()
        var page = PDFFullReadDiagnostic.Page(number: 1)
        page.text = "架空科目V\n架空教員W\n架空室X"
        page.characters = [
            .init(range: .init(NSRange(location: 0, length: 1)), text: "架", whitespace: false,
                selectionText: "架", selectionBounds: .init(CGRect(x: 8, y: 10, width: 70, height: 7)), characterBounds: [.init(.null)]),
            .init(range: .init(NSRange(location: 1, length: 1)), text: "空", whitespace: false,
                selectionText: "空", selectionBounds: .init(CGRect(x: 15, y: 10, width: 7, height: 7)),
                characterBounds: [.init(CGRect(x: 15, y: 10, width: 7, height: 7))])
        ]
        full.pages = [page]
        full.attemptFailure = PDFParseError(code: .unsupported, page: 1, stage: .characterMapping)
        let report = try PDFFullDiagnosticEncoding.report(full)
        XCTAssertTrue(report.hasPrefix("TAKUPOKE-PDF-FULL-ZIP-1\n"))
        let encoded = String(report.split(separator: "\n", maxSplits: 1)[1])
        let data = try XCTUnwrap(Data(base64Encoded: encoded, options: .ignoreUnknownCharacters))
        let archive = try Archive(data: data, accessMode: .read)
        XCTAssertEqual(archive.map(\.path), ["diagnostic.json"])
        let entry = try XCTUnwrap(archive["diagnostic.json"])
        var decoded = Data()
        _ = try archive.extract(entry) { decoded.append($0) }
        XCTAssertEqual(decoded, try full.jsonData())
        let restored = try JSONDecoder().decode(PDFFullReadDiagnostic.self, from: decoded)
        XCTAssertEqual(restored.pages[0].text, page.text)
        XCTAssertEqual(restored.pages[0].characters.map(\.text), ["架", "空"])
        XCTAssertEqual(restored.pages[0].characters[0].characterBounds[0]?.state, .null)
        XCTAssertEqual(restored.attemptFailure?.stage, .characterMapping)
    }
#endif
    func testFailureStagesSurvivePageWrappingAndContainNoSourceText() throws {
        func assertFailure(_ pages: [PDFPageLayout], kind: MaterialKind, page: Int,
                           stage: PDFParseError.Stage, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertThrowsError(try parse(pages, kind: kind), file: file, line: line) { error in
                guard let failure = error as? PDFParseError else { return XCTFail("Unexpected error type", file: file, line: line) }
                XCTAssertEqual(failure.page, page, file: file, line: line)
                XCTAssertEqual(failure.stage, stage, file: file, line: line)
                XCTAssertTrue(failure.localizedDescription.contains(stage.label), file: file, line: line)
                XCTAssertFalse(failure.localizedDescription.contains("架空"), file: file, line: line)
            }
        }
        var missingYear = timetable()
        missingYear.glyphs.removeAll { $0.cy == 20 }
        assertFailure([missingYear], kind: .timetable, page: 1, stage: .yearHeading)
        var missingPeriod = timetable()
        missingPeriod.glyphs.removeAll { $0.cy == 70 }
        assertFailure([missingPeriod], kind: .timetable, page: 1, stage: .periodHeading)
        var missingGrid = timetable()
        missingGrid.lines = []
        assertFailure([missingGrid], kind: .timetable, page: 1, stage: .gridCell)
        var missingColumns = calendar([10, 11, 12, 1, 2, 3])
        missingColumns.glyphs.removeAll { $0.text == "詫" }
        assertFailure([calendar(Array(4...9)), missingColumns], kind: .events, page: 2, stage: .eventColumns)
        var missingDates = calendar([10, 11, 12, 1, 2, 3])
        missingDates.glyphs.removeAll { $0.cy > 70 && $0.x < 30 }
        assertFailure([calendar(Array(4...9)), missingDates], kind: .events, page: 2, stage: .calendarDates)
    }
    func testOldFailureDecodesAndNewFailureRetainsOnlyFixedDiagnostic() throws {
        let old = try JSONDecoder().decode(PDFParseError.self, from: Data(#"{"code":"unsupported","page":1}"#.utf8))
        XCTAssertNil(old.stage)
        XCTAssertNil(old.geometry)
        XCTAssertNil(old.trace)
        XCTAssertNil(old.diagnosticReport)
        for stage in PDFParseError.Stage.allCases {
            let failure = PDFParseError(code: .unsupported, page: 2, stage: stage)
            XCTAssertEqual(try JSONDecoder().decode(PDFParseError.self, from: JSONEncoder().encode(failure)), failure)
            XCTAssertTrue(failure.localizedDescription.contains("前回の正常な解析結果は保持しています"))
        }
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
        var old = good
        old.version = 1
        try library.savePDFAnalysis(old)
        let legacy = try MaterialLibrary(root: root)
        XCTAssertEqual(legacy.state.pdfAnalyses?["timetable"]?.version, 1)
        XCTAssertEqual(legacy.state.pdfAnalyses?["timetable"]?.lessons, old.lessons)
        try acquire("replacement")
        let failure = PDFDiagnosticRecorder().attaching(to: PDFParseError(code: .ambiguous, page: 1, stage: .fragmentOverlap,
            cell: PDFParseError.Cell(classRow: 1, weekday: 2, period: 3),
            geometry: PDFCellGeometryDiagnostic([
                PDFGlyph(text: "架空秘密", x: 10, y: 10, width: 5, height: 6, sourceLine: 5, sourceOrder: 20)
            ], box: PDFBox(left: 0, top: 0, right: 40, bottom: 60))))
        try library.recordPDFFailure(failure, kind: .timetable)
        XCTAssertEqual(try MaterialLibrary(root: root).state.pdfParseAttempts?["timetable"]?.failure, failure)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        let manifest = root.appendingPathComponent("library.json")
        let before = try Data(contentsOf: manifest)
        var next = good; next.sourceDigest = "replacement"
        reject = true
        XCTAssertThrowsError(try library.savePDFAnalysis(next))
        XCTAssertEqual(try Data(contentsOf: manifest), before)
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.sourceDigest, "synthetic-digest")
        XCTAssertEqual(library.state.pdfAnalyses?["timetable"]?.version, 1)
        reject = false
        try library.savePDFAnalysis(next)
        let reopened = try MaterialLibrary(root: root)
        XCTAssertEqual(reopened.state.pdfAnalyses?["timetable"]?.sourceDigest, "replacement")
        XCTAssertEqual(reopened.state.pdfAnalyses?["timetable"]?.version, PDFAnalysis.parserVersion)
        XCTAssertNil(reopened.state.pdfParseAttempts?["timetable"]?.failure)
    }
}
