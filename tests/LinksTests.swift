import Foundation
import XCTest
@testable import TakupokeParsing

final class LinksTests: XCTestCase {
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
        XCTAssertEqual(LinkSearch.score(terms: "かくうりんく", query: "unrelated"), -1)
    }
}
