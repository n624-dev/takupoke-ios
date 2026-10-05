import SwiftUI

struct HomeLessonRow: View {
    let block: TimetableSchedule.GridBlock
    let time: String?
    let names: TimetableLessonNames
    let inProgress: Bool
    let accent: Color
    let action: () -> Void

    private var change: ScheduleChange? {
        if case .change(let change) = block.content { return change }
        return nil
    }

    private var usesRawMetadata: Bool {
        if case .special = block.content { return true }
        return false
    }

    private var subjectText: String {
        let source = names.cellSubject.isEmpty ? "変更を確認" : (usesRawMetadata ? names.subject : names.cellSubject)
        let text = usesRawMetadata ? TimetableDisplayText.cardLine(TimetableDisplayText.kana(source)) : TimetableDisplayText.continuous(source)
        return TimetableDisplayText.cellSubject(text)
    }

    private var teacherText: String {
        if case .normal = block.content { return TimetableDisplayText.continuous(names.cellTeacher) }
        return TimetableDisplayText.cardLine(TimetableDisplayText.kana(usesRawMetadata ? names.teacher : names.cellTeacher))
    }

    private var roomText: String {
        TimetableDisplayText.continuous(usesRawMetadata ? names.room : names.cellRoom)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(time.map(TimetableDisplayText.periodTime) ?? "時刻未確認")
                    .font(.subheadline.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 56)
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 4) {
                    if change != nil || inProgress {
                        HStack(spacing: 8) {
                            if let change {
                                Label(change.cardKindLabel, systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.orange)
                            }
                            if inProgress { Text("授業中").foregroundStyle(accent) }
                        }.font(.caption.weight(.semibold))
                    }
                    if change?.isCancellation != true {
                        Text(subjectText)
                            .font(.headline)
                    }
                    let metadata = [teacherText, roomText].filter { !$0.isEmpty }
                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: "・"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .padding(.leading, 8)
            .overlay(alignment: .leading) {
                if inProgress { RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TimetableDisplayText.lessonAccessibilityLabel(
            names: names, time: time, kind: change?.cardKindLabel) + (inProgress ? "、授業中" : ""))
        .accessibilityHint("授業詳細を開きます")
    }
}
