import Foundation

/// A read-only projection of the currently saved successful analyses.
/// It does not change the stored parsing result or infer school event rules.
enum TimetableSchedule {
    struct Slot {
        let baseLessons: [PDFLesson]
        let changes: [ScheduleChange]

        /// A change row names its date, class and period. All original lessons
        /// remain available for the detail sheet, including parallel lessons.
        var displayedLessons: [PDFLesson] { changes.isEmpty ? baseLessons : [] }
    }

    static func classes(in state: MaterialLibraryState) -> [String] {
        let lessonClasses = state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.lessons.map(\.className) ?? []
        let changeClasses = state.changeAnalysis?.records.map(\.displayClassName) ?? []
        return Set(lessonClasses + changeClasses).sorted()
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

    static func lessons(on day: SchoolDate, className: String, analysis: PDFAnalysis?) -> [PDFLesson] {
        guard let analysis, termRange(for: analysis)?.contains(day) == true else { return [] }
        return analysis.lessons.filter { $0.className == className && $0.weekday == day.schoolWeekday }
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
                     changes: ChangeAnalysis?, includesChanges: Bool) -> Slot {
        let base = lessons(on: day, className: className, analysis: timetable).filter { $0.period == period }
        let changes = includesChanges ? Self.changes(on: day, className: className, analysis: changes)
            .filter { Int($0.period) == period } : []
        return Slot(baseLessons: base, changes: changes)
    }
}

enum ChangeRange: String, CaseIterable {
    case today = "今日以降"
    case week = "この週"
    case all = "全件"
}
