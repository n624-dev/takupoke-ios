import SwiftUI

extension TimetableView {
    func refreshToday() {
        let current = SchoolDate.today()
        if today != current { today = current }
    }

    func consumeTodayRequest() {
        guard todayRequest != nil else { return }
        weekPull.cancelWeekMove()
        today = SchoolDate.today()
        navigationHalfAnchor = today
        // This action opens the week containing today, including weekends.
        weekStart = today.monday
        showingWeekPicker = false
        updateFocus = nil; updateMessage = nil
        todayRequest = nil
    }

    func consumeUpdateRequest() {
        guard let update = updateRequest, ApplicationData.shared.readyForCurrentPeriod,
              model.ready || model.failed,
              update.kind == .changes || specialSchedules.ready || specialSchedules.failed else { return }
        refreshToday()
        navigationHalfAnchor = today
        let selected = Set(selectedClasses)
        let currentRevision: String?
        let upcoming: Set<SchoolDate>
        switch update.kind {
        case .changes:
            let record = model.state.record(for: .changes)
            if let record, let changes, changes.matches(record: record,
                defaultYear: ChangeNormalizer.effectiveSchoolYear(configured: changeSchoolYear, today: today)) {
                currentRevision = ScheduleUpdateNotice.digest((record.source.selectionID ?? record.storedName) + "/" + record.digest)
            } else { currentRevision = nil }
            upcoming = includesChanges ? Set((changes?.records ?? []).compactMap { row in
                guard selected.contains(row.displayClassName), row.detailPeriods != nil,
                      TimetableSchedule.shouldDisplay(row, isInternationalStudent: isInternationalStudent,
                                                     matchedByRule: isMappedInternational) else { return nil }
                return SchoolDate(iso8601: row.change_date)
            }) : []
        case .exam, .examReturn:
            let record = specialSchedules.records[update.kind == .exam ? .exam : .examReturn]
            currentRevision = record?.digest
            upcoming = Set((record?.analysis.lessons ?? []).compactMap { lesson in
                guard selected.contains(lesson.className) else { return nil }
                return SchoolDate(iso8601: lesson.date)
            })
        }
        let edition = update.edition(currentRevision: currentRevision)
        let canBeShown = update.date(today: today, upcoming: upcoming, edition: edition, selectedClasses: selected,
                                     allowsRememberedDates: includesChanges && update.kind == .changes && !selected.isEmpty,
                                     international: isInternationalStudent,
                                     mappingRevision: mappings.current?.archiveSHA256 ?? "no-mapping")
        let target = canBeShown.flatMap { weekBounds.contains($0.monday) ? $0 : nil }
        weekPull.cancelWeekMove()
        closeDetailSelections()
        showingWeekPicker = false
        weekStart = target?.monday ?? today.monday
        updateFocus = target
        if target == nil { updateMessage = "通知の対象を現在の時間割で確認できません。" }
        else if edition != .same { updateMessage = "現在保存している時間割を表示しています。" }
        else { updateMessage = nil }
        updateRequest = nil
    }

    func moveWeek(_ days: Int) {
        weekPull.completeWeekMove()
        if let next = weekStart.addingDays(days), weekBounds.contains(next) { weekStart = next }
    }

    var weekBounds: ClosedRange<SchoolDate> {
        TimetableSchedule.reachableWeekBounds(containing: navigationHalfAnchor,
                                               classes: selectedClasses, timetable: timetable,
                                               changes: changes, events: events,
                                               includesChanges: includesChanges, specials: specials,
                                               sourceIndex: daySchedule.sourceIndex)
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
        weekPull.completeWeekMove()
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
            weekPull.cancelWeekMove()
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
