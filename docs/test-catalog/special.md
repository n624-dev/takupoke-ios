# 試験・返却PDF

対応関係・宣言名・実行方法のSHA-256：
`472169f43c7045f4ff84233bef00937be08ebb0d8c773d48ead1f9309f258c11`

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

- `testMissingDatabaseOrTablesPreserveRetainedPDFCopies`
- `testFreshStoreCollectsOrphansOnlyAfterValidMetadataAndUpgradesLegacyRecords`
- `testIncompleteSpecialTimesDoNotReplacePreviousStoreResult`
- `testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis`
- `testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis`
- `testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure`
- `testPreviousVersionAnalysisStillProvidesSelectedSource`

## [tests/SpecialScheduleTests.swift](../../tests/SpecialScheduleTests.swift)

- `testParsedMergedCellRetainsRawClockButItsRemainingFragmentUsesPeriodClock`
- `testRepeatedLowerHeaderBandBelowMergedClassBorderUsesItsOwnRule`
- `testSingleDayPeriodWordAndPartialSeparatorDoNotMoveTheBodyBoundary`
- `testReturnColumnHeadingsAreExcludedWithoutChangingLessonFields`
- `testMatchingPeriodWordsInsideTheClassTableAreRetained`
- `testReturnColumnHeadingSeparationThroughNativePDFKit`
- `testStrict239RetainsEightCellLinesAndNonFixedSeventeenClassSet`
- `testStrict239RetainsPDFPeriodOrderAndReturnDateOrder`
- `testRelativeSpecialSchedulesOutsideViewportCannotBecomeStrictSuccess`
- `testReturnColumnsMustBeInDateOrderBeforeSelectingFirstDayTimes`
- `testReturnScheduleTreatsHorizontallyDividedCellAsTwoLessons`
- `testSeventeenExamHeadingsCannotReplaceARequiredClassWithAnUnknownClass`
- `testSpecialSinglePeriodTimesCannotOverlapOrReversePeriodOrder`
- `testAdjacentPeriodTimesAndIndependentConsecutiveChartRemainValid`
- `testExamParsesDatesClassesAndDocumentTimes`
- `testSpecialLessonSeparatesDocumentSubjectTeacherAndRoom`
- `testFullCopyIncludesSpecialKindContentAndFailure`
- `testReturnPositionsExportUsesExactAdoptedRowsAndContainsOnlyNumbers`
- `testSpecialFirstYearMovesOnlyTheLessonAndKeepsSeventeenSourceClasses`

## [tests/PDFTextGeometryTests+Visibility.swift](../../tests/PDFTextGeometryTests+Visibility.swift)

- `testUnusedDevicePaintDoesNotRejectBlackTextAndSavedColorRestores`
- `testClipContainmentHasNoToleranceAndPreservesLimitsAndCancellation`
- `testStrict239ReadDoesNotPromoteLegacySuccessToCertifiedRecovery`
- `testNativeBoundedOutlinesAndSingletonNormalBlendPreserveDirectText`
- `testNativeOutlineFontBoundsCannotCrossGridOutsideTheAdvanceBox`
- `testNativeDiscardedCurvesUnusedDashAndRestoredDashKeepTheVisibleTable`
- `testNativeVerifiedFilledArrowRetainsItsOriginalGeometryInStrictReaders`
- `testNativeDisjointFilledRulesAndDecorationsPreserveTextAndGeometryInEitherPaintOrder`
- `testNativeOverlappingFilledRulesNeverCompleteDeferredCapture`
- `testNativeLightBackgroundBeforeTextPreservesAcquisitionAndRejectsOverpaint`
- `testNativeBackgroundContrastCannotCertifyHiddenLowContrastOrLateBackgroundText`
- `testNativeBackgroundCannotEraseOrHideStructuralRules`
- `testNativeBackgroundOverprintRequiresKnownNormalCompositingAndRestoresGraphicsState`
- `testNativeInertTagsContainedClipsDeviceSpacesAndUnusedStylesPreserveDirectAcquisition`
- `testNativeConcealingClipsOptionalReplacementAndUnbalancedTagsRemainRejected`
