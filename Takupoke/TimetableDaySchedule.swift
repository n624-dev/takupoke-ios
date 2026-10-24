import Foundation

/// Application-owned lifetime, independent of busy/error publications.
@MainActor
final class TimetableProjectionCache {
    struct Key: Equatable {
        let materials: UUID
        let specials: UUID
        let events: UUID
    }
    private var stored: (Key,TimetableSchedule.SourceIndex)?
    struct ClockKey:Hashable {
        let period:Int
        let days:[SchoolDate]
        let classes:[String]
        let includesChanges:Bool
        let international:Bool
        let mappingRevision:String
        let timesRevision:String
    }
    private let clocks = TimetableBoundedMemo<ClockKey,String?>(limit:512)
    private let empty = TimetableSchedule.SourceIndex(timetable:nil,changes:nil,events:nil,specials:[])
    private var suspended: Bool
    init(suspended:Bool = false) { self.suspended = suspended }
    func sourceIndex(for key:Key,make:() -> TimetableSchedule.SourceIndex) -> TimetableSchedule.SourceIndex {
        guard !suspended else { return empty }
        if let stored, stored.0 == key { return stored.1 }
        let value = make(); clocks.removeAll(); stored = (key,value); return value
    }
    func periodTime(for key:ClockKey,index:TimetableSchedule.SourceIndex,make:() -> String?) -> String? {
        guard !suspended, stored?.1 === index else { return nil }
        return clocks.value(for:key,make:make)
    }
    func suspend() { stored = nil; clocks.removeAll(); suspended = true }
    func resume() { suspended = false }
}

/// Shared, read-only schedule and clock projection for the home and week views.
struct TimetableDaySchedule {
    let timetable: PDFAnalysis?
    let changes: ChangeAnalysis?
    let events: PDFAnalysis?
    let specials: [SpecialScheduleAnalysis]
    let includesChanges: Bool
    var customTimes: TimetableTimes? = nil
    let sourceIndex: TimetableSchedule.SourceIndex

    init(timetable:PDFAnalysis?,changes:ChangeAnalysis?,events:PDFAnalysis?,specials:[SpecialScheduleAnalysis],
         includesChanges:Bool,customTimes:TimetableTimes? = nil,sourceIndex:TimetableSchedule.SourceIndex? = nil) {
        self.timetable = timetable; self.changes = changes; self.events = events; self.specials = specials
        self.includesChanges = includesChanges; self.customTimes = customTimes
        self.sourceIndex = sourceIndex ?? TimetableSchedule.SourceIndex(timetable:timetable,changes:changes,events:events,specials:specials)
    }

