import SwiftUI
import UIKit

extension TimetableView {
    var weekGrid: some View {
        let days = TimetableSchedule.displayedDays(weekStart: weekStart, classes: selectedClasses,
                                                   timetable: timetable, changes: changes, events: events,
                                                   includesChanges: includesChanges,
                                                   isInternationalStudent: isInternationalStudent,
                                                   specials: specials, matchedByRule: isMappedInternational)
        let columns = days.map(dayLayout)
        let eventsOnly = !columns.isEmpty && columns.allSatisfy { $0.fullDayEventTitle != nil }
        let rowHeights = gridRowHeights(columns, days: days)
        return ScrollView(.horizontal) {
            Group {
                if eventsOnly {
                    HStack(alignment: .top, spacing: gridSpacing) {
                        Color.clear.frame(width: periodColumnWidth, height: 1)
                        ForEach(columns, id: \.day) { column in
                            VStack(spacing: gridSpacing) {
                                dayHeaderCell(column)
                                if let title = column.fullDayEventTitle {
                                    fullDayEventCard(title, width: column.width, height: nil)
                                }
                            }
                        }
                    }
                } else {
                    Grid(alignment: .topLeading, horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
                        GridRow {
                            Text("時限")
                                .font(periodHeadingFont)
                                .frame(width: periodColumnWidth, alignment: .center)
                                .gridCellAnchor(.center)
                            ForEach(columns, id: \.day) { column in
                                dayHeaderCell(column).gridCellAnchor(.center)
                            }
                        }
                        GridRow {
                            VStack(spacing: gridSpacing) {
                                ForEach(1...8, id: \.self) { period in
                                    let commonTime = commonPeriodTime(period, days: days)
                                    VStack(spacing: 2) {
                                        Text("\(period)").font(periodNumberFont)
                                        if let commonTime {
                                            Text(TimetableDisplayText.periodTime(commonTime))
                                                .font(periodClockFont)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .multilineTextAlignment(.center)
                                    .frame(width: periodColumnWidth, height: rowHeights[period - 1], alignment: .center)
                                }
                            }
                            ForEach(columns, id: \.day) { column in
                                dayColumn(column, days: days, rowHeights: rowHeights)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, gridSpacing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: WeekGridWidthKey.self, value: proxy.size.width)
        })
        .background(periodColumnMeasurement)
        .onPreferenceChange(PeriodColumnWidthKey.self) { width in
            let fittedWidth = ceil(width) + 2
            guard width > 0, abs(periodColumnWidth - fittedWidth) > 0.5 else { return }
            periodColumnWidth = fittedWidth
            dayHeaderHeight = 0
        }
        .onPreferenceChange(WeekGridWidthKey.self) { width in
            guard width > 0, abs(gridViewportWidth - width) > 0.5 else { return }
            gridViewportWidth = width
            dayHeaderHeight = 0
        }
        .onPreferenceChange(DayHeaderHeightKey.self) { height in
            if abs(dayHeaderHeight - height) > 0.5 { dayHeaderHeight = height }
        }
        .accessibilityLabel("\(selectedClasses.map(TimetableDisplayText.className).joined(separator: "・"))の週の時間割")
    }

    var weekEvents: some View {
        let rows = (0..<7).compactMap { weekStart.addingDays($0) }.compactMap { day -> (SchoolDate, [String])? in
            let titles = TimetableSchedule.events(on: day, analysis: events).map(\.title)
            return titles.isEmpty ? nil : (day, titles)
        }
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                        Text(TimetableDisplayText.kana("\(entry.0.month)/\(entry.0.day) " + entry.1.joined(separator: "・")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct WeekGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
