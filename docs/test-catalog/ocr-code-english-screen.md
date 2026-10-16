# 原教室コード・英語専用VisionとEnglishV1の独立比較

対応関係・宣言名・実行方法のSHA-256：
`77fe15f394f06fa4c761dc5ef43d84067201dd12b70b3fbf135afc0dd9be53cc`

環境：Linux契約検査／Mac SDK26 Native Vision（研究専用）

```bash
bash tools/ocr-code-english-screen/run.sh
python3 -B -m unittest discover -s tests -p test_ocr_code_english_screen.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-code-english-screen.yml](../../.github/workflows/ocr-code-english-screen.yml)
- [tools/ocr-code-english-screen/protocol.json](../../tools/ocr-code-english-screen/protocol.json)
- [tools/ocr-code-english-screen/code_english_contract.py](../../tools/ocr-code-english-screen/code_english_contract.py)
- [tools/ocr-code-english-screen/prepare.py](../../tools/ocr-code-english-screen/prepare.py)
- [tools/ocr-code-english-screen/read.py](../../tools/ocr-code-english-screen/read.py)
- [tools/ocr-code-english-screen/read.swift](../../tools/ocr-code-english-screen/read.swift)
- [tools/ocr-code-english-screen/compare.py](../../tools/ocr-code-english-screen/compare.py)
- [tools/ocr-code-english-screen/run.sh](../../tools/ocr-code-english-screen/run.sh)

## [tests/test_ocr_code_english_screen.py](../../tests/test_ocr_code_english_screen.py)

- `test_identical_pixel_conflicting_literals_are_reported_without_removing_fields`
- `test_complete_inventory_and_distinct_literal_probability_domains`
- `test_high_score_wrong_outputs_and_paired_losses_are_retained`
- `test_missing_duplicate_reordered_and_partial_calls_fail`
- `test_changed_pixels_configuration_and_padding_are_rejected`
- `test_geometry_remains_original_and_outside_is_not_clamped_or_hidden`
- `test_input_inventory_rejects_expected_text_and_original_byte_drift`
- `test_native_api_error_is_retained_and_cli_fails_after_complete_raw_report`
