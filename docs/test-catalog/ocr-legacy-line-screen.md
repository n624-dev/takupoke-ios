# 従来型Vision・原画素4倍反復の認識器探索

対応関係・宣言名・実行方法のSHA-256：
`decf2c038df12fbdd9f11099b2d77edfd30e7a1a441f85d1b8f69169c4bb75b4`

環境：Linux比較器／Mac SDK26 Native Vision（研究専用）

```bash
bash tools/ocr-legacy-line-screen/run.sh
python3 -B -m unittest discover -s tests -p test_ocr_legacy_line_screen.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-legacy-line-screen.yml](../../.github/workflows/ocr-legacy-line-screen.yml)
- [tools/ocr-legacy-line-screen/protocol.json](../../tools/ocr-legacy-line-screen/protocol.json)
- [tools/ocr-legacy-line-screen/read.swift](../../tools/ocr-legacy-line-screen/read.swift)
- [tools/ocr-legacy-line-screen/compare.py](../../tools/ocr-legacy-line-screen/compare.py)
- [tools/ocr-legacy-line-screen/run.sh](../../tools/ocr-legacy-line-screen/run.sh)

## [tests/test_ocr_legacy_line_screen.py](../../tests/test_ocr_legacy_line_screen.py)

- `test_preserves_high_score_wrong_and_counts_paired_gains_and_losses`
- `test_refuses_omission_duplication_source_drift_and_changed_configuration`
- `test_api_error_is_not_an_empty_or_successful_recognition`
- `test_split_outside_and_low_native_scores_are_retained`
- `test_geometry_error_preserves_recognized_literal_and_native_confidence`
