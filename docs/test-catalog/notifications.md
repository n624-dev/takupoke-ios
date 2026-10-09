# 通知許可・実配信・設定・バックグラウンド

対応関係・宣言名・実行方法のSHA-256：
`f0548954c86dd8fbceb3085132d5a80e57a14f4b0a23cc4faf71e912ce80e9ed`

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
- `testInvalidDateCannotNotify`
- `testFailedParseCannotReplaceNotificationBaselineWithPreviousAnalysis`

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`
- `testChangedDataProducesOneLocalNotification`

## [tests/test_notification_settings_lifecycle.py](../../tests/test_notification_settings_lifecycle.py)

- `test_actual_bridge_preserves_os_objects_for_immediate_delayed_and_cancelled_reads`
- `test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status`