    func commonPeriodTime(_ period: Int, days: [SchoolDate], classes: [String],
                          international: Bool, matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> String? {
        var times: Set<String> = []
        for day in days {
            let plan = sourceIndex.plan(on:day)
            if plan.isNoClass && !plan.apiNoClass { continue }
            for className in classes {
                let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                                  timetable: timetable, changes: changes,
                                                  includesChanges: includesChanges, events: events,
                                                  specials: specials,sourceIndex:sourceIndex)
                    .filteringChanges(isInternationalStudent: international,
                                      matchedByRule: matchedByRule)
                let visible = slot.displayedLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: international,
                                                                                                matchedByRule: matchedByRule) } ||
                    slot.displayedSpecialLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: international,
                                                                                               matchedByRule: matchedByRule) } ||
                    slot.changes.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: international,
                                                                              matchedByRule: matchedByRule) }
                guard visible else { continue }
                let visibleSpecials = slot.changes.isEmpty ? slot.displayedSpecialLessons.filter {
                    TimetableSchedule.shouldDisplay($0, isInternationalStudent: international, matchedByRule: matchedByRule)
                } : nil
                guard let time = slotTime(slot, on: day, className: className, period: period,
                                          visibleSpecialLessons: visibleSpecials) else { return nil }
                times.insert(time)
                if times.count > 1 { return nil }
            }
        }
        return times.first
    }
    func slotTime(_ slot: TimetableSchedule.Slot, on day: SchoolDate,
                          className: String, period: Int,
                          visibleSpecialLessons: [TimetableSchedule.SpecialItem]? = nil) -> String? {
        if !slot.changes.isEmpty && !hasRequiredSpecialSources(on: day, className: className) { return nil }
        let specialItems = visibleSpecialLessons ?? slot.specialLessons
        if !specialItems.isEmpty {
            let clocks = specialItems.map { item -> String? in
                let sources = specials.filter { $0.kind == item.kind && $0.lessons.contains(item.lesson) }
                let values = sources.map { $0.displayTime(for: item.lesson, in: period...period) }
                let confirmed = values.compactMap { $0 }
                return !values.isEmpty && values.count == confirmed.count && Set(confirmed).count == 1 ? confirmed.first : nil
            }
            let times = clocks.compactMap { $0 }
            return times.count == clocks.count && Set(times).count == 1 ? times.first : nil
        }
        let sourceTimes = Set(specials.flatMap { analysis in
            analysis.lessons.filter { $0.date == day.iso8601 && $0.className == className &&
                $0.period == period }.compactMap { analysis.displayTime(for: $0, in: period...period) }
        })
        if sourceTimes.count == 1 { return sourceTimes.first }
        if sourceTimes.count > 1 { return nil }
        let applicable = specials.filter { $0.applies(date: day.iso8601, className: className) }
        if applicable.isEmpty {
            let plan = sourceIndex.plan(on:day)
            return plan.apiTest || plan.apiTestReturn ? nil : (customTimes?.time(on: day, period: period) ?? TimetableSchedule.normalPeriodTimes[period - 1])
        }
        let times = Set(applicable.compactMap { $0.periodTime(on: day.iso8601, period: period) })
        return times.count == 1 && applicable.allSatisfy({ $0.periodTime(on: day.iso8601, period: period) != nil })
            ? times.first : nil
    }

    private func hasRequiredSpecialSources(on day: SchoolDate, className: String) -> Bool {
        let plan = sourceIndex.plan(on:day)
        return (!plan.apiTest || specials.contains { $0.kind == .exam && $0.applies(date: day.iso8601, className: className) }) &&
            (!plan.apiTestReturn || specials.contains { $0.kind == .examReturn && $0.applies(date: day.iso8601, className: className) })
    }

    func cardTime(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                          className: String) -> String? {
        if case .special(let item) = block.content {
            if block.startPeriod == block.endPeriod && item.lesson.spanStart == item.lesson.spanEnd { return item.timeRange }
            let sources = specials.filter { $0.kind == item.kind && $0.lessons.contains(item.lesson) }
            let ranges = sources.map { source -> String? in
                var clocks: [String] = []
                for period in block.startPeriod...block.endPeriod {
                    let lessons = source.lessons.filter { $0.date == day.iso8601 && $0.className == className &&
                        $0.period == period && $0.subject == item.lesson.subject &&
                        $0.teacher == item.lesson.teacher && $0.room == item.lesson.room }
                    let times = lessons.compactMap { source.displayTime(for: $0, in: block.startPeriod...block.endPeriod) }
                    guard !lessons.isEmpty, times.count == lessons.count, Set(times).count == 1,
                          let time = times.first else { return nil }
                    clocks.append(time)
                }
                guard let first = clocks.first?.components(separatedBy: "〜").first,
                      let last = clocks.last?.components(separatedBy: "〜").last else { return nil }
                return "\(first)〜\(last)"
            }
            let confirmed = ranges.compactMap { $0 }
            return !ranges.isEmpty && confirmed.count == ranges.count && Set(confirmed).count == 1 ? confirmed.first : nil
        }
        if case .change = block.content {
            guard hasRequiredSpecialSources(on: day, className: className) else { return nil }
            let applicable = specials.filter { $0.applies(date: day.iso8601, className: className) }
            if !applicable.isEmpty {
                let range = block.startPeriod...block.endPeriod
                let ranges = applicable.map { source -> String? in
                    var clocks: [String] = []
                    for period in range {
                        let lessons = source.lessons.filter { $0.date == day.iso8601 && $0.className == className && $0.period == period }
                        let values = lessons.isEmpty ? [source.periodTime(on: day.iso8601, period: period)] :
                            lessons.map { source.displayTime(for: $0, in: range) }
                        let confirmed = values.compactMap { $0 }
                        guard confirmed.count == values.count, Set(confirmed).count == 1, let clock = confirmed.first else { return nil }
                        clocks.append(clock)
                    }
                    guard let start = clocks.first?.components(separatedBy: "〜").first,
                          let end = clocks.last?.components(separatedBy: "〜").last else { return nil }
                    return "\(start)〜\(end)"
                }
                let confirmed = ranges.compactMap { $0 }
                return confirmed.count == ranges.count && Set(confirmed).count == 1 ? confirmed.first : nil
            }
        }
        let firstSlot = TimetableSchedule.slot(on: day, period: block.startPeriod, className: className,
                                               timetable: timetable, changes: changes,
                                               includesChanges: includesChanges, events: events, specials: specials,sourceIndex:sourceIndex)
        guard let first = slotTime(firstSlot, on: day, className: className,
                                   period: block.startPeriod) else { return nil }
        if block.startPeriod == block.endPeriod { return first }
        let lastSlot = TimetableSchedule.slot(on: day, period: block.endPeriod, className: className,
                                              timetable: timetable, changes: changes,
                                              includesChanges: includesChanges, events: events, specials: specials,sourceIndex:sourceIndex)
        guard let last = slotTime(lastSlot, on: day, className: className,
                                  period: block.endPeriod),
              let startTime = first.components(separatedBy: "〜").first,
              let endTime = last.components(separatedBy: "〜").last else { return nil }
        return "\(startTime)〜\(endTime)"
    }

    func changeTimeRanges(_ change: ScheduleChange) -> [String?] {
        guard let day = SchoolDate(iso8601: change.change_date),
              let periods = change.detailPeriods else { return [] }
        var ranges: [ClosedRange<Int>] = []
        for period in periods {
            if let last = ranges.last, last.upperBound + 1 == period {
                ranges[ranges.count - 1] = last.lowerBound...period
            } else { ranges.append(period...period) }
        }
        return ranges.map { range in
            cardTime(TimetableSchedule.GridBlock(startPeriod: range.lowerBound,
                endPeriod: range.upperBound, content: .change(change)),
                on: day, className: change.displayClassName)
        }
    }

    func normalTime(from start: Int, to end: Int, on day: SchoolDate? = nil) -> String {
        let first = day.flatMap { customTimes?.time(on: $0, period: start) } ?? TimetableSchedule.normalPeriodTimes[start - 1]
        let last = day.flatMap { customTimes?.time(on: $0, period: end) } ?? TimetableSchedule.normalPeriodTimes[end - 1]
        return "\(first.components(separatedBy: "〜").first ?? first)〜\(last.components(separatedBy: "〜").last ?? last)"
    }
}

