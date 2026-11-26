import SwiftUI

@MainActor
struct TimetablePresentation {
    let schedule: TimetableDaySchedule
    let mappings: MappingModel
    private var timetable: PDFAnalysis? { schedule.timetable }
    private var changes: ChangeAnalysis? { schedule.changes }
    private var events: PDFAnalysis? { schedule.events }
    private var specials: [SpecialScheduleAnalysis] { schedule.specials }

    func normalTime(from start: Int, to end: Int) -> String {
        schedule.normalTime(from: start, to: end)
    }

    func beforeSubject(_ selection: ChangeSelection) -> String {
        if !selection.change.before_subject.isEmpty {
            return mappings.names(for: selection.change).before.cellSubject
        }
        let names = selection.baseLessons.map(\.names.cellSubject).reduce(into: [String]()) { result, name in
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return names.isEmpty ? "記載なし" : names.joined(separator: "・")
    }

    func changeSelection(for change: ScheduleChange) -> ChangeSelection {
        guard let day = SchoolDate(iso8601: change.change_date) else {
            return ChangeSelection(change: change, baseLessons: [], baseSpecialLessons: [], relatedChanges: [])
        }
        let periods = change.gridPeriods ?? []
        let originals = periods.map { period in
            TimetableSchedule.slot(on: day, period: period, className: change.displayClassName,
                                   timetable: timetable, changes: nil, includesChanges: false,
                                   events: events, specials: specials)
        }
        let related = TimetableSchedule.changes(on: day, className: change.displayClassName, analysis: changes)
            .filter { $0 != change && !Set($0.gridPeriods ?? []).isDisjoint(with: periods) }
        return ChangeSelection(change: change, baseLessons: originals.flatMap(\.baseLessons),
                               baseSpecialLessons: originals.flatMap(\.specialLessons), relatedChanges: related)
    }


}

struct LessonSelection: Identifiable {
    let id = UUID()
    let lesson: PDFLesson
    let date: SchoolDate
    let startPeriod: Int
    let endPeriod: Int
}

struct ChangeSelection: Identifiable {
    let id = UUID()
    let change: ScheduleChange
    let baseLessons: [PDFLesson]
    let baseSpecialLessons: [TimetableSchedule.SpecialItem]
    let relatedChanges: [ScheduleChange]
}

struct SpecialSelection: Identifiable {
    let id = UUID()
    let item: TimetableSchedule.SpecialItem
    let startPeriod: Int
    let endPeriod: Int
    let timeRange: String?
}
