import SwiftUI
import UIKit

extension TimetableView {
    var periodHeadingFont: Font { .caption.bold() }
    var periodNumberFont: Font { .system(size: 15, weight: .semibold) }
    var periodClockFont: Font { .system(size: 9) }

    // Measure unconstrained SwiftUI text with the same fonts and environment as
    // the visible column. Include source times even in an events-only week so
    // hiding the period labels does not shift the day columns.
    var periodColumnMeasurement: some View {
        let ranges = TimetableSchedule.normalPeriodTimes + specials.flatMap { analysis in
            Array(analysis.periodTimes.values) + analysis.lessons.compactMap(\.timeRange)
        }
        let times = Set(ranges.map(TimetableDisplayText.periodTime)).sorted()
        return VStack(spacing: 0) {
            Text("時限").font(periodHeadingFont)
            ForEach(1...8, id: \.self) { period in
                Text("\(period)").font(periodNumberFont)
            }
            ForEach(times, id: \.self) { time in
                Text(time).font(periodClockFont)
            }
        }
        .fixedSize()
        .background(GeometryReader { proxy in
            Color.clear.preference(key: PeriodColumnWidthKey.self, value: proxy.size.width)
        })
        .hidden()
        .accessibilityHidden(true)
    }

    func dayHeaderCell(_ column: DayGridLayout) -> some View {
        dayHeader(on: column.day, hasFullDayCard: column.fullDayEventTitle != nil)
            .frame(width: column.width, height: dayHeaderHeight > 0 ? dayHeaderHeight : nil,
                   alignment: .top)
            .background(column.day == today ? Color.accentColor.opacity(0.14) :
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
    }

    private func dayHeader(on day: SchoolDate, hasFullDayCard: Bool) -> some View {
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        return VStack(alignment: .center, spacing: 2) {
            VStack(spacing: 0) {
                Text("\(day.month)/\(day.day)").font(.subheadline.bold().monospacedDigit())
                Text("(\(weekdayNames[day.schoolWeekday - 1]))").font(.caption)
                if day == today { Text("今日").font(.caption2.bold()) }
            }
            ForEach(Array(plan.headerEvents(hasFullDayCard: hasFullDayCard).enumerated()), id: \.offset) { _, event in
                Text(TimetableDisplayText.kana(event.title))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.apiTest && selectedClasses.contains(where: { className in
                !specials.contains { $0.kind == .exam && $0.applies(date: day.iso8601, className: className) }
            }) {
                Text("試験時間割：未公開または未解析です")
                    .font(.caption2).foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.apiTestReturn && selectedClasses.contains(where: { className in
                !specials.contains { $0.kind == .examReturn && $0.applies(date: day.iso8601, className: className) }
            }) {
                Text("試験返却時間割：未公開または未解析です")
                    .font(.caption2).foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: DayHeaderHeightKey.self, value: proxy.size.height)
        })
        .accessibilityElement(children: .combine)
    }
}

struct DayHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PeriodColumnWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
