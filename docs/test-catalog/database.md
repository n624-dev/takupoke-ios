# ローカルDB・移行・半期削除

対応関係・宣言名・実行方法のSHA-256：
`5edddb8fd8475b22b64dd3488897a81a390b051ecd026b7dba24143ccab4c787`

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
- `testHalfYearDeletionPreservesPreferencesPublicEventsAndExternalOriginal`
