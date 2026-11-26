import Foundation

extension TimetableSchedule {
    struct GridBlock {
        enum Content {
            case normal(PDFLesson)
            case special(SpecialItem)
            case change(ScheduleChange)
        }

        var startPeriod: Int
        var endPeriod: Int
        let content: Content
    }

    struct PositionedBlock {
        let block: GridBlock
        let lane: Int
    }

    static func blocks(on day: SchoolDate, className: String, timetable: PDFAnalysis?,
                       changes: ChangeAnalysis?, includesChanges: Bool, events: PDFAnalysis? = nil,
                       specials: [SpecialScheduleAnalysis] = [], isInternationalStudent: Bool = false,
                       matchedByRule: ((String, String) -> Bool)? = nil) -> [GridBlock] {
        var result: [GridBlock] = []
        for period in 1...8 {
            let item = slot(on: day, period: period, className: className, timetable: timetable,
                            changes: changes, includesChanges: includesChanges, events: events, specials: specials)
            for lesson in item.displayedLessons where shouldDisplay(lesson, isInternationalStudent: isInternationalStudent,
                                                                    matchedByRule: matchedByRule) {
                if let previous = result.indices.last(where: { index in
                    guard result[index].endPeriod == period - 1,
                          case .normal(let old) = result[index].content else { return false }
                    return old.names.subject == lesson.names.subject && old.names.teacher == lesson.names.teacher &&
                        old.names.room == lesson.names.room
                }) {
                    result[previous].endPeriod = period
                } else {
                    result.append(GridBlock(startPeriod: period, endPeriod: period, content: .normal(lesson)))
                }
            }
            for special in item.displayedSpecialLessons where shouldDisplay(special, isInternationalStudent: isInternationalStudent,
                                                                            matchedByRule: matchedByRule) {
                if let previous = result.indices.last(where: { index in
                    guard result[index].endPeriod == period - 1,
                          case .special(let old) = result[index].content else { return false }
                    return old.kind == special.kind && old.lesson.subject == special.lesson.subject &&
                        old.lesson.teacher == special.lesson.teacher && old.lesson.room == special.lesson.room
                }) {
                    result[previous].endPeriod = period
                } else {
                    result.append(GridBlock(startPeriod: period, endPeriod: period, content: .special(special)))
                }
            }
            let visibleChanges = item.changes.filter { shouldDisplay($0,
                isInternationalStudent: isInternationalStudent, matchedByRule: matchedByRule) }
            if let change = effectiveChange(visibleChanges) {
                if let previous = result.indices.last(where: { index in
                    guard result[index].endPeriod == period - 1,
                          case .change(let old) = result[index].content else { return false }
                    return old == change
                }) {
                    result[previous].endPeriod = period
                } else {
                    result.append(GridBlock(startPeriod: period, endPeriod: period, content: .change(change)))
                }
            }
        }
        return result
    }

    /// Place overlapping cards in separate horizontal lanes within one class.
    static func positioned(_ blocks: [GridBlock]) -> [PositionedBlock] {
        var laneEnds: [Int] = []
        return blocks.enumerated().sorted {
            ($0.element.startPeriod, $0.offset) < ($1.element.startPeriod, $1.offset)
        }.map { _, block in
            let lane = laneEnds.firstIndex(where: { $0 < block.startPeriod }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(block.endPeriod) }
            else { laneEnds[lane] = block.endPeriod }
            return PositionedBlock(block: block, lane: lane)
        }
    }
}
