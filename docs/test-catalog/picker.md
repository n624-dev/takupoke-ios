# ファイル選択・再選択・背景・キャンセル

対応関係・宣言名・実行方法のSHA-256：
`5aa97cdae8e1e3b18a59e13ccbeba29e777831389aba6eb7ca07965debee33d4`

環境：Apple iOS26/27 UI＋Nativeレイアウト

```bash
bash tools/test-picker-ui.sh
```

## 変更時に確認するソース

- [Takupoke/GuidedDocumentPicker.swift](../../Takupoke/GuidedDocumentPicker.swift)
- [Takupoke/MaterialDocumentPicker.swift](../../Takupoke/MaterialDocumentPicker.swift)
- [Takupoke/MaterialPickerLayout.swift](../../Takupoke/MaterialPickerLayout.swift)
- [tests/ui/MaterialPickerUIChecks.swift](../../tests/ui/MaterialPickerUIChecks.swift)
- [tests/ui/PickerTapHarness.swift](../../tests/ui/PickerTapHarness.swift)
- [tools/picker_test_project.py](../../tools/picker_test_project.py)
- [tools/test-picker-ui.sh](../../tools/test-picker-ui.sh)

## [tests/MaterialPickerLayoutTests.swift](../../tests/MaterialPickerLayoutTests.swift)

- `testInstructionNeverCoversPickerAtPhoneSizes`
- `testWrappedInstructionReservesMoreSpaceWithoutMovingBottomControls`

## [tests/ui/MaterialPickerTapChecks.swift](../../tests/ui/MaterialPickerTapChecks.swift)

- `testInstructionSurroundMatchesFilesBackground`
- `testReselectionWithMissingAppearanceReturn`
- `testReselectionThroughActualButtons`

## [tests/test_picker_ui_runner.py](../../tests/test_picker_ui_runner.py)

- `test_preparation_order_exact_completions_failures_and_owned_cleanup`

## [tests/test_simulator_frontend.py](../../tests/test_simulator_frontend.py)

- `test_selected_xcode_frontends_and_owned_window_are_ready_before_returning`
- `test_boot_frontend_window_and_readiness_errors_fail_without_another_boot`

## [tests/test_notification_service_trace.py](../../tests/test_notification_service_trace.py)

- `test_shutdown_confirmation_requires_exact_owned_runtime_and_one_stopped_device`
- `test_runtime_health_filters_owned_device_and_bounds_failed_observations`
- `test_boot_readiness_requires_one_actual_owned_native_identity_with_the_original_deadline`
- `test_boot_readiness_rejects_host_wrong_identity_bad_responses_and_failed_spawn_without_retry`
- `test_real_identity_program_cannot_prove_a_host_process_is_a_simulator`
- `test_boot_failure_observation_is_bounded_read_only_and_excludes_other_devices_and_private_fields`
- `test_launch_observation_keeps_nested_codes_without_private_error_details`
- `test_launch_error_codes_are_bounded_and_reject_unknown_domains_and_large_values`
- `test_accessibility_observation_has_only_known_services_and_fixed_words_in_order`
- `test_accessibility_failure_limits_do_not_emit_raw_text_or_mutate_os_state`
- `test_accessibility_service_report_rejects_oversized_health_output`
- `test_spooled_observation_bounds_real_stdout_stderr_and_keeps_exit_status`
- `test_notification_log_collection_bounds_memory_before_reporting_limit`
- `test_notification_evidence_survives_later_accessibility_noise_in_original_order`
- `test_notification_observation_failures_preserve_the_other_readonly_phases`
- `test_notification_window_uses_unanswered_request_even_when_failure_finishes_later`
- `test_notification_window_collects_only_bounded_owned_trace_and_request_interval`
- `test_notification_service_trace_keeps_only_known_processes_and_fixed_words`
- `test_notification_service_trace_is_bounded_without_permission_mutation`
