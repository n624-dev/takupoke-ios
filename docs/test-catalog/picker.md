# ファイル選択・再選択・背景・キャンセル

対応関係・宣言名・実行方法のSHA-256：
`d1bb4ab73d0e278cf0d91e16811dd7aa154a09e78943212afd049ff4610b22ce`

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
