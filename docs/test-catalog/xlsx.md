# 時間割変更・曜日・行除外・原文保持

対応関係・宣言名・実行方法のSHA-256：
`2c1a748d6a91801a1226749fc3ed6ca8cb9a8866d6655068fb73b043ff488fb0`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/BoundedXML.swift](../../Takupoke/BoundedXML.swift)
- [Takupoke/ChangeAnalysis.swift](../../Takupoke/ChangeAnalysis.swift)
- [Takupoke/ChangeAnalysisView.swift](../../Takupoke/ChangeAnalysisView.swift)
- [Takupoke/ChangeNormalizer+Dates.swift](../../Takupoke/ChangeNormalizer+Dates.swift)
- [Takupoke/ChangeNormalizer.swift](../../Takupoke/ChangeNormalizer.swift)
- [Takupoke/ChangePreviewView.swift](../../Takupoke/ChangePreviewView.swift)
- [Takupoke/ChangeWorkbookEditorView.swift](../../Takupoke/ChangeWorkbookEditorView.swift)
- [Takupoke/XLSXReader+Worksheet.swift](../../Takupoke/XLSXReader+Worksheet.swift)
- [Takupoke/XLSXReader.swift](../../Takupoke/XLSXReader.swift)
- [Takupoke/ChangeWorkbookEditor.swift](../../Takupoke/ChangeWorkbookEditor.swift)
- [tests/ParsingTests.swift](../../tests/ParsingTests.swift)

## [tests/test_change_preview_actions.py](../../tests/test_change_preview_actions.py)

- `test_paused_files_do_not_start_background_work_before_foreground_return`
- `test_special_provider_refresh_keeps_cancellation_separate_from_failure`
- `test_recovered_timetable_clears_previous_error_only_after_commit`
- `test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration`
- `test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success`
- `test_actual_callbacks_preserve_rejected_preview_and_dispatch_accepted_action_once`
- `test_actual_worker_records_failure_only_for_the_reviewed_original`
- `test_invalid_year_blocks_change_acquisition_without_stalling_other_queued_materials`

## [tests/ParsingTests+Normalization.swift](../../tests/ParsingTests+Normalization.swift)

- `testReferenceFixturesThroughCompressedXLSX`
- `testAIClassAliasesThroughXLSXKeepRowsAndSourceText`
- `testLegacyAIClassDisplayDoesNotRewriteSavedResults`
- `testDatesAndExplicitYear`
- `testTableFailuresAndBounds`
- `testRowEditsRetainOriginalValuesAcrossSchoolFileUpdates`
- `testIdenticalOriginalRowsRequireUnambiguousCorrection`
- `testCompleteWeekdayExclusionsCarryOverOnlyToUnchangedSubsets`
- `testAmbiguousWeekdayGroupsResolveOnlySelectedRowsWithMatchingRawEvidence`
- `testCorrectionReviewIncludesMultipleFieldsAndEmptyFormulaRows`
- `testEditorUsesRecognizedAliasesInsteadOfAddingShadowColumns`
- `testChangedFormulaWithSameCachedErrorDoesNotRestoreCorrection`
- `testSharedFormulaFollowerMatchesOnlyAnUnchangedMaster`
- `testArrayFormulaIdentityAndTrailingFormattedBlanks`
- `testPriorConflictingEditUsesTheLabelFromItsOwnWorkbookGeneration`
- `testPriorDateEditKeepsItsYearColumnAndExcelDateSystem`
- `testBlankDateKeepsPersonalCorrectionWhenOnlyFormattingChangesIn1904Workbook`
- `testEditorPreserves1904SerialAndConvertsOnlyTheMappedDate`
- `testEmptyFirstSheetAllowsSelectingOtherSheet`
- `testTurningOffWeekdayCompletionSurvivesSameRowRefresh`
- `testOpenEditorRejectsAnotherPersonalEditToSameDigest`
- `testPhysicalHeaderWidthAndHeaderEvidenceSurviveSourceRefresh`
- `testNumericPersonalDateIsInvalidatedByChangedEpoch`
- `testMergedFollowersTrackSchoolAnchorIncludingImplicitLastRow`
- `testReviewValidatesWeekdayAliasUniquenessAndMigratesMatchingCachedFormula`
- `testGroupedWorkbookCorrectionsUseOnlySelectedRowsAndKeepRawEvidence`
- `testWorkbookClassSeparatorsAndReadableMonthDayAcrossSavedEdits`
- `testWorkbookTimestampEvidenceEpochsAndPersonalReason`

