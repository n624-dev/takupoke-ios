import SwiftUI

extension TimetableView {
    var weekSection: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                weekControlRow(compact: false)
                weekControlRow(compact: true)
                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        calendarButton(compact: false)
                        calendarButton(compact: true, fitsOwnRow: true)
                    }
                    HStack {
                        previousWeekButton
                        Spacer()
                        nextWeekButton
                    }
                }
            }
            .buttonStyle(WeekControlButtonStyle())
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
        HStack(spacing: 0) {
            previousWeekButton
            Spacer(minLength: 6)
            calendarButton(compact: compact)
            Spacer(minLength: 6)
            nextWeekButton
        }
    }

    @ViewBuilder private var previousWeekButton: some View {
        if canMovePrevious {
            Button { moveWeek(-7) } label: {
                Text("前週").fixedSize().foregroundStyle(weekControlColor)
            }
            .fixedSize()
        }
    }

    @ViewBuilder private var nextWeekButton: some View {
        if canMoveNext {
            Button { moveWeek(7) } label: {
                Text("翌週").fixedSize().foregroundStyle(weekControlColor)
            }
            .fixedSize()
        }
    }

    private func calendarButton(compact: Bool, fitsOwnRow: Bool = false) -> some View {
        let end = weekStart.addingDays(6)!
        return Button(action: openWeekPicker) {
            HStack(spacing: 5) {
                Image(systemName: "calendar").fixedSize().accessibilityHidden(true)
                Text(weekStart.weekRangeLabel(ending: end, compact: compact))
                    .lineLimit(1)
                    .minimumScaleFactor(fitsOwnRow ? 0.65 : 1)
                    .fixedSize(horizontal: !fitsOwnRow, vertical: true)
            }
            .fixedSize(horizontal: !fitsOwnRow, vertical: true)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(weekControlColor)
        }
        .fixedSize(horizontal: !fitsOwnRow, vertical: true)
        .accessibilityLabel("\(weekStart.month)月\(weekStart.day)日から\(end.month)月\(end.day)日")
        .accessibilityIdentifier("timetable-week-calendar")
        .accessibilityHint("カレンダーで表示する週を選びます")
    }
}

// Give ViewThatFits the width of the actual title, icon and glass insets, including in a List row.
private struct WeekControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
    }
}
