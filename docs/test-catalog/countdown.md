# カウントダウン・日付・通知・保存

対応関係・宣言名・実行方法のSHA-256：
`2db86d00bea352c80fad2c1336d8df7f2656b33a6ebffd6bc9a347f3f4cb8fa6`

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
- `testOfflineCacheExpiryPublishesPresentationWithoutRequestingData`
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
