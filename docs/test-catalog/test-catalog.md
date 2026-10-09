# テスト一覧・対象検索・宣言整合性・CI接続

対応関係・宣言名・実行方法のSHA-256：
`9d4c20d00560d75a202e5435951d76d095f10ad752d1f84c82daec41ace1c234`

環境：Linux Python（隔離Gitリポジトリ）

```bash
python3 -B -m unittest discover -s tests -p test_test_catalog.py -v
python3 -B -m unittest discover -s tests -p test_ui_test_manifest.py -v
```

## 変更時に確認するソース

- [.github/workflows/ios-release.yml](../../.github/workflows/ios-release.yml)
- [tests/test-catalog.json](../../tests/test-catalog.json)
- [tools/test_catalog.py](../../tools/test_catalog.py)
- [tools/test_catalog_inventory.py](../../tools/test_catalog_inventory.py)
- [.github/workflows/test-tools.yml](../../.github/workflows/test-tools.yml)

## [tests/test_test_catalog.py](../../tests/test_test_catalog.py)

- `test_changed_runtime_reports_existing_tests_without_forcing_edits`
- `test_body_comments_and_line_changes_do_not_make_the_index_stale`
- `test_new_source_without_mapping_is_rejected`
- `test_unregistered_test_and_missing_registered_file_are_rejected`
- `test_deleting_a_registered_test_is_still_rejected`
- `test_document_only_changes_do_not_require_test_edits`
- `test_renamed_source_reports_corresponding_tests_without_test_edits`
- `test_new_corresponding_case_file_can_qualify_existing_runtime_changes`
- `test_stale_or_obsolete_generated_documents_are_rejected`
- `test_integration_case_can_cover_two_sources_without_duplicate_source_ownership`
- `test_search_finds_case_and_source_names`
- `test_inventory_distinguishes_declarations_from_theory_expansions`
- `test_renamed_case_and_changed_execution_command_require_index_update`
- `test_workflow_enforces_changed_code_against_event_base`

## [tests/test_ui_test_manifest.py](../../tests/test_ui_test_manifest.py)

- `test_split_sources_are_registered_in_the_selected_target_only`
- `test_unregistered_split_file_is_rejected`
- `test_manual_split_registers_all_helpers_and_refuses_unknown_files`
- `test_network_rewrite_preserves_standard_xlsx_identifiers_only`
- `test_ai_switch_probe_preserves_production_setter_and_rejects_marker_drift`
- `test_notification_switch_trace_preserves_setters_and_rejects_marker_drift`
- `test_notification_readiness_probe_observes_os_without_granting_or_saving`
- `test_owned_launch_trace_filters_other_content_and_refuses_symlinks_and_large_files`
- `test_picker_completion_rejects_missing_failed_skipped_duplicate_and_unknown_cases`
- `test_event_cache_probe_changes_only_automatic_startup_in_isolated_copy`
- `test_native_ocr_probe_preserves_actual_multiline_confidence_guard`
- `test_all_source_tests_are_assigned_once_and_both_os_checks_are_required`
- `test_missing_obsolete_or_duplicate_source_tests_fail`
- `test_overlapping_manifest_is_rejected`
- `test_passed_results_with_only_the_declared_voiceover_exception`
- `test_empty_missing_extra_and_duplicate_results_fail`
- `test_failure_and_unexpected_skip_fail`
- `test_workflow_matrix_matches_gate_and_publish_follows_gate`
- `test_manual_matrix_requires_every_unchanged_case_on_both_os_separately`
- `test_cli_selects_the_complete_shard_and_rejects_invalid_shard`
- `test_cli_reads_japanese_source_with_non_utf8_default_encoding`
- `test_relaunch_diagnosis_cannot_replace_the_full_shard_gate`
- `test_single_diagnostic_case_requires_exact_completion_and_cannot_select_full_shards`
- `test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs`
- `test_both_shards_on_both_os_preserve_selection_and_os_size_checks`
- `test_missing_xctest_completion_fails_shell_and_cleans_up`
