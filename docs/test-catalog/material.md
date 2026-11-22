# 原本取得・更新・保存・File Provider

対応関係・宣言名・実行方法のSHA-256：
`53058cee333204738994f700224d3faab15275b8e1c815e1cc11391679dc69fe`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B -m unittest discover -s tests -p test_change_preview_actions.py
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

- `testRefreshPreservesTheFirstFailureAndStillChecksOtherSources`
- `testRefreshPreservesChangeAndAcquisitionFailureKinds`
- `testRefreshCancellationStopsBeforeTheNextSourceAndAfterTheLastRead`
- `testUserSelectionsWaitAndPreserveOrderAcrossAllFourKinds`
- `testPendingSelectionKeepsLeaseUntilCancellationOrRetentionClear`
- `testCancellationDropsPendingAndLateCallbacksUntilForegroundReturn`
- `testRefreshDiagnosticIsBoundedAndSafeUnderConcurrentEvents`
- `testBusyOrLoadingDefersAndCoalescesNotifications`
- `testBackgroundDropsPendingAndLateNotifications`
- `testObservationIdentityIgnoresSuccessfulReadMetadata`
- `testFailedVersionRetriesOnlyAfterQuietPeriodAndSuccessfulReadAcknowledgesIt`
- `testRepeatedAttributeNotificationsDoNotRestartRefresh`
- `testReplacementAndUnsupportedVersionsStillGetHashChecked`
- `testFailedRegistrationRetriesSameSourceWithoutInitialRefreshAndRejectsLateCallbacks`
- `testReadAcknowledgesMaterializedVersionAndStillDetectsLaterEdit`
- `testFailedReadDoesNotAcknowledgeUnreadVersion`
- `testCopiedVersionRemainsObservableUntilCommittedAndCannotHideNewerBytes`
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

## [tests/test_change_preview_actions.py](../../tests/test_change_preview_actions.py)

- `test_recovered_timetable_clears_previous_error_only_after_commit`
- `test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration`
- `test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success`
- `test_actual_callbacks_preserve_rejected_preview_and_dispatch_accepted_action_once`
- `test_actual_worker_records_failure_only_for_the_reviewed_original`
- `test_invalid_year_blocks_change_acquisition_without_stalling_other_queued_materials`
