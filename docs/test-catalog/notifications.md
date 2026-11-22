# 通知許可・実配信・設定・バックグラウンド

対応関係・宣言名・実行方法のSHA-256：
`e259b3621ab8dec9d05d8fc3379a95b65498696c91f4809ef56b1601fee841f2`

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

- `testCountdownNotificationRouteOpensCurrentDetailAndMissingTargetList`
- `testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration`
- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`
- `testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors`
- `testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch`

## [tests/test_notification_settings_lifecycle.py](../../tests/test_notification_settings_lifecycle.py)

- `test_explicit_countdown_authorization_starts_without_a_settings_read`
- `test_countdown_storage_actions_remove_only_owned_pending_notifications`
- `test_authorization_bridge_requires_one_real_callback_and_preserves_denial_and_errors`
- `test_actual_bridge_preserves_os_objects_for_immediate_delayed_and_cancelled_reads`
- `test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status`
- `test_actual_apply_keeps_denial_separate_from_storage_success_and_failure`
- `test_background_refresh_waits_for_countdown_and_cancels_its_owned_plan`
