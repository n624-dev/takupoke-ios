import SwiftUI

extension TimetableView {
    var weekSection: some View {
        Section {
            HStack {
                if canMovePrevious {
                    Button { moveWeek(-7) } label: {
                        Text("前週").foregroundStyle(weekControlColor)
                    }
                }
                Spacer()
                Button {
                    openWeekPicker()
                } label: {
                    Label("\(weekStart.month)/\(weekStart.day)〜\(weekStart.addingDays(6)!.month)/\(weekStart.addingDays(6)!.day)",
                          systemImage: "calendar")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(weekControlColor)
                }
                .accessibilityLabel("\(weekStart.month)月\(weekStart.day)日から\(weekStart.addingDays(6)!.month)月\(weekStart.addingDays(6)!.day)日")
                .accessibilityHint("カレンダーで表示する週を選びます")
                Spacer()
                if canMoveNext {
                    Button { moveWeek(7) } label: {
                        Text("翌週").foregroundStyle(weekControlColor)
                    }
                }
            }
            .buttonStyle(.bordered)
            // Keep the standard neutral background; theme only the labels.
            .tint(nil as Color?)
            Picker("表示モード", selection: $includesChanges) {
                Text("通常").tag(false)
                Text("変更込み").tag(true)
            }
            .pickerStyle(.segmented)
            if let timetable, TimetableSchedule.termRange(for: timetable) == nil {
                Label("通常時間割の学期を確認できません。元PDFを再解析してください。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if timetable == nil {
                Label("通常時間割の解析結果がありません。", systemImage: "doc.questionmark")
                    .foregroundStyle(.secondary)
            }
            if includesChanges && changes == nil {
                Label("時間割変更の解析結果がありません。", systemImage: "doc.questionmark")
                    .foregroundStyle(.secondary)
            }
            if let timetable, timetable.sourceDigest != model.state.record(for: .timetable)?.digest ||
                timetable.version != PDFAnalysis.currentVersion(for: .timetable) {
                Label("通常時間割は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let changes, changes.sourceDigest != model.state.record(for: .changes)?.digest ||
                changes.version != ChangeAnalysis.parserVersion {
                Label("時間割変更は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if !SchoolEventsCoverage(savedYears: Set(schoolEvents.saved.keys)).coversWeek(starting: weekStart) {
                Label("学校行事は未取得です。", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            if let sourceCheckMessage = schoolEvents.sourceCheckMessage {
                Label(sourceCheckMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            ForEach(SpecialScheduleKind.allCases) { kind in
                if let source = specialSchedules.sources[kind],
                   let record = specialSchedules.records[kind],
                   source.digest != record.digest || record.analysis.version != SpecialScheduleAnalysis.parserVersion {
                    Label("\(kind.title)は前回の解析結果です。", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            if selectedClasses.isEmpty {
                Text(savedClasses.isEmpty ? "クラスを設定すると時間割を表示します。" :
                     "保存したクラスは現在の資料に見つかりません。資料を再解析するか、クラスを選び直してください。")
                    .foregroundStyle(.secondary)
            } else {
                weekGrid
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            weekEvents
        } header: { Text("週の時間割") }
    }
}
