# 原本取得・更新・保存・File Provider

対応関係・宣言名・実行方法のSHA-256：
`0f23b7382058b3e28f941f31443682198a033bd6e5f73ec5a90c940cd752c86d`

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
- [Takupoke/MaterialFileReader.swift](../../Takupoke/MaterialFileReader.swift)
- [Takupoke/SelectedFileProvider.swift](../../Takupoke/SelectedFileProvider.swift)
- [Takupoke/FilePipeline.swift](../../Takupoke/FilePipeline.swift)
- [Takupoke/PipelineWorkspace.swift](../../Takupoke/PipelineWorkspace.swift)
- [Takupoke/MaterialLibrary+Pipeline.swift](../../Takupoke/MaterialLibrary+Pipeline.swift)
- [Takupoke/SpecialScheduleStore+Pipeline.swift](../../Takupoke/SpecialScheduleStore+Pipeline.swift)
- [Takupoke/MaterialWorker+Pipeline.swift](../../Takupoke/MaterialWorker+Pipeline.swift)
- [Takupoke/SpecialSchedulesModel+Pipeline.swift](../../Takupoke/SpecialSchedulesModel+Pipeline.swift)
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

- `testPipelineStageDeadlinesProgressOverallAndCommitFence`
- `testUnresponsivePipelineExpiresWithoutPublishingAndOtherFilesContinue`
- `testTransientRetriesStopAtTwoAndKeepOneCommitAndCleanup`
- `testIsolatedLibraryRejectsChangedSourceAndKeepsOtherFiles`
- `testSpecialSnapshotPreservesOtherSourceAndRejectsStaleCommit`
- `testLateStageAndProgressCannotEraseExpiredDeadline`
- `testClearPresentationDuringCommitCannotStrandLane`
- `testSavingCanFinishAfterDeadlineWithoutPermittingAnotherAttempt`
- `testPipelineCanRepairMissingMaterialCopyEvenWhenOriginalBytesMatch`
- `testCancelledAdmissionNeverLaunchesProvider`
- `testCancellationAtRetryReplacementStopsNewProvider`
- `testSelectionIntentRejectsAnOlderNotYetStartedRequest`
- `testSourceCancellationDoesNotDropAnotherDrainedBatchRequest`
- `testRetryBudgetExpiresEvenWhenOwnerQueueCannotRun`
- `testInjectedProviderCannotPublishDelayedCompletionForAnySelectedKind`
- `testDiagnosticElapsedTimeUsesInjectedMonotonicClock`
- `testBlockedReaderRejectsLateBytesAfterCancellation`
- `testSharedReaderChecksCancellationBeforeReadAndAfterLateBytesOrEOF`
- `testSharedReaderPrefersCancellationOverLateIOErrors`
- `testSharedReaderRejectsCancellationDuringSynchronize`
- `testSharedReaderValidatesSplitHeadersSizeAndDigest`
- `testSharedReaderCopiesRealFileIntoStagingWithoutChangingSource`
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
- `testMonitorRegistrationRemainsOwnedUntilAStoppedResolverReturns`
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

- `testMaterialPersistenceAndWebPDF`

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

- `test_batch_cancellation_is_separate_from_child_deadline`
- `test_paused_files_do_not_start_background_work_before_foreground_return`
- `test_special_provider_refresh_keeps_cancellation_separate_from_failure`
- `test_recovered_timetable_clears_previous_error_only_after_commit`
- `test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration`
- `test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success`
- `test_actual_callbacks_preserve_rejected_preview_and_dispatch_accepted_action_once`
- `test_actual_worker_records_failure_only_for_the_reviewed_original`
- `test_invalid_year_blocks_change_acquisition_without_stalling_other_queued_materials`
