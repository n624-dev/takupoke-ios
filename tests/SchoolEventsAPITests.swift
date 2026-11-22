import Foundation
import XCTest
@testable import TakupokeParsing

#if canImport(SwiftUI)
import CryptoKit

private final class EventsProjectionTransport: URLProtocol {
    enum Mode: Equatable { case cached, updated, failure }
    private static let lock = NSLock()
    private static var mode = Mode.cached
    private static var bodyResponses: [Int: [Int]] = [:]
    static let savedAt = Date(timeIntervalSince1970: 1_965_000_000)
    static func set(_ value:Mode) { lock.lock(); mode = value; lock.unlock() }
    static func reset() {
        lock.lock(); defer { lock.unlock() }
        mode = .cached
        bodyResponses.removeAll()
    }

    static func responses(year: Int) -> [Int] {
        lock.lock(); defer { lock.unlock() }
        return bodyResponses[year] ?? []
    }

    static func payload(year: Int, updated: Bool = false) -> SchoolEventsPayload {
        SchoolEventsPayload(version: "v1", schoolYear: year, sourcePdfSha256: String(repeating: updated ? "b" : "a", count: 64),
            sourcePdfETag: nil, events: [.init(startDate: "\(year)-04-01", endDate: "\(year)-04-01",
                title: updated ? "架空更新行事" : "架空保存行事\(year)", tag: "行事")])
    }

    static func body(_ payload: SchoolEventsPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(payload)
    }

    static func version(_ body: Data) -> String {
        "sha256-" + SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    }
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        guard let url = request.url, url.host == "events.example.invalid",
              ["/events", "/events/source-status"].contains(url.path),
              request.httpMethod == "GET", let components = URLComponents(url:url,resolvingAgainstBaseURL:false),
              components.queryItems?.count == 1, let query = components.queryItems?.first,
              query.name == "schoolYear", let year = query.value.flatMap(Int.init), [2032,2033].contains(year) else {
            client?.urlProtocol(self,didFailWithError:URLError(.unsupportedURL)); return
        }
        Self.lock.lock(); let mode = Self.mode; Self.lock.unlock()
        let updated = year == 2032 && mode != .cached
        let payload = Self.payload(year: year, updated: updated)
        var status = 200, data = Data(), headers = ["Content-Type": "application/json"]
        do {
            if url.path == "/events/source-status" {
                let observedAt = ISO8601DateFormatter().string(from: Self.savedAt.addingTimeInterval(updated ? 3_600 : 0))
                let source = SchoolEventsSourceStatus(version: "v1", schoolYear: year,
                    dataVersion: Self.version(try Self.body(payload)), adoptedSourcePdfSha256: payload.sourcePdfSha256,
                    status: .matched, lastSuccessfulStatus: .matched, lastSuccessAt: observedAt, lastAttemptAt: observedAt,
                    nextAttemptAt: nil, checking: false, stale: false)
                data = try JSONEncoder().encode(source)
            } else {
                let validator = year == 2032 && mode == .failure ? "\"next-2032\"" : "\"initial-\(year)\""
                guard request.value(forHTTPHeaderField: "If-None-Match") == validator else {
                    throw URLError(.unsupportedURL)
                }
                switch (updated, mode) {
                case (true, .updated):
                    headers["ETag"] = "\"next-2032\""
                    data = try Self.body(payload)
                case (true, .failure): status = 503
                default:
                    status = 304
                    headers["ETag"] = validator
                }
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if url.path == "/events" {
            Self.lock.lock()
            Self.bodyResponses[year, default: []].append(status)
            Self.lock.unlock()
        }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:url,statusCode:status,httpVersion:"HTTP/1.1",
            headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data); client?.urlProtocolDidFinishLoading(self)
    }
}
#endif

