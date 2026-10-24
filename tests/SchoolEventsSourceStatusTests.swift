import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import TakupokeParsing

final class SchoolEventsSourceStatusTests: XCTestCase {
    private let hash = String(repeating: "a", count: 64)
    private let revision = String(repeating: "b", count: 64)
    private func saved(year: Int = 2032, hash: String? = nil) -> SavedSchoolEvents {
        SavedSchoolEvents(fetchedAt: Date(), payload: SchoolEventsPayload(version: "v1", schoolYear: year,
            sourcePdfSha256: hash ?? self.hash, sourcePdfETag: "\"fictional-etag\"",
            events: [.init(startDate: "2032-04-01", endDate: "2032-04-01", title: "架空行事", tag: "行事")]),
            apiETag: "W/\"\(revision)\"")
    }
    private func payload(_ updates: [String: Any] = [:]) throws -> Data {
        var value: [String: Any] = ["version": "v1", "schoolYear": 2032, "dataVersion": "sha256-\(revision)",
            "adoptedSourcePdfSha256": hash, "status": "matched", "lastSuccessfulStatus": "matched",
            "lastSuccessAt": "2032-04-01T00:00:00.000Z", "lastAttemptAt": "2032-04-01T00:00:00.000Z",
            "nextAttemptAt": "2032-04-02T00:00:00.000Z", "checking": false, "stale": false]
        value.merge(updates, uniquingKeysWith: { _, new in new })
        return try JSONSerialization.data(withJSONObject: value)
    }
    func testMatchingUsesYearHashAndExactDeliveredVersion() throws {
        let status = try SchoolEventsSourceStatus.decode(payload(), year: 2032)
        XCTAssertTrue(status.applies(to: saved()))
        XCTAssertFalse(status.applies(to: saved(year: 2033)))
        XCTAssertFalse(status.applies(to: saved(hash: String(repeating: "c", count: 64))))
        let oldVersion = try SchoolEventsSourceStatus.decode(payload(["dataVersion": "sha256-\(hash)"]), year: 2032)
        XCTAssertFalse(oldVersion.applies(to: saved()))
        XCTAssertTrue(oldVersion.message(for: saved(), now: Date()).contains("異なる配信版"))
        // Source ETag never determines a match; adopted hash and API data version do.
        XCTAssertTrue(status.message(for: saved(), now: Date()).contains("登録元と一致"))
    }
    func testUnknownDifferentUnavailableCheckingAndStaleRemainDistinct() throws {
        let now = SchoolEventsSourceStatus.date("2032-04-01T01:00:00Z")!
        let difference = try SchoolEventsSourceStatus.decode(payload(["status": "source_differs", "lastSuccessfulStatus": "source_differs"]), year: 2032)
        XCTAssertTrue(difference.message(for: saved(), now: now).contains("内容確認待ち"))
        let unavailable = try SchoolEventsSourceStatus.decode(payload(["status": "unavailable"]), year: 2032)
        let message = unavailable.message(for: saved(), now: now.addingTimeInterval(48 * 3600), networkFailed: true)
        for text in ["確認できません", "前回は登録元と一致", "最終成功確認", "日本時間", "古くなっています", "状態APIに接続できません"] {
            XCTAssertTrue(message.contains(text), text)
        }
        let unknown = try SchoolEventsSourceStatus.decode(payload(["status": "unknown", "lastSuccessfulStatus": NSNull(),
            "lastSuccessAt": NSNull(), "checking": true, "stale": true]), year: 2032)
        XCTAssertTrue(unknown.message(for: saved(), now: now).contains("未確認"))
        XCTAssertTrue(unknown.message(for: saved(), now: now).contains("確認中"))
    }
    func testStatusCacheExpiresAtTwelveHoursAndCheckingAtOneMinute() throws {
        let now = Date()
        let status = try SchoolEventsSourceStatus.decode(payload(), year: 2032)
        let cache = CachedSchoolEventsSourceStatus(fetchedAt: now, value: status)
        XCTAssertTrue(cache.isFresh(for: saved(), now: now.addingTimeInterval(12 * 3600 - 1)))
        XCTAssertFalse(cache.isFresh(for: saved(), now: now.addingTimeInterval(12 * 3600)))
        XCTAssertFalse(cache.isFresh(for: saved(), now: now.addingTimeInterval(-1)))
        XCTAssertFalse(cache.isFresh(for: saved(year: 2033), now: now))
        let checking = CachedSchoolEventsSourceStatus(fetchedAt: now,
            value: try SchoolEventsSourceStatus.decode(payload(["checking": true]), year: 2032))
        XCTAssertTrue(checking.isFresh(for: saved(), now: now.addingTimeInterval(59)))
        XCTAssertFalse(checking.isFresh(for: saved(), now: now.addingTimeInterval(60)))
    }
    func testCacheRoundTripAndCorruptionCannotModifySavedEvents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SchoolEventsSourceStatusStore(root: root)
        let original = saved()
        let cache = CachedSchoolEventsSourceStatus(fetchedAt: Date(), value: try SchoolEventsSourceStatus.decode(payload(), year: 2032))
        try store.save(cache)
        XCTAssertEqual(store.load(year: 2032)?.value, cache.value)
        XCTAssertNil(store.load(year: 2033))
        try Data("broken fictional cache".utf8).write(to: root.appendingPathComponent("source-status-2032.json"))
        XCTAssertNil(store.load(year: 2032))
        XCTAssertEqual(original.payload.events.first?.title, "架空行事")
    }
    func testMalformedStatusCannotClaimAnUnverifiedMatch() throws {
        for invalid: [String: Any] in [
            ["version": "v2"], ["schoolYear": 2033], ["dataVersion": "v1"], ["status": "fictional"],
            ["adoptedSourcePdfSha256": "bad"], ["lastSuccessAt": "bad"], ["lastSuccessAt": NSNull()],
            ["lastSuccessfulStatus": "unknown"], ["lastSuccessfulStatus": "source_differs"],
        ] {
            XCTAssertThrowsError(try SchoolEventsSourceStatus.decode(payload(invalid), year: 2032))
        }
        XCTAssertThrowsError(try SchoolEventsSourceStatus.decode(Data(repeating: 32, count: 8_193), year: 2032))
    }

    func testClientUsesOnlyGETStatusAPIAndRejectsErrorsWithoutDeletingLastSuccess() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SourceStatusURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        SourceStatusURLProtocol.responseData = try payload()
        SourceStatusURLProtocol.statusCode = 200
        let status = try await SchoolEventsSourceStatusClient.fetch(year: 2032, session: session)
        XCTAssertEqual(status.status, .matched)
        XCTAssertEqual(SourceStatusURLProtocol.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(SourceStatusURLProtocol.lastRequest?.url?.path, "/events/source-status")
        XCTAssertEqual(SourceStatusURLProtocol.lastRequest?.url?.query, "schoolYear=2032")
        SourceStatusURLProtocol.statusCode = 503
        do {
            _ = try await SchoolEventsSourceStatusClient.fetch(year: 2032, session: session)
            XCTFail("503 must fail")
        } catch { XCTAssertEqual(status.status, .matched) }
    }
}

private final class SourceStatusURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        guard request.url?.scheme == "https", request.url?.host == "takupoke-api.n624.jp",
              request.url?.path == "/events/source-status", request.httpMethod == "GET" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
