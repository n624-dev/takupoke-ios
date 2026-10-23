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
}
