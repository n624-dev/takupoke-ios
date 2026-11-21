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
                if theme != .systemDefault { XCTAssertTrue(explicitColors.insert(color).inserted, theme.title) }
            }
        }
    }

    func testLightYellowReachesSmallTextContrastAndKeepsTheSystemDarkYellow() throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("Resolved SwiftUI colors require macOS 14") }
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        let standard = try XCTUnwrap(MainColor.yellow.color(for: .light, contrast: .standard)).resolve(in: environment)
        let increased = try XCTUnwrap(MainColor.yellow.color(for: .light, contrast: .increased)).resolve(in: environment)
        for tint in [standard, increased] {
            XCTAssertGreaterThan(tint.linearRed, 0)
            XCTAssertGreaterThan(tint.linearGreen, tint.linearRed * 0.80, "Keep the hue near yellow")
            XCTAssertLessThan(tint.linearBlue, tint.linearGreen * 0.10, "Keep a saturated yellow")
        }
        func luminance(_ color: Color.Resolved) -> Double {
            0.2126 * Double(color.linearRed) + 0.7152 * Double(color.linearGreen) + 0.0722 * Double(color.linearBlue)
        }
        for level in [1.0, 0.85] {
            let background = Color(.sRGB, red: level, green: level, blue: level).resolve(in: environment)
            XCTAssertGreaterThanOrEqual((luminance(background) + 0.05) / (luminance(standard) + 0.05), 4.5)
        }
        XCTAssertLessThan(luminance(increased), luminance(standard))
        environment.colorScheme = .dark
        for contrast in [ColorSchemeContrast.standard, .increased] {
            let dark = try XCTUnwrap(MainColor.yellow.color(for: .dark, contrast: contrast))
            XCTAssertEqual(dark.resolve(in: environment), Color.yellow.resolve(in: environment))
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
        XCTAssertTrue(MainColor.allCases.filter { $0 != .systemDefault }
            .allSatisfy { $0.color(for: .light, contrast: .standard) != nil })
    }
    #endif
}
