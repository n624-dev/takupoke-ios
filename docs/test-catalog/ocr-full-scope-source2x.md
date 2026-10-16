# 全17クラス・5日・全時限の原PDF2x固定比較

対応関係・宣言名・実行方法のSHA-256：
`5560cfa5497f55f095aa78f22451dce16b5f1b126bad89b81fbe7a9bc3fbda94`

環境：Apple SDK26。既使用の独立架空6資料、現行2048 V6の失敗とは別条件

```bash
bash tools/ocr-full-scope-source2x/run.sh
```

## 変更時に確認するソース

- [.github/workflows/ocr-full-scope-source2x.yml](../../.github/workflows/ocr-full-scope-source2x.yml)
- [tools/ocr-full-scope-source2x/protocol.json](../../tools/ocr-full-scope-source2x/protocol.json)
- [tools/ocr-full-scope-source2x/run.sh](../../tools/ocr-full-scope-source2x/run.sh)

## [tests/test_ocr_document_qualification.py](../../tests/test_ocr_document_qualification.py)

- `test_all_six_frozen_sources_have_all_classes_days_periods_and_image_only_pixels`
- `test_frozen_case_reproduces_pdf_and_oracle_without_reading_model_output`
- `test_unknown_case_and_overwrite_are_rejected`

## [tests/RecoveryDocumentQualificationTests.swift](../../tests/RecoveryDocumentQualificationTests.swift)

- `testAcquireCompleteFrozenOriginalSource`

## [tests/test_ocr_research_receipt.py](../../tests/test_ocr_research_receipt.py)

- `test_source_receipt_keeps_wrong_unassigned_and_ineligible_outcomes_visible`
- `test_no_original_text_prompt_recovery_result_or_unknown_strings_enter_notice`
- `test_source_receipt_refuses_missing_scope_wrong_variant_and_unexecuted_native_capture`
- `test_native_receipt_requires_all_original_probability_and_identity_checks`
- `test_counts_hashes_and_measurements_cannot_hide_nonfinite_or_free_text_values`
