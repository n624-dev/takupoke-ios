# 試験・返却PDF

対応ソース・テストのSHA-256：
`85048c77698cf12ade06c681488c95871b19875c2880e7b3e863925bbac8264f`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/SpecialSchedule.swift](../../Takupoke/SpecialSchedule.swift)
- [Takupoke/SpecialScheduleAnalysisView.swift](../../Takupoke/SpecialScheduleAnalysisView.swift)
- [Takupoke/SpecialScheduleParser+Pages.swift](../../Takupoke/SpecialScheduleParser+Pages.swift)
- [Takupoke/SpecialScheduleParser+Times.swift](../../Takupoke/SpecialScheduleParser+Times.swift)
- [Takupoke/SpecialScheduleParser.swift](../../Takupoke/SpecialScheduleParser.swift)
- [Takupoke/SpecialScheduleRecord.swift](../../Takupoke/SpecialScheduleRecord.swift)
- [Takupoke/SpecialScheduleStore.swift](../../Takupoke/SpecialScheduleStore.swift)
- [Takupoke/SpecialSchedulesModel+Analysis.swift](../../Takupoke/SpecialSchedulesModel+Analysis.swift)
- [Takupoke/SpecialSchedulesModel+Provider.swift](../../Takupoke/SpecialSchedulesModel+Provider.swift)
- [Takupoke/SpecialSchedulesModel+Startup.swift](../../Takupoke/SpecialSchedulesModel+Startup.swift)
- [Takupoke/SpecialSchedulesModel+Updates.swift](../../Takupoke/SpecialSchedulesModel+Updates.swift)
- [Takupoke/SpecialSchedulesModel.swift](../../Takupoke/SpecialSchedulesModel.swift)
- [tests/SpecialScheduleTests+Fixtures.swift](../../tests/SpecialScheduleTests+Fixtures.swift)

## [tests/SpecialScheduleTests+Persistence.swift](../../tests/SpecialScheduleTests+Persistence.swift)

- `testIncompleteSpecialTimesDoNotReplacePreviousStoreResult`（宣言行 8）
- `testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis`（宣言行 30）
- `testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis`（宣言行 75）
- `testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure`（宣言行 107）
- `testPreviousVersionAnalysisStillProvidesSelectedSource`（宣言行 126）

## [tests/SpecialScheduleTests.swift](../../tests/SpecialScheduleTests.swift)

- `testRelativeSpecialSchedulesOutsideViewportCannotBecomeStrictSuccess`（宣言行 8）
- `testReturnColumnsMustBeInDateOrderBeforeSelectingFirstDayTimes`（宣言行 18）
- `testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessons`（宣言行 25）
- `testSeventeenExamHeadingsCannotReplaceARequiredClassWithAnUnknownClass`（宣言行 55）
- `testSpecialSinglePeriodTimesCannotOverlapOrReversePeriodOrder`（宣言行 65）
- `testAdjacentPeriodTimesAndIndependentConsecutiveChartRemainValid`（宣言行 79）
- `testExamParsesDatesClassesAndDocumentTimes`（宣言行 86）
- `testSpecialLessonSeparatesDocumentSubjectTeacherAndRoom`（宣言行 105）
- `testFullCopyIncludesSpecialKindContentAndFailure`（宣言行 118）
