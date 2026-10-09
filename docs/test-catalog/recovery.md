# PDF復旧・OCR・構造・Validator・端末内Provider

対応ソース・テストのSHA-256：
`da00f0d696d311eb110ce4e8c52d9355b2ff3e9ab8dea589dbd072efed7b06ce`

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

- `testDenseCalibrationIgnoresOutsideTextWithoutExhaustingWorkBudget`（宣言行 11）
- `testCalibrationSourceScanCancelsAndDoesNotCacheAPartialReference`（宣言行 37）
- `testCalibrationReferenceInventoryChargesHeightMismatchAndCancels`（宣言行 61）
- `testBuilderNeverConvertsCancelledCalibrationIntoStructureRecovery`（宣言行 82）
- `testMalformedAnnualNumericColumnsCannotHideBehindAValidYear`（宣言行 94）
- `testOrdinaryTitleYearMustBeUniqueWhileRepeatedEquivalentYearsRemainValid`（宣言行 115）
- `testRecoveryTitleYearEvidenceMustIncludeEveryEquivalentMarker`（宣言行 139）
- `testSourceIdentityIndexPreservesDuplicateAmbiguityAndCancellation`（宣言行 180）
- `testRasterRuleGraphStopsAtItsComparisonBudgetAndChecksCancellationInsidePass`（宣言行 210）
- `testRasterInkAndRuleMaskCheckCancellationInsideTheirPixelLoops`（宣言行 236）
- `testOffscreenRecoveryLayoutFailsBeforeSourceBindingOrAI`（宣言行 263）

## [tests/RecoveryBuilderTests+Ordered.swift](../../tests/RecoveryBuilderTests+Ordered.swift)

- `testOrderedNormalTimetableKeepsAll680UnlabelledTuplesAndFormalProjection`（宣言行 56）
- `testOrderedNormalTimetableCannotGuessMissingRowsOrAcceptPluralAndPartialLabels`（宣言行 85）
- `testOrderedRowValidatorRejectsSimultaneouslySwappedBindingsAndResult`（宣言行 114）
- `testOrderedNormalRowsRejectOpaqueAtomsMissingMetadataAndTwoHorizontalGroups`（宣言行 133）
- `testOrderedProofDropCannotHideVerticalRoleSwapAndOversizedProofRefuses`（宣言行 171）
- `testNewOrderedProofCannotBeBackdatedAndRoundTripsItsOriginalGeometry`（宣言行 189）

## [tests/RecoveryBuilderTests+Parallel.swift](../../tests/RecoveryBuilderTests+Parallel.swift)

- `testLayoutRecoveryPreservesParallelLessonsAndAllSlots`（宣言行 40）
- `testLayoutRecoveryCannotBypassUnalignedParallelEvidenceRefusal`（宣言行 60）
- `testLayoutRecoveryKeepsACompoundSingleRoleLiteralThroughRulesAndValidator`（宣言行 76）
- `testInlineRoleScopesCannotCollapseMatchedOrMismatchedMultipleBodyRoles`（宣言行 112）
- `testInlineRoleScopesKeepEachSingleCompoundRoleWithoutParallelInvention`（宣言行 128）
- `testReorderedInlineRolesRequireIndependentLabels`（宣言行 154）
- `testMultiCharacterTermGlyphFailsWithoutOutOfBoundsAccess`（宣言行 161）
- `testPartialReorderedRoleLabelsCannotBecomeFixedOrParallelBindings`（宣言行 175）
- `testTeacherOnlyCellCannotUseOutsideTableOrConflictingRoleCalibration`（宣言行 190）
- `testRecoveryCannotCalibrateTeacherOnlyCellFromOutsideTable`（宣言行 211）
- `testFractionalRasterCellIncludesEveryInteriorPixelCenter`（宣言行 222）
- `testStrictMissingTeacherDoesNotShiftRoomIntoTeacher`（宣言行 238）

## [tests/RecoveryBuilderTests+Raster.swift](../../tests/RecoveryBuilderTests+Raster.swift)

- `testOCRRecoveryRejectsAnEntireUnobservedClassRow`（宣言行 74）
- `testOCRRecoveryAccountsForBothClassRowsRulesAndKnownAnnotation`（宣言行 93）
- `testOCRRecoveryRejectsUnobservedAnnotationInkOutsideRecognizedCells`（宣言行 123）
- `testVectorRecoveryDoesNotTreatUnrequestedRasterAsOCRProof`（宣言行 133）
- `testRasterCoverageMaskFirstKeepsUnionAndFractionalPixelSemantics`（宣言行 163）
- `testRasterCoveragePreparedMaskCannotHideInkWhenRulesChange`（宣言行 180）
- `testRasterCoverageRulePixelsDoNotSpendTheTextComparisonBudget`（宣言行 190）
- `testRasterCoverageMaskFirstStillBoundsUnmaskedTextSearch`（宣言行 210）
- `testRasterCoverageMaskFirstChecksCancellationOnCertifiedRailPixels`（宣言行 223）

