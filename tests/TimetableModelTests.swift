import Foundation
import XCTest
@testable import TakupokeParsing

private final class LinksRevisionTransport: URLProtocol {
    private static let lock = NSLock()
    private static var pending = [LinksRevisionTransport]()
    private static var requestCount = 0
    private static var started: XCTestExpectation?
    static func expectStart(_ event:XCTestExpectation) { lock.lock(); started = event; lock.unlock() }
    static func reset() { lock.lock(); pending = []; requestCount = 0; started = nil; lock.unlock() }
    static var count:Int { lock.lock(); defer { lock.unlock() }; return requestCount }
    static func release(status: Int = 200) {
        lock.lock(); let requests = pending; pending = []; lock.unlock()
        for request in requests {
            let url = request.request.url!
            request.client?.urlProtocol(request,didReceive:HTTPURLResponse(url:url,statusCode:status,httpVersion:"HTTP/1.1",
                headerFields:["ETag":"\""+String(repeating:"A",count:43)+"\""])!,cacheStoragePolicy:.notAllowed)
            request.client?.urlProtocol(request,didLoad:Data())
            request.client?.urlProtocolDidFinishLoading(request)
        }
    }
    override class func canInit(with request:URLRequest) -> Bool { true }
    override class func canonicalRequest(for request:URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard request.url?.absoluteString == "https://links.example.invalid/links-revision",
              request.httpMethod == "GET", request.value(forHTTPHeaderField:"Authorization") == nil else {
            client?.urlProtocol(self,didFailWithError:URLError(.unsupportedURL)); return
        }
        Self.lock.lock(); Self.pending.append(self); Self.requestCount += 1
        let event = Self.started; Self.started = nil; Self.lock.unlock()
        event?.fulfill()
    }
    override func stopLoading() { Self.lock.lock(); Self.pending.removeAll { $0 === self }; Self.lock.unlock() }
}

