import Foundation
import XCTest
@testable import TakupokeParsing

final class CancellationLinkedTaskTests: XCTestCase {
    func testParentCancellationReachesAnAlreadySuspendedOwnedWorkerAndWaitsForCleanup() async throws {
        let started = expectation(description: "owned async work entered")
        let cancelled = expectation(description: "owned async work observed cancellation")
        let cleaned = expectation(description: "worker cleanup finished")
        let worker = Task.detached { () throws -> Int in
            defer { cleaned.fulfill() }
            started.fulfill()
            do { try await Task.sleep(nanoseconds: 30_000_000_000) }
            catch { cancelled.fulfill(); throw error }
            return 7
        }
        let parent = Task { try await CancellationLinkedTask.value(of: worker) }
        await fulfillment(of: [started], timeout: 2)
        parent.cancel()
        await fulfillment(of: [cancelled, cleaned], timeout: 2)
        // Always release the owned worker, including when the cancellation test fails.
        worker.cancel()
        do { _ = try await parent.value; XCTFail("Cancelled async work must not return a usable result") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testSuccessAndOriginalFailureKeepTheirValues() async throws {
        let result = try await CancellationLinkedTask.value(of: Task.detached { 42 })
        XCTAssertEqual(result, 42)
        let failed = Task.detached { () throws -> Int in throw CocoaError(.fileReadNoPermission) }
        do { _ = try await CancellationLinkedTask.value(of: failed); XCTFail("Original error must be retained") }
        catch { XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain); XCTAssertEqual((error as NSError).code, CocoaError.fileReadNoPermission.rawValue) }
    }

    func testCancellationSignalsAnUnresponsiveWorkerWithoutReleasingItsOwnership() async throws {
        final class WorkerExit: @unchecked Sendable {
            private let lock = NSLock()
            private var completed = false
            func finish() { lock.withLock { completed = true } }
            var finished: Bool { lock.withLock { completed } }
        }
        let exit = WorkerExit()
        let entered = expectation(description: "worker entered SDK boundary")
        let notified = expectation(description: "worker received cancellation")
        let released = expectation(description: "worker exited and cleaned up")
        let returnedEarly = expectation(description: "waiter must remain suspended while SDK owns input")
        returnedEarly.isInverted = true
        let (gate, sdk) = AsyncStream<Void>.makeStream()
        defer { sdk.finish() }
        let worker = Task.detached { () throws -> Int in
            defer { exit.finish(); released.fulfill() }
            await withTaskCancellationHandler {
                entered.fulfill()
                // AsyncStream iteration would normally end on cancellation.
                // This independent SDK callback is owned until it responds.
                await Task.detached {
                    var next = gate.makeAsyncIterator()
                    _ = await next.next()
                }.value
            } onCancel: { notified.fulfill() }
            try Task.checkCancellation()
            return 42
        }
        let waiter = Task {
            defer { if !exit.finished { returnedEarly.fulfill() } }
            return try await CancellationLinkedTask.value(of: worker)
        }
        await fulfillment(of: [entered], timeout: 2)
        waiter.cancel()
        await fulfillment(of: [notified], timeout: 2)
        await fulfillment(of: [returnedEarly], timeout: 0.1)
        sdk.yield(())
        await fulfillment(of: [released], timeout: 2)
        do { _ = try await waiter.value; XCTFail("A late SDK completion must not be usable") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
