import Foundation
import XCTest
@testable import TakupokeParsing

final class RecoveryPromptCatalogTests: XCTestCase {
    func testPackagedInstructionLoadsVerifiedCanonicalBytes() throws {
        let text = try RecoveryPromptCatalog.fieldExtraction()
        XCTAssertEqual(try RecoveryPromptCatalog.validateFieldExtraction(Data(text.utf8)), text)
        XCTAssertEqual(text.utf8.count, 2939)
    }

    func testSameLengthMutationFailsRatherThanFallingBackToOldInstruction() throws {
        var data = Data(try RecoveryPromptCatalog.fieldExtraction().utf8)
        data[0] ^= 1
        XCTAssertThrowsError(try RecoveryPromptCatalog.validateFieldExtraction(data))
    }

    func testTruncationNewlineAndInvalidEncodingFailClosed() throws {
        let data = Data(try RecoveryPromptCatalog.fieldExtraction().utf8)
        XCTAssertThrowsError(try RecoveryPromptCatalog.validateFieldExtraction(Data(data.dropLast())))
        XCTAssertThrowsError(try RecoveryPromptCatalog.validateFieldExtraction(data + Data([10])))
        var invalid = data; invalid[0] = 0xff
        XCTAssertThrowsError(try RecoveryPromptCatalog.validateFieldExtraction(invalid))
    }
}
