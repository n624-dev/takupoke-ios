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

    /// Match the merged-week source: the last makeup wins; otherwise the last row wins.
    /// All rows stay in `Slot.changes` for the detail view and change list.
    static func effectiveChange(_ changes: [ScheduleChange]) -> ScheduleChange? {
        changes.last { $0.isMakeup } ?? changes.last
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
                                   timeRange: analysis.timeRange(for: $0)) }
        }
        let base = plan.isNoClass || plan.isSupplementary || plan.apiTest || plan.apiTestReturn || specialDayApplies ? [] :
            lessons(on: day, className: className, analysis: timetable,
                    weekday: plan.weekdayOverride).filter { $0.period == period }
        let special = specialDayItems.filter { $0.lesson.period == period }
        let changes = includesChanges ? Self.changes(on: day, className: className, analysis: changes)
            .filter { $0.gridPeriods?.contains(period) == true } : []
        return Slot(baseLessons: base, specialLessons: special, changes: changes)
    }


}

enum ChangeRange: String, CaseIterable {
    case today = "今日以降"
    case week = "この週"
    case all = "全件"
}
