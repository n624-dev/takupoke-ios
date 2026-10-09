# IPA・AltStore・公開ゲート・ビルド・一時領域

対応ソース・テストのSHA-256：
`f8876349717da30d3f47805b121ca7ef647232fabaf6daf334bacc2f4cb0e76c`

環境：Linux Python／Apple iPhone SDK。AltStore導入は実機限定

```bash
python3 -B -m unittest discover -s tests -v
```

## 変更時に確認するソース

- [Package.swift](../../Package.swift)
- [Takupoke.xcodeproj/project.pbxproj](../../Takupoke.xcodeproj/project.pbxproj)
- [Takupoke.xcodeproj/project.xcworkspace/contents.xcworkspacedata](../../Takupoke.xcodeproj/project.xcworkspace/contents.xcworkspacedata)
- [tools/build-ios-app.sh](../../tools/build-ios-app.sh)
- [tools/build-ios.sh](../../tools/build-ios.sh)
- [tools/development_publish_dispatch.py](../../tools/development_publish_dispatch.py)
- [tools/development_release.py](../../tools/development_release.py)
- [tools/parallel_build.py](../../tools/parallel_build.py)
- [tools/prepare-coreai-runtime.py](../../tools/prepare-coreai-runtime.py)
- [tools/prepare-llama-runtime.py](../../tools/prepare-llama-runtime.py)
- [tools/publish.py](../../tools/publish.py)
- [tools/release.py](../../tools/release.py)
- [tools/release_gate.py](../../tools/release_gate.py)
- [tools/resolve-xcode-packages.sh](../../tools/resolve-xcode-packages.sh)
- [tools/timed_command.py](../../tools/timed_command.py)

## [tests/test_coreai_runtime_packaging.py](../../tests/test_coreai_runtime_packaging.py)

- `test_host_manifest_sdk_and_resources_survive_temporary_build`（宣言行 10）

## [tests/test_development_publish_dispatch.py](../../tests/test_development_publish_dispatch.py)

- `test_trusted_checkout_uses_prior_source_without_current_run_credit`（宣言行 33）
- `test_foreign_context_injected_inputs_and_current_run_are_refused`（宣言行 36）
- `test_prior_owned_stage_publishes_exact_three_and_records_cleanup_identity`（宣言行 54）
- `test_prior_failure_cannot_claim_current_success_or_record_ownership`（宣言行 70）
- `test_owned_id_change_refuses_upload_and_preserves_replacement`（宣言行 84）
- `test_changed_latest_or_main_is_reported_without_deleting_public_release`（宣言行 98）
- `test_upload_failure_records_prior_owned_id_and_preserves_other_draft`（宣言行 113）
- `test_workflow_publisher_is_independent_feature_only_without_build_or_artifact`（宣言行 127）

## [tests/test_development_release.py](../../tests/test_development_release.py)

- `test_exact_successful_run_including_device_build_is_required`（宣言行 29）
- `test_all_thirteen_checks_include_six_manual_cases_without_historical_pass_credit`（宣言行 36）
- `test_wrong_identity_attempt_or_skipped_failure_never_qualifies`（宣言行 52）
- `test_queued_aggregate_with_executing_exact_build_can_stage_but_never_publish`（宣言行 103）
- `test_staging_rejects_nonexecuting_foreign_or_duplicate_build_job`（宣言行 110）
- `test_staging_rejects_terminal_run_wrong_attempt_or_wrong_job_key`（宣言行 126）
- `test_queued_aggregate_stages_privately_and_refused_build_never_creates_draft`（宣言行 135）
- `test_original_unsigned_device_metadata_and_bytes_are_inspected`（宣言行 151）
- `test_staging_is_private_exact_source_and_never_finalizes`（宣言行 165）
- `test_wrong_stage_context_and_collision_do_not_mutate_preexisting_release`（宣言行 178）
- `test_stage_failed_upload_cleans_only_recorded_owned_draft`（宣言行 188）
- `test_each_other_job_failure_keeps_draft_private_and_blocks_prepare`（宣言行 199）
- `test_cleanup_refuses_foreign_body_source_attempt_or_published_release`（宣言行 212）
- `test_tampered_asset_or_foreign_inventory_never_prepares`（宣言行 224）
- `test_prepare_rerun_during_download_preserves_caller_directory`（宣言行 237）
- `test_completed_thirteen_prepare_and_finalize_same_owned_three_assets_with_public_readback`（宣言行 247）
- `test_final_upload_failure_or_gate_change_deletes_only_owned_private_draft`（宣言行 267）
- `test_workflow_has_no_artifacts_and_write_scope_is_feature_dispatch_only`（宣言行 282）
- `test_conditionally_skipped_nonfeature_build_has_distinct_name_not_duplicate_credit`（宣言行 299）

