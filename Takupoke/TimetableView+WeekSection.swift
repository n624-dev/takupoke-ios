import SwiftUI

extension TimetableView {
    var weekSection: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                weekControlRow(compact: false)
                weekControlRow(compact: true)
                VStack(spacing: 8) {
                    calendarButton(compact: true)
                    HStack {
                        previousWeekButton
                        Spacer()
                        nextWeekButton
                    }
                }
            }
            .buttonStyle(.glass)
            .tint(nil as Color?)
            Picker("表示モード", selection: $includesChanges) {
                Text("通常").tag(false)
                Text("変更込み").tag(true)
            }
            .pickerStyle(.segmented)
            if let timetable, TimetableSchedule.termRange(for: timetable) == nil {
                InlineWarning("通常時間割の学期を確認できません。元PDFを再解析してください。")
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
                InlineWarning("通常時間割は前回の解析結果です。")
            }
            if let changes, model.state.record(for: .changes).map({ changes.matches(record: $0,
                defaultYear: ChangeNormalizer.effectiveSchoolYear(configured: changeSchoolYear, today: today)) }) != true {
                InlineWarning("時間割変更は前回の解析結果です。")
            }
            if schoolEvents.ready && !SchoolEventsCoverage(savedYears: Set(schoolEvents.saved.keys)).coversWeek(starting: weekStart) {
                Label("学校行事は未取得です。", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            SchoolEventsWarnings(model: schoolEvents)
            SpecialScheduleWarnings(model: specialSchedules)
            if selectedClasses.isEmpty {
                if savedClasses.isEmpty {
                    Text("クラスを設定すると時間割を表示します。").foregroundStyle(.secondary)
                } else {
                    InlineWarning("保存したクラスは現在の資料に見つかりません。資料を再解析するか、クラスを選び直してください。")
                }
            } else {
                weekGrid
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            weekEvents
        } header: { Text("週の時間割") }
    }

    private func weekControlRow(compact: Bool) -> some View {
        HStack(spacing: 6) {
            previousWeekButton
            Spacer(minLength: 0)
            calendarButton(compact: compact)
            Spacer(minLength: 0)
            nextWeekButton
        }
    }

    @ViewBuilder private var previousWeekButton: some View {
        if canMovePrevious {
            Button("前週") { moveWeek(-7) }
                .foregroundStyle(weekControlColor)
                .fixedSize()
        }
    }

    @ViewBuilder private var nextWeekButton: some View {
        if canMoveNext {
            Button("翌週") { moveWeek(7) }
                .foregroundStyle(weekControlColor)
                .fixedSize()
        }
    }

    private func calendarButton(compact: Bool) -> some View {
        let end = weekStart.addingDays(6)!
        return Button(action: openWeekPicker) {
            Label(weekStart.weekRangeLabel(ending: end, compact: compact), systemImage: "calendar")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(weekControlColor)
        }
        .fixedSize()
        .accessibilityLabel("\(weekStart.month)月\(weekStart.day)日から\(end.month)月\(end.day)日")
        .accessibilityIdentifier("timetable-week-calendar")
        .accessibilityHint("カレンダーで表示する週を選びます")
    }
}
