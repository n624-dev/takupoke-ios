import XCTest
@testable import TakupokeParsing

final class MainColorTests: XCTestCase {
    func testDefaultAndChoiceOrder() {
        XCTAssertEqual(MainColor.allCases.map(\.title),
                       ["デフォルト", "青", "緑", "黄色", "オレンジ", "赤", "ピンク", "紫"])
    }

    func testUnsetPreferenceDoesNotCreateAStoredColor() throws {
        let suite = "MainColorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selection = defaults.string(forKey: MainColor.storageKey)
            .flatMap(MainColor.init(rawValue:)) ?? .systemDefault
        XCTAssertEqual(selection, .systemDefault)
        XCTAssertNil(defaults.object(forKey: MainColor.storageKey))
    }

    func testAllSavedColorsSurviveReadAndDefaultRemovesOnlyColor() throws {
        let suite = "MainColorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("fictional-class", forKey: "timetableSelectedClasses")
        for choice in MainColor.allCases where choice != .systemDefault {
            choice.save(in: defaults)
            XCTAssertEqual(defaults.string(forKey: MainColor.storageKey), choice.rawValue)
            XCTAssertEqual(defaults.string(forKey: MainColor.storageKey)
                .flatMap(MainColor.init(rawValue:)), choice)
            MainColor.systemDefault.save(in: defaults)
            XCTAssertNil(defaults.object(forKey: MainColor.storageKey))
            XCTAssertEqual(defaults.string(forKey: "timetableSelectedClasses"), "fictional-class")
        }
    }

    #if canImport(SwiftUI)
    func testDefaultHasNoTintOverrideAndExplicitBlueIsKept() {
        XCTAssertNil(MainColor.systemDefault.color)
        XCTAssertNotNil(MainColor.blue.color)
        XCTAssertTrue(MainColor.allCases.filter { $0 != .systemDefault }.allSatisfy { $0.color != nil })
    }
    #endif
}