extension TimetableDaySchedule {
    static func schoolDay(at date: Date) -> SchoolDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return SchoolDate(year: parts.year!, month: parts.month!, day: parts.day!)!
    }

    func blocks(on day: SchoolDate, className: String, international: Bool,
                matchedByRule: ((String, String, Int?) -> Bool)? = nil) -> [TimetableSchedule.GridBlock] {
        TimetableSchedule.positioned(TimetableSchedule.blocks(on: day, className: className,
            timetable: timetable, changes: changes, includesChanges: includesChanges, events: events,
            specials: specials, isInternationalStudent: international, matchedByRule: matchedByRule,sourceIndex:sourceIndex))
            .map(\.block)
    }

    /// A visual merge does not prove continuous activity. Retain a source's
    /// explicit merged clock only when the entire original span is represented.
    private func activityTimes(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                               className: String) -> [String] {
        let item: TimetableSchedule.SpecialItem?
        let sources: [SpecialScheduleAnalysis]
        if case .special(let special) = block.content {
            item = special
            sources = specials.filter { $0.kind == special.kind && $0.lessons.contains(special.lesson) }
        } else {
            item = nil
            sources = specials.filter { $0.applies(date: day.iso8601, className: className) }
            if sources.isEmpty {
                return (block.startPeriod...block.endPeriod).map {
                    customTimes?.time(on: day, period: $0) ?? TimetableSchedule.normalPeriodTimes[$0 - 1]
                }
            }
        }
        guard !sources.isEmpty else { return [] }
        var agreed: Set<String>?
        for source in sources {
            var intervals = Set<String>()
            for period in block.startPeriod...block.endPeriod {
                let lessons = source.lessons.filter { lesson in
                    lesson.date == day.iso8601 && lesson.className == className && lesson.period == period &&
                        (item == nil || (lesson.subject == item!.lesson.subject &&
                                         lesson.teacher == item!.lesson.teacher && lesson.room == item!.lesson.room))
                }
                let values: [String?] = lessons.isEmpty && item == nil ?
                    [source.periodTime(on: day.iso8601, period: period)] : lessons.map { lesson in
                        lesson.timeRange == nil ? source.periodTime(on: day.iso8601, period: period) :
                            source.displayTime(for: lesson, in: block.startPeriod...block.endPeriod)
                    }
                let verified = values.compactMap { $0 }
                guard !values.isEmpty, verified.count == values.count else { return [] }
                intervals.formUnion(verified)
            }
            if let agreed, agreed != intervals { return [] }
            agreed = intervals
        }
        return Array(agreed ?? [])
    }

    func activityMinuteRanges(_ block:TimetableSchedule.GridBlock,on day:SchoolDate,className:String) -> [Range<Int>] {
        if case .change(let change) = block.content, change.isCancellation { return [] }
        let clocks: [String?]
        if case .normal = block.content {
            // Normal cards are a visual merge; their internal breaks remain.
            clocks = (block.startPeriod...block.endPeriod).map { period in
                customTimes?.time(on: day, period: period) ?? TimetableSchedule.normalPeriodTimes[period - 1]
            }
        } else {
            guard cardTime(block, on: day, className: className) != nil else { return [] }
            clocks = activityTimes(block, on: day, className: className).map { Optional($0) }
        }
        return clocks.compactMap { clock in
            guard let ends = clock?.components(separatedBy: "〜"), ends.count == 2,
                  let start = Self.minutes(ends[0]), let end = Self.minutes(ends[1]), start < end else { return nil }
            return start..<end
        }
    }
    func isInProgress(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                      className: String, now: Date) -> Bool {
        guard day == Self.schoolDay(at: now) else { return false }
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Asia/Tokyo")!
        let minute = calendar.component(.hour,from:now)*60+calendar.component(.minute,from:now)
        return activityMinuteRanges(block,on:day,className:className).contains { $0.contains(minute) }
    }

    private static func minutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// Missing input must not be presented as a confirmed day without lessons.
    func missingMessages(on day: SchoolDate, className: String) -> [String] {
        let plan = sourceIndex.plan(on:day)
        var messages: [String] = plan.weekdayOverrideWarning.map { [$0] } ?? []
        for kind in SpecialScheduleKind.allCases {
            let expected = kind == .exam ? plan.apiTest : plan.apiTestReturn
            if expected && !specials.contains(where: { $0.kind == kind && $0.applies(date: day.iso8601, className: className) }) {
                messages.append("\(kind.title)：未公開または未解析です")
            }
        }
        let hasSpecial = specials.contains { $0.applies(date: day.iso8601, className: className) }
        if !plan.isNoClass && !plan.isSupplementary && !plan.apiTest && !plan.apiTestReturn && !hasSpecial {
            if let timetable {
                if let range = TimetableSchedule.termRange(for: timetable) {
                    if !range.contains(day) {
                        messages.append("今日に適用できる通常時間割がありません。")
                    } else if !timetable.lessons.contains(where: { $0.className == className }) {
                        messages.append("このクラスの通常時間割がありません。")
                    }
                } else { messages.append("通常時間割の学期を確認できません。再解析してください。") }
            } else { messages.append("通常時間割の解析結果がありません。") }
        }
        return messages
    }
}
