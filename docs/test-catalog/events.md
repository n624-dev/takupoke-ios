# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`7699264be6f1ea8af7402bb6233cfc43014206a06a08993451b9d1d5696a9e35`

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
