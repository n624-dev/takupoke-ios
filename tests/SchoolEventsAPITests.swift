import Foundation
import XCTest
@testable import TakupokeParsing

final class SchoolEventsAPITests: XCTestCase {
    private func payload(_ events: [SchoolEventsPayload.Event]) -> SchoolEventsPayload {
        SchoolEventsPayload(version: "v1", schoolYear: 2032,
                            sourcePdfSha256: String(repeating: "a", count: 64),
                            sourcePdfETag: "\"fictional-etag\"", events: events)
    }

    private func fictionalPayload(year: Int, title: String = "架空行事A") -> SchoolEventsPayload {
        SchoolEventsPayload(version: "v1", schoolYear: year,
                            sourcePdfSha256: String(repeating: "a", count: 64),
                            sourcePdfETag: nil,
                            events: [.init(startDate: "\(year)-04-01", endDate: "\(year)-04-01",
                                           title: title, tag: "行事")])
    }

    func testCorruptYearRetainsHealthyYearsAndOriginalUntilVerifiedSameYearRepair() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(fictionalPayload(year: 2032))
        let healthyFile = root.appendingPathComponent("events-2032.json")
        let healthyBytes = try Data(contentsOf: healthyFile)
        let damagedFile = root.appendingPathComponent("events-2033.json")
        let damagedBytes = Data("{fictional damaged JSON".utf8)
        try damagedBytes.write(to: damagedFile)
        let available = try store.loadAvailable()
        XCTAssertEqual(Set(available.saved.keys), [2032])
        XCTAssertEqual(available.failedYears, [2033])
        XCTAssertEqual(available.warning, "2033年度の保存済み学校行事を読み取れません。正常な年度の結果は表示しています。該当年度を再取得してください。端末内の結果は削除していません。")
        XCTAssertThrowsError(try store.loadAll())
        XCTAssertEqual(try Data(contentsOf: damagedFile), damagedBytes)

        // A valid refresh of another year cannot acknowledge the damaged year.
        try store.save(fictionalPayload(year: 2034))
        XCTAssertEqual(try store.loadAvailable().failedYears, [2033])
        var invalid = fictionalPayload(year: 2033)
        invalid = SchoolEventsPayload(version: "invalid", schoolYear: 2033,
                                       sourcePdfSha256: invalid.sourcePdfSha256,
                                       sourcePdfETag: nil, events: invalid.events)
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(try Data(contentsOf: damagedFile), damagedBytes)
        XCTAssertEqual(try store.loadAvailable().failedYears, [2033])

