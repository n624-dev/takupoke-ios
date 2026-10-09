# 時間割・今日の予定・授業時刻・授業名

対応関係・宣言名・実行方法のSHA-256：
`9ec000ea4b38edeecb3da04fccd889a432cd1589b02612922951059329dfabe6`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
```

## 変更時に確認するソース

- [Takupoke/TimetableDaySchedule.swift](../../Takupoke/TimetableDaySchedule.swift)
- [Takupoke/TimetableLessonNames.swift](../../Takupoke/TimetableLessonNames.swift)
- [Takupoke/TimetablePresentation+Details.swift](../../Takupoke/TimetablePresentation+Details.swift)
- [Takupoke/TimetablePresentation.swift](../../Takupoke/TimetablePresentation.swift)
- [Takupoke/TimetableSchedule+Blocks.swift](../../Takupoke/TimetableSchedule+Blocks.swift)
- [Takupoke/TimetableSchedule+Events.swift](../../Takupoke/TimetableSchedule+Events.swift)
- [Takupoke/TimetableSchedule+Weeks.swift](../../Takupoke/TimetableSchedule+Weeks.swift)
- [Takupoke/TimetableSchedule.swift](../../Takupoke/TimetableSchedule.swift)
- [Takupoke/TimetableTimes.swift](../../Takupoke/TimetableTimes.swift)
- [Takupoke/TimetableTimesModel.swift](../../Takupoke/TimetableTimesModel.swift)
- [Takupoke/TimetableTimesService.swift](../../Takupoke/TimetableTimesService.swift)

## [tests/HomeScheduleTests.swift](../../tests/HomeScheduleTests.swift)

- `testChangeDetailsJoinSeparateExamSlotsAndKeepDisjointPeriodsSeparate`
- `testJapaneseDayAtMidnightAndWeekendWeek`
- `testAllDayKeepsEndedMergedLessonsAndChecksExactClockBoundaries`
- `testChangesWinAndCancellationIsNeverInProgress`
- `testExamAndReturnKeepOwnTimesIncludingReplacements`
- `testMissingExamNeverBorrowsNormalClockAndWarnsEvenWithChanges`
- `testMissingTermClassAndNoClassEventAreDistinct`
- `testMappedInternationalSubjectFilterIsShared`

## [tests/TimetableNameTests.swift](../../tests/TimetableNameTests.swift)

- `testAccessibleLessonKeepsFullNamesAndFieldMeanings`
- `testChangeSubjectTriesOneLineSpellingBeforeWrappingWithoutTruncation`
- `testPeriodTimeUsesThreeCenteredLines`
- `testHalfwidthKatakanaChangesOnlyAtPresentationBoundary`
- `testBothFormsSurviveSavingAndDisplayWithoutChangingSource`
- `testPartialMappingFallsBackIndependentlyForEachField`
- `testIndependentLessonsKeepMissingMetadataAfterRoundTrip`

## [tests/TimetableScheduleTests+Blocks.swift](../../tests/TimetableScheduleTests+Blocks.swift)

- `testMatchingAdjacentNormalAndExamLessonsBecomeSpanningCards`
- `testSpecialDocumentsMergeBySlotAndChangesRetainBothOriginals`

## [tests/TimetableScheduleTests+Changes.swift](../../tests/TimetableScheduleTests+Changes.swift)

- `testChangeRangesUseDatesWithoutDiscardingPastRows`
- `testChangePeriodDisplayKeepsCombinedSourceValue`
- `testMergedSlotReplacesPeriodButRetainsOriginalForDetails`
- `testConsecutiveChangeNotationCoversBothPeriodsWithoutChangingSource`
- `testMakeupWinsSharedPeriodAndOtherRowsRemainAvailable`
- `testLastChangeWinsWithoutMakeupAndOverlappingWinnersSplitCards`
- `testOverlappingChangesUseSeparateLanes`
- `testSeventhAndEighthPeriodSpanKeepsSeparateEighthPeriodInAnotherLane`

## [tests/TimetableScheduleTests+Events.swift](../../tests/TimetableScheduleTests+Events.swift)

- `testExplicitCalendarTagsAffectWeekWithoutChangingParsedEvents`
- `testUncertainEventRangeOnlyAffectsKnownStartDay`
- `testApiNoClassKeepsChangesWhileExamTagSuppressesOrdinaryLessons`
- `testFullDayEventCardAppearsOnlyWhenNoLessonIsDisplayed`
- `testWeekendEventAndSupplementaryDaysAppearWithoutLessons`
- `testWeekendMemoAndPlainNoClassTagDoNotAddColumns`
- `testWeekdaySupplementaryCardAndHeaderAvoidDuplicateTitles`

## [tests/TimetableScheduleTests.swift](../../tests/TimetableScheduleTests.swift)

- `testTermBoundariesAndUnknownTermNeverReuseOldLessons`
- `testSelectableClassesIncludeAbsentKnownClasses`
- `testOnlyFixedFirstYearPairCanBeAdded`
- `testInternationalStudentFilterUsesNormalizedSubjectPrefix`
- `testInternationalStudentMappingFlagHidesNonPrefixedSubjectsAcrossSources`
- `testAcademicHalfNavigationUsesMondayAndKnownWeekData`
- `testPreviousWeekCanCrossBoundaryWhenPartOfWeekIsInCurrentHalf`
- `testOctoberOpeningKeepsSeptemberBoundaryWhenPickingAnotherWeek`
- `testReachableWeeksExtendThroughConsecutiveSavedWeeksAndAllowReturning`

## [tests/TimetableTimesServiceTests.swift](../../tests/TimetableTimesServiceTests.swift)

- `testPublicConditionalRevision`
- `testAuthenticatedDownloadAndChangedRevisionRejection`

## [tests/TimetableTimesTests.swift](../../tests/TimetableTimesTests.swift)

- `testDateSpecificTimeAndContinuousRange`
- `testWeekColumnHidesConflictingClockAndIgnoresEmptyDays`
- `testPDFClockHasPriorityOverAPIClock`
- `testMalformedTimesAreRejected`
