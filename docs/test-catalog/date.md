# 日本時間・学校年度・日付表示

対応関係・宣言名・実行方法のSHA-256：
`9e3b7f770d1025680e7d2dba34942b31ba2ad92a7b8c9ab84c7f14de192ffb24`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/JapaneseDateDisplay.swift](../../Takupoke/JapaneseDateDisplay.swift)
- [Takupoke/SchoolDate.swift](../../Takupoke/SchoolDate.swift)

## [tests/JapaneseDateDisplayTests.swift](../../tests/JapaneseDateDisplayTests.swift)

- `testTimestampUsesJapaneseDateAcrossMidnightWithForeignDeviceZone`
- `testTimestampUsesNextSchoolYearDateWithForeignDeviceZone`

## [tests/SchoolDateTests.swift](../../tests/SchoolDateTests.swift)

- `testJapaneseSchoolYearAndAutomaticChangeYear`
- `testInvalidNonemptyConfiguredYearNeverFallsBackToToday`
- `testStrictCivilDateParsingAcrossLeapAndSchoolYearBoundary`
- `testApplicabilityBoundariesAndOverlap`
- `testMondayAndWeekNavigationAcrossYearBoundary`
- `testDisplayedWeekAdvancesOnWeekend`