## [tests/RecoveryBuilderTests+Ruled.swift](../../tests/RecoveryBuilderTests+Ruled.swift)

- `testGenericRuledRecoveryPreservesOriginalTwoFortySlotFormalOracles`（宣言行 61）
- `testGenericRuledRecoveryRejectsIncompleteDaysDuplicateSlotsAndConflictingHeadings`（宣言行 103）
- `testGenericRuledRecoveryRejectsNeighbourBodyUnrecognizedInkAndUnprovedBlank`（宣言行 129）
- `testGenericRuledRecoveryCancellationRemainsTerminal`（宣言行 158）
- `testGenericRuledRecoveryKeepsOriginalTopologyWorkLimit`（宣言行 174）
- `testGenericRuledRecoveryCannotDiscardAnUnknownPhysicalClassRow`（宣言行 185）

## [tests/RecoveryBuilderTests+Special.swift](../../tests/RecoveryBuilderTests+Special.swift)

- `testDenseRecoverySourceGroupsUseOneIndexAndRemainCancellable`（宣言行 11）
- `testRecoverySpecialTitleYearEvidenceCannotIgnoreASecondYear`（宣言行 158）
- `testSpecialTitleYearMustBeUniqueAndEquivalentYearMarkersRemainValid`（宣言行 207）
- `testExamLayoutRecoveryReusesAllRepeatedClockCharts`（宣言行 241）
- `testExamDerivedSpanOnLaterPageUsesVerifiedPrimaryEndpointChart`（宣言行 252）
- `testReturnDerivedSpanOnLaterPageUsesApplicableNormalNote`（宣言行 262）
- `testReturnLayoutRecoveryRequiresNormalTimeNoteAndSpanEndpoints`（宣言行 282）

## [tests/RecoveryFunctionalCoverageTests.swift](../../tests/RecoveryFunctionalCoverageTests.swift)

- `testFunctionalUnlabeledTeacherAndRoomBlanksReachFormalConversionWithoutShifting`（宣言行 34）
- `testFunctionalMergedUnlabeledParallelTuplesRetainSeparatorAndEveryFormalSlot`（宣言行 54）
- `testFunctionalExamMergedClockAndBlankRolesReachFormalConversion`（宣言行 76）
- `testFunctionalReturnSplitParallelBlankRoomAndMergedNormalClockReachFormalConversion`（宣言行 92）
- `testFunctionalSpecialHeaderEvidenceCannotBeRemovedOrBorrowedForConversion`（宣言行 108）
- `testFunctionalReturnClassRowMustHaveCompletePhysicalBoundarySupport`（宣言行 128）
- `testFunctionalReturnClassRowIncludesBoundaryAtPeriodHeaderBottom`（宣言行 141）

## [tests/RecoveryOCRAcquisitionTests.swift](../../tests/RecoveryOCRAcquisitionTests.swift)

- `testSnapshotOwnsBytesAfterSourceIsAtomicallyReplaced`（宣言行 18）
- `testSnapshotLimitAndEmptySourceRefuseWithoutUnboundedRead`（宣言行 27）
- `testSnapshotCancellationAfterFirstChunkKeepsSourceUntouched`（宣言行 39）
- `testCountsUncertaintyOnlyAfterEveryRequiredPageIsCaptured`（宣言行 71）
- `testMixedVectorOCRInventoryRetainsExactRequiredPageIDs`（宣言行 81）
- `testThreeFourAndFiftySevenNativeFailuresRemainSeparate`（宣言行 90）
- `testAlternateHighConfidenceCandidateCannotRescueTop1`（宣言行 102）
- `testMissingWhitespaceRangeIsPreservedAndCannotBecomeCorrectable`（宣言行 111）
- `testNativeWholeLineRangeKeepsUnpositionedSpaceWithoutInventingItsBox`（宣言行 117）
- `testWholeLineRangeCannotRescueMissingInkInvalidSpaceOrMultilineText`（宣言行 130）
- `testHighConfidenceWholeLineStillRequiresBodyProofBeforeStrictParser`（宣言行 140）
- `testObservedLineBoxIsSeparateAuthorityAndMissingOrWrongBoxStillRefuses`（宣言行 150）
- `testNativeRangeOutsidePageRefusesWithoutClipping`（宣言行 170）
- `testInvalidConfidenceAndUncapturedCandidateRefuse`（宣言行 179）
- `testStrictBoundaryDoesNotLowerConfidence`（宣言行 186）
- `testNativeOrderAndFullTextCharacterMembershipMustAgree`（宣言行 190）
- `testCanonicalCapturePreservesUnicodeAndChangesWithSourceOrConfidence`（宣言行 200）
- `testCancellationIsCheckedDuringLargeInventoryValidation`（宣言行 211）
- `testSharedDocumentBudgetCannotResetPerPage`（宣言行 221）

