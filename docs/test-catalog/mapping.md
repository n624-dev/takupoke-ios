# 名称対応・パッケージ・認証取得

対応関係・宣言名・実行方法のSHA-256：
`007b4e5d4cda059b086de78df2401b9ec4dc671b1a999a3f2bbc041e41934b71`

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
