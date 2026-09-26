import SwiftUI

extension TimetableView {
    var changesSection: some View {
        let visible = listClasses.flatMap { className in
            TimetableSchedule.changes(in: changes, className: className, range: changeRange,
                                      today: today, weekStart: weekStart)
        }.filter { TimetableSchedule.shouldDisplay($0, isInternationalStudent: isInternationalStudent,
                                                   matchedByRule: isMappedInternational) }
            .sorted { ($0.change_date, $0.period, $0.displayClassName) < ($1.change_date, $1.period, $1.displayClassName) }
        return Section {
            Picker("表示範囲", selection: Binding(
                get: { changeRange }, set: { changeRangeValue = $0.rawValue })) {
                ForEach(ChangeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            NavigationLink {
                TimetableChangeClassSelection(classes: classes, value: Binding(
                    get: { changeClassesValue.isEmpty ? selectedClassesValue : changeClassesValue },
                    set: { changeClassesValue = $0 }))
            } label: {
                LabeledContent("対象クラス", value: changeClassesValue.isEmpty
                    ? (savedClasses.isEmpty ? "未選択" : TimetableDisplayText.classNames(savedClasses))
                    : TimetableDisplayText.classNames(savedChangeClasses))
            }
            if !changeClassesValue.isEmpty && savedChangeClasses.contains(where: { !availableClasses.contains($0) }) {
                Label("保存した対象クラスの一部は現在の資料にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if !changeClassesValue.isEmpty {
                Button("時間割設定に戻す") { changeClassesValue = "" }
            }
            if listClasses.isEmpty {
                Text("対象クラスを選んでください。")
                    .foregroundStyle(.secondary)
            } else if changes == nil {
                Text("時間割変更の解析結果がありません。")
                    .foregroundStyle(.secondary)
            } else if visible.isEmpty {
                Text("この範囲の時間割変更はありません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, change in
                    let selection = changeSelection(for: change)
                    Button {
                        selectedChange = selection
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.change_date) · \(TimetableDisplayText.className(change.displayClassName)) · \(change.period.isEmpty ? "時限未記載" : change.displayPeriod)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(TimetableDisplayText.kana(changeSummary(selection))).font(.subheadline)
                            if !change.note.isEmpty { Text(TimetableDisplayText.kana(change.note)).font(.caption).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: { Text("時間割変更一覧") }
    }

    func beforeSubject(_ selection: ChangeSelection) -> String {
        if !selection.change.before_subject.isEmpty {
            return mappings.names(for: selection.change).before.cellSubject
        }
        let names = selection.baseLessons.map(\.names.cellSubject).reduce(into: [String]()) { result, name in
            if !name.isEmpty && !result.contains(name) { result.append(name) }
        }
        return names.isEmpty ? "記載なし" : names.joined(separator: "・")
    }

    private func changeSummary(_ selection: ChangeSelection) -> String {
        let before = beforeSubject(selection)
        let parsedAfter = mappings.names(for: selection.change).after.cellSubject
        let after = parsedAfter.isEmpty ? "記載なし" : parsedAfter
        return "\(before) → \(after)"
    }

    func changeSelection(for change: ScheduleChange) -> ChangeSelection {
        guard let day = SchoolDate(iso8601: change.change_date) else {
            return ChangeSelection(change: change, baseLessons: [], baseSpecialLessons: [], relatedChanges: [])
        }
        let periods = change.gridPeriods ?? []
        let originals = periods.map { period in
            TimetableSchedule.slot(on: day, period: period, className: change.displayClassName,
                                   timetable: timetable, changes: nil, includesChanges: false,
                                   events: events, specials: specials)
        }
        let related = TimetableSchedule.changes(on: day, className: change.displayClassName, analysis: changes)
            .filter { $0 != change && !Set($0.gridPeriods ?? []).isDisjoint(with: periods) }
        return ChangeSelection(change: change, baseLessons: originals.flatMap(\.baseLessons),
                               baseSpecialLessons: originals.flatMap(\.specialLessons), relatedChanges: related)
    }
}
