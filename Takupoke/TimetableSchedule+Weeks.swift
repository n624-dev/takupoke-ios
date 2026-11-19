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
                                    specials: [SpecialScheduleAnalysis] = [],
                                    sourceIndex: SourceIndex? = nil) -> ClosedRange<SchoolDate> {
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
                          specials: specials, sourceIndex: sourceIndex) {
            upper = next
        }
        return lower...upper
    }

    static func hasWeekData(start: SchoolDate, classes: [String], timetable: PDFAnalysis?,
                            changes: ChangeAnalysis?, events: PDFAnalysis?, includesChanges: Bool,
                            specials: [SpecialScheduleAnalysis] = [], sourceIndex: SourceIndex? = nil) -> Bool {
        guard !classes.isEmpty else { return false }
        return (0..<7).compactMap { start.addingDays($0) }.contains { day in
            if !Self.events(on: day, analysis: events).isEmpty { return true }
            return classes.contains { className in
                (1...8).contains { period in
                    let slot = slot(on: day, period: period, className: className, timetable: timetable,
                                    changes: changes, includesChanges: includesChanges, events: events,
                                    specials: specials, sourceIndex: sourceIndex)
                    return !slot.displayedLessons.isEmpty || !slot.specialLessons.isEmpty || !slot.changes.isEmpty
                }
            }
        }
    }
}

/// Advance with the display's elapsed time without catching up in one frame
/// when the renderer or main thread misses a display opportunity.
struct WeekSlideClock {
    private var lastTarget: TimeInterval?
    private var elapsed: TimeInterval = 0

    mutating func progress(timestamp: TimeInterval, target: TimeInterval, duration: TimeInterval) -> Double {
        let previous = lastTarget ?? timestamp
        if target > previous {
            elapsed += min(target - previous, 1.0 / 30)
            lastTarget = target
        }
        return min(1, elapsed / duration)
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

    static func preparedWeeks(selected: SchoolDate, arriving: SchoolDate?,
                              within bounds: ClosedRange<SchoolDate>) -> [SchoolDate] {
        var offsets = [-7, 0, 7]
        if let arriving {
            if arriving == selected.addingDays(-7) { offsets.insert(-14, at: 0) }
            if arriving == selected.addingDays(7) { offsets.append(14) }
        }
        return offsets.compactMap { selected.addingDays($0) }.filter(bounds.contains)
    }
}

/// Releases are ordered by the week each physical contact started from.
/// A release remains pending while its exact destination finishes preparing.
struct WeekPullReleases {
    struct Move: Equatable {
        let source: SchoolDate
        let destination: SchoolDate
    }

    private var pending: [Move] = []
    var isEmpty: Bool { pending.isEmpty }
    var lastDestination: SchoolDate? { pending.last?.destination }

    mutating func append(from source: SchoolDate, distance: CGFloat, within bounds: ClosedRange<SchoolDate>) {
        guard (lastDestination ?? source) == source, bounds.contains(source) else { return }
        let previous = source.addingDays(-7)
        let next = source.addingDays(7)
        let days = WeekEdgePull.weekOffset(onRelease: distance,
            previous: previous.map(bounds.contains) == true, next: next.map(bounds.contains) == true)
        guard days != 0, let destination = days > 0 ? next : previous else { return }
        pending.append(Move(source: source, destination: destination))
    }

    mutating func consume(from source: SchoolDate, isReady: (SchoolDate) -> Bool) -> Move? {
        guard let first = pending.first, first.source == source,
              isReady(source), isReady(first.destination) else { return nil }
        return pending.removeFirst()
    }

    mutating func cancel() { pending.removeAll() }
}

struct WeekHorizontalPosition {
    let offset: CGFloat
    let range: CGFloat

    init(offset: CGFloat, range: CGFloat) {
        self.range = max(0, range)
        self.offset = min(self.range, max(0, offset))
    }

    func offset(after translation: CGPoint) -> CGFloat {
        min(range, max(0, offset - translation.x))
    }

    func pullDistance(after translation: CGPoint) -> CGFloat {
        WeekEdgePull(velocity: CGPoint(x: 1, y: 0), offset: offset, scrollRange: range)?
            .distance(for: translation) ?? 0
    }
}

struct WeekDeferredPulls {
    struct Contact {
        let week: SchoolDate?
        let start: WeekHorizontalPosition?
        let translation: CGPoint
    }

    private var contacts: [Contact] = []
    var isEmpty: Bool { contacts.isEmpty }

    mutating func append(_ contact: Contact) { contacts.append(contact) }

    mutating func consume(on week: SchoolDate, startingPosition: () -> WeekHorizontalPosition?)
        -> (start: WeekHorizontalPosition, translation: CGPoint)? {
        guard let first = contacts.first, first.week == nil || first.week == week,
              let start = first.start ?? startingPosition() else { return nil }
        contacts.removeFirst()
        return (start, first.translation)
    }

    mutating func cancel() { contacts.removeAll() }
}

extension SchoolDate {
    func weekRangeLabel(ending end: SchoolDate, compact: Bool) -> String {
        let omitMonth = compact && year == end.year && month == end.month
        let last = omitMonth ? "\(end.day)" : "\(end.month)/\(end.day)"
        return "\(month)/\(day)〜\(last)"
    }
}

extension WeekEdgePull {
    static func rubberBandOffset(offset: CGFloat, scrollRange: CGFloat) -> CGFloat {
        min(max(0, offset), max(0, scrollRange)) - offset
    }

    /// Leave room for the glass edge and shadow on both axes. The compact badge
    /// is chosen by the caller before placement in a short visible body.
    static func badgeFrame(visible: CGRect, preferredY: CGFloat, size: CGSize,
                           previous: Bool, margin: CGFloat) -> CGRect {
        let area = visible.insetBy(dx: margin, dy: margin)
        let x = previous ? area.minX : area.maxX - size.width
        let y = min(max(area.minY, preferredY - size.height / 2), max(area.minY, area.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

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
