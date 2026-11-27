# リンク・検索・設定保持

対応関係・宣言名・実行方法のSHA-256：
`78fa8a49e83fa9f96fe82bf788e66b66e06d54bd0800e37bd6580b273ff8271b`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B -m unittest discover -s tests -p test_links_model_lifecycle.py
```

## 変更時に確認するソース

- [Takupoke/BoundedHTTPResponse.swift](../../Takupoke/BoundedHTTPResponse.swift)
- [Takupoke/LinkSearch.swift](../../Takupoke/LinkSearch.swift)
- [Takupoke/LinksAPI.swift](../../Takupoke/LinksAPI.swift)
- [Takupoke/LinksModel.swift](../../Takupoke/LinksModel.swift)
- [Takupoke/LinksStore.swift](../../Takupoke/LinksStore.swift)
- [Takupoke/LinksView.swift](../../Takupoke/LinksView.swift)
- [tests/support_swift_http.py](../../tests/support_swift_http.py)

## [tests/BoundedHTTPResponseTests.swift](../../tests/BoundedHTTPResponseTests.swift)

- `testRejectsExcessiveDeclaredLengthBeforeReadingAnyBytes`
- `testUnknownAndUnderstatedLengthsBothStopAtFirstExcessByte`
- `testExactLimitAndEmptyRevisionResponsesRemainUsable`
- `testCancelledReaderDoesNotConsumeAnyPartOfTheResponse`
- `testAccountCommunicationBudgetCountsRequestsAndExcludesTimeBetweenThem`
- `testDeadlineEndsAnIntermittentTransferBeforeItsLateCompletion`
- `testExplicitCancellationRemainsDistinctFromDeadlineAndAllowsAnotherRead`

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

## [tests/test_links_model_lifecycle.py](../../tests/test_links_model_lifecycle.py)

- `test_corrupt_preferences_remain_visible_after_revision_success_and_can_be_reloaded`
