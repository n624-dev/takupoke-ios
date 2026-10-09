# 学校行事API・年度別保存

対応ソース・テストのSHA-256：
`7ac8b01cc708845d14a2e92bed3a844d262f58d7b9b3ed817b4b97e18b21d085`

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

- `testAnnualCoverageUsesValidatedYearEvenWithoutEventsOnDisplayedDay`（宣言行 20）
- `testWeekCoverageChecksEveryDayAcrossSchoolYearBoundary`（宣言行 44）
- `testCorruptYearRetainsHealthyYearsAndOriginalUntilVerifiedSameYearRepair`（宣言行 58）
- `testOversizedNonregularAndWrongYearCachesAreReportedIndividually`（宣言行 97）
- `testSymlinkCacheIsNotFollowedAndAtomicRepairRetainsHealthyTarget`（宣言行 119）
- `testDirectoryFailureDoesNotBecomeAvailableEmptyCache`（宣言行 134）
- `testCancelledLoadCannotBecomeAvailableCache`（宣言行 143）
- `testValidatesYearAndInclusiveDatesBeforeSaving`（宣言行 155）
- `testLegacyPayloadWithoutETagLoadsButMalformedValidatorIsRejected`（宣言行 173）
- `testSavedResultsSurviveInvalidReplacement`（宣言行 186）
- `testOldSavedResultWithoutResponseETagCanLoad`（宣言行 204）
- `testNotModifiedRequiresMatchingSavedValidatorAndEmptyBody`（宣言行 216）
- `testWeekdayTagRequiresAnExplicitWeekday`（宣言行 236）
