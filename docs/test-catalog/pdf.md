# Strict PDF・文字・位置・罫線

対応関係・宣言名・実行方法のSHA-256：
`4fbedc5808f1ad435a18708bb2c2094671414b0ce2161ec6e15dd68d1710848e`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
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

## [tests/PDFParsingTests+Diagnostics.swift](../../tests/PDFParsingTests+Diagnostics.swift)

- `testTimetableFailureReportsLocationAndLineCountWithoutNames`
- `testTimetableGeometryReportReproducesFailureWithoutSourceText`
- `testGeometryDiagnosticHasBoundedSize`
- `testTraceCoversP01AndAllFailureStagesWithInvalidRectangles`
- `testTraceLimitsKeepStartupAndFinalFailureAndEncodeInvalidNumbers`
- `testFullDiagnosticCopyPreservesAllTextAndGeometryLosslessly`
- `testFailureStagesSurvivePageWrappingAndContainNoSourceText`
- `testOldFailureDecodesAndNewFailureRetainsOnlyFixedDiagnostic`
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

## [tests/PDFTextGeometryTests.swift](../../tests/PDFTextGeometryTests.swift)

- `testCollisionIndexMatchesInclusiveBruteForceAcrossWidthsPadsAndBoundaryContacts`
- `testCollisionIndexKeepsDenseDisjointTableSearchInsideOneOriginalPaintBudget`
- `testCollisionIndexChargesConstructionSearchAndPreservesThrownCancellation`
- `testStrokePaddingRequiresAnExactAnglePreservingTransform`
- `testOnlyFilledTextModeHasAnIndependentGlyphExtentProof`
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
- `testNativeInertTagsContainedClipsDeviceSpacesAndUnusedStylesPreserveDirectAcquisition`
- `testNativeConcealingClipsOptionalReplacementAndUnbalancedTagsRemainRejected`

## [tests/PDFTextGeometryTests+Colors.swift](../../tests/PDFTextGeometryTests+Colors.swift)

- `testVisibleDeviceColorsKeepOriginalGlyphOrderAndCoordinates`
- `testNativeVisibleDeviceCalibratedAndUnusedUnknownColorsPreserveAcquisition`
- `testNativeTrustedSRGBProfileSupportsExplicitAndDefaultColors`
- `testNativeInvalidUsedColorAndWhiteCalibratedTextRemainRejected`
- `testNativeMalformedMismatchedAndWhiteICCColorsDoNotCertifyText`
- `testNativeCMYKVisibilityMatchesFictionalRenderedTextIncludingFaintInk`
