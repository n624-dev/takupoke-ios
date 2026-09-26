import SwiftUI

extension TimetableView {
    func commonPeriodTime(_ period: Int, days: [SchoolDate]) -> String? {
        var times: Set<String> = []
        for day in days {
            let plan = TimetableSchedule.dayPlan(on: day, events: events)
            if plan.isNoClass && !plan.apiNoClass { continue }
            for className in selectedClasses {
                let slot = TimetableSchedule.slot(on: day, period: period, className: className,
                                                  timetable: timetable, changes: changes,
                                                  includesChanges: includesChanges, events: events,
                                                  specials: specials)
                let visible = slot.displayedLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                                                matchedByRule: isMappedInternational) } ||
                    slot.displayedSpecialLessons.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                                               matchedByRule: isMappedInternational) } ||
                    slot.changes.contains { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                                              matchedByRule: isMappedInternational) }
                guard visible else { continue }
                guard let time = slotTime(slot, on: day, className: className, period: period) else { return nil }
                times.insert(time)
                if times.count > 1 { return nil }
            }
        }
        return times.first
    }

    private func slotTime(_ slot: TimetableSchedule.Slot, on day: SchoolDate,
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
