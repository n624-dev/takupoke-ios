import Foundation

/// A read-only projection of the currently saved successful analyses.
/// It does not change the stored parsing result or infer school event rules.
enum TimetableSchedule {
    static func sameProjection(_ lhs:PDFAnalysis?,_ rhs:PDFAnalysis?) -> Bool {
        switch (lhs,rhs) {
        case (nil,nil): return true
        case (let lhs?,let rhs?):
            return lhs.kind == rhs.kind && lhs.version == rhs.version && lhs.sourceDigest == rhs.sourceDigest &&
                lhs.parsedAt == rhs.parsedAt && lhs.schoolYear == rhs.schoolYear && lhs.term == rhs.term &&
                lhs.lessons == rhs.lessons && lhs.events == rhs.events
        default: return false
        }
    }
    static func sameProjection(_ lhs:ChangeAnalysis?,_ rhs:ChangeAnalysis?) -> Bool {
        switch (lhs,rhs) {
        case (nil,nil): return true
        case (let lhs?,let rhs?):
            return lhs.version == rhs.version && lhs.sourceDigest == rhs.sourceDigest && lhs.parsedAt == rhs.parsedAt &&
                lhs.defaultYear == rhs.defaultYear && lhs.records == rhs.records
        default: return false
        }
    }
    /// Immutable accepted inputs with bounded, unfiltered query memoization.
    /// Display scope and mapping rules are applied by the existing callers.
    final class SourceIndex {
        private struct DayClass: Hashable { let day:SchoolDate; let name:String }
        private struct NormalKey: Hashable { let weekday:Int; let period:Int; let name:String }
        private struct SlotKey: Hashable { let day:SchoolDate; let period:Int; let name:String; let includesChanges:Bool }
        private let range: SchoolDateRange?
        private let specials: [SpecialScheduleAnalysis]
        private var normal = [NormalKey:[PDFLesson]]()
        private var changes = [SlotKey:[ScheduleChange]]()
        private var specialItems = [DayClass:[SpecialItem]]()
        private var eventIntervals = [(SchoolDate,SchoolDate,PDFSchoolEvent)]()
        private var plans = [SchoolDate:DayPlan]()
        private var applicable = [DayClass:[SpecialScheduleAnalysis]]()
        private var slots = [SlotKey:Slot]()
        var cachedPlanCount:Int { plans.count }
        var cachedSlotCount:Int { slots.count }

        init(timetable:PDFAnalysis?,changes:ChangeAnalysis?,events:PDFAnalysis?,specials:[SpecialScheduleAnalysis]) {
            range = timetable.flatMap { TimetableSchedule.termRange(for:$0) }; self.specials = specials
            for lesson in timetable?.lessons ?? [] {
                normal[NormalKey(weekday:lesson.weekday,period:lesson.period,name:lesson.className),default:[]].append(lesson)
            }
            // Parse every distinct raw date once. Keep exact canonical matching:
            // the old source selectors compare the original text to iso8601.
            var dates = [String:SchoolDate]()
            var invalid = Set<String>()
            func date(_ text:String) -> SchoolDate? {
                if let value = dates[text] { return value }
                if invalid.contains(text) { return nil }
                guard let value = SchoolDate(iso8601:text), value.iso8601 == text else { invalid.insert(text); return nil }
                dates[text] = value; return value
            }
            for change in changes?.records ?? [] {
                guard let day = date(change.change_date), let periods = change.gridPeriods else { continue }
                for period in Set(periods) {
                    self.changes[SlotKey(day:day,period:period,name:change.displayClassName,includesChanges:true),default:[]].append(change)
                }
            }
            for source in specials {
                for lesson in source.lessons {
                    guard let day = date(lesson.date) else { continue }
                    specialItems[DayClass(day:day,name:lesson.className),default:[]].append(
                        SpecialItem(kind:source.kind,lesson:lesson,timeRange:source.timeRange(for:lesson)))
                }
            }
            for event in events?.events ?? [] {
                // Events historically accept any parseable start text, unlike
                // change/special exact-string selectors. Invalid ranges retain
                // their valid start day, without expanding a long range.
                guard let start = SchoolDate(iso8601:event.date) else { continue }
                let end = !event.periodNeedsReview ? event.endDate.flatMap(SchoolDate.init(iso8601:)) : nil
                eventIntervals.append((start,end.map { $0 >= start ? $0:start } ?? start,event))
            }
        }

        func plan(on day:SchoolDate) -> DayPlan {
            if let value = plans[day] { return value }
            let visible = eventIntervals.compactMap { $0.0 <= day && day <= $0.1 ? $0.2:nil }
            let value = TimetableSchedule.dayPlan(on:day,visible:visible)
            if plans.count >= 512 { plans.removeAll(keepingCapacity:true) }
            plans[day] = value; return value
        }

        func applicableSpecials(on day:SchoolDate,className:String) -> [SpecialScheduleAnalysis] {
            let key = DayClass(day:day,name:className)
            if let value = applicable[key] { return value }
            let value = specials.filter { $0.applies(date:day.iso8601,className:className) }
            if applicable.count >= 1024 { applicable.removeAll(keepingCapacity:true) }
            applicable[key] = value; return value
        }

