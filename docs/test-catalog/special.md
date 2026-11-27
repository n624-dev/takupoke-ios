# 試験・返却PDF

対応関係・宣言名・実行方法のSHA-256：
`f1e5f4a6c10bfd5578db81b13a89474f21ec145615d2ffcdaccfadd4c9b7d425`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B -m unittest discover -s tests -p test_change_preview_actions.py -k special_provider_refresh -v
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

- `testScopedReturnSubsetCannotReplaceFullReturnAfterRestart`
- `testVariableExamScopeSurvivesStoreRestartAndRejectsPhantomScope`
- `testInterruptedEmptySpecialDatabaseCanFinishInitializationWithoutLosingSources`
- `testMissingScheduleTableWithOtherSchemaOrVersionIsNotReinitialized`
- `testMissingDatabaseOrTablesPreserveRetainedPDFCopies`
- `testFreshStoreCollectsOrphansOnlyAfterValidMetadataAndUpgradesLegacyRecords`
- `testIncompleteSpecialTimesDoNotReplacePreviousStoreResult`
- `testAcquisitionFailureStatusKeepsGoodAnalysisUntilTheSameSourceIsConfirmed`
- `testCancellingSpecialReanalysisKeepsOnlyTheSameOriginalRecoveryJob`
- `testSelectedPDFAndFailurePersistWithoutReplacingPreviousAnalysis`
- `testUnchangedSpecialPDFCheckPersistsWithoutReplacingAcquisitionOrAnalysis`
- `testSameBytesProviderRenamePreservesOriginalAnalysisAndPendingFailure`
- `testPreviousVersionAnalysisStillProvidesSelectedSource`
- `testReturnClockDateAndLegacyRawTimesSurviveSqliteReopen`

## [tests/SpecialScheduleTests.swift](../../tests/SpecialScheduleTests.swift)

- `testStrictExamRequiresEachDateLabelToDescribeOneWholeDay`
- `testPrintedExamWeekdayMustAgreeInStrictCertifiedAndRecovery`
- `testSegmentedCellTopBordersDefineTheCompleteExamBody`
- `testBlankRuledExamEdgeRowsCannotDisappearFromScope`
- `testDeclaredExamPageCountMustMatchTheSelectedDocument`
- `testExamUsesHeadersForPageOrderColumnsDaysAndScope`
- `testExamRejectsDuplicateScopeAndMissingHeadersWithoutDiscardingBody`
- `testFivePageExamAndReorderedSixPageExamKeepEveryLesson`
- `testSpecialPeriodHeadingsDoNotTruncateNumericTokens`
- `testSpecialConsecutiveHeadingsDoNotAdoptNumericSuffix`
- `testReturnMergedLessonRejectsAPartialPeriodList`
- `testMissingContinuousHeadingKeepsVerifiedSinglePeriodFallback`
- `testSpecialWholeNumericTokensRetainAdjacentAndWidthNormalizedHeadings`
- `testTruncatedSpecialClockCannotReplaceSavedGoodAnalysis`
- `testParsedMergedCellRetainsRawClockButItsRemainingFragmentUsesPeriodClock`
- `testExplicitClockForSeparateExamCellsSurvivesStoreReload`
- `testRepeatedLowerHeaderBandBelowMergedClassBorderUsesItsOwnRule`
- `testSingleDayPeriodWordAndPartialSeparatorDoNotMoveTheBodyBoundary`
- `testReturnColumnHeadingsAreExcludedWithoutChangingLessonFields`
- `testMatchingPeriodWordsInsideTheClassTableAreRetained`
- `testReturnColumnHeadingSeparationThroughNativePDFKit`
- `testStrict239RetainsEightCellLinesAndNonFixedSeventeenClassSet`
- `testStrict239RetainsPDFPeriodOrderAndReturnDateOrder`
- `testRelativeSpecialSchedulesOutsideViewportCannotBecomeStrictSuccess`
- `testReturnColumnsMustBeInDateOrderBeforeSelectingFirstDayTimes`
- `testUnevenReturnGradeBandsBindTheLastDepartmentAndBothAdvancedRows`
- `testPartiallyMergedReturnGradeCannotClaimAClassAcrossItsBorder`
- `testSameReturnPDFRetriesTheLastScopeFailureAfterGradeBandFix`
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
- `testHomeWarningsUseTheRetainedResultForEachSelectedMaterial`
- `testLoadingFailureAndUnselectedAreDistinctForBothKinds`
- `testFirstFailedAnalysisAndPreviousSuccessUseDifferentWarnings`

## [tests/test_change_preview_actions.py](../../tests/test_change_preview_actions.py)

- `test_batch_cancellation_is_separate_from_child_deadline`
- `test_paused_files_do_not_start_background_work_before_foreground_return`
- `test_special_provider_refresh_keeps_cancellation_separate_from_failure`
- `test_recovered_timetable_clears_previous_error_only_after_commit`
- `test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration`
- `test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success`
- `test_actual_callbacks_preserve_rejected_preview_and_dispatch_accepted_action_once`
- `test_actual_worker_records_failure_only_for_the_reviewed_original`
- `test_invalid_year_blocks_change_acquisition_without_stalling_other_queued_materials`
