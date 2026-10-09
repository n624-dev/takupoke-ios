# リンク・検索・設定保持

対応ソース・テストのSHA-256：
`a2db25042858813c38d1a7160cedcb5661e44f0801149e2785cb38ed2f4e4f9e`

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

- `testLinkOpeningModeUsesHTTPSOnlyAndKeepsOverrideTemporary`（宣言行 8）
- `testRecommendationsRespectVisibilityAndAstroOrdering`（宣言行 28）
- `testValidatesResponseBeforeAdoptingIt`（宣言行 51）
- `testWeakETagComparisonPreservesOpaqueEmbeddedMarker`（宣言行 61）
- `test200304AndFailureKeepPreviousResult`（宣言行 66）
- `testCacheReplacementOnlyAfterValidSave`（宣言行 79）
- `testPreferencesFollowIDAndRetainMissingItems`（宣言行 90）
- `testSearchMatchesKanaRomajiAndRanking`（宣言行 107）
