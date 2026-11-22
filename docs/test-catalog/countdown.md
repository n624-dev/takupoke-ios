# カウントダウン・日付・通知・保存

対応関係・宣言名・実行方法のSHA-256：
`c5d6e52b484769a6b2d05ee819d6d01e5361c0498788fd2e54df811d36a44279`

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
- `testAutomaticClassExamReservesEveryDayWithoutReplacingTodaysCard`
- `testSchoolAutomaticPlansLaterPeriodsAndHonorsFixedAndUnconfirmedEvents`
- `testStartupHoldsOnlyExistingAutomaticClassReservationsForTheSameSelection`
- `testReminderDayEditingRequiresACompleteInRangeValue`
- `testRemovingReminderKeepsTheOtherRowsOwnUnfinishedText`
- `testRegistrationStoreRejectsInvalidWritesAndSurvivesSchoolDataRetention`
- `testClassExamDistinguishesAbsentUnloadedAndUnconfirmedChanges`
- `testClassExamUsesAcceptedSlotsVisibilityAndAppliedChanges`

## [tests/SchoolEventsSourceModelTests.swift](../../tests/SchoolEventsSourceModelTests.swift)

- `testCheckingAutomaticallyBecomesMatchedWithoutFetchingEventsAgain`
- `testManualCheckingFollowsUpWithinSixtySecondsDuringEachPriorFailureBackoff`
- `testManualCancellationDoesNotImmediatelyRestartExpiredAutomaticBodyRequest`
- `testManualSchoolEventsCancellationAfterJoiningStatusAlsoStopsTheBodyRequest`
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
- `testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors`
- `testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch`
