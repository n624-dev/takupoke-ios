# 日本時間・学校年度・日付表示

対応関係・宣言名・実行方法のSHA-256：
`c92efb6636688d1fe4f1bc87e0370c30234ff6d99e164fed4a7ba81a5a20ef0e`

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
- `testStrictCivilDateParsingAcrossLeapAndSchoolYearBoundary`
- `testApplicabilityBoundariesAndOverlap`
- `testMondayAndWeekNavigationAcrossYearBoundary`
- `testDisplayedWeekAdvancesOnWeekend`
