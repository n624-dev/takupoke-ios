# Windows OCR候補のApple原画素比較（認識器の研究）

対応関係・宣言名・実行方法のSHA-256：
`4f3157c2b4da46f4c4abb5e9d3bff9db5070887ab8fc316d405b729c394a4cd7`

環境：Apple macOS26／配布SDK27。iPhone・文書全体・採用合格は対象外

```bash
bash tools/ocr-windows-transfer/run.sh
python3 -B -m unittest discover -s tests -p test_ocr_windows_transfer.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-windows-transfer-screen.yml](../../.github/workflows/ocr-windows-transfer-screen.yml)
- [tools/ocr-windows-transfer/compare.py](../../tools/ocr-windows-transfer/compare.py)
- [tools/ocr-windows-transfer/frames.py](../../tools/ocr-windows-transfer/frames.py)
- [tools/ocr-windows-transfer/infer.py](../../tools/ocr-windows-transfer/infer.py)
- [tools/ocr-windows-transfer/prepare.py](../../tools/ocr-windows-transfer/prepare.py)
- [tools/ocr-windows-transfer/protocol.json](../../tools/ocr-windows-transfer/protocol.json)
- [tools/ocr-windows-transfer/requirements.txt](../../tools/ocr-windows-transfer/requirements.txt)
- [tools/ocr-windows-transfer/run.sh](../../tools/ocr-windows-transfer/run.sh)
- [tools/ocr-windows-transfer/vision.swift](../../tools/ocr-windows-transfer/vision.swift)

## [tests/test_ocr_windows_transfer.py](../../tests/test_ocr_windows_transfer.py)

- `test_native_top_one_cannot_be_replaced_by_correct_high_score_alternate`
- `test_missing_split_and_outside_remain_unassigned_without_joining_or_clamping`
- `test_raw_unicode_spaces_and_confusable_codes_stay_different`
- `test_pinned_artifact_mismatch_cannot_create_output`
- `test_existing_wrong_artifact_is_rejected_without_network_or_repair`
- `test_independent_design_cannot_substitute_an_unsupported_glyph`
- `test_transform_keeps_b_g_r_and_normalized_zero_padding`
- `test_c_t_c_blank_separates_repeated_tokens_and_all_scores_are_validated`
- `test_ink_frame_uses_all_observed_ink_even_when_it_is_distant_from_main_text`
