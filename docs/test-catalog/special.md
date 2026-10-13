# 試験・返却PDF

対応関係・宣言名・実行方法のSHA-256：
`1ebf2da1b2e1965a7e349fba0aa217da217f66f2462f522ae22fc8cf5012538c`

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

- `testIncompleteSpecialTimesDoNotReplacePreviousStoreResult`
- `testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis`
- `testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis`
- `testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure`
- `testPreviousVersionAnalysisStillProvidesSelectedSource`

## [tests/SpecialScheduleTests.swift](../../tests/SpecialScheduleTests.swift)

- `testRelativeSpecialSchedulesOutsideViewportCannotBecomeStrictSuccess`
- `testReturnColumnsMustBeInDateOrderBeforeSelectingFirstDayTimes`
- `testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessons`
- `testSeventeenExamHeadingsCannotReplaceARequiredClassWithAnUnknownClass`
- `testSpecialSinglePeriodTimesCannotOverlapOrReversePeriodOrder`
- `testAdjacentPeriodTimesAndIndependentConsecutiveChartRemainValid`
- `testExamParsesDatesClassesAndDocumentTimes`
- `testSpecialLessonSeparatesDocumentSubjectTeacherAndRoom`
- `testFullCopyIncludesSpecialKindContentAndFailure`

## [tests/PDFTextGeometryTests+Visibility.swift](../../tests/PDFTextGeometryTests+Visibility.swift)

- `testUnusedDevicePaintDoesNotRejectBlackTextAndSavedColorRestores`
- `testClipContainmentHasNoToleranceAndPreservesLimitsAndCancellation`
- `testNativeBoundedOutlinesAndSingletonNormalBlendPreserveDirectText`
- `testNativeOutlineFontBoundsCannotCrossGridOutsideTheAdvanceBox`
- `testNativeDiscardedCurvesUnusedDashAndRestoredDashKeepTheVisibleTable`
- `testNativeVerifiedFilledArrowRetainsItsOriginalGeometryInStrictReaders`
- `testNativeDisjointFilledRulesAndDecorationsPreserveTextAndGeometryInEitherPaintOrder`
- `testNativeOverlappingFilledRulesNeverCompleteDeferredCapture`
- `testNativeInertTagsContainedClipsDeviceSpacesAndUnusedStylesPreserveDirectAcquisition`
- `testNativeConcealingClipsOptionalReplacementAndUnbalancedTagsRemainRejected`
