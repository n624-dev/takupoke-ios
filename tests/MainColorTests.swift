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
    func testWeekControlsKeepThemeAndContrastInLightAndDarkAppearances() throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("Resolved SwiftUI colors require macOS 14") }
        func luminance(_ color: Color.Resolved) -> Double {
            0.2126 * Double(color.linearRed) + 0.7152 * Double(color.linearGreen) + 0.0722 * Double(color.linearBlue)
        }
        for scheme in [ColorScheme.light, .dark] {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            let surface = scheme == .light ? 0.75 : 0.06
            for increased in [false, true] {
                var explicitColors = Set<Color.Resolved>()
                for theme in MainColor.allCases {
                    let style = WeekControlAccent(theme: theme)
                    let color = style.color(in: environment, increasedContrast: increased).resolve(in: environment)
                    let ink = luminance(color)
                    let ratio = (max(ink, surface) + 0.05) / (min(ink, surface) + 0.05)
                    XCTAssertGreaterThanOrEqual(ratio + 0.001, increased ? 7 : 4.5, theme.title)
                    if theme != .systemDefault { XCTAssertTrue(explicitColors.insert(color).inserted, theme.title) }
                }
            }
        }
    }

    func testDefaultHasNoTintOverrideAndExplicitBlueIsKept() {
        XCTAssertNil(MainColor.systemDefault.color)
        XCTAssertNotNil(MainColor.blue.color)
        XCTAssertTrue(MainColor.allCases.filter { $0 != .systemDefault }.allSatisfy { $0.color != nil })
    }
    #endif
}
