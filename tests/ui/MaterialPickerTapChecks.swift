import XCTest
import UIKit

final class MaterialPickerTapChecks: XCTestCase {
    private var lastRevealedRow: Int?

    func testInstructionSurroundMatchesFilesBackground() {
        continueAfterFailure = false
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--tap-checks", "--appearance-\(appearance)",
                                   "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            app.tabBars.buttons["設定"].tap()
            app.buttons["ファイル選択"].tap()
            guard let button = reveal(app, identifier: "choose-0") else { return }
            button.tap()
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
            XCTAssertTrue(instruction.waitForNonExistence(timeout: 8),
                          "Picker instruction remained before terminating the appearance fixture")
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
        guard let detail = reveal(app, identifier: "detail-0") else { return }
        detail.tap()
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

    private func reveal(_ app: XCUIApplication, identifier: String) -> XCUIElement? {
        // SwiftUI List is a native CollectionView on both supported OSes.
        // A generic descendants query can expand retained picker/other-tab
        // subtrees and time out after returning from Home. Scope the real list.
        let list = app.collectionViews["picker-file-list"].firstMatch
        let button = list.buttons[identifier].firstMatch
        let navigation = app.navigationBars["ファイル選択"].firstMatch
        let tabs = app.tabBars.firstMatch
        guard let row = Int(identifier.split(separator: "-").last ?? ""), (0..<4).contains(row) else {
            XCTFail("Unknown synthetic file row: \(identifier)")
            return nil
        }
        // Native existence polling preserves XCTest's normal app idleness.
        guard navigation.waitForExistence(timeout: 30), tabs.waitForExistence(timeout: 30),
              list.waitForExistence(timeout: 10) else {
            XCTFail("File list viewport did not return")
            return nil
        }
        let barFrame = navigation.frame, tabFrame = tabs.frame
        guard !barFrame.isEmpty, !tabFrame.isEmpty,
              barFrame.maxY.isFinite, tabFrame.minY.isFinite,
              barFrame.maxY + 4 < tabFrame.minY - 4 else {
            XCTFail("File list viewport has invalid bounds")
            return nil
        }
        let top = barFrame.maxY + 4, bottom = tabFrame.minY - 4
        // The fixture has four ordered rows. After row 3, row 0 may be recycled
        // above the viewport. Scroll back before asking XCTest for its
        // offscreen frame; the failed run blocked on that query before a swipe.
        // At most three ordinary list drags; every target still needs the same
        // viewport and hittability assertions before its actual button tap.
        if let previous = lastRevealedRow, row < previous {
            for _ in row..<previous { list.swipeDown() }
        }
        for _ in 0..<8 {
            guard button.exists else { list.swipeUp(); continue }
            let frame = button.frame
            if frame.minY < top { list.swipeDown() }
            else if frame.maxY > bottom { list.swipeUp() }
            else { break }
        }
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("File button did not appear: \(identifier)")
            return nil
        }
        let frame = button.frame
        XCTAssertGreaterThanOrEqual(frame.minY, top, "Button is above file viewport: \(identifier)")
        XCTAssertLessThanOrEqual(frame.maxY, bottom, "Button is below file viewport: \(identifier)")
        XCTAssertTrue(button.isHittable, "Button is not hittable: \(identifier)")
        lastRevealedRow = row
        return button
    }

    private func chooseAndCancel(_ app: XCUIApplication, kind: Int) {
        guard let button = reveal(app, identifier: "choose-\(kind)") else { return }
        button.tap()
        let instruction = app.staticTexts["架空ファイル\(kind)を選んでください"].firstMatch
        XCTAssertTrue(instruction.waitForExistence(timeout: 8), "Picker did not open after tap \(kind)\n\(app.debugDescription)")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), app.debugDescription)
        cancel.tap()
        XCTAssertTrue(instruction.waitForNonExistence(timeout: 8), "Picker instruction remained after cancellation \(kind)")
    }
}
