# PDF復旧・OCR・構造・Validator・端末内Provider

対応関係・宣言名・実行方法のSHA-256：
`929d99e30f2488c027378518107166685321007bb943e6bf863560e48b2448a8`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/CoreAIRecoveryProvider.swift](../../Takupoke/CoreAIRecoveryProvider.swift)
- [Takupoke/LocalLlamaRecoveryProvider.swift](../../Takupoke/LocalLlamaRecoveryProvider.swift)
- [Takupoke/LocalRecoveryModelManager.swift](../../Takupoke/LocalRecoveryModelManager.swift)
- [Takupoke/PDFRecoveryCoordinator.swift](../../Takupoke/PDFRecoveryCoordinator.swift)
- [Takupoke/PDFRecoveryRecognition.swift](../../Takupoke/PDFRecoveryRecognition.swift)
- [Takupoke/RecoveryConversion.swift](../../Takupoke/RecoveryConversion.swift)
- [Takupoke/RecoveryDocumentBuilder.swift](../../Takupoke/RecoveryDocumentBuilder.swift)
- [Takupoke/RecoveryEngine.swift](../../Takupoke/RecoveryEngine.swift)
- [Takupoke/RecoveryModelStore.swift](../../Takupoke/RecoveryModelStore.swift)
- [Takupoke/RecoveryModels.swift](../../Takupoke/RecoveryModels.swift)
- [Takupoke/RecoveryOCRAcquisition.swift](../../Takupoke/RecoveryOCRAcquisition.swift)
- [Takupoke/RecoveryOCRStructure.swift](../../Takupoke/RecoveryOCRStructure.swift)
- [Takupoke/RecoveryPromptCatalog.swift](../../Takupoke/RecoveryPromptCatalog.swift)
- [Takupoke/RecoveryRasterGrid.swift](../../Takupoke/RecoveryRasterGrid.swift)
- [Takupoke/RecoveryStructure.swift](../../Takupoke/RecoveryStructure.swift)
- [Takupoke/RecoveryValidator.swift](../../Takupoke/RecoveryValidator.swift)
- [Takupoke/RecoveryVisionCapture.swift](../../Takupoke/RecoveryVisionCapture.swift)
- [Takupoke/SystemLanguageRecoveryProvider.swift](../../Takupoke/SystemLanguageRecoveryProvider.swift)
- [Vendor/CoreAIRecoveryBridge/Package.swift](../../Vendor/CoreAIRecoveryBridge/Package.swift)
- [Vendor/CoreAIRecoveryBridge/Sources/CCoreAIRecovery/CCoreAIRecovery.m](../../Vendor/CoreAIRecoveryBridge/Sources/CCoreAIRecovery/CCoreAIRecovery.m)
- [Vendor/CoreAIRecoveryBridge/Sources/CCoreAIRecovery/include/CCoreAIRecovery.h](../../Vendor/CoreAIRecoveryBridge/Sources/CCoreAIRecovery/include/CCoreAIRecovery.h)
- [Vendor/CoreAIRecoveryRuntime/Package.swift](../../Vendor/CoreAIRecoveryRuntime/Package.swift)
- [Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/CoreAIRecoveryRuntime.swift](../../Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/CoreAIRecoveryRuntime.swift)
- [Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/RecoveryPromptCatalog.swift](../../Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/RecoveryPromptCatalog.swift)
- [Vendor/LocalLlama/LICENSE.llama.cpp](../../Vendor/LocalLlama/LICENSE.llama.cpp)
- [Vendor/LocalLlama/Package.swift](../../Vendor/LocalLlama/Package.swift)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/CLlamaRecovery.cpp](../../Vendor/LocalLlama/Sources/CLlamaRecovery/CLlamaRecovery.cpp)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-alloc.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-alloc.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-backend.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-backend.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-cpu.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-cpu.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-opt.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml-opt.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/ggml.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/gguf.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/gguf.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/llama.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/PrivateHeaders/llama.h)
- [Vendor/LocalLlama/Sources/CLlamaRecovery/include/CLlamaRecovery.h](../../Vendor/LocalLlama/Sources/CLlamaRecovery/include/CLlamaRecovery.h)

## [tests/RecoveryBuilderTests+Calibration.swift](../../tests/RecoveryBuilderTests+Calibration.swift)

