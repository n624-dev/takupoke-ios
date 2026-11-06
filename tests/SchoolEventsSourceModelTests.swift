import Foundation
import XCTest
import Combine
import CryptoKit
@testable import TakupokeParsing

private final class SourceStatusTransport: URLProtocol {
    private static let lock = NSLock()
    private static var scenario: SourceStatusScenario?
    private let stateLock = NSLock()
    private var stopped = false
    static func use(_ value: SourceStatusScenario?) { lock.lock(); scenario = value; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let scenario = Self.scenario; Self.lock.unlock()
        guard let scenario else { client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return }
        scenario.receive(self)
    }
    override func stopLoading() { stateLock.lock(); stopped = true; stateLock.unlock() }
    func finish(status: Int, data: Data, etag: String? = nil) {
        stateLock.lock(); let cancelled = stopped; stateLock.unlock()
        guard !cancelled else { return }
        var headers = ["Content-Type": "application/json"]
        headers["ETag"] = etag
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class SourceStatusScenario {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var held: [SourceStatusTransport] = []
    var holdStatus = false
    var statusHTTP = 200
    var updated = false
    var oldStatusVersion = false
    var checking = false
    var started: XCTestExpectation?
    private(set) var unexpected = 0

    static func events(year: Int, updated: Bool = false) -> Data {
        // Explicit fictional wire bytes: dataVersion must hash these bytes,
        // not a re-encoded payload with another key order.
        Data("{\"version\":\"v1\",\"schoolYear\":\(year),\"sourcePdfSha256\":\"\(String(repeating: "a", count: 64))\",\"events\":[{\"startDate\":\"\(year)-04-01\",\"endDate\":\"\(year)-04-01\",\"title\":\"架空\(updated ? "更新" : "保存")行事\",\"tag\":\"行事\"}]}".utf8)
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func count(path: String, year: Int) -> Int { lock.lock(); defer { lock.unlock() }; return counts["\(path)/\(year)"] ?? 0 }
    func receive(_ transport: SourceStatusTransport) {
        let request = transport.request
        guard let url = request.url, url.host == "source.example.invalid",
              ["/events", "/events/source-status"].contains(url.path), request.httpMethod == "GET",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "schoolYear", let year = items[0].value.flatMap(Int.init),
              [2032, 2033].contains(year) else {
            lock.lock(); unexpected += 1; lock.unlock()
            transport.client?.urlProtocol(transport, didFailWithError: URLError(.unsupportedURL)); return
        }
        lock.lock()
        counts["\(url.path)/\(year)", default: 0] += 1
        let shouldHold = holdStatus && url.path == "/events/source-status"
        let event = started; if shouldHold { held.append(transport); started = nil }
        lock.unlock()
        if shouldHold { event?.fulfill(); return }
        reply(transport)
    }
    func release() {
        lock.lock(); let values = held; held = []; lock.unlock()
        for value in values { reply(value) }
    }
    private func reply(_ transport: SourceStatusTransport) {
        let url = transport.request.url!
        let year = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems![0].value!)!
        if url.path == "/events" {
            let data = Self.events(year: year, updated: updated)
            let tag = "W/\"" + Self.hash(data) + "\""
            let notModified = transport.request.value(forHTTPHeaderField: "If-None-Match") == tag
            transport.finish(status: notModified ? 304 : 200, data: notModified ? Data() : data, etag: tag)
        } else {
            let digest = Self.hash(Self.events(year: year, updated: updated && !oldStatusVersion))
            let data = try! JSONSerialization.data(withJSONObject: ["version": "v1", "schoolYear": year,
                "dataVersion": "sha256-" + digest, "adoptedSourcePdfSha256": String(repeating: "a", count: 64),
                "status": "matched", "lastSuccessfulStatus": "matched", "lastSuccessAt": "2032-05-01T03:04:05.842Z",
                "lastAttemptAt": "2032-05-01T03:04:05Z", "nextAttemptAt": "2032-05-02T03:04:05Z",
                "checking": checking, "stale": false])
            transport.finish(status: statusHTTP, data: data)
        }
    }
}

@MainActor
final class SchoolEventsSourceModelTests: XCTestCase {
    @MainActor private final class RetryClock {
        var pending: [(TimeInterval, CheckedContinuation<Void, Error>)] = []
        var scheduled = 0
        var onScheduled: (() -> Void)?
        func wait(_ seconds: TimeInterval) async throws {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                pending.append((seconds, continuation)); scheduled += 1
                onScheduled?()
            }
            try Task.checkCancellation()
        }
        func advance() { pending.removeFirst().1.resume() }
        func cancel() {
            let owned = pending; pending = []
            for value in owned { value.1.resume(throwing: CancellationError()) }
        }
    }
    @MainActor private final class Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("source-model-" + UUID().uuidString)
        let network = SourceStatusScenario()
        var now = SchoolEventsSourceStatus.date("2032-05-01T03:04:05.842Z")!
        var model: SchoolEventsModel!
        init() throws {
            let store = try SchoolEventsStore(root: root.appendingPathComponent("SchoolEventsAPI"))
            for year in [2032, 2033] {
                let data = SourceStatusScenario.events(year: year)
                try store.save(.decode(data, requestedYear: year), apiETag: "W/\"" + SourceStatusScenario.hash(data) + "\"")
            }
            SourceStatusTransport.use(network)
            model = makeModel()
            model.loadIfNeeded()
        }
        func makeModel(waitForSourceExpiry: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }, waitForSourceRetry: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }, nowProvider: (() -> Date)? = nil) -> SchoolEventsModel {
            SchoolEventsModel(storeRoot: root, eventsEndpoint: URL(string: "https://source.example.invalid/events")!,
                makeSession: {
                    let config = URLSessionConfiguration.ephemeral
                    config.protocolClasses = [SourceStatusTransport.self]; config.urlCache = nil
                    return URLSession(configuration: config)
                }, now: nowProvider ?? { [unowned self] in self.now }, waitForSourceExpiry: waitForSourceExpiry,
                waitForSourceRetry: waitForSourceRetry)
        }
        func clean() { model.cancel(); SourceStatusTransport.use(nil); try? FileManager.default.removeItem(at: root) }
    }

    private func pendingRetry(_ clock: RetryClock) async throws {
        if clock.pending.isEmpty {
            let scheduled = expectation(description: "bounded retry scheduled")
            clock.onScheduled = { scheduled.fulfill() }
            await fulfillment(of: [scheduled], timeout: 5)
            clock.onScheduled = nil
        }
        XCTAssertEqual(clock.pending.count, 1)
        XCTAssertEqual(try XCTUnwrap(clock.pending.first).0, 60)
    }

    private func finishRetry(_ f: Fixture, _ clock: RetryClock) async throws {
        try await pendingRetry(clock)
        let received = expectation(description: "actual metadata reply published")
        let subscription = f.model.$sourceStatuses.dropFirst().first().sink { _ in received.fulfill() }
        f.now.addTimeInterval(60); clock.advance()
        await fulfillment(of: [received], timeout: 5)
        subscription.cancel()
        await f.model.checkSource(year: 2032)?.value
    }

    func testCheckingAutomaticallyBecomesMatchedWithoutFetchingEventsAgain() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        let data = f.model.saved[2032]?.payload, generation = f.model.scheduleGeneration
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await pendingRetry(clock)
        XCTAssertNil(f.model.checkSource(year: 2032))
        f.network.checking = false
        try await finishRetry(f, clock)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 0)
        XCTAssertEqual(clock.scheduled, 1); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        XCTAssertEqual(f.model.saved[2032]?.payload, data)
        XCTAssertEqual(f.model.scheduleGeneration, generation); XCTAssertFalse(f.model.busy)
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testCheckingStopsAfterExactlyThreeAdditionalRequests() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        for expected in 2...4 {
            try await finishRetry(f, clock)
            XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), expected)
        }
        XCTAssertEqual(clock.scheduled, 3); XCTAssertTrue(clock.pending.isEmpty)
        for _ in 0..<5 { XCTAssertNil(f.model.checkSource(year: 2032)) }
        f.model.setSourceChecksActive(false); f.model.setSourceChecksActive(true)
        XCTAssertNil(f.model.checkSource(year: 2032))
        XCTAssertEqual(clock.scheduled, 3)
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("現在の更新状況は未確認"))
        f.now.addTimeInterval(60)
        let display = try XCTUnwrap(f.model.sourcePresentation(year: 2032))
        XCTAssertTrue(display.message.contains("現在の更新状況は未確認")); XCTAssertTrue(display.warning)
        XCTAssertNotNil(display.lastSuccessAt); XCTAssertTrue(try XCTUnwrap(display.lastSuccessfulMessage).contains("一致"))
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 0)
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testFailedFollowUpStopsAndPreservesSavedEventsAndSuccessfulEvidence() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        let data = f.model.saved[2032]?.payload, previous = f.model.sourceStatuses[2032]
        try await pendingRetry(clock)
        let failed = expectation(description: "actual metadata error published")
        let subscription = f.model.$sourceErrors.dropFirst().first().sink { _ in failed.fulfill() }
        f.network.statusHTTP = 503; f.now.addTimeInterval(60); clock.advance()
        await fulfillment(of: [failed], timeout: 5); subscription.cancel()
        f.model.setSourceChecksActive(false)
        XCTAssertEqual(f.model.sourceStatuses[2032], previous)
        XCTAssertEqual(f.model.saved[2032]?.payload, data)
        XCTAssertNotNil(f.model.sourceErrors[2032]); XCTAssertFalse(f.model.failed)
        XCTAssertEqual(clock.scheduled, 1); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
    }

    func testBackgroundSuspensionCancelsPendingAndInFlightFollowUps() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await pendingRetry(clock)
        f.model.setSourceChecksActive(false); clock.advance()
        await Task.yield()
        XCTAssertNil(f.model.checkSource(year: 2032, force: true))
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        f.model.setSourceChecksActive(true)
        await f.model.checkSource(year: 2032, force: true)?.value
        try await pendingRetry(clock)
        let previous = f.model.sourceStatuses[2032]
        f.network.holdStatus = true
        let started = expectation(description: "in-flight automatic follow-up")
        f.network.started = started; f.now.addTimeInterval(60); clock.advance()
        await fulfillment(of: [started], timeout: 5)
        let running = try XCTUnwrap(f.model.checkSource(year: 2032, force: true))
        f.model.setSourceChecksActive(false); await running.value
        f.network.release()
        XCTAssertEqual(f.model.sourceStatuses[2032], previous)
        XCTAssertNil(f.model.sourceErrors[2032]); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 3)
    }

    func testChangedSavedVersionCancelsPendingFollowUpAndMismatchedReplyCannotScheduleOne() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await pendingRetry(clock)
        f.network.updated = true
        let refreshed = await f.model.refreshInBackground(); XCTAssertTrue(refreshed)
        clock.advance(); await Task.yield()
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title, "架空更新行事")
        f.network.oldStatusVersion = true
        await f.model.checkSource(year: 2032, force: true)?.value
        XCTAssertEqual(clock.scheduled, 1); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("配信版が一致しない"))
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testManualCheckSupersedesPendingFollowUpWithoutAnExtraRequest() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
        f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await pendingRetry(clock)
        f.network.checking = false
        await f.model.checkSource(year: 2032, force: true)?.value
        clock.advance(); await Task.yield()
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        XCTAssertEqual(clock.scheduled, 1); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
    }

    func testForegroundResumesTheRemainingBudgetWithoutRepeatingTheInitialRequest() async throws {
        for backgroundSeconds in [0.0, 120.0] {
            let f = try Fixture(), clock = RetryClock()
            defer { f.clean(); clock.cancel() }
            f.model = f.makeModel(waitForSourceRetry: clock.wait); f.model.loadIfNeeded()
            f.network.checking = true
            await f.model.checkSource(year: 2032)?.value
            try await finishRetry(f, clock)
            try await pendingRetry(clock)
            f.model.setSourceChecksActive(false); clock.advance(); await Task.yield()
            f.now.addTimeInterval(backgroundSeconds)
            f.model.setSourceChecksActive(true)
            let resumed = f.model.checkSource(year: 2032)
            if backgroundSeconds == 0 {
                XCTAssertNil(resumed)
                XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
                try await finishRetry(f, clock)
            } else {
                await resumed?.value
                XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 3)
            }
            try await finishRetry(f, clock)
            XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 4)
            f.now.addTimeInterval(120)
            XCTAssertNil(f.model.checkSource(year: 2032))
            XCTAssertTrue(clock.pending.isEmpty)
        }
    }

    func testForegroundBudgetAndCacheUseOneTimeSnapshotAtExpiryBoundary() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        var crossingBoundary = false, clockReads = 0
        f.model = f.makeModel(waitForSourceRetry: clock.wait, nowProvider: { [unowned f] in
            guard crossingBoundary else { return f.now }
            defer { clockReads += 1 }
            return f.now.addingTimeInterval(clockReads == 0 ? 0 : 0.2)
        })
        f.model.loadIfNeeded(); f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await finishRetry(f, clock); try await pendingRetry(clock)
        f.model.setSourceChecksActive(false); clock.advance(); await Task.yield()
        f.now.addTimeInterval(59.9); crossingBoundary = true
        f.model.setSourceChecksActive(true)
        XCTAssertNil(f.model.checkSource(year: 2032))
        XCTAssertEqual(clockReads, 1)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        crossingBoundary = false
        try await finishRetry(f, clock); try await finishRetry(f, clock)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 4)
        XCTAssertTrue(clock.pending.isEmpty)
    }

    func testExpiryPublishesToObserversWithoutARequestOrSavedEventsChange() async throws {
        let f = try Fixture(); defer { f.clean() }
        f.network.checking = true
        var waits = [(TimeInterval, CheckedContinuation<Void, Error>)]()
        let scheduled = expectation(description: "metadata presentation expiry scheduled")
        f.model.cancel()
        f.model = f.makeModel(waitForSourceExpiry: { seconds in
            try await withCheckedThrowingContinuation { continuation in
                waits.append((seconds, continuation))
                if waits.count == 1 { scheduled.fulfill() }
            }
        })
        f.model.loadIfNeeded()
        let data = f.model.saved[2032]?.payload, generation = f.model.scheduleGeneration
        await f.model.checkSource(year: 2032)?.value
        await fulfillment(of: [scheduled], timeout: 5)
        let wait = try XCTUnwrap(waits.first)
        XCTAssertEqual(wait.0, 60)
        // Observe the same Published event used by settings/Home/week views.
        let changed = expectation(description: "advisory presentation changed")
        let subscription = f.model.$sourcePresentationRevision.dropFirst().first().sink { _ in changed.fulfill() }
        f.now.addTimeInterval(60)
        wait.1.resume()
        await fulfillment(of: [changed], timeout: 5)
        subscription.cancel()
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("前回確認時"))
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        XCTAssertEqual(f.model.saved[2032]?.payload, data); XCTAssertEqual(f.model.scheduleGeneration, generation)
        XCTAssertFalse(f.model.busy); XCTAssertEqual(f.network.unexpected, 0)
        f.model.cancel()
        // The next successful-observation deadline may already be waiting.
        // Release only owned continuations; cancellation/generation reject it.
        for entry in waits.dropFirst() { entry.1.resume(throwing: CancellationError()) }
    }

    private func dataFinished(_ model: SchoolEventsModel) async {
        let complete = expectation(description: "actual data operation finished")
        let subscription = model.$busy.filter { !$0 }.first().sink { _ in complete.fulfill() }
        await fulfillment(of: [complete], timeout: 5)
        subscription.cancel()
    }

    func testActualMetadataRequestIsNonblockingCoalescedCachedPersistedAndFailureRetainsEvents() async throws {
        let f = try Fixture(); defer { f.clean() }
        let generation = f.model.scheduleGeneration, original = f.model.saved[2032]?.payload
        f.network.holdStatus = true
        let started = expectation(description: "one real metadata request")
        f.network.started = started
        let first = try XCTUnwrap(f.model.checkSource(year: 2032))
        let second = try XCTUnwrap(f.model.checkSource(year: 2032, force: true))
        await fulfillment(of: [started], timeout: 5)
        XCTAssertFalse(f.model.busy); XCTAssertTrue(f.model.ready)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        f.network.holdStatus = false; f.network.release()
        await first.value; await second.value
        XCTAssertNil(f.model.checkSource(year: 2032))
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        XCTAssertEqual(f.model.scheduleGeneration, generation)
        XCTAssertEqual(f.model.projectionBuildCount, 1)
        let reopened = f.makeModel(); reopened.loadIfNeeded()
        XCTAssertNil(reopened.checkSource(year: 2032))
        f.now.addTimeInterval(43_199); XCTAssertNil(f.model.checkSource(year: 2032))
        f.now.addTimeInterval(1)
        let expired = try XCTUnwrap(f.model.checkSource(year: 2032)); await expired.value
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        let previous = f.model.sourceStatuses[2032]
        f.network.statusHTTP = 503
        await f.model.checkSource(year: 2032, force: true)?.value
        XCTAssertEqual(f.model.sourceStatuses[2032], previous)
        XCTAssertNotNil(f.model.sourceErrors[2032])
        XCTAssertEqual(f.model.saved[2032]?.payload, original); XCTAssertFalse(f.model.failed)
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testActualStartupForegroundManual304AndNew200BindEachYearAndVersion() async throws {
        let f = try Fixture(); defer { f.clean() }
        f.model.refreshAtStartup(); await dataFinished(f.model)
        for year in [2032, 2033] { await f.model.checkSource(year: year)?.value }
        XCTAssertNil(f.model.sourceCheckMessage)
        for year in [2032, 2033] {
            XCTAssertEqual(f.network.count(path: "/events", year: year), 1)
            XCTAssertEqual(f.network.count(path: "/events/source-status", year: year), 1)
        }
        f.now.addTimeInterval(43_200)
        f.model.refreshAtStartup()
        for year in [2032, 2033] { await f.model.checkSource(year: year)?.value }
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 1)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        f.model.fetch(year: 2032); await dataFinished(f.model)
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 3)
        let healthy2033 = f.model.saved[2033]?.payload
        f.network.updated = true; f.network.oldStatusVersion = true
        f.model.fetch(year: 2032); await dataFinished(f.model)
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title, "架空更新行事")
        XCTAssertEqual(f.model.saved[2032]?.dataVersion,
                       "sha256-" + SourceStatusScenario.hash(SourceStatusScenario.events(year: 2032, updated: true)))
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("配信版が一致しない"))
        XCTAssertEqual(f.model.saved[2033]?.payload, healthy2033)
        f.network.oldStatusVersion = false
        await f.model.checkSource(year: 2032, force: true)?.value
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        let restored = f.makeModel(); restored.loadIfNeeded()
        XCTAssertEqual(restored.saved[2032]?.dataVersion, f.model.saved[2032]?.dataVersion)
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testActualOldInflightSnapshotAndCancellationCannotPublishMetadataIntoNewData() async throws {
        let f = try Fixture(); defer { f.clean() }
        f.network.holdStatus = true
        let started = expectation(description: "held old snapshot")
        f.network.started = started
        let old = try XCTUnwrap(f.model.checkSource(year: 2032))
        await fulfillment(of: [started], timeout: 5)
        f.network.updated = true
        let updated = await f.model.refreshInBackground(); XCTAssertTrue(updated)
        f.network.oldStatusVersion = true
        f.network.release(); await old.value
        XCTAssertNil(f.model.sourceStatuses[2032])
        let cancelledStart = expectation(description: "cancellable metadata owner")
        f.network.started = cancelledStart
        let cancelled = try XCTUnwrap(f.model.checkSource(year: 2032))
        await fulfillment(of: [cancelledStart], timeout: 5)
        f.model.cancel(); await cancelled.value
        XCTAssertNil(f.model.sourceStatuses[2032]); XCTAssertFalse(f.model.busy)
        f.network.holdStatus = false; f.network.oldStatusVersion = false
        f.network.release()
        await f.model.checkSource(year: 2032)?.value
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        XCTAssertEqual(f.network.unexpected, 0)
    }
}
