# ローカルDB・移行・半期削除

対応関係・宣言名・実行方法のSHA-256：
`900a2a06cee25d40e3c1e6755fd6e40cb60e518ebfb1d09d91a92843880697f0`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/LegacyDatabaseMigration.swift](../../Takupoke/LegacyDatabaseMigration.swift)
- [Takupoke/LocalMaterialDatabase+Current.swift](../../Takupoke/LocalMaterialDatabase+Current.swift)
- [Takupoke/LocalMaterialDatabase+Legacy.swift](../../Takupoke/LocalMaterialDatabase+Legacy.swift)
- [Takupoke/LocalMaterialDatabase+Records.swift](../../Takupoke/LocalMaterialDatabase+Records.swift)
- [Takupoke/LocalMaterialDatabase+Schema.swift](../../Takupoke/LocalMaterialDatabase+Schema.swift)
- [Takupoke/LocalMaterialDatabase+Snapshot.swift](../../Takupoke/LocalMaterialDatabase+Snapshot.swift)
- [Takupoke/LocalMaterialDatabase.swift](../../Takupoke/LocalMaterialDatabase.swift)
- [Takupoke/SchoolDataRetention.swift](../../Takupoke/SchoolDataRetention.swift)
- [tests/LocalDatabaseTests.swift](../../tests/LocalDatabaseTests.swift)

## [tests/LocalDatabaseTests+Current.swift](../../tests/LocalDatabaseTests+Current.swift)

- `testAnalysisPDFURLUsesTheOriginalActuallyReferencedByTheSavedAnalysis`
- `testUnchangedAcquisitionOnlyReadsItsMetadataAndKeepsRollbackAndGenerationChecks`
- `testUnchangedPipelineCommitsOnlyAcquisitionMetadataOnTheLiveDatabase`
- `testCancellingTimetableReanalysisKeepsTheSameOriginalRecoveryJob`
- `testRowSkipConsentAndResultRollbackTogetherAndOldPayloadRemainsReadable`
- `testWeekdayConsentAndResultCommitTogetherAndRollbackTogether`
- `testRuntimeRoundTripAndRecordReordering`
- `testSameDigestAutomaticRefreshReusesOriginalAndPersistsUpdatedModificationDate`
- `testRuntimeKeepsOriginalForPreviousGoodAnalysisAndCollectsOnlyAfterRestart`
- `testRuntimeAcquisitionRollbackKeepsMemoryDatabaseAndOriginal`
- `testRuntimeAnalysisRollbackPreservesLastGoodRows`
- `testRuntimeRejectsStaleWriter`
- `testRuntimeReparseAndChangedYearPreserveDistinctInputConditions`
- `testRuntimeUnchangedResponseUpdatesValidatorsWithoutReplacingOriginal`
- `testFreshSQLiteCutoverIgnoresLegacyAndReopensWithoutReset`
- `testIncompleteInitializationAndOrphanFilesAreRecovered`
- `testMissingOrCorruptCurrentDatabaseDoesNotResetOrCollectFiles`
- `testRuntimeRejectsMissingCurrentOriginalWithoutErasingAnalysis`
- `testSecondRuntimeOwnerCannotCollectActiveStaging`
- `testRuntimeBindsReparseToExactAcquisitionEvenWhenBytesMatch`
- `testRuntimeProjectionCorruptionRefusesLoadAndWrite`
- `testFirstYearMoveCommitsOnlyDestinationAndRollbackKeepsOriginalLessons`

## [tests/LocalDatabaseTests+Legacy.swift](../../tests/LocalDatabaseTests+Legacy.swift)

- `testMigrationRoundTripRetainsParallelLessonsAndUnknownApplicability`
- `testOldAnalysisKeepsMissingOriginalInsteadOfNewFile`
- `testInterruptedPreparationOnlyRemovesOwnedCandidate`
- `testImportTransactionRollsBackAndCanRetry`
- `testUnreadableManifestIsNotReplacedOrInitialized`
- `testMissingFileAndTraversalFailWithoutDeletingLegacyCopies`
- `testSymlinkOriginalAndOverlappingRootsRejected`
- `testSourceChangedDuringPreparationIsNotReportedReady`
- `testDatabaseOpenDoesNotCreateMissingOrOverwriteFutureSchema`
- `testConstraintsRejectWrongKindMutationAndReferencedOriginalDeletion`
- `testReparseIdentityIncludesParserAndInputConditions`
- `testVerificationRejectsMissingRowsAndInconsistentProjection`
- `testEmptyArchiveMigratesWithoutPretendingThereAreNoChanges`

## [tests/SchoolDataRetentionTests.swift](../../tests/SchoolDataRetentionTests.swift)

- `testJapanBoundariesIncludeOctoberAndAprilButNotJanuary`
- `testDeletesOnlyOwnedPrivateDataAndCommitsPeriodAfterCleanup`
- `testFailureDoesNotCommitNewPeriodAndRetryCompletes`
- `testAutomaticMarkerRecoveryKeepsCurrentDataOrArchivesUnverifiedDataAndRetries`
- `testHalfYearDeletionPreservesPreferencesPublicEventsAndExternalOriginal`

## [tests/SchoolDataRecoveryTests.swift](../../tests/SchoolDataRecoveryTests.swift)

- `testMalformedMarkersRemainBlockedUntilExplicitQuarantineAndCleanup`
- `testReadFailureAndNonFileMarkerNeverOfferDestructiveRecovery`
- `testQuarantineFailureDoesNotDeleteMarkerOrPrivateData`
- `testInterruptedRecoveryAndDeletionFailureRetainEvidenceUntilRetryCommits`
- `testMarkerWriteFailureKeepsQuarantineAndNeverCommitsAPeriod`
