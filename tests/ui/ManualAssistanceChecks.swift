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
        app.launchArguments=["--reset-fixture","--manual-ui","--fixture-input-trace","--manual-integral-rails","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]+flags
        guard launchApplicationOnce() else { return }
        app.tabBars.buttons["設定"].tap();tap("時間割ファイル");tap("通常時間割の詳細を見る");tap("端末内で復旧する");tap("端末内で復旧を開始")
    }
    func launchApplicationOnce()->Bool {
        // Observe the same cold-launch preconditions as the application suite.
        // Never prelaunch the target or retry a failed target launch.
        guard app.wait(for:.notRunning,timeout:nativeStateTimeout) else {
            XCTFail("Previous manual fixture process did not terminate")
            return false
        }
        let deadline=Date().addingTimeInterval(nativeStateTimeout)
        print("TAKUPOKE-MANUAL-LAUNCH home-once;target-not-prelaunched")
        XCUIDevice.shared.press(.home)
        let system=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        var observedFrame=CGRect.null
        var observedState = -1
        let ready=expectation(for:NSPredicate { _,_ in
            guard Date() <= deadline else { return false }
            let state=system.state
            observedState=Int(state.rawValue)
            guard state == .runningForeground else { return false }
            observedFrame=system.frame
            return ManualScrollNavigation.usable(observedFrame) && Date() <= deadline
        },evaluatedWith:system)
        let remaining=deadline.timeIntervalSinceNow
        guard remaining > 0,XCTWaiter.wait(for:[ready],timeout:remaining) == .completed,
              Date() <= deadline else {
            print("TAKUPOKE-MANUAL-LAUNCH failed;state=\(observedState);frame=\(observedFrame)")
            XCTFail("System UI did not respond before this cold manual fixture launch")
            return false
        }
        print("TAKUPOKE-MANUAL-LAUNCH ready;state=\(observedState);frame=\(observedFrame)")
        app.launch()
        guard app.staticTexts["fixture-ready"].waitForExistence(timeout:45) else {
            XCTFail("Manual fixture did not become ready: "+app.debugDescription)
            return false
        }
        return true
    }
    let fixtureMenuActions=["表示サイズを変更","同じ原本の状態を再確認","架空原本のハッシュを変更"]
}
