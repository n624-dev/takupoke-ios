# 確認訂正・画像比較・入力変更・実操作

対応関係・宣言名・実行方法のSHA-256：
`5a65cb3476d1435ddb5f5832142b34485c33f11b5231d1236232e9b494faf36d`

環境：Apple iOS26/27＋Linux契約検査。実機・モデル品質は別確認

```bash
bash tools/test-manual-ui.sh
```

## 変更時に確認するソース

- [.github/workflows/manual-input-native-probe.yml](../../.github/workflows/manual-input-native-probe.yml)
- [Takupoke/PDFRecoveryView.swift](../../Takupoke/PDFRecoveryView.swift)
- [Takupoke/RecoveryManualAssistance.swift](../../Takupoke/RecoveryManualAssistance.swift)
- [Takupoke/RecoveryManualReview.swift](../../Takupoke/RecoveryManualReview.swift)
- [tests/ui/ManualAssistanceFixture.swift](../../tests/ui/ManualAssistanceFixture.swift)
- [tools/manual_ui_diagnostics.py](../../tools/manual_ui_diagnostics.py)
- [tools/manual_ui_project.py](../../tools/manual_ui_project.py)
- [tools/test-manual-ui.sh](../../tools/test-manual-ui.sh)
- [tests/ui/ManualAssistanceChecks.swift](../../tests/ui/ManualAssistanceChecks.swift)
- [tests/ui/ManualAssistanceGeometry.swift](../../tests/ui/ManualAssistanceGeometry.swift)
- [tests/ui/ManualAssistanceChecks+Navigation.swift](../../tests/ui/ManualAssistanceChecks+Navigation.swift)
- [tests/ui/ManualAssistanceChecks+Review.swift](../../tests/ui/ManualAssistanceChecks+Review.swift)
- [tests/ui/ManualAssistanceChecks+Input.swift](../../tests/ui/ManualAssistanceChecks+Input.swift)
- [tests/ui/ManualAssistanceChecks+Lifecycle.swift](../../tests/ui/ManualAssistanceChecks+Lifecycle.swift)
- [tests/ui/ManualAssistanceChecks+OneCorrection.swift](../../tests/ui/ManualAssistanceChecks+OneCorrection.swift)

## [tests/RecoveryManualAssistanceTests.swift](../../tests/RecoveryManualAssistanceTests.swift)

- `testBodyLineAtomsKeepEveryRawSpaceAndRealBoxThroughThreeManualFields`
- `testVersionSevenManualAtomsRetainConsentThroughSnapshotMigration`
- `testHighConfidenceLineAtomStillRequiresWholeLiteralAndUniqueBodyOwner`
- `testWholeLineRangeCrossingRolesFailsEvenWithAllInkCharactersInsideCell`
- `testLineAtomCannotBeSelectedAcrossPhysicalCellOrUsedAsHeading`
- `testCommonBodyProofKeepsIndependentNativeBoxesWithoutExpandingAnyRange`
- `testOneNativeCharacterAcrossCellRoleOrSharedBoundaryRefusesWholeAtom`
- `testCandidateRangeOtherRoleAndMissingOrDuplicateAtomReceiptRefuse`
- `testMissingVerifiedRoleScopeCannotUsePhysicalCellProofAlone`
- `testStandaloneBuilderAtomCannotEscapeWithoutNativeCapture`
- `testManualInputIdenticalRebindPreservesThreeIndividualAcknowledgements`
- `testManualInputRawUnicodeChangeRequiresNewAcknowledgement`
- `testManualOneTwoThreeFieldsReachFormalConversionWithSeparateHumanProvenance`
- `testManualFourthFieldAndAnyHeaderUncertaintyAreTerminal`
- `testExplicitHighConfidenceBodySelectionPreservesNativeCaptureAndLegacyDefault`
- `testCorrectionMenuEligibilityUsesEachFieldsOCRSources`
- `testExplicitSelectionRetainsAllMandatoryFieldsAndThreeFieldUnionLimit`
- `testSelectedCorrectionUsesOnlyHashMatchedOriginalRasterAndNativeCapture`
- `testExplicitHighConfidenceSelectionStillRefusesUnownedOrAlteredNativeCharacters`
- `testManualPendingRawLowConfidenceCannotBeAdoptedWithoutCorrections`
- `testManualPrintedFieldCannotBecomeBlankOrPartialOverlay`
- `testManualEverySourceHashSnapshotParentCropAndTargetIsBound`
- `testManualIncompleteCaptureAndMissingCoverageCannotOfferItems`
- `testManualCancellationPropagatesBeforeDraftOrOverlay`
- `testManualCorrectedUTF16BoundAndExplicitTimestampAreEnforced`
- `testManualFullFieldParentsPreserveOriginalOrderAndNativeConfidence`
- `testManualEverySourceRequiresExactNativePageOrderAndConfidenceMembership`
- `testVersionSixNativeAndManualAuditsKeepExactConfirmationOnlyAfterCurrentProof`
- `testAtomContractCannotBeBackdatedToVersionSixOrLoseKnownVersionGuard`
- `testVersionSevenNativeAtomReceiptRetainsConfirmationAfterRevalidation`
- `testOptionalManualReceiptAbsencePreservesHistoricalJSON`

