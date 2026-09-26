import Foundation

extension TimetableSchedule {
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
