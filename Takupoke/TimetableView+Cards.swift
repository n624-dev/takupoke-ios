import SwiftUI
import UIKit

extension TimetableView {
    func gridCard(_ block: TimetableSchedule.GridBlock, on day: SchoolDate,
                          className: String, days: [SchoolDate], height: CGFloat) -> some View {
        let time = cardTime(block, on: day, className: className)
        let isChange: Bool = {
            if case .change = block.content { return true }
            return false
        }()
        let isCancellation: Bool = {
            if case .change(let change) = block.content { return change.isCancellation }
            return false
        }()
        let showTime = block.startPeriod != block.endPeriod ||
            commonPeriodTime(block.startPeriod, days: days) == nil
        return Button {
            switch block.content {
            case .normal(let lesson):
                selectedLesson = LessonSelection(lesson: lesson, date: day,
                                                 startPeriod: block.startPeriod, endPeriod: block.endPeriod)
            case .special(let item):
                selectedSpecial = SpecialSelection(item: item, startPeriod: block.startPeriod,
                                                   endPeriod: block.endPeriod, timeRange: time)
            case .change(let change):
                selectedChange = changeSelection(for: change)
            }
        } label: {
            VStack(alignment: .center, spacing: 1) {
                switch block.content {
                case .normal(let lesson):
                    Text(cardText(TimetableDisplayText.continuous(lesson.names.cellSubject),
                                  fontSize: 11, weight: .semibold, lines: 2))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !lesson.names.cellTeacher.isEmpty {
                        Text(cardText(TimetableDisplayText.continuous(lesson.names.cellTeacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !lesson.names.cellRoom.isEmpty {
                        Text(cardRoom(lesson.names.cellRoom)).font(.system(size: 9)).lineLimit(1)
                    }
                case .special(let item):
                    Text(cardText(TimetableDisplayText.kana(item.lesson.subject),
                                  fontSize: 11, weight: .semibold, lines: 2))
                        .font(.system(size: 11, weight: .semibold)).lineLimit(2)
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !item.lesson.teacher.isEmpty {
                        Text(cardText(TimetableDisplayText.kana(item.lesson.teacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !item.lesson.room.isEmpty {
                        Text(cardRoom(item.lesson.room)).font(.system(size: 9)).lineLimit(1)
                    }
                case .change(let change):
                    let names = mappings.names(for: change).after
                    HStack(spacing: 1) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 8))
                        Text(change.cardKindLabel)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    if !isCancellation {
                        Text(changeCardSubject(change, names: names))
                            .font(.system(size: 11, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if showTime, let time {
                        Text(TimetableDisplayText.periodTime(time))
                            .font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(3)
                    }
                    if !names.cellTeacher.isEmpty {
                        Text(cardText(TimetableDisplayText.kana(names.cellTeacher), fontSize: 9))
                            .font(.system(size: 9)).lineLimit(1)
                    }
                    if !names.cellRoom.isEmpty {
                        Text(cardRoom(names.cellRoom)).font(.system(size: 9)).lineLimit(1)
                    }
                }
            }
            .padding(3)
            .frame(width: dayColumnWidth, height: height, alignment: .center)
            .multilineTextAlignment(.center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: dayColumnWidth, height: height)
        .foregroundStyle(isChange ? Color.orange : Color.primary)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("\(TimetableDisplayText.className(className)) " +
            (block.startPeriod == block.endPeriod ? "\(block.startPeriod)限" :
                "\(block.startPeriod)〜\(block.endPeriod)限") + "の授業詳細")
    }

    func cardRoom(_ source: String) -> String {
        let full = TimetableDisplayText.continuous(source)
        let compact = PDFDisplayText.continuous(TimetableDisplayText.halfwidthKana(source))
        return cardText(full, fontSize: 9, alternatives: [compact])
    }

    func changeCardSubject(_ change: ScheduleChange, names: TimetableLessonNames) -> String {
        let source = TimetableDisplayText.continuous(names.cellSubject)
        guard !source.isEmpty else { return cardText("変更を確認", fontSize: 11, weight: .semibold, lines: 2) }
        let short: String?
        if let rules = mappings.current?.rules, let lessons = timetable?.lessons {
            short = rules.shortSubject(for: change, in: lessons)
        } else {
            short = nil
        }
        let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let available = dayColumnWidth - 10
        return TimetableDisplayText.changeCardSubject(source, short: short) {
            ($0 as NSString).size(withAttributes: [.font: font]).width <= available
        }
    }

    func cardText(_ value: String, fontSize: CGFloat, weight: UIFont.Weight = .regular,
                          lines: Int = 1, width: CGFloat? = nil, alternatives: [String] = []) -> String {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let available = (width ?? dayColumnWidth - 8) - 2
        func fits(_ text: String) -> Bool {
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            if lines == 1 { return (text as NSString).size(withAttributes: attributes).width <= available }
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: available, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            return bounds.height <= font.lineHeight * CGFloat(lines) + 0.5
        }
        let primary = value.replacingOccurrences(of: "\n", with: " ")
        if fits(primary) { return primary }
        let candidates = alternatives.map { $0.replacingOccurrences(of: "\n", with: " ") }
        for candidate in candidates where fits(candidate) { return candidate }
        let fallback = candidates.last ?? primary
        let characters = Array(fallback)
        var lower = 0, upper = characters.count
        while lower < upper {
            let middle = (lower + upper + 1) / 2
            if fits(String(characters.prefix(middle)) + "⋯") { lower = middle }
            else { upper = middle - 1 }
        }
        return String(characters.prefix(lower)) + "⋯"
    }
}
