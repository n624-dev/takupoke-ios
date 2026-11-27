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
    private var validators: [String?] = []
    private var held: [SourceStatusTransport] = []
    var holdStatus = false
    var holdBody = false
    var statusHTTP = 200
    var bodyHTTP = 200
    var bypassNotModified = false
    var updated = false
    var oldStatusVersion = false
    var checking = false
    var stale = false
    var sourceDifference = false
    var successAt = "2032-05-01T03:04:05.842Z"
    var nextAttemptAt = "2032-05-02T03:04:05.842Z"
    var started: XCTestExpectation?
    private(set) var unexpected = 0

    static func events(year: Int, updated: Bool = false, format: String = "v1") -> Data {
        // Explicit fictional wire bytes: dataVersion must hash these bytes,
        // not a re-encoded payload with another key order.
        let dates = "\"startDate\":\"\(year)-04-01\",\"endDate\":\"\(year)-04-01\""
        let fields = format == "v2" ? "\"eventId\":\"stable-fixture\",\"ranges\":[{\(dates)}]" : dates
        return Data("{\"version\":\"\(format)\",\"schoolYear\":\(year),\"sourcePdfSha256\":\"\(String(repeating: "a", count: 64))\",\"events\":[{\(fields),\"title\":\"架空\(updated ? "更新" : "保存")行事\",\"tag\":\"行事\"}]}".utf8)
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func count(path: String, year: Int) -> Int { lock.lock(); defer { lock.unlock() }; return counts["\(path)/\(year)"] ?? 0 }
    func bodyValidators() -> [String?] { lock.lock(); defer { lock.unlock() }; return validators }
    func receive(_ transport: SourceStatusTransport) {
        let request = transport.request
        guard let url = request.url, url.host == "source.example.invalid",
              ["/events", "/events/source-status"].contains(url.path), request.httpMethod == "GET",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              (items.count == 1 || items.count == 2 && items[1] == URLQueryItem(name: "format", value: "v2")),
              items[0].name == "schoolYear", let year = items[0].value.flatMap(Int.init),
              [2032, 2033].contains(year) else {
            lock.lock(); unexpected += 1; lock.unlock()
            transport.client?.urlProtocol(transport, didFailWithError: URLError(.unsupportedURL)); return
        }
        lock.lock()
        counts["\(url.path)/\(year)", default: 0] += 1
        if url.path == "/events" { validators.append(request.value(forHTTPHeaderField: "If-None-Match")) }
        let shouldHold = holdStatus && url.path == "/events/source-status" || holdBody && url.path == "/events"
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
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let year = Int(items[0].value!)!
        let format = items.count == 1 ? "v1" : "v2"
        if url.path == "/events" {
            let data = Self.events(year: year, updated: updated, format: format)
            let tag = "W/\"" + Self.hash(data) + "\""
            let notModified = !bypassNotModified && transport.request.value(forHTTPHeaderField: "If-None-Match") == tag
            transport.finish(status: bodyHTTP == 200 && notModified ? 304 : bodyHTTP, data: notModified ? Data() : data, etag: tag)
        } else {
            let digest = Self.hash(Self.events(year: year, updated: updated && !oldStatusVersion, format: format))
            let state = sourceDifference ? "source_differs" : "matched"
            let data = try! JSONSerialization.data(withJSONObject: ["version": "v1", "schoolYear": year,
                "dataVersion": "sha256-" + digest, "adoptedSourcePdfSha256": String(repeating: "a", count: 64),
                "status": state, "lastSuccessfulStatus": state, "lastSuccessAt": successAt,
                "lastAttemptAt": successAt, "nextAttemptAt": nextAttemptAt,
                "checking": checking, "stale": stale])
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
        }, nowProvider: (() -> Date)? = nil, format: SchoolEventsFormat = .v1) -> SchoolEventsModel {
            SchoolEventsModel(storeRoot: root, eventsEndpoint: URL(string: "https://source.example.invalid/events")!, preferredFormat: format,
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

    func testNewSchoolYearStopsAutomaticChecksButKeepsSavedEventsAndManualRefresh() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let model = try XCTUnwrap(fixture.model)
        let prior = try XCTUnwrap(model.saved[2032])
        fixture.now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2033-03-31T14:59:59Z"))
        XCTAssertTrue(model.isAutomaticRefreshEnabled(year: 2032))
        fixture.now.addTimeInterval(1)
        XCTAssertFalse(model.isAutomaticRefreshEnabled(year: 2032))
        XCTAssertTrue(model.isAutomaticRefreshEnabled(year: 2033))
        XCTAssertNil(model.checkSource(year: 2032))
        _ = await model.refreshInBackground()
        XCTAssertEqual(fixture.network.count(path: "/events", year: 2032), 0)
        XCTAssertEqual(fixture.network.count(path: "/events/source-status", year: 2032), 0)
        XCTAssertEqual(model.saved[2032], prior)
        model.fetch(year: 2032)
        await dataFinished(model)
        XCTAssertEqual(fixture.network.count(path: "/events", year: 2032), 1)
        XCTAssertEqual(fixture.network.count(path: "/events/source-status", year: 2032), 1)
        XCTAssertEqual(model.saved[2032]?.payload, prior.payload)
        XCTAssertNil(model.checkSource(year: 2032))
        XCTAssertEqual(fixture.network.unexpected, 0)
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

    func testManualCheckingFollowsUpWithinSixtySecondsDuringEachPriorFailureBackoff() async throws {
        for failures in 1...3 {
            let f = try Fixture(), clock = RetryClock()
            defer { f.clean(); clock.cancel() }
            f.model = f.makeModel(waitForSourceRetry:clock.wait)
            f.model.loadIfNeeded()
            f.network.successAt = "2032-05-01T03:00:00Z"
            let initial = try XCTUnwrap(f.model.checkSource(year:2032,force:true))
            _ = await initial.value
            let lastSuccess = try XCTUnwrap(f.model.sourcePresentation(year:2032)?.lastSuccessAt)
            f.network.statusHTTP = 503
            for _ in 0..<failures {
                f.now.addTimeInterval(1)
                let failed = try XCTUnwrap(f.model.checkSource(year:2032,force:true))
                let succeeded = await failed.value
                XCTAssertFalse(succeeded)
            }
            let store = try SchoolEventsStore(root:f.root.appendingPathComponent("SchoolEventsAPI"))
            let oldRetry = try XCTUnwrap(store.loadRefreshState(year:2032)).source
            XCTAssertEqual(oldRetry.retryAt?.timeIntervalSince(f.now),Double([900,1800,3600][failures-1]))
            f.now.addTimeInterval(1)
            f.network.statusHTTP = 200; f.network.checking = true
            f.model.fetch(year:2032)
            await dataFinished(f.model)
            XCTAssertEqual(try store.loadRefreshState(year:2032)?.source.firstFailureAt,oldRetry.firstFailureAt)
            XCTAssertEqual(try store.loadRefreshState(year:2032)?.followUpAt,f.now.addingTimeInterval(60))
            XCTAssertEqual(f.model.sourcePresentation(year:2032)?.lastSuccessAt,lastSuccess)
            XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year:2032)).message.contains("確認中"))
            XCTAssertEqual(f.network.count(path:"/events/source-status",year:2032),failures+2)
            try await finishRetry(f,clock)
            XCTAssertEqual(f.network.count(path:"/events/source-status",year:2032),failures+3)
            XCTAssertEqual(try store.loadRefreshState(year:2032)?.followUpsRemaining,2)
            XCTAssertEqual(f.model.sourcePresentation(year:2032)?.lastSuccessAt,lastSuccess)
            XCTAssertEqual(f.network.unexpected,0)
        }
    }

    func testManualCancellationDoesNotImmediatelyRestartExpiredAutomaticBodyRequest() async throws {
        for expired in [false, true] {
            let f = try Fixture()
            defer { f.clean() }
            let store = try SchoolEventsStore(root:f.root.appendingPathComponent("SchoolEventsAPI"))
            for (year,age) in [(2032, expired ? 3601 : 60),(2033,60)] {
                let bytes = SourceStatusScenario.events(year:year)
                let checkedAt = f.now.addingTimeInterval(-Double(age))
                try store.save(.decode(bytes,requestedYear:year),apiETag:"W/\""+SourceStatusScenario.hash(bytes)+"\"",
                    fetchedAt:checkedAt,lastEventsCheckedAt:checkedAt)
            }
            f.model = f.makeModel()
            f.model.loadIfNeeded()
            await f.model.checkSource(year:2032)?.value
            await f.model.checkSource(year:2033)?.value
            let started = expectation(description:"body is in flight before cancellation")
            f.network.holdBody = true; f.network.started = started
            f.model.refreshAtStartup()
            if expired { await fulfillment(of:[started],timeout:5) }
            f.model.fetch(year:2032)
            if !expired { await fulfillment(of:[started],timeout:5) }
            f.model.cancel()
            f.network.holdBody = false; f.network.updated = true; f.network.release()
            await dataFinished(f.model)
            f.model.reevaluate()
            XCTAssertFalse(f.model.isChecking(year:2032))
            XCTAssertEqual(f.network.count(path:"/events",year:2032),1)
            XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title,"架空保存行事")
            XCTAssertEqual(f.model.message,SchoolEventsError.cancelled.localizedDescription)

            f.now.addTimeInterval(3600)
            f.model.reevaluate()
            XCTAssertTrue(f.model.isChecking(year:2033))
            let otherYear = try XCTUnwrap(f.model.checkSource(year:2033))
            _ = await otherYear.value
            XCTAssertEqual(f.network.count(path:"/events",year:2033),1)
            XCTAssertFalse(f.model.isChecking(year:2032))
            f.model.setSourceChecksActive(false); f.model.setSourceChecksActive(true)
            let resumed = try XCTUnwrap(f.model.checkSource(year:2032))
            _ = await resumed.value
            XCTAssertEqual(f.network.count(path:"/events",year:2032),2)
            XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title,"架空更新行事")
            XCTAssertEqual(f.network.unexpected,0)
        }
    }

    func testManualSchoolEventsCancellationAfterJoiningStatusAlsoStopsTheBodyRequest() async throws {
        let f = try Fixture()
        defer { f.clean() }
        let statusStarted = expectation(description:"source-only check started")
        f.network.holdStatus = true; f.network.started = statusStarted
        let source = try XCTUnwrap(f.model.checkSource(year:2032))
        await fulfillment(of:[statusStarted],timeout:5)
        f.model.fetch(year:2032)
        let bodyStarted = expectation(description:"joined manual check escalated to body")
        f.network.holdStatus = false; f.network.holdBody = true; f.network.started = bodyStarted
        f.network.release()
        let sourceSucceeded = await source.value
        XCTAssertTrue(sourceSucceeded)
        await fulfillment(of:[bodyStarted],timeout:5)
        f.model.cancel()
        f.network.holdBody = false; f.network.updated = true; f.network.release()
        await dataFinished(f.model)
        XCTAssertEqual(f.network.count(path:"/events",year:2032),1)
        XCTAssertEqual(f.network.count(path:"/events/source-status",year:2032),1)
        XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title,"架空保存行事")
        XCTAssertEqual(f.model.message,SchoolEventsError.cancelled.localizedDescription)
        XCTAssertFalse(f.model.isChecking(year:2032))
        XCTAssertEqual(f.network.unexpected,0)
    }

    func testCheckingStopsAfterExactlyThreeAdditionalRequestsAndRestartsAfterPersistentDelay() async throws {
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
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("後で自動確認"))
        f.now.addTimeInterval(60)
        let display = try XCTUnwrap(f.model.sourcePresentation(year: 2032))
        XCTAssertTrue(display.message.contains("後で自動確認")); XCTAssertFalse(display.warning)
        XCTAssertNotNil(display.lastSuccessAt); XCTAssertTrue(try XCTUnwrap(display.lastSuccessfulMessage).contains("一致"))
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 0)
        f.model.cancel()
        f.model = f.makeModel()
        f.model.loadIfNeeded()
        f.now.addTimeInterval(839)
        XCTAssertNil(f.model.checkSource(year: 2032))
        f.now.addTimeInterval(1)
        f.network.checking = false
        f.network.successAt = "2032-05-01T03:20:00Z"
        let resumed = try XCTUnwrap(f.model.checkSource(year: 2032))
        _ = await resumed.value
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 5)
        XCTAssertNil(f.model.sourceErrors[2032])
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
        f.model.setSourceChecksActive(false)
        f.network.updated = true; f.network.checking = false
        let refreshed = await f.model.refreshInBackground(); XCTAssertTrue(refreshed)
        clock.advance(); await Task.yield()
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title, "架空更新行事")
        f.model.setSourceChecksActive(true)
        f.network.oldStatusVersion = true
        await f.model.checkSource(year: 2032, force: true)?.value
        XCTAssertEqual(clock.scheduled, 1); XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("配信版または元PDFが一致しません"))
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 2)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 4)
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

    func testCheckingBoundaryIsSixtySecondsAndCoalescesInFlightResponses() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceRetry: clock.wait)
        f.model.loadIfNeeded(); f.network.checking = true
        await f.model.checkSource(year: 2032)?.value
        try await pendingRetry(clock)
        f.now.addTimeInterval(59)
        XCTAssertNil(f.model.checkSource(year: 2032))
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        f.network.checking = false
        f.now.addTimeInterval(1)
        let first = try XCTUnwrap(f.model.checkSource(year: 2032))
        let second = try XCTUnwrap(f.model.checkSource(year: 2032))
        _ = await first.value; _ = await second.value
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        XCTAssertNil(f.model.checkSource(year: 2032))
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
    }

    func testDailyExpiryStartsAutomaticRequestBeforeTwelveHourCacheExpires() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.now.addTimeInterval(23 * 3_600)
        let store = try SchoolEventsStore(root: f.root.appendingPathComponent("SchoolEventsAPI"))
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("SchoolEventsAPI/events-2033.json"))
        let value = try XCTUnwrap(store.loadAll()[2032])
        try store.save(value.payload, apiETag: value.apiETag, fetchedAt: value.fetchedAt,
                       lastEventsCheckedAt: f.now.addingTimeInterval(1))
        f.now.addTimeInterval(1)
        f.model = f.makeModel(waitForSourceExpiry: clock.wait)
        f.model.loadIfNeeded()
        f.model.refreshAtStartup()
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 0)
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        if clock.pending.isEmpty {
            let scheduled = expectation(description: "source calendar deadline automatically scheduled")
            clock.onScheduled = { scheduled.fulfill() }
            await fulfillment(of: [scheduled], timeout: 5)
            clock.onScheduled = nil
        }
        XCTAssertEqual(try XCTUnwrap(clock.pending.first).0, 3_599, accuracy: 0.001)
        let received = expectation(description: "deadline triggered a real source request")
        let subscription = f.model.$sourceStatuses.dropFirst().first().sink { _ in received.fulfill() }
        f.now.addTimeInterval(3_599)
        f.network.stale = true
        clock.advance()
        await fulfillment(of: [received], timeout: 5)
        subscription.cancel()
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        XCTAssertEqual(f.model.sourcePresentation(year: 2032)?.lastSuccessAt,
                       SchoolEventsSourceStatus.date(f.network.successAt))
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        XCTAssertNil(f.model.checkSource(year: 2032))
    }

    func testOfflineCacheExpiryPublishesPresentationWithoutRequestingData() async throws {
        let f = try Fixture(), clock = RetryClock()
        defer { f.clean(); clock.cancel() }
        f.model = f.makeModel(waitForSourceExpiry: clock.wait)
        f.model.loadIfNeeded()
        await f.model.checkSource(year: 2032)?.value
        f.model.setNetworkReachable(false)
        let lastSuccess = f.model.sourcePresentation(year: 2032)?.lastSuccessAt
        XCTAssertNotNil(lastSuccess)
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("一致"))
        if clock.pending.isEmpty {
            let scheduled = expectation(description: "cached status expiry scheduled while offline")
            clock.onScheduled = { scheduled.fulfill() }
            await fulfillment(of: [scheduled], timeout: 5)
            clock.onScheduled = nil
        }
        XCTAssertEqual(try XCTUnwrap(clock.pending.first).0, 43_200)
        let expired = expectation(description: "visible cached status is invalidated")
        let subscription = f.model.$sourcePresentationRevision.dropFirst().first().sink { _ in expired.fulfill() }
        f.now.addTimeInterval(43_200); clock.advance()
        await fulfillment(of: [expired], timeout: 5)
        subscription.cancel()
        let presentation = try XCTUnwrap(f.model.sourcePresentation(year: 2032))
        XCTAssertTrue(presentation.message.contains("古く"))
        XCTAssertEqual(presentation.lastSuccessAt, lastSuccess)
        XCTAssertFalse(presentation.warning)
        XCTAssertEqual(f.model.projectionBuildCount, 1)
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 0)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 1)
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
        let firstAdopted = f.model.saved[2032]?.fetchedAt
        f.model.refreshAtStartup()
        for year in [2032, 2033] { await f.model.checkSource(year: year)?.value }
        XCTAssertEqual(f.model.saved[2032]?.lastEventsCheckedAt, f.now)
        XCTAssertEqual(f.model.saved[2032]?.fetchedAt, firstAdopted)
        XCTAssertNil(f.model.sourceCheckMessage)
        for year in [2032, 2033] {
            XCTAssertEqual(f.network.count(path: "/events", year: year), 1)
            XCTAssertEqual(f.network.count(path: "/events/source-status", year: year), 1)
        }
        f.now.addTimeInterval(43_200)
        f.model.refreshAtStartup()
        for year in [2032, 2033] { await f.model.checkSource(year: year)?.value }
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 2)
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
        XCTAssertTrue(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).message.contains("配信版または元PDFが一致しません"))
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
        f.model.setSourceChecksActive(false)
        XCTAssertFalse(f.model.isChecking(year: 2032))
        XCTAssertNil(f.model.sourceStatuses[2032])
        f.network.updated = true
        f.network.holdStatus = false
        // Start the next phase before awaiting the cancelled foreground owner.
        let updated = await f.model.refreshInBackground(); XCTAssertTrue(updated)
        XCTAssertEqual(f.model.saved[2032]?.payload.events.first?.title, "架空更新行事")
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 2)
        let adopted = f.model.sourceStatuses[2032]
        f.network.oldStatusVersion = true
        f.network.release()
        let cancelledForeground = await old.value
        XCTAssertFalse(cancelledForeground)
        XCTAssertEqual(f.model.sourceStatuses[2032], adopted)
        let cancelledStart = expectation(description: "cancellable metadata owner")
        f.network.holdStatus = true; f.network.started = cancelledStart
        f.model.setSourceChecksActive(true)
        let cancelled = try XCTUnwrap(f.model.checkSource(year: 2032, force: true))
        await fulfillment(of: [cancelledStart], timeout: 5)
        f.model.cancel(); await cancelled.value
        XCTAssertEqual(f.model.sourceStatuses[2032], adopted); XCTAssertFalse(f.model.busy)
        f.network.holdStatus = false; f.network.oldStatusVersion = false
        f.network.release()
        await f.model.checkSource(year: 2032)?.value
        XCTAssertFalse(try XCTUnwrap(f.model.sourcePresentation(year: 2032)).warning)
        XCTAssertEqual(f.network.unexpected, 0)
    }
}