## [tests/RecoveryOCRStructureTests.swift](../../tests/RecoveryOCRStructureTests.swift)

- `testMergedNativeCellRetainsBothAxesAndOriginalSourceLineOnce`（宣言行 39）
- `testSameTextAtDifferentCoordinatesLinksExactPhysicalOccurrence`（宣言行 50）
- `testOutsideTableLinesRetainOriginalOrderAndRawCandidates`（宣言行 56）
- `testMissingOrDifferentCellLineRefusesInsteadOfAddingOrCorrectingText`（宣言行 63）
- `testCanonicallyEquivalentUnicodeDoesNotBecomeAnExactRawMatch`（宣言行 70）
- `testDuplicateExactFlatLinesAreAmbiguousRatherThanChosenByOrder`（宣言行 75）
- `testAlternateRankOrConfidenceCannotBeNormalizedDuringLinking`（宣言行 80）
- `testTwoDistinctCellsCannotClaimTheSameNativeLine`（宣言行 88）
- `testNativeRowsAndColumnsMustRetainIdenticalCellContent`（宣言行 93）
- `testEmptyNativeCellIsRetainedWithoutInventingAFieldOrLine`（宣言行 98）
- `testNativeSpanIndicesAreKeptWithoutPeriodInference`（宣言行 105）
- `testNestedTablesRefuseExplicitlyRatherThanSilentlyLoseHierarchy`（宣言行 111）
- `testHierarchyCannotRaiseLowNativeConfidenceOrIncreaseManualAllowance`（宣言行 116）
- `testLegacyNilHierarchyCanonicalBytesStayUnchangedAndDecode`（宣言行 125）
- `testHierarchyChangesCaptureFingerprintInputWithoutChangingRawLines`（宣言行 132）
- `testNativeRegionNonfiniteOutOfBoundsAndOversizeRefuseWithoutClipping`（宣言行 139）
- `testDocumentPartitionCannotBorrowAnExactLineFromAnotherObservation`（宣言行 150）
- `testCancellationAndAggregateLimitAreChargedInsideNativeTextAndArrays`（宣言行 158）
- `testAggregateStructureBudgetCannotBeDisabledByCaller`（宣言行 172）
- `testDuplicateDocumentUUIDAndMissingGlobalLinePartitionRefuse`（宣言行 179）

## [tests/RecoveryPromptCatalogTests.swift](../../tests/RecoveryPromptCatalogTests.swift)

- `testPackagedInstructionLoadsVerifiedCanonicalBytes`（宣言行 6）
- `testSameLengthMutationFailsRatherThanFallingBackToOldInstruction`（宣言行 12）
- `testTruncationNewlineAndInvalidEncodingFailClosed`（宣言行 18）

## [tests/RecoveryRecertificationTests.swift](../../tests/RecoveryRecertificationTests.swift)

- `testLegalOldConfirmationCarriesForwardExactlyWithoutAnotherConfirmation`（宣言行 68）
- `testFixedAndScopedInlineCompoundCannotRetainOldOrForgedCurrentConfirmation`（宣言行 89）
- `testStaleAcceptanceFingerprintsCannotRecertifyChangedSourceOrResult`（宣言行 109）
- `testCurrentCertificateMustStillProveItsOriginalConfirmation`（宣言行 127）
- `testHistoricallyImpossibleDistinctMetadataCannotInventOldConfirmation`（宣言行 141）
- `testCurrentIndependentStructureAndFieldHistoriesAreRetainedExactly`（宣言行 149）
- `testUnconfirmedOldPreviewCannotBecomeAcceptedThroughConversion`（宣言行 170）
- `testOlderAndFutureVersionsCannotTakeTheExplicitHistoricalTransition`（宣言行 179）
- `testOCRCoverageProofSurvivesJSONRoundtripAndRemainsReusable`（宣言行 187）
- `testFormalProjectionMustBeIdenticalBeforeMetadataOnlyUpgrade`（宣言行 197）
- `testLibraryAutomaticallyPersistsSameHashRecertificationAndReloadsWithoutPreview`（宣言行 220）
- `testDisplayFiltersRejectedRecoveryWithoutDeletingAuditAndPreservesStrictResults`（宣言行 247）
- `testPreparedUpgradeCannotReplaceConfirmationChangedBeforeSave`（宣言行 266）
- `testFailedPersistenceDoesNotMutateLastGoodOrConfirmation`（宣言行 290）
- `testOldOCRConfirmationCannotAcquireCoverageFromMetadata`（宣言行 310）
- `testOCRProofIsBoundToAcceptanceAndCannotBeFilledIntoAnOldAudit`（宣言行 323）
- `testAcquisitionCacheRechecksUnprovedOCRWhileKeepingVectorConfirmation`（宣言行 347）

