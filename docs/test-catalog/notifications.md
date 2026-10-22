# 通知許可・実配信・設定・バックグラウンド

対応関係・宣言名・実行方法のSHA-256：
`babe5125e3704c1e2510c0a27cf93469000d31bb73ca9da0b353d3943b12c1df`

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

- `testFirstImportAndUnchangedContentDoNotNotify`
- `testUpdatesOnlyCountSelectedClassesTodayOrLaterAndCountReplacementsOnce`
- `testSelectionChangeAndReorderingDoNotBecomeDataUpdates`
- `testSavedBaselineSurvivesRestartAndSeparatesExamAndReturn`
- `testFailedChangeSendCannotSurviveClassSwitchTargetExpiryOrChangedContent`
- `testFailedRemovalNoticeRemainsRelevantOnlyWhileSlotIsAbsent`
- `testPersistedPendingSurvivesPartialStartupAndOnlyConfirmedAbsenceClearsIt`
- `testInvalidDateCannotNotify`
- `testFailedParseCannotReplaceNotificationBaselineWithPreviousAnalysis`

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`

## [tests/test_notification_settings_lifecycle.py](../../tests/test_notification_settings_lifecycle.py)

- `test_authorization_bridge_requires_one_real_callback_and_preserves_denial_and_errors`
- `test_actual_bridge_preserves_os_objects_for_immediate_delayed_and_cancelled_reads`
- `test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status`