final class SchoolEventsAPITests: XCTestCase {
#if canImport(SwiftUI)
    @MainActor func testActualEventsModelCachesProjectionAcrossReads304FailureAndStoreReload() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("events-projection-"+UUID().uuidString)
        EventsProjectionTransport.reset()
        defer { try? FileManager.default.removeItem(at:base); EventsProjectionTransport.reset() }
        let store = try SchoolEventsStore(root:base.appendingPathComponent("SchoolEventsAPI"))
        let savedAt = EventsProjectionTransport.savedAt
        var now = savedAt
        for year in [2032,2033] {
            let payload = EventsProjectionTransport.payload(year: year)
            try store.save(payload, apiETag: "\"initial-\(year)\"", fetchedAt: savedAt,
                responseDataVersion: EventsProjectionTransport.version(try EventsProjectionTransport.body(payload)))
        }
        let model = SchoolEventsModel(storeRoot:base,eventsEndpoint:URL(string:"https://events.example.invalid/events")!,preferredFormat: .v1,makeSession:{
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [EventsProjectionTransport.self]; configuration.urlCache = nil
            return URLSession(configuration:configuration)
        }, now: { now }, startsActive: false)
        model.loadIfNeeded(); XCTAssertTrue(model.ready); XCTAssertEqual(model.projectionBuildCount,1)
        let first = try XCTUnwrap(model.analysis), generation = model.scheduleGeneration
        for _ in 0..<1000 { XCTAssertEqual(model.analysis?.events,first.events) }
        XCTAssertEqual(model.projectionBuildCount,1)
        let notModified = await model.refreshInBackground()
        XCTAssertTrue(notModified); XCTAssertEqual(model.projectionBuildCount,1); XCTAssertEqual(model.scheduleGeneration,generation)
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2032), [304])
        XCTAssertEqual(model.saved[2032]?.lastEventsCheckedAt, now)
        now.addTimeInterval(3_599)
        let stillFresh = await model.refreshInBackground()
        XCTAssertTrue(stillFresh)
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2032), [304])
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2033), [304])
        now.addTimeInterval(1)
        EventsProjectionTransport.set(.updated)
        let updated = await model.refreshInBackground()
        XCTAssertTrue(updated); XCTAssertEqual(model.projectionBuildCount,2); XCTAssertNotEqual(model.scheduleGeneration,generation)
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2032), [304, 200])
        XCTAssertEqual(model.analysis?.events.map(\.title),["架空更新行事","架空保存行事2033"])
        let current = model.analysis, currentGeneration = model.scheduleGeneration
        let confirmedAt = now
        now.addTimeInterval(3_600)
        EventsProjectionTransport.set(.failure)
        let failed = await model.refreshInBackground()
        XCTAssertFalse(failed); XCTAssertFalse(model.failed); XCTAssertEqual(model.projectionBuildCount,2)
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2032), [304, 200, 503])
        XCTAssertEqual(EventsProjectionTransport.responses(year: 2033), [304, 304, 304])
        XCTAssertNil(model.sourceCheckMessage)
        XCTAssertEqual(model.saved[2032]?.lastEventsCheckedAt, confirmedAt)
        XCTAssertEqual(model.scheduleGeneration,currentGeneration); XCTAssertEqual(model.analysis?.events,current?.events)
        let reopened = SchoolEventsModel(storeRoot:base, startsActive: false)
        reopened.loadIfNeeded(); XCTAssertEqual(reopened.analysis?.events,current?.events)
        XCTAssertEqual(reopened.saved[2033]?.fetchedAt,savedAt)
    }