## [tests/ParsingTests+Persistence.swift](../../tests/ParsingTests+Persistence.swift)

- `testPersistenceFailureAndNewSourceKeepLastGoodResult`
- `testInvalidYearCannotReplaceAcceptedSqliteDatesAndFreshnessUsesYearAndConsents`
- `testPersonalCorrectionSurvivesInsertedRowsAndYieldsToSchoolCorrection`
- `testSameBytesFromDifferentSelectionDoNotCertifyPersonalResult`
- `testLegacyAmbiguousWeekdayExclusionsCanBeConfirmedAndSavedAfterReopen`
- `testUnresolvedDuplicateDecisionsBelongToChosenSheet`

## [tests/ParsingTests+Preview.swift](../../tests/ParsingTests+Preview.swift)

- `testLiteralWeekdayNeedsExplicitCorrectionAndKeepsOriginalText`
- `testWeekdayConsentIsAtomicAndLimitedToSelectedContent`
- `testCachedStringWeekdayDecodesSpreadsheetEscapesOnce`
- `testMetadataAndValidatedWeekdayFormulas`
- `testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula`
- `testWarningPreviewKeepsSuccessAndFailureUnchanged`
- `testPreviewDoesNotBypassOtherErrors`

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

- `testCancellationWhileMigratingLegacyChangeEditsLeavesOriginalAndDecisionsIntact`
- `testSuccessfulExclusionsCanBeReviewedAndExplicitlyRemovedWithWeekdayCorrection`
- `testSkipAndExplicitWeekdayCorrectionReparseAllRemainingRowsAndRetainDecisions`
- `testLegacyChangeIdentitySurvivesRenamedLocalCopyWithoutWeakeningStaleChecks`
- `testConsecutiveIdenticalWeekdayPlaceholdersGroupWithoutHidingPopulatedOrSeparatedRows`
- `testGroupedWeekdayPlaceholdersStillRequireExplicitFullRowConsent`
- `testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow`
- `testExcludedClassCannotBecomeEvidenceForRemainingAllRow`
- `testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped`
- `testRowSkipsCannotHideDateClassFormulaOrStructuralErrors`
- `testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects`
- `testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving`
- `testOldRowSkipDecisionSurvivesSQLiteUpgradeAndCurrentRevalidation`
- `testRowSkipRevalidationFailureCancellationAndSaveFailureKeepDecision`
- `testRenewedBookmarkMatchesOnlyTheSelectedOriginal`

## [tests/ParsingTests+Workbook.swift](../../tests/ParsingTests+Workbook.swift)

- `testFormulaRangeCannotSupplyUnverifiedChangeCells`
- `testFormulaRangeStartingBeforeHeaderStillMarksAffectedTableCells`
- `testLeadingZeroGradesFromWorkbookProduceSelectableCanonicalClasses`
- `testTypedDateCellsUseTheirWrittenCalendarDateAndBomIsAccepted`
- `testUnsupportedAndMalformedWorkbooks`
- `testSharedStringsExpansionLimit`
- `testCancellationAndCorruption`
- `testRichTextNumericDatesAndSparseCells`
- `testWorkbookChangeKindsRemainIndependentOfRemarksAndPersist`
- `testOoxmlEscapesDecodeOnceAcrossSharedInlineAndRichStrings`
- `testUnconfirmedTimestampKeepsOriginalAndDoesNotBlockLessonInEitherReadPath`
