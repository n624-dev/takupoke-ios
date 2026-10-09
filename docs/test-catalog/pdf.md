# Strict PDF・文字・位置・罫線

対応ソース・テストのSHA-256：
`5bc294dc841b6d1cc7ddd1670a29aa2948a49d32ddfee2968791efdbe8377138`

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

## [tests/PDFParsingTests+Diagnostics.swift](../../tests/PDFParsingTests+Diagnostics.swift)

- `testTimetableFailureReportsLocationAndLineCountWithoutNames`（宣言行 12）
- `testTimetableGeometryReportReproducesFailureWithoutSourceText`（宣言行 26）
- `testGeometryDiagnosticHasBoundedSize`（宣言行 68）
- `testTraceCoversP01AndAllFailureStagesWithInvalidRectangles`（宣言行 78）
- `testTraceLimitsKeepStartupAndFinalFailureAndEncodeInvalidNumbers`（宣言行 104）
- `testFullDiagnosticCopyPreservesAllTextAndGeometryLosslessly`（宣言行 118）
- `testFailureStagesSurvivePageWrappingAndContainNoSourceText`（宣言行 148）
- `testOldFailureDecodesAndNewFailureRetainsOnlyFixedDiagnostic`（宣言行 175）
- `testPDFFailureReplacementAndManifestRollback`（宣言行 187）

## [tests/PDFParsingTests+Events.swift](../../tests/PDFParsingTests+Events.swift)

- `testCloseCalendarLinesKeepTheirOrderAndExplicitTags`（宣言行 12）
- `testTagsUseOnlyExplicitDeclarationsAndFlagConflicts`（宣言行 30）
- `testCalendarScopesDatesPeriodsAndYearBoundary`（宣言行 55）
- `testUnknownPeriodIsExplicitAndUnsupportedInputStops`（宣言行 71）
- `testConflictingPeriodAndMismatchedYearAreNotAccepted`（宣言行 93）

## [tests/PDFParsingTests+PDFKit.swift](../../tests/PDFParsingTests+PDFKit.swift)

- `testIndependentOrderedRowSourcePDFsReachFormalOrRefuseWithoutOracleInput`（宣言行 14）
- `testVisibilityCollisionWorkAndCancellationAreBoundedWithinEachPaint`（宣言行 85）
- `testDisjointVisibilityCollisionIndexAvoidsTheFormerFullGlyphScan`（宣言行 109）
- `testPDFPathPaintPreservesFilledRulesAndUniqueArrow`（宣言行 119）
- `testPDFPathPaintPreservesStrokeRules`（宣言行 146）
- `testPDFPathPaintChecksCancellationWithinFillAndStroke`（宣言行 157）
- `testPDFPathPaintBoundsStemComparisonWork`（宣言行 176）
- `testPDFPathPaintBudgetIsCumulativeAcrossCallbacks`（宣言行 188）
- `testPDFKitTextSelectionsStayAlignedAcrossSpacesLinesAndRotations`（宣言行 209）
- `testPDFKitFullDiagnosticCollectsAllTextWhitespaceAndMultiplePages`（宣言行 273）
- `testPDFKitBridgeRecognizesFilledArrowGeometry`（宣言行 309）
- `testPDFKitBridgeReadsSyntheticPDFAndRotation`（宣言行 340）

## [tests/PDFParsingTests+Timetable.swift](../../tests/PDFParsingTests+Timetable.swift)

- `testRelativeTimetableOutsideViewportCannotBecomeStrictSuccess`（宣言行 12）
- `testTimetablePeriodsParallelLessonsAndEmptyRoom`（宣言行 20）
- `testTimetableRejectsUnalignedParallelEvidenceAcrossAnyTwoRoles`（宣言行 42）
- `testTimetableKeepsOneCompoundRoleLiteralWithoutInventingParallelTuples`（宣言行 55）
- `testTimetableRoomCollapsesOnlyRepeatedHalfwidthVoicingMarks`（宣言行 69）
- `testSourceOrderKeepsMixedSizeLessonNamesAndMetadataSeparate`（宣言行 93）
- `testTimetableJoinsAlignedNonoverlappingLineFragments`（宣言行 111）
- `testTimetableFragmentsDoNotMergeOverlapsOrNearbyDifferentLines`（宣言行 127）
- `testTimetableBoundaryOverhangRequiresForwardTextAndGeometry`（宣言行 146）
- `testCharacterBoundsKeepNeighbouringCellsOutOfTimetable`（宣言行 171）
- `testCharacterGeometryValidatesUTF16RangesAndDoesNotDropInvalidBounds`（宣言行 218）
- `testRemovingDisplayBreaksPreservesStoredLessonFields`（宣言行 243）
- `testAmbiguousSourceOrderStopsInsteadOfFallingBackToCoordinates`（宣言行 254）
- `testDamagedClassAndUnalignedParallelFieldsStopWholeTable`（宣言行 263）

