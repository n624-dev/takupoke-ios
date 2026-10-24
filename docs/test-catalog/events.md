# 学校行事API・年度別保存

対応関係・宣言名・実行方法のSHA-256：
`aee5e04e8204f89b1b17dc708ab40b7407e3798d2b633f1a654b69994f05da6c`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/SchoolEventsAPI.swift](../../Takupoke/SchoolEventsAPI.swift)
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
