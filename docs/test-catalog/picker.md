# ファイル選択・再選択・背景・キャンセル

対応関係・宣言名・実行方法のSHA-256：
`db9502e87a0ec4e2f9faf17c2b0baa97aaa6d2fc9f74748a5c3c27b6e12cc098`

環境：Apple iOS26/27 UI＋Nativeレイアウト

```bash
bash tools/test-picker-ui.sh
```

## 変更時に確認するソース

- [Takupoke/GuidedDocumentPicker.swift](../../Takupoke/GuidedDocumentPicker.swift)
- [Takupoke/MaterialDocumentPicker.swift](../../Takupoke/MaterialDocumentPicker.swift)
- [Takupoke/MaterialPickerLayout.swift](../../Takupoke/MaterialPickerLayout.swift)
- [tests/ui/MaterialPickerUIChecks.swift](../../tests/ui/MaterialPickerUIChecks.swift)
- [tests/ui/PickerTapHarness.swift](../../tests/ui/PickerTapHarness.swift)
- [tools/picker_test_project.py](../../tools/picker_test_project.py)
- [tools/test-picker-ui.sh](../../tools/test-picker-ui.sh)

## [tests/MaterialPickerLayoutTests.swift](../../tests/MaterialPickerLayoutTests.swift)

- `testInstructionNeverCoversPickerAtPhoneSizes`
- `testWrappedInstructionReservesMoreSpaceWithoutMovingBottomControls`

## [tests/ui/MaterialPickerTapChecks.swift](../../tests/ui/MaterialPickerTapChecks.swift)

- `testInstructionSurroundMatchesFilesBackground`
- `testReselectionWithMissingAppearanceReturn`
- `testReselectionThroughActualButtons`

## [tests/test_picker_ui_runner.py](../../tests/test_picker_ui_runner.py)

- `test_preparation_order_exact_completions_failures_and_owned_cleanup`
