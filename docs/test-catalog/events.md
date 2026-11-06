# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`41c5e284e9443a5eab4a18926fb5d26ae127addd57a7b3ac7cb1cb6e06064149`

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

## [tests/SchoolEventsSourceStatusTests.swift](../../tests/SchoolEventsSourceStatusTests.swift)

- `testSourceStatusValidatesWireVersionYearHashesStatesAndFractionalDates`
- `testMetadataBindingRequiresYearAdoptedHashAndEventsVersionButNotPDFETag`
- `testMetadataTTLIsTwelveHoursOrSixtySecondsWhileCheckingAndRejectsClockRollback`
- `testPresentationSeparatesMatchedDifferenceUnknownFailureStalenessAndSnapshotMismatch`
- `testExhaustedFollowUpsShowUnconfirmedWhileKeepingLastSuccess`
- `testExpiredCheckingDescribesThePastWithoutDiscardingSuccessfulEvidence`
- `testAdvisoryStorePreservesNewestSuccessAcrossUnavailableOlderEdgeAndReload`
- `testDamagedOversizedSymlinkAndWrongYearMetadataCannotBlockHealthyEvents`

## [tests/SchoolEventsSourceModelTests.swift](../../tests/SchoolEventsSourceModelTests.swift)

- `testCheckingAutomaticallyBecomesMatchedWithoutFetchingEventsAgain`
- `testCheckingStopsAfterExactlyThreeAdditionalRequests`
- `testFailedFollowUpStopsAndPreservesSavedEventsAndSuccessfulEvidence`
- `testBackgroundSuspensionCancelsPendingAndInFlightFollowUps`
- `testChangedSavedVersionCancelsPendingFollowUpAndMismatchedReplyCannotScheduleOne`
- `testManualCheckSupersedesPendingFollowUpWithoutAnExtraRequest`
- `testForegroundResumesTheRemainingBudgetWithoutRepeatingTheInitialRequest`
- `testForegroundBudgetAndCacheUseOneTimeSnapshotAtExpiryBoundary`
- `testExpiryPublishesToObserversWithoutARequestOrSavedEventsChange`
- `testActualMetadataRequestIsNonblockingCoalescedCachedPersistedAndFailureRetainsEvents`
- `testActualStartupForegroundManual304AndNew200BindEachYearAndVersion`
- `testActualOldInflightSnapshotAndCancellationCannotPublishMetadataIntoNewData`
