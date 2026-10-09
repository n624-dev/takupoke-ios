# 通知許可・実配信・設定・バックグラウンド

対応ソース・テストのSHA-256：
`5b521f59b2dbfd6c83e2ab25691d2a7f36537b6d38ea28c0b6ab958b40ea9959`

環境：Apple iOS26/27 UI＋Native。自然なバックグラウンドは実機限定

```bash
TKPK_UI_SHARD=A bash tools/test-app-ui.sh
```

## 変更時に確認するソース

- [Takupoke/BackgroundRefresh.swift](../../Takupoke/BackgroundRefresh.swift)
- [Takupoke/NotificationSettingsView.swift](../../Takupoke/NotificationSettingsView.swift)
- [Takupoke/ScheduleNotificationSnapshot.swift](../../Takupoke/ScheduleNotificationSnapshot.swift)
- [Takupoke/ScheduleNotifications.swift](../../Takupoke/ScheduleNotifications.swift)

## [tests/ScheduleNotificationTests.swift](../../tests/ScheduleNotificationTests.swift)

- `testFirstImportAndUnchangedContentDoNotNotify`（宣言行 12）
- `testUpdatesOnlyCountSelectedClassesTodayOrLaterAndCountReplacementsOnce`（宣言行 21）
- `testSelectionChangeAndReorderingDoNotBecomeDataUpdates`（宣言行 34）
- `testSavedBaselineSurvivesRestartAndSeparatesExamAndReturn`（宣言行 40）
- `testFailedChangeSendCannotSurviveClassSwitchTargetExpiryOrChangedContent`（宣言行 54）
- `testFailedRemovalNoticeRemainsRelevantOnlyWhileSlotIsAbsent`（宣言行 70）
- `testInvalidDateCannotNotify`（宣言行 79）
- `testFailedParseCannotReplaceNotificationBaselineWithPreviousAnalysis`（宣言行 84）

## [tests/ui/ApplicationChecks+Notifications.swift](../../tests/ui/ApplicationChecks+Notifications.swift)

- `testNotificationControlsAndAppearance`（宣言行 80）
- `testChangedDataProducesOneLocalNotification`（宣言行 148）
