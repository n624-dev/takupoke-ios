import XCTest

final class MaterialPickerTapChecks: XCTestCase {
    func testReselectionWithMissingAppearanceReturn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--tap-checks", "--unpaired-appearance", "-AppleLanguages", "(en)"]
        app.launch()
        app.tabBars.buttons["設定"].tap()
        app.buttons["ファイル選択"].tap()
        // Fault injection isolates the stale appearance record. This does not
        // claim that OneDrive emits this exact callback sequence.
        chooseAndCancel(app, kind: 0)
    }

    func testReselectionThroughActualButtons() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--tap-checks", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons["設定"].tap()
        app.buttons["ファイル選択"].tap()

        // Open before ever visiting a detail screen, then repeat across all kinds.
        for index in 0..<8 { chooseAndCancel(app, kind: index % 4) }
        reveal(app, identifier: "detail-0")
        app.buttons["detail-0"].tap()
        XCTAssertTrue(app.staticTexts["架空の詳細"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        chooseAndCancel(app, kind: 0)

        app.tabBars.buttons["ホーム"].tap()
        app.tabBars.buttons["設定"].tap()
        chooseAndCancel(app, kind: 1)
        XCUIDevice.shared.press(.home)
        app.activate()
        chooseAndCancel(app, kind: 2)
    }

    private func reveal(_ app: XCUIApplication, identifier: String) {
        let button = app.buttons[identifier]
        for _ in 0..<4 where !button.isHittable { app.swipeUp() }
        if !button.isHittable {
            for _ in 0..<4 where !button.isHittable { app.swipeDown() }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(button.isHittable, "Button is not hittable: \(identifier)\n\(app.debugDescription)")
    }

    private func chooseAndCancel(_ app: XCUIApplication, kind: Int) {
        reveal(app, identifier: "choose-\(kind)")
        app.buttons["choose-\(kind)"].tap()
        let instruction = app.staticTexts["架空ファイル\(kind)を選んでください"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 8), "Picker did not open after tap \(kind)\n\(app.debugDescription)")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), app.debugDescription)
        cancel.tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: instruction)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 8), .completed)
    }
}
