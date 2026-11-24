import Foundation
import XCTest
@testable import TakupokeParsing

final class ServiceStatusTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func node(_ id: String, _ type: String, _ attributes: [String: Any]) -> [String: Any] {
        ["id": id, "type": type, "attributes": attributes]
    }
    private func node(_ id: String, _ attributes: [String: Any]) -> [String: Any] {
        node(id, "status_page_resource", attributes)
    }
    private func resource(_ id: String, status: String = "operational") -> [String: Any] {
        node(id, ["resource_type": "Monitor", "status": status, "availability": 0.999806,
                  "public_name": "架空サービス", "status_history": []])
    }
    private func reference(_ id: String, _ type: String = "status_page_resource") -> [String: String] { ["id": id, "type": type] }
    private func payload(_ nodes: [[String: Any]], references: [[String: String]]? = nil,
                         reports: [[String: String]] = [], page: String = "267223") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "data": ["id": page, "type": "status_page", "attributes": ["aggregate_state": "downtime"],
                     "relationships": ["resources": ["data": references ?? [reference("9028864"), reference("9028865")]],
                                       "status_reports": ["data": reports]]],
            "included": nodes
        ])
    }

    func testUsesLinkedIDsAndIgnoresUnrelatedOutageAndNames() throws {
        let data = try payload([resource("unrelated", status: "downtime"), resource("9028865"), resource("9028864")])
        let value = try ServiceStatusSnapshot.decode(data)
        XCTAssertEqual(value.resources.count, 2)
        XCTAssertEqual(value.resources[.api]?.state, .operational)
        XCTAssertEqual(value.resources[.authentication]?.state, .operational)
        XCTAssertEqual(value.resources[.api]?.availability, 0.999806)
    }

    func testUnlinkedMissingDuplicateWrongTypeAndUnknownStateNeverBecomeHealthy() throws {
        let api = resource("9028864")
        let cases: [(Data, ServiceStatusSnapshot.State?)] = [
            (try payload([api], references: []), nil),
            (try payload([]), nil),
            (try payload([api, api]), nil),
            (try payload([api], references: [reference("9028864"), reference("9028864")]), nil),
            (try payload([node("9028864", "status_page_section", ["status": "operational"])]), nil),
            (try payload([resource("9028864", status: "new_unknown_state")]), .unknown),
            (try payload([resource("9028864", status: "recovered")]), .unknown)
        ]
        for (data, expected) in cases {
            let value = try ServiceStatusSnapshot.decode(data)
            XCTAssertEqual(value.resources[.api]?.state, expected)
            var cache = ServiceStatusCache()
            cache.accept(value, etag: nil, at: now)
            XCTAssertEqual(cache.presentation(for: .api, at: now).tone, .unknown)
        }
    }

    func testHistoryKeepsUnmonitoredRecoveryAndUnknownDaysWithoutInventingDates() throws {
        let history: [[String: Any]] = [
            ["day": "2032-04-03", "status": "recovered", "downtime_duration": 360.5],
            ["day": "2032-04-01", "status": "not_monitored"],
            ["day": "2032-04-02", "status": "unexpected"],
            ["day": "2032-02-31", "status": "operational"],
            ["day": "2032-04-04", "status": "operational"],
            ["day": "2032-04-04", "status": "downtime"]
        ]
        let data = try payload([node("9028864", ["resource_type": "Monitor", "status": "operational",
                                               "status_history": history, "availability": 99.95])])
        let value = try XCTUnwrap(try ServiceStatusSnapshot.decode(data).resources[.api])
        XCTAssertEqual(value.history.map(\.id), ["2032-04-01", "2032-04-02", "2032-04-03", "2032-04-04"])
        XCTAssertEqual(value.history.map(\.state), [.not_monitored, .unknown, .recovered, .unknown])
        XCTAssertEqual(value.history[2].downtime, 360.5)
        XCTAssertNil(value.availability, "Do not guess whether an invalid fraction means a percentage")
    }

    func testResolvedIncidentWithNullEndAndUnsortedUpdatesUsesRelationships() throws {
        func affected(_ id: String, _ status: String) -> [[String: String]] { [["status_page_resource_id": id, "status": status]] }
        var report = node("report", "status_report", ["title": "架空サービス is down", "ends_at": NSNull(),
            "aggregate_state": "resolved", "starts_at": "2032-04-01T00:00:00.000Z",
            "affected_resources": affected("9028864", "resolved")])
        report["relationships"] = ["status_updates": ["data": [reference("down", "status_update"), reference("up", "status_update")]]]
        let down = node("down", "status_update", ["message": "架空サービス停止", "published_at": "2032-04-01T00:00:00Z",
                                                   "affected_resources": affected("9028864", "downtime")])
        let up = node("up", "status_update", ["message": "架空サービス復旧", "published_at": "2032-04-01T00:06:00.000Z",
                                               "affected_resources": affected("9028864", "resolved")])
        let unrelated = node("unrelated", "status_report", ["title": "別の架空サービス停止", "affected_resources": affected("other", "downtime")])
        let data = try payload([resource("9028864"), resource("9028865"), report, down, up, unrelated],
                               reports: [reference("report", "status_report"), reference("unrelated", "status_report")])
        let value = try ServiceStatusSnapshot.decode(data)
        let incident = try XCTUnwrap(value.resources[.api]?.incidents.first)
        XCTAssertEqual(value.resources[.api]?.incidents.count, 1)
        XCTAssertTrue(incident.resolved)
        XCTAssertEqual(incident.updates.map(\.id), ["up", "down"])
        XCTAssertTrue(try XCTUnwrap(value.resources[.authentication]).incidents.isEmpty)
        var ambiguous = report
        var attributes = try XCTUnwrap(ambiguous["attributes"] as? [String: Any])
        attributes["affected_resources"] = affected("9028864", "resolved") + affected("9028864", "downtime")
        ambiguous["attributes"] = attributes
        let conflicted = try ServiceStatusSnapshot.decode(payload([resource("9028864"), ambiguous],
            reports: [reference("report", "status_report")]))
        XCTAssertEqual(conflicted.resources[.api]?.incidents.first?.state, "unknown")
        XCTAssertFalse(try XCTUnwrap(conflicted.resources[.api]?.incidents.first).resolved)
    }

    func testCacheFailureExpiryAndClockRollbackRetainEvidenceButNotCurrentNormal() throws {
        let snapshot = try ServiceStatusSnapshot.decode(payload([resource("9028864")]))
        var cache = ServiceStatusCache()
        XCTAssertThrowsError(try cache.revalidate(at: now))
        cache.accept(snapshot, etag: nil, at: now)
        XCTAssertThrowsError(try cache.revalidate(at: now), "An unsolicited 304 must not renew unvalidated evidence")
        cache.accept(snapshot, etag: "\"fictional\"", at: now)
        XCTAssertThrowsError(try cache.revalidate(responseETag: "\"different\"", at: now.addingTimeInterval(1)))
        XCTAssertEqual(cache.checkedAt, now)
        try cache.revalidate(responseETag: "W/\"fictional\"", at: now)
        XCTAssertEqual(cache.presentation(for: .api, at: now).tone, .good)
        for date in [now.addingTimeInterval(180), now.addingTimeInterval(-1)] {
            XCTAssertEqual(cache.presentation(for: .api, at: date).tone, .unknown)
        }
        cache.recordFailure()
        XCTAssertEqual(cache.snapshot, snapshot)
        XCTAssertEqual(cache.checkedAt, now)
        XCTAssertEqual(cache.presentation(for: .api, at: now).tone, .unknown)
        let later = now.addingTimeInterval(200)
        try cache.revalidate(at: later)
        XCTAssertEqual(cache.checkedAt, later)
        XCTAssertEqual(cache.presentation(for: .api, at: later).tone, .good)
        XCTAssertEqual(cache.presentation(for: .authentication, at: later).tone, .unknown)
    }

    func testMissingResourcesKeepTheirPreviousHistoryWithoutRevalidatingThem() throws {
        let original = try ServiceStatusSnapshot.decode(payload([resource("9028864"), resource("9028865")]))
        var cache = ServiceStatusCache()
        cache.accept(original, etag: "\"first\"", at: now)
        let partial = try ServiceStatusSnapshot.decode(payload([resource("9028865", status: "downtime")]))
        let later = now.addingTimeInterval(10)
        cache.accept(partial, etag: "\"partial\"", at: later)
        XCTAssertEqual(cache.presentation(for: .api, at: later).tone, .unknown)
        XCTAssertEqual(cache.presentation(for: .authentication, at: later).tone, .unavailable)
        XCTAssertEqual(cache.retained[.api]?.value, original.resources[.api])
        XCTAssertEqual(cache.retained[.api]?.checkedAt, now)
        try cache.revalidate(at: later.addingTimeInterval(10))
        XCTAssertEqual(cache.retained[.api]?.checkedAt, now)
        XCTAssertEqual(cache.retained[.authentication]?.checkedAt, later.addingTimeInterval(10))
        XCTAssertFalse(cache.hasCurrentResource(.api, at: later.addingTimeInterval(10)))
        let ambiguous = try ServiceStatusSnapshot.decode(payload([resource("9028864"), resource("9028864")]))
        cache.accept(ambiguous, etag: nil, at: later.addingTimeInterval(20))
        XCTAssertEqual(cache.retained[.api]?.value, original.resources[.api])
        XCTAssertEqual(cache.presentation(for: .api, at: later.addingTimeInterval(20)).tone, .unknown)
    }

    func testInvalidEnvelopeAndOversizedResponseAreRejected() throws {
        XCTAssertThrowsError(try ServiceStatusSnapshot.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try ServiceStatusSnapshot.decode(payload([resource("9028864")], page: "another-page")))
        XCTAssertThrowsError(try ServiceStatusSnapshot.decode(Data(repeating: 32, count: ServiceStatusSnapshot.maximumBytes + 1)))
    }

    func testMonitorStalenessFieldAndPageMetadataAreNotProbeDates() throws {
        let value = try ServiceStatusSnapshot.decode(payload([node("9028864", ["resource_type": "Monitor", "status": "operational",
            "status_not_updated_since": "2032-04-01T00:00:00Z", "updated_at": "2032-04-01T00:00:00Z"])]))
        var cache = ServiceStatusCache()
        cache.accept(value, etag: nil, at: now)
        XCTAssertEqual(cache.checkedAt, now)
        XCTAssertEqual(cache.snapshot?.resources[.api]?.state, .operational)
    }
}