## [tests/PDFTextGeometryTests.swift](../../tests/PDFTextGeometryTests.swift)

- `testCollisionIndexMatchesInclusiveBruteForceAcrossWidthsPadsAndBoundaryContacts`（宣言行 13）
- `testCollisionIndexKeepsDenseDisjointTableSearchInsideOneOriginalPaintBudget`（宣言行 37）
- `testCollisionIndexChargesConstructionSearchAndPreservesThrownCancellation`（宣言行 56）
- `testStrokePaddingRequiresAnExactAnglePreservingTransform`（宣言行 77）
- `testOnlyFilledTextModeHasAnIndependentGlyphExtentProof`（宣言行 85）
- `testViewportChecksWholeGlyphsRulesAndFiniteEndpointSums`（宣言行 91）
- `testStrictStrokeWidthBoundsIncludeTransformsAndHairlines`（宣言行 106）
- `testStrictDeviceColorsRequireVisibleBlackComponents`（宣言行 115）
- `testRecoveryRetainsDrawnSpacesWithoutChangingStrictGlyphs`（宣言行 133）
- `testFullTwoByteSingletonCodeDomainRemainsBoundedAndCancellable`（宣言行 150）
- `testUnicodeCharactersRangesAndSurrogatePairs`（宣言行 167）
- `testMalformedOrUnsupportedUnicodeMapsFailClosed`（宣言行 178）
- `testUnusedControlMappingsAreMetadataButDrawingThemFailsClosed`（宣言行 193）
- `testUnusedUnsupportedFontStateAndGraphicsRestorePreserveReadableGlyphs`（宣言行 212）
- `testEmptyShowRequiresSelectedValidTextStateAndRetainsCancellation`（宣言行 227）
- `testSpacingAndTJKeepAdjacentCellsSeparate`（宣言行 243）
- `testCompositeCode32DoesNotApplyWordSpacing`（宣言行 263）
- `testTransformsRiseScalingAndSavedGraphicsState`（宣言行 274）
- `testLineMatrixMovesIndependentlyOfStringAdvance`（宣言行 299）
- `testCoverageRejectsDroppedDuplicatedOrChangedText`（宣言行 316）
- `testUnsafeTextStateAndCancellationFailClosed`（宣言行 328）
- `testNativeExplicitFontAndUnicodeResourcesDecodeIndependently`（宣言行 355）
- `testNativeNearAxisMiterAndNonSimilarStrokeCannotCertifyPaintBounds`（宣言行 462）
- `testNativeCrossedOrRetracedThinFillIsNotARectangularBorder`（宣言行 495）
- `testNativeWhiteTextAndOpaqueRepaintUseRasterInsteadOfSelectableText`（宣言行 530）
- `testNativeCroppedOutBodyCannotBecomeCompleteInput`（宣言行 571）
- `testNativeOffCanvasSelectableTextCannotBecomeCompleteInput`（宣言行 616）
- `testNativeThinStrokeCannotCrossAcquiredGlyphs`（宣言行 633）
- `testNativeOutlinedTextUsesCompositedRasterInsteadOfSelectionBounds`（宣言行 644）
- `testNativeDashedGhostRulesCannotBecomeACompleteTable`（宣言行 658）
- `testNativeSpecialVisibilityScanRejectsHiddenAndUnverifiedText`（宣言行 691）
- `testNativeSpecialVisibilityScanAllowsOpaqueTextAndRules`（宣言行 716）
- `testNativeResourcesAndTJThroughPDFKitBridge`（宣言行 727）
- `testNativeMissingMappingAndReplacementContentFailClosed`（宣言行 744）
- `testNativeUnusedUnsupportedFontSetupAllowsCompleteReadableTextButUseRejects`（宣言行 756）
