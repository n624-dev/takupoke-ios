# OCR研究の有限数値レシート・原文の非送信

対応関係・宣言名・実行方法のSHA-256：
`ca63cae52d5bfec3422f3a152d7c12e50c04cf0570735b7ad0591d2e2a0ae268`

環境：Linux Python。実推論／精度合格は各Apple研究jobで別検証

```bash
python3 -B -m unittest discover -s tests -p test_ocr_research_receipt.py -v
```

## 変更時に確認するソース

- [tools/ocr-research-receipt.py](../../tools/ocr-research-receipt.py)

## [tests/test_ocr_research_receipt.py](../../tests/test_ocr_research_receipt.py)

- `test_source_receipt_keeps_wrong_unassigned_and_ineligible_outcomes_visible`
- `test_no_original_text_prompt_recovery_result_or_unknown_strings_enter_notice`
- `test_source_receipt_refuses_missing_scope_wrong_variant_and_unexecuted_native_capture`
- `test_native_receipt_requires_all_original_probability_and_identity_checks`
- `test_counts_hashes_and_measurements_cannot_hide_nonfinite_or_free_text_values`