- `testDenseCalibrationIgnoresOutsideTextWithoutExhaustingWorkBudget`
- `testCalibrationSourceScanCancelsAndDoesNotCacheAPartialReference`
- `testCalibrationReferenceInventoryChargesHeightMismatchAndCancels`
- `testBuilderNeverConvertsCancelledCalibrationIntoStructureRecovery`
- `testMalformedAnnualNumericColumnsCannotHideBehindAValidYear`
- `testOrdinaryTitleYearMustBeUniqueWhileRepeatedEquivalentYearsRemainValid`
- `testRecoveryTitleYearEvidenceMustIncludeEveryEquivalentMarker`
- `testSourceIdentityIndexPreservesDuplicateAmbiguityAndCancellation`
- `testRasterRuleGraphStopsAtItsComparisonBudgetAndChecksCancellationInsidePass`
- `testRasterInkAndRuleMaskCheckCancellationInsideTheirPixelLoops`
- `testOffscreenRecoveryLayoutFailsBeforeSourceBindingOrAI`

## [tests/RecoveryBuilderTests+Ordered.swift](../../tests/RecoveryBuilderTests+Ordered.swift)

- `testOrderedNormalTimetableKeepsAll680UnlabelledTuplesAndFormalProjection`
- `testOrderedNormalTimetableCannotGuessMissingRowsOrAcceptPluralAndPartialLabels`
- `testOrderedRowValidatorRejectsSimultaneouslySwappedBindingsAndResult`
- `testOrderedNormalRowsRejectOpaqueAtomsMissingMetadataAndTwoHorizontalGroups`
- `testOrderedProofDropCannotHideVerticalRoleSwapAndOversizedProofRefuses`
- `testNewOrderedProofCannotBeBackdatedAndRoundTripsItsOriginalGeometry`

## [tests/RecoveryBuilderTests+Parallel.swift](../../tests/RecoveryBuilderTests+Parallel.swift)

- `testLayoutRecoveryPreservesParallelLessonsAndAllSlots`
- `testLayoutRecoveryCannotBypassUnalignedParallelEvidenceRefusal`
- `testLayoutRecoveryKeepsACompoundSingleRoleLiteralThroughRulesAndValidator`
- `testInlineRoleScopesCannotCollapseMatchedOrMismatchedMultipleBodyRoles`
- `testInlineRoleScopesKeepEachSingleCompoundRoleWithoutParallelInvention`
- `testReorderedInlineRolesRequireIndependentLabels`
- `testMultiCharacterTermGlyphFailsWithoutOutOfBoundsAccess`
- `testPartialReorderedRoleLabelsCannotBecomeFixedOrParallelBindings`
- `testTeacherOnlyCellCannotUseOutsideTableOrConflictingRoleCalibration`
- `testRecoveryCannotCalibrateTeacherOnlyCellFromOutsideTable`
- `testFractionalRasterCellIncludesEveryInteriorPixelCenter`
- `testStrictMissingTeacherDoesNotShiftRoomIntoTeacher`

## [tests/RecoveryBuilderTests+Raster.swift](../../tests/RecoveryBuilderTests+Raster.swift)

- `testOCRRecoveryRejectsAnEntireUnobservedClassRow`
- `testOCRRecoveryAccountsForBothClassRowsRulesAndKnownAnnotation`
- `testOCRRecoveryRejectsUnobservedAnnotationInkOutsideRecognizedCells`
- `testVectorRecoveryDoesNotTreatUnrequestedRasterAsOCRProof`
- `testRasterCoverageMaskFirstKeepsUnionAndFractionalPixelSemantics`
- `testRasterCoveragePreparedMaskCannotHideInkWhenRulesChange`
- `testRasterCoverageRulePixelsDoNotSpendTheTextComparisonBudget`
- `testRasterCoverageMaskFirstStillBoundsUnmaskedTextSearch`
- `testRasterCoverageMaskFirstChecksCancellationOnCertifiedRailPixels`

## [tests/RecoveryBuilderTests+Ruled.swift](../../tests/RecoveryBuilderTests+Ruled.swift)

- `testGenericRuledRecoveryPreservesOriginalTwoFortySlotFormalOracles`
- `testGenericRuledRecoveryRejectsIncompleteDaysDuplicateSlotsAndConflictingHeadings`
- `testGenericRuledRecoveryRejectsNeighbourBodyUnrecognizedInkAndUnprovedBlank`
- `testGenericRuledRecoveryCancellationRemainsTerminal`
- `testGenericRuledRecoveryKeepsOriginalTopologyWorkLimit`
- `testGenericRuledRecoveryCannotDiscardAnUnknownPhysicalClassRow`

## [tests/RecoveryBuilderTests+Special.swift](../../tests/RecoveryBuilderTests+Special.swift)

