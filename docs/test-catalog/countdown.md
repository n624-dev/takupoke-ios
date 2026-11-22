# カウントダウン・日付・通知・保存

対応関係・宣言名・実行方法のSHA-256：
`71b53ac3d5bcabc9bc06cf2169af76d04c43b543e9ce83df9730a9646353b2cb`

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
