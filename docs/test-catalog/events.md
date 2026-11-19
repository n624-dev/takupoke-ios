# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`0746dfec7c663aa853e18ea3a6cfb51cd93daa9c74bb683a8a9eb53ea4338577`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/SchoolEventsAPI.swift](../../Takupoke/SchoolEventsAPI.swift)
- [Takupoke/SchoolEventsSourceStatus.swift](../../Takupoke/SchoolEventsSourceStatus.swift)
- [Takupoke/SchoolEventsModel.swift](../../Takupoke/SchoolEventsModel.swift)
- [Takupoke/SchoolEventsStore.swift](../../Takupoke/SchoolEventsStore.swift)
- [Takupoke/SchoolEventsView.swift](../../Takupoke/SchoolEventsView.swift)

## [tests/SchoolEventsAPITests.swift](../../tests/SchoolEventsAPITests.swift)

- `testActualEventsModelCachesProjectionAcrossReads304FailureAndStoreReload`
- `testNearLimitPayloadRemainsReadableAfterSavingItsMetadataEnvelope`
- `testAnnualCoverageUsesValidatedYearEvenWithoutEventsOnDisplayedDay`
- `testWeekCoverageChecksEveryDayAcrossSchoolYearBoundary`
- `testCorruptYearRetainsHealthyYearsAndOriginalUntilVerifiedSameYearRepair`
- `testOversizedNonregularAndWrongYearCachesAreReportedIndividually`
- `testSymlinkCacheIsNotFollowedAndAtomicRepairRetainsHealthyTarget`
- `testDirectoryFailureDoesNotBecomeAvailableEmptyCache`
- `testCancelledLoadCannotBecomeAvailableCache`
- `testValidatesYearAndInclusiveDatesBeforeSaving`
- `testLegacyPayloadWithoutETagLoadsButMalformedValidatorIsRejected`
- `testSavedResultsSurviveInvalidReplacement`
- `testOldSavedResultWithoutResponseETagCanLoad`
- `testNotModifiedRequiresMatchingSavedValidatorAndEmptyBody`
- `testWeekdayTagRequiresAnExplicitWeekday`
- `testIdentifiedCalendarPreservesOneOccurrenceAndProjectsSplitRanges`
- `testIdentifiedCalendarRejectsInvalidIDAndRangesButAcceptsReviewedEmptyPayload`

## [tests/SchoolEventsSourceStatusTests.swift](../../tests/SchoolEventsSourceStatusTests.swift)

- `testSourceStatusValidatesWireVersionYearHashesStatesAndFractionalDates`
- `testMetadataBindingRequiresYearAdoptedHashAndEventsVersionButNotPDFETag`
- `testMetadataTTLIsTwelveHoursOrSixtySecondsWhileCheckingAndRejectsClockRollback`
- `testPresentationSeparatesMatchedDifferenceUnknownFailureStalenessAndSnapshotMismatch`
- `testExhaustedFollowUpsShowUnconfirmedWhileKeepingLastSuccess`
- `testExpiredCheckingDescribesThePastWithoutDiscardingSuccessfulEvidence`
- `testAdvisoryStorePreservesNewestSuccessAcrossUnavailableOlderEdgeAndReload`
- `testDamagedOversizedSymlinkAndWrongYearMetadataCannotBlockHealthyEvents`
- `testLongWarningUsesSuccessfulObservationOrPersistedFirstFailure`
- `testPersistedRetryBackoffIsIndependentOfConfirmationAndClockRollback`

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
