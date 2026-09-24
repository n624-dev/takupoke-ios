import Foundation

/// A read-only projection of the currently saved successful analyses.
/// It does not change the stored parsing result or infer school event rules.
enum TimetableSchedule {
    // Public timetable settings use a fixed first-year pairing. Local parser IDs
    // use underscores in place of the Web settings' hyphens.
    static let firstYearHomerooms: Set<String> = ["1_1", "1_2", "1_3"]
    static let firstYearDepartments: Set<String> = ["1_CN", "1_ES", "1_IT"]
    static let selectableClasses: [String] =
        ["1_1", "1_2", "1_3"] + (1...5).flatMap { year in
            ["CN", "ES", "IT"].map { "\(year)_\($0)" }
        } + ["AI_1", "AI_2"]
    static let normalPeriodTimes = [
        "08:50〜09:35", "09:35〜10:20", "10:30〜11:15", "11:15〜12:00",
        "12:50〜13:35", "13:35〜14:20", "14:30〜15:15", "15:15〜16:00"
    ]

    static func compatibleAdditionalClass(_ candidate: String, with primary: String) -> Bool {
        (firstYearHomerooms.contains(primary) && firstYearDepartments.contains(candidate)) ||
        (firstYearDepartments.contains(primary) && firstYearHomerooms.contains(candidate))
    }

    static func isInternationalStudentSubject(_ value: String) -> Bool {
        value.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix("留")
    }

    private static func isInternationalStudentSubject(_ value: String, className: String,
                                                       matchedByRule: ((String, String) -> Bool)?) -> Bool {
        isInternationalStudentSubject(value) ||
            (matchedByRule?(value, className) == true)
    }

    static func shouldDisplay(_ lesson: PDFLesson, isInternationalStudent: Bool,
                              matchedByRule: ((String, String) -> Bool)? = nil) -> Bool {
        isInternationalStudent || ![lesson.names.subject, lesson.names.subjectFullName ?? ""]
            .contains(where: { isInternationalStudentSubject($0, className: lesson.className, matchedByRule: matchedByRule) })
    }

    static func shouldDisplay(_ change: ScheduleChange, isInternationalStudent: Bool,
                              matchedByRule: ((String, String) -> Bool)? = nil) -> Bool {
        isInternationalStudent || ![change.before_subject, change.after_subject]
            .contains(where: { isInternationalStudentSubject($0, className: change.displayClassName, matchedByRule: matchedByRule) })
    }

    static func shouldDisplay(_ item: SpecialItem, isInternationalStudent: Bool,
                              matchedByRule: ((String, String) -> Bool)? = nil) -> Bool {
        isInternationalStudent || !isInternationalStudentSubject(item.lesson.subject,
            className: item.lesson.className, matchedByRule: matchedByRule)
    }

    struct SpecialItem {
        let kind: SpecialScheduleKind
        let lesson: SpecialScheduleLesson
        let timeRange: String?
    }

    struct Slot {
        let baseLessons: [PDFLesson]
        let specialLessons: [SpecialItem]
        let changes: [ScheduleChange]

        /// A change row names its date, class and period. All original lessons
        /// remain available for the detail sheet, including parallel lessons.
        var displayedLessons: [PDFLesson] { changes.isEmpty ? baseLessons : [] }
        var displayedSpecialLessons: [SpecialItem] { changes.isEmpty ? specialLessons : [] }
    }

    struct GridBlock {
        enum Content {
            case normal(PDFLesson)
            case special(SpecialItem)
            case change(ScheduleChange)
        }

        var startPeriod: Int
        var endPeriod: Int
        let content: Content
    }

    struct PositionedBlock {
        let block: GridBlock
        let lane: Int
    }

