# 確認訂正・画像比較・入力変更・実操作

対応ソース・テストのSHA-256：
`6c887cd63440da5466f9dfcaa2054d95f31d288b379cdce371b7758f29b8224d`

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

## [tests/RecoveryManualAssistanceTests.swift](../../tests/RecoveryManualAssistanceTests.swift)

- `testBodyLineAtomsKeepEveryRawSpaceAndRealBoxThroughThreeManualFields`（宣言行 37）
- `testHighConfidenceLineAtomStillRequiresWholeLiteralAndUniqueBodyOwner`（宣言行 55）
- `testWholeLineRangeCrossingRolesFailsEvenWithAllInkCharactersInsideCell`（宣言行 74）
- `testLineAtomCannotBeSelectedAcrossPhysicalCellOrUsedAsHeading`（宣言行 92）
- `testCommonBodyProofKeepsIndependentNativeBoxesWithoutExpandingAnyRange`（宣言行 116）
- `testOneNativeCharacterAcrossCellRoleOrSharedBoundaryRefusesWholeAtom`（宣言行 133）
- `testCandidateRangeOtherRoleAndMissingOrDuplicateAtomReceiptRefuse`（宣言行 153）
- `testMissingVerifiedRoleScopeCannotUsePhysicalCellProofAlone`（宣言行 167）
- `testStandaloneBuilderAtomCannotEscapeWithoutNativeCapture`（宣言行 176）
- `testManualInputIdenticalRebindPreservesThreeIndividualAcknowledgements`（宣言行 188）
- `testManualInputRawUnicodeChangeRequiresNewAcknowledgement`（宣言行 200）
- `testManualOneTwoThreeFieldsReachFormalConversionWithSeparateHumanProvenance`（宣言行 233）
- `testManualFourthFieldAndAnyHeaderUncertaintyAreTerminal`（宣言行 258）
- `testManualPendingRawLowConfidenceCannotBeAdoptedWithoutCorrections`（宣言行 262）
- `testManualPrintedFieldCannotBecomeBlankOrPartialOverlay`（宣言行 269）
- `testManualEverySourceHashSnapshotParentCropAndTargetIsBound`（宣言行 277）
- `testManualIncompleteCaptureAndMissingCoverageCannotOfferItems`（宣言行 298）
- `testManualCancellationPropagatesBeforeDraftOrOverlay`（宣言行 310）
- `testManualCorrectedUTF16BoundAndExplicitTimestampAreEnforced`（宣言行 321）
- `testManualFullFieldParentsPreserveOriginalOrderAndNativeConfidence`（宣言行 329）
- `testManualEverySourceRequiresExactNativePageOrderAndConfidenceMembership`（宣言行 351）
- `testVersionSixNativeAndManualAuditsKeepExactConfirmationOnlyAfterCurrentProof`（宣言行 372）
- `testAtomContractCannotBeBackdatedToVersionSixOrLoseKnownVersionGuard`（宣言行 398）
- `testVersionSevenNativeAtomReceiptRetainsConfirmationAfterRevalidation`（宣言行 410）
- `testOptionalManualReceiptAbsencePreservesHistoricalJSON`（宣言行 426）

## [tests/RecoveryManualReviewTests.swift](../../tests/RecoveryManualReviewTests.swift)

- `testChangedLiteralShowsBothSidesWithoutAssigningParallelRoles`（宣言行 16）
- `testParallelOrderDoesNotInventAChangeAndMultiplicityRemainsVisible`（宣言行 23）
- `testWhitespaceAndUnicodeBytesAreComparedLiterally`（宣言行 28）
- `testTeacherRoomSpanAndTimeChangesAreVisible`（宣言行 32）
- `testExplicitBlankCanCompareButMissingPreviousCellCannot`（宣言行 37）
- `testDifferentYearTermKindAndMissingPreviousAreUnavailable`（宣言行 43）
- `testDifferentClassDayOrPeriodCannotBeGuessed`（宣言行 50）
- `testDuplicateScopeSlotsAndUndeclaredEntriesCannotCompare`（宣言行 56）
- `testPixelHighlightPreservesOriginAndFractionalBounds`（宣言行 62）
- `testHighlightRejectsOutsideNonfiniteAndDegenerateGeometry`（宣言行 67）

