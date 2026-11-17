import SwiftUI

@MainActor
struct TimetablePresentation {
    let schedule: TimetableDaySchedule
    let mappings: MappingModel
    var sourceRecord: MaterialRecord? = nil

    var displayedSourceDate: Date? {
        guard let analysis = schedule.changes else { return nil }
        if let date = analysis.sourceModifiedAt { return date }
        guard let record = sourceRecord, record.digest == analysis.sourceDigest,
              record.originalName == analysis.sourceName else { return nil }
        return record.sourceModifiedAt
    }
    private var changes: ChangeAnalysis? { schedule.changes }

    func normalTime(from start: Int, to end: Int) -> String {
        schedule.normalTime(from: start, to: end)
    }

    func changeSelection(for change: ScheduleChange) -> ChangeSelection {
        let names = mappings.names(for: change)
        guard let day = SchoolDate(iso8601: change.change_date) else {
            return ChangeSelection(change: change, baseLessons: [], baseSpecialLessons: [], relatedChanges: [],
                                   comparison: ChangeComparison(change: change, names: names, candidates: [:]))
        }
        let periods = change.detailPeriods ?? []
        let originals = periods.map { period in
            schedule.sourceIndex.slot(on: day, period: period, className: change.displayClassName, includesChanges: false)
        }
        var candidates: [Int: [ChangeBaseCandidate]] = [:]
        for (period, slot) in zip(periods, originals) {
            candidates[period] = slot.baseLessons.map { ChangeBaseCandidate(names: mappings.names(for: $0), source: "通常時間割") }
                + slot.specialLessons.map { item in
                    let source = TimetableLessonNames(subject: item.lesson.subject, teacher: item.lesson.teacher, room: item.lesson.room)
                    let mapped = mappings.current?.rules.applying(to: source, className: change.displayClassName) ?? source
                    return ChangeBaseCandidate(names: mapped, source: item.kind.title)
                }
        }
        let related = TimetableSchedule.changes(on: day, className: change.displayClassName, analysis: changes)
            .filter { $0 != change && !Set($0.detailPeriods ?? []).isDisjoint(with: periods) }
        return ChangeSelection(change: change, baseLessons: originals.flatMap(\.baseLessons),
                               baseSpecialLessons: originals.flatMap(\.specialLessons), relatedChanges: related,
                               comparison: ChangeComparison(change: change, names: names, candidates: candidates))
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
    let comparison: ChangeComparison
}

struct SpecialSelection: Identifiable {
    let id = UUID()
    let item: TimetableSchedule.SpecialItem
    let startPeriod: Int
    let endPeriod: Int
    let timeRange: String?
}
