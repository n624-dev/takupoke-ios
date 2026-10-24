# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`89ea0850d2e9846b1e904f2ef9f5b55b91a9b4e70132b1a5da03d0b5e18a6d23`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/SchoolEventsAPI.swift](../../Takupoke/SchoolEventsAPI.swift)
- [Takupoke/SchoolEventsModel.swift](../../Takupoke/SchoolEventsModel.swift)
- [Takupoke/SchoolEventsStore.swift](../../Takupoke/SchoolEventsStore.swift)
- [Takupoke/SchoolEventsView.swift](../../Takupoke/SchoolEventsView.swift)
- [Takupoke/SchoolEventsSourceStatus.swift](../../Takupoke/SchoolEventsSourceStatus.swift)

## [tests/SchoolEventsAPITests.swift](../../tests/SchoolEventsAPITests.swift)

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

- `testMatchingUsesYearHashAndExactDeliveredVersion`
- `testUnknownDifferentUnavailableCheckingAndStaleRemainDistinct`
- `testStatusCacheExpiresAtTwelveHoursAndCheckingAtOneMinute`
- `testCacheRoundTripAndCorruptionCannotModifySavedEvents`
- `testMalformedStatusCannotClaimAnUnverifiedMatch`
- `testClientUsesOnlyGETStatusAPIAndRejectsErrorsWithoutDeletingLastSuccess`
