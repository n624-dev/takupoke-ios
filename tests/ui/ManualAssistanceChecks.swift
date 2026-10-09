import XCTest
import UIKit

final class ManualAssistanceChecks:XCTestCase {
    var app:XCUIApplication!
    var fixtureMenuOpen=false
    // AX snapshots on a loaded simulator can take longer than five seconds.
    // Keep every native state assertion, allowing bounded time to observe it.
    let nativeStateTimeout:TimeInterval=45
    override func setUp() { continueAfterFailure=false;app=XCUIApplication() }
    func launch(_ flags:[String]=[]) {
        app.launchArguments=["--reset-fixture","--manual-ui","--manual-integral-rails","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]+flags
        app.launch();XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout:45),app.debugDescription)
        app.tabBars.buttons["設定"].tap();tap("時間割ファイル");tap("通常時間割の詳細を見る");tap("端末内で復旧する");tap("端末内で復旧を開始")
    }
    let fixtureMenuActions=["表示サイズを変更","同じ原本の状態を再確認","架空原本のハッシュを変更"]
}
