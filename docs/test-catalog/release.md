# IPA・AltStore・公開ゲート・ビルド・一時領域

対応関係・宣言名・実行方法のSHA-256：
`060c93785c6ac251cf955b74c27c631492d834a1878e245032e70b1b470a94a4`

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

- `test_host_manifest_sdk_and_resources_survive_temporary_build`

## [tests/test_development_publish_dispatch.py](../../tests/test_development_publish_dispatch.py)

- `test_trusted_checkout_uses_prior_source_without_current_run_credit`
- `test_foreign_context_injected_inputs_and_current_run_are_refused`
- `test_prior_owned_stage_publishes_exact_three_and_records_cleanup_identity`
- `test_prior_failure_cannot_claim_current_success_or_record_ownership`
- `test_owned_id_change_refuses_upload_and_preserves_replacement`
- `test_changed_latest_or_main_is_reported_without_deleting_public_release`
- `test_upload_failure_records_prior_owned_id_and_preserves_other_draft`
- `test_workflow_publisher_is_independent_feature_only_without_build_or_artifact`

## [tests/test_development_release.py](../../tests/test_development_release.py)

- `test_exact_successful_run_including_device_build_is_required`
- `test_all_thirteen_checks_include_six_manual_cases_without_historical_pass_credit`
- `test_wrong_identity_attempt_or_skipped_failure_never_qualifies`
- `test_queued_aggregate_with_executing_exact_build_can_stage_but_never_publish`
- `test_staging_rejects_nonexecuting_foreign_or_duplicate_build_job`
- `test_staging_rejects_terminal_run_wrong_attempt_or_wrong_job_key`
- `test_queued_aggregate_stages_privately_and_refused_build_never_creates_draft`
- `test_original_unsigned_device_metadata_and_bytes_are_inspected`
- `test_staging_is_private_exact_source_and_never_finalizes`
- `test_wrong_stage_context_and_collision_do_not_mutate_preexisting_release`
- `test_stage_failed_upload_cleans_only_recorded_owned_draft`
- `test_each_other_job_failure_keeps_draft_private_and_blocks_prepare`
- `test_cleanup_refuses_foreign_body_source_attempt_or_published_release`
- `test_tampered_asset_or_foreign_inventory_never_prepares`
- `test_prepare_rerun_during_download_preserves_caller_directory`
- `test_completed_thirteen_prepare_and_finalize_same_owned_three_assets_with_public_readback`
- `test_final_upload_failure_or_gate_change_deletes_only_owned_private_draft`
- `test_workflow_has_no_artifacts_and_write_scope_is_feature_dispatch_only`
- `test_conditionally_skipped_nonfeature_build_has_distinct_name_not_duplicate_credit`

## [tests/test_distribution.py](../../tests/test_distribution.py)

- `test_source_matches_ipa_and_immutable_download`
- `test_notes_are_snapshotted_and_must_match_source`
- `test_missing_or_empty_notes_stop_generation`
- `test_metadata_mismatches_fail_before_source_generation`
- `test_undeclared_permissions_and_profiles_fail`
- `test_public_release_excludes_diagnostics_and_requires_bundled_policies`
- `test_modified_ipa_and_source_fail_validation`
- `test_unexpected_release_files_are_rejected`
- `test_versions_increment_on_push_and_retry`
- `test_previous_versions_cannot_replace_newer_release`
- `test_publish_only_after_uploaded_bytes_match`
- `test_unpublished_draft_is_verified_by_id_not_tag`
- `test_new_draft_is_not_rediscovered_through_stale_listing`
- `test_missing_draft_stops_before_publication`
- `test_unexpected_draft_is_not_modified`
- `test_incomplete_assets_stop_publication`
- `test_asset_download_failure_stops_publication`
- `test_binary_download_preserves_bytes`
- `test_upload_failure_does_not_publish`
- `test_corrupt_uploaded_asset_does_not_publish`
- `test_stale_main_does_not_create_release`
- `test_main_changing_during_upload_leaves_draft`
- `test_pull_requests_cannot_publish`
- `test_existing_draft_can_be_retried_without_replacing_public_release`
- `test_older_retry_does_not_overwrite_latest`
- `test_cannot_read_previous_release_fails_closed`
- `test_new_version_can_follow_previous_release`

## [tests/test_github_api_response.py](../../tests/test_github_api_response.py)

- `test_successful_empty_delete_does_not_fail_after_remote_mutation`
- `test_empty_json_reads_and_writes_are_still_rejected`
- `test_failed_delete_propagates_and_valid_json_is_parsed`

## [tests/test_parallel_build.py](../../tests/test_parallel_build.py)

- `test_child_logs_keep_their_labels`
- `test_both_commands_start_before_either_finishes`
- `test_failure_stops_peer_and_propagates_status`

## [tests/test_release_gate.py](../../tests/test_release_gate.py)

- `test_all_required_jobs_succeed_while_release_itself_is_running`
- `test_all_six_manual_checks_reject_borrowed_source_or_attempt`
- `test_missing_and_running_jobs_wait`
- `test_each_required_job_is_individually_required`
- `test_unsuccessful_completion_is_never_accepted`
- `test_run_commit_attempt_branch_repository_and_event_are_checked`
- `test_job_metadata_must_match_the_same_attempt_and_commit`
- `test_duplicate_job_is_rejected`
- `test_manual_main_run_is_allowed`
- `test_polling_uses_attempt_jobs_and_all_pages_until_success`
- `test_missing_job_times_out_with_bounded_wait`
- `test_api_failure_aborts_instead_of_allowing_publication`
- `test_cli_rejects_untrusted_context_without_api_calls`

## [tests/test_timed_command.py](../../tests/test_timed_command.py)

- `test_exited_leader_does_not_leave_term_ignoring_descendant_running`
- `test_child_output_and_exit_status_are_preserved`
- `test_cancellation_reaches_child_and_allows_its_cleanup`

## [tests/test_xcode_package_resolution.py](../../tests/test_xcode_package_resolution.py)

- `test_transient_dependency_failure_is_bounded_and_can_recover`
- `test_exhausted_resolution_preserves_failure_status`
- `test_cancellation_status_is_never_retried`

## [tests/ObservedScreenGeometryTests.swift](../../tests/ObservedScreenGeometryTests.swift)

- `testObservedEqualPhysicalEdgesSurviveFloatingPointArithmetic`
- `testPhysicalAndFractionalPixelClippingIsStillRejectedOnEveryEdge`
- `testEmptyNonFiniteAndInvalidScaleDoNotBecomeVisible`
