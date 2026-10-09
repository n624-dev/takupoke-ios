# ファイル選択・再選択・背景・キャンセル

対応ソース・テストのSHA-256：
`fe8de2db5f1b1b2b02cf6b771e15233703c92deb7995e04bc94f588b0169a2a1`

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

- `testInstructionNeverCoversPickerAtPhoneSizes`（宣言行 5）
- `testWrappedInstructionReservesMoreSpaceWithoutMovingBottomControls`（宣言行 25）

## [tests/ui/MaterialPickerTapChecks.swift](../../tests/ui/MaterialPickerTapChecks.swift)

- `testInstructionSurroundMatchesFilesBackground`（宣言行 7）
- `testReselectionWithMissingAppearanceReturn`（宣言行 54）
- `testReselectionThroughActualButtons`（宣言行 66）