    static func blocks(on day: SchoolDate, className: String, timetable: PDFAnalysis?,
                       changes: ChangeAnalysis?, includesChanges: Bool, events: PDFAnalysis? = nil,
                       specials: [SpecialScheduleAnalysis] = [], isInternationalStudent: Bool = false,
                       matchedByRule: ((String, String) -> Bool)? = nil) -> [GridBlock] {
        var result: [GridBlock] = []
        for period in 1...8 {
            let item = slot(on: day, period: period, className: className, timetable: timetable,
                            changes: changes, includesChanges: includesChanges, events: events, specials: specials)
            for lesson in item.displayedLessons where shouldDisplay(lesson, isInternationalStudent: isInternationalStudent,
                                                                    matchedByRule: matchedByRule) {
                if let previous = result.indices.last(where: { index in
                    guard result[index].endPeriod == period - 1,
                          case .normal(let old) = result[index].content else { return false }
                    return old.names.subject == lesson.names.subject && old.names.teacher == lesson.names.teacher &&
                        old.names.room == lesson.names.room
                }) {
                    result[previous].endPeriod = period
                } else {
                    result.append(GridBlock(startPeriod: period, endPeriod: period, content: .normal(lesson)))
                }
            }
            for special in item.displayedSpecialLessons where shouldDisplay(special, isInternationalStudent: isInternationalStudent,
                                                                            matchedByRule: matchedByRule) {
                if let previous = result.indices.last(where: { index in
                    guard result[index].endPeriod == period - 1,
                          case .special(let old) = result[index].content else { return false }
                    return old.kind == special.kind && old.lesson.subject == special.lesson.subject &&
                        old.lesson.teacher == special.lesson.teacher && old.lesson.room == special.lesson.room
                }) {
                    result[previous].endPeriod = period
                } else {
                    result.append(GridBlock(startPeriod: period, endPeriod: period, content: .special(special)))
                }
            }
            for change in item.changes where shouldDisplay(change, isInternationalStudent: isInternationalStudent,
                                                            matchedByRule: matchedByRule) {
                if let covered = change.gridPeriods, covered.first == period, let last = covered.last {
                    result.append(GridBlock(startPeriod: period, endPeriod: last, content: .change(change)))
                }
            }
        }
        return result
    }

    /// Place overlapping cards in separate horizontal lanes within one class.
    static func positioned(_ blocks: [GridBlock]) -> [PositionedBlock] {
        var laneEnds: [Int] = []
        return blocks.enumerated().sorted {
            ($0.element.startPeriod, $0.offset) < ($1.element.startPeriod, $1.offset)
        }.map { _, block in
            let lane = laneEnds.firstIndex(where: { $0 < block.startPeriod }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(block.endPeriod) }
            else { laneEnds[lane] = block.endPeriod }
            return PositionedBlock(block: block, lane: lane)
        }
    }

    struct DayPlan {
        let events: [PDFSchoolEvent]
        let isNoClass: Bool
        let isSupplementary: Bool
        let weekdayOverride: Int?
        let apiNoClass: Bool
        let apiTest: Bool
        let apiTestReturn: Bool

        var noClassLabels: [String] {
            Array(Set(events.compactMap { event in
                guard event.classification?.needsReview == false,
                      let type = event.classification?.type,
                      type == .noClass || type == .schoolEventNoClass else { return nil }
                return event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty })).sorted()
        }
    }

    static func fullDayEventTitle(plan: DayPlan, layouts: [[PositionedBlock]]) -> String? {
        guard plan.isNoClass, layouts.allSatisfy(\.isEmpty) else { return nil }
        return plan.noClassLabels.isEmpty ? "授業なし" : plan.noClassLabels.joined(separator: "・")
    }

    static func classes(in state: MaterialLibraryState, specials: [SpecialScheduleAnalysis] = []) -> [String] {
        let lessonClasses = state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.lessons.map(\.className) ?? []
        let changeClasses = state.changeAnalysis?.records.map(\.displayClassName) ?? []
        let specialClasses = specials.flatMap(\.coveredClasses)
        return Set(lessonClasses + changeClasses + specialClasses).sorted()
    }

    static func termRange(for analysis: PDFAnalysis) -> SchoolDateRange? {
        let year = analysis.schoolYear
        switch analysis.term {
        case "前期":
            guard let start = SchoolDate(year: year, month: 4, day: 1),
                  let end = SchoolDate(year: year, month: 10, day: 1) else { return nil }
            return SchoolDateRange(start: start, endExclusive: end)
        case "後期":
            guard let start = SchoolDate(year: year, month: 10, day: 1),
                  let end = SchoolDate(year: year + 1, month: 4, day: 1) else { return nil }
            return SchoolDateRange(start: start, endExclusive: end)
        default:
            return nil
        }
    }