## [tests/RecoveryStructureTests.swift](../../tests/RecoveryStructureTests.swift)

- `testStructureResourceLimitDoesNotLoadAnotherRuntime`（宣言行 54）
- `testFoldedInterleavedLabelsUseBoundedRulesBeforeProviders`（宣言行 64）
- `testImmutablePreparedRequestStillValidatesProviderStructureMetadata`（宣言行 79）
- `testFoldedLabelsInTwoPhysicalParallelBandsPreserveLessonPairing`（宣言行 98）
- `testInvalidCoverageOrHeaderStopsBeforeProviderAvailabilityOrGeneration`（宣言行 118）
- `testAdjacentWrappedLabelRemainsCheapRulesOnly`（宣言行 130）
- `testStructureProposalRejectsInventedCoordinatesSwappedLabelAndMissingOriginalBody`（宣言行 135）
- `testBoundedLabelRulesRejectUnknownLabelsAndOverlappingRoleFootprints`（宣言行 147）
- `testBoundedLabelRulesPropagateLimitsAndInnerCancellation`（宣言行 166）
- `testBoundedLabelRulesRespectTheBuildersSharedWorkBudget`（宣言行 177）
- `testBoundedLabelRulesUseMeasuredCutsIndependentOfInputOrdering`（宣言行 186）
- `testExamAndReturnInterleavedLabelsUseBoundedRulesWithCompleteCoverage`（宣言行 199）

## [tests/RecoveryTests.swift](../../tests/RecoveryTests.swift)