#endif
    func testNearLimitPayloadRemainsReadableAfterSavingItsMetadataEnvelope() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let encoder=JSONEncoder()
        let base="架空"+String(repeating:"あ",count:140)
        var events=Array(repeating:SchoolEventsPayload.Event(startDate:"2032-04-01",
            endDate:"2032-04-01",title:base,tag:"行事"),count:1800)
        var remaining=999_990 - (try encoder.encode(payload(events))).count
        XCTAssertGreaterThan(remaining,0)
        for index in events.indices where remaining>0 {
            let extra=min(200-events[index].title.count,remaining)
            events[index] = .init(startDate:"2032-04-01",endDate:"2032-04-01",
                title:events[index].title+String(repeating:"X",count:extra),tag:"行事")
            remaining -= extra
        }
        XCTAssertEqual(remaining,0)
        let accepted=payload(events)
        let bytes=try encoder.encode(accepted)
        XCTAssertEqual(bytes.count,999_990)
        _ = try SchoolEventsPayload.decode(bytes,requestedYear:2032)
        let store=try SchoolEventsStore(root:root)
        try store.save(accepted,apiETag:"\""+String(repeating:"e",count:254)+"\"",
            fetchedAt:Date(timeIntervalSince1970:1))
        let reopened=try SchoolEventsStore(root:root).loadAvailable()
        XCTAssertTrue(reopened.failedYears.isEmpty)
        XCTAssertTrue(reopened.saved[2032]?.payload == accepted)
        let persisted=try Data(contentsOf:root.appendingPathComponent("events-2032.json"))
        var oversized=events
        oversized.append(.init(startDate:"2032-04-02",endDate:"2032-04-02",
            title:"架空の上限超過対照",tag:"行事"))
        XCTAssertThrowsError(try store.save(payload(oversized)))
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("events-2032.json")),persisted)
    }

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

    func testAnnualCoverageUsesValidatedYearEvenWithoutEventsOnDisplayedDay() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(fictionalPayload(year: 2031))
        let day = SchoolDate(iso8601: "2032-04-05")!
        var coverage = SchoolEventsCoverage(savedYears: Set(try store.loadAvailable().saved.keys))
        XCTAssertFalse(coverage.contains(day: day))
        XCTAssertTrue(coverage.contains(day: SchoolDate(iso8601: "2032-03-31")!))

        // A valid year may contain events on other days. That confirms annual
        // availability without inventing an event on the displayed day.
        try store.save(fictionalPayload(year: 2032))
        let loaded = try store.loadAvailable()
        XCTAssertFalse(try XCTUnwrap(loaded.saved[2032]).payload.projectedEvents.contains { $0.date == day.iso8601 })
        coverage = SchoolEventsCoverage(savedYears: Set(loaded.saved.keys))
        XCTAssertTrue(coverage.contains(day: day))
        try Data("{fictional damaged JSON".utf8).write(to: root.appendingPathComponent("events-2033.json"))
        let damaged = try store.loadAvailable()
        XCTAssertEqual(damaged.failedYears, [2033])
        XCTAssertFalse(SchoolEventsCoverage(savedYears: Set(damaged.saved.keys))
            .contains(day: SchoolDate(iso8601: "2033-04-01")!))
    }

    func testWeekCoverageChecksEveryDayAcrossSchoolYearBoundary() {
        let start = SchoolDate(iso8601: "2032-03-29")!
        XCTAssertEqual(start.schoolWeekday, 1)
        XCTAssertFalse(SchoolEventsCoverage(savedYears: []).coversWeek(starting: start))
        XCTAssertFalse(SchoolEventsCoverage(savedYears: [2031]).coversWeek(starting: start))
        XCTAssertFalse(SchoolEventsCoverage(savedYears: [2032]).coversWeek(starting: start))
        XCTAssertTrue(SchoolEventsCoverage(savedYears: [2031, 2032]).coversWeek(starting: start))
        XCTAssertTrue(SchoolEventsCoverage(savedYears: [2032])
            .coversWeek(starting: SchoolDate(iso8601: "2032-04-05")!))
        // Include the final weekend day, even when only weekdays have columns.
        XCTAssertFalse(SchoolEventsCoverage(savedYears: [2034])
            .coversWeek(starting: SchoolDate(iso8601: "2035-03-26")!))
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

    func testAcceptedEventResponseWithUnescapedSlashesSurvivesReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        let entries = (0..<2_000).map { index in
            SchoolEventsPayload.IdentifiedEvent(eventId: "fictional-\(index)",
                title: "架空行事 " + String(repeating: "あ", count: 92) + String(repeating: "/", count: 90),
                tag: "行事",
                ranges: [.init(startDate: "2032-04-01", endDate: "2032-04-01")])
        }
        let original = SchoolEventsPayload(schoolYear: 2032, sourcePdfSha256: String(repeating: "a", count: 64),
                                           sourcePdfETag: nil, identifiedEvents: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let body = try encoder.encode(original)
        let accepted = try SchoolEventsPayload.decode(body, requestedYear: 2032, requestedFormat: .v2)
        XCTAssertGreaterThan(try JSONEncoder().encode(original).count, 1_000_000)

        try store.save(accepted)
        XCTAssertEqual(try store.loadAll()[2032]?.payload, accepted)
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

extension SchoolEventsAPITests {
    func testIdentifiedCalendarPreservesOneOccurrenceAndProjectsSplitRanges() throws {
        let item = SchoolEventsPayload.IdentifiedEvent(eventId: "fixed-test-001", title: "架空分割試験", tag: "テスト",
            ranges: [.init(startDate: "2032-06-04", endDate: "2032-06-04"),
                     .init(startDate: "2032-06-07", endDate: "2032-06-09")])
        let known = SchoolEventsPayload(schoolYear: 2032, sourcePdfSha256: String(repeating: "a", count: 64),
                                        sourcePdfETag: nil, identifiedEvents: [item])
        let data = try JSONEncoder().encode(known)
        let validated = try SchoolEventsPayload.decode(data, requestedYear: 2032, requestedFormat: .v2)
        XCTAssertEqual(validated.identifiedEvents, [item])
        XCTAssertEqual(validated.projectedEvents.map(\.date), ["2032-06-04", "2032-06-07"])
        XCTAssertEqual(validated.projectedEvents.map(\.apiTag), ["テスト", "テスト"])
        XCTAssertThrowsError(try SchoolEventsPayload.decode(data, requestedYear: 2032, requestedFormat: .v1))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SchoolEventsStore(root: root)
        try store.save(validated)
        XCTAssertEqual(try store.loadAll()[2032]?.payload.identifiedEvents, [item])
    }

    func testIdentifiedCalendarRejectsInvalidIDAndRangesButAcceptsReviewedEmptyPayload() throws {
        typealias Item = SchoolEventsPayload.IdentifiedEvent
        let valid = Item(eventId: "fixed-1", title: "架空予定", tag: "行事",
            ranges: [.init(startDate: "2032-06-04", endDate: "2032-06-07")])
        let invalid = [
            Item(eventId: "", title: valid.title, tag: valid.tag, ranges: valid.ranges),
            Item(eventId: valid.eventId, title: valid.title, tag: valid.tag, ranges: []),
            Item(eventId: valid.eventId, title: valid.title, tag: valid.tag,
                 ranges: [.init(startDate: "2032-02-01", endDate: "2032-02-01")]),
            Item(eventId: valid.eventId, title: valid.title, tag: valid.tag, ranges: valid.ranges + valid.ranges),
            Item(eventId: valid.eventId, title: valid.title, tag: "誤った種別", ranges: valid.ranges),
        ]
        func wire(_ events: [Item]) throws -> Data {
            try JSONEncoder().encode(SchoolEventsPayload(schoolYear: 2032, sourcePdfSha256: String(repeating: "b", count: 64),
                                                        sourcePdfETag: nil, identifiedEvents: events))
        }
        for value in invalid {
            XCTAssertThrowsError(try SchoolEventsPayload.decode(wire([value]), requestedYear: 2032, requestedFormat: .v2))
        }
        XCTAssertThrowsError(try SchoolEventsPayload.decode(wire([valid, valid]), requestedYear: 2032, requestedFormat: .v2))
        let empty = try SchoolEventsPayload.decode(wire([]), requestedYear: 2032, requestedFormat: .v2)
        XCTAssertEqual(empty.identifiedEvents, [])
        XCTAssertTrue(empty.projectedEvents.isEmpty)
    }
}
