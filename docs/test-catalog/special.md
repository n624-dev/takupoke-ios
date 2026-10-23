# 試験・返却PDF

対応関係・宣言名・実行方法のSHA-256：
`03c47a960470c907d5c51acefb680cb4002f41e34f9025acacd9c99744005aa8`

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

- `testInterruptedEmptySpecialDatabaseCanFinishInitializationWithoutLosingSources`
- `testMissingScheduleTableWithOtherSchemaOrVersionIsNotReinitialized`
- `testMissingDatabaseOrTablesPreserveRetainedPDFCopies`
- `testFreshStoreCollectsOrphansOnlyAfterValidMetadataAndUpgradesLegacyRecords`
- `testIncompleteSpecialTimesDoNotReplacePreviousStoreResult`
- `testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis`
- `testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis`
- `testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure`
- `testPreviousVersionAnalysisStillProvidesSelectedSource`
- `testReturnClockDateAndLegacyRawTimesSurviveSqliteReopen`

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
- `testReturnColumnClockDateSurvivesSortedDatesCardsChangesAndPersistence`

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

## [tests/SpecialAvailabilityTests.swift](../../tests/SpecialAvailabilityTests.swift)

- `testHomeKeepsLoadedLessonsWhenIndependentStoresAreUnavailable`
- `testLoadingFailureAndUnselectedAreDistinctForBothKinds`
- `testFirstFailedAnalysisAndPreviousSuccessUseDifferentWarnings`
