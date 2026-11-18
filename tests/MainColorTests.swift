import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif
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
    func testWeekControlsPreserveSelectedSystemColorInBothAppearances() throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("Resolved SwiftUI colors require macOS 14") }
        for scheme in [ColorScheme.light, .dark] {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            var explicitColors = Set<Color.Resolved>()
            for theme in MainColor.allCases {
                let style = WeekControlAccent(theme: theme)
                let color = style.resolve(in: environment).resolve(in: environment)
                XCTAssertEqual(color, theme.displayColor.resolve(in: environment), theme.title)
                if theme != .systemDefault { XCTAssertTrue(explicitColors.insert(color).inserted, theme.title) }
            }
        }
    }

    @MainActor func testSharedSelectionPublishesImmediatelyAndDefaultRemovesOnlyItsPreference() async throws {
        let suite = "MainColorModelTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("green", forKey: MainColor.storageKey)
        defaults.set("fictional-class", forKey: "timetableSelectedClasses")
        let model = MainColorModel(defaults: defaults)
        XCTAssertEqual(model.selection, .green)
        var observations: [MainColor] = []
        let subscription = model.$selection.sink { observations.append($0) }
        defer { subscription.cancel() }
        for color in [MainColor.orange, .purple, .systemDefault, .blue] {
            model.select(color)
            XCTAssertEqual(model.selection, color)
            XCTAssertEqual(observations.last, color)
            XCTAssertEqual(defaults.string(forKey: MainColor.storageKey), color == .systemDefault ? nil : color.rawValue)
        }
        XCTAssertEqual(observations, [.green, .orange, .purple, .systemDefault, .blue])
        XCTAssertEqual(defaults.string(forKey: "timetableSelectedClasses"), "fictional-class")
        XCTAssertEqual(MainColorModel(defaults: defaults).selection, .blue)
        defaults.set("unknown-future-choice", forKey: MainColor.storageKey)
        XCTAssertEqual(MainColorModel(defaults: defaults).selection, .systemDefault)
    }

    func testDefaultHasNoTintOverrideAndExplicitBlueIsKept() {
        XCTAssertNil(MainColor.systemDefault.color)
        XCTAssertNotNil(MainColor.blue.color)
        XCTAssertTrue(MainColor.allCases.filter { $0 != .systemDefault }.allSatisfy { $0.color != nil })
    }
    #endif
}
