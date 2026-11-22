# 名称対応・パッケージ・認証取得

対応関係・宣言名・実行方法のSHA-256：
`b63d0510874c673ea564a23cc1509c096def7f738767e0eeb95212fe8ae2286f`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/MappingModel.swift](../../Takupoke/MappingModel.swift)
- [Takupoke/MappingModels.swift](../../Takupoke/MappingModels.swift)
- [Takupoke/MappingOIDC.swift](../../Takupoke/MappingOIDC.swift)
- [Takupoke/MappingPackage.swift](../../Takupoke/MappingPackage.swift)
- [Takupoke/MappingRules+Changes.swift](../../Takupoke/MappingRules+Changes.swift)
- [Takupoke/MappingRules.swift](../../Takupoke/MappingRules.swift)
- [Takupoke/MappingService.swift](../../Takupoke/MappingService.swift)
- [Takupoke/MappingSettingsView.swift](../../Takupoke/MappingSettingsView.swift)
- [Takupoke/MappingStore.swift](../../Takupoke/MappingStore.swift)

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

## [tests/MappingRulesTests.swift](../../tests/MappingRulesTests.swift)

- `testExactSubjectSpellingResolvesContextDespiteAnotherWidthEquivalentAlias`
- `testExplicitOrdinarySubjectIsNeverHiddenByAnOmittedInternationalPrefix`
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
- `testRevisionTTLForceFailureAndInstalledRevisionUseTheSameCoordinator`
- `testLastRevisionWaiterCancellationCancelsOwnerAndCannotInstallLateSuccess`
- `testRevisionResetRejectsOldGenerationWhileNewOwnerCompletes`
- `testStableLinkRowInputsIncludeEveryRenderedValueAndActionOwner`
- `testLateSearchTermsRemainMatchesWithExactPrefixAndSubstringPriority`
- `testPreparedSearchPreservesRankingOrderAndCurrentVisibilityAcrossQueries`
- `testAllPrivateResourceCombinationsUseOneAppropriateAuthentication`
- `testSyllabusDepartmentOnlyResolvesKnownLinkAndUsesCalendarYear`
- `testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary`
- `testRecommendationsRespectVisibilityAndAstroOrdering`
- `testValidatesResponseBeforeAdoptingIt`
- `testWeakETagComparisonPreservesOpaqueEmbeddedMarker`
- `test200304AndFailureKeepPreviousResult`
- `testCacheReplacementOnlyAfterValidSave`
- `testAcceptedLinkResponseWithUnescapedSlashesSurvivesReload`
- `testPreferencesFollowIDAndRetainMissingItems`
- `testSearchMatchesKanaRomajiAndRanking`
