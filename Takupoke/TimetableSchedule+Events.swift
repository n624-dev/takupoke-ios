import Foundation

extension TimetableSchedule {
    struct DayPlan {
        let events: [PDFSchoolEvent]
        let isNoClass: Bool
        let isSupplementary: Bool
        let weekdayOverride: Int?
        let apiNoClass: Bool
        let apiTest: Bool
        let apiTestReturn: Bool
        let weekendEventLabels: [String]

        var noClassLabels: [String] {
            Array(Set(events.compactMap { event in
                guard event.classification?.needsReview == false,
                      let type = event.classification?.type,
                      type == .noClass || type == .schoolEventNoClass else { return nil }
                return event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty })).sorted()
        }
    }

    static func fullDayEventTitle(plan: DayPlan, layouts: [[PositionedBlock]]) -> String? {
        guard plan.isNoClass || !plan.weekendEventLabels.isEmpty,
              layouts.allSatisfy(\.isEmpty) else { return nil }
        let labels = Array(Set(plan.noClassLabels + plan.weekendEventLabels)).sorted()
        return labels.isEmpty ? "授業なし" : labels.joined(separator: "・")
    }

    static func events(on day: SchoolDate, analysis: PDFAnalysis?) -> [PDFSchoolEvent] {
        (analysis?.events ?? []).filter { event in
            guard let start = SchoolDate(iso8601: event.date) else { return false }
            if start == day { return true }
            guard !event.periodNeedsReview, let endText = event.endDate,
                  let end = SchoolDate(iso8601: endText), end >= start else { return false }
            return start < day && day <= end
        }
    }

    static func dayPlan(on day: SchoolDate, events analysis: PDFAnalysis?) -> DayPlan {
        let visible = events(on: day, analysis: analysis)
        let reliable = visible.compactMap { event -> PDFEventClassification? in
            guard event.classification?.needsReview == false else { return nil }
            return event.classification
        }
        let noClass = reliable.contains { $0.type == .noClass || $0.type == .schoolEventNoClass }
        let supplementary = reliable.contains { $0.type == .supplementary }
        let overrides = Set(reliable.filter { $0.type == .weekdayOverride }.compactMap(\.scheduleDay))
        return DayPlan(events: visible, isNoClass: noClass, isSupplementary: supplementary,
                       weekdayOverride: overrides.count == 1 ? overrides.first : nil,
                       apiNoClass: visible.contains { $0.apiTag == "授業なし" || $0.apiTag == "行事（授業なし）" },
                       apiTest: visible.contains { $0.apiTag == "テスト" },
                       apiTestReturn: visible.contains { $0.apiTag == "テスト返却" },
                       weekendEventLabels: day.schoolWeekday > 5 ? Array(Set(visible.filter {
                           $0.apiTag == "行事（授業なし）" || $0.apiTag == "補講日"
                       }.map(\.title))).sorted() : [])
    }
}
