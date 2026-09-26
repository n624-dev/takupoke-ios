import SwiftUI
import UIKit

extension TimetableView {
    func dayLayout(_ day: SchoolDate) -> DayGridLayout {
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

    func laneWidth(_ blocks: [TimetableSchedule.PositionedBlock]) -> CGFloat {
        let lanes = max(1, (blocks.map(\.lane).max() ?? -1) + 1)
        return CGFloat(lanes) * dayColumnWidth + CGFloat(lanes - 1) * gridSpacing
    }

    func gridRowHeights(_ columns: [DayGridLayout], days: [SchoolDate]) -> [CGFloat] {
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
}