- `testDenseRecoverySourceGroupsUseOneIndexAndRemainCancellable`
- `testRecoverySpecialTitleYearEvidenceCannotIgnoreASecondYear`
- `testSpecialTitleYearMustBeUniqueAndEquivalentYearMarkersRemainValid`
- `testExamLayoutRecoveryReusesAllRepeatedClockCharts`
- `testExamDerivedSpanOnLaterPageUsesVerifiedPrimaryEndpointChart`
- `testReturnDerivedSpanOnLaterPageUsesApplicableNormalNote`
- `testReturnLayoutRecoveryRequiresNormalTimeNoteAndSpanEndpoints`

## [tests/RecoveryFunctionalCoverageTests.swift](../../tests/RecoveryFunctionalCoverageTests.swift)

- `testFunctionalUnlabeledTeacherAndRoomBlanksReachFormalConversionWithoutShifting`
- `testFunctionalMergedUnlabeledParallelTuplesRetainSeparatorAndEveryFormalSlot`
- `testFunctionalExamMergedClockAndBlankRolesReachFormalConversion`
- `testFunctionalReturnSplitParallelBlankRoomAndMergedNormalClockReachFormalConversion`
- `testFunctionalSpecialHeaderEvidenceCannotBeRemovedOrBorrowedForConversion`
- `testFunctionalReturnClassRowMustHaveCompletePhysicalBoundarySupport`
- `testFunctionalReturnClassRowIncludesBoundaryAtPeriodHeaderBottom`

## [tests/RecoveryOCRAcquisitionTests.swift](../../tests/RecoveryOCRAcquisitionTests.swift)

- `testSnapshotOwnsBytesAfterSourceIsAtomicallyReplaced`
- `testSnapshotLimitAndEmptySourceRefuseWithoutUnboundedRead`
- `testSnapshotCancellationAfterFirstChunkKeepsSourceUntouched`
- `testCountsUncertaintyOnlyAfterEveryRequiredPageIsCaptured`
- `testMixedVectorOCRInventoryRetainsExactRequiredPageIDs`
- `testThreeFourAndFiftySevenNativeFailuresRemainSeparate`
- `testAlternateHighConfidenceCandidateCannotRescueTop1`
- `testMissingWhitespaceRangeIsPreservedAndCannotBecomeCorrectable`
- `testNativeWholeLineRangeKeepsUnpositionedSpaceWithoutInventingItsBox`
- `testWholeLineRangeCannotRescueMissingInkInvalidSpaceOrMultilineText`
- `testHighConfidenceWholeLineStillRequiresBodyProofBeforeStrictParser`
- `testObservedLineBoxIsSeparateAuthorityAndMissingOrWrongBoxStillRefuses`
- `testNativeRangeOutsidePageRefusesWithoutClipping`
- `testInvalidConfidenceAndUncapturedCandidateRefuse`
- `testStrictBoundaryDoesNotLowerConfidence`
- `testNativeOrderAndFullTextCharacterMembershipMustAgree`
- `testCanonicalCapturePreservesUnicodeAndChangesWithSourceOrConfidence`
- `testCancellationIsCheckedDuringLargeInventoryValidation`
- `testSharedDocumentBudgetCannotResetPerPage`

## [tests/RecoveryOCRStructureTests.swift](../../tests/RecoveryOCRStructureTests.swift)

- `testMergedNativeCellRetainsBothAxesAndOriginalSourceLineOnce`
- `testSameTextAtDifferentCoordinatesLinksExactPhysicalOccurrence`
- `testOutsideTableLinesRetainOriginalOrderAndRawCandidates`
- `testMissingOrDifferentCellLineRefusesInsteadOfAddingOrCorrectingText`
- `testCanonicallyEquivalentUnicodeDoesNotBecomeAnExactRawMatch`
- `testDuplicateExactFlatLinesAreAmbiguousRatherThanChosenByOrder`
- `testAlternateRankOrConfidenceCannotBeNormalizedDuringLinking`
- `testTwoDistinctCellsCannotClaimTheSameNativeLine`
- `testNativeRowsAndColumnsMustRetainIdenticalCellContent`
- `testEmptyNativeCellIsRetainedWithoutInventingAFieldOrLine`
- `testNativeSpanIndicesAreKeptWithoutPeriodInference`
- `testNestedTablesRefuseExplicitlyRatherThanSilentlyLoseHierarchy`
- `testHierarchyCannotRaiseLowNativeConfidenceOrIncreaseManualAllowance`
- `testLegacyNilHierarchyCanonicalBytesStayUnchangedAndDecode`
- `testHierarchyChangesCaptureFingerprintInputWithoutChangingRawLines`
- `testNativeRegionNonfiniteOutOfBoundsAndOversizeRefuseWithoutClipping`
- `testDocumentPartitionCannotBorrowAnExactLineFromAnotherObservation`
- `testCancellationAndAggregateLimitAreChargedInsideNativeTextAndArrays`
- `testAggregateStructureBudgetCannotBeDisabledByCaller`
- `testDuplicateDocumentUUIDAndMissingGlobalLinePartitionRefuse`

