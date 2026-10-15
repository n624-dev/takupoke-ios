# Strict PDF・文字・位置・罫線

対応関係・宣言名・実行方法のSHA-256：
`9b76b9d79ec367fe904ee3912badec1c1ef885883f604ce9b47fe124e9386aa5`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B tools/pdf_branch_catalog.py check
```

## 変更時に確認するソース

- [Takupoke/PDFAnalysis.swift](../../Takupoke/PDFAnalysis.swift)
- [Takupoke/PDFAnalysisView.swift](../../Takupoke/PDFAnalysisView.swift)
- [Takupoke/PDFCharacterGeometry.swift](../../Takupoke/PDFCharacterGeometry.swift)
- [Takupoke/PDFDiagnostics.swift](../../Takupoke/PDFDiagnostics.swift)
- [Takupoke/PDFDrawnTextReader+Fonts.swift](../../Takupoke/PDFDrawnTextReader+Fonts.swift)
- [Takupoke/PDFDrawnTextReader.swift](../../Takupoke/PDFDrawnTextReader.swift)
- [Takupoke/PDFFullDiagnosticEncoding.swift](../../Takupoke/PDFFullDiagnosticEncoding.swift)
- [Takupoke/PDFFullReadDiagnostic.swift](../../Takupoke/PDFFullReadDiagnostic.swift)
- [Takupoke/PDFGrid.swift](../../Takupoke/PDFGrid.swift)
- [Takupoke/PDFKitReader+Diagnostics.swift](../../Takupoke/PDFKitReader+Diagnostics.swift)
- [Takupoke/PDFKitReader.swift](../../Takupoke/PDFKitReader.swift)
- [Takupoke/PDFLessonDetail.swift](../../Takupoke/PDFLessonDetail.swift)
- [Takupoke/PDFParseError.swift](../../Takupoke/PDFParseError.swift)
- [Takupoke/PDFPathReader.swift](../../Takupoke/PDFPathReader.swift)
- [Takupoke/PDFSchoolParser+Events.swift](../../Takupoke/PDFSchoolParser+Events.swift)
- [Takupoke/PDFSchoolParser+Timetable.swift](../../Takupoke/PDFSchoolParser+Timetable.swift)
- [Takupoke/PDFSchoolParser.swift](../../Takupoke/PDFSchoolParser.swift)
- [Takupoke/PDFTextGeometry.swift](../../Takupoke/PDFTextGeometry.swift)
- [Takupoke/PDFUnicodeMap.swift](../../Takupoke/PDFUnicodeMap.swift)
- [tests/PDFParsingTests.swift](../../tests/PDFParsingTests.swift)
- [Takupoke/PDFContentVisibility.swift](../../Takupoke/PDFContentVisibility.swift)
- [Takupoke/PDFPaintSpace.swift](../../Takupoke/PDFPaintSpace.swift)
- [Takupoke/PDFPaintSample.swift](../../Takupoke/PDFPaintSample.swift)
- [tools/strict_pdf_compatibility_fixtures.py](../../tools/strict_pdf_compatibility_fixtures.py)
- [Takupoke/PDFEncodedGlyphMap.swift](../../Takupoke/PDFEncodedGlyphMap.swift)
- [Takupoke/PDFDrawnTextReader+GlyphBounds.swift](../../Takupoke/PDFDrawnTextReader+GlyphBounds.swift)
- [tools/pdf_branch_catalog.py](../../tools/pdf_branch_catalog.py)
- [Takupoke/PDF239DrawnTextReader.swift](../../Takupoke/PDF239DrawnTextReader.swift)
- [Takupoke/PDF239DrawnTextReader+Fonts.swift](../../Takupoke/PDF239DrawnTextReader+Fonts.swift)
- [Takupoke/PDF239TextGeometry.swift](../../Takupoke/PDF239TextGeometry.swift)
- [Takupoke/PDF239UnicodeMap.swift](../../Takupoke/PDF239UnicodeMap.swift)
- [Takupoke/PDF239PathReader.swift](../../Takupoke/PDF239PathReader.swift)
- [Takupoke/PDF239Grid.swift](../../Takupoke/PDF239Grid.swift)
- [Takupoke/PDF239SchoolParser.swift](../../Takupoke/PDF239SchoolParser.swift)
- [Takupoke/PDF239SchoolParser+Timetable.swift](../../Takupoke/PDF239SchoolParser+Timetable.swift)
- [Takupoke/PDF239SchoolParser+Events.swift](../../Takupoke/PDF239SchoolParser+Events.swift)
- [Takupoke/PDF239SpecialScheduleParser.swift](../../Takupoke/PDF239SpecialScheduleParser.swift)
- [Takupoke/PDF239SpecialScheduleParser+Pages.swift](../../Takupoke/PDF239SpecialScheduleParser+Pages.swift)
- [Takupoke/PDF239SpecialScheduleParser+Times.swift](../../Takupoke/PDF239SpecialScheduleParser+Times.swift)
- [Takupoke/PDF239KitReader.swift](../../Takupoke/PDF239KitReader.swift)
- [Takupoke/PDFReturnGeometryDiagnostic.swift](../../Takupoke/PDFReturnGeometryDiagnostic.swift)

## [tests/PDFParsingTests+Diagnostics.swift](../../tests/PDFParsingTests+Diagnostics.swift)

- `testTimetableFailureReportsLocationAndLineCountWithoutNames`
- `testTimetableGeometryReportReproducesFailureWithoutSourceText`
- `testGeometryDiagnosticHasBoundedSize`
- `testTraceCoversP01AndAllFailureStagesWithInvalidRectangles`
- `testTraceLimitsKeepStartupAndFinalFailureAndEncodeInvalidNumbers`
- `testFullDiagnosticCopyPreservesAllTextAndGeometryLosslessly`
- `testFailureStagesSurvivePageWrappingAndContainNoSourceText`
- `testOldFailureDecodesAndNewFailureRetainsOnlyFixedDiagnostic`
- `testFixedBranchCodesRoundTripWithoutChangingLegacyFailures`
- `testHumanReadableFailureSeparatesCodesWithoutExposingInternalStages`
- `testPDFFailureReplacementAndManifestRollback`

## [tests/PDFParsingTests+Events.swift](../../tests/PDFParsingTests+Events.swift)

- `testCloseCalendarLinesKeepTheirOrderAndExplicitTags`
- `testTagsUseOnlyExplicitDeclarationsAndFlagConflicts`
- `testCalendarScopesDatesPeriodsAndYearBoundary`
- `testUnknownPeriodIsExplicitAndUnsupportedInputStops`
- `testConflictingPeriodAndMismatchedYearAreNotAccepted`

## [tests/PDFParsingTests+PDFKit.swift](../../tests/PDFParsingTests+PDFKit.swift)

- `testIndependentOrderedRowSourcePDFsReachFormalOrRefuseWithoutOracleInput`
- `testVisibilityCollisionWorkAndCancellationAreBoundedWithinEachPaint`
- `testDisjointVisibilityCollisionIndexAvoidsTheFormerFullGlyphScan`
- `testPDFPathPaintPreservesFilledRulesAndUniqueArrow`
- `testPDFPathPaintPreservesStrokeRules`
- `testPDFPathPaintChecksCancellationWithinFillAndStroke`
- `testPDFPathPaintBoundsStemComparisonWork`
- `testPDFPathPaintBudgetIsCumulativeAcrossCallbacks`
- `testPDFKitTextSelectionsStayAlignedAcrossSpacesLinesAndRotations`
- `testPDFKitFullDiagnosticCollectsAllTextWhitespaceAndMultiplePages`
- `testPDFKitBridgeRecognizesFilledArrowGeometry`
- `testPDFKitBridgeReadsSyntheticPDFAndRotation`

## [tests/PDFParsingTests+Timetable.swift](../../tests/PDFParsingTests+Timetable.swift)

- `testStrict239RetainsFirstYearMarkerAndOriginalCoordinateContract`
- `testStrict239RestoresTrailingEmptyFieldsWithoutRoleCalibration`
- `testRelativeTimetableOutsideViewportCannotBecomeStrictSuccess`
- `testTimetablePeriodsParallelLessonsAndEmptyRoom`
- `testTimetableRejectsUnalignedParallelEvidenceAcrossAnyTwoRoles`
- `testTimetableKeepsOneCompoundRoleLiteralWithoutInventingParallelTuples`
- `testTimetableRoomCollapsesOnlyRepeatedHalfwidthVoicingMarks`
- `testSourceOrderKeepsMixedSizeLessonNamesAndMetadataSeparate`
- `testTimetableJoinsAlignedNonoverlappingLineFragments`
- `testTimetableFragmentsDoNotMergeOverlapsOrNearbyDifferentLines`
- `testTimetableBoundaryOverhangRequiresForwardTextAndGeometry`
- `testCharacterBoundsKeepNeighbouringCellsOutOfTimetable`
- `testCharacterGeometryValidatesUTF16RangesAndDoesNotDropInvalidBounds`
- `testRemovingDisplayBreaksPreservesStoredLessonFields`
- `testAmbiguousSourceOrderStopsInsteadOfFallingBackToCoordinates`
- `testDamagedClassAndUnalignedParallelFieldsStopWholeTable`
- `testFirstYearPDFClassAssignmentUsesOnlyTheUnconvertedRawSubject`

## [tests/PDFTextGeometryTests.swift](../../tests/PDFTextGeometryTests.swift)

- `testCollisionIndexMatchesInclusiveBruteForceAcrossWidthsPadsAndBoundaryContacts`
- `testCollisionIndexKeepsDenseDisjointTableSearchInsideOneOriginalPaintBudget`
- `testCollisionIndexChargesConstructionSearchAndPreservesThrownCancellation`
- `testStrokePaddingRequiresAnExactAnglePreservingTransform`
- `testEncodedGlyphBoundsDoNotUseUnrelatedFontExtentsOrRescueMissingGlyphs`
- `testEncodedSymbolicGlyphMapIsBoundedAndNeverUsesUnicode`
- `testVisibleTextModesKeepOriginalGeometryAndBoundOutlinesSeparately`
- `testOutlinedTextRejectsUnknownBoundsWideOrDashedStrokeAndInvisibleInk`
- `testOutlinedTextStateRestoresWidthModeJoinMiterAndDash`
- `testWhiteFillWithVisibleOutlineIsNotInvisibleText`
- `testWhiteOutlinedGlyphCannotConcealAnotherGlyph`
- `testViewportChecksWholeGlyphsRulesAndFiniteEndpointSums`
- `testStrictStrokeWidthBoundsIncludeTransformsAndHairlines`
- `testCanonicalBlackClassificationIsSeparateFromVisibleColorEligibility`
- `testRecoveryRetainsDrawnSpacesWithoutChangingStrictGlyphs`
- `testFullTwoByteSingletonCodeDomainRemainsBoundedAndCancellable`
- `testUnicodeCharactersRangesAndSurrogatePairs`
- `testMalformedOrUnsupportedUnicodeMapsFailClosed`
- `testUnusedControlMappingsAreMetadataButDrawingThemFailsClosed`
- `testUnusedUnsupportedFontStateAndGraphicsRestorePreserveReadableGlyphs`
- `testEmptyShowRequiresSelectedValidTextStateAndRetainsCancellation`
- `testSpacingAndTJKeepAdjacentCellsSeparate`
- `testCompositeCode32DoesNotApplyWordSpacing`
- `testTransformsRiseScalingAndSavedGraphicsState`
- `testLineMatrixMovesIndependentlyOfStringAdvance`
- `testCoverageRejectsDroppedDuplicatedOrChangedText`
- `testUnsafeTextStateAndCancellationFailClosed`
- `testNativeExplicitFontAndUnicodeResourcesDecodeIndependently`
- `testNativeNearAxisMiterAndNonSimilarStrokeCannotCertifyPaintBounds`
- `testNativeCrossedOrRetracedThinFillIsNotARectangularBorder`
- `testNativeWhiteTextAndOpaqueRepaintUseRasterInsteadOfSelectableText`
- `testNativeCroppedOutBodyCannotBecomeCompleteInput`
- `testNativeOffCanvasSelectableTextCannotBecomeCompleteInput`
- `testNativeRejectionBranchIsFixedAndPositiveControlStillReads`
- `testNativeThinStrokeCannotCrossAcquiredGlyphs`
- `testNativeOutlinedTextUsesCompositedRasterInsteadOfSelectionBounds`
- `testNativeDashedGhostRulesCannotBecomeACompleteTable`
- `testNativeSpecialVisibilityScanRejectsHiddenAndUnverifiedText`
- `testNativeSpecialVisibilityScanAllowsOpaqueTextAndRules`
- `testNativeResourcesAndTJThroughPDFKitBridge`
- `testNativeMissingMappingAndReplacementContentFailClosed`
- `testNativeUnusedUnsupportedFontSetupAllowsCompleteReadableTextButUseRejects`

## [tests/PDFTextGeometryTests+Visibility.swift](../../tests/PDFTextGeometryTests+Visibility.swift)

- `testUnusedDevicePaintDoesNotRejectBlackTextAndSavedColorRestores`
- `testClipContainmentHasNoToleranceAndPreservesLimitsAndCancellation`
- `testStrict239ReadDoesNotPromoteLegacySuccessToCertifiedRecovery`
- `testNativeBoundedOutlinesAndSingletonNormalBlendPreserveDirectText`
- `testNativeOutlineFontBoundsCannotCrossGridOutsideTheAdvanceBox`
- `testNativeDiscardedCurvesUnusedDashAndRestoredDashKeepTheVisibleTable`
- `testNativeVerifiedFilledArrowRetainsItsOriginalGeometryInStrictReaders`
- `testNativeDisjointFilledRulesAndDecorationsPreserveTextAndGeometryInEitherPaintOrder`
- `testNativeOverlappingFilledRulesNeverCompleteDeferredCapture`
- `testNativeLightBackgroundBeforeTextPreservesAcquisitionAndRejectsOverpaint`
- `testNativeBackgroundContrastCannotCertifyHiddenLowContrastOrLateBackgroundText`
- `testNativeBackgroundCannotEraseOrHideStructuralRules`
- `testNativeBackgroundOverprintRequiresKnownNormalCompositingAndRestoresGraphicsState`
- `testNativeInertTagsContainedClipsDeviceSpacesAndUnusedStylesPreserveDirectAcquisition`
- `testNativeConcealingClipsOptionalReplacementAndUnbalancedTagsRemainRejected`

## [tests/PDFTextGeometryTests+Colors.swift](../../tests/PDFTextGeometryTests+Colors.swift)

- `testPDFPaintNumbersExpandExponentsWithoutRoundingSmallValues`
- `testVisibleDeviceColorsKeepOriginalGlyphOrderAndCoordinates`
- `testNativeDeviceColorAssignmentsKeepOperationLimitAndCancellation`
- `testNativeVisibleDeviceCalibratedAndUnusedUnknownColorsPreserveAcquisition`
- `testNativeTrustedSRGBProfileSupportsExplicitAndDefaultColors`
- `testNativeInvalidUsedColorAndWhiteCalibratedTextRemainRejected`
- `testNativeMalformedMismatchedAndWhiteICCColorsDoNotCertifyText`
- `testNativeCMYKVisibilityMatchesFictionalRenderedTextIncludingFaintInk`

## [tests/StrictPDFCompatibilityTests.swift](../../tests/StrictPDFCompatibilityTests.swift)

- `testNormalDocumentModesPreserveEveryLessonTuple`
- `testSixExamPagesPreserveClassesDatesTimesAndEveryLessonTuple`
- `testReturnDocumentPreservesFirstDayAndOrdinaryDayTimes`

## [tests/test_pdf_branch_catalog.py](../../tests/test_pdf_branch_catalog.py)

- `test_document_matches_every_fixed_source_branch`
- `test_missing_reused_and_undeclared_branches_are_rejected`