## [tests/RecoveryManualReviewTests.swift](../../tests/RecoveryManualReviewTests.swift)

- `testChangedLiteralShowsBothSidesWithoutAssigningParallelRoles`
- `testParallelOrderDoesNotInventAChangeAndMultiplicityRemainsVisible`
- `testWhitespaceAndUnicodeBytesAreComparedLiterally`
- `testTeacherRoomSpanAndTimeChangesAreVisible`
- `testExplicitBlankCanCompareButMissingPreviousCellCannot`
- `testDifferentYearTermKindAndMissingPreviousAreUnavailable`
- `testDifferentClassDayOrPeriodCannotBeGuessed`
- `testDuplicateScopeSlotsAndUndeclaredEntriesCannotCompare`
- `testPixelHighlightPreservesOriginAndFractionalBounds`
- `testHighlightRejectsOutsideNonfiniteAndDegenerateGeometry`

## [tests/test_manual_input_lifecycle.py](../../tests/test_manual_input_lifecycle.py)

- `test_actual_activation_does_not_resume_source_checks_after_backgrounding_during_awaits`
- `test_actual_background_methods_preserve_idle_draft_and_cancel_heavy_work`
- `test_actual_field_callbacks_reject_replaced_missing_and_reviewed_drafts`
- `test_retention_route_keeps_explicit_draft_cancellation`

## [tests/test_manual_review_controls.py](../../tests/test_manual_review_controls.py)

- `test_actual_review_readiness_requires_one_coherent_state_with_original_deadline`
- `test_actual_xctest_comparison_and_pixel_geometry`

## [tests/test_manual_scroll_navigation.py](../../tests/test_manual_scroll_navigation.py)

- `test_actual_navigation_state_on_offscreen_virtualized_and_keyboard_frames`
- `test_qa_only_owner_resolution_and_existing_caps_are_preserved`

## [tests/test_manual_ui_diagnostics.py](../../tests/test_manual_ui_diagnostics.py)

- `test_owned_launch_trace_exports_only_fixed_stages_and_rejects_unknown_content`
- `test_owned_input_trace_is_bounded_and_rejects_body_symlinks_and_invalid_encoding`
- `test_command_timeout_and_output_cap_are_explicit`
- `test_sigterm_reaps_owned_command_and_keeps_signal_exit`
- `test_crash_capture_filters_exact_app_time_size_and_symlinks`
- `test_crash_identity_rejects_prefix_helper_and_arbitrary_mentions`
- `test_jetsam_exports_only_exact_app_entry`
- `test_legacy_crash_requires_exact_identity_lines`
- `test_legacy_failure_excludes_attachment_payloads`
- `test_always_collection_retains_original_exit_when_tools_fail`
- `test_collection_tool_errors_stay_unknown_no_binary_payload`
- `test_assertions_completion_guard_and_result_bundle_remain`

## [tests/test_manual_ui_project.py](../../tests/test_manual_ui_project.py)

