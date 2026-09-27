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

    func slotTime(_ slot: TimetableSchedule.Slot, on day: SchoolDate,
                  className: String, period: Int) -> String? {
        daySchedule.slotTime(slot, on: day, className: className, period: period)
    }

    func cardTime(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                  className: String) -> String? {
        daySchedule.cardTime(block, on: day, className: className)
    }

    func normalTime(from start: Int, to end: Int) -> String {
        daySchedule.normalTime(from: start, to: end)
    }
}
