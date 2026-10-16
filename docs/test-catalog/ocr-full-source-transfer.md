# 全PDF原画素・実罫線からのOCR領域取得比較（研究）

対応関係・宣言名・実行方法のSHA-256：
`717c0e3c598727c0d8e364aff598708f22c35165a42cbfa0788ccaa7706d5f21`

環境：macOS26/PDFKit/Vision・実RecoveryRasterGrid。各条件444値×2描画条件、初期探索であり正式採用・iPhone品質ではない

```bash
bash tools/ocr-full-document-transfer/run.sh
TAKUPOKE_OCR_FULL_FONTS=<owned-pinned-fonts> python3 -B -m unittest discover -s tests -p test_ocr_full_document_transfer.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-full-document-transfer.yml](../../.github/workflows/ocr-full-document-transfer.yml)
- [tools/ocr-full-document-transfer/compare.py](../../tools/ocr-full-document-transfer/compare.py)
- [tools/ocr-full-document-transfer/generate.py](../../tools/ocr-full-document-transfer/generate.py)
- [tools/ocr-full-document-transfer/mask-access.swift](../../tools/ocr-full-document-transfer/mask-access.swift)
- [tools/ocr-full-document-transfer/protocol.json](../../tools/ocr-full-document-transfer/protocol.json)
- [tools/ocr-full-document-transfer/read.py](../../tools/ocr-full-document-transfer/read.py)
- [tools/ocr-full-document-transfer/run.sh](../../tools/ocr-full-document-transfer/run.sh)

## [tests/test_ocr_full_document_transfer.py](../../tests/test_ocr_full_document_transfer.py)

- `test_reader_manifest_never_contains_answers_or_region_coordinates`
- `test_all_six_sources_are_image_only_and_keep_the_complete_declared_scope`
- `test_same_independent_normal_design_reproduces_pdf_and_source_pixels`
- `test_prior_source_is_never_overwritten`
- `test_post_test_capture_report_keeps_original_rank_unicode_probability_and_box`
- `test_post_test_capture_report_refuses_duplicate_or_missing_original_orders`
- `test_frames_preserve_all_original_ink_without_grabbing_the_next_line`
- `test_competing_cell_owners_are_not_resolved_by_prediction_or_nearest_cell`
- `test_rule_mask_cannot_hide_white_gaps`
- `test_an_unread_region_is_not_ignored_when_another_fragment_matches`
- `test_a_physical_region_covering_two_semantic_cells_has_no_unique_owner`
- `test_correct_fields_do_not_hide_an_unassigned_region_crossing_role_bands`

## [tests/RecoveryFullSourceProbeTests.swift](../../tests/RecoveryFullSourceProbeTests.swift)

- `testAcquireFullOriginalPixelsNativeVisionAndPhysicalRules`
