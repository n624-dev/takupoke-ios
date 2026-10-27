import Foundation
import XCTest
@testable import TakupokeParsing

final class SchoolEventsSourceStatusTests: XCTestCase {
    private let instant = SchoolEventsSourceStatus.date("2032-05-01T03:04:05.842Z")!
    private let expectedSourceHash = String(repeating: "a", count: 64)
    private let version = "sha256-" + String(repeating: "b", count: 64)

    private func wire(status: String = "matched", success: String? = "matched",
                      date: String? = "2032-05-01T03:04:05.842Z", checking: Bool = false,
                      stale: Bool = false, year: Int = 2032, hash: String? = nil,
                      version: String? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["version": "v1", "schoolYear": year,
            "dataVersion": version ?? self.version, "adoptedSourcePdfSha256": hash ?? self.expectedSourceHash,
            "status": status, "lastSuccessfulStatus": success as Any? ?? NSNull(),
            "lastSuccessAt": date as Any? ?? NSNull(), "lastAttemptAt": "2032-05-01T03:04:05Z",
            "nextAttemptAt": "2032-05-02T03:04:05Z", "checking": checking, "stale": stale])
    }

    private func saved(year: Int = 2032, hash: String? = nil, version: String? = nil,
                       tag: String? = nil) -> SavedSchoolEvents {
        .init(fetchedAt: instant, payload: .init(version: "v1", schoolYear: year,
            sourcePdfSha256: hash ?? self.expectedSourceHash, sourcePdfETag: tag,
            events: [.init(startDate: "\(year)-04-01", endDate: "\(year)-04-01", title: "架空行事A", tag: "行事")]),
            apiETag: "W/\"" + String((version ?? self.version).dropFirst(7)) + "\"")
    }

    func testSourceStatusValidatesWireVersionYearHashesStatesAndFractionalDates() throws {
        let value = try SchoolEventsSourceStatus.decode(wire(), year: 2032)
        XCTAssertEqual(value.status, .matched)
        XCTAssertEqual(SchoolEventsSourceStatus.date(value.lastSuccessAt), instant)
        for data in [try wire(status: "invented"), try wire(year: 2033), try wire(hash: "abc"),
                     try wire(version: "sha256-ABC"), try wire(date: "not a date"),
                     try wire(success: nil, date: nil), try wire(success: "unavailable"),
                     try wire(success: "source_differs")] {
            XCTAssertThrowsError(try SchoolEventsSourceStatus.decode(data, year: 2032))
        }
        XCTAssertThrowsError(try SchoolEventsSourceStatus.decode(Data(repeating: 32, count: 16_385), year: 2032))
        XCTAssertEqual(try SchoolEventsSourceStatus.decode(wire(status: "unknown", success: nil, date: nil), year: 2032).status, .unknown)
        XCTAssertEqual(try SchoolEventsSourceStatus.decode(wire(status: "unavailable"), year: 2032).lastSuccessfulStatus, .matched)
    }

    func testMetadataBindingRequiresYearAdoptedHashAndEventsVersionButNotPDFETag() throws {
        let status = try SchoolEventsSourceStatus.decode(wire(), year: 2032)
        XCTAssertTrue(status.matches(saved(tag: "\"changed-etag-only\"")))
        XCTAssertFalse(status.matches(saved(year: 2033)))
        XCTAssertFalse(status.matches(saved(hash: String(repeating: "c", count: 64))))
        XCTAssertFalse(status.matches(saved(version: "sha256-" + String(repeating: "d", count: 64))))
        let legacy = SavedSchoolEvents(fetchedAt: instant, payload: saved().payload, apiETag: "\"arbitrary-v1\"")
        XCTAssertNil(legacy.dataVersion); XCTAssertFalse(status.matches(legacy))
        let noTag = SavedSchoolEvents(fetchedAt: instant, payload: saved().payload, apiETag: nil)
        XCTAssertNil(noTag.dataVersion); XCTAssertFalse(status.matches(noTag))
    }

    func testMetadataTTLIsTwelveHoursOrSixtySecondsWhileCheckingAndRejectsClockRollback() throws {
        let value = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try SchoolEventsSourceStatus.decode(wire(), year: 2032))
        XCTAssertTrue(value.isFresh(at: instant.addingTimeInterval(43_199)))
        XCTAssertFalse(value.isFresh(at: instant.addingTimeInterval(43_200)))
        XCTAssertFalse(value.isFresh(at: instant.addingTimeInterval(-1)))
        let checking = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try SchoolEventsSourceStatus.decode(wire(checking: true), year: 2032))
        XCTAssertTrue(checking.isFresh(at: instant.addingTimeInterval(59)))
        XCTAssertFalse(checking.isFresh(at: instant.addingTimeInterval(60)))
        let mismatched = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try SchoolEventsSourceStatus.decode(wire(hash: String(repeating: "c", count: 64)), year: 2032),
            requestedTarget: .init(saved()))
        // Cache a known mismatch without applying its observation to the old
        // payload or re-querying on every tab. A new target must re-evaluate.
        XCTAssertTrue(mismatched.canReuse(for: saved(), at: instant))
        XCTAssertFalse(mismatched.canReuse(for: saved(version: "sha256-" + String(repeating: "d", count: 64)), at: instant))
    }

    func testPresentationSeparatesMatchedDifferenceUnknownFailureStalenessAndSnapshotMismatch() throws {
        func present(_ data: Data, age: TimeInterval = 0, error: String? = nil) throws -> SchoolEventsSourcePresentation {
            .make(saved: saved(), cached: .init(receivedAt: instant,
                response: try .decode(data, year: 2032)), error: error, now: instant.addingTimeInterval(age))
        }
        XCTAssertFalse(try present(wire()).warning)
        let differs = try present(wire(status: "source_differs", success: "source_differs"))
        XCTAssertTrue(differs.warning); XCTAssertTrue(differs.message.contains("内容は確認待ち"))
        XCTAssertTrue(try present(wire(status: "unknown", success: nil, date: nil)).message.contains("未確認"))
        let failed = try present(wire(status: "unavailable"))
        XCTAssertTrue(failed.warning); XCTAssertEqual(failed.lastSuccessAt, instant)
        XCTAssertTrue(try XCTUnwrap(failed.lastSuccessfulMessage).contains("一致"))
        XCTAssertTrue(try present(wire(), age: 43_200).message.contains("古く"))
        XCTAssertTrue(try present(wire(stale: true)).message.contains("古く"))
        XCTAssertTrue(try present(wire(), error: "架空の通信失敗").message.contains("架空の通信失敗"))
        XCTAssertTrue(try present(wire(version: "sha256-" + String(repeating: "e", count: 64))).message.contains("配信版が一致しない"))
        XCTAssertNil(try present(wire(hash: String(repeating: "e", count: 64))).lastSuccessAt)
        XCTAssertTrue(SchoolEventsSourcePresentation.make(saved: saved(), cached: nil, error: nil, now: instant).warning)
    }

    func testExpiredCheckingDescribesThePastWithoutDiscardingSuccessfulEvidence() throws {
        let response = try SchoolEventsSourceStatus.decode(wire(checking: true), year: 2032)
        let cached = SavedSchoolEventsSourceStatus(receivedAt: instant, response: response)
        let restored = try JSONDecoder().decode(SavedSchoolEventsSourceStatus.self, from: JSONEncoder().encode(cached))
        for age in [59.0, 60, 61, 3_600, 43_200, 86_400] {
            let at = instant.addingTimeInterval(age)
            let display = SchoolEventsSourcePresentation.make(saved: saved(), cached: restored, error: nil, now: at)
            XCTAssertEqual(restored.isFresh(at: at), age < 60)
            XCTAssertEqual(display.message.contains("APIが元PDFを確認中です"), age < 60)
            XCTAssertEqual(display.message.contains("前回確認時"), age >= 60)
            XCTAssertTrue(display.warning)
            XCTAssertEqual(display.lastSuccessAt, instant)
            XCTAssertTrue(try XCTUnwrap(display.lastSuccessfulMessage).contains("一致"))
        }
        let failed = SchoolEventsSourcePresentation.make(saved: saved(), cached: restored,
            error: "架空の通信失敗", now: instant.addingTimeInterval(61))
        XCTAssertEqual(failed.message, "架空の通信失敗")
        XCTAssertEqual(failed.lastSuccessAt, instant)
        let mismatched = SchoolEventsSourcePresentation.make(saved: saved(hash: String(repeating: "c", count: 64)),
            cached: restored, error: nil, now: instant.addingTimeInterval(61))
        XCTAssertTrue(mismatched.message.contains("一致しない")); XCTAssertNil(mismatched.lastSuccessAt)
        XCTAssertEqual(cached.presentationDeadlines, [instant.addingTimeInterval(60), instant.addingTimeInterval(86_400)])
    }

    func testAdvisoryStorePreservesNewestSuccessAcrossUnavailableOlderEdgeAndReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        let first = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try .decode(wire(status: "source_differs", success: "source_differs"), year: 2032))
        let unavailable = SavedSchoolEventsSourceStatus(receivedAt: instant.addingTimeInterval(1),
            response: try .decode(wire(status: "unavailable", success: nil, date: nil), year: 2032), previous: first)
        try store.saveSourceStatus(unavailable)
        let restored = try XCTUnwrap(store.loadSourceStatus(year: 2032))
        XCTAssertEqual(restored, unavailable)
        let display = SchoolEventsSourcePresentation.make(saved: saved(), cached: restored, error: nil, now: instant)
        XCTAssertEqual(display.lastSuccessAt, instant)
        XCTAssertTrue(try XCTUnwrap(display.lastSuccessfulMessage).contains("差異"))
        XCTAssertTrue(display.message.contains("確認できませんでした"))
        let old = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try .decode(wire(date: "2032-04-30T03:04:05Z"), year: 2032), previous: restored)
        XCTAssertEqual(old.successfulResponse?.status, .source_differs)
        let changed = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try .decode(wire(hash: String(repeating: "c", count: 64)), year: 2032), previous: old)
        XCTAssertNil(changed.previousSuccess)
    }

    func testDamagedOversizedSymlinkAndWrongYearMetadataCannotBlockHealthyEvents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(saved().payload, apiETag: saved().apiETag)
        let original = try Data(contentsOf: root.appendingPathComponent("events-2032.json"))
        let file = root.appendingPathComponent("source-status-2032.json")
        for bytes in [Data("{broken".utf8), Data(repeating: 32, count: 18_433),
                      try JSONEncoder().encode(SavedSchoolEventsSourceStatus(receivedAt: instant,
                        response: try .decode(wire(year: 2033), year: 2033)))] {
            try bytes.write(to: file, options: .atomic)
            XCTAssertThrowsError(try store.loadSourceStatus(year: 2032))
            XCTAssertEqual(try store.loadAvailable().saved[2032]?.payload, saved().payload)
            XCTAssertTrue(try store.loadAvailable().failedYears.isEmpty)
        }
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("events-2032.json"))
        XCTAssertThrowsError(try store.loadSourceStatus(year: 2032))
        try store.saveSourceStatus(.init(receivedAt: instant, response: try .decode(wire(), year: 2032)))
        XCTAssertNotNil(try store.loadSourceStatus(year: 2032))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("events-2032.json")), original)
    }
}
