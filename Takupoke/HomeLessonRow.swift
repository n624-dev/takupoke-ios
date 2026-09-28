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
                        Text(TimetableDisplayText.continuous(names.cellSubject.isEmpty ? "変更を確認" : names.cellSubject))
                            .font(.headline)
                    }
                    let metadata = [names.cellTeacher, names.cellRoom].filter { !$0.isEmpty }
                    if !metadata.isEmpty {
                        Text(TimetableDisplayText.continuous(metadata.joined(separator: "・")))
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
        .accessibilityHint("授業詳細を開きます")
    }
}