private final class LinksDownloadTransport: URLProtocol {
    static let revision = String(repeating: "N", count: 43)
    static func payload(digest: String) -> LinksPayload {
        LinksPayload(version: "v1", linksVersion: "sha256-" + String(repeating: digest, count: 64),
                     categories: [.init(id: "fictional-category", label: "架空分類", sortOrder: 0, buttons: [])])
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "links-download.example.invalid", request.httpMethod == "GET",
              request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-token" else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        let status: Int
        var headers = ["ETag": "\"fictional-links\""]
        switch url.path {
        case "/unavailable": status = 503
        case "/unavailable-with-revision": status = 503; headers["X-Links-Revision"] = Self.revision
        case "/unauthorized": status = 401
        case "/forbidden": status = 403
        case "/no-revision": status = 200
        case "/invalid-revision": status = 200; headers["X-Links-Revision"] = "invalid"
        case "/changed": status = 200; headers["X-Links-Revision"] = String(repeating: "C", count: 43)
        case "/current": status = 200; headers["X-Links-Revision"] = Self.revision
        default: client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        guard let body = status == 200 ? try? JSONEncoder().encode(Self.payload(digest: "b")) : Data(),
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class TimetableModelTests: XCTestCase {
    func testActualLinksModelSharesOwnedURLSessionAcrossAutomaticAndManualWaiters() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("links-model-network-"+UUID().uuidString)
        let suite = "links-model-network-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { try? FileManager.default.removeItem(at:root); defaults.removePersistentDomain(forName:suite); LinksRevisionTransport.reset() }
        LinksRevisionTransport.reset()
        var sessions = 0
        let model = LinksModel(preferencesStore:LinkPreferencesStore(defaults:defaults),storeRoot:root,revisionNetwork:{
            sessions += 1
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [LinksRevisionTransport.self]; configuration.urlCache = nil
            return URLSession(configuration:configuration)
        },endpoint:URL(string:"https://links.example.invalid/links")!)
        defer { model.resetForRetention() }
        let started = expectation(description:"single actual revision transport")
        LinksRevisionTransport.expectStart(started)
        let first = Task { await model.refresh() }
        await fulfillment(of:[started],timeout:5)
        let second = Task { await model.refresh() }
        let manual = Task { try await model.revision() }
        for _ in 0..<1000 { if model.pendingRevisionWaiters == 3 { break }; await Task.yield() }
        XCTAssertEqual(model.pendingRevisionWaiters,3); XCTAssertEqual(LinksRevisionTransport.count,1)
        first.cancel(); await first.value
        XCTAssertTrue(model.busy); XCTAssertEqual(model.pendingRevisionWaiters,2)
        LinksRevisionTransport.release()
        await second.value
        let manualValue = try await manual.value
        XCTAssertEqual(manualValue,.available(String(repeating:"A",count:43)))
        XCTAssertEqual(sessions,1); XCTAssertFalse(model.busy); XCTAssertFalse(model.failed)
        model.report(LinksError.unavailable); let error = model.message
        await model.refresh()
        XCTAssertEqual(LinksRevisionTransport.count,1); XCTAssertEqual(model.message,error); XCTAssertTrue(model.failed)
        let forcedStarted = expectation(description:"forced check bypasses TTL")
        LinksRevisionTransport.expectStart(forcedStarted)
        let forced = Task { await model.refresh(force:true) }
        await fulfillment(of:[forcedStarted],timeout:5)
        XCTAssertEqual(LinksRevisionTransport.count,2); XCTAssertTrue(model.busy)
        LinksRevisionTransport.release(); await forced.value
        XCTAssertFalse(model.failed); XCTAssertFalse(model.busy); XCTAssertEqual(sessions,2)
        let resetStarted = expectation(description:"request before retention reset")
        LinksRevisionTransport.expectStart(resetStarted)
        let reset = Task { await model.refresh(force:true) }
        await fulfillment(of:[resetStarted],timeout:5)
        model.resetForRetention(); await reset.value
        XCTAssertFalse(model.ready); XCTAssertFalse(model.busy); XCTAssertNil(model.saved)
    }

    func testFailedLinkRevisionRetainsUnreadableCacheWarningAndBytes() async throws {
        let suite = "links-model-read-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let store = root.appendingPathComponent("LinksAPI", isDirectory: true)
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite); LinksRevisionTransport.reset() }
        LinksRevisionTransport.reset()
        let file = store.appendingPathComponent("links.json")
        let original = Data("{fictional-unreadable-links".utf8)
        try original.write(to: file)
        let model = LinksModel(preferencesStore: LinkPreferencesStore(defaults: defaults), storeRoot: root, revisionNetwork: {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [LinksRevisionTransport.self]
            return URLSession(configuration: config)
        }, endpoint: URL(string: "https://links.example.invalid/links")!)
        defer { model.resetForRetention() }
        model.loadIfNeeded()
        let warning = try XCTUnwrap(model.message)
        XCTAssertTrue(model.failed && model.saved == nil)
        let started = expectation(description: "fictional unavailable link revision")
        LinksRevisionTransport.expectStart(started)
        let refresh = Task { await model.refresh(force: true) }
        let wait = await XCTWaiter.fulfillment(of: [started], timeout: 5)
        guard wait == .completed else {
            refresh.cancel()
            await refresh.value
            XCTFail("Link revision request did not start")
            return
        }
        LinksRevisionTransport.release(status: 503)
        await refresh.value
        XCTAssertEqual(model.message, warning + "\n" + LinksError.unavailable.localizedDescription)
        XCTAssertTrue(model.failed && model.saved == nil)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testLinkDownloadDistinguishesUnavailableInvalidAndChangedResponses() async throws {
        let suite = "links-download-status-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        let directory = root.appendingPathComponent("LinksAPI", isDirectory: true)
        let store = try LinksStore(root: directory)
        let original = SavedLinks(payload: LinksDownloadTransport.payload(digest: "a"), apiETag: "\"original\"",
                                  checkedAt: Date(timeIntervalSince1970: 0), revision: String(repeating: "A", count: 43))
        try store.save(original)
        let file = directory.appendingPathComponent("links.json")
        let originalBytes = try Data(contentsOf: file)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LinksDownloadTransport.self]
        let network = URLSession(configuration: config)
        defer { network.invalidateAndCancel() }
        func model(_ path: String) throws -> LinksModel {
            let url = try XCTUnwrap(URL(string: "https://links-download.example.invalid/" + path))
            let model = LinksModel(preferencesStore: LinkPreferencesStore(defaults: defaults), storeRoot: root, endpoint: url)
            model.loadIfNeeded()
            return model
        }
        for (path, description) in [
            ("unavailable", LinksError.unavailable.localizedDescription),
            ("unavailable-with-revision", LinksError.unavailable.localizedDescription),
            ("unauthorized", "認証を完了できませんでした。"),
            ("forbidden", "認証を完了できませんでした。"),
            ("no-revision", LinksError.invalidResponse.localizedDescription),
            ("invalid-revision", LinksError.invalidResponse.localizedDescription),
            ("changed", "取得中に一覧が更新されました。もう一度お試しください。"),
        ] {
            let current = try model(path)
            do {
                try await current.download(token: "synthetic-token", revision: LinksDownloadTransport.revision, network: network)
                XCTFail("Unexpectedly accepted \(path)")
            } catch { current.report(error) }
            XCTAssertEqual(current.message, description + " 保存済みの一覧を表示しています。", path)
            XCTAssertEqual(current.saved, original, path)
            XCTAssertEqual(try Data(contentsOf: file), originalBytes, path)
        }
        let current = try model("current")
        try await current.download(token: "synthetic-token", revision: LinksDownloadTransport.revision, network: network)
        XCTAssertFalse(current.failed)
        XCTAssertEqual(try store.load()?.revision, LinksDownloadTransport.revision)
        XCTAssertEqual(try store.load()?.payload, LinksDownloadTransport.payload(digest: "b"))
    }

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
            XCTAssertEqual(reopened.revisionConfirmation?.outcome, .adopted)
            XCTAssertEqual(reopened.revisionConfirmation, current.revisionConfirmation)
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
            let warning = try XCTUnwrap(current.message)
            if host == "failure.example.test" {
                do { _ = try await current.revision(using: network); XCTFail("Failed revision was accepted") }
                catch { current.report(error) }
                XCTAssertEqual(current.message, warning + "\n" + TimetableTimesError.unavailable.localizedDescription)
            }
            do {
                try await current.download(token: token, revision: requestedRevision, network: network)
                XCTFail("Failed download must not replace the cache")
            } catch {
                XCTAssertTrue(error is TimetableTimesError)
                current.report(error)
                XCTAssertEqual(current.message, warning + "\n" + error.localizedDescription)
            }
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

