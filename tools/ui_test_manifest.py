"""Partition the full app suite and require every selected XCTest to complete."""
import argparse
from collections import Counter
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CHECK_SOURCES = (
    "ApplicationChecks.swift",
    "ApplicationChecks+Navigation.swift",
    "ApplicationChecks+Changes.swift",
    "ApplicationChecks+Recovery.swift",
    "ApplicationChecks+Timetable.swift",
    "ApplicationChecks+Settings.swift",
    "ApplicationChecks+Events.swift",
    "ApplicationChecks+Notifications.swift",
)
FIXTURE_SOURCES = (
    "ApplicationFixture.swift",
    "ApplicationFixture+Changes.swift",
    "ApplicationFixture+Events.swift",
    "ApplicationFixture+Grid.swift",
    "ApplicationFixture+Selection.swift",
    "ApplicationFixture+Recovery.swift",
    "ApplicationFixture+OCR.swift",
    "ApplicationFixture+NotificationPermission.swift",
)

MANUAL_CHECK_SOURCES = (
    "ManualAssistanceChecks.swift",
    "ManualAssistanceGeometry.swift",
    "ManualAssistanceChecks+Navigation.swift",
    "ManualAssistanceChecks+Review.swift",
    "ManualAssistanceChecks+Input.swift",
    "ManualAssistanceChecks+Lifecycle.swift",
    "ManualAssistanceChecks+Cases.swift",
    "ManualAssistanceChecks+OneCorrection.swift",
)


def manual_check_source(root=ROOT):
    folder = root / "tests/ui"
    actual = {path.name for path in folder.glob("ManualAssistanceChecks*.swift")}
    expected = set(MANUAL_CHECK_SOURCES) - {"ManualAssistanceGeometry.swift"}
    if actual != expected:
        raise ValueError("Manual UI test files differ from registered sources")
    return "\n".join((folder / name).read_text(encoding="utf-8")
                     for name in MANUAL_CHECK_SOURCES)


def check_source(root=ROOT):
    folder = root / "tests/ui"
    actual = {path.name for path in folder.glob("ApplicationChecks*.swift")}
    if actual != set(CHECK_SOURCES):
        raise ValueError("UI test files differ from registered sources")
    return "\n".join((folder / name).read_text(encoding="utf-8")
                     for name in CHECK_SOURCES)


SYSTEM_SIZE_TEST = "testTimetableUsesSystemTextSize"
VOICEOVER_TEST = "testVoiceOverReadsTimetableCard"
RELAUNCH_PROBE_TESTS = ("testChangedAccountDataNoticeOpensSharedAcquisition",
                        "testChangedDataProducesOneLocalNotification",
                        "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork",
                        "testLinkPreferencesSurviveRelaunch",
                        "testNotificationControlsAndAppearance",
                        "testSettingsAccountDataAndFileDetails")
# Balanced using measured case durations, including the three OS size reruns.
SHARDS = {
    "A": (
        "testTimetableCommonClocksAndEventOnlyWeekScale",
        "testUsageHelpIsOrganizedByTask",
        "testLegalDocumentsAndIndividualLicenses",
        "testFileFailuresKeepResultsAndStayInTheirOwnDetails",
        "testSettingsClassSelectionSharesTimetablePreference",
        "testMergedCardsFromAllSources",
        "testEmptyDataCanBeConfigured",
        "testChangedDataProducesOneLocalNotification",
        "testSettingsGroupsAndCompactDataOverviews",
        "testRecoveryClosingKeepsFormalAndModelManagementIsAccessible",
        "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork",
        "testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair",
        "testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates",
        "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch",
        "testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption",
    ),
    "B": (
        "testSettingsAccountDataAndFileDetails",
        SYSTEM_SIZE_TEST,
        "testNotificationControlsAndAppearance",
        "testTimetableDynamicTypeScalesAndRestoresStandardLayout",
        "testSetupCanBeSkippedAndOffersAllFiles",
        "testLinkPreferencesSurviveRelaunch",
        "testHomeTimetableAndWeekCalendar",
        VOICEOVER_TEST,
        "testChangedAccountDataNoticeOpensSharedAcquisition",
        "testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption",
        "testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster",
        "testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis",
    ),
}
REQUIRED_JOBS = frozenset(
    f"Application iOS {ios} UI {shard}" for ios in (26, 27) for shard in SHARDS
)
MANUAL_CASES = (
    "testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground",
    "testChangedOriginalCannotSubmitOrReplaceLastGood",
    "testThreeFieldsRequireEachAcknowledgementAndFourRefuses",
)
MANUAL_REQUIRED_JOBS = frozenset(
    f"Manual correction iOS {ios} / {case}" for ios in (26, 27) for case in MANUAL_CASES
)
ALL_UI_REQUIRED_JOBS = REQUIRED_JOBS | MANUAL_REQUIRED_JOBS
RESULT = re.compile(
    r"Test Case '-\[PickerTapChecks\.ApplicationChecks (test\w+)\]' "
    r"(passed|skipped|failed) \([\d.]+ seconds\)\."
)


