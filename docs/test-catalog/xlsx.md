# 時間割変更・曜日・行除外・原文保持

対応関係・宣言名・実行方法のSHA-256：
`06daa394fedc3d5fd6172aa57c3789a9eedb30449aef52d42ba1eea4cf0c33f6`

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

## [tests/ParsingTests+Normalization.swift](../../tests/ParsingTests+Normalization.swift)

- `testReferenceFixturesThroughCompressedXLSX`
- `testAIClassAliasesThroughXLSXKeepRowsAndSourceText`
- `testLegacyAIClassDisplayDoesNotRewriteSavedResults`
- `testDatesAndExplicitYear`
- `testTableFailuresAndBounds`

## [tests/ParsingTests+Persistence.swift](../../tests/ParsingTests+Persistence.swift)

- `testPersistenceFailureAndNewSourceKeepLastGoodResult`

## [tests/ParsingTests+Preview.swift](../../tests/ParsingTests+Preview.swift)

- `testLiteralWeekdayNeedsExplicitCorrectionAndKeepsOriginalText`
- `testWeekdayConsentIsAtomicAndLimitedToSelectedContent`
- `testMetadataAndValidatedWeekdayFormulas`
- `testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula`
- `testWarningPreviewKeepsSuccessAndFailureUnchanged`
- `testPreviewDoesNotBypassOtherErrors`

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

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