- `test_missing_or_duplicate_anchor_fails_closed`
- `test_binding_diagnostics_are_opt_in_hashed_and_explicitly_truncated`
- `test_editor_uses_physical_clear_and_checks_full_replacement`
- `test_manual_case_filter_is_exact_and_default_keeps_whole_suite`
- `test_completion_guard_rejects_missing_duplicate_skipped_failed_or_other_case`
- `test_coordinator_preserves_actual_submit_adopt_and_source_guards`
- `test_view_identifiers_do_not_precheck_or_bypass_existing_disabled_gate`
- `test_review_readiness_measures_actual_coordinator_state`
- `test_comparable_prior_defers_actual_builder_until_qa_window_exists`
- `test_review_uses_production_japan_timestamp_without_device_timezone`
- `test_existing_app_generator_raster_anchor_matches_current_acquisition`
- `test_generated_host_preserves_production_background_task_registration`
- `test_fixture_dimensions_respect_native_capture_limit_and_uniform_rule_scale`
- `test_actual_qa_failure_stage_and_bitmap_extent_are_observable_in_accessibility_tree`
- `test_raster_ab_preserves_old_rendering_and_uses_same_physical_predicate`
- `test_fixture_uses_current_period_and_actual_builder_proof`
- `test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps`

## [tests/ui/ManualAssistanceChecks+Cases.swift](../../tests/ui/ManualAssistanceChecks+Cases.swift)

- `testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`
- `testChangedOriginalCannotSubmitOrReplaceLastGood`
- `testThreeFieldsRequireEachAcknowledgementAndFourRefuses`
- `testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch`

## [tests/test_manual_ui_runner.py](../../tests/test_manual_ui_runner.py)

- `test_workflow_budget_includes_runtime_preparation_and_stops_before_ui_on_failure`
- `test_whole_suite_uses_one_successful_owned_build`
- `test_selected_case_uses_the_same_build_without_retesting_others`
- `test_shipping_27_uses_exact_27_0_when_newer_minor_is_available`
- `test_failed_build_never_starts_tests_or_becomes_success`
- `test_missing_completion_refuses_even_after_successful_build`
- `test_passing_completions_without_native_identities_are_rejected`

## [tests/RecoveryFunctionalCoverageTests.swift](../../tests/RecoveryFunctionalCoverageTests.swift)

- `testFunctionalUnlabeledTeacherAndRoomBlanksReachFormalConversionWithoutShifting`
- `testFunctionalMergedUnlabeledParallelTuplesRetainSeparatorAndEveryFormalSlot`
- `testFunctionalExamMergedClockAndBlankRolesReachFormalConversion`
- `testFunctionalReturnSplitParallelBlankRoomAndMergedNormalClockReachFormalConversion`
- `testFunctionalSpecialHeaderEvidenceCannotBeRemovedOrBorrowedForConversion`
- `testFunctionalReturnClassRowMustHaveCompletePhysicalBoundarySupport`
- `testFunctionalReturnClassRowIncludesBoundaryAtPeriodHeaderBottom`
- `testSpecialMarkedRawSubjectMovesAcrossStrictAndValidatedRecoveryProjections`
- `testMigratedStrictLessonsStillCompareAtTheirOriginalPDFCells`

## [tests/test_simulator_frontend.py](../../tests/test_simulator_frontend.py)

- `test_selected_xcode_frontends_and_owned_window_preserve_boot_order`
- `test_boot_frontend_window_errors_fail_without_retry`
- `test_headless_bootstatus_is_not_reported_as_completed_ui_execution`

## [tests/test_ui_execution_identity.py](../../tests/test_ui_execution_identity.py)

- `test_every_selected_case_requires_one_actual_owned_runner_identity`
- `test_missing_duplicated_foreign_host_and_malformed_proofs_fail_closed`
- `test_real_swift_identity_cannot_certify_a_host_process_as_a_simulator`

## [tests/test_notification_service_trace.py](../../tests/test_notification_service_trace.py)

- `test_shutdown_confirmation_requires_exact_owned_runtime_and_one_stopped_device`
- `test_runtime_health_filters_owned_device_and_bounds_failed_observations`
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