    func testDisjointChangeDetailsAndGridAgreeOnAffectedPeriods() throws {
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
        XCTAssertEqual(selection.comparison.groups.compactMap { $0.pairs.first?.before }, ["架空科目1", "架空科目3"])
        XCTAssertEqual(selection.comparison.groups.map(\.periods), [[1], [3]])
        XCTAssertEqual(selection.relatedChanges, [overlap, disjointOverlap])
        XCTAssertEqual(presentation.changeSelection(for: change("1,3", before: "架空明記科目A")).comparison.groups.first?.pairs.first?.before, "架空明記科目A")
        for notation in ["1,3", "3,1", "1・3限", "確認が必要"] {
            let row = change(notation)
            let changes = ChangeAnalysis(sourceDigest: "fictional", sourceName: "fictional.xlsx",
                defaultYear: 2032, parsedAt: Date(), records: [row])
            let schedule = TimetableDaySchedule(timetable: timetable, changes: changes,
                events: nil, specials: [], includesChanges: true)
            let changedPeriods = notation == "確認が必要" ? [] : [1, 3]
            for period in 1...3 {
                let expected = changedPeriods.contains(period) ? [row] : []
                let slot = TimetableSchedule.slot(on: day, period: period, className: "2_IT", timetable: timetable,
                    changes: changes, includesChanges: true)
                XCTAssertEqual(slot.changes, expected)
                XCTAssertEqual(schedule.sourceIndex.slot(on: day, period: period, className: "2_IT",
                    includesChanges: true), slot)
            }
            let blocks = schedule.blocks(on: day, className: "2_IT", international: false)
            let changed = blocks.filter { if case .change = $0.content { true } else { false } }
            XCTAssertEqual(changed.map(\.startPeriod), changedPeriods)
            XCTAssertEqual(changed.map(\.endPeriod), changedPeriods)
            XCTAssertTrue(blocks.contains { block in
                guard case .normal(let lesson) = block.content else { return false }
                return lesson.names.subject == "架空科目2" && block.startPeriod == 2 && block.endPeriod == 2
            })
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
            XCTAssertEqual(result.comparison.groups.compactMap { $0.pairs.first?.source }, [kind.title, kind.title])
        }
        XCTAssertTrue(presentation.changeSelection(for: change("invalid")).baseLessons.isEmpty)
        XCTAssertTrue(presentation.changeSelection(for: change("1", date: "invalid")).relatedChanges.isEmpty)
    }
}
