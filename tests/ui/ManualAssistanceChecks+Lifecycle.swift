import XCTest
import UIKit

extension ManualAssistanceChecks {
    func editStage(_ stage:String,_ e:XCUIElement) {
        let keyboardFrame=observedKeyboardFrame()
        let exists=e.exists
        print("TAKUPOKE-MANUAL-EDIT stage=\(stage);id=\(exists ? e.identifier:"absent");exists=\(exists);hittable=\(exists && e.isHittable);frame=\(exists ? String(describing:e.frame):"absent");focused=\(exists && e.debugDescription.contains("Keyboard Focused"));keyboard=\(keyboardFrame.map { String(describing:$0) } ?? "absent")")
    }
    func enterBackground()->Bool {
        print("TAKUPOKE-MANUAL-APP-STATE before-home=\(app.state.rawValue)")
        XCUIDevice.shared.press(.home)
        let background=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let state=self.app.state
            return state == .runningBackground || state == .runningBackgroundSuspended
        },object:app)
        guard XCTWaiter.wait(for:[background],timeout:nativeStateTimeout) == .completed else {
            XCTFail("Home must put the existing process in background before activation; observed=\(app.state.rawValue)")
            return false
        }
        print("TAKUPOKE-MANUAL-APP-STATE background-observed=\(app.state.rawValue)")
        guard app.state != .notRunning else {
            XCTFail("Background must preserve the existing process; no relaunch")
            return false
        }
        return true
    }
}
