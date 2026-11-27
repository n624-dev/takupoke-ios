# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`d2517e3f69578ee65e11db8e5af9eb0f7f4daf13a0690284b99ebc13e305ec85`

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

## [tests/BoundedHTTPResponseTests.swift](../../tests/BoundedHTTPResponseTests.swift)

- `testRejectsExcessiveDeclaredLengthBeforeReadingAnyBytes`
- `testUnknownAndUnderstatedLengthsBothStopAtFirstExcessByte`
- `testExactLimitAndEmptyRevisionResponsesRemainUsable`
- `testCancelledReaderDoesNotConsumeAnyPartOfTheResponse`

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
- `testAcceptedEventResponseWithUnescapedSlashesSurvivesReload`
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
- `testStructuredEvidenceNeverPromotesStaleFailedOrMismatchedResultsToMatched`
- `testStatusDoesNotHideAnEventsFailureOrCheckBehindACachedPDFMatch`
- `testExpiredCheckingDescribesThePastWithoutDiscardingSuccessfulEvidence`
- `testAdvisoryStorePreservesNewestSuccessAcrossUnavailableOlderEdgeAndReload`
- `testDamagedOversizedSymlinkAndWrongYearMetadataCannotBlockHealthyEvents`
- `testLongWarningUsesSuccessfulObservationOrPersistedFirstFailure`
- `testPersistedRetryBackoffIsIndependentOfConfirmationAndClockRollback`

## [tests/SchoolEventsSourceModelTests.swift](../../tests/SchoolEventsSourceModelTests.swift)

- `testNewSchoolYearStopsAutomaticChecksButKeepsSavedEventsAndManualRefresh`
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
- `testCountdownDistinguishesAnActiveSourceCheckFromUnknownAndFailure`