    static func lessons(on day: SchoolDate, className: String, analysis: PDFAnalysis?,
                        weekday: Int? = nil) -> [PDFLesson] {
        guard let analysis, termRange(for: analysis)?.contains(day) == true else { return [] }
        return analysis.lessons.filter { $0.className == className && $0.weekday == (weekday ?? day.schoolWeekday) }
            .sorted { $0.period < $1.period }
    }

    static func events(on day: SchoolDate, analysis: PDFAnalysis?) -> [PDFSchoolEvent] {
        (analysis?.events ?? []).filter { event in
            guard let start = SchoolDate(iso8601: event.date) else { return false }
            if start == day { return true }
            guard !event.periodNeedsReview, let endText = event.endDate,
                  let end = SchoolDate(iso8601: endText), end >= start else { return false }
            return start < day && day <= end
        }
    }

    static func dayPlan(on day: SchoolDate, events analysis: PDFAnalysis?) -> DayPlan {
        let visible = events(on: day, analysis: analysis)
        let reliable = visible.compactMap { event -> PDFEventClassification? in
            guard event.classification?.needsReview == false else { return nil }
            return event.classification
        }
        let noClass = reliable.contains { $0.type == .noClass || $0.type == .schoolEventNoClass }
        let supplementary = reliable.contains { $0.type == .supplementary }
        let overrides = Set(reliable.filter { $0.type == .weekdayOverride }.compactMap(\.scheduleDay))
        return DayPlan(events: visible, isNoClass: noClass, isSupplementary: supplementary,
                       weekdayOverride: overrides.count == 1 ? overrides.first : nil,
                       apiNoClass: visible.contains { $0.apiTag == "授業なし" || $0.apiTag == "行事（授業なし）" },
                       apiTest: visible.contains { $0.apiTag == "テスト" },
                       apiTestReturn: visible.contains { $0.apiTag == "テスト返却" })
    }

    static func changes(in analysis: ChangeAnalysis?, className: String, range: ChangeRange,
                        today: SchoolDate, weekStart: SchoolDate) -> [ScheduleChange] {
        guard let weekEnd = weekStart.addingDays(7) else { return [] }
        return (analysis?.records ?? []).filter { change in
            guard change.displayClassName == className, let day = SchoolDate(iso8601: change.change_date) else { return false }
            switch range {
            case .today: return day >= today
            case .week: return day >= weekStart && day < weekEnd
            case .all: return true
            }
        }.sorted { ($0.change_date, $0.period) < ($1.change_date, $1.period) }
    }

    static func changes(on day: SchoolDate, className: String, analysis: ChangeAnalysis?) -> [ScheduleChange] {
        (analysis?.records ?? []).filter { $0.displayClassName == className && $0.change_date == day.iso8601 }
    }

    static func slot(on day: SchoolDate, period: Int, className: String, timetable: PDFAnalysis?,
                     changes: ChangeAnalysis?, includesChanges: Bool, events: PDFAnalysis? = nil,
                     specials: [SpecialScheduleAnalysis] = []) -> Slot {
        let plan = dayPlan(on: day, events: events)
        guard !plan.isNoClass || plan.apiNoClass else {
            return Slot(baseLessons: [], specialLessons: [], changes: [])
        }
        let specialDayApplies = specials.contains { $0.applies(date: day.iso8601, className: className) }
        let specialDayItems = specials.flatMap { analysis in
            analysis.lessons.filter { $0.date == day.iso8601 && $0.className == className }
                .map { SpecialItem(kind: analysis.kind, lesson: $0,
                                   timeRange: $0.timeRange) }
        }
        let base = plan.isNoClass || plan.isSupplementary || plan.apiTest || plan.apiTestReturn || specialDayApplies ? [] :
            lessons(on: day, className: className, analysis: timetable,
                    weekday: plan.weekdayOverride).filter { $0.period == period }
        let special = specialDayItems.filter { $0.lesson.period == period }
        let changes = includesChanges ? Self.changes(on: day, className: className, analysis: changes)
            .filter { $0.gridPeriods?.contains(period) == true } : []
        return Slot(baseLessons: base, specialLessons: special, changes: changes)
    }

