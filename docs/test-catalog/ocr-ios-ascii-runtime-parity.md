# ASCII OCRのiOS 2入力・2出力CPU照合（研究）

対応関係・宣言名・実行方法のSHA-256：
`b52c48f8b16ee8963baf5248022839d0b4efcd5fe19b6a0d31d23db45570043f`

環境：iOS26／27 Simulatorのnative Swift前処理＋C API。iPhone SDKリンクと実機実行は別

```bash
bash tools/ocr-ios-ascii-runtime-parity/run.sh
python3 -B -m unittest discover -s tests -p 'test_ocr_ios*runtime_parity.py' -v
python3 -B -m unittest discover -s tests -p test_ocr_simulator_cancellation.py
python3 -B -m unittest discover -s tests -p test_workflow_source_paths.py
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

## [tests/test_ocr_simulator_cancellation.py](../../tests/test_ocr_simulator_cancellation.py)

- `test_term_during_create_and_boot_removes_only_the_owned_device`

## [tests/test_workflow_source_paths.py](../../tests/test_workflow_source_paths.py)

- `test_new_nested_code_starts_development_catalog_checks`
- `test_original_code_recognition_tracks_its_shared_implementations`
- `test_v6_parity_tracks_shared_input_preparation_and_numerical_runtime`
