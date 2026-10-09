# 時間割変更・曜日・行除外・原文保持

対応ソース・テストのSHA-256：
`7376025e61e6b1497d0d9ee267ccd1d36965f905fe21fc7c637bb5e4bccfe447`

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

- `testReferenceFixturesThroughCompressedXLSX`（宣言行 7）
- `testAIClassAliasesThroughXLSXKeepRowsAndSourceText`（宣言行 36）
- `testLegacyAIClassDisplayDoesNotRewriteSavedResults`（宣言行 68）
- `testDatesAndExplicitYear`（宣言行 103）
- `testTableFailuresAndBounds`（宣言行 113）

## [tests/ParsingTests+Persistence.swift](../../tests/ParsingTests+Persistence.swift)

- `testPersistenceFailureAndNewSourceKeepLastGoodResult`（宣言行 7）

## [tests/ParsingTests+Preview.swift](../../tests/ParsingTests+Preview.swift)

- `testLiteralWeekdayNeedsExplicitCorrectionAndKeepsOriginalText`（宣言行 28）
- `testWeekdayConsentIsAtomicAndLimitedToSelectedContent`（宣言行 54）
- `testMetadataAndValidatedWeekdayFormulas`（宣言行 91）
- `testWeekdayFormulaMissingOrStaleCacheAndMajorColumnFormula`（宣言行 112）
- `testWarningPreviewKeepsSuccessAndFailureUnchanged`（宣言行 132）
- `testPreviewDoesNotBypassOtherErrors`（宣言行 188）

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

- `testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow`（宣言行 17）
- `testExcludedClassCannotBecomeEvidenceForRemainingAllRow`（宣言行 53）
- `testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped`（宣言行 73）
- `testRowSkipsCannotHideDateClassFormulaOrStructuralErrors`（宣言行 98）
- `testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects`（宣言行 135）
- `testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving`（宣言行 182）

## [tests/ParsingTests+Workbook.swift](../../tests/ParsingTests+Workbook.swift)

- `testUnsupportedAndMalformedWorkbooks`（宣言行 7）
- `testSharedStringsExpansionLimit`（宣言行 53）
- `testCancellationAndCorruption`（宣言行 65）
- `testRichTextNumericDatesAndSparseCells`（宣言行 87）