## [tests/test_manual_input_lifecycle.py](../../tests/test_manual_input_lifecycle.py)

- `test_actual_methods_preserve_idle_draft_and_only_reset_ack_on_raw_change`（宣言行 27）
- `test_view_rejects_detached_field_callbacks_and_retention_still_cancels`（宣言行 91）

## [tests/test_manual_review_controls.py](../../tests/test_manual_review_controls.py)

- `test_actual_xctest_comparison_and_pixel_geometry`（宣言行 7）

## [tests/test_manual_scroll_navigation.py](../../tests/test_manual_scroll_navigation.py)

- `test_actual_navigation_state_on_offscreen_virtualized_and_keyboard_frames`（宣言行 14）
- `test_qa_only_owner_resolution_and_existing_caps_are_preserved`（宣言行 147）

## [tests/test_manual_ui_diagnostics.py](../../tests/test_manual_ui_diagnostics.py)

- `test_command_timeout_and_output_cap_are_explicit`（宣言行 20）
- `test_sigterm_reaps_owned_command_and_keeps_signal_exit`（宣言行 28）
- `test_crash_capture_filters_exact_app_time_size_and_symlinks`（宣言行 53）
- `test_crash_identity_rejects_prefix_helper_and_arbitrary_mentions`（宣言行 73）
- `test_jetsam_exports_only_exact_app_entry`（宣言行 84）
- `test_legacy_crash_requires_exact_identity_lines`（宣言行 102）
- `test_legacy_failure_excludes_attachment_payloads`（宣言行 111）
- `test_always_collection_retains_original_exit_when_tools_fail`（宣言行 120）
- `test_collection_tool_errors_stay_unknown_no_binary_payload`（宣言行 138）
- `test_assertions_completion_guard_and_result_bundle_remain`（宣言行 153）

## [tests/test_manual_ui_project.py](../../tests/test_manual_ui_project.py)

- `test_missing_or_duplicate_anchor_fails_closed`（宣言行 14）
- `test_binding_diagnostics_are_opt_in_hashed_and_explicitly_truncated`（宣言行 18）
- `test_editor_uses_physical_clear_and_checks_full_replacement`（宣言行 32）
- `test_manual_case_filter_is_exact_and_default_keeps_whole_suite`（宣言行 46）
- `test_completion_guard_rejects_missing_duplicate_skipped_failed_or_other_case`（宣言行 66）
- `test_coordinator_preserves_actual_submit_adopt_and_source_guards`（宣言行 90）
- `test_view_identifiers_do_not_precheck_or_bypass_existing_disabled_gate`（宣言行 102）
- `test_review_readiness_measures_actual_coordinator_state`（宣言行 113）
- `test_comparable_prior_defers_actual_builder_until_qa_window_exists`（宣言行 120）
- `test_review_uses_production_japan_timestamp_without_device_timezone`（宣言行 146）
- `test_existing_app_generator_raster_anchor_matches_current_acquisition`（宣言行 153）
- `test_generated_host_preserves_production_background_task_registration`（宣言行 162）
- `test_fixture_dimensions_respect_native_capture_limit_and_uniform_rule_scale`（宣言行 183）
- `test_actual_qa_failure_stage_and_bitmap_extent_are_observable_in_accessibility_tree`（宣言行 197）
- `test_raster_ab_preserves_old_rendering_and_uses_same_physical_predicate`（宣言行 208）
- `test_fixture_uses_current_period_and_actual_builder_proof`（宣言行 225）
- `test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps`（宣言行 235）

## [tests/ui/ManualAssistanceChecks.swift](../../tests/ui/ManualAssistanceChecks.swift)

- `testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground`（宣言行 390）
- `testChangedOriginalCannotSubmitOrReplaceLastGood`（宣言行 442）
- `testThreeFieldsRequireEachAcknowledgementAndFourRefuses`（宣言行 462）
