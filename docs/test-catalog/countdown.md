# カウントダウン・日付・通知・保存

対応関係・宣言名・実行方法のSHA-256：
`45a562b5a85b6f2013168e41de0e3b12ff96ba5bf0f698d4de0e7cbca204eea9`

環境：Linux Swift／iOS 26.5・27.0シミュレータ

```bash
bash tools/test-parsing.sh
TKPK_UI_RELAUNCH_PROBE=1 TKPK_UI_PROBE_CASE=countdown bash tools/test-app-ui.sh
```

## 変更時に確認するソース

- [Takupoke/Countdown.swift](../../Takupoke/Countdown.swift)
- [Takupoke/CountdownModel.swift](../../Takupoke/CountdownModel.swift)
- [Takupoke/CountdownView.swift](../../Takupoke/CountdownView.swift)

## [tests/CountdownTests.swift](../../tests/CountdownTests.swift)

- `testJapaneseCalendarPhaseCoversLeapDayYearBoundaryAndSplitRanges`
- `testHomeFilteringAndProgressDoNotDependOnReservation`
- `testNotificationDeadlineAndSourcePauseApplyOnlyToTheirOwnTargets`
- `testRegistrationStoreRejectsInvalidWritesAndSurvivesSchoolDataRetention`
- `testClassExamUsesAcceptedSlotsVisibilityAndAppliedChanges`

## [tests/SchoolEventsSourceModelTests.swift](../../tests/SchoolEventsSourceModelTests.swift)

- `testCheckingAutomaticallyBecomesMatchedWithoutFetchingEventsAgain`
- `testCheckingStopsAfterExactlyThreeAdditionalRequestsAndRestartsAfterPersistentDelay`
- `testFailedFollowUpStopsAndPreservesSavedEventsAndSuccessfulEvidence`
- `testBackgroundSuspensionCancelsPendingAndInFlightFollowUps`
- `testChangedSavedVersionCancelsPendingFollowUpAndMismatchedReplyCannotScheduleOne`
- `testManualCheckSupersedesPendingFollowUpWithoutAnExtraRequest`
- `testForegroundResumesTheRemainingBudgetWithoutRepeatingTheInitialRequest`
- `testCheckingBoundaryIsSixtySecondsAndCoalescesInFlightResponses`
- `testDailyExpiryStartsAutomaticRequestBeforeTwelveHourCacheExpires`
- `testActualMetadataRequestIsNonblockingCoalescedCachedPersistedAndFailureRetainsEvents`
- `testActualStartupForegroundManual304AndNew200BindEachYearAndVersion`
- `testActualOldInflightSnapshotAndCancellationCannotPublishMetadataIntoNewData`
- `testV2MigrationUsesAnIndependentValidatorAndPreservesV1UntilValidatedSave`
- `testBodyTimeoutBackoffAndRepeated200RespectPersistedConfirmation`
- `testDifferencePersistsAndMismatchRecoveryOnlyChecksOneBody`

## [tests/ui/ApplicationChecks+Events.swift](../../tests/ui/ApplicationChecks+Events.swift)

- `testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover`
- `testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair`
- `testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates`
- `testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent`

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`
- `testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch`
