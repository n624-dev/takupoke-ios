import Foundation

extension TimetableSchedule {
    static func displayedDays(weekStart: SchoolDate, classes: [String], timetable: PDFAnalysis?,
                              changes: ChangeAnalysis?, events: PDFAnalysis?, includesChanges: Bool,
                              isInternationalStudent: Bool, specials: [SpecialScheduleAnalysis] = [],
                              matchedByRule: ((String, String, Int?) -> Bool)? = nil,
                              sourceIndex:SourceIndex? = nil) -> [SchoolDate] {
        (0..<7).compactMap { weekStart.addingDays($0) }.filter { day in
            if day.schoolWeekday <= 5 { return true }
            let plan = sourceIndex?.plan(on:day) ?? dayPlan(on: day, events: events)
            if !plan.weekendEventLabels.isEmpty { return true }
            if plan.isNoClass && !plan.apiNoClass { return false }
            return classes.contains { className in
                (1...8).contains { period in
                    let item = slot(on: day, period: period, className: className, timetable: timetable,
                                    changes: changes, includesChanges: includesChanges, events: events,
                                    specials: specials,sourceIndex:sourceIndex)
                        .filteringChanges(isInternationalStudent: isInternationalStudent,
                                          matchedByRule: matchedByRule)
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

/// Distances are measured from the finger's starting position. A wide week
/// consumes its remaining horizontal scroll range before either edge can arm.
struct WeekEdgePull {
    static let threshold: CGFloat = 115
    private let left: CGFloat
    private let right: CGFloat

    init?(velocity: CGPoint, offset: CGFloat, scrollRange: CGFloat) {
        guard abs(velocity.x) > abs(velocity.y) else { return nil }
        let range = max(0, scrollRange)
        left = min(range, max(0, offset))
        right = range - left
    }

    func distance(for translation: CGPoint) -> CGFloat {
        guard abs(translation.x) > abs(translation.y) else { return 0 }
        return max(0, translation.x - left) + min(0, translation.x + right)
    }

    static func weekOffset(onRelease distance: CGFloat, previous: Bool, next: Bool) -> Int {
        if previous && distance >= threshold { return -7 }
        if next && distance <= -threshold { return 7 }
        return 0
    }
}

extension SchoolDate {
    func weekRangeLabel(ending end: SchoolDate, compact: Bool) -> String {
        let omitMonth = compact && year == end.year && month == end.month
        let last = omitMonth ? "\(end.day)" : "\(end.month)/\(end.day)"
        return "\(month)/\(day)〜\(last)"
    }
}

extension WeekEdgePull {
    /// Coordinates are local to the standing grid, after clipping to the on-screen list body.
    static func badgeCenter(visible: CGRect, headerHeight: CGFloat) -> CGFloat {
        let firstCell = min(visible.maxY, max(visible.minY, headerHeight))
        return firstCell < visible.maxY ? (firstCell + visible.maxY) / 2 : visible.midY
    }

    /// The native rubber band is smaller than finger travel. Start the next page at its actual seam.
    static func incomingOffset(viewportWidth: CGFloat, offset: CGFloat, scrollRange: CGFloat,
                               days: Int) -> CGFloat {
        let clamped = min(max(0, offset), max(0, scrollRange))
        let direction: CGFloat = days > 0 ? 1 : -1
        let exposed = min(viewportWidth, max(0, (offset - clamped) * direction))
        return direction * (viewportWidth - exposed)
    }
}
