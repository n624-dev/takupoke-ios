# ステータス・公開監視情報・取消表示

対応関係・宣言名・実行方法のSHA-256：
`330d2c4c493c94fd8e9a2d97dac5783830d137e421f61efb1a8098b135f69d42`

環境：Linux Swift（状態判定）／Apple iOS26/27（画面・通信）

```bash
bash tools/test-parsing.sh
bash tools/test-app-ui.sh
```

## 変更時に確認するソース

- [Takupoke/AppStatusView.swift](../../Takupoke/AppStatusView.swift)
- [Takupoke/ServiceStatus.swift](../../Takupoke/ServiceStatus.swift)
- [Takupoke/ServiceStatusModel.swift](../../Takupoke/ServiceStatusModel.swift)
- [Takupoke/ServiceStatusView.swift](../../Takupoke/ServiceStatusView.swift)
- [Takupoke/StatusPresentation.swift](../../Takupoke/StatusPresentation.swift)
- [Takupoke/StatusRow.swift](../../Takupoke/StatusRow.swift)

## [tests/ServiceStatusTests.swift](../../tests/ServiceStatusTests.swift)

- `testUsesLinkedIDsAndIgnoresUnrelatedOutageAndNames`
- `testUnlinkedMissingDuplicateWrongTypeAndUnknownStateNeverBecomeHealthy`
- `testHistoryKeepsUnmonitoredRecoveryAndUnknownDaysWithoutInventingDates`
- `testResolvedIncidentWithNullEndAndUnsortedUpdatesUsesRelationships`
- `testCacheFailureExpiryAndClockRollbackRetainEvidenceButNotCurrentNormal`
- `testMissingResourcesKeepTheirPreviousHistoryWithoutRevalidatingThem`
- `testInvalidEnvelopeAndOversizedResponseAreRejected`
- `testMonitorStalenessFieldAndPageMetadataAreNotProbeDates`

## [tests/StatusPresentationTests.swift](../../tests/StatusPresentationTests.swift)

- `testCancellationIsNeutralAndKeepsTheSavedResult`
- `testUnknownAndUnselectedDoNotBecomeFailuresOrAllNormal`
- `testAccountAcquisitionDoesNotAssertLatestOrAuthentication`
- `testSummaryCountsAttentionWithoutCountingNeutralCancellation`
- `testOnlyCancellationErrorsAreNeutral`
- `testExplicitResumeIsInSessionAndDoesNotReplayDiscardedRequests`

## [tests/ui/ApplicationChecks+Settings.swift](../../tests/ui/ApplicationChecks+Settings.swift)

- `testRetentionMarkerRecoveryRequiresConfirmationAndPreservesPublicData`
- `testSettingsAccountDataAndFileDetails`
- `testUsageHelpIsOrganizedByTask`
- `testSettingsGroupsAndCompactDataOverviews`
- `testStatusScreenUsesPublicResourcesAndDataRoutes`
- `testEmptyDataCanBeConfigured`
- `testChangedAccountDataNoticeOpensSharedAcquisition`
- `testFileFailuresKeepResultsAndStayInTheirOwnDetails`
- `testSettingsClassSelectionSharesTimetablePreference`
- `testLinkPreferencesSurviveRelaunch`
- `testLegalDocumentsAndIndividualLicenses`
- `testSetupCanBeSkippedAndOffersAllFiles`

## [tests/test_application_ui_runner.py](../../tests/test_application_ui_runner.py)

- `test_actual_shutdown_helper_only_accepts_verified_target_state_after_exit_149`
- `test_diagnosis_defaults_to_27_without_adding_26_matrix_rows`
- `test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtime`
- `test_optional_hang_observer_preserves_phase_results_and_owned_cleanup`
- `test_input_probe_runs_each_original_case_once_on_the_same_owned_device`
- `test_year_input_probe_keeps_preceding_case_and_reads_keyboard_settings_without_writes`
- `test_successful_notification_probe_observes_os_before_deleting_simulator`
- `test_headless_runner_keeps_all_selected_ui_cases_and_actual_size_commands`
- `test_passing_ui_completions_without_native_case_identities_fail_closed`
- `test_both_shards_on_both_os_preserve_selection_and_os_size_checks`
- `test_missing_xctest_completion_fails_shell_and_cleans_up`
- `test_failed_ui_build_does_not_boot_or_run_tests_and_still_cleans_up`
- `test_failed_frontend_launch_does_not_run_ui_and_cleans_owned_device`
- `test_missing_selected_xcode_frontend_fails_without_running_ui`
- `test_failed_owned_device_window_does_not_run_ui_and_cleans_up`
- `test_failed_or_duplicate_first_batch_stops_without_retry_or_size_checks`
- `test_failed_final_notification_batch_is_not_rescued_by_passed_scenarios`
- `test_failed_fresh_notification_device_boot_stops_and_cleans_both_devices`
