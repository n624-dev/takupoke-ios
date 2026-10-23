# 時間割変更・曜日・行除外・原文保持

対応関係・宣言名・実行方法のSHA-256：
`ac6fda77ad11e599a2f0cd4eb0138d8250b6d138642f67b754e2e171d853a941`

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
- [Takupoke/XLSXReader+Worksheet.swift](../../Takupoke/XLSXReader+Worksheet.swift)
- [Takupoke/XLSXReader.swift](../../Takupoke/XLSXReader.swift)
- [tests/ParsingTests.swift](../../tests/ParsingTests.swift)

## [tests/test_change_preview_actions.py](../../tests/test_change_preview_actions.py)

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

## [tests/ParsingTests+Persistence.swift](../../tests/ParsingTests+Persistence.swift)

- `testPersistenceFailureAndNewSourceKeepLastGoodResult`
- `testInvalidYearCannotReplaceAcceptedSqliteDatesAndFreshnessUsesYearAndConsents`

## [tests/ParsingTests+Preview.swift](../../tests/ParsingTests+Preview.swift)

- `testLiteralWeekdayNeedsExplicitCorrectionAndKeepsOriginalText`
- `testWeekdayConsentIsAtomicAndLimitedToSelectedContent`
- `testCachedStringWeekdayDecodesSpreadsheetEscapesOnce`
- `testMetadataAndValidatedWeekdayFormulas`
- `testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula`
- `testWarningPreviewKeepsSuccessAndFailureUnchanged`
- `testPreviewDoesNotBypassOtherErrors`

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

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

- `testUnsupportedAndMalformedWorkbooks`
- `testSharedStringsExpansionLimit`
- `testCancellationAndCorruption`
- `testRichTextNumericDatesAndSparseCells`
- `testWorkbookChangeKindsRemainIndependentOfRemarksAndPersist`
- `testOoxmlEscapesDecodeOnceAcrossSharedInlineAndRichStrings`
