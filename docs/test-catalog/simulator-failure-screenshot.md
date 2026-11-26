# シミュレーター失敗時の画面記録

対応関係・宣言名・実行方法のSHA-256：
`a6d2b7c642c2ae5176d902e8d416748ec5046495a83d5745e801b9089dd3934d`

環境：macOS Simulator。Linuxは架空コマンドによる撮影・削除順とログの検査

```bash
python3 -B -m unittest discover -s tests -p test_simulator_failure_screenshot.py
```

## 変更時に確認するソース

- [tools/simulator_failure_screenshot.py](../../tools/simulator_failure_screenshot.py)

## [tests/test_simulator_failure_screenshot.py](../../tests/test_simulator_failure_screenshot.py)

- `test_fallback_skips_a_complete_native_capture_and_keeps_once_limit`
- `test_signal_exit_does_not_wait_for_screenshot_before_cleanup`
- `test_capture_exact_device_once_with_checksummed_image_and_owned_cleanup`
- `test_rejects_device_alias_command_failure_and_invalid_image`
- `test_normalizes_unusable_native_output_to_a_bounded_png`

## [tests/test_application_ui_runner.py](../../tests/test_application_ui_runner.py)

- `test_actual_shutdown_helper_only_accepts_verified_target_state_after_exit_149`
- `test_diagnosis_defaults_to_27_without_adding_26_matrix_rows`
- `test_alternate_toolchain_preflight_requires_requested_sdk_and_same_runtime`
- `test_optional_hang_observer_preserves_phase_results_and_owned_cleanup`
- `test_input_probe_runs_each_original_case_once_on_the_same_owned_device`
- `test_year_input_probe_keeps_preceding_case_and_reads_keyboard_settings_without_writes`
- `test_successful_notification_probe_observes_os_before_deleting_simulator`
- `test_headless_runner_keeps_all_selected_ui_cases_and_actual_size_commands`
- `test_passing_ui_completions_without_native_case_identities_fail_closed`
- `test_both_shards_on_both_os_preserve_selection_and_os_size_checks`
- `test_missing_xctest_completion_fails_shell_and_cleans_up`
- `test_failed_ui_build_does_not_boot_or_run_tests_and_still_cleans_up`
- `test_failed_frontend_launch_does_not_run_ui_and_cleans_owned_device`
- `test_missing_selected_xcode_frontend_fails_without_running_ui`
- `test_failed_owned_device_window_does_not_run_ui_and_cleans_up`
- `test_failed_or_duplicate_first_batch_stops_without_retry_or_size_checks`
- `test_failed_final_notification_batch_is_not_rescued_by_passed_scenarios`
- `test_failed_fresh_notification_device_boot_stops_and_cleans_both_devices`

## [tests/test_manual_ui_runner.py](../../tests/test_manual_ui_runner.py)

- `test_workflow_budget_includes_runtime_preparation_and_stops_before_ui_on_failure`
- `test_whole_suite_uses_one_successful_owned_build`
- `test_selected_case_uses_the_same_build_without_retesting_others`
- `test_shipping_27_uses_exact_27_0_when_newer_minor_is_available`
- `test_failed_build_never_starts_tests_or_becomes_success`
- `test_missing_completion_refuses_even_after_successful_build`
- `test_passing_completions_without_native_identities_are_rejected`

## [tests/test_picker_ui_runner.py](../../tests/test_picker_ui_runner.py)

- `test_picker_lease_typechecks_with_only_picker_dependencies`
- `test_preparation_order_exact_completions_failures_and_owned_cleanup`

## [tests/test_ocr_simulator_cancellation.py](../../tests/test_ocr_simulator_cancellation.py)

- `test_term_during_create_and_boot_removes_only_the_owned_device`
