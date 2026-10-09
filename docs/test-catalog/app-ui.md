# 通常画面・設定・実Switch・UI fixture・登録一覧

対応関係・宣言名・実行方法のSHA-256：
`0738ed2a7265c88ac8c35366247b49936011fbcd16f609ff4b5f36cbd7d63807`

環境：Apple iOS26/27。LinuxはPython契約検査のみ

```bash
bash tools/test-app-ui.sh
```

## 変更時に確認するソース

- [.github/workflows/application-relaunch-native-probe.yml](../../.github/workflows/application-relaunch-native-probe.yml)
- [.github/workflows/ordered-row-proof-native.yml](../../.github/workflows/ordered-row-proof-native.yml)
- [Takupoke/AboutView.swift](../../Takupoke/AboutView.swift)
- [Takupoke/AccountDataModel.swift](../../Takupoke/AccountDataModel.swift)
- [Takupoke/AccountDataSettingsView.swift](../../Takupoke/AccountDataSettingsView.swift)
- [Takupoke/AppIcon.icon/icon.json](../../Takupoke/AppIcon.icon/icon.json)
- [Takupoke/ApplicationData.swift](../../Takupoke/ApplicationData.swift)
- [Takupoke/Assets.xcassets/AppIcon.appiconset/Contents.json](../../Takupoke/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [Takupoke/Assets.xcassets/Contents.json](../../Takupoke/Assets.xcassets/Contents.json)
- [Takupoke/ContentView.swift](../../Takupoke/ContentView.swift)
- [Takupoke/HomeLessonRow.swift](../../Takupoke/HomeLessonRow.swift)
- [Takupoke/HomeTodayView.swift](../../Takupoke/HomeTodayView.swift)
- [Takupoke/HomeView.swift](../../Takupoke/HomeView.swift)
- [Takupoke/Info.plist](../../Takupoke/Info.plist)
- [Takupoke/LegalDocumentView.swift](../../Takupoke/LegalDocumentView.swift)
- [Takupoke/LinkRow.swift](../../Takupoke/LinkRow.swift)
- [Takupoke/LoadingRow.swift](../../Takupoke/LoadingRow.swift)
- [Takupoke/MainColor.swift](../../Takupoke/MainColor.swift)
- [Takupoke/OpenSourceLicensesView.swift](../../Takupoke/OpenSourceLicensesView.swift)
- [Takupoke/PrivacyInfo.xcprivacy](../../Takupoke/PrivacyInfo.xcprivacy)
- [Takupoke/SafariLinkView.swift](../../Takupoke/SafariLinkView.swift)
- [Takupoke/SavedPDFView.swift](../../Takupoke/SavedPDFView.swift)
- [Takupoke/SettingsView.swift](../../Takupoke/SettingsView.swift)
- [Takupoke/SetupView.swift](../../Takupoke/SetupView.swift)
- [Takupoke/TakupokeApp.swift](../../Takupoke/TakupokeApp.swift)
- [Takupoke/TimetableClassSelection.swift](../../Takupoke/TimetableClassSelection.swift)
- [Takupoke/TimetableView+Cards.swift](../../Takupoke/TimetableView+Cards.swift)
- [Takupoke/TimetableView+Changes.swift](../../Takupoke/TimetableView+Changes.swift)
- [Takupoke/TimetableView+DayColumns.swift](../../Takupoke/TimetableView+DayColumns.swift)
- [Takupoke/TimetableView+Details.swift](../../Takupoke/TimetableView+Details.swift)
- [Takupoke/TimetableView+Grid.swift](../../Takupoke/TimetableView+Grid.swift)
- [Takupoke/TimetableView+GridHeaders.swift](../../Takupoke/TimetableView+GridHeaders.swift)
- [Takupoke/TimetableView+Layout.swift](../../Takupoke/TimetableView+Layout.swift)
- [Takupoke/TimetableView+Navigation.swift](../../Takupoke/TimetableView+Navigation.swift)
- [Takupoke/TimetableView+Times.swift](../../Takupoke/TimetableView+Times.swift)
- [Takupoke/TimetableView+WeekSection.swift](../../Takupoke/TimetableView+WeekSection.swift)
- [Takupoke/TimetableView.swift](../../Takupoke/TimetableView.swift)
- [Takupoke/UsageHelpView.swift](../../Takupoke/UsageHelpView.swift)
- [tests/ui/ApplicationChecks+Navigation.swift](../../tests/ui/ApplicationChecks+Navigation.swift)
- [tests/ui/ApplicationChecks.swift](../../tests/ui/ApplicationChecks.swift)
- [tests/ui/ApplicationFixture+Changes.swift](../../tests/ui/ApplicationFixture+Changes.swift)
- [tests/ui/ApplicationFixture+Events.swift](../../tests/ui/ApplicationFixture+Events.swift)
- [tests/ui/ApplicationFixture+Grid.swift](../../tests/ui/ApplicationFixture+Grid.swift)
- [tests/ui/ApplicationFixture+OCR.swift](../../tests/ui/ApplicationFixture+OCR.swift)
- [tests/ui/ApplicationFixture+Recovery.swift](../../tests/ui/ApplicationFixture+Recovery.swift)
- [tests/ui/ApplicationFixture+Selection.swift](../../tests/ui/ApplicationFixture+Selection.swift)
- [tests/ui/ApplicationFixture.swift](../../tests/ui/ApplicationFixture.swift)
- [tools/app_test_project.py](../../tools/app_test_project.py)
- [tools/test-app-ui.sh](../../tools/test-app-ui.sh)
- [tools/ui_test_manifest.py](../../tools/ui_test_manifest.py)
- [tests/Support/ObservedScreenGeometry.swift](../../tests/Support/ObservedScreenGeometry.swift)

## [tests/MainColorTests.swift](../../tests/MainColorTests.swift)

- `testDefaultAndChoiceOrder`
- `testUnsetPreferenceDoesNotCreateAStoredColor`
- `testAllSavedColorsSurviveReadAndDefaultRemovesOnlyColor`
- `testDefaultHasNoTintOverrideAndExplicitBlueIsKept`

## [tests/test_ui_test_manifest.py](../../tests/test_ui_test_manifest.py)

- `test_split_sources_are_registered_in_the_selected_target_only`
- `test_unregistered_split_file_is_rejected`
- `test_manual_split_registers_all_helpers_and_refuses_unknown_files`
- `test_network_rewrite_preserves_standard_xlsx_identifiers_only`
- `test_ai_switch_probe_preserves_production_setter_and_rejects_marker_drift`
- `test_notification_switch_trace_preserves_setters_and_rejects_marker_drift`
- `test_notification_readiness_probe_observes_os_without_granting_or_saving`
- `test_owned_launch_trace_filters_other_content_and_refuses_symlinks_and_large_files`
- `test_picker_completion_rejects_missing_failed_skipped_duplicate_and_unknown_cases`
- `test_event_cache_probe_changes_only_automatic_startup_in_isolated_copy`
- `test_native_ocr_probe_preserves_actual_multiline_confidence_guard`
- `test_all_source_tests_are_assigned_once_and_both_os_checks_are_required`
- `test_missing_obsolete_or_duplicate_source_tests_fail`
- `test_overlapping_manifest_is_rejected`
- `test_passed_results_with_only_the_declared_voiceover_exception`
- `test_empty_missing_extra_and_duplicate_results_fail`
- `test_failure_and_unexpected_skip_fail`
- `test_workflow_matrix_matches_gate_and_publish_follows_gate`
- `test_manual_matrix_requires_every_unchanged_case_on_both_os_separately`
- `test_cli_selects_the_complete_shard_and_rejects_invalid_shard`
- `test_cli_reads_japanese_source_with_non_utf8_default_encoding`
- `test_relaunch_diagnosis_cannot_replace_the_full_shard_gate`
- `test_single_diagnostic_case_requires_exact_completion_and_cannot_select_full_shards`
- `test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs`
- `test_both_shards_on_both_os_preserve_selection_and_os_size_checks`
- `test_missing_xctest_completion_fails_shell_and_cleans_up`

## [tests/ui/ApplicationChecks+Changes.swift](../../tests/ui/ApplicationChecks+Changes.swift)

- `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`

## [tests/ui/ApplicationChecks+Events.swift](../../tests/ui/ApplicationChecks+Events.swift)

- `testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair`
- `testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates`

## [tests/ui/ApplicationChecks+Recovery.swift](../../tests/ui/ApplicationChecks+Recovery.swift)

- `testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption`
- `testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption`
- `testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis`
- `testRecoveryClosingKeepsFormalAndModelManagementIsAccessible`
- `testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster`

## [tests/ui/ApplicationChecks+Settings.swift](../../tests/ui/ApplicationChecks+Settings.swift)

- `testSettingsAccountDataAndFileDetails`
- `testUsageHelpIsOrganizedByTask`
- `testSettingsGroupsAndCompactDataOverviews`
- `testEmptyDataCanBeConfigured`
- `testChangedAccountDataNoticeOpensSharedAcquisition`
- `testFileFailuresKeepResultsAndStayInTheirOwnDetails`
- `testSettingsClassSelectionSharesTimetablePreference`
- `testLinkPreferencesSurviveRelaunch`
- `testLegalDocumentsAndIndividualLicenses`
- `testSetupCanBeSkippedAndOffersAllFiles`

## [tests/ui/ApplicationChecks+Timetable.swift](../../tests/ui/ApplicationChecks+Timetable.swift)

- `testMergedCardsFromAllSources`
- `testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork`
- `testHomeTimetableAndWeekCalendar`
- `testTimetableDynamicTypeScalesAndRestoresStandardLayout`
- `testTimetableUsesSystemTextSize`
- `testTimetableCommonClocksAndEventOnlyWeekScale`
- `testVoiceOverReadsTimetableCard`
- `testVoiceOverReadsTimetableCard`

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`

## [tests/ObservedScreenGeometryTests.swift](../../tests/ObservedScreenGeometryTests.swift)

- `testObservedEqualPhysicalEdgesSurviveFloatingPointArithmetic`
- `testPhysicalAndFractionalPixelClippingIsStillRejectedOnEveryEdge`
- `testEmptyNonFiniteAndInvalidScaleDoNotBecomeVisible`
