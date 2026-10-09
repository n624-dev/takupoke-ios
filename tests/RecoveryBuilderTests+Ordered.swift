import Foundation
import XCTest
#if canImport(CryptoKit)
    import CryptoKit
#elseif canImport(Crypto)
    import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    private func orderedNormalTimetablePages() -> [PDFPageLayout] {
        // Independent fictional positional timetable: five separately ruled days,
        // all 17 printed classes, eight unmerged periods and three unlabelled rows.
        let classes = Array(RecoveryValidator.specialClasses.reversed())
        return (1...5).map { day in
            var glyphs = [PDFGlyph]()
            var rules = [PDFRule]()
            var order = 0
            func put(_ text: String, _ x: Double, _ y: Double, _ line: Int) {
                for (offset, character) in text.enumerated() {
                    glyphs.append(
                        PDFGlyph(
                            text: String(character), x: x + Double(offset) * 5, y: y, width: 5, height: 9,
                            sourceLine: line, sourceOrder: order))
                    order += 1
                }
            }
            put("2027年度 前期", 10, 10, 0)
            put(["月", "火", "水", "木", "金"][day - 1], 500, 40, 1)
            rules += [
                PDFRule(x1: 100, y1: 35, x2: 980, y2: 35), PDFRule(x1: 100, y1: 35, x2: 100, y2: 60),
                PDFRule(x1: 980, y1: 35, x2: 980, y2: 60),
            ]
            for y in [60.0, 90.0] + (1...17).map({ 90 + Double($0) * 90 }) {
                rules.append(PDFRule(x1: 0, y1: y, x2: 980, y2: y))
            }
            rules.append(PDFRule(x1: 0, y1: 60, x2: 0, y2: 1620))
            for column in 0...8 {
                let x = 100 + Double(column) * 110
                rules.append(PDFRule(x1: x, y1: 60, x2: x, y2: 1620))
            }
            for period in 1...8 { put(String(period), 100 + Double(period - 1) * 110 + 52, 68, 2) }
            for (row, cls) in classes.enumerated() {
                let top = 90 + Double(row) * 90
                put(cls, 12, top + 40, 10 + row * 4)
                for period in 1...8 {
                    let x = 106 + Double(period - 1) * 110
                    put("架空検証甲\(day)\(row)\(period)", x, top + 12, 11 + row * 4)
                    put("架空担当乙\(day)\(row)\(period)", x, top + 38, 12 + row * 4)
                    put("仮室検証丙\(day)\(row)\(period)", x, top + 64, 13 + row * 4)
                }
            }
            return PDFPageLayout(width: 980, height: 1620, glyphs: glyphs, lines: rules)
        }
    }
    func testOrderedNormalTimetableKeepsAll680UnlabelledTuplesAndFormalProjection() async throws {
        let hash = String(repeating: "b", count: 64)
        let doc = try RecoveryDocumentBuilder.build(
            orderedNormalTimetablePages(), kind: .timetable, hash: hash)
        XCTAssertEqual(doc.cells.count, 680)
        XCTAssertEqual(doc.requiredSlots.count, 680)
        XCTAssertTrue(doc.cells.allSatisfy { $0.orderedRowProof?.sourceIds.count == 3 })
        XCTAssertEqual(RecoveryValidator.inputErrors(doc), [])
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
        XCTAssertEqual(run.state, .awaitingConfirmation, run.errors.joined(separator: ","))
        let result = try XCTUnwrap(run.result)
        XCTAssertTrue(RecoveryValidator.validate(doc, result).canAdopt)
        let period = SchoolDataPeriod(day: SchoolDate(iso8601: "2027-04-01")!)
        let source = RecoverySelectedSource(
            kind: .timetable, url: URL(fileURLWithPath: "/fictional-positional.pdf"), digest: hash,
            originalName: "fictional-positional.pdf", storedName: "fictional-positional.pdf", period: period)
        let formal = try RecoveryConversion.timetable(
            RecoveryPreview(document: doc, result: result, source: source))
        XCTAssertEqual(formal.lessons.count, 680)
        let classes = Array(RecoveryValidator.specialClasses.reversed())
        for lesson in formal.lessons {
            let row = try XCTUnwrap(classes.firstIndex(of: lesson.className))
            let suffix = "\(lesson.weekday)\(row)\(lesson.period)"
            XCTAssertEqual(lesson.names.subject, "架空検証甲" + suffix)
            XCTAssertEqual(lesson.names.teacher, "架空担当乙" + suffix)
            XCTAssertEqual(lesson.names.room, "仮室検証丙" + suffix)
        }
    }
    func testOrderedNormalTimetableCannotGuessMissingRowsOrAcceptPluralAndPartialLabels() throws {
        let original = orderedNormalTimetablePages()
        let hash = String(repeating: "b", count: 64)
        var missing = original
        missing[0].glyphs.removeAll { $0.sourceLine == 12 && $0.x > 100 && $0.x < 210 }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(missing, kind: .timetable, hash: hash))
        var plural = original
        let index = plural[0].glyphs.firstIndex { $0.sourceLine == 11 && $0.x == 106 }!
        plural[0].glyphs[index].text = "・"
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(plural, kind: .timetable, hash: hash))
        var overlap = original
        for i in overlap[0].glyphs.indices
        where overlap[0].glyphs[i].sourceLine == 12 && overlap[0].glyphs[i].x > 100
            && overlap[0].glyphs[i].x < 210
        { overlap[0].glyphs[i].y = 102 }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(overlap, kind: .timetable, hash: hash))
        var partialLabel = original
        for (offset, char) in "科目：".enumerated() {
            partialLabel[0].glyphs[index + offset].text = String(char)
        }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(partialLabel, kind: .timetable, hash: hash))
        XCTAssertThrowsError(
            try RecoveryDocumentBuilder.build(Array(original.dropLast()), kind: .timetable, hash: hash))
        var missingClass = original
        for n in missingClass.indices {
            missingClass[n].glyphs.removeAll { $0.sourceLine == 10 && $0.x < 100 }
        }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(missingClass, kind: .timetable, hash: hash))
    }
    func testOrderedRowValidatorRejectsSimultaneouslySwappedBindingsAndResult() async throws {
        var doc = try RecoveryDocumentBuilder.build(
            orderedNormalTimetablePages(), kind: .timetable, hash: String(repeating: "b", count: 64))
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
        var result = try XCTUnwrap(run.result)
        let subject = doc.cells[0].lessonBindings[0].subject
        let teacher = doc.cells[0].lessonBindings[0].teacher
        doc.cells[0].lessonBindings[0].subject = teacher
        doc.cells[0].lessonBindings[0].teacher = subject
        let swappedSourceIds = teacher + subject + doc.cells[0].lessonBindings[0].room
        doc.cells[0].sourceIds = swappedSourceIds
        doc.cells[0].orderedRowProof?.sourceIds = swappedSourceIds
        let position = try XCTUnwrap(result.cells.firstIndex { $0.cellId == doc.cells[0].id })
        let original = result.cells[position].lessons[0].subject
        result.cells[position].lessons[0].subject = result.cells[position].lessons[0].teacher
        result.cells[position].lessons[0].teacher = original
        XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.contains("orderedRowEvidence"))
    }
    func testOrderedNormalRowsRejectOpaqueAtomsMissingMetadataAndTwoHorizontalGroups() throws {
        let original = orderedNormalTimetablePages()
        let hash = String(repeating: "b", count: 64)
        var opaque = original
        let row = opaque[0].glyphs.filter { $0.sourceLine == 11 && $0.x > 100 && $0.x < 210 }
        opaque[0].glyphs.removeAll { $0.sourceLine == 11 && $0.x > 100 && $0.x < 210 }
        var atom = row[0]
        atom.text = row.map(\.text).joined()
        atom.width = Double(row.count) * 5
        atom.ocrLineAtom = true
        opaque[0].glyphs.append(atom)
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(opaque, kind: .timetable, hash: hash))
        var noMetadata = original
        for i in noMetadata[0].glyphs.indices {
            noMetadata[0].glyphs[i].sourceLine = nil
            noMetadata[0].glyphs[i].sourceOrder = nil
        }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(noMetadata, kind: .timetable, hash: hash))
        var split = original
        for i in split[0].glyphs.indices
        where (11...13).contains(split[0].glyphs[i].sourceLine ?? -1) && split[0].glyphs[i].x >= 126
            && split[0].glyphs[i].x < 210
        { split[0].glyphs[i].x += 20 }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(split, kind: .timetable, hash: hash))
        let pieces = [
            RecoveryOrderedRowPiece(
                text: "架", box: RecoveryBox(x: 0, y: 0, width: 5, height: 9), sourceLine: 1, sourceOrder: 1),
            RecoveryOrderedRowPiece(
                text: " ", box: RecoveryBox(x: 5, y: 0, width: 5, height: 9), sourceLine: 1, sourceOrder: 2),
            RecoveryOrderedRowPiece(
                text: "空", box: RecoveryBox(x: 10, y: 0, width: 5, height: 9), sourceLine: 1, sourceOrder: 3),
        ]
        XCTAssertTrue(RecoveryOrderedRowProof.singleRow(pieces))
        var wideSpace = pieces
        wideSpace[1].box.width = 40
        wideSpace[2].box.x = 45
        XCTAssertFalse(RecoveryOrderedRowProof.singleRow(wideSpace))
    }
    func testOrderedProofDropCannotHideVerticalRoleSwapAndOversizedProofRefuses() async throws {
        var doc = try RecoveryDocumentBuilder.build(
            orderedNormalTimetablePages(), kind: .timetable, hash: String(repeating: "b", count: 64))
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
        let result = try XCTUnwrap(run.result)
        let source = doc.cells[0].lessonBindings[0].subject
        let teacher = doc.cells[0].lessonBindings[0].teacher
        doc.cells[0].orderedRowProof = nil
        doc.cells[0].lessonBindings[0].subject = teacher
        doc.cells[0].lessonBindings[0].teacher = source
        XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.contains("orderedRowEvidence"))
        doc = try RecoveryDocumentBuilder.build(
            orderedNormalTimetablePages(), kind: .timetable, hash: String(repeating: "b", count: 64))
        let piece = try XCTUnwrap(doc.cells[0].orderedRowProof?.rows[0].first)
        doc.cells[0].orderedRowProof?.rows[0] = Array(repeating: piece, count: 257)
        XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.contains("validationLimit"))
    }
    func testNewOrderedProofCannotBeBackdatedAndRoundTripsItsOriginalGeometry() async throws {
        var doc = try RecoveryDocumentBuilder.build(
            orderedNormalTimetablePages(), kind: .timetable, hash: String(repeating: "b", count: 64))
        let data = try JSONEncoder().encode(doc)
        XCTAssertTrue(
            try JSONDecoder().decode(RecoveryDocument.self, from: data) == doc,
            "Recovery document lost original ordered-row evidence while decoding")
        let run = try await RecoveryEngine.run(
            doc, os: "ios", osMajor: 27, foreground: true, providers: [], rule: { _ in nil }, check: {})
        var result = try XCTUnwrap(run.result)
        result.metadata.validatorVersion = 7
        doc.structureMetadata?.validatorVersion = 7
        let receipt = RecoveryAcceptance(
            pdfHash: doc.pdfHash, resultHash: try RecoveryValidator.fingerprint(result),
            scopeHash: try RecoveryValidator.fingerprint(doc), metadata: result.metadata,
            acceptedAt: Date(timeIntervalSince1970: 1_770_000_000))
        XCTAssertNil(
            try RecoveryValidator.recertify(
                RecoveryAdopted(document: doc, result: result, acceptance: receipt), hash: doc.pdfHash))
    }
}
