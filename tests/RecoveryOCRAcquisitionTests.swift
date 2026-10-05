import Foundation
import XCTest
#if canImport(TakupokeParsing)
@testable import TakupokeParsing
#endif

final class RecoveryOCRAcquisitionTests: XCTestCase {
    private let sourcePDFHash = String(repeating: "a", count: 64)
    private let box = RecoveryOCRRange(x: 10, y: 10, width: 10, height: 10)
    private func withSource(_ bytes: Data, run: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ocr-snapshot-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fictional-source.bin")
        try bytes.write(to: url)
        try run(url)
    }
    func testSnapshotOwnsBytesAfterSourceIsAtomicallyReplaced() throws {
        let original = Data("entirely fictional source A".utf8)
        try withSource(original) { url in
            let snapshot = try RecoveryOCRSourceSnapshot.read(url, maximumBytes: 100)
            try Data("different fictional source B".utf8).write(to: url, options: .atomic)
            XCTAssertEqual(snapshot, original)
            XCTAssertNotEqual(try Data(contentsOf: url), snapshot)
        }
    }
    func testSnapshotLimitAndEmptySourceRefuseWithoutUnboundedRead() throws {
        try withSource(Data(repeating: 65, count: 65_537)) { url in
            XCTAssertThrowsError(try RecoveryOCRSourceSnapshot.read(url, maximumBytes: 65_536)) {
                XCTAssertEqual($0 as? RecoveryOCRSnapshotFailure, .limit)
            }
        }
        try withSource(Data()) { url in
            XCTAssertThrowsError(try RecoveryOCRSourceSnapshot.read(url, maximumBytes: 10)) {
                XCTAssertEqual($0 as? RecoveryOCRSnapshotFailure, .unreadable)
            }
        }
    }
    func testSnapshotCancellationAfterFirstChunkKeepsSourceUntouched() throws {
        let bytes = Data(repeating: 65, count: 131_073)
        try withSource(bytes) { url in
            var checks = 0
            XCTAssertThrowsError(try RecoveryOCRSourceSnapshot.read(url, maximumBytes: bytes.count, check: {
                checks += 1
                if checks == 3 { throw CancellationError() }
            })) { XCTAssertTrue($0 is CancellationError) }
            XCTAssertEqual(checks, 3)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    private func candidate(_ text: String = "架", confidence: Double = 1,
                           range: RecoveryOCRRange? = nil, missing: Bool = false) -> RecoveryOCRCandidate {
        .init(text: text, confidence: confidence,
              characters: text.map { .init(text: String($0), range: missing ? nil : (range ?? box)) })
    }
    private func page(_ number: Int = 1, candidates: [RecoveryOCRCandidate]? = nil,
                      complete: Bool = true) -> RecoveryOCRPage {
        .init(page: number, width: 100, height: 100, nativeDocumentCount: 1,
              lines: [.init(nativeOrder: 0, candidates: candidates ?? [candidate()])], captureComplete: complete)
    }
    private func draft(_ pages: [RecoveryOCRPage], count: Int? = nil, required: [Int]? = nil) -> RecoveryOCRAcquisitionDraft {
        .init(sourcePDFHash: sourcePDFHash, documentPageCount: count ?? pages.count,
              requiredOCRPages: required ?? pages.map(\.page), pages: pages)
    }
    private func fails(_ value: RecoveryOCRAcquisitionDraft, _ expected: RecoveryOCRAcquisitionFailure,
                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try value.assess(), file: file, line: line) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure, expected, file: file, line: line)
        }
    }
    func testCountsUncertaintyOnlyAfterEveryRequiredPageIsCaptured() throws {
        let first = page(candidates: [candidate(confidence: 0.5)])
        fails(draft([first], count: 2, required: [1, 2]), .invalidInventory)
        fails(draft([first, page(2, complete: false)]), .incomplete)
        fails(draft([first, page(2, candidates: [candidate(missing: true)])]), .characterMapping)
        let assessment = try draft([first, page(2)]).assess()
        XCTAssertEqual(assessment.top1Count, 2)
        XCTAssertEqual(assessment.lowConfidenceNativeOrders, [1: [0], 2: []])
        XCTAssertFalse(assessment.directLayoutsAllowed)
    }
    func testMixedVectorOCRInventoryRetainsExactRequiredPageIDs() throws {
        let value = draft([page(2), page(4)], count: 4, required: [2, 4])
        XCTAssertTrue(try value.assess().directLayoutsAllowed)
        XCTAssertEqual(value.requiredOCRPages, [2, 4])
        XCTAssertEqual(try value.assess().requiredOCRPages, [2, 4])
        XCTAssertEqual(try value.assess().documentPageCount, 4)
        fails(draft([page(4), page(2)], count: 4, required: [2, 4]), .invalidInventory)
        fails(draft([page(2), page(2)], count: 4, required: [2, 2]), .invalidInventory)
    }
    func testThreeFourAndFiftySevenNativeFailuresRemainSeparate() throws {
        for count in [3, 4, 57] {
            let lines = (0..<count).map { RecoveryOCRLine(nativeOrder: $0, candidates: [candidate(confidence: 0.5)]) }
            let p = RecoveryOCRPage(page: 1, width: 100, height: 100, nativeDocumentCount: 1,
                                    lines: lines, captureComplete: true)
            let value = try draft([p]).assess()
            XCTAssertEqual(value.lowConfidenceNativeOrders[1], Array(0..<count))
            XCTAssertEqual(value.top1Count, count)
            XCTAssertFalse(value.directLayoutsAllowed)
        }
        // These are native counts; ownership and document-wide semantic max3 is a later gate.
    }
    func testAlternateHighConfidenceCandidateCannotRescueTop1() throws {
        let original = candidate("誤", confidence: 0.5), alternate = candidate("架", confidence: 1)
        let value = draft([page(candidates: [original, alternate])])
        XCTAssertFalse(try value.assess().directLayoutsAllowed)
        XCTAssertEqual(value.pages[0].lines[0].candidates, [original, alternate])
        let repeated = draft([page(candidates: [candidate(), candidate()])])
        XCTAssertEqual(repeated.pages[0].lines[0].candidates.count, 2)
        XCTAssertTrue(try repeated.assess().directLayoutsAllowed)
    }
    func testMissingWhitespaceRangeIsPreservedAndCannotBecomeCorrectable() {
        let value = draft([page(candidates: [.init(text: "架 ", confidence: 0.5,
            characters: [.init(text: "架", range: box), .init(text: " ", range: nil)])])])
        fails(value, .characterMapping)
        XCTAssertNil(value.pages[0].lines[0].candidates[0].characters[1].range)
    }
    func testNativeWholeLineRangeKeepsUnpositionedSpaceWithoutInventingItsBox() throws {
        let native = RecoveryOCRCandidate(text:"架 空",confidence:0.85,characters:[
            .init(text:"架",range:box),.init(text:" ",range:nil),
            .init(text:"空",range:.init(x:25,y:10,width:10,height:10))],
            lineRange:.init(x:10,y:10,width:25,height:10))
        let value = draft([page(candidates:[native])])
        XCTAssertTrue(try value.assess().directLayoutsAllowed)
        XCTAssertEqual(try value.assess().top1CharacterCount,3)
        XCTAssertNil(value.pages[0].lines[0].candidates[0].characters[1].range)
        XCTAssertEqual(try JSONDecoder().decode(RecoveryOCRAcquisitionDraft.self,from:value.canonicalData()),value)
        var low = native; low = .init(text:native.text,confidence:0.849999,characters:native.characters,lineRange:native.lineRange)
        XCTAssertFalse(try draft([page(candidates:[low])]).assess().directLayoutsAllowed)
    }
    func testWholeLineRangeCannotRescueMissingInkInvalidSpaceOrMultilineText() {
        for (text,characters,range) in [
            ("架 空",[RecoveryOCRCharacter(text:"架",range:nil),.init(text:" ",range:nil),.init(text:"空",range:box)],box),
            ("架 ",[.init(text:"架",range:box),.init(text:" ",range:.init(x:15,y:10,width:0,height:10))],box),
            ("架 空",[.init(text:"架",range:box),.init(text:" ",range:nil),.init(text:"空",range:.init(x:25,y:10,width:10,height:10))],box),
            ("  ",[.init(text:" ",range:box),.init(text:" ",range:nil)],box),
            ("架 \n",[.init(text:"架",range:box),.init(text:" ",range:nil),.init(text:"\n",range:box)],box)
        ] {
            fails(draft([page(candidates:[.init(text:text,confidence:1,characters:characters,lineRange:range)])]),.characterMapping)
        }
    }
    func testHighConfidenceWholeLineStillRequiresBodyProofBeforeStrictParser() throws {
        let chars = [RecoveryOCRCharacter(text:"架",range:box),.init(text:" ",range:nil),.init(text:"空",range:box)]
        let raw = RecoveryOCRCandidate(text:"架 空",confidence:0.95,characters:chars,lineRange:box)
        let captured = draft([page(candidates:[raw])])
        XCTAssertTrue(try captured.assess().directLayoutsAllowed)
        XCTAssertThrowsError(try captured.strictAssessment()) {
            XCTAssertEqual($0 as? RecoveryOCRAcquisitionFailure,.characterMapping)
        }
        XCTAssertTrue(try draft([page()]).strictAssessment().directLayoutsAllowed)
    }
    func testNativeRangeOutsidePageRefusesWithoutClipping() {
        for range in [RecoveryOCRRange(x: 95, y: 10, width: 10, height: 10),
                      .init(x: 10, y: 95, width: 10, height: 10),
                      .init(x: -0.1, y: 10, width: 10, height: 10),
                      .init(x: 10, y: 10, width: .nan, height: 10)] {
            let value = draft([page(candidates: [candidate(range: range)])])
            fails(value, .characterMapping)
        }
    }
    func testInvalidConfidenceAndUncapturedCandidateRefuse() {
        for confidence in [Double.nan, -.infinity, -0.1, 1.1] {
            fails(draft([page(candidates: [candidate(confidence: confidence)])]), .invalidInventory)
        }
        fails(draft([page(candidates: [])]), .invalidInventory)
        fails(draft([page(candidates: [candidate("")])]), .invalidInventory)
    }
    func testStrictBoundaryDoesNotLowerConfidence() throws {
        XCTAssertTrue(try draft([page(candidates: [candidate(confidence: 0.85)])]).assess().directLayoutsAllowed)
        XCTAssertFalse(try draft([page(candidates: [candidate(confidence: 0.849999)])]).assess().directLayoutsAllowed)
    }
    func testNativeOrderAndFullTextCharacterMembershipMustAgree() {
        let bad = RecoveryOCRPage(page: 1, width: 100, height: 100, nativeDocumentCount: 1,
            lines: [.init(nativeOrder: 1, candidates: [candidate()])], captureComplete: true)
        fails(draft([bad]), .invalidInventory)
        fails(draft([page(candidates: [.init(text: "架別", confidence: 1,
             characters: [.init(text: "架", range: box)])])]), .invalidInventory)
        // Canonically equivalent Unicode is still different raw native bytes.
        fails(draft([page(candidates: [.init(text: "が", confidence: 1,
             characters: [.init(text: "か\u{3099}", range: box)])])]), .invalidInventory)
    }
    func testCanonicalCapturePreservesUnicodeAndChangesWithSourceOrConfidence() throws {
        let original = draft([page(candidates: [candidate("か\u{3099}", confidence: 0.5)])])
        let bytes = try original.canonicalData()
        XCTAssertEqual(try JSONDecoder().decode(RecoveryOCRAcquisitionDraft.self, from: bytes), original)
        XCTAssertEqual(try original.canonicalData(), bytes)
        XCTAssertEqual(original.pages[0].lines[0].candidates[0].text.unicodeScalars.count, 2)
        XCTAssertNotEqual(try draft([page(candidates: [candidate("か\u{3099}", confidence: 1)])]).canonicalData(), bytes)
        let differentHash = RecoveryOCRAcquisitionDraft(sourcePDFHash: String(repeating: "b", count: 64),
            documentPageCount: 1, requiredOCRPages: [1], pages: original.pages)
        XCTAssertNotEqual(try differentHash.canonicalData(), bytes)
    }
    func testCancellationIsCheckedDuringLargeInventoryValidation() {
        let text = String(repeating: "架", count: 1000)
        let value = draft([page(candidates: [candidate(text)])])
        var checks = 0
        XCTAssertThrowsError(try value.assess(check: {
            checks += 1
            if checks == 3 { throw CancellationError() }
        })) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(checks, 3)
    }
    func testSharedDocumentBudgetCannotResetPerPage() {
        let characters = [RecoveryOCRCharacter](repeating: .init(text: "A", range: box), count: 100_000)
        let candidate = RecoveryOCRCandidate(text: String(repeating: "A", count: 100_000), confidence: 1, characters: characters)
        let pages = (1...12).map { page($0, candidates: [candidate]) }
        fails(draft(pages), .limit)
    }
}
