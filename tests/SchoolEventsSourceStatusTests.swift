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
                      version: String? = nil, next: String = "2032-05-02T03:04:05Z") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["version": "v1", "schoolYear": year,
            "dataVersion": version ?? self.version, "adoptedSourcePdfSha256": hash ?? self.expectedSourceHash,
            "status": status, "lastSuccessfulStatus": success as Any? ?? NSNull(),
            "lastSuccessAt": date as Any? ?? NSNull(), "lastAttemptAt": "2032-05-01T03:04:05Z",
            "nextAttemptAt": next, "checking": checking, "stale": stale])
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
        XCTAssertFalse(mismatched.matches(saved()))
        XCTAssertTrue(value.matches(saved()))
        XCTAssertEqual(value.nextRegularCheck, instant.addingTimeInterval(43_200))
        let beforeDailyExpiry = SavedSchoolEventsSourceStatus(receivedAt: instant.addingTimeInterval(23 * 3_600),
            response: value.response)
        XCTAssertEqual(beforeDailyExpiry.nextRegularCheck, SchoolEventsSourceStatus.date("2032-05-02T03:04:05Z"))
        let laterAttempt = SavedSchoolEventsSourceStatus(receivedAt: beforeDailyExpiry.receivedAt,
            response: try SchoolEventsSourceStatus.decode(wire(next: "2032-05-02T04:04:05Z"), year: 2032))
        XCTAssertEqual(laterAttempt.nextRegularCheck, instant.addingTimeInterval(86_400))
    }

    func testPresentationSeparatesMatchedDifferenceUnknownFailureStalenessAndSnapshotMismatch() throws {
        func present(_ data: Data, age: TimeInterval = 0, error: String? = nil) throws -> SchoolEventsSourcePresentation {
            .make(saved: saved(), cached: .init(receivedAt: instant,
                response: try .decode(data, year: 2032)), error: error, now: instant.addingTimeInterval(age))
        }
        XCTAssertFalse(try present(wire()).warning)
        let differs = try present(wire(status: "source_differs", success: "source_differs"))
        XCTAssertTrue(differs.warning); XCTAssertTrue(differs.message.contains("更新待ち"))
        XCTAssertTrue(differs.updateWaiting)
        XCTAssertTrue(differs.message.contains("端末の再取得では解消しません"))
        XCTAssertTrue(try present(wire(status: "unknown", success: nil, date: nil)).message.contains("未確認"))
        let failed = try present(wire(status: "unavailable"))
        XCTAssertFalse(failed.warning); XCTAssertEqual(failed.lastSuccessAt, instant)
        XCTAssertTrue(try XCTUnwrap(failed.lastSuccessfulMessage).contains("一致"))
        XCTAssertTrue(try present(wire(), age: 43_200).message.contains("古く"))
        XCTAssertTrue(try present(wire(stale: true)).message.contains("古く"))
        XCTAssertTrue(try present(wire(), error: "架空の通信失敗").message.contains("架空の通信失敗"))
        XCTAssertTrue(try present(wire(version: "sha256-" + String(repeating: "e", count: 64))).message.contains("配信版が一致しない"))
        XCTAssertNil(try present(wire(hash: String(repeating: "e", count: 64))).lastSuccessAt)
        XCTAssertFalse(SchoolEventsSourcePresentation.make(saved: saved(), cached: nil, error: nil, now: instant).warning)
    }

    func testExhaustedFollowUpsShowUnconfirmedWhileKeepingLastSuccess() throws {
        let checking = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try SchoolEventsSourceStatus.decode(wire(checking: true), year: 2032))
        let display = SchoolEventsSourcePresentation.make(saved: saved(), cached: checking,
            error: "元PDFの確認結果をまだ取得できません。後で自動確認します。", now: instant, firstFailureAt: instant)
        XCTAssertTrue(display.message.contains("後で自動確認")); XCTAssertFalse(display.warning)
        XCTAssertEqual(display.lastSuccessAt, instant)
        XCTAssertTrue(try XCTUnwrap(display.lastSuccessfulMessage).contains("一致"))
        let matched = SavedSchoolEventsSourceStatus(receivedAt: instant,
            response: try SchoolEventsSourceStatus.decode(wire(), year: 2032))
        let completed = SchoolEventsSourcePresentation.make(saved: saved(), cached: matched,
            error: nil, now: instant)
        XCTAssertFalse(completed.warning); XCTAssertEqual(completed.message, "元PDFの本文は登録元と一致しています。")
    }

    func testStructuredEvidenceNeverPromotesStaleFailedOrMismatchedResultsToMatched() throws {
        func evidence(_ data: Data, age: TimeInterval = 0, error: String? = nil) throws -> SchoolEventsSourcePresentation.Evidence {
            SchoolEventsSourcePresentation.make(saved: saved(), cached: .init(receivedAt: instant,
                response: try .decode(data, year: 2032)), error: error, now: instant.addingTimeInterval(age)).evidence
        }
        XCTAssertEqual(try evidence(wire()), .matched)
        XCTAssertEqual(try evidence(wire(status: "source_differs", success: "source_differs")), .differs)
        XCTAssertEqual(try evidence(wire(checking: true)), .checking)
        XCTAssertEqual(try evidence(wire(checking: true), age: 60), .unknown)
        XCTAssertEqual(try evidence(wire(), age: 43_200), .unknown)
        XCTAssertEqual(try evidence(wire(stale: true)), .unknown)
        XCTAssertEqual(try evidence(wire(status: "unavailable")), .unknown)
        XCTAssertEqual(try evidence(wire(status: "unknown", success: nil, date: nil)), .unknown)
        XCTAssertEqual(try evidence(wire(), error: "架空の通信失敗"), .unknown)
        XCTAssertEqual(try evidence(wire(hash: String(repeating: "e", count: 64))), .unknown)
        XCTAssertEqual(SchoolEventsSourcePresentation.make(saved: saved(), cached: nil, error: nil, now: instant).evidence, .unknown)
    }

    func testStatusDoesNotHideAnEventsFailureOrCheckBehindACachedPDFMatch() throws {
        let source = SchoolEventsSourcePresentation.make(saved: saved(), cached: .init(receivedAt: instant,
            response: try .decode(wire(), year: 2032)), error: nil, now: instant)
        XCTAssertEqual(source.evidence, .matched)
        func status(ready: Bool = true, failed: Bool = false, checking: Bool = false,
                    cacheFailed: Bool = false, acquired: Bool = true) -> StatusPresentation {
            .schoolEvents(ready: ready, failed: failed, checking: checking,
                          cacheFailed: cacheFailed, acquired: acquired, source: source)
        }
        XCTAssertEqual(status().tone, .good)
        XCTAssertEqual(status(failed: true).tone, .attention)
        XCTAssertEqual(status(checking: true).tone, .checking)
        XCTAssertEqual(status(ready: false, failed: true).tone, .unavailable)
        XCTAssertEqual(status(cacheFailed: true).tone, .attention)
        XCTAssertEqual(status(acquired: false).tone, .neutral)
        XCTAssertEqual(source.evidence, .matched, "The retained source evidence is not discarded")
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
            XCTAssertFalse(display.warning)
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

extension SchoolEventsSourceStatusTests {
    func testLongWarningUsesSuccessfulObservationOrPersistedFirstFailure() throws {
        let matched = SavedSchoolEventsSourceStatus(receivedAt: instant.addingTimeInterval(47 * 3_600),
            response: try .decode(wire(), year: 2032))
        for age in [172_799.0, 172_800, 172_801] {
            let date = instant.addingTimeInterval(age)
            for cached in [nil, matched] {
                let value = SchoolEventsSourcePresentation.make(saved: saved(), cached: cached, error: nil,
                    now: date, firstFailureAt: cached == nil ? instant : instant.addingTimeInterval(86_400), checking: true)
                XCTAssertEqual(value.warning, age >= 172_800)
            }
        }
    }

    func testPersistedRetryBackoffIsIndependentOfConfirmationAndClockRollback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(saved())
        var state = SchoolEventsRefreshState(target: .init(saved()), requestedBodyFormat: .v2)
        var date = instant
        for interval in [900.0, 1800, 3600, 3600] {
            state.source.fail(at: date)
            XCTAssertEqual(state.source.retryAt, date.addingTimeInterval(interval))
            XCTAssertEqual(state.source.firstFailureAt, instant)
            XCTAssertNil(state.body.retryAt)
            date = date.addingTimeInterval(interval)
        }
        try store.saveRefreshState(state)
        XCTAssertEqual(try store.loadRefreshState(year: 2032), state)
        let rolledBack = instant.addingTimeInterval(-900)
        state.adjustClock(at: rolledBack)
        XCTAssertEqual(state.source.retryAt, rolledBack.addingTimeInterval(3600))
        try Data("{broken".utf8).write(to: root.appendingPathComponent("refresh-2032.json"), options: .atomic)
        XCTAssertThrowsError(try store.loadRefreshState(year: 2032))
        XCTAssertEqual(try store.loadAvailable().saved[2032]?.payload, saved().payload)
        XCTAssertNil(try store.loadAvailable().saved[2032]?.lastEventsCheckedAt)
    }
}
