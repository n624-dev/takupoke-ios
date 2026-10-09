# 通常画面・設定・実Switch・UI fixture・登録一覧

対応ソース・テストのSHA-256：
`91a83e8849b6bea7ec2cdeb4d3b237424db247cd24085c69261061a60aae5878`

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

## [tests/MainColorTests.swift](../../tests/MainColorTests.swift)

- `testDefaultAndChoiceOrder`（宣言行 5）
- `testUnsetPreferenceDoesNotCreateAStoredColor`（宣言行 10）
- `testAllSavedColorsSurviveReadAndDefaultRemovesOnlyColor`（宣言行 20）
- `testDefaultHasNoTintOverrideAndExplicitBlueIsKept`（宣言行 37）

## [tests/test_ui_test_manifest.py](../../tests/test_ui_test_manifest.py)

- `test_split_sources_are_registered_in_the_selected_target_only`（宣言行 25）
- `test_unregistered_split_file_is_rejected`（宣言行 44）
- `test_network_rewrite_preserves_standard_xlsx_identifiers_only`（宣言行 56）
- `test_ai_switch_probe_preserves_production_setter_and_rejects_marker_drift`（宣言行 71）
- `test_picker_completion_rejects_missing_failed_skipped_duplicate_and_unknown_cases`（宣言行 84）
- `test_event_cache_probe_changes_only_automatic_startup_in_isolated_copy`（宣言行 102）
- `test_native_ocr_probe_preserves_actual_multiline_confidence_guard`（宣言行 116）
- `test_all_source_tests_are_assigned_once_and_both_os_checks_are_required`（宣言行 172）
- `test_missing_obsolete_or_duplicate_source_tests_fail`（宣言行 180）
- `test_overlapping_manifest_is_rejected`（宣言行 188）
- `test_passed_results_with_only_the_declared_voiceover_exception`（宣言行 193）
- `test_empty_missing_extra_and_duplicate_results_fail`（宣言行 202）
- `test_failure_and_unexpected_skip_fail`（宣言行 210）
- `test_workflow_matrix_matches_gate_and_publish_follows_gate`（宣言行 218）
- `test_manual_matrix_requires_every_unchanged_case_on_both_os_separately`（宣言行 232）
- `test_cli_selects_the_complete_shard_and_rejects_invalid_shard`（宣言行 264）
- `test_cli_reads_japanese_source_with_non_utf8_default_encoding`（宣言行 273）
- `test_relaunch_diagnosis_cannot_replace_the_full_shard_gate`（宣言行 281）
- `test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs`（宣言行 296）
- `test_both_shards_on_both_os_preserve_selection_and_os_size_checks`（宣言行 371）
- `test_missing_xctest_completion_fails_shell_and_cleans_up`（宣言行 393）

## [tests/ui/ApplicationChecks+Changes.swift](../../tests/ui/ApplicationChecks+Changes.swift)

- `testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch`（宣言行 6）

## [tests/ui/ApplicationChecks+Events.swift](../../tests/ui/ApplicationChecks+Events.swift)

- `testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair`（宣言行 4）
- `testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates`（宣言行 76）

## [tests/ui/ApplicationChecks+Recovery.swift](../../tests/ui/ApplicationChecks+Recovery.swift)

- `testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption`（宣言行 118）
- `testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption`（宣言行 150）
- `testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis`（宣言行 184）
- `testRecoveryClosingKeepsFormalAndModelManagementIsAccessible`（宣言行 266）
- `testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster`（宣言行 279）

## [tests/ui/ApplicationChecks+Settings.swift](../../tests/ui/ApplicationChecks+Settings.swift)

- `testSettingsAccountDataAndFileDetails`（宣言行 6）
- `testUsageHelpIsOrganizedByTask`（宣言行 100）
- `testSettingsGroupsAndCompactDataOverviews`（宣言行 117）
- `testEmptyDataCanBeConfigured`（宣言行 142）
- `testChangedAccountDataNoticeOpensSharedAcquisition`（宣言行 163）
- `testFileFailuresKeepResultsAndStayInTheirOwnDetails`（宣言行 178）
- `testSettingsClassSelectionSharesTimetablePreference`（宣言行 206）
- `testLinkPreferencesSurviveRelaunch`（宣言行 224）
- `testLegalDocumentsAndIndividualLicenses`（宣言行 287）
- `testSetupCanBeSkippedAndOffersAllFiles`（宣言行 322）

## [tests/ui/ApplicationChecks+Timetable.swift](../../tests/ui/ApplicationChecks+Timetable.swift)

- `testMergedCardsFromAllSources`（宣言行 6）
- `testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork`（宣言行 31）
- `testHomeTimetableAndWeekCalendar`（宣言行 91）
- `testTimetableDynamicTypeScalesAndRestoresStandardLayout`（宣言行 138）
- `testTimetableUsesSystemTextSize`（宣言行 241）
- `testTimetableCommonClocksAndEventOnlyWeekScale`（宣言行 262）
- `testVoiceOverReadsTimetableCard`（宣言行 315）
- `testVoiceOverReadsTimetableCard`（宣言行 333）

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`（宣言行 80）
- `testChangedDataProducesOneLocalNotification`（宣言行 148）