## [tests/RecoveryPromptCatalogTests.swift](../../tests/RecoveryPromptCatalogTests.swift)

- `testPackagedInstructionLoadsVerifiedCanonicalBytes`
- `testSameLengthMutationFailsRatherThanFallingBackToOldInstruction`
- `testTruncationNewlineAndInvalidEncodingFailClosed`

## [tests/RecoveryRecertificationTests.swift](../../tests/RecoveryRecertificationTests.swift)

- `testLegalOldConfirmationCarriesForwardExactlyWithoutAnotherConfirmation`
- `testFixedAndScopedInlineCompoundCannotRetainOldOrForgedCurrentConfirmation`
- `testStaleAcceptanceFingerprintsCannotRecertifyChangedSourceOrResult`
- `testCurrentCertificateMustStillProveItsOriginalConfirmation`
- `testHistoricallyImpossibleDistinctMetadataCannotInventOldConfirmation`
- `testCurrentIndependentStructureAndFieldHistoriesAreRetainedExactly`
- `testUnconfirmedOldPreviewCannotBecomeAcceptedThroughConversion`
- `testOlderAndFutureVersionsCannotTakeTheExplicitHistoricalTransition`
- `testOCRCoverageProofSurvivesJSONRoundtripAndRemainsReusable`
- `testFormalProjectionMustBeIdenticalBeforeMetadataOnlyUpgrade`
- `testLibraryAutomaticallyPersistsSameHashRecertificationAndReloadsWithoutPreview`
- `testDisplayFiltersRejectedRecoveryWithoutDeletingAuditAndPreservesStrictResults`
- `testPreparedUpgradeCannotReplaceConfirmationChangedBeforeSave`
- `testFailedPersistenceDoesNotMutateLastGoodOrConfirmation`
- `testOldOCRConfirmationCannotAcquireCoverageFromMetadata`
- `testOCRProofIsBoundToAcceptanceAndCannotBeFilledIntoAnOldAudit`
- `testAcquisitionCacheRechecksUnprovedOCRWhileKeepingVectorConfirmation`

## [tests/RecoveryStructureTests.swift](../../tests/RecoveryStructureTests.swift)

- `testStructureResourceLimitDoesNotLoadAnotherRuntime`
- `testFoldedInterleavedLabelsUseBoundedRulesBeforeProviders`
- `testImmutablePreparedRequestStillValidatesProviderStructureMetadata`
- `testFoldedLabelsInTwoPhysicalParallelBandsPreserveLessonPairing`
- `testInvalidCoverageOrHeaderStopsBeforeProviderAvailabilityOrGeneration`
- `testAdjacentWrappedLabelRemainsCheapRulesOnly`
- `testStructureProposalRejectsInventedCoordinatesSwappedLabelAndMissingOriginalBody`
- `testBoundedLabelRulesRejectUnknownLabelsAndOverlappingRoleFootprints`
- `testBoundedLabelRulesPropagateLimitsAndInnerCancellation`
- `testBoundedLabelRulesRespectTheBuildersSharedWorkBudget`
- `testBoundedLabelRulesUseMeasuredCutsIndependentOfInputOrdering`
- `testExamAndReturnInterleavedLabelsUseBoundedRulesWithCompleteCoverage`

## [tests/RecoveryTests.swift](../../tests/RecoveryTests.swift)

