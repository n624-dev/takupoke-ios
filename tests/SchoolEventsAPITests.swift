import Foundation
import XCTest
@testable import TakupokeParsing

final class SchoolEventsAPITests: XCTestCase {
    private func payload(_ events: [SchoolEventsPayload.Event]) -> SchoolEventsPayload {
        SchoolEventsPayload(version: "v1", schoolYear: 2032,
                            sourcePdfSha256: String(repeating: "a", count: 64),
                            sourcePdfETag: "\"fictional-etag\"", events: events)
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
