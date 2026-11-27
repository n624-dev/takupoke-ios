import Foundation
import XCTest
@testable import TakupokeParsing

final class BoundedHTTPResponseTests: XCTestCase {
    private final class Expiry: @unchecked Sendable {
        private let lock = NSLock()
        private var expired = false
        private let event = AsyncStream<Void>.makeStream()

        var deadline: BoundedHTTPResponse.Deadline {
            .init(hasExpired: { [self] in lock.withLock { expired } }, waitUntilExpired: { [self] in
                var events = event.stream.makeAsyncIterator()
                _ = await events.next()
                try Task.checkCancellation()
            })
        }

        func fire() {
            lock.withLock { expired = true }
            event.continuation.finish()
        }
    }

    private actor SlowTransfer {
        private var finish: CheckedContinuation<Data, Never>?
        private let arrived = AsyncStream<UInt8>.makeStream()
        nonisolated var progress: AsyncStream<UInt8> { arrived.stream }

        func readIgnoringCancellation() async -> Data {
            await withCheckedContinuation { continuation in
                finish = continuation
                arrived.continuation.yield(10)
                arrived.continuation.yield(20)
                arrived.continuation.finish()
            }
        }

        func complete() {
            finish?.resume(returning: Data([10, 20, 30]))
            finish = nil
        }
    }

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

    func testAccountCommunicationBudgetCountsRequestsAndExcludesTimeBetweenThem() async throws {
        final class Clock: @unchecked Sendable {
            let lock = NSLock()
            var instant: TimeInterval = 0
            func read() -> TimeInterval { lock.withLock { instant } }
            func advance(_ seconds: TimeInterval) { lock.withLock { instant += seconds } }
        }
        let clock = Clock()
        let budget = BoundedHTTPResponse.CommunicationBudget(now: { clock.read() }, wait: { _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
        })
        for _ in 0..<3 {
            let data = try await budget.read { clock.advance(55); return Data([1]) }
            XCTAssertEqual(data, Data([1]))
            clock.advance(599)
        }
        do {
            _ = try await budget.read { clock.advance(15); return Data([2]) }
            XCTFail("The remaining fifteen seconds must bound the fourth request")
        } catch BoundedHTTPResponse.Failure.deadlineExceeded {}
        do {
            _ = try await budget.read { XCTFail("A fifth transfer must not start after budget exhaustion"); return Data() }
            XCTFail("Expected the total communication limit")
        } catch BoundedHTTPResponse.Failure.deadlineExceeded {}
        let freshBudget = BoundedHTTPResponse.CommunicationBudget(now: { clock.read() }, wait: { _ in
            try await Task.sleep(nanoseconds: 10_000_000_000)
        })
        do {
            _ = try await freshBudget.read { clock.advance(60); return Data([3]) }
            XCTFail("Each communication has its own sixty second limit")
        } catch BoundedHTTPResponse.Failure.deadlineExceeded {}
    }

    func testDeadlineEndsAnIntermittentTransferBeforeItsLateCompletion() async throws {
        let clock = Expiry(), old = SlowTransfer()
        let request = Task { try await clock.deadline.read { await old.readIgnoringCancellation() } }
        var progress = old.progress.makeAsyncIterator()
        let first = await progress.next()
        let second = await progress.next()
        XCTAssertEqual([first, second], [10, 20])
        clock.fire()
        do {
            _ = try await request.value
            XCTFail("The original deadline must win even though bytes arrived")
        } catch BoundedHTTPResponse.Failure.deadlineExceeded {}
        let new = try await Expiry().deadline.read { Data([40]) }
        await old.complete()
        XCTAssertEqual(new, Data([40]))
    }

    func testExplicitCancellationRemainsDistinctFromDeadlineAndAllowsAnotherRead() async throws {
        let clock = Expiry(), old = SlowTransfer()
        let request = Task { try await clock.deadline.read { await old.readIgnoringCancellation() } }
        var progress = old.progress.makeAsyncIterator()
        _ = await progress.next()
        request.cancel()
        do {
            _ = try await request.value
            XCTFail("Explicit cancellation must win")
        } catch is CancellationError {}
        await old.complete()
        let new = try await Expiry().deadline.read { Data([50]) }
        XCTAssertEqual(new, Data([50]))
    }
}
