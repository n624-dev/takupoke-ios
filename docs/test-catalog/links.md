# リンク・検索・設定保持

対応関係・宣言名・実行方法のSHA-256：
`3c6991c22870e42133290498111184d7bac786f0ba821f68c5ba0f60def1eff7`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/LinkSearch.swift](../../Takupoke/LinkSearch.swift)
- [Takupoke/LinksAPI.swift](../../Takupoke/LinksAPI.swift)
- [Takupoke/LinksModel.swift](../../Takupoke/LinksModel.swift)
- [Takupoke/LinksStore.swift](../../Takupoke/LinksStore.swift)
- [Takupoke/LinksView.swift](../../Takupoke/LinksView.swift)

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
