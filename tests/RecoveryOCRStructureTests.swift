import Foundation
import XCTest
#if canImport(TakupokeParsing)
@testable import TakupokeParsing
#endif

final class RecoveryOCRStructureTests: XCTestCase {
    private let region = [RecoveryOCRNativePoint(x: 0.1, y: 0.1), .init(x: 0.8, y: 0.1),
                          .init(x: 0.8, y: 0.8), .init(x: 0.1, y: 0.8)]
    private func line(_ text: String = "架空科目A", order: Int = 0, confidence: Double = 1,
                      x: Double = 10) -> RecoveryOCRLine {
        .init(nativeOrder: order, candidates: [.init(text: text, confidence: confidence,
            characters: text.enumerated().map { .init(text: String($0.element),
                range: .init(x: x + Double($0.offset) * 5, y: 10, width: 5, height: 10)) })])
    }
    private func cell(_ lines: [RecoveryOCRLine], row: Int = 0, upper: Int? = nil,
                      column: Int = 0, nested: Int = 0) -> RecoveryOCRNativeCell {
        .init(rowLower: row, rowUpper: upper ?? row, columnLower: column, columnUpper: column,
              contentRegion: lines.isEmpty ? [] : region, transcript: lines.map { $0.candidates[0].text }.joined(separator: "\n"),
              lines: lines, nestedTableCount: nested)
    }
    private func page(_ lines: [RecoveryOCRLine], rows: [[RecoveryOCRNativeCell]],
                      columns: [[RecoveryOCRNativeCell]]? = nil) -> RecoveryOCRPage {
        .init(page: 1, width: 100, height: 100, nativeDocumentCount: 1, lines: lines, captureComplete: true,
            structure: .init(documents: [.init(nativeOrder: 0, nativeUUID: "00000000-0000-0000-0000-000000000001",
                lineOrders: Array(lines.indices), tables: [.init(nativeOrder: 0, region: region,
                    rows: rows, columns: columns ?? rows)])]))
    }
    private func draft(_ page: RecoveryOCRPage) -> RecoveryOCRAcquisitionDraft {
        .init(sourcePDFHash: String(repeating: "a", count: 64), documentPageCount: 1, requiredOCRPages: [1], pages: [page])
    }
    private func links(_ page: RecoveryOCRPage) throws -> [RecoveryOCRNativeCellLink] {
        var work = 0
        return try RecoveryOCRStructure.links(page.structure!, page: page, consume: {
            work += 1
            guard work <= 2_000_000 else { throw RecoveryOCRAcquisitionFailure.limit }
        })
    }
    func testMergedNativeCellRetainsBothAxesAndOriginalSourceLineOnce() throws {
        let nativeLine = line(), merged = cell([line()], upper: 1)
        let input = page([nativeLine], rows: [[merged], [merged]], columns: [[merged]])
        let value = try links(input)
        XCTAssertEqual(value.count, 1)
        XCTAssertEqual(value[0].rowLower, 0); XCTAssertEqual(value[0].rowUpper, 1)
        XCTAssertEqual(value[0].lineOrders, [0])
        XCTAssertEqual(input.lines, [nativeLine])
        XCTAssertEqual(input.structure!.documents[0].tables[0].rows.count, 2)
        XCTAssertTrue(try draft(input).assess().directLayoutsAllowed)
    }
    func testSameTextAtDifferentCoordinatesLinksExactPhysicalOccurrence() throws {
        let a = line(), b = line(order: 1, x: 45)
        let input = page([a, b], rows: [[cell([line()], column: 0), cell([line(x: 45)], column: 1)]])
        XCTAssertEqual(try links(input).map(\.lineOrders), [[0], [1]])
        XCTAssertEqual(input.lines.map(\.nativeOrder), [0, 1])
    }
    func testOutsideTableLinesRetainOriginalOrderAndRawCandidates() throws {
        let body = line(order: 1), note = line("架空注記", order: 0, x: 2)
        let input = page([note, body], rows: [[cell([line()])]])
        XCTAssertEqual(try links(input)[0].lineOrders, [1])
        XCTAssertEqual(input.lines, [note, body])
        XCTAssertEqual(try draft(input).assess().top1Count, 2)
    }
    func testMissingOrDifferentCellLineRefusesInsteadOfAddingOrCorrectingText() {
        for child in [line("別の架空科目"), line(x: 10.0000000001)] {
            XCTAssertThrowsError(try draft(page([line()], rows: [[cell([child])]])).assess()) {
                XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .characterMapping)
            }
        }
    }
    func testCanonicallyEquivalentUnicodeDoesNotBecomeAnExactRawMatch() {
        XCTAssertThrowsError(try draft(page([line("が")], rows: [[cell([line("か\u{3099}")])]])).assess()) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .characterMapping)
        }
    }
    func testDuplicateExactFlatLinesAreAmbiguousRatherThanChosenByOrder() {
        XCTAssertThrowsError(try draft(page([line(), line(order: 1)], rows: [[cell([line()])]])).assess()) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .characterMapping)
        }
    }
    func testAlternateRankOrConfidenceCannotBeNormalizedDuringLinking() {
        let top = line().candidates[0], alternate = line("別の架空科目", confidence: 0.5).candidates[0]
        let flat = RecoveryOCRLine(nativeOrder: 0, candidates: [top, alternate])
        for child in [RecoveryOCRLine(nativeOrder: 0, candidates: [alternate, top]),
                      RecoveryOCRLine(nativeOrder: 0, candidates: [top]), line(confidence: 0.9)] {
            XCTAssertThrowsError(try draft(page([flat], rows: [[cell([child])]])).assess())
        }
    }
    func testTwoDistinctCellsCannotClaimTheSameNativeLine() {
        XCTAssertThrowsError(try draft(page([line()], rows: [[cell([line()]), cell([line()], column: 1)]])).assess()) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .invalidInventory)
        }
    }
    func testNativeRowsAndColumnsMustRetainIdenticalCellContent() {
        for columns in [[], [[cell([line("別の架空科目")])]], [[cell([line()], column: 1)]]] {
            XCTAssertThrowsError(try draft(page([line()], rows: [[cell([line()])]], columns: columns)).assess())
        }
    }
    func testEmptyNativeCellIsRetainedWithoutInventingAFieldOrLine() throws {
        let input = page([], rows: [[cell([])]])
        let value = try links(input)
        XCTAssertEqual(value.count, 1); XCTAssertEqual(value[0].lineOrders, [])
        XCTAssertEqual(try draft(input).assess().top1Count, 0)
        // Raster coverage and Builder topology remain mandatory downstream.
    }
    func testNativeSpanIndicesAreKeptWithoutPeriodInference() throws {
        let input = page([line()], rows: [[cell([line()], row: 7, upper: 9, column: 12)]])
        let value = try links(input)[0]
        XCTAssertEqual(value.rowLower, 7); XCTAssertEqual(value.rowUpper, 9)
        XCTAssertEqual(value.columnLower, 12); XCTAssertEqual(value.columnUpper, 12)
    }
    func testNestedTablesRefuseExplicitlyRatherThanSilentlyLoseHierarchy() {
        XCTAssertThrowsError(try draft(page([line()], rows: [[cell([line()], nested: 1)]])).assess()) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .invalidInventory)
        }
    }
    func testHierarchyCannotRaiseLowNativeConfidenceOrIncreaseManualAllowance() throws {
        for confidence in [0.849999, 0.85] {
            let input = page([line(confidence: confidence)], rows: [[cell([line(confidence: confidence)])]])
            let result = try draft(input).assess()
            XCTAssertEqual(result.directLayoutsAllowed, confidence == 0.85)
            XCTAssertEqual(result.top1Count, 1)
            XCTAssertEqual(result.lowConfidenceNativeOrders[1], confidence == 0.85 ? [] : [0])
        }
    }
    func testLegacyNilHierarchyCanonicalBytesStayUnchangedAndDecode() throws {
        var input = page([line()], rows: []); input.structure = nil
        let encoded = try draft(input).canonicalData()
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("structure"))
        XCTAssertEqual(try JSONDecoder().decode(RecoveryOCRAcquisitionDraft.self, from: encoded), draft(input))
        XCTAssertTrue(try draft(input).assess().directLayoutsAllowed)
    }
    func testHierarchyChangesCaptureFingerprintInputWithoutChangingRawLines() throws {
        let a = page([line()], rows: [[cell([line()])]])
        let b = page([line()], rows: [[cell([line()], row: 2)]])
        XCTAssertEqual(a.lines, b.lines)
        XCTAssertNotEqual(try draft(a).canonicalData(), try draft(b).canonicalData())
        XCTAssertEqual(try JSONDecoder().decode(RecoveryOCRAcquisitionDraft.self, from: draft(a).canonicalData()), draft(a))
    }
    func testNativeRegionNonfiniteOutOfBoundsAndOversizeRefuseWithoutClipping() {
        let input = page([line()], rows: [[cell([line()])]])
        for points in [[RecoveryOCRNativePoint(x: .nan, y: 0), region[1], region[2]],
                       [.init(x: 1.00001, y: 0), region[1], region[2]],
                       [RecoveryOCRNativePoint](repeating: region[0], count: 4097)] {
            let table = RecoveryOCRNativeTable(nativeOrder: 0, region: points, rows: [[cell([line()])]], columns: [[cell([line()])]])
            var changed = input
            changed.structure = .init(documents: [.init(nativeOrder: 0, nativeUUID: "00000000-0000-0000-0000-000000000001", lineOrders: [0], tables: [table])])
            XCTAssertThrowsError(try draft(changed).assess())
        }
    }
    func testDocumentPartitionCannotBorrowAnExactLineFromAnotherObservation() {
        let native = line(), table = page([native], rows: [[cell([native])]]).structure!.documents[0].tables[0]
        let input = RecoveryOCRPage(page: 1, width: 100, height: 100, nativeDocumentCount: 2,
            lines: [native], captureComplete: true, structure: .init(documents: [
                .init(nativeOrder: 0, nativeUUID: "00000000-0000-0000-0000-000000000001", lineOrders: [], tables: [table]),
                .init(nativeOrder: 1, nativeUUID: "00000000-0000-0000-0000-000000000002", lineOrders: [0], tables: [])]))
        XCTAssertThrowsError(try draft(input).assess())
    }
    func testCancellationAndAggregateLimitAreChargedInsideNativeTextAndArrays() {
        let text = String(repeating: "架", count: 1000)
        let input = page([line(text)], rows: [[cell([line(text)])]])
        var work = 0
        XCTAssertThrowsError(try RecoveryOCRStructure.links(input.structure!, page: input, consume: {
            work += 1; if work == 200 { throw CancellationError() }
        })) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(work, 200)
        work = 0
        XCTAssertThrowsError(try RecoveryOCRStructure.links(input.structure!, page: input, consume: {
            work += 1; if work > 100 { throw RecoveryOCRAcquisitionFailure.limit }
        })) { XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .limit) }
        XCTAssertEqual(work, 101)
    }
    func testAggregateStructureBudgetCannotBeDisabledByCaller() {
        let huge = line(String(repeating: "架", count: 100_000))
        let input = page([huge], rows: [[cell([huge])]])
        XCTAssertThrowsError(try RecoveryOCRStructure.links(input.structure!, page: input, consume: {})) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, .limit)
        }
    }
    func testDuplicateDocumentUUIDAndMissingGlobalLinePartitionRefuse() {
        let input = page([line()], rows: [[cell([line()])]])
        let original = input.structure!.documents[0]
        var missing = input
        missing.structure = .init(documents: [.init(nativeOrder: 0, nativeUUID: original.nativeUUID,
            lineOrders: [], tables: [])])
        XCTAssertThrowsError(try draft(missing).assess())
        let duplicate = RecoveryOCRPage(page: 1, width: 100, height: 100, nativeDocumentCount: 2,
            lines: [line()], captureComplete: true, structure: .init(documents: [original,
                .init(nativeOrder: 1, nativeUUID: original.nativeUUID, lineOrders: [], tables: [])]))
        XCTAssertThrowsError(try draft(duplicate).assess())
    }
}