def validate_source(source):
    declared = Counter(re.findall(r"\bfunc\s+(test\w+)\s*\(", source))
    selected = Counter(test for tests in SHARDS.values() for test in tests)
    if any(count != 1 for count in selected.values()):
        raise ValueError("UI manifest contains duplicate tests")
    # VoiceOver has one implementation per conditional compilation branch.
    if any(count != (2 if test == VOICEOVER_TEST else 1)
           for test, count in declared.items()):
        raise ValueError("Unexpected duplicate XCTest declaration")
    if set(declared) != set(selected):
        raise ValueError(f"UI manifest differs from source: "
                         f"missing={sorted(set(declared) - set(selected))}, "
                         f"obsolete={sorted(set(selected) - set(declared))}")


def selected_tests(shard):
    if shard == "all":
        return tuple(test for tests in SHARDS.values() for test in tests)
    return SHARDS[shard]


def validate_results(log, expected, ios):
    results = RESULT.findall(log)
    counts = Counter(test for test, _ in results)
    if counts != Counter(expected):
        raise ValueError(f"XCTest completion differs from selection: {dict(counts)}")
    for test, status in results:
        required = "skipped" if test == VOICEOVER_TEST and ios == 26 else "passed"
        if status != required:
            raise ValueError(f"Unexpected XCTest result: {test} {status}, expected {required}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shard", choices=(*SHARDS, "all"), default="all")
    parser.add_argument("--mode", choices=("selectors", "system-size", "verify"), required=True)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--ios", type=int, choices=(26, 27))
    parser.add_argument("--system-size-only", action="store_true")
    parser.add_argument("--relaunch-probe", action="store_true")
    parser.add_argument("--probe-case", choices=RELAUNCH_PROBE_TESTS)
    parser.add_argument("--runner-log", action="store_true")
    args = parser.parse_args()
    validate_source(check_source())
    if args.relaunch_probe and (args.shard != "all" or args.system_size_only):
        parser.error("Relaunch probe is separate from full shards and system-size checks")
    if args.probe_case and not args.relaunch_probe:
        parser.error("A focused case is only allowed in the diagnostic probe")
    if args.runner_log and args.system_size_only:
        parser.error("A complete runner log is separate from a single system-size check")
    tests = RELAUNCH_PROBE_TESTS if args.relaunch_probe else selected_tests(args.shard)
    if args.probe_case:
        tests = (args.probe_case,)
    if args.mode == "selectors":
        for test in tests:
            print("-only-testing:PickerTapChecks/ApplicationChecks/" + test)
    elif args.mode == "system-size":
        print("1" if SYSTEM_SIZE_TEST in tests else "0")
    else:
        if args.log is None or args.ios is None:
            parser.error("verify requires --log and --ios")
        if args.system_size_only:
            if SYSTEM_SIZE_TEST not in tests:
                parser.error("OS size check is not assigned to this shard")
            tests = (SYSTEM_SIZE_TEST,)
        if args.runner_log and SYSTEM_SIZE_TEST in tests:
            tests += (SYSTEM_SIZE_TEST,) * 3
        validate_results(args.log.read_text(encoding="utf-8", errors="replace"), tests, args.ios)
        print(f"Verified {len(tests)} XCTest completions on iOS {args.ios}.")


if __name__ == "__main__":
    main()
