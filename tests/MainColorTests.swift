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
    func testWeekControlsUseTheSharedTintInBothAppearances() throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("Resolved SwiftUI colors require macOS 14") }
        for scheme in [ColorScheme.light, .dark] {
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            var explicitColors = Set<Color.Resolved>()
            for theme in MainColor.allCases {
                let style = WeekControlAccent(theme: theme)
                let color = style.resolve(in: environment).resolve(in: environment)
                let tint = theme.color(for: scheme, contrast: environment.colorSchemeContrast) ?? .accentColor
                XCTAssertEqual(color, tint.resolve(in: environment), theme.title)
                if theme == .yellow && scheme == .light {
                    XCTAssertEqual(color, Color.accentColor.resolve(in: environment))
                } else if theme != .systemDefault {
                    XCTAssertTrue(explicitColors.insert(color).inserted, theme.title)
                }
            }
        }
    }

    func testLightYellowIsAnIconColorAndDarkYellowRemainsSystemTint() throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("Resolved SwiftUI colors require macOS 14") }
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        let icon = MainColor.lightYellowIcon.resolve(in: environment)
        XCTAssertEqual(icon.red, 1, accuracy: 0.002)
        XCTAssertEqual(icon.green, 0.8, accuracy: 0.002)
        XCTAssertEqual(icon.blue, 0, accuracy: 0.002)
        for contrast in [ColorSchemeContrast.standard, .increased] {
            XCTAssertNil(MainColor.yellow.color(for: .light, contrast: contrast),
                         "Light yellow icons must not change the native tint of functional controls")
            XCTAssertEqual(MainColor.yellow.displayColor(for: .light, contrast: contrast), .accentColor)
        }
        let standardTitle = try XCTUnwrap(MainColor.yellow.tabTitleTint(for: .light, contrast: .standard))
        let title = standardTitle.resolve(in: environment)
        XCTAssertEqual(title.red, 71.0 / 255, accuracy: 0.002)
        XCTAssertEqual(title.green, 71.0 / 255, accuracy: 0.002)
        XCTAssertEqual(title.blue, 76.0 / 255, accuracy: 0.002)
        XCTAssertEqual(MainColor.yellow.tabTitleTint(for: .light, contrast: .increased), .primary)
        environment.colorScheme = .dark
        for contrast in [ColorSchemeContrast.standard, .increased] {
            let dark = try XCTUnwrap(MainColor.yellow.color(for: .dark, contrast: contrast))
            XCTAssertEqual(dark.resolve(in: environment), Color.yellow.resolve(in: environment))
            XCTAssertEqual(MainColor.yellow.tabTitleTint(for: .dark, contrast: contrast), dark)
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
        XCTAssertNil(MainColor.systemDefault.color(for: .light, contrast: .standard))
        XCTAssertEqual(MainColor.blue.color(for: .light, contrast: .standard), .blue)
        XCTAssertTrue(MainColor.allCases.filter { $0 != .systemDefault && $0 != .yellow }
            .allSatisfy { $0.color(for: .light, contrast: .standard) != nil })
        for scheme in [ColorScheme.light, .dark] {
            for contrast in [ColorSchemeContrast.standard, .increased] {
                for theme in MainColor.allCases where theme != .yellow {
                    XCTAssertEqual(theme.tabTitleTint(for: scheme, contrast: contrast),
                                   theme.color(for: scheme, contrast: contrast))
                }
            }
        }
    }
    #endif
}
