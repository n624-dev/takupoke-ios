# 時間割・今日の予定・授業時刻・授業名

対応関係・宣言名・実行方法のSHA-256：
`5e7728994754a748928409c19bb9fce60a19eb445396165a747ff1a8a6c4af5b`

環境：Linux Swift／Apple Native（PDFKit・VisionはApple限定）

```bash
bash tools/test-parsing.sh
python3 -B -m unittest discover -s tests -p test_timetable_change_names.py
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
- [Takupoke/TimetableRenderCache.swift](../../Takupoke/TimetableRenderCache.swift)
- [Takupoke/TimetableBoundaryClock.swift](../../Takupoke/TimetableBoundaryClock.swift)

## [tests/HomeScheduleTests.swift](../../tests/HomeScheduleTests.swift)

- `testHomeClockPublishesCardBoundariesAndJapaneseMidnightWithoutPeriodicTicks`
- `testHomeClockHandlesTimeJumpsAndUsesFreshDateForChangedSourcePlans`
- `testConfigureCannotConsumeAnUnpublishedStartOrEndBoundary`
- `testBoundaryPlanKeepsNormalBreaksAndOnlyVerifiedSpecialContinuity`
- `testOverlappingSpecialCardsRetainIndividualClocksAndProgressWhileCommonAndChangeStayAmbiguous`
- `testMergedSpecialCardClocksUseOnlyTheirOwnDocumentAndNeverBorrowMissingTimes`
- `testFragmentsOfMergedSpecialsUseOnlyVerifiedIndividualClocks`
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

- `testHiddenInternationalCancellationPreservesOrdinaryLessonsAndClock`
- `testHiddenChangesDoNotOverrideVisibleCancellationOrMakeupPriority`
- `testHiddenCancellationPreservesSpecialLessonsWithoutFillingSpecialBlanks`
- `testHiddenCancellationKeepsWeekendWithWeekdayOverrideVisible`
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
- `testConflictingWeekdayOverridesWarnPreserveTagsAndFallBackToRealWeekday`

## [tests/TimetableScheduleTests.swift](../../tests/TimetableScheduleTests.swift)

- `testWeekRangeRetainsBothDatesAtNarrowWidths`
- `testWeekPullCentersOnVisibleLessonsAndContinuesFromNativeEdge`
- `testWeekBadgeHasClearanceOnBothEdgesAndInShortOrScrolledBodies`
- `testLivePageHandoffPreservesTheReleasedContentPosition`
- `testWeekPullConsumesHiddenColumnsAndUsesTheFinalFingerPosition`
- `testWeekPreparationIncludesTheWeekBeyondArrivalAndStaysBounded`
- `testEachWeekPullWaitsForItsOwnReadyPageAndCommitsOnce`
- `testEarlyContactsKeepTheirDisplacementsWhileTheNextScrollViewPrepares`
- `testBoundedRenderingMemoKeepsNilAndExactUnicodeInputs`
- `testCommonClockCacheSeparatesDisplayScopeAndStopsAtRetentionBoundary`
- `testAcceptedSourceIndexMatchesOriginalSelectorsAndBlocksAcrossScopes`
- `testProjectionCacheUsesGenerationAndSuspendsBeforeRebuilding`
- `testTermBoundariesAndUnknownTermNeverReuseOldLessons`
- `testSelectableClassesIncludeAbsentKnownClasses`
- `testOnlyFixedFirstYearPairCanBeAdded`
- `testInternationalStudentFilterUsesNormalizedSubjectPrefix`
- `testInternationalStudentMappingFlagHidesNonPrefixedSubjectsAcrossSources`
- `testWeekSlideClockKeepsNormalDurationAndLimitsSingleFrameCatchup`
- `testAcademicHalfNavigationUsesMondayAndKnownWeekData`
- `testPreviousWeekCanCrossBoundaryWhenPartOfWeekIsInCurrentHalf`
- `testOctoberOpeningKeepsSeptemberBoundaryWhenPickingAnotherWeek`
- `testReachableWeeksExtendThroughConsecutiveSavedWeeksAndAllowReturning`

## [tests/TimetableTimesServiceTests.swift](../../tests/TimetableTimesServiceTests.swift)

- `testPublicConditionalRevision`
- `testAuthenticatedDownloadAndChangedRevisionRejection`
- `testUnreadableSavedTimesStayReportedUntilValidatedDownload`

## [tests/TimetableTimesTests.swift](../../tests/TimetableTimesTests.swift)

- `testDateSpecificTimeAndContinuousRange`
- `testWeekColumnHidesConflictingClockAndIgnoresEmptyDays`
- `testPDFClockHasPriorityOverAPIClock`
- `testMalformedTimesAreRejected`

## [tests/test_timetable_change_names.py](../../tests/test_timetable_change_names.py)

- `test_home_subject_rendering_uses_formal_name_for_all_content_kinds_without_changing_cell_names`
- `test_list_uses_formal_names_for_explicit_and_inferred_subjects_with_source_fallback`

## [tests/TimetableModelTests.swift](../../tests/TimetableModelTests.swift)

- `testActualLinksModelSharesOwnedURLSessionAcrossAutomaticAndManualWaiters`
- `testFailedLinkRevisionRetainsUnreadableCacheWarningAndBytes`
- `testLinkDownloadDistinguishesUnavailableInvalidAndChangedResponses`
- `testCorruptTimeCachesCanBeReplacedAndReopened`
- `testFailedTimeDownloadsPreserveCorruptCacheAndOfferRetry`
- `testUnavailableDirectoryAndFailedSaveNeverPublishSuccess`
- `testDisjointChangeDetailsFindOriginalsAndRelatedChangesWithoutChangingGrid`

## [tests/MappingRulesTests.swift](../../tests/MappingRulesTests.swift)

- `testExactSubjectSpellingResolvesContextDespiteAnotherWidthEquivalentAlias`
- `testExplicitOrdinarySubjectIsNeverHiddenByAnOmittedInternationalPrefix`
- `testConditionalTeacherUsesExactThenUniqueWidthMatchWithinItsContext`
- `testOmittedInternationalShortSubjectStillResolvesItsConditionalTeacher`
- `testContextualInternationalChangesUseTheirOwnClassAndSchoolYearBeforeReplacement`
- `testNameMatchingAcceptsWidthVariantsAndKeepsSourceSpelling`
- `testWidthEquivalentAliasesDoNotResolveAnAmbiguousName`
- `testClassSpecificWidthEquivalentSubjectPrecedesGenericExactAlias`
- `testCommaSeparatedTeachersAndRoomsMapMembersAndRetainSeparators`
- `testPartialMetadataKeepsUnknownNamesOrderWhitespaceAndEmptyMembers`
- `testWholeFieldAliasPrecedesMemberMappingAndSubjectIsNotSplit`
- `testChangeSuffixRequiresAllMembersToHaveOneConfirmedRole`
- `testContextualTeacherWithinListRequiresMatchingYearClassAndSubject`
- `testParentheticalCommaIsNotSplitAndBothChangeSidesAreMapped`
- `testContextualTeacherAndConfirmedRoomSeparateInEitherSuffixOrder`
- `testChangeComparisonReportsOnlyConfirmedDifferencesAndKeepsCandidatesByPeriod`

## [tests/TimetableClockEvidenceTests.swift](../../tests/TimetableClockEvidenceTests.swift)

- `testChangeVisualMergesRespectBreaksAndLunchWithDefaultAndCustomClocks`
- `testIndependentSpecialCellsKeepTheirGapWhenVisuallyMerged`
- `testHiddenSpecialLessonDoesNotRemoveTheVisibleCommonClock`
- `testChangeClockRemainsUnknownWhenOneRequiredSpecialKindIsMissing`
- `testChangeCommonClockChecksApplicableDocumentsWithEmptyPeriod`
- `testWholeSpecialReplacementPreservesRecordedContinuousClockAndDetailBoundaries`
- `testPartialReplacementAndUnrecordedWholeRangeUseOnlyVerifiedPeriodClocks`
- `testWholeReplacementRequiresEveryApplicableDocumentToAgree`
- `testNormalVisualMergesRespectBreaksAndLunchWithDefaultAndDateSpecificClocks`
