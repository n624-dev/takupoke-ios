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
                "checking": false, "stale": false])
            transport.finish(status: statusHTTP, data: data)
        }
    }
}

@MainActor
final class SchoolEventsSourceModelTests: XCTestCase {
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
        func makeModel() -> SchoolEventsModel {
            SchoolEventsModel(storeRoot: root, eventsEndpoint: URL(string: "https://source.example.invalid/events")!,
                makeSession: {
                    let config = URLSessionConfiguration.ephemeral
                    config.protocolClasses = [SourceStatusTransport.self]; config.urlCache = nil
                    return URLSession(configuration: config)
                }, now: { [unowned self] in self.now })
        }
        func clean() { model.cancel(); SourceStatusTransport.use(nil); try? FileManager.default.removeItem(at: root) }
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
