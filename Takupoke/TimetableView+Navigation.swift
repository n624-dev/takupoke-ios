import SwiftUI

extension TimetableView {
    func moveWeek(_ days: Int) {
        if let next = weekStart.addingDays(days), weekBounds.contains(next) { weekStart = next }
    }

    var weekBounds: ClosedRange<SchoolDate> {
        TimetableSchedule.reachableWeekBounds(containing: navigationHalfAnchor,
                                               classes: selectedClasses, timetable: timetable,
                                               changes: changes, events: events,
                                               includesChanges: includesChanges, specials: specials)
    }

    private func pickerDate(_ day: SchoolDate) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    }

    var weekPickerRange: ClosedRange<Date> {
        pickerDate(weekBounds.lowerBound)...pickerDate(weekBounds.upperBound.addingDays(6)!)
    }

    var pickerWeekIsReachable: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: weekPickerDate)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let picked = SchoolDate(year: year, month: month, day: day) else { return false }
        return weekBounds.contains(picked.monday)
    }

    func openWeekPicker() {
        weekPickerDate = pickerDate(min(max(weekStart, weekBounds.lowerBound), weekBounds.upperBound))
        showingWeekPicker = true
    }

    func selectPickedWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let parts = calendar.dateComponents([.year, .month, .day], from: weekPickerDate)
        if let year = parts.year, let month = parts.month, let day = parts.day,
           let picked = SchoolDate(year: year, month: month, day: day),
           weekBounds.contains(picked.monday) {
            weekStart = picked.monday
        }
        showingWeekPicker = false
    }

    var canMovePrevious: Bool {
        guard let previous = weekStart.addingDays(-7) else { return false }
        return weekBounds.contains(previous)
    }

    var canMoveNext: Bool {
        guard let next = weekStart.addingDays(7) else { return false }
        return weekBounds.contains(next)
    }

    static func decode(_ value: String) -> [String] {
        value.split(separator: "|").map(String.init).reduce(into: [String]()) { result, name in
            if !result.contains(name) { result.append(name) }
        }
    }
}