- `testGroundedRulesDoNotLoadLanguageModel`（宣言行 36）
- `testModelNotReadyWaitsWithoutDownloadingFallback`（宣言行 37）
- `testMalformedOutputIsTerminalBeforeNextProvider`（宣言行 38）
- `testResourceLimitDoesNotLoadAnotherRuntime`（宣言行 39）
- `testRepeatedMalformedPeriodEvidenceCannotTriggerQuadraticMembership`（宣言行 50）
- `testRecoveryStringInventoriesAndConcatenationShareTheWorkLimit`（宣言行 62）
- `testRecoverySourceIndexRetainsOriginalOrderAndTallOrphanIntersections`（宣言行 72）
- `testRecoveryIndexCandidateBudgetAndCancellationAreSharedAndFailClosed`（宣言行 85）
- `testCompleteGroundedResultCanBePreviewed`（宣言行 101）
- `testUnknownIsNeverFreePeriod`（宣言行 102）
- `testIncompleteReaderIsRejected`（宣言行 103）
- `testPartialCellIsRejected`（宣言行 104）
- `testMissingSlotIsRejected`（宣言行 105）
- `testMissingResultCellIsRejected`（宣言行 106）
- `testDuplicateIdsRejectWithoutThrowing`（宣言行 107）
- `testNeighbourEvidenceIsRejected`（宣言行 108）
- `testInventedValueIsRejected`（宣言行 109）
- `testContentCannotBecomeEmpty`（宣言行 110）
- `testChangedYearIsRejected`（宣言行 111）
- `testChangedHashIsRejected`（宣言行 112）
- `testWrongSchemaRejects`（宣言行 113）
- `testTemporaryNotReadyNeverTriggersDownloadFallback`（宣言行 114）
- `testRecoveryMetadataRoundTrips`（宣言行 115）
- `testWrongHeaderTextIsRejected`（宣言行 116）
- `testFieldsCannotSwapRoles`（宣言行 117）
- `testTruncatedNamesAreRejected`（宣言行 118）
- `testKnownTextCannotBecomeBlank`（宣言行 119）
- `testOverlappingCellsAreRejected`（宣言行 120）
- `testWrongHeadingAxisIsRejected`（宣言行 121）
- `testOverflowingBoundsReject`（宣言行 122）
- `testCancelledRuleRecoveryDoesNotReturnPreview`（宣言行 123）
- `testIncompleteAndCancelledAnalysisResumeButDefinitiveFailureDoesNotLoop`（宣言行 128）
- `testSpecialScopeVersionRetriesSameHashEarlierSuccessfulAnalysis`（宣言行 133）
- `testOrdinaryRoleAliasVersionRetriesUnchangedEarlierSuccess`（宣言行 141）
- `testUnusedFontReaderVersionRetriesEarlierSameHashDefinitiveFailure`（宣言行 146）
- `testParallelAlignmentVersionRetriesEarlierSameHashSuccessAndFailure`（宣言行 155）
- `testOCRCoverageVersionRetriesPriorSameHashSuccessWithoutChangingEvents`（宣言行 167）
- `testRecoverySourceRequiresCurrentStrictFailureForSameDocument`（宣言行 174）
- `testRecoveryDocumentCannotReplaceAnotherYearOrHalf`（宣言行 185）
- `testFixedBindingCannotHideAnExplicitRoleLabel`（宣言行 195）
- `testManifestRequiresKnownBackendAndMinimumOS`（宣言行 201）
- `testSpecialSchedulesWithFullScopeAndExplicitSpanTimesPass`（宣言行 215）
- `testInventoryCannotDiscardTextToClaimEmpty`（宣言行 216）
- `testUnassignedTextInBlankCellRejects`（宣言行 217）
- `testUnboundLiteralCannotBeClassifiedAsPeriodHeader`（宣言行 218）
- `testUnusedSpanCannotClassifyOrphanAsClock`（宣言行 219）
- `testOrphanCannotBeHiddenInYearOrClassEvidence`（宣言行 220）
- `testOrphanCannotBeHiddenInReturnNote`（宣言行 221）
- `testOrphanTextOutsideCellsRejects`（宣言行 222）
- `testCommonClockCannotOverrideDateSpecificTime`（宣言行 223）
- `testAnotherDayClockCannotBeQuoted`（宣言行 224）
- `testReversedSpanClockCannotPassEvenWhenTextExists`（宣言行 225）
- `testReturnNormalTimeRequiresActualApplicableNote`（宣言行 226）
- `testSeventeenClassesCannotIncludeAnUnexpectedReplacement`（宣言行 227）
- `testDownloadedModelsExcludeExistingAndNewRootsFromBackup`（宣言行 230）
- `testModelDeletionFailurePreservesPointerForRetry`（宣言行 246）
- `testPartialCoreAIDeletionKeepsManagementIdentityAcrossRestart`（宣言行 266）
- `testModelUpdateSameBytesRemovesOldVersionAndFailureKeepsActiveModel`（宣言行 295）
- `testCoreAIArchiveAndPreparedBundleSwitchTogetherAndCancelledUpdateKeepsBoth`（宣言行 313）
- `testOriginalHashVerificationRejectsADataPeriodChangeDuringRead`（宣言行 341）
- `testOldValidatorApprovalCannotBeReusedButRemainsDecodable`（宣言行 354）
- `testApprovalOnlyReusesExactValidatedResult`（宣言行 361）
- `testUniqueRoleScopePartitionUsesRulesWithoutLoadingLocalAI`（宣言行 383）
- `testRoleProposalCannotSwapRolesOrOmitAnOriginalAtom`（宣言行 393）
- `testExternalColumnLabelIsStructuralEvidenceOutsideTheCell`（宣言行 402）
- `testFaintOrColoredUnrecognizedInkCannotProveAnEmptyRasterCell`（宣言行 415）
- `testRasterRulesRetainLinesTouchingRightAndBottomEdge`（宣言行 430）
- `testIsolatedOrDanglingCharacterStrokesCannotMaskUnrecognizedInk`（宣言行 438）
- `testOCRUnrecognizedInkCannotBecomeAnEmptyField`（宣言行 453）
- `testConnectedBorderCannotHideOnePixelOfFaintContentBesideIt`（宣言行 459）
- `testAiFeaturePermissionDefaultsOffAndOldTicketsCannotRevive`（宣言行 476）
- `testThickBorderWithDifferentPixelLaneEndpointsSharesOneClosedJunction`（宣言行 494）
- `testParallelBordersWithWhitePixelGapRemainTwoBoundaries`（宣言行 516）
- `testOpenRasterBorderKeepsClosedInteriorAndLeavesUnsupportedTailAsInk`（宣言行 528）
- `testOpenHShapeCannotCertifyClosedInteriorRules`（宣言行 541）