        let repaired = fictionalPayload(year: 2033, title: "架空再取得行事A")
        try store.save(repaired, fetchedAt: Date(timeIntervalSince1970: 2))
        let reloaded = try SchoolEventsStore(root: root).loadAvailable()
        XCTAssertEqual(Set(reloaded.saved.keys), [2032, 2033, 2034])
        XCTAssertEqual(reloaded.saved[2033]?.payload, repaired)
        XCTAssertTrue(reloaded.failedYears.isEmpty)
        XCTAssertNil(reloaded.warning)
        XCTAssertEqual(try Data(contentsOf: healthyFile), healthyBytes)
        XCTAssertNotEqual(try Data(contentsOf: damagedFile), damagedBytes)
    }

    func testOversizedNonregularAndWrongYearCachesAreReportedIndividually() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(fictionalPayload(year: 2032))
        let oversized = root.appendingPathComponent("events-2033.json")
        try Data(repeating: 32, count: 1_000_001).write(to: oversized)
        let nonregular = root.appendingPathComponent("events-2034.json")
        try FileManager.default.createDirectory(at: nonregular, withIntermediateDirectories: false)
        let wrongYear = root.appendingPathComponent("events-2035.json")
        try JSONEncoder().encode(SavedSchoolEvents(fetchedAt: Date(timeIntervalSince1970: 1),
                                                  payload: fictionalPayload(year: 2036), apiETag: nil)).write(to: wrongYear)
        let available = try store.loadAvailable()
        XCTAssertEqual(Set(available.saved.keys), [2032])
        XCTAssertEqual(available.failedYears, [2033, 2034, 2035])
        XCTAssertTrue(try XCTUnwrap(available.warning).hasPrefix("2033、2034、2035年度"))
        XCTAssertEqual(try Data(contentsOf: oversized).count, 1_000_001)
        XCTAssertTrue(try nonregular.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
        XCTAssertThrowsError(try store.save(fictionalPayload(year: 2034)))
        XCTAssertEqual(try store.loadAvailable().failedYears, [2033, 2034, 2035])
    }

    func testSymlinkCacheIsNotFollowedAndAtomicRepairRetainsHealthyTarget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(fictionalPayload(year: 2032))
        let healthy = root.appendingPathComponent("events-2032.json")
        let bytes = try Data(contentsOf: healthy)
        let link = root.appendingPathComponent("events-2033.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: healthy)
        XCTAssertEqual(try store.loadAvailable().failedYears, [2033])
        try store.save(fictionalPayload(year: 2033))
        XCTAssertEqual(try Data(contentsOf: healthy), bytes)
        XCTAssertTrue(try store.loadAvailable().failedYears.isEmpty)
    }

    func testDirectoryFailureDoesNotBecomeAvailableEmptyCache() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try FileManager.default.removeItem(at: root)
        try Data("fictional non-directory root".utf8).write(to: root)
        XCTAssertThrowsError(try store.loadAvailable())
    }

    func testCancelledLoadCannotBecomeAvailableCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cancelled = try await Task {
            let store = try SchoolEventsStore(root: root)
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try store.loadAvailable(); return false }
            catch is CancellationError { return true }
        }.value
        XCTAssertTrue(cancelled)
    }

    func testValidatesYearAndInclusiveDatesBeforeSaving() throws {
        let event = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2033-03-31",
                                               title: "架空休業A", tag: "授業なし")
        let data = try JSONEncoder().encode(payload([event]))
        let decoded = try SchoolEventsPayload.decode(data, requestedYear: 2032)
        XCTAssertEqual(decoded.events, [event])
        XCTAssertEqual(decoded.sourcePdfETag, "\"fictional-etag\"")
        XCTAssertThrowsError(try SchoolEventsPayload.decode(data, requestedYear: 2033))
        let invalid = SchoolEventsPayload.Event(startDate: "2032-02-30", endDate: "2032-04-01",
                                                 title: "架空行事A", tag: "行事")
        XCTAssertThrowsError(try SchoolEventsPayload.decode(JSONEncoder().encode(payload([invalid])),
                                                              requestedYear: 2032))
        let unknownTag = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                                    title: "架空行事A", tag: "未確認")
        XCTAssertThrowsError(try SchoolEventsPayload.decode(JSONEncoder().encode(payload([unknownTag])),
                                                              requestedYear: 2032))
    }

    func testLegacyPayloadWithoutETagLoadsButMalformedValidatorIsRejected() throws {
        let event = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                               title: "架空行事A", tag: "行事")
        let legacy = SchoolEventsPayload(version: "v1", schoolYear: 2032,
                                         sourcePdfSha256: String(repeating: "a", count: 64),
                                         sourcePdfETag: nil, events: [event])
        XCTAssertNil(try SchoolEventsPayload.decode(JSONEncoder().encode(legacy), requestedYear: 2032).sourcePdfETag)
        let invalid = SchoolEventsPayload(version: "v1", schoolYear: 2032,
                                          sourcePdfSha256: String(repeating: "a", count: 64),
                                          sourcePdfETag: "W/\"fictional\"", events: [event])
        XCTAssertThrowsError(try SchoolEventsPayload.decode(JSONEncoder().encode(invalid), requestedYear: 2032))
    }

    func testSavedResultsSurviveInvalidReplacement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        let event = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                               title: "架空行事A", tag: "行事")
        let tag = "W/\"fictional-response-v1\""
        try store.save(payload([event]), apiETag: tag, fetchedAt: Date(timeIntervalSince1970: 1))
        let invalid = SchoolEventsPayload(version: "v2", schoolYear: 2032,
                                          sourcePdfSha256: String(repeating: "a", count: 64),
                                          sourcePdfETag: nil, events: [event])
        XCTAssertThrowsError(try store.save(invalid))
        let restored = try XCTUnwrap(store.loadAll()[2032])
        XCTAssertEqual(restored.payload.events, [event])
        XCTAssertEqual(restored.fetchedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(restored.apiETag, tag)
    }

    func testOldSavedResultWithoutResponseETagCanLoad() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        let event = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                               title: "架空行事A", tag: "行事")
        try store.save(payload([event]), fetchedAt: Date(timeIntervalSince1970: 1))
        let restored = try XCTUnwrap(store.loadAll()[2032])
        XCTAssertNil(restored.apiETag)
        XCTAssertEqual(restored.payload.events, [event])
    }

    func testNotModifiedRequiresMatchingSavedValidatorAndEmptyBody() throws {
        let tag = "W/\"fictional-response-v1\""
        XCTAssertTrue(try SchoolEventsResponse.isNotModified(status: 304, data: Data(),
                                                               sentETag: tag, receivedETag: tag,
                                                               hasSavedResult: true))
        XCTAssertFalse(try SchoolEventsResponse.isNotModified(status: 200, data: Data("{}".utf8),
                                                                sentETag: tag, receivedETag: tag,
                                                                hasSavedResult: true))
        XCTAssertThrowsError(try SchoolEventsResponse.isNotModified(status: 304, data: Data(),
                                                                     sentETag: tag, receivedETag: "W/\"other\"",
                                                                     hasSavedResult: true))
        XCTAssertThrowsError(try SchoolEventsResponse.isNotModified(status: 304, data: Data(),
                                                                     sentETag: tag, receivedETag: tag,
                                                                     hasSavedResult: false))
        XCTAssertThrowsError(try SchoolEventsResponse.isNotModified(status: 304, data: Data("x".utf8),
                                                                     sentETag: tag, receivedETag: tag,
                                                                     hasSavedResult: true))
        XCTAssertFalse(SchoolEventsResponse.validETag("W/\"bad\r\nvalidator\""))
    }

    func testWeekdayTagRequiresAnExplicitWeekday() throws {
        let valid = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                               title: "月曜日授業", tag: "曜日振替")
        XCTAssertNoThrow(try SchoolEventsPayload.decode(JSONEncoder().encode(payload([valid])),
                                                             requestedYear: 2032))
        let invalid = SchoolEventsPayload.Event(startDate: "2032-04-01", endDate: "2032-04-01",
                                                 title: "架空行事A", tag: "曜日振替")
        XCTAssertThrowsError(try SchoolEventsPayload.decode(JSONEncoder().encode(payload([invalid])),
                                                              requestedYear: 2032))
    }
}
