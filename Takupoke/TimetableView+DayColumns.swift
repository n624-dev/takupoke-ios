import SwiftUI
import UIKit

extension TimetableView {
    func dayColumn(_ column: DayGridLayout, days: [SchoolDate], rowHeights: [CGFloat]) -> some View {
        let totalHeight = rowHeights.reduce(0, +) + 7 * gridSpacing
        return Group {
            if let title = column.fullDayEventTitle {
                fullDayEventCard(title, width: column.width, height: totalHeight)
            } else {
                HStack(alignment: .top, spacing: gridSpacing) {
                    ForEach(selectedClasses.indices, id: \.self) { index in
                        classLane(on: column.day, className: selectedClasses[index], days: days,
                                  positioned: column.positioned[index], rowHeights: rowHeights)
                    }
                }
            }
        }
        .frame(width: column.width, height: totalHeight, alignment: .topLeading)
    }

    func fullDayEventCard(_ title: String, width: CGFloat, height: CGFloat?) -> some View {
        Text(TimetableDisplayText.kana(title))
            .font(gridFont(14, weight: .semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(3)
            .frame(width: width, height: height, alignment: .center)
            .frame(minHeight: height == nil ? gridRowHeight : nil)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3)))
            .accessibilityLabel(title)
            .accessibilityIdentifier("timetable-event-\(title)")
    }
    private func classLane(on day: SchoolDate, className: String, days: [SchoolDate],
                           positioned: [TimetableSchedule.PositionedBlock], rowHeights: [CGFloat]) -> some View {
        let width = laneWidth(positioned)
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: gridSpacing) {
                ForEach(1...8, id: \.self) { period in
                    let occupied = positioned.contains { $0.block.startPeriod <= period && period <= $0.block.endPeriod }
                    Group {
                        if occupied || plan.isNoClass { Color.clear }
                        else { Text("—").foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center) }
                    }
                    .padding(6)
                    .frame(width: width, height: rowHeights[period - 1], alignment: .center)
                    .background(plan.isNoClass ? Color.orange.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
                }
            }
            ForEach(positioned.indices, id: \.self) { index in
                let entry = positioned[index]
                let span = entry.block.endPeriod - entry.block.startPeriod + 1
                let height = rowHeights[(entry.block.startPeriod - 1)..<entry.block.endPeriod].reduce(0, +) +
                    CGFloat(span - 1) * gridSpacing
                gridCard(entry.block, on: day, className: className, days: days, height: height)
                    .offset(x: CGFloat(entry.lane) * (dayColumnWidth + gridSpacing),
                            y: rowHeights.prefix(entry.block.startPeriod - 1).reduce(0, +) +
                                CGFloat(entry.block.startPeriod - 1) * gridSpacing)
            }
        }
        .frame(width: width, height: rowHeights.reduce(0, +) + 7 * gridSpacing, alignment: .topLeading)
    }

}
