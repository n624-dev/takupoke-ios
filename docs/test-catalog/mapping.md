# 名称対応・パッケージ・認証取得

対応関係・宣言名・実行方法のSHA-256：
`2781195a2b40a0bf7a45f991d9464a26a0fabdb0fc53b711be28876e40551dee`

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

## [tests/MappingServiceTests.swift](../../tests/MappingServiceTests.swift)

- `testRevisionCheckUsesConditionalRequestAndNoCredentials`
- `testChangedRevisionDoesNotDownloadZip`
- `testDifferentPrivateRevisionCannotBeAdopted`
- `testBothRevisionEndpointsDistinguishMissingSameAndChangedData`
- `testRevisionFailureIsNotReportedAsCurrentForEitherEndpoint`

## [tests/LinksTests.swift](../../tests/LinksTests.swift)

- `testLateSearchTermsRemainMatchesWithExactPrefixAndSubstringPriority`
- `testAllPrivateResourceCombinationsUseOneAppropriateAuthentication`
- `testSyllabusDepartmentOnlyResolvesKnownLinkAndUsesCalendarYear`
- `testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary`
- `testRecommendationsRespectVisibilityAndAstroOrdering`
- `testValidatesResponseBeforeAdoptingIt`
- `testWeakETagComparisonPreservesOpaqueEmbeddedMarker`
- `test200304AndFailureKeepPreviousResult`
- `testCacheReplacementOnlyAfterValidSave`
- `testPreferencesFollowIDAndRetainMissingItems`
- `testSearchMatchesKanaRomajiAndRanking`
