# 原本取得・更新・保存・File Provider

対応ソース・テストのSHA-256：
`733aaf4bdda467413b17f90fa841f38a3c39356cd442f1aa00c0db9c44fa2f48`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/FileRefreshDiagnostics.swift](../../Takupoke/FileRefreshDiagnostics.swift)
- [Takupoke/MaterialAccess.swift](../../Takupoke/MaterialAccess.swift)
- [Takupoke/MaterialLibrary+Analysis.swift](../../Takupoke/MaterialLibrary+Analysis.swift)
- [Takupoke/MaterialLibrary+Validation.swift](../../Takupoke/MaterialLibrary+Validation.swift)
- [Takupoke/MaterialLibrary.swift](../../Takupoke/MaterialLibrary.swift)
- [Takupoke/MaterialModels.swift](../../Takupoke/MaterialModels.swift)
- [Takupoke/MaterialWorker+Analysis.swift](../../Takupoke/MaterialWorker+Analysis.swift)
- [Takupoke/MaterialWorker+Provider.swift](../../Takupoke/MaterialWorker+Provider.swift)
- [Takupoke/MaterialsModel+Updates.swift](../../Takupoke/MaterialsModel+Updates.swift)
- [Takupoke/MaterialsModel.swift](../../Takupoke/MaterialsModel.swift)
- [Takupoke/MaterialsView+FileSummary.swift](../../Takupoke/MaterialsView+FileSummary.swift)
- [Takupoke/MaterialsView.swift](../../Takupoke/MaterialsView.swift)
- [Takupoke/ScopedMaterialSelection.swift](../../Takupoke/ScopedMaterialSelection.swift)
- [Takupoke/SelectedFileMonitor.swift](../../Takupoke/SelectedFileMonitor.swift)
- [Takupoke/SelectedFileObservation.swift](../../Takupoke/SelectedFileObservation.swift)
- [Takupoke/SelectedFilePresenter.swift](../../Takupoke/SelectedFilePresenter.swift)
- [Takupoke/SelectedFileSource.swift](../../Takupoke/SelectedFileSource.swift)
- [Takupoke/WebPDFDownloader.swift](../../Takupoke/WebPDFDownloader.swift)
- [tools/test-materials.sh](../../tools/test-materials.sh)
- [tools/test-parsing.sh](../../tools/test-parsing.sh)

## [tests/FileRefreshTests.swift](../../tests/FileRefreshTests.swift)

- `testUserSelectionsWaitAndPreserveOrderAcrossAllFourKinds`（宣言行 6）
- `testPendingSelectionKeepsLeaseUntilCancellationOrRetentionClear`（宣言行 20）
- `testCancellationDropsPendingAndLateCallbacksUntilForegroundReturn`（宣言行 36）
- `testRefreshDiagnosticIsBoundedAndSafeUnderConcurrentEvents`（宣言行 52）
- `testBusyOrLoadingDefersAndCoalescesNotifications`（宣言行 71）
- `testBackgroundDropsPendingAndLateNotifications`（宣言行 85）
- `testObservationIdentityIgnoresSuccessfulReadMetadata`（宣言行 98）
- `testRepeatedAttributeNotificationsDoNotRestartRefresh`（宣言行 108）
- `testReplacementAndUnsupportedVersionsStillGetHashChecked`（宣言行 124）
- `testReadAcknowledgesMaterializedVersionAndStillDetectsLaterEdit`（宣言行 133）
- `testFailedReadDoesNotAcknowledgeUnreadVersion`（宣言行 176）
- `testSuspendedMonitorCannotRestartFromSourceUpdateOrLateWork`（宣言行 205）
- `testEveryForegroundEntryChecksOnceAndUnchangedSourcesDoNotLoop`（宣言行 223）
- `testBackgroundAndReselectionInvalidatePendingCallbacks`（宣言行 242）
- `testPresenterRegistersBeforeInitialRefreshAndObservesCoordinatedWrite`（宣言行 257）
- `testOwnFileOperationsDoNotFeedBackButExternalWritesStillNotify`（宣言行 291）
- `testStopWhileResolvingCannotRegisterAfterBackground`（宣言行 336）

## [tests/MaterialLibraryChecks.swift](../../tests/MaterialLibraryChecks.swift)

- `main`（宣言行 16）

## [tests/WebPDFChecks.swift](../../tests/WebPDFChecks.swift)

- `run`（宣言行 40）

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

- `testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow`（宣言行 17）
- `testExcludedClassCannotBecomeEvidenceForRemainingAllRow`（宣言行 53）
- `testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped`（宣言行 73）
- `testRowSkipsCannotHideDateClassFormulaOrStructuralErrors`（宣言行 98）
- `testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects`（宣言行 135）
- `testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving`（宣言行 182）
