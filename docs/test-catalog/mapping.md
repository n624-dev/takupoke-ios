# 名称対応・パッケージ・認証取得

対応関係・宣言名・実行方法のSHA-256：
`ad600b6446400c26cbd5361896c33936d18f9f27da83c93f18a4855fe8f092d1`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B -m unittest discover -s tests -p test_mapping_oidc_form.py -v
```

## 変更時に確認するソース

- [Takupoke/MappingIDTokenVerification.swift](../../Takupoke/MappingIDTokenVerification.swift)
- [Takupoke/MappingModel.swift](../../Takupoke/MappingModel.swift)
- [Takupoke/MappingModels.swift](../../Takupoke/MappingModels.swift)
- [Takupoke/MappingOIDC.swift](../../Takupoke/MappingOIDC.swift)
- [Takupoke/MappingPackage.swift](../../Takupoke/MappingPackage.swift)
- [Takupoke/MappingRules+Changes.swift](../../Takupoke/MappingRules+Changes.swift)
- [Takupoke/MappingRules.swift](../../Takupoke/MappingRules.swift)
- [Takupoke/MappingService.swift](../../Takupoke/MappingService.swift)
- [Takupoke/MappingSettingsView.swift](../../Takupoke/MappingSettingsView.swift)
- [Takupoke/MappingStore.swift](../../Takupoke/MappingStore.swift)

## [tests/BoundedHTTPResponseTests.swift](../../tests/BoundedHTTPResponseTests.swift)

- `testRejectsExcessiveDeclaredLengthBeforeReadingAnyBytes`
- `testUnknownAndUnderstatedLengthsBothStopAtFirstExcessByte`
- `testExactLimitAndEmptyRevisionResponsesRemainUsable`
- `testCancelledReaderDoesNotConsumeAnyPartOfTheResponse`
- `testAccountCommunicationBudgetCountsRequestsAndExcludesTimeBetweenThem`
- `testDeadlineEndsAnIntermittentTransferBeforeItsLateCompletion`
- `testExplicitCancellationRemainsDistinctFromDeadlineAndAllowsAnotherRead`

## [tests/MappingPackageTests.swift](../../tests/MappingPackageTests.swift)

- `testValidatedPackageAppliesExactRulesWithoutChangingSourceNames`
- `testListSelectionResolvesExplicitAndInferredSubjectsThroughInstalledMappings`
- `testInvalidNewPackageCannotReplaceSavedPackage`
- `testDuplicateExactRuleIsRejected`
- `testInternationalStudentMarkerAlsoMatchesUnmarkedSubjectInMappedClass`
- `testChangeFieldSeparatesOnlyMappedTrailingTeacherAndRoom`
- `testChangePresentationSeparatesBothSidesAndKeepsSourceFields`
- `testContextualTeacherSplitsOnlyMatchingYearClassAndSubject`
- `testChangeShortSubjectUsesOnlyOneAliasFromSameClass`
- `testScopedInternationalRuleSurvivesGenericExactAliasBeforeLessonReplacement`
- `testCorruptMappingPayloadAllowsRepairAndFailuresPreserveItsBytes`
- `testUnreadableMappingDatabaseCanBeReacquiredWithoutDiscardingItsOriginalBytes`
- `testMappingDatabaseReplacementProtectsChangedFilesAndLeavesSidecarsAlone`

## [tests/MappingRulesTests.swift](../../tests/MappingRulesTests.swift)

- `testExactSubjectSpellingResolvesContextDespiteAnotherWidthEquivalentAlias`
- `testExplicitOrdinarySubjectIsNeverHiddenByAnOmittedInternationalPrefix`
- `testLargeMappingKeepsOnlyRawRulesInStorageAndRebuildsForReplacedData`
- `testConditionalTeacherUsesExactThenUniqueWidthMatchWithinItsContext`
- `testOmittedInternationalShortSubjectStillResolvesItsConditionalTeacher`
- `testContextualInternationalChangesUseTheirOwnClassAndSchoolYearBeforeReplacement`
- `testNameMatchingAcceptsWidthVariantsAndKeepsSourceSpelling`
- `testWidthEquivalentAliasesDoNotResolveAnAmbiguousName`
- `testClassSpecificWidthEquivalentSubjectPrecedesGenericExactAlias`
- `testCommaSeparatedTeachersAndRoomsMapMembersAndRetainSeparators`
- `testPartialMetadataKeepsUnknownNamesOrderWhitespaceAndEmptyMembers`
- `testWholeFieldAliasPrecedesMemberMappingAndSubjectIsNotSplit`
- `testChangeSuffixRequiresAllMembersToHaveOneConfirmedRole`
- `testContextualTeacherWithinListRequiresMatchingYearClassAndSubject`
- `testParentheticalCommaIsNotSplitAndBothChangeSidesAreMapped`
- `testContextualTeacherAndConfirmedRoomSeparateInEitherSuffixOrder`
- `testChangeComparisonReportsOnlyConfirmedDifferencesAndKeepsCandidatesByPeriod`

## [tests/MappingServiceTests.swift](../../tests/MappingServiceTests.swift)

- `testRevisionCheckUsesConditionalRequestAndNoCredentials`
- `testChangedRevisionDoesNotDownloadZip`
- `testDifferentPrivateRevisionCannotBeAdopted`
- `testBothRevisionEndpointsDistinguishMissingSameAndChangedData`
- `testRevisionFailureIsNotReportedAsCurrentForEitherEndpoint`
- `testNotModifiedRequiresMatchingValidatorForAllPrivateResources`

## [tests/LinksTests.swift](../../tests/LinksTests.swift)

- `testRevisionWorkCoalescesForcedCallerAndCancelsOnlyItsOwnWait`
- `testCancellingTheLaterWaiterStillLetsTheFirstAcceptItsResponse`
- `testRevisionTTLForceFailureAndInstalledRevisionUseTheSameCoordinator`
- `testLastRevisionWaiterCancellationCancelsOwnerAndCannotInstallLateSuccess`
- `testRevisionResetRejectsOldGenerationWhileNewOwnerCompletes`
- `testStableLinkRowInputsIncludeEveryRenderedValueAndActionOwner`
- `testLateSearchTermsRemainMatchesWithExactPrefixAndSubstringPriority`
- `testPreparedSearchPreservesRankingOrderAndCurrentVisibilityAcrossQueries`
- `testAllPrivateResourceCombinationsUseOneAppropriateAuthentication`
- `testMappingIDTokenChecksClaimsClockAndRealSignatureSeparately`
- `testMappingAccessTokenCacheKeepsScopeAndExpirySeparate`
- `testSyllabusDepartmentOnlyResolvesKnownLinkAndUsesCalendarYear`
- `testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary`
- `testRecommendationsRespectVisibilityAndAstroOrdering`
- `testValidatesResponseBeforeAdoptingIt`
- `testWeakETagComparisonPreservesOpaqueEmbeddedMarker`
- `test200304AndFailureKeepPreviousResult`
- `testCacheReplacementOnlyAfterValidSave`
- `testUnknownLinkColorUsesTheStandardColorAndKeepsTheExactPublishedValue`
- `testAcceptedLinkResponseWithUnescapedSlashesSurvivesReload`
- `testPreferencesFollowIDAndRetainMissingItems`
- `testDamagedLinkPreferencesRestoreEachReadableValueAndKeepTheOriginal`
- `testSearchMatchesKanaRomajiAndRanking`

## [tests/test_mapping_oidc_form.py](../../tests/test_mapping_oidc_form.py)

- `test_browser_cancellation_authentication_and_transport_are_distinct`
- `test_exchange_preserves_opaque_code_in_form_body`
