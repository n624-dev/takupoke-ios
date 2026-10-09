# 独立した架空PDF・原文契約・固定期待値

対応ソース・テストのSHA-256：
`686a7f6ad85fb876f8fdc5ac9879315e10b4e8cf53335a92e13a37a718589810`

環境：Linux契約検査。PDF描画・OCRはApple限定

```bash
python3 -B tools/recovery-prompt-contracts/test_shared_prompts.py
```

## 変更時に確認するソース

- [tests/fixtures/normalization.json](../../tests/fixtures/normalization.json)
- [tests/fixtures/recovery-exam.json](../../tests/fixtures/recovery-exam.json)
- [tests/fixtures/recovery-folded-preparation.json](../../tests/fixtures/recovery-folded-preparation.json)
- [tests/fixtures/recovery-generic-ruled-original-two.json](../../tests/fixtures/recovery-generic-ruled-original-two.json)
- [tests/fixtures/recovery-return.json](../../tests/fixtures/recovery-return.json)
- [tools/generate-normalization-fixtures.py](../../tools/generate-normalization-fixtures.py)
- [tools/independent-wide-timetable/artifact-pins.json](../../tools/independent-wide-timetable/artifact-pins.json)
- [tools/independent-wide-timetable/dense-artifact-pins.json](../../tools/independent-wide-timetable/dense-artifact-pins.json)
- [tools/independent-wide-timetable/expected.json](../../tools/independent-wide-timetable/expected.json)
- [tools/independent-wide-timetable/generate.py](../../tools/independent-wide-timetable/generate.py)
- [tools/independent-wide-timetable/generate_dense.py](../../tools/independent-wide-timetable/generate_dense.py)
- [tools/ordered-row-e2e/generate.py](../../tools/ordered-row-e2e/generate.py)
- [tools/recovery-prompt-contracts/check_ios_adapters.py](../../tools/recovery-prompt-contracts/check_ios_adapters.py)
- [tools/recovery-prompt-contracts/check_shared_prompts.py](../../tools/recovery-prompt-contracts/check_shared_prompts.py)
- [tools/recovery-prompt-contracts/manifest.json](../../tools/recovery-prompt-contracts/manifest.json)
- [tools/recovery-prompt-contracts/protocol.json](../../tools/recovery-prompt-contracts/protocol.json)
- [tools/recovery-prompt-contracts/validation-fixtures.json](../../tools/recovery-prompt-contracts/validation-fixtures.json)

## [tools/independent-wide-timetable/test_dense_generator.py](../../tools/independent-wide-timetable/test_dense_generator.py)

- `test_same_invented_literal_oracle_without_changing_frozen_main`（宣言行 14）
- `test_new_closed_grid_fits_compact_page_with_whole_17_class_coverage`（宣言行 22）

## [tools/independent-wide-timetable/test_generator.py](../../tools/independent-wide-timetable/test_generator.py)

- `test_all_680_slots_are_unique_and_merged_values_repeat_without_new_lessons`（宣言行 19）
- `test_frozen_independent_oracle_matches_design_and_contains_only_fake_values`（宣言行 28）
- `test_design_includes_distinct_merges_parallel_and_blank_semantics`（宣言行 38）
- `test_public_class_contract_snapshot_matches_real_ios_source_definition`（宣言行 47）

## [tools/recovery-prompt-contracts/test_shared_prompts.py](../../tools/recovery-prompt-contracts/test_shared_prompts.py)

- `test_original_bytes_and_thirty_strict_boundaries`（宣言行 15）
- `test_manifest_cannot_reapprove_changed_text_or_relabel_copy`（宣言行 18）
- `test_archived_reference_is_exact_but_not_new_request`（宣言行 30）
- `test_new_production_contract_loads_same_bytes_without_alternative_validator`（宣言行 37）
- `test_full_head_envelope_preserves_all_ids_and_untrusted_data`（宣言行 44）
- `test_copy_keeps_full_enum_requires_known_order_and_does_not_prove_empty`（宣言行 55）
- `test_bounds_unknown_tasks_and_no_order_repair`（宣言行 66）