    static func displayedDays(weekStart: SchoolDate, classes: [String], timetable: PDFAnalysis?,
                              changes: ChangeAnalysis?, events: PDFAnalysis?, includesChanges: Bool,
                              isInternationalStudent: Bool, specials: [SpecialScheduleAnalysis] = [],
                              matchedByRule: ((String, String) -> Bool)? = nil) -> [SchoolDate] {
        (0..<7).compactMap { weekStart.addingDays($0) }.filter { day in
            if day.schoolWeekday <= 5 { return true }
            let plan = dayPlan(on: day, events: events)
            if plan.isNoClass && !plan.apiNoClass { return false }
            return classes.contains { className in
                (1...8).contains { period in
                    let item = slot(on: day, period: period, className: className, timetable: timetable,
                                    changes: changes, includesChanges: includesChanges, events: events,
                                    specials: specials)
                    return item.displayedLessons.contains { shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                            matchedByRule: matchedByRule) } ||
                        item.displayedSpecialLessons.contains { shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                                   matchedByRule: matchedByRule) } ||
                        item.changes.contains { shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                               matchedByRule: matchedByRule) }
                }
            }
        }
    }

    static func isSameAcademicHalf(_ lhs: SchoolDate, _ rhs: SchoolDate) -> Bool {
        func key(_ day: SchoolDate) -> String {
            if (4...9).contains(day.month) { return "\(day.year):first" }
            return "\(day.month >= 10 ? day.year : day.year - 1):second"
        }
        return key(lhs) == key(rhs)
    }

    static func weekOverlapsAcademicHalf(start: SchoolDate, containing reference: SchoolDate) -> Bool {
        (0..<7).compactMap { start.addingDays($0) }
            .contains { isSameAcademicHalf($0, reference) }
    }

    /// The week buttons and calendar use the same contiguous range. A week
    /// overlapping the opening academic half is always reachable; later weeks
    /// are reachable only as long as each following week contains saved data.
    static func reachableWeekBounds(containing reference: SchoolDate, classes: [String],
                                    timetable: PDFAnalysis?, changes: ChangeAnalysis?,
                                    events: PDFAnalysis?, includesChanges: Bool,
                                    specials: [SpecialScheduleAnalysis] = []) -> ClosedRange<SchoolDate> {
        let firstHalf = (4...9).contains(reference.month)
        let startYear = firstHalf ? reference.year : (reference.month >= 10 ? reference.year : reference.year - 1)
        guard let halfStart = SchoolDate(year: startYear, month: firstHalf ? 4 : 10, day: 1),
              let endExclusive = SchoolDate(year: startYear + (firstHalf ? 0 : 1),
                                            month: firstHalf ? 10 : 4, day: 1),
              let lastDay = endExclusive.addingDays(-1) else {
            let week = reference.displayWeekStart
            return week...week
        }
        let lower = halfStart.monday
        var upper = max(lastDay.monday, reference.displayWeekStart)
        while let next = upper.addingDays(7), next.addingDays(6) != nil,
              hasWeekData(start: next, classes: classes, timetable: timetable,
                          changes: changes, events: events, includesChanges: includesChanges,
                          specials: specials) {
            upper = next
        }
        return lower...upper
    }

    static func hasWeekData(start: SchoolDate, classes: [String], timetable: PDFAnalysis?,
                            changes: ChangeAnalysis?, events: PDFAnalysis?, includesChanges: Bool,
                            specials: [SpecialScheduleAnalysis] = []) -> Bool {
        guard !classes.isEmpty else { return false }
        return (0..<7).compactMap { start.addingDays($0) }.contains { day in
            if !Self.events(on: day, analysis: events).isEmpty { return true }
            return classes.contains { className in
                (1...8).contains { period in
                    let slot = slot(on: day, period: period, className: className, timetable: timetable,
                                    changes: changes, includesChanges: includesChanges, events: events,
                                    specials: specials)
                    return !slot.displayedLessons.isEmpty || !slot.specialLessons.isEmpty || !slot.changes.isEmpty
                }
            }
        }
    }
}

enum ChangeRange: String, CaseIterable {
    case today = "今日以降"
    case week = "この週"
    case all = "全件"
}
