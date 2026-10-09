# 名称対応・パッケージ・認証取得

対応ソース・テストのSHA-256：
`2aeb01fcd4d5d0a76e8f559948768fda156f303a0a48a08d81b5a6656460b4c6`

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

- `testValidatedPackageAppliesExactRulesWithoutChangingSourceNames`（宣言行 43）
- `testInvalidNewPackageCannotReplaceSavedPackage`（宣言行 58）
- `testDuplicateExactRuleIsRejected`（宣言行 74）
- `testInternationalStudentMarkerAlsoMatchesUnmarkedSubjectInMappedClass`（宣言行 83）
- `testChangeFieldSeparatesOnlyMappedTrailingTeacherAndRoom`（宣言行 104）
- `testChangePresentationSeparatesBothSidesAndKeepsSourceFields`（宣言行 121）
- `testContextualTeacherSplitsOnlyMatchingYearClassAndSubject`（宣言行 138）
- `testChangeShortSubjectUsesOnlyOneAliasFromSameClass`（宣言行 165）

## [tests/MappingRulesTests.swift](../../tests/MappingRulesTests.swift)

- `testNameMatchingAcceptsWidthVariantsAndKeepsSourceSpelling`（宣言行 31）
- `testWidthEquivalentAliasesDoNotResolveAnAmbiguousName`（宣言行 49）
- `testClassSpecificWidthEquivalentSubjectPrecedesGenericExactAlias`（宣言行 64）
- `testCommaSeparatedTeachersAndRoomsMapMembersAndRetainSeparators`（宣言行 78）
- `testPartialMetadataKeepsUnknownNamesOrderWhitespaceAndEmptyMembers`（宣言行 94）
- `testWholeFieldAliasPrecedesMemberMappingAndSubjectIsNotSplit`（宣言行 108）
- `testChangeSuffixRequiresAllMembersToHaveOneConfirmedRole`（宣言行 121）
- `testContextualTeacherWithinListRequiresMatchingYearClassAndSubject`（宣言行 138）
- `testParentheticalCommaIsNotSplitAndBothChangeSidesAreMapped`（宣言行 156）

## [tests/MappingServiceTests.swift](../../tests/MappingServiceTests.swift)

- `testRevisionCheckUsesConditionalRequestAndNoCredentials`（宣言行 51）
- `testChangedRevisionDoesNotDownloadZip`（宣言行 58）
- `testDifferentPrivateRevisionCannotBeAdopted`（宣言行 65）
- `testBothRevisionEndpointsDistinguishMissingSameAndChangedData`（宣言行 75）
- `testRevisionFailureIsNotReportedAsCurrentForEitherEndpoint`（宣言行 92）
