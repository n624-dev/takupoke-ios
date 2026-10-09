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
            "testSettingsAccountDataAndFileDetails": ["--ai-feature-probe"],
            "testTimetableDynamicTypeScalesAndRestoresStandardLayout": ["--grid-probe"],
            "testTimetableUsesSystemTextSize": ["--grid-probe", "--system-text-size"],
            "testTimetableCommonClocksAndEventOnlyWeekScale": ["--grid-probe", "--normal-only"],
            "testEmptyDataCanBeConfigured": ["--empty-fixture"],
            "testChangedAccountDataNoticeOpensSharedAcquisition": ["--updated-revisions"],
            "testFileFailuresKeepResultsAndStayInTheirOwnDetails": ["--failed-refresh"],
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
            "testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair": ["--events-cache-corrupt"],
            "testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates": [
                "--events-year-coverage", "--normal-only",
            ],
            "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch": ["--change-row-skip"],
        ]
        for (method, arguments) in initialConditions where name.contains(method) {
            app.launchArguments += arguments
        }
        #if !TAKUPOKE_VOICEOVER_AUTOMATION
            if name.contains("testVoiceOverReadsTimetableCard") { return }
        #endif
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30), app.debugDescription)
    }
    func launchReady() {
        // One launch after confirmed process termination. A persistence check
        // must not overlap the previous process or be rescued by a relaunch.
        if app.state != .notRunning { app.terminate() }
        guard app.wait(for: .notRunning, timeout: 45) else {
            XCTFail("Previous fixture process did not terminate")
            return
        }
        print("UI_LAUNCH terminated; starting one new process")
        app.launch()
        guard app.wait(for: .runningForeground, timeout: 45) else {
            XCTFail("New fixture process did not enter foreground")
            return
        }
        XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout: 45), app.debugDescription)
    }
    func screen(_ title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), app.debugDescription)
    }
}
