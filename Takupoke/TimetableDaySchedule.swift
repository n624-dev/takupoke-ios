import Foundation

/// Shared, read-only schedule and clock projection for the home and week views.
struct TimetableDaySchedule {
    let timetable: PDFAnalysis?
    let changes: ChangeAnalysis?
    let events: PDFAnalysis?
    let specials: [SpecialScheduleAnalysis]
    let includesChanges: Bool

    func slotTime(_ slot: TimetableSchedule.Slot, on day: SchoolDate,
                          className: String, period: Int) -> String? {
        if !slot.specialLessons.isEmpty {
            let times = Set(slot.specialLessons.compactMap(\.timeRange))
            return times.count == 1 && slot.specialLessons.allSatisfy({ $0.timeRange != nil })
                ? times.first : nil
        }
        let sourceTimes = Set(specials.flatMap { analysis in
            analysis.lessons.filter { $0.date == day.iso8601 && $0.className == className &&
                $0.period == period }.compactMap { analysis.timeRange(for: $0) }
        })
        if sourceTimes.count == 1 { return sourceTimes.first }
        if sourceTimes.count > 1 { return nil }
        let applicable = specials.filter { $0.applies(date: day.iso8601, className: className) }
        if applicable.isEmpty {
            let plan = TimetableSchedule.dayPlan(on: day, events: events)
            return plan.apiTest || plan.apiTestReturn ? nil : TimetableSchedule.normalPeriodTimes[period - 1]
        }
        let times = Set(applicable.compactMap { $0.periodTime(on: day.iso8601, period: period) })
        return times.count == 1 && applicable.allSatisfy({ $0.periodTime(on: day.iso8601, period: period) != nil })
            ? times.first : nil
    }

    func cardTime(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                          className: String) -> String? {
        let firstSlot = TimetableSchedule.slot(on: day, period: block.startPeriod, className: className,
                                               timetable: timetable, changes: changes,
                                               includesChanges: includesChanges, events: events, specials: specials)
        guard let first = slotTime(firstSlot, on: day, className: className,
                                   period: block.startPeriod) else { return nil }
        if block.startPeriod == block.endPeriod { return first }
        let lastSlot = TimetableSchedule.slot(on: day, period: block.endPeriod, className: className,
                                              timetable: timetable, changes: changes,
                                              includesChanges: includesChanges, events: events, specials: specials)
        guard let last = slotTime(lastSlot, on: day, className: className,
                                  period: block.endPeriod),
              let startTime = first.components(separatedBy: "〜").first,
              let endTime = last.components(separatedBy: "〜").last else { return nil }
        return "\(startTime)〜\(endTime)"
    }

    func normalTime(from start: Int, to end: Int) -> String {
        let first = TimetableSchedule.normalPeriodTimes[start - 1]
        let last = TimetableSchedule.normalPeriodTimes[end - 1]
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
                matchedByRule: ((String, String) -> Bool)? = nil) -> [TimetableSchedule.GridBlock] {
        TimetableSchedule.positioned(TimetableSchedule.blocks(on: day, className: className,
            timetable: timetable, changes: changes, includesChanges: includesChanges, events: events,
            specials: specials, isInternationalStudent: international, matchedByRule: matchedByRule))
            .map(\.block)
    }

    func isInProgress(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                      className: String, now: Date) -> Bool {
        if case .change(let change) = block.content, change.isCancellation { return false }
        guard day == Self.schoolDay(at: now),
              let time = cardTime(block, on: day, className: className) else { return false }
        let ends = time.components(separatedBy: "〜")
        guard ends.count == 2, let start = Self.minutes(ends[0]), let end = Self.minutes(ends[1]),
              start < end else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return start <= minute && minute < end
    }

    private static func minutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// Missing input must not be presented as a confirmed day without lessons.
    func missingMessages(on day: SchoolDate, className: String) -> [String] {
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        var messages: [String] = []
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
