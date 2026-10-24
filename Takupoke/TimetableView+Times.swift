import SwiftUI

extension TimetableView {
    func commonPeriodTime(_ period: Int, days: [SchoolDate]) -> String? {
        let schedule = daySchedule
        let key = TimetableProjectionCache.ClockKey(period:period,days:days,classes:selectedClasses,
            includesChanges:includesChanges,international:isInternationalStudent,
            mappingRevision:mappings.current?.revision ?? "",timesRevision:times.current?.revision ?? "")
        return ApplicationData.shared.projections.periodTime(for:key,index:schedule.sourceIndex) {
            schedule.commonPeriodTime(period,days:days,classes:selectedClasses,
                international:isInternationalStudent,matchedByRule:isMappedInternational)
        }
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
