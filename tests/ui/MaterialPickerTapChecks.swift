import XCTest
import UIKit

final class MaterialPickerTapChecks: XCTestCase {
    func testInstructionSurroundMatchesFilesBackground() {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--tap-checks", "--appearance-\(appearance)",
                                   "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            app.tabBars.buttons["設定"].tap()
            app.buttons["ファイル選択"].tap()
            reveal(app, identifier: "choose-0")
            app.buttons["choose-0"].tap()
            let instruction = app.staticTexts["架空ファイル0を選んでください"]
            XCTAssertTrue(instruction.waitForExistence(timeout: 8))
            let cancel = app.buttons["Cancel"].firstMatch
            XCTAssertTrue(cancel.waitForExistence(timeout: 30))
            let image = XCUIScreen.main.screenshot().image
            let surround = pixel(image, at: CGPoint(x: app.frame.minX + 4, y: instruction.frame.midY), bounds: app.frame)
            let files = pixel(image, at: CGPoint(x: app.frame.minX + 4, y: app.frame.minY + app.frame.height * 0.6), bounds: app.frame)
            print("PICKER BACKGROUND \(appearance): surround=\(surround), Files=\(files)")
            for channel in 0..<3 {
                XCTAssertEqual(surround[channel], files[channel], accuracy: 2,
                               "Background seam in \(appearance) mode")
            }
            cancel.tap()
            app.terminate()
        }
    }

    private func pixel(_ image: UIImage, at point: CGPoint, bounds: CGRect) -> [Double] {
        guard let source = image.cgImage,
              let crop = source.cropping(to: CGRect(x: (point.x - bounds.minX) * CGFloat(source.width) / bounds.width,
                y: (point.y - bounds.minY) * CGFloat(source.height) / bounds.height, width: 1, height: 1)) else {
            XCTFail("Cannot read screenshot pixel")
            return [0, 0, 0, 0]
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes.map(Double.init)
    }

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
        let button = app.buttons[identifier].firstMatch
        let top = app.navigationBars.firstMatch.frame.maxY + 4
        let bottom = app.tabBars.firstMatch.frame.minY - 4
        // isHittable may include a row XCTest can scroll to automatically.
        // Scroll explicitly before tapping so recycled List rows are settled.
        for _ in 0..<8 {
            guard button.exists else { app.swipeUp(); continue }
            if button.frame.minY < top { app.swipeDown() }
            else if button.frame.maxY > bottom { app.swipeUp() }
            else { break }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertGreaterThanOrEqual(button.frame.minY, top, app.debugDescription)
        XCTAssertLessThanOrEqual(button.frame.maxY, bottom, app.debugDescription)
        XCTAssertTrue(button.isHittable, "Button is not hittable: \(identifier)\n\(app.debugDescription)")
    }

    private func chooseAndCancel(_ app: XCUIApplication, kind: Int) {
        reveal(app, identifier: "choose-\(kind)")
        app.buttons["choose-\(kind)"].firstMatch.tap()
        let instruction = app.staticTexts["架空ファイル\(kind)を選んでください"].firstMatch
        XCTAssertTrue(instruction.waitForExistence(timeout: 8), "Picker did not open after tap \(kind)\n\(app.debugDescription)")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(instruction.waitForNonExistence(timeout: 8), "Picker instruction remained after cancellation \(kind)")
    }
}
