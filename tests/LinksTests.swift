import Foundation
import XCTest
@testable import TakupokeParsing

final class LinksTests: XCTestCase {
    @MainActor private final class RevisionGate {
        let started = XCTestExpectation(description:"owned revision started")
        let cancelled = XCTestExpectation(description:"owned revision cancelled")
        var calls = 0
        var continuation: CheckedContinuation<MappingRevisionResult,Error>?
        func fetch() async throws -> MappingRevisionResult {
            calls += 1
            return try await withTaskCancellationHandler(operation:{
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation; started.fulfill()
                }
            },onCancel:{ Task { @MainActor in self.cancelled.fulfill() } })
        }
        func complete(_ value:MappingRevisionResult) {
            continuation?.resume(returning:value); continuation = nil
        }
    }
    @MainActor private func waitForWaiters(_ count:Int,_ coordinator:LinksRevisionCoordinator) async throws {
        for _ in 0..<1000 {
            if coordinator.pendingWaiterCount == count { return }
            await Task.yield()
        }
        XCTFail("revision callers did not enroll"); throw LinksError.unavailable
    }
    @MainActor func testRevisionWorkCoalescesForcedCallerAndCancelsOnlyItsOwnWait() async throws {
        let coordinator = LinksRevisionCoordinator(), gate = RevisionGate()
        defer { coordinator.reset(); gate.complete(.unchanged) }
        let first = Task { try await coordinator.value(installed:"fictional-v1",force:false,fetch:gate.fetch) }
        await fulfillment(of:[gate.started],timeout:2)
        let second = Task { try await coordinator.value(installed:"fictional-v1",force:true,fetch:gate.fetch) }
        try await waitForWaiters(2,coordinator)
        first.cancel()
        switch await first.result { case .failure(let error): XCTAssertTrue(error is CancellationError); case .success: XCTFail("cancelled waiter succeeded") }
        XCTAssertEqual(coordinator.pendingWaiterCount,1); XCTAssertEqual(gate.calls,1)
        gate.complete(.available("fictional-v2"))
        let secondValue = try await second.value
        XCTAssertEqual(secondValue,.available("fictional-v2"))
        XCTAssertEqual(coordinator.pendingWaiterCount,0)
    }
    @MainActor func testRevisionTTLForceFailureAndInstalledRevisionUseTheSameCoordinator() async throws {
        var time = 0.0, calls = 0
        let coordinator = LinksRevisionCoordinator(minimumInterval:300,now:{ time })
        func request(_ installed:String?,_ force:Bool = false,_ fail:Bool = false) async throws -> MappingRevisionResult {
            try await coordinator.value(installed:installed,force:force) {
                calls += 1
                if fail { throw LinksError.unavailable }
                return .available("fictional-v2")
            }
        }
        let initial = try await request(nil)
        XCTAssertEqual(initial,.available("fictional-v2")); XCTAssertEqual(calls,1)
        time = 10; _ = try await request(nil); XCTAssertEqual(calls,1)
        _ = try await request(nil,true); XCTAssertEqual(calls,2)
        time = 309; _ = try await request(nil); XCTAssertEqual(calls,2)
        time = 310
        do { _ = try await request(nil,false,true); XCTFail("expired request failure was cached as success") } catch { XCTAssertTrue(error is LinksError) }
        _ = try await request(nil); XCTAssertEqual(calls,4)
        _ = try await request("fictional-v2"); XCTAssertEqual(calls,5)
        coordinator.reset(); _ = try await request("fictional-v2"); XCTAssertEqual(calls,6)
    }
    @MainActor func testLastRevisionWaiterCancellationCancelsOwnerAndCannotInstallLateSuccess() async throws {
        let coordinator = LinksRevisionCoordinator(), gate = RevisionGate()
        defer { coordinator.reset(); gate.complete(.unchanged) }
        let request = Task { try await coordinator.value(installed:nil,force:false,fetch:gate.fetch) }
        await fulfillment(of:[gate.started],timeout:2)
        request.cancel()
        switch await request.result { case .failure(let error): XCTAssertTrue(error is CancellationError); case .success: XCTFail("cancelled waiter succeeded") }
        await fulfillment(of:[gate.cancelled],timeout:2)
        gate.complete(.available("fictional-stale"))
        let result = try await coordinator.value(installed:nil,force:false) { .available("fictional-fresh") }
        XCTAssertEqual(result,.available("fictional-fresh"))
    }
    @MainActor func testRevisionResetRejectsOldGenerationWhileNewOwnerCompletes() async throws {
        let coordinator = LinksRevisionCoordinator(), old = RevisionGate(), current = RevisionGate()
        defer { coordinator.reset(); old.complete(.unchanged); current.complete(.unchanged) }
        let stale = Task { try await coordinator.value(installed:nil,force:false,fetch:old.fetch) }
        await fulfillment(of:[old.started],timeout:2)
        coordinator.reset()
        switch await stale.result { case .failure(let error): XCTAssertTrue(error is CancellationError); case .success: XCTFail("reset waiter succeeded") }
        let fresh = Task { try await coordinator.value(installed:nil,force:false,fetch:current.fetch) }
        await fulfillment(of:[current.started],timeout:2)
        old.complete(.available("fictional-old")); current.complete(.available("fictional-current"))
        let freshValue = try await fresh.value
        XCTAssertEqual(freshValue,.available("fictional-current"))
        let cached = try await coordinator.value(installed:nil,force:false) { XCTFail("current success was not cached"); return .unchanged }
        XCTAssertEqual(cached,.available("fictional-current"))
    }
    func testStableLinkRowInputsIncludeEveryRenderedValueAndActionOwner() {
        let owner = UUID()
        func item(_ href:String) -> LinkItem {
            LinkItem(id:"fictional-row",categoryId:"fictional-category",label:"架空リンク",href:href,
                color:"sky",visible:true,sortOrder:0,recommended:false,recommendationOrder:0,searchAliases:[],searchTerms:"")
        }
        let original = item("https://example.invalid/first")
        func value(subtitle:String? = nil,ready:Bool = true,favorite:Bool = false,color:String = "sky",
                   override:Bool = false,actionOwner:UUID? = nil,link:LinkItem? = nil) -> LinkRowPresentation {
            LinkRowPresentation(item:link ?? original,subtitle:subtitle,preferencesReady:ready,favorite:favorite,
                color:color,hasColorOverride:override,actionOwner:actionOwner ?? owner)
        }
        XCTAssertEqual(value(),value())
        for changed in [value(subtitle:"架空カテゴリ"),value(ready:false),value(favorite:true),value(color:"blue"),
                        value(override:true),value(actionOwner:UUID()),value(link:item("https://example.invalid/second"))] {
            XCTAssertNotEqual(value(),changed)
        }
    }
    func testLateSearchTermsRemainMatchesWithExactPrefixAndSubstringPriority() throws {
        let terms = (0..<1001).map { "q\($0)" }.joined(separator: "|") + "|needle"
        let late = LinkItem(id: "fictional-late", categoryId: "fictional-category", label: "架空リンク",
            href: "https://example.invalid/late", color: "sky", visible: true, sortOrder: 0,
            recommended: false, recommendationOrder: 0, searchAliases: [], searchTerms: terms)
        _ = try LinksPayload.decode(JSONEncoder().encode(payload([late])))
        XCTAssertLessThanOrEqual(terms.count, 5000)
        let exact = LinkSearch.score(terms: terms, query: "needle")
        let prefix = LinkSearch.score(terms: terms, query: "need")
        let substring = LinkSearch.score(terms: terms, query: "eed")
        XCTAssertGreaterThanOrEqual(substring, 0)
        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, substring)
        XCTAssertEqual(LinkSearch.score(terms: terms, query: "absent"), -1)
        let kana = (0..<334).map { "あ\($0)" }.joined(separator: "|") + "|finalmatch"
        XCTAssertGreaterThanOrEqual(LinkSearch.score(terms: kana, query: "finalmatch"), 0)
        XCTAssertGreaterThan(LinkSearch.score(terms: "needle|needless", query: "needle"),
                             LinkSearch.score(terms: "another|needle", query: "needle"))
    }

    func testAllPrivateResourceCombinationsUseOneAppropriateAuthentication() {
        for mask in 0..<8 {
            let selection = AccountDataSelection(rawValue: mask)
            XCTAssertEqual(selection.permitsSchoolNetwork, mask == 1)
            XCTAssertEqual(selection.scope.contains("links.read"), mask & 1 != 0)
            XCTAssertEqual(selection.scope.contains("mapping.read"), mask & 6 != 0)
            XCTAssertTrue(selection.acceptsAssurance(acr: "urn:takunin:assurance:strict", amr: ["microsoft"]))
            XCTAssertEqual(selection.acceptsAssurance(acr: "urn:takunin:assurance:standard", amr: ["school_network"]), mask == 1)
            XCTAssertFalse(selection.acceptsAssurance(acr: "urn:takunin:assurance:standard", amr: ["microsoft"]))
        }
    }

    func testSyllabusDepartmentOnlyResolvesKnownLinkAndUsesCalendarYear() throws {
        let original = try XCTUnwrap(URL(string: "https://l.n624.jp/gSBBt"))
        for department in SyllabusLinkPolicy.departments {
            XCTAssertEqual(SyllabusLinkPolicy.resolve(label: "高専Webシラバス", original: original, departmentID: department.id, year: 2033).absoluteString,
                           "https://l.n624.jp/KCWgd?department_id=\(department.id)&year=2033")
        }
        for department in ["", "unknown"] {
            XCTAssertEqual(SyllabusLinkPolicy.resolve(label: "高専Webシラバス", original: original, departmentID: department, year: 2033), original)
        }
        let unrelated = try XCTUnwrap(URL(string: "https://example.invalid/gSBBt"))
        XCTAssertEqual(SyllabusLinkPolicy.resolve(label: "高専Webシラバス", original: unrelated, departmentID: "49", year: 2033), unrelated)
        XCTAssertEqual(SyllabusLinkPolicy.resolve(label: "架空リンク", original: original, departmentID: "49", year: 2033), original)
    }
    private let tag = "W/\"fictional-links-etag\""

    func testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary() throws {
        let web = try XCTUnwrap(URL(string: "https://example.invalid/path"))
        let app = try XCTUnwrap(URL(string: "jrshikoku://fictional"))
        XCTAssertEqual(LinkOpeningMode.external.destination(for: web), .external)
        XCTAssertEqual(LinkOpeningMode.external.destination(for: web, opposite: true), .inApp)
        XCTAssertEqual(LinkOpeningMode.external.destination(for: web), .external)
        XCTAssertEqual(LinkOpeningMode.inApp.destination(for: web), .inApp)
        XCTAssertEqual(LinkOpeningMode.inApp.destination(for: web, opposite: true), .external)
        XCTAssertEqual(LinkOpeningMode.inApp.destination(for: app, opposite: true), .external)
        XCTAssertEqual(LinkOpeningMode.inApp.destination(for: app), .external)
    }

    private func item(id: String = "fictional-link", href: String = "https://example.invalid/path",
                      visible: Bool = true, label: String = "架空リンクA", sortOrder: Int = 1,
                      recommended: Bool = false, recommendationOrder: Int = 0) -> LinkItem {
        LinkItem(id: id, categoryId: "fictional-category", label: label, href: href,
                 color: "sky", visible: visible, sortOrder: sortOrder, recommended: recommended,
                 recommendationOrder: recommendationOrder, searchAliases: ["架空別名A"], searchTerms: "かくうりんく|fictional")
    }

    func testRecommendationsRespectVisibilityAndAstroOrdering() throws {
        let links = payload([
            item(id: "later", recommended: true, recommendationOrder: 20),
            item(id: "name-second", label: "架空リンクい", sortOrder: 20, recommended: true, recommendationOrder: 10),
            item(id: "name-first", label: "架空リンクあ", sortOrder: 20, recommended: true, recommendationOrder: 10),
            item(id: "first", sortOrder: 90, recommended: true, recommendationOrder: 0),
            item(id: "sort-first", sortOrder: 10, recommended: true, recommendationOrder: 10),
            item(id: "hidden-by-user", recommended: true),
            item(id: "hidden-by-api", visible: false, recommended: true),
            item(id: "not-recommended")
        ])
        let decoded = try LinksPayload.decode(JSONEncoder().encode(links))
        XCTAssertEqual(decoded.recommendations(hiddenIDs: ["hidden-by-user"]).map(\.id),
                       ["first", "sort-first", "name-first", "name-second", "later"])
        XCTAssertTrue(decoded.recommendations(hiddenIDs: Set(links.categories[0].buttons.map(\.id))).isEmpty)
    }

    private func payload(_ items: [LinkItem], version: String = "v1") -> LinksPayload {
        LinksPayload(version: version, linksVersion: "sha256-" + String(repeating: "a", count: 64),
                     categories: [LinkCategory(id: "fictional-category", label: "架空カテゴリA",
                                               sortOrder: 1, buttons: items)])
    }

    func testValidatesResponseBeforeAdoptingIt() throws {
        let valid = payload([item(), item(id: "fictional-hidden", visible: false)])
        XCTAssertEqual(try LinksPayload.decode(JSONEncoder().encode(valid)), valid)
        XCTAssertThrowsError(try LinksPayload.decode(JSONEncoder().encode(payload([item()], version: "v2"))))
        XCTAssertThrowsError(try LinksPayload.decode(JSONEncoder().encode(payload([item(), item()]))))
        XCTAssertThrowsError(try LinksPayload.decode(JSONEncoder().encode(payload([item(href: "http://example.invalid")]))))
        XCTAssertThrowsError(try LinksPayload.decode(JSONEncoder().encode(payload([item(href: "https://user:pass@example.invalid")]))))
        XCTAssertEqual(try LinksPayload.decode(JSONEncoder().encode(payload([item(href: "jrshikoku://open")]))).categories.count, 1)
    }

    func testWeakETagComparisonPreservesOpaqueEmbeddedMarker() throws {
        let saved = SavedLinks(payload:payload([item()]),apiETag:"\"abcW/def\"",checkedAt:Date())
        XCTAssertThrowsError(try LinksResponse.decode(status:304,data:Data(),receivedETag:"\"abcdef\"",saved:saved))
        XCTAssertNoThrow(try LinksResponse.decode(status:304,data:Data(),receivedETag:"W/\"abcW/def\"",saved:saved))
    }
    func test200304AndFailureKeepPreviousResult() throws {
        let first = try LinksResponse.decode(status: 200, data: JSONEncoder().encode(payload([item()])),
                                             receivedETag: tag, saved: nil, checkedAt: Date(timeIntervalSince1970: 1))
        let unchanged = try LinksResponse.decode(status: 304, data: Data(), receivedETag: tag,
                                                 saved: first, checkedAt: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(unchanged.payload, first.payload)
        XCTAssertEqual(unchanged.checkedAt, Date(timeIntervalSince1970: 2))
        XCTAssertThrowsError(try LinksResponse.decode(status: 304, data: Data(), receivedETag: tag, saved: nil))
        XCTAssertThrowsError(try LinksResponse.decode(status: 304, data: Data("x".utf8), receivedETag: tag, saved: first))
        XCTAssertThrowsError(try LinksResponse.decode(status: 304, data: Data(), receivedETag: "W/\"other\"", saved: first))
        XCTAssertThrowsError(try LinksResponse.decode(status: 503, data: Data(), receivedETag: tag, saved: first))
    }

    func testCacheReplacementOnlyAfterValidSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LinksStore(root: root)
        let original = SavedLinks(payload: payload([item()]), apiETag: tag, checkedAt: Date(timeIntervalSince1970: 1))
        try store.save(original)
        XCTAssertThrowsError(try store.save(SavedLinks(payload: payload([item()], version: "v2"),
                                                        apiETag: tag, checkedAt: Date())))
        XCTAssertEqual(try store.load(), original)
    }

    func testPreferencesFollowIDAndRetainMissingItems() throws {
        let suite = "links-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LinkPreferencesStore(defaults: defaults)
        var value = LinkPreferences()
        value.favoriteIDs.insert("fictional-link")
        value.hiddenIDs.insert("temporarily-absent")
        value.colorOverrides["fictional-link"] = "teal"
        try store.save(value)
        XCTAssertEqual(try store.load(), value)
        XCTAssertEqual(try store.load().favoriteIDs, ["fictional-link"])
        value.colorOverrides["fictional-link"] = "not-a-color"
        XCTAssertThrowsError(try store.save(value))
        XCTAssertEqual(try store.load().colorOverrides["fictional-link"], "teal")
    }

    func testSearchMatchesKanaRomajiAndRanking() {
        XCTAssertEqual(LinkSearch.normalize("ｶﾀｶﾅ！"), "かたかな")
        XCTAssertEqual(LinkSearch.romaji("しゃっくり"), "shakkuri")
        XCTAssertGreaterThanOrEqual(LinkSearch.score(terms: "しら|しらばす", query: "sira"), 0)
        XCTAssertGreaterThan(LinkSearch.score(terms: "かくう|かくうりんく", query: "かくう"),
                             LinkSearch.score(terms: "かくうりんく", query: "かくう"))
        for term in ["ちゅうごく","チュウゴク","ﾁｭｳｺﾞｸ"] {
            XCTAssertGreaterThanOrEqual(LinkSearch.score(terms:term,query:"chugoku"),0)
            XCTAssertGreaterThanOrEqual(LinkSearch.score(terms:term,query:"chuugoku"),0)
        }
        XCTAssertGreaterThanOrEqual(LinkSearch.score(terms:"ＡＢＣ",query:"abc"),0)
        XCTAssertEqual(LinkSearch.score(terms: "かくうりんく", query: "unrelated"), -1)
    }
}