extension SchoolEventsSourceModelTests {
    func testV2MigrationUsesAnIndependentValidatorAndPreservesV1UntilValidatedSave() async throws {
        let f = try Fixture()
        defer { f.clean() }
        f.model = f.makeModel(format: .v2)
        f.model.loadIfNeeded()
        let old = try XCTUnwrap(f.model.saved[2032])
        f.network.bodyHTTP = 503
        f.model.fetch(year: 2032); await dataFinished(f.model)
        XCTAssertEqual(f.model.saved[2032]?.payload.format, .v1)
        XCTAssertEqual(f.model.saved[2032]?.fetchedAt, old.fetchedAt)
        XCTAssertNil(f.model.saved[2032]?.lastEventsCheckedAt)
        XCTAssertNil(f.network.bodyValidators().first ?? nil)
        let reopened = f.makeModel(format: .v2)
        reopened.loadIfNeeded()
        defer { reopened.cancel() }
        XCTAssertEqual(reopened.saved[2032]?.payload, old.payload)

        f.network.bodyHTTP = 200
        f.model.fetch(year: 2032); await dataFinished(f.model)
        let adopted = try XCTUnwrap(f.model.saved[2032])
        XCTAssertEqual(adopted.payload.format, .v2)
        XCTAssertEqual(adopted.payload.identifiedEvents?.first?.eventId, "stable-fixture")
        XCTAssertEqual(adopted.lastEventsCheckedAt, f.now)
        XCTAssertEqual(f.model.sourceStatuses[2032]?.requestedTarget?.format, .v2)
        XCTAssertTrue(f.model.sourceStatuses[2032]?.matches(adopted) == true)
        XCTAssertEqual(f.network.bodyValidators(), [nil, nil])

        f.now.addTimeInterval(3_600)
        f.model.fetch(year: 2032); await dataFinished(f.model)
        XCTAssertEqual(f.model.saved[2032]?.fetchedAt, adopted.fetchedAt)
        XCTAssertEqual(f.model.saved[2032]?.lastEventsCheckedAt, f.now)
        XCTAssertEqual(f.network.bodyValidators().last ?? nil, adopted.apiETag)
        XCTAssertEqual(f.network.unexpected, 0)
    }

