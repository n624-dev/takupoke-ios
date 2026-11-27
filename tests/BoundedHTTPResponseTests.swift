import Foundation
import XCTest
@testable import TakupokeParsing

final class BoundedHTTPResponseTests: XCTestCase {
    private final class Stream: AsyncSequence, AsyncIteratorProtocol {
        typealias Element = UInt8
        private let body: [UInt8]
        private(set) var consumed = 0
        init(_ body: [UInt8]) { self.body = body }
        func makeAsyncIterator() -> Stream { self }
        func next() async -> UInt8? {
            guard consumed < body.count else { return nil }
            defer { consumed += 1 }
            return body[consumed]
        }
    }

    func testRejectsExcessiveDeclaredLengthBeforeReadingAnyBytes() async throws {
        let source = Stream([10, 20, 30, 40])
        do {
            _ = try await BoundedHTTPResponse.collect(source, expectedLength: 200, maximum: 4)
            XCTFail("Excessive declared content length was accepted")
        } catch BoundedHTTPResponse.Failure.sizeExceeded {}
        XCTAssertEqual(source.consumed, 0)
    }

    func testUnknownAndUnderstatedLengthsBothStopAtFirstExcessByte() async throws {
        for expected: Int64 in [-1, 1, 4] {
            let source = Stream([10, 20, 30, 40, 50, 60, 70])
            do {
                _ = try await BoundedHTTPResponse.collect(source, expectedLength: expected, maximum: 4)
                XCTFail("Excess bytes were accepted with declared length \(expected)")
            } catch BoundedHTTPResponse.Failure.sizeExceeded {}
            XCTAssertEqual(source.consumed, 5)
        }
    }

    func testExactLimitAndEmptyRevisionResponsesRemainUsable() async throws {
        let expected = Data([10, 20, 30, 40])
        let body = try await BoundedHTTPResponse.collect(Stream(Array(expected)), expectedLength: -1, maximum: 4)
        XCTAssertEqual(body, expected)
        let empty = try await BoundedHTTPResponse.collect(Stream([]), expectedLength: 0, maximum: 0)
        XCTAssertTrue(empty.isEmpty)
    }

    func testCancelledReaderDoesNotConsumeAnyPartOfTheResponse() async throws {
        let source = Stream([10, 20, 30, 40])
        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await BoundedHTTPResponse.collect(source, expectedLength: -1, maximum: 4)
        }
        do {
            _ = try await operation.value
            XCTFail("A cancelled transfer was accepted")
        } catch is CancellationError {}
        XCTAssertEqual(source.consumed, 0)
    }
}
