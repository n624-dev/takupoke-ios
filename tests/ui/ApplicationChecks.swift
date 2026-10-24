import XCTest
import UIKit
import CryptoKit

final class ApplicationChecks: XCTestCase {
    var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        let initialConditions: [String: [String]] = [
            "testLinkPreferencesSurviveRelaunch": ["--fixture-input-trace"],
            "testSettingsAccountDataAndFileDetails": ["--ai-feature-probe"],
            "testRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData": ["--retention-corrupt"],
            "testTimetableDynamicTypeScalesAndRestoresStandardLayout": ["--grid-probe"],
            "testTimetableUsesSystemTextSize": ["--grid-probe", "--system-text-size"],
            "testTimetableCommonClocksAndEventOnlyWeekScale": ["--grid-probe", "--normal-only"],
            "testEmptyDataCanBeConfigured": ["--empty-fixture"],
            "testChangedAccountDataNoticeOpensSharedAcquisition": ["--updated-revisions"],
            "testFileFailuresKeepResultsAndStayInTheirOwnDetails": ["--failed-refresh"],
            "testFirstFailedSpecialDocumentsWarnOnHomeAndWeekAndOpenTheirDetails": ["--first-failed-special"],
            "testVoiceOverReadsTimetableCard": ["--mapped-names"],
            "testNotificationControlsAndAppearance": ["--theme-probe", "--notification-permission-probe"],
            "testChangedDataProducesOneLocalNotification": ["--notification-permission-probe"],
            "testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption": ["--recovery-preview"],
            "testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis": [
                "--recovery-preview", "--recovery-parallel",
            ],
            "testRecoveryClosingKeepsFormalAndModelManagementIsAccessible": ["--recovery-preview"],
            "testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption": [
                "--recovery-preview", "--recovery-exam",
            ],
            "testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster": ["--recovery-ocr-probe"],
            "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork": [
                "--selection-snapshot", "--normal-only",
            ],
            "testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover": ["--auxiliary-store-failures", "--auxiliary-store-day", "--normal-only"],
            "testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair": ["--events-cache-corrupt"],
            "testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates": [
                "--events-year-coverage", "--normal-only",
            ],
            "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch": ["--change-row-skip", "--fixture-input-trace"],
        ]
        for (method, arguments) in initialConditions where name.contains(method) {
            app.launchArguments += arguments
        }
        #if !TAKUPOKE_VOICEOVER_AUTOMATION
            if name.contains("testVoiceOverReadsTimetableCard") { return }
        #endif
        if name.contains("testRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData") {
            launchReady(expectDataReady: false)
            return
        }
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30), app.debugDescription)
    }
    private func prepareSystemUI() -> Bool {
        // U43: a successful initial process did not prove input readiness after
        // relaunch. Observe the system surface for each single cold launch.
        let deadline = Date().addingTimeInterval(45)
        print("UI_AUTOMATION_PREPARATION home-once;scope=cold-launch;target-not-prelaunched")
        XCUIDevice.shared.press(.home)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var observedFrame = CGRect.null
        var observedState = -1
        let ready = expectation(for: NSPredicate { _, _ in
            guard Date() <= deadline else { return false }
            let state = system.state
            observedState = Int(state.rawValue)
            guard state == .runningForeground else { return false }
            observedFrame = system.frame
            return self.usable(observedFrame) && Date() <= deadline
        }, evaluatedWith: system)
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0, XCTWaiter.wait(for: [ready], timeout: remaining) == .completed,
            Date() <= deadline else {
            print("UI_AUTOMATION_PREPARATION failed;state=\(observedState);frame=\(observedFrame)")
            XCTFail("System UI did not respond before this cold target launch")
            return false
        }
        print("UI_AUTOMATION_READY state=\(observedState);frame=\(observedFrame)")
        return true
    }
    func launchReady(expectDataReady: Bool = true) {
        // One launch after confirmed process termination. A persistence check
        // must not overlap the previous process or be rescued by a relaunch.
        if app.state != .notRunning { app.terminate() }
        guard app.wait(for: .notRunning, timeout: 45) else {
            XCTFail("Previous fixture process did not terminate")
            return
        }
        guard prepareSystemUI() else { return }
        print("UI_LAUNCH terminated; starting one new process")
        app.launch()
        guard app.wait(for: .runningForeground, timeout: 45) else {
            XCTFail("New fixture process did not enter foreground")
            return
        }
        if expectDataReady {
            XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout: 45), app.debugDescription)
        } else {
            XCTAssertTrue(app.buttons["保存期間の管理情報を復旧"].waitForExistence(timeout: 45), app.debugDescription)
            XCTAssertFalse(app.tabBars.buttons["ホーム"].exists, app.debugDescription)
        }
    }
    func screen(_ title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), app.debugDescription)
    }
}
