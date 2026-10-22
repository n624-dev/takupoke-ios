# 日本時間・学校年度・日付表示

対応関係・宣言名・実行方法のSHA-256：
`f92c0df0b0fe51e65236b9a7b104f7ae063eb43e8f4d54f1d7dfea344bb1b8b5`

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
- `testUnknownConfiguredYearCannotMatchAttemptOrRequestAutomaticReanalysis`
