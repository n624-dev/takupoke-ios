# ASCII OCRのiOS 2入力・2出力CPU照合（研究）

対応関係・宣言名・実行方法のSHA-256：
`f4d3e01fa5366cdbb42ea39765864af3f126d3a0b50ca282f00f695a5cf019cb`

環境：iOS26／27 Simulatorのnative Swift前処理＋C API。iPhone SDKリンクと実機実行は別

```bash
bash tools/ocr-ios-ascii-runtime-parity/run.sh
python3 -B -m unittest discover -s tests -p 'test_ocr_ios*runtime_parity.py' -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-ios-ascii-runtime-parity.yml](../../.github/workflows/ocr-ios-ascii-runtime-parity.yml)
- [tools/ocr-ios-ascii-runtime-parity/compare.py](../../tools/ocr-ios-ascii-runtime-parity/compare.py)
- [tools/ocr-ios-ascii-runtime-parity/prepare.py](../../tools/ocr-ios-ascii-runtime-parity/prepare.py)
- [tools/ocr-ios-ascii-runtime-parity/protocol.json](../../tools/ocr-ios-ascii-runtime-parity/protocol.json)
- [tools/ocr-ios-ascii-runtime-parity/run.sh](../../tools/ocr-ios-ascii-runtime-parity/run.sh)
- [tools/ocr-ios-ascii-runtime-parity/runner.cpp](../../tools/ocr-ios-ascii-runtime-parity/runner.cpp)

## [tests/test_ocr_ios_ascii_runtime_parity.py](../../tests/test_ocr_ios_ascii_runtime_parity.py)

- `test_inference_identity_requires_its_own_udid_pid_and_ios_simulator_target`
- `test_reject_output_has_its_own_probability_tolerance`
- `test_reject_threshold_crossing_fails_inside_numeric_tolerance`
- `test_reject_probability_requires_exact_shape_finite_unit_domain`
- `test_identical_reject_output_retains_both_decisions`
- `test_actual_native_width_must_match_both_value_and_int64_bytes`
- `test_same_greedy_text_cannot_hide_changed_ascii_nonwinning_probability`

## [tests/test_ocr_ios_runtime_parity.py](../../tests/test_ocr_ios_runtime_parity.py)

- `test_full_probability_drift_rejects_even_when_greedy_text_is_unchanged`
- `test_crossing_selected_piece_floor_rejects_within_numeric_tolerance`
- `test_identical_native_probabilities_keep_spaces_and_ctc_intervals`
- `test_losing_nan_is_rejected_instead_of_ignored`
- `test_framework_archive_cannot_escape_the_owned_slice`
- `test_owned_simulator_delete_still_runs_after_shutdown_timeout`
- `test_failed_owned_delete_is_not_counted_as_clean_success`
- `test_shutdown_nonzero_does_not_replace_successful_owned_delete`
- `test_selected_xcode_frontend_preserves_bootstatus_and_owned_device`
- `test_missing_frontend_fails_before_boot_instead_of_substituting_xcode`
- `test_native_transform_claim_cannot_hide_different_tensor_bytes`
- `test_native_transform_requires_inventory_and_actual_widths`
- `test_native_process_identity_rejects_another_device_or_host_os`
