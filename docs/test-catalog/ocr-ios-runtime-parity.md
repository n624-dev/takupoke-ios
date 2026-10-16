# iOS CPU Runtimeの原確率・CTC照合（研究）

対応関係・宣言名・実行方法のSHA-256：
`3cc5c1c216f19bf4e5e230c94594d7ad5d068618ba9bfb18c96a7c99b4fc1b4c`

環境：iOS26／27 Simulator実プロセス＋実iPhoneSDKリンク。物理iPhone・全文書採用は別確認

```bash
bash tools/ocr-ios-runtime-parity/run.sh
python3 -B -m unittest discover -s tests -p test_ocr_ios_runtime_parity.py -v
```

## 変更時に確認するソース

- [.github/workflows/ocr-ios-runtime-parity.yml](../../.github/workflows/ocr-ios-runtime-parity.yml)
- [tools/ocr-ios-runtime-parity/compare.py](../../tools/ocr-ios-runtime-parity/compare.py)
- [tools/ocr-ios-runtime-parity/prepare.py](../../tools/ocr-ios-runtime-parity/prepare.py)
- [tools/ocr-ios-runtime-parity/protocol.json](../../tools/ocr-ios-runtime-parity/protocol.json)
- [tools/ocr-ios-runtime-parity/rasterize.swift](../../tools/ocr-ios-runtime-parity/rasterize.swift)
- [tools/ocr-ios-runtime-parity/run.sh](../../tools/ocr-ios-runtime-parity/run.sh)
- [tools/ocr-ios-runtime-parity/runner.cpp](../../tools/ocr-ios-runtime-parity/runner.cpp)
- [tools/ocr-ios-runtime-parity/tensor-main.swift](../../tools/ocr-ios-runtime-parity/tensor-main.swift)
- [tools/ocr-ios-runtime-parity/tensor.swift](../../tools/ocr-ios-runtime-parity/tensor.swift)

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