- `testGroundedRulesDoNotLoadLanguageModel`
- `testModelNotReadyWaitsWithoutDownloadingFallback`
- `testMalformedOutputIsTerminalBeforeNextProvider`
- `testResourceLimitDoesNotLoadAnotherRuntime`
- `testRepeatedMalformedPeriodEvidenceCannotTriggerQuadraticMembership`
- `testRecoveryStringInventoriesAndConcatenationShareTheWorkLimit`
- `testRecoverySourceIndexRetainsOriginalOrderAndTallOrphanIntersections`
- `testRecoveryIndexCandidateBudgetAndCancellationAreSharedAndFailClosed`
- `testCompleteGroundedResultCanBePreviewed`
- `testUnknownIsNeverFreePeriod`
- `testIncompleteReaderIsRejected`
- `testPartialCellIsRejected`
- `testMissingSlotIsRejected`
- `testMissingResultCellIsRejected`
- `testDuplicateIdsRejectWithoutThrowing`
- `testNeighbourEvidenceIsRejected`
- `testInventedValueIsRejected`
- `testContentCannotBecomeEmpty`
- `testChangedYearIsRejected`
- `testChangedHashIsRejected`
- `testWrongSchemaRejects`
- `testTemporaryNotReadyNeverTriggersDownloadFallback`
- `testRecoveryMetadataRoundTrips`
- `testWrongHeaderTextIsRejected`
- `testFieldsCannotSwapRoles`
- `testTruncatedNamesAreRejected`
- `testKnownTextCannotBecomeBlank`
- `testOverlappingCellsAreRejected`
- `testWrongHeadingAxisIsRejected`
- `testOverflowingBoundsReject`
- `testCancelledRuleRecoveryDoesNotReturnPreview`
- `testIncompleteAndCancelledAnalysisResumeButDefinitiveFailureDoesNotLoop`
- `testSpecialScopeVersionRetriesSameHashEarlierSuccessfulAnalysis`
- `testOrdinaryRoleAliasVersionRetriesUnchangedEarlierSuccess`
- `testUnusedFontReaderVersionRetriesEarlierSameHashDefinitiveFailure`
- `testParallelAlignmentVersionRetriesEarlierSameHashSuccessAndFailure`
- `testOCRCoverageVersionRetriesPriorSameHashSuccessWithoutChangingEvents`
- `testRecoverySourceRequiresCurrentStrictFailureForSameDocument`
- `testRecoveryDocumentCannotReplaceAnotherYearOrHalf`
- `testFixedBindingCannotHideAnExplicitRoleLabel`
- `testManifestRequiresKnownBackendAndMinimumOS`
- `testSpecialSchedulesWithFullScopeAndExplicitSpanTimesPass`
- `testInventoryCannotDiscardTextToClaimEmpty`
- `testUnassignedTextInBlankCellRejects`
- `testUnboundLiteralCannotBeClassifiedAsPeriodHeader`
- `testUnusedSpanCannotClassifyOrphanAsClock`
- `testOrphanCannotBeHiddenInYearOrClassEvidence`
- `testOrphanCannotBeHiddenInReturnNote`
- `testOrphanTextOutsideCellsRejects`
- `testCommonClockCannotOverrideDateSpecificTime`
- `testAnotherDayClockCannotBeQuoted`
- `testReversedSpanClockCannotPassEvenWhenTextExists`
- `testReturnNormalTimeRequiresActualApplicableNote`
- `testSeventeenClassesCannotIncludeAnUnexpectedReplacement`
- `testDownloadedModelsExcludeExistingAndNewRootsFromBackup`
- `testModelDeletionFailurePreservesPointerForRetry`
- `testPartialCoreAIDeletionKeepsManagementIdentityAcrossRestart`
- `testModelUpdateSameBytesRemovesOldVersionAndFailureKeepsActiveModel`
- `testCoreAIArchiveAndPreparedBundleSwitchTogetherAndCancelledUpdateKeepsBoth`
- `testOriginalHashVerificationRejectsADataPeriodChangeDuringRead`
- `testOldValidatorApprovalCannotBeReusedButRemainsDecodable`
- `testApprovalOnlyReusesExactValidatedResult`
- `testUniqueRoleScopePartitionUsesRulesWithoutLoadingLocalAI`
- `testRoleProposalCannotSwapRolesOrOmitAnOriginalAtom`
- `testExternalColumnLabelIsStructuralEvidenceOutsideTheCell`
- `testFaintOrColoredUnrecognizedInkCannotProveAnEmptyRasterCell`
- `testRasterRulesRetainLinesTouchingRightAndBottomEdge`
- `testIsolatedOrDanglingCharacterStrokesCannotMaskUnrecognizedInk`
- `testOCRUnrecognizedInkCannotBecomeAnEmptyField`
- `testConnectedBorderCannotHideOnePixelOfFaintContentBesideIt`
- `testAiFeaturePermissionDefaultsOffAndOldTicketsCannotRevive`
- `testThickBorderWithDifferentPixelLaneEndpointsSharesOneClosedJunction`
- `testParallelBordersWithWhitePixelGapRemainTwoBoundaries`
- `testOpenRasterBorderKeepsClosedInteriorAndLeavesUnsupportedTailAsInk`
- `testOpenHShapeCannotCertifyClosedInteriorRules`