    func testBodyTimeoutBackoffAndRepeated200RespectPersistedConfirmation() async throws {
        let f = try Fixture()
        defer { f.clean() }
        f.model.refreshAtStartup()
        for year in [2032, 2033] { await f.model.checkSource(year: year)?.value }
        let original = try XCTUnwrap(f.model.saved[2032])
        f.now.addTimeInterval(3_599)
        f.model.reevaluate()
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 1)
        f.network.bypassNotModified = true
        f.network.bodyHTTP = 503
        f.now.addTimeInterval(1)
        f.model.reevaluate()
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 2)
        XCTAssertEqual(f.model.saved[2032]?.lastEventsCheckedAt, original.lastEventsCheckedAt)

        f.now.addTimeInterval(899)
        f.model.setNetworkReachable(false)
        f.model.reevaluate()
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 2)
        f.network.bodyHTTP = 200
        f.now.addTimeInterval(1)
        f.model.setNetworkReachable(true)
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 3)
        XCTAssertEqual(f.model.saved[2032]?.lastEventsCheckedAt, f.now)
        XCTAssertEqual(f.model.saved[2032]?.fetchedAt, original.fetchedAt)
        XCTAssertEqual(f.model.saved[2032]?.payload, original.payload)
        XCTAssertEqual(f.network.count(path: "/events", year: 2034), 0)
    }

    func testDifferencePersistsAndMismatchRecoveryOnlyChecksOneBody() async throws {
        let f = try Fixture()
        defer { f.clean() }
        f.network.sourceDifference = true
        await f.model.checkSource(year: 2032)?.value
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 1)
        XCTAssertEqual(f.model.countdownSourceState(year: 2032, at: f.now), .sourceDifference)
        XCTAssertTrue(f.model.sourcePresentation(year: 2032)?.warning == true)
        f.network.statusHTTP = 503
        await f.model.checkSource(year: 2032, force: true)?.value
        let restored = f.makeModel()
        restored.loadIfNeeded()
        defer { restored.cancel() }
        XCTAssertEqual(restored.countdownSourceState(year: 2032, at: f.now), .sourceDifference)
        XCTAssertTrue(restored.sourcePresentation(year: 2032)?.warning == true)

        f.now.addTimeInterval(60)
        f.network.updated = true
        f.network.statusHTTP = 200
        f.network.sourceDifference = false
        f.network.successAt = "2032-05-01T03:05:05Z"
        await restored.checkSource(year: 2032, force: true)?.value
        XCTAssertEqual(restored.saved[2032]?.payload.events.first?.title, "架空更新行事")
        XCTAssertEqual(restored.countdownSourceState(year: 2032, at: f.now), .available)
        XCTAssertFalse(restored.sourcePresentation(year: 2032)?.warning == true)
        XCTAssertEqual(f.network.count(path: "/events", year: 2032), 2)
        XCTAssertEqual(f.network.count(path: "/events/source-status", year: 2032), 3)
    }

    func testCountdownDistinguishesAnActiveSourceCheckFromUnknownAndFailure() async throws {
        let f = try Fixture()
        defer { f.clean() }
        XCTAssertEqual(f.model.countdownSourceState(year: 2032, at: f.now), .sourcePending)
        f.network.holdStatus = true
        f.network.statusHTTP = 503
        let started = expectation(description: "original PDF comparison is in flight")
        f.network.started = started
        let request = try XCTUnwrap(f.model.checkSource(year: 2032))
        await fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(f.model.countdownSourceState(year: 2032, at: f.now), .sourceChecking)
        f.network.holdStatus = false
        f.network.release()
        _ = await request.value
        XCTAssertEqual(f.model.countdownSourceState(year: 2032, at: f.now), .sourceCheckFailed)
        let restored = f.makeModel()
        restored.loadIfNeeded()
        defer { restored.cancel() }
        XCTAssertEqual(restored.countdownSourceState(year: 2032, at: f.now), .sourcePending)
        for status: CountdownAvailability in [.sourcePending, .sourceChecking, .sourceCheckFailed, .sourceDifference] {
            XCTAssertFalse(status.allowsNotification)
            XCTAssertTrue(status.presentsDatesOnHome)
        }
    }
}
