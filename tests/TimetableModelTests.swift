import Foundation
import XCTest
@testable import TakupokeParsing

@MainActor
final class TimetableModelTests: XCTestCase {
    private let revision = String(repeating: "T", count: 43)
    private final class Stub: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let url = request.url, let host = url.host,
                  ["times.example.test", "failure.example.test", "invalid.example.test"].contains(host) else {
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
            }
            let revision = String(repeating: "T", count: 43)
            let isRevision = url.path == "/timetable-times-revision"
            if isRevision { precondition(request.value(forHTTPHeaderField: "If-None-Match") == nil) }
            let status = url.host == "failure.example.test" ? 503 :
                (!isRevision && request.value(forHTTPHeaderField: "Authorization") != "Bearer synthetic-token" ? 401 : 200)
            let headers = isRevision ? ["ETag": "\"\(revision)\""] :
                ["Content-Type": "application/json", "X-Timetable-Times-Revision": revision]
            let body = isRevision ? Data() : Data((url.host == "invalid.example.test" ? "{invalid" : "{\"schemaVersion\":1,\"days\":[]}").utf8)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [Stub.self]
        return URLSession(configuration: config)
    }
    private func model(_ root: URL, host: String = "times.example.test") -> TimetableTimesModel {
        TimetableTimesModel(directory: root, baseURL: URL(string: "https://\(host)")!)
    }

    func testCorruptTimeCachesCanBeReplacedAndReopened() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("current.json")
        let invalidRevision = SavedTimetableTimes(revision: "invalid", fetchedAt: Date(), data: .init(schemaVersion: 1, days: []))
        let invalidData = SavedTimetableTimes(revision: revision, fetchedAt: Date(), data: .init(schemaVersion: 2, days: []))
        let network = session(); defer { network.invalidateAndCancel() }
        for bytes in [Data("{invalid".utf8), try JSONEncoder().encode(invalidRevision),
                      try JSONEncoder().encode(invalidData), Data(repeating: 32, count: 133 * 1024)] {
            try bytes.write(to: file)
            let current = model(root)
            current.loadIfNeeded()
            XCTAssertTrue(current.ready); XCTAssertTrue(current.failed); XCTAssertNil(current.current)
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            let result = try await current.revision(using: network)
            XCTAssertEqual(result, .available(revision))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
            try await current.download(token: "synthetic-token", revision: revision, network: network)
            XCTAssertFalse(current.failed); XCTAssertFalse(current.updateAvailable)
            let reopened = model(root); reopened.loadIfNeeded()
            XCTAssertFalse(reopened.failed); XCTAssertEqual(reopened.current?.revision, revision)
            XCTAssertEqual(reopened.current?.data, TimetableTimes(schemaVersion: 1, days: []))
        }
    }

    func testFailedTimeDownloadsPreserveCorruptCacheAndOfferRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("current.json"), bytes = Data("{invalid".utf8)
        try bytes.write(to: file)
        let network = session(); defer { network.invalidateAndCancel() }
        for (host, token, requestedRevision) in [
            ("failure.example.test", "synthetic-token", revision),
            ("invalid.example.test", "synthetic-token", revision),
            ("times.example.test", "invalid-token", revision),
            ("times.example.test", "synthetic-token", String(repeating: "U", count: 43))] {
            let current = model(root, host: host); current.loadIfNeeded()
            do {
                try await current.download(token: token, revision: requestedRevision, network: network)
                XCTFail("Failed download must not replace the cache")
            } catch { XCTAssertTrue(error is TimetableTimesError) }
            XCTAssertNil(current.current)
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }

    func testUnavailableDirectoryAndFailedSaveNeverPublishSuccess() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("fictional unavailable directory".utf8)
        try bytes.write(to: root)
        let unavailable = model(root); unavailable.loadIfNeeded()
        XCTAssertFalse(unavailable.ready); XCTAssertTrue(unavailable.failed)
        XCTAssertEqual(try Data(contentsOf: root), bytes)
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("current.json")
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let sentinel = file.appendingPathComponent("fictional.pdf"); try bytes.write(to: sentinel)
        let current = model(root); current.loadIfNeeded()
        let network = session(); defer { network.invalidateAndCancel() }
        do {
            try await current.download(token: "synthetic-token", revision: revision, network: network)
            XCTFail("Failed save must not publish the response")
        } catch { XCTAssertTrue(error is TimetableTimesError) }
        XCTAssertNil(current.current)
        XCTAssertEqual(try Data(contentsOf: sentinel), bytes)
    }

    func testDisjointChangeDetailsFindOriginalsAndRelatedChangesWithoutChangingGrid() throws {
        let day = SchoolDate(iso8601: "2032-04-05")!
        func change(_ periods: String, date: String = "2032-04-05", cls: String = "2_IT", before: String = "") -> ScheduleChange {
            ScheduleChange(change_date: date, class_name: cls, period: periods, before_subject: before,
                after_subject: "架空科目B", teacher: "", room: "", note: "", raw_text: "", canonical_text: "")
        }
        let target = change("1,3"), overlap = change("3"), disjointOverlap = change("3,5")
        let rows = [target, overlap, disjointOverlap, change("2"), change("1", cls: "1_CN"), change("1", date: "2032-04-06")]
        let lessons = (1...3).map { PDFLesson(className: "2_IT", weekday: 1, period: $0,
            names: TimetableLessonNames(subject: "架空科目\($0)"), sourceText: "", page: 1) }
        let timetable = PDFAnalysis(kind: .timetable, sourceDigest: "fictional", sourceName: "fictional.pdf",
            parsedAt: Date(), schoolYear: 2032, term: "前期", lessons: lessons, events: [], notices: [])
        let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: rows)
        let schedule = TimetableDaySchedule(timetable: timetable, changes: changes, events: nil, specials: [], includesChanges: true)
        let presentation = TimetablePresentation(schedule: schedule, mappings: MappingModel())
        let selection = presentation.changeSelection(for: target)
        XCTAssertEqual(selection.baseLessons.map(\.period), [1, 3])
        XCTAssertEqual(presentation.beforeSubject(selection), "架空科目1・架空科目3")
        XCTAssertEqual(selection.relatedChanges, [overlap, disjointOverlap])
        XCTAssertEqual(presentation.beforeSubject(presentation.changeSelection(for: change("1,3", before: "架空明記科目A"))), "架空明記科目A")
        XCTAssertNil(target.gridPeriods)
        for period in [1, 3] {
            let slot = TimetableSchedule.slot(on: day, period: period, className: "2_IT", timetable: timetable,
                changes: ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx", defaultYear: 2032, parsedAt: Date(), records: [target]), includesChanges: true, events: nil, specials: [])
            XCTAssertTrue(slot.changes.isEmpty)
        }
        for kind in SpecialScheduleKind.allCases {
            let special = SpecialScheduleAnalysis(kind: kind, sourceDigest: "fictional", sourceName: "fictional.pdf",
                parsedAt: Date(), schoolYear: 2032, coveredDates: [day.iso8601], coveredClasses: ["2_IT"],
                periodTimes: [1: "09:00〜09:20", 3: "10:00〜10:20"], lessons: [1, 3].map {
                    SpecialScheduleLesson(date: day.iso8601, className: "2_IT", period: $0, spanStart: $0, spanEnd: $0,
                        timeRange: nil, lines: ["架空試験科目\($0)"], page: 1)
                })
            let source = TimetableDaySchedule(timetable: timetable, changes: changes, events: nil, specials: [special], includesChanges: true)
            let result = TimetablePresentation(schedule: source, mappings: MappingModel()).changeSelection(for: target)
            XCTAssertTrue(result.baseLessons.isEmpty)
            XCTAssertEqual(result.baseSpecialLessons.map { $0.lesson.period }, [1, 3])
        }
        XCTAssertTrue(presentation.changeSelection(for: change("invalid")).baseLessons.isEmpty)
        XCTAssertTrue(presentation.changeSelection(for: change("1", date: "invalid")).relatedChanges.isEmpty)
    }
}