        func slot(on day:SchoolDate,period:Int,className:String,includesChanges:Bool) -> Slot {
            let key = SlotKey(day:day,period:period,name:className,includesChanges:includesChanges)
            if let value = slots[key] { return value }
            let plan = plan(on:day)
            let base = range?.contains(day) == true ? normal[NormalKey(weekday:plan.weekdayOverride ?? day.schoolWeekday,period:period,name:className),default:[]]:[]
            let special = specialItems[DayClass(day:day,name:className),default:[]].filter { $0.lesson.period == period }
            let changed = includesChanges ? changes[key,default:[]]:[]
            let value = TimetableSchedule.resolvedSlot(plan:plan,specialDayApplies:!applicableSpecials(on:day,className:className).isEmpty,
                base:base,special:special,changes:changed)
            if slots.count >= 4096 { slots.removeAll(keepingCapacity:true) }
            slots[key] = value; return value
        }
    }
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
                                                       schoolYear: Int? = nil,
                                                       matchedByRule: ((String, String, Int?) -> Bool)?) -> Bool {
        isInternationalStudentSubject(value) ||
            (matchedByRule?(value, className, schoolYear) == true)
    }

    static func shouldDisplay(_ lesson: PDFLesson, isInternationalStudent: Bool,
                              matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> Bool {
        isInternationalStudent || ![lesson.names.subject, lesson.names.subjectFullName ?? ""]
            .contains(where: { isInternationalStudentSubject($0, className: lesson.className, matchedByRule: matchedByRule) })
    }

    static func shouldDisplay(_ change: ScheduleChange, isInternationalStudent: Bool,
                              matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> Bool {
        isInternationalStudent || ![change.before_subject, change.after_subject]
            .contains(where: { isInternationalStudentSubject($0, className: change.displayClassName,
                schoolYear: SchoolDate(iso8601: change.change_date)?.schoolYear, matchedByRule: matchedByRule) })
    }

    static func shouldDisplay(_ item: SpecialItem, isInternationalStudent: Bool,
                              matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> Bool {
        isInternationalStudent || !isInternationalStudentSubject(item.lesson.subject,
            className: item.lesson.className, matchedByRule: matchedByRule)
    }

    struct SpecialItem: Equatable {
        let kind: SpecialScheduleKind
        let lesson: SpecialScheduleLesson
        let timeRange: String?
    }

    struct Slot: Equatable {
        let baseLessons: [PDFLesson]
        let specialLessons: [SpecialItem]
        let changes: [ScheduleChange]

        /// A change row names its date, class and period. All original lessons
        /// remain available for the detail sheet, including parallel lessons.
        var displayedLessons: [PDFLesson] { changes.isEmpty ? baseLessons : [] }
        var displayedSpecialLessons: [SpecialItem] { changes.isEmpty ? specialLessons : [] }

        /// Apply the display scope before deciding whether a change replaces
        /// a lesson. The unfiltered slot remains available to detail views.
        func filteringChanges(isInternationalStudent: Bool,
                              matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> Slot {
            Slot(baseLessons: baseLessons, specialLessons: specialLessons,
                 changes: changes.filter { TimetableSchedule.shouldDisplay($0,
                     isInternationalStudent: isInternationalStudent, matchedByRule: matchedByRule) })
        }
    }

    /// Match the merged-week source: the last makeup wins; otherwise the last row wins.
    /// All rows stay in `Slot.changes` for the detail view and change list.
    static func effectiveChange(_ changes: [ScheduleChange]) -> ScheduleChange? {
        changes.last { $0.isMakeup } ?? changes.last
    }

    static func classes(in state: MaterialLibraryState, specials: [SpecialScheduleAnalysis] = []) -> [String] {
        let lessonClasses = state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.lessons.map(\.className) ?? []
        let changeClasses = state.changeAnalysis?.records.map(\.displayClassName) ?? []
        let specialClasses = specials.flatMap { $0.coveredClasses + $0.lessons.map(\.className) }
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
                     specials: [SpecialScheduleAnalysis] = [], sourceIndex:SourceIndex? = nil) -> Slot {
        if let sourceIndex { return sourceIndex.slot(on:day,period:period,className:className,includesChanges:includesChanges) }
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
        let base = lessons(on: day, className: className, analysis: timetable,
                    weekday: plan.weekdayOverride).filter { $0.period == period }
        let special = specialDayItems.filter { $0.lesson.period == period }
        let changes = includesChanges ? Self.changes(on: day, className: className, analysis: changes)
            .filter { $0.gridPeriods?.contains(period) == true } : []
        return resolvedSlot(plan:plan,specialDayApplies:specialDayApplies,base:base,special:special,changes:changes)
    }

    private static func resolvedSlot(plan:DayPlan,specialDayApplies:Bool,base:[PDFLesson],special:[SpecialItem],changes:[ScheduleChange]) -> Slot {
        guard !plan.isNoClass || plan.apiNoClass else { return Slot(baseLessons:[],specialLessons:[],changes:[]) }
        let suppressed = plan.isNoClass || plan.isSupplementary || plan.apiTest || plan.apiTestReturn || specialDayApplies
        return Slot(baseLessons:suppressed ? []:base,specialLessons:special,changes:changes)
    }


}

enum ChangeRange: String, CaseIterable {
    case today = "今日以降"
    case week = "この週"
    case all = "全件"
}
