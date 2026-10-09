# リンク・検索・設定保持

対応関係・宣言名・実行方法のSHA-256：
`304fefe701feac01eb10cef748f20e25cc47e6297a03bde8cea06bf3474959ca`

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

- `testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary`
- `testRecommendationsRespectVisibilityAndAstroOrdering`
- `testValidatesResponseBeforeAdoptingIt`
- `testWeakETagComparisonPreservesOpaqueEmbeddedMarker`
- `test200304AndFailureKeepPreviousResult`
- `testCacheReplacementOnlyAfterValidSave`
- `testPreferencesFollowIDAndRetainMissingItems`
- `testSearchMatchesKanaRomajiAndRanking`
