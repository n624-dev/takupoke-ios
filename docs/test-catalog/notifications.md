# 通知許可・実配信・設定・バックグラウンド

対応関係・宣言名・実行方法のSHA-256：
`221b3efe8967cfcd563d21a3efbdf6dcb4435116a7c35dc7a5a4e4a94a5e7fc1`

環境：Apple iOS26/27 UI＋Native。自然なバックグラウンドは実機限定

```bash
TKPK_UI_SHARD=A bash tools/test-app-ui.sh
python3 -B -m unittest discover -s tests -p test_notification_settings_lifecycle.py -v
```

## 変更時に確認するソース

- [Takupoke/BackgroundRefresh.swift](../../Takupoke/BackgroundRefresh.swift)
- [Takupoke/NotificationSettingsView.swift](../../Takupoke/NotificationSettingsView.swift)
- [Takupoke/ScheduleNotificationSnapshot.swift](../../Takupoke/ScheduleNotificationSnapshot.swift)
- [Takupoke/ScheduleNotifications.swift](../../Takupoke/ScheduleNotifications.swift)

## [tests/ScheduleNotificationTests.swift](../../tests/ScheduleNotificationTests.swift)

- `testPersonalEditRebasesSameDocumentAndLaterSchoolUpdateNotifies`
- `testLegacyBaselineAdoptsDocumentOnPersonalSaveAndPreservesSchoolNotices`
- `testFirstImportAndUnchangedContentDoNotNotify`
- `testUpdatesOnlyCountSelectedClassesTodayOrLaterAndCountReplacementsOnce`
- `testSelectionChangeAndReorderingDoNotBecomeDataUpdates`
- `testSavedBaselineSurvivesRestartAndSeparatesExamAndReturn`
- `testMalformedStoredBaselineRecoversWithoutInventingAnUpdate`
- `testStoredBaselinePreservesUnrecognizedFormatAndDoesNotFollowSymlinks`
- `testFailedChangeSendCannotSurviveClassSwitchTargetExpiryOrChangedContent`
- `testIndexedChangesRetainAllContentsAndMergeOnlyEligiblePendingSlots`
- `testFailedRemovalNoticeRemainsRelevantOnlyWhileSlotIsAbsent`
- `testPersistedPendingSurvivesPartialStartupAndOnlyConfirmedAbsenceClearsIt`
- `testInvalidDateCannotNotify`
- `testFailedParseCannotReplaceNotificationBaselineWithPreviousAnalysis`

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testCountdownDeleteWriteFailureKeepsDetailAndCanRetry`
- `testCountdownNotificationRouteOpensCurrentDetailAndMissingTargetList`
- `testSchoolCountdownReservesBothLaterPeriodsWhileCurrentPeriodIsDisplayed`
- `testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration`
- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`
- `testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors`
- `testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch`

## [tests/test_notification_settings_lifecycle.py](../../tests/test_notification_settings_lifecycle.py)

- `test_disabling_update_notices_removes_owned_ids_now_and_after_a_late_write`
- `test_countdown_retries_only_rejected_missing_reservations_while_plan_is_current`
- `test_explicit_countdown_authorization_starts_without_a_settings_read`
- `test_countdown_storage_actions_remove_only_owned_pending_notifications`
- `test_authorization_bridge_requires_one_real_callback_and_preserves_denial_and_errors`
- `test_actual_bridge_preserves_os_objects_and_finishes_cancelled_or_missing_reads`
- `test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status`
- `test_actual_apply_keeps_denial_storage_and_independent_delivery_results_separate`
- `test_retention_can_retry_private_notification_cleanup_after_unknown_os_reads`
- `test_retention_does_not_wait_indefinitely_or_clean_up_before_a_notification_write_finishes`
- `test_background_refresh_waits_for_countdown_and_cancels_its_owned_plan`
