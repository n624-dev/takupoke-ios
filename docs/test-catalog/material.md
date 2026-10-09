# 原本取得・更新・保存・File Provider

対応関係・宣言名・実行方法のSHA-256：
`e7c7d4fe1a6839142d96762e90043006c90c6fd660e6c685c59793e9b65ea1f7`

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

- `testUserSelectionsWaitAndPreserveOrderAcrossAllFourKinds`
- `testPendingSelectionKeepsLeaseUntilCancellationOrRetentionClear`
- `testCancellationDropsPendingAndLateCallbacksUntilForegroundReturn`
- `testRefreshDiagnosticIsBoundedAndSafeUnderConcurrentEvents`
- `testBusyOrLoadingDefersAndCoalescesNotifications`
- `testBackgroundDropsPendingAndLateNotifications`
- `testObservationIdentityIgnoresSuccessfulReadMetadata`
- `testRepeatedAttributeNotificationsDoNotRestartRefresh`
- `testReplacementAndUnsupportedVersionsStillGetHashChecked`
- `testReadAcknowledgesMaterializedVersionAndStillDetectsLaterEdit`
- `testFailedReadDoesNotAcknowledgeUnreadVersion`
- `testSuspendedMonitorCannotRestartFromSourceUpdateOrLateWork`
- `testEveryForegroundEntryChecksOnceAndUnchangedSourcesDoNotLoop`
- `testBackgroundAndReselectionInvalidatePendingCallbacks`
- `testPresenterRegistersBeforeInitialRefreshAndObservesCoordinatedWrite`
- `testOwnFileOperationsDoNotFeedBackButExternalWritesStillNotify`
- `testStopWhileResolvingCannotRegisterAfterBackground`

## [tests/MaterialLibraryChecks.swift](../../tests/MaterialLibraryChecks.swift)

- `main`

## [tests/WebPDFChecks.swift](../../tests/WebPDFChecks.swift)

- `run`

## [tests/ParsingTests+RowSkips.swift](../../tests/ParsingTests+RowSkips.swift)

- `testRowSkipsAreExplicitKeepRowNumbersAndExcludeWholeExpandedRow`
- `testExcludedClassCannotBecomeEvidenceForRemainingAllRow`
- `testWeekdayOnlyFormulaWithOrWithoutCacheCanBeInspectedButNeverAutoSkipped`
- `testRowSkipsCannotHideDateClassFormulaOrStructuralErrors`
- `testRowSkipConsentPersistsOnlyForSameSelectedContentAndNeverResurrects`
- `testRowSkipsRejectStalePreviewCancellationAndAllExcludedWithoutSaving`