## [tests/test_distribution.py](../../tests/test_distribution.py)

- `test_source_matches_ipa_and_immutable_download`（宣言行 65）
- `test_notes_are_snapshotted_and_must_match_source`（宣言行 77）
- `test_missing_or_empty_notes_stop_generation`（宣言行 88）
- `test_metadata_mismatches_fail_before_source_generation`（宣言行 98）
- `test_undeclared_permissions_and_profiles_fail`（宣言行 116）
- `test_public_release_excludes_diagnostics_and_requires_bundled_policies`（宣言行 126）
- `test_modified_ipa_and_source_fail_validation`（宣言行 135）
- `test_unexpected_release_files_are_rejected`（宣言行 153）
- `test_versions_increment_on_push_and_retry`（宣言行 159）
- `test_previous_versions_cannot_replace_newer_release`（宣言行 167）
- `test_publish_only_after_uploaded_bytes_match`（宣言行 284）
- `test_unpublished_draft_is_verified_by_id_not_tag`（宣言行 290）
- `test_new_draft_is_not_rediscovered_through_stale_listing`（宣言行 297）
- `test_missing_draft_stops_before_publication`（宣言行 304）
- `test_unexpected_draft_is_not_modified`（宣言行 311）
- `test_incomplete_assets_stop_publication`（宣言行 321）
- `test_asset_download_failure_stops_publication`（宣言行 331）
- `test_binary_download_preserves_bytes`（宣言行 338）
- `test_upload_failure_does_not_publish`（宣言行 348）
- `test_corrupt_uploaded_asset_does_not_publish`（宣言行 355）
- `test_stale_main_does_not_create_release`（宣言行 362）
- `test_main_changing_during_upload_leaves_draft`（宣言行 368）
- `test_pull_requests_cannot_publish`（宣言行 374）
- `test_existing_draft_can_be_retried_without_replacing_public_release`（宣言行 381）
- `test_older_retry_does_not_overwrite_latest`（宣言行 391）
- `test_cannot_read_previous_release_fails_closed`（宣言行 398）
- `test_new_version_can_follow_previous_release`（宣言行 406）

## [tests/test_github_api_response.py](../../tests/test_github_api_response.py)

- `test_successful_empty_delete_does_not_fail_after_remote_mutation`（宣言行 14）
- `test_empty_json_reads_and_writes_are_still_rejected`（宣言行 21）
- `test_failed_delete_propagates_and_valid_json_is_parsed`（宣言行 28）

## [tests/test_parallel_build.py](../../tests/test_parallel_build.py)

- `test_child_logs_keep_their_labels`（宣言行 17）
- `test_both_commands_start_before_either_finishes`（宣言行 28）
- `test_failure_stops_peer_and_propagates_status`（宣言行 47）

## [tests/test_release_gate.py](../../tests/test_release_gate.py)

- `test_all_required_jobs_succeed_while_release_itself_is_running`（宣言行 26）
- `test_all_six_manual_checks_reject_borrowed_source_or_attempt`（宣言行 30）
- `test_missing_and_running_jobs_wait`（宣言行 39）
- `test_each_required_job_is_individually_required`（宣言行 44）
- `test_unsuccessful_completion_is_never_accepted`（宣言行 54）
- `test_run_commit_attempt_branch_repository_and_event_are_checked`（宣言行 61）
- `test_job_metadata_must_match_the_same_attempt_and_commit`（宣言行 70）
- `test_duplicate_job_is_rejected`（宣言行 77）
- `test_manual_main_run_is_allowed`（宣言行 82）
- `test_polling_uses_attempt_jobs_and_all_pages_until_success`（宣言行 86）
- `test_missing_job_times_out_with_bounded_wait`（宣言行 106）
- `test_api_failure_aborts_instead_of_allowing_publication`（宣言行 116）
- `test_cli_rejects_untrusted_context_without_api_calls`（宣言行 122）

## [tests/test_timed_command.py](../../tests/test_timed_command.py)

- `test_exited_leader_does_not_leave_term_ignoring_descendant_running`（宣言行 16）
- `test_child_output_and_exit_status_are_preserved`（宣言行 47）
- `test_cancellation_reaches_child_and_allows_its_cleanup`（宣言行 57）

## [tests/test_xcode_package_resolution.py](../../tests/test_xcode_package_resolution.py)

- `test_transient_dependency_failure_is_bounded_and_can_recover`（宣言行 53）
- `test_exhausted_resolution_preserves_failure_status`（宣言行 60）
- `test_cancellation_status_is_never_retried`（宣言行 65）
