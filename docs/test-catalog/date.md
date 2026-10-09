# 日本時間・学校年度・日付表示

対応ソース・テストのSHA-256：
`32eb2eade97c7dab126b0e66d685dac4987a815447a1bddfc1592d77f3958be1`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/JapaneseDateDisplay.swift](../../Takupoke/JapaneseDateDisplay.swift)
- [Takupoke/SchoolDate.swift](../../Takupoke/SchoolDate.swift)

## [tests/JapaneseDateDisplayTests.swift](../../tests/JapaneseDateDisplayTests.swift)

- `testTimestampUsesJapaneseDateAcrossMidnightWithForeignDeviceZone`（宣言行 6）
- `testTimestampUsesNextSchoolYearDateWithForeignDeviceZone`（宣言行 20）

## [tests/SchoolDateTests.swift](../../tests/SchoolDateTests.swift)

- `testJapaneseSchoolYearAndAutomaticChangeYear`（宣言行 5）
- `testStrictCivilDateParsingAcrossLeapAndSchoolYearBoundary`（宣言行 15）
- `testApplicabilityBoundariesAndOverlap`（宣言行 26）
- `testMondayAndWeekNavigationAcrossYearBoundary`（宣言行 43）
- `testDisplayedWeekAdvancesOnWeekend`（宣言行 51）
