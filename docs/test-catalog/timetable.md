# 時間割・今日の予定・授業時刻・授業名

対応ソース・テストのSHA-256：
`41a0facd44ae4ff462c041aaa86d3be432045a8000fc7f50f9561d75bd289ceb`

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

- `testChangeDetailsJoinSeparateExamSlotsAndKeepDisjointPeriodsSeparate`（宣言行 41）
- `testJapaneseDayAtMidnightAndWeekendWeek`（宣言行 70）
- `testAllDayKeepsEndedMergedLessonsAndChecksExactClockBoundaries`（宣言行 78）
- `testChangesWinAndCancellationIsNeverInProgress`（宣言行 95）
- `testExamAndReturnKeepOwnTimesIncludingReplacements`（宣言行 114）
- `testMissingExamNeverBorrowsNormalClockAndWarnsEvenWithChanges`（宣言行 133）
- `testMissingTermClassAndNoClassEventAreDistinct`（宣言行 145）
- `testMappedInternationalSubjectFilterIsShared`（宣言行 160）

## [tests/TimetableNameTests.swift](../../tests/TimetableNameTests.swift)

- `testAccessibleLessonKeepsFullNamesAndFieldMeanings`（宣言行 6）
- `testChangeSubjectTriesOneLineSpellingBeforeWrappingWithoutTruncation`（宣言行 17）
- `testPeriodTimeUsesThreeCenteredLines`（宣言行 32）
- `testHalfwidthKatakanaChangesOnlyAtPresentationBoundary`（宣言行 38）
- `testBothFormsSurviveSavingAndDisplayWithoutChangingSource`（宣言行 51）
- `testPartialMappingFallsBackIndependentlyForEachField`（宣言行 69）
- `testIndependentLessonsKeepMissingMetadataAfterRoundTrip`（宣言行 86）

## [tests/TimetableScheduleTests+Blocks.swift](../../tests/TimetableScheduleTests+Blocks.swift)

- `testMatchingAdjacentNormalAndExamLessonsBecomeSpanningCards`（宣言行 5）
- `testSpecialDocumentsMergeBySlotAndChangesRetainBothOriginals`（宣言行 51）

## [tests/TimetableScheduleTests+Changes.swift](../../tests/TimetableScheduleTests+Changes.swift)

- `testChangeRangesUseDatesWithoutDiscardingPastRows`（宣言行 5）
- `testChangePeriodDisplayKeepsCombinedSourceValue`（宣言行 24）
- `testMergedSlotReplacesPeriodButRetainsOriginalForDetails`（宣言行 37）
- `testConsecutiveChangeNotationCoversBothPeriodsWithoutChangingSource`（宣言行 56）
- `testMakeupWinsSharedPeriodAndOtherRowsRemainAvailable`（宣言行 87）
- `testLastChangeWinsWithoutMakeupAndOverlappingWinnersSplitCards`（宣言行 122）
- `testOverlappingChangesUseSeparateLanes`（宣言行 146）
- `testSeventhAndEighthPeriodSpanKeepsSeparateEighthPeriodInAnotherLane`（宣言行 160）

## [tests/TimetableScheduleTests+Events.swift](../../tests/TimetableScheduleTests+Events.swift)

- `testExplicitCalendarTagsAffectWeekWithoutChangingParsedEvents`（宣言行 5）
- `testUncertainEventRangeOnlyAffectsKnownStartDay`（宣言行 36）
- `testApiNoClassKeepsChangesWhileExamTagSuppressesOrdinaryLessons`（宣言行 51）
- `testFullDayEventCardAppearsOnlyWhenNoLessonIsDisplayed`（宣言行 78）
- `testWeekendEventAndSupplementaryDaysAppearWithoutLessons`（宣言行 113）
- `testWeekendMemoAndPlainNoClassTagDoNotAddColumns`（宣言行 145）
- `testWeekdaySupplementaryCardAndHeaderAvoidDuplicateTitles`（宣言行 159）

## [tests/TimetableScheduleTests.swift](../../tests/TimetableScheduleTests.swift)

- `testTermBoundariesAndUnknownTermNeverReuseOldLessons`（宣言行 13）
- `testSelectableClassesIncludeAbsentKnownClasses`（宣言行 29）
- `testOnlyFixedFirstYearPairCanBeAdded`（宣言行 37）
- `testInternationalStudentFilterUsesNormalizedSubjectPrefix`（宣言行 46）
- `testInternationalStudentMappingFlagHidesNonPrefixedSubjectsAcrossSources`（宣言行 83）
- `testAcademicHalfNavigationUsesMondayAndKnownWeekData`（宣言行 110）
- `testPreviousWeekCanCrossBoundaryWhenPartOfWeekIsInCurrentHalf`（宣言行 128）
- `testOctoberOpeningKeepsSeptemberBoundaryWhenPickingAnotherWeek`（宣言行 139）
- `testReachableWeeksExtendThroughConsecutiveSavedWeeksAndAllowReturning`（宣言行 150）

## [tests/TimetableTimesServiceTests.swift](../../tests/TimetableTimesServiceTests.swift)

- `testPublicConditionalRevision`（宣言行 35）
- `testAuthenticatedDownloadAndChangedRevisionRejection`（宣言行 43）

## [tests/TimetableTimesTests.swift](../../tests/TimetableTimesTests.swift)

- `testDateSpecificTimeAndContinuousRange`（宣言行 20）
- `testWeekColumnHidesConflictingClockAndIgnoresEmptyDays`（宣言行 28）
- `testPDFClockHasPriorityOverAPIClock`（宣言行 35）
- `testMalformedTimesAreRejected`（宣言行 46）
