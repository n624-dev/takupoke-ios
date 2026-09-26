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
                            .font(.caption.bold())
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
                                    Text("\(period)").font(.system(size: 15, weight: .semibold))
                                    if let commonTime {
                                        Text(TimetableDisplayText.periodTime(commonTime))
                                            .font(.system(size: 9))
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
        .onPreferenceChange(DayHeaderHeightKey.self) { height in
            if abs(dayHeaderHeight - height) > 0.5 { dayHeaderHeight = height }
        }
        .accessibilityLabel("\(selectedClasses.map(TimetableDisplayText.className).joined(separator: "・"))の週の時間割")
    }

    private func dayHeaderCell(_ column: DayGridLayout) -> some View {
        dayHeader(on: column.day)
            .frame(width: column.width, height: dayHeaderHeight > 0 ? dayHeaderHeight : nil,
                   alignment: .top)
            .background(column.day == today ? Color.accentColor.opacity(0.14) :
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
    }

    private func dayLayout(_ day: SchoolDate) -> DayGridLayout {
        let positioned = selectedClasses.map { className in
            TimetableSchedule.positioned(TimetableSchedule.blocks(on: day, className: className,
                timetable: timetable, changes: changes, includesChanges: includesChanges, events: events,
                specials: specials, isInternationalStudent: isInternationalStudent,
                matchedByRule: isMappedInternational))
        }
        let widths = positioned.map { laneWidth($0) }
        let width = widths.reduce(0, +) + gridSpacing * CGFloat(max(0, widths.count - 1))
        return DayGridLayout(day: day, positioned: positioned, width: width,
                             fullDayEventTitle: TimetableSchedule.fullDayEventTitle(
                                plan: TimetableSchedule.dayPlan(on: day, events: events), layouts: positioned))
    }

    private func dayColumn(_ column: DayGridLayout, days: [SchoolDate], rowHeights: [CGFloat]) -> some View {
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

    private func fullDayEventCard(_ title: String, width: CGFloat, height: CGFloat?) -> some View {
        Text(TimetableDisplayText.kana(title))
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(3)
            .frame(width: width, height: height, alignment: .center)
            .frame(minHeight: height == nil ? gridRowHeight : nil)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3)))
            .accessibilityLabel(title)
    }

    private func dayHeader(on day: SchoolDate) -> some View {
        let plan = TimetableSchedule.dayPlan(on: day, events: events)
        return VStack(alignment: .center, spacing: 2) {
            VStack(spacing: 0) {
                Text("\(day.month)/\(day.day)").font(.subheadline.bold().monospacedDigit())
                Text("(\(weekdayNames[day.schoolWeekday - 1]))").font(.caption)
                if day == today { Text("今日").font(.caption2.bold()) }
            }
            ForEach(Array(plan.events.filter { $0.apiTag != "行事メモ" }.enumerated()), id: \.offset) { _, event in
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

    private func laneWidth(_ blocks: [TimetableSchedule.PositionedBlock]) -> CGFloat {
        let lanes = max(1, (blocks.map(\.lane).max() ?? -1) + 1)
        return CGFloat(lanes) * dayColumnWidth + CGFloat(lanes - 1) * gridSpacing
    }

    private func gridRowHeights(_ columns: [DayGridLayout], days: [SchoolDate]) -> [CGFloat] {
        var heights = Array(repeating: gridRowHeight, count: 8)
        var entries: [(SchoolDate, String, TimetableSchedule.GridBlock)] = []
        for column in columns {
            for (index, lane) in column.positioned.enumerated() {
                for entry in lane {
                    entries.append((column.day, selectedClasses[index], entry.block))
                }
            }
        }
        entries.sort { ($0.2.endPeriod - $0.2.startPeriod) < ($1.2.endPeriod - $1.2.startPeriod) }
        for (day, className, block) in entries {
            let start = block.startPeriod - 1
            let end = block.endPeriod
            let required = cardRequiredHeight(block, on: day, className: className, days: days)
            let available: CGFloat = heights[start..<end].reduce(CGFloat.zero, +) +
                CGFloat(end - start - 1) * gridSpacing
            if required > available { heights[end - 1] += required - available }
        }
        return heights
    }

    private func cardRequiredHeight(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                                    className: String, days: [SchoolDate]) -> CGFloat {
        var parts: [(String, CGFloat, UIFont.Weight, Int?)] = []
        switch block.content {
        case .normal(let lesson):
            parts.append((cardText(TimetableDisplayText.continuous(lesson.names.cellSubject),
                                   fontSize: 11, weight: .semibold, lines: 2), 11, .semibold, 2))
            if !lesson.names.cellTeacher.isEmpty {
                parts.append((cardText(TimetableDisplayText.continuous(lesson.names.cellTeacher), fontSize: 9), 9, .regular, 1))
            }
            if !lesson.names.cellRoom.isEmpty { parts.append((cardRoom(lesson.names.cellRoom), 9, .regular, 1)) }
        case .special(let item):
            parts.append((cardText(TimetableDisplayText.kana(item.lesson.subject),
                                   fontSize: 11, weight: .semibold, lines: 2), 11, .semibold, 2))
            if !item.lesson.teacher.isEmpty {
                parts.append((cardText(TimetableDisplayText.kana(item.lesson.teacher), fontSize: 9), 9, .regular, 1))
            }
            if !item.lesson.room.isEmpty { parts.append((cardRoom(item.lesson.room), 9, .regular, 1)) }
        case .change(let change):
            parts.append((change.cardKindLabel, 11, .semibold, 1))
            if !change.isCancellation {
                parts.append((changeCardSubject(change, names: mappings.names(for: change).after), 11, .semibold, nil))
            }
            let names = mappings.names(for: change).after
            if !names.cellTeacher.isEmpty {
                parts.append((cardText(TimetableDisplayText.kana(names.cellTeacher), fontSize: 9), 9, .regular, 1))
            }
            if !names.cellRoom.isEmpty { parts.append((cardRoom(names.cellRoom), 9, .regular, 1)) }
        }
        if (block.startPeriod != block.endPeriod || commonPeriodTime(block.startPeriod, days: days) == nil),
           let time = cardTime(block, on: day, className: className) {
            let timeIndex: Int
            if case .change = block.content { timeIndex = 2 }
            else { timeIndex = 1 }
            parts.insert((TimetableDisplayText.periodTime(time), 8.5, .regular, 3),
                         at: min(parts.count, timeIndex))
        }
        let width = dayColumnWidth - 10
        let textHeight = parts.reduce(CGFloat.zero) { total, part in
            let (value, size, weight, limit) = part
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let bounds = (value as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font], context: nil)
            let measured = max(font.lineHeight, ceil(bounds.height))
            return total + (limit.map { min(measured, font.lineHeight * CGFloat($0)) } ?? measured)
        }
        return textHeight + CGFloat(max(0, parts.count - 1)) + 10
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

private struct DayHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
