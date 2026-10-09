# ローカルDB・移行・半期削除

対応ソース・テストのSHA-256：
`877e7eb968532874dcd3733732a5d5c4ce40d8091d3c6795704644fb5dc50a8a`

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

- `testRowSkipConsentAndResultRollbackTogetherAndOldPayloadRemainsReadable`（宣言行 7）
- `testWeekdayConsentAndResultCommitTogetherAndRollbackTogether`（宣言行 37）
- `testRuntimeRoundTripAndRecordReordering`（宣言行 57）
- `testSameDigestAutomaticRefreshReusesOriginalAndPersistsUpdatedModificationDate`（宣言行 76）
- `testRuntimeKeepsOriginalForPreviousGoodAnalysisAndCollectsOnlyAfterRestart`（宣言行 96）
- `testRuntimeAcquisitionRollbackKeepsMemoryDatabaseAndOriginal`（宣言行 118）
- `testRuntimeAnalysisRollbackPreservesLastGoodRows`（宣言行 135）
- `testRuntimeRejectsStaleWriter`（宣言行 151）
- `testRuntimeReparseAndChangedYearPreserveDistinctInputConditions`（宣言行 165）
- `testRuntimeUnchangedResponseUpdatesValidatorsWithoutReplacingOriginal`（宣言行 181）
- `testFreshSQLiteCutoverIgnoresLegacyAndReopensWithoutReset`（宣言行 196）
- `testIncompleteInitializationAndOrphanFilesAreRecovered`（宣言行 210）
- `testMissingOrCorruptCurrentDatabaseDoesNotResetOrCollectFiles`（宣言行 225）
- `testRuntimeRejectsMissingCurrentOriginalWithoutErasingAnalysis`（宣言行 238）
- `testSecondRuntimeOwnerCannotCollectActiveStaging`（宣言行 251）
- `testRuntimeBindsReparseToExactAcquisitionEvenWhenBytesMatch`（宣言行 260）
- `testRuntimeProjectionCorruptionRefusesLoadAndWrite`（宣言行 284）

## [tests/LocalDatabaseTests+Legacy.swift](../../tests/LocalDatabaseTests+Legacy.swift)

- `testMigrationRoundTripRetainsParallelLessonsAndUnknownApplicability`（宣言行 7）
- `testOldAnalysisKeepsMissingOriginalInsteadOfNewFile`（宣言行 29）
- `testInterruptedPreparationOnlyRemovesOwnedCandidate`（宣言行 48）
- `testImportTransactionRollsBackAndCanRetry`（宣言行 65）
- `testUnreadableManifestIsNotReplacedOrInitialized`（宣言行 78）
- `testMissingFileAndTraversalFailWithoutDeletingLegacyCopies`（宣言行 88）
- `testSymlinkOriginalAndOverlappingRootsRejected`（宣言行 101）
- `testSourceChangedDuringPreparationIsNotReportedReady`（宣言行 113）
- `testDatabaseOpenDoesNotCreateMissingOrOverwriteFutureSchema`（宣言行 125）
- `testConstraintsRejectWrongKindMutationAndReferencedOriginalDeletion`（宣言行 140）
- `testReparseIdentityIncludesParserAndInputConditions`（宣言行 156）
- `testVerificationRejectsMissingRowsAndInconsistentProjection`（宣言行 179）
- `testEmptyArchiveMigratesWithoutPretendingThereAreNoChanges`（宣言行 193）

## [tests/SchoolDataRetentionTests.swift](../../tests/SchoolDataRetentionTests.swift)

- `testJapanBoundariesIncludeOctoberAndAprilButNotJanuary`（宣言行 5）
- `testDeletesOnlyOwnedPrivateDataAndCommitsPeriodAfterCleanup`（宣言行 16）
- `testFailureDoesNotCommitNewPeriodAndRetryCompletes`（宣言行 35）
- `testHalfYearDeletionPreservesPreferencesPublicEventsAndExternalOriginal`（宣言行 56）
