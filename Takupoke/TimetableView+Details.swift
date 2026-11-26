import SwiftUI

extension TimetableView {
    var daySchedule: TimetableDaySchedule {
        TimetableDaySchedule(timetable: timetable, changes: changes, events: events,
                             specials: specials, includesChanges: includesChanges, customTimes: times.current?.data)
    }

    var presentation: TimetablePresentation {
        TimetablePresentation(schedule: daySchedule, mappings: mappings)
    }

    func lessonDetail(_ selection: LessonSelection) -> some View {
        presentation.lessonDetail(selection)
    }

    func specialDetail(_ selection: SpecialSelection) -> some View {
        presentation.specialDetail(selection)
    }

    func changeDetail(_ selection: ChangeSelection) -> some View {
        presentation.changeDetail(selection)
    }
}
