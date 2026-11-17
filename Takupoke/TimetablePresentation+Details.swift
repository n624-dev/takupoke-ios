import SwiftUI

extension TimetablePresentation {
    func lessonDetail(_ selection: LessonSelection) -> some View {
        let lesson = selection.lesson
        let names = mappings.names(for: lesson)
        return List {
            Section("通常の授業") {
                LabeledContent("日付", value: selection.date.iso8601)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: selection.startPeriod == selection.endPeriod
                               ? "\(selection.startPeriod)限" : "\(selection.startPeriod)〜\(selection.endPeriod)限")
                LabeledContent("時刻", value: schedule.normalTime(from: selection.startPeriod, to: selection.endPeriod, on: selection.date))
                LabeledContent("科目", value: TimetableDisplayText.continuous(names.detailSubject))
                LabeledContent("教員", value: names.detailTeacher.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailTeacher))
                LabeledContent("教室", value: names.detailRoom.isEmpty ? "記載なし" : TimetableDisplayText.continuous(names.detailRoom))
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    func specialDetail(_ selection: SpecialSelection) -> some View {
        let item = selection.item
        let lesson = item.lesson
        return List {
            Section(item.kind.title) {
                LabeledContent("日付", value: lesson.date)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: selection.startPeriod == selection.endPeriod
                               ? "\(selection.startPeriod)限" : "\(selection.startPeriod)〜\(selection.endPeriod)限")
                if let time = selection.timeRange { LabeledContent("時刻", value: time) }
                LabeledContent("科目", value: TimetableDisplayText.continuous(lesson.subject))
                LabeledContent("教員", value: lesson.teacher.isEmpty ? "記載なし" : TimetableDisplayText.continuous(lesson.teacher))
                LabeledContent("教室", value: lesson.room.isEmpty ? "記載なし" : TimetableDisplayText.continuous(lesson.room))
                DisclosureGroup("元のセルの記載") {
                    Text(TimetableDisplayText.kana(lesson.lines.joined(separator: "\n"))).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("授業詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    func changeDetail(_ selection: ChangeSelection) -> some View {
        let change = selection.change
        let comparison = selection.comparison
        let times = schedule.changeTimeRanges(change)
        return List {
            Section("変更内容") {
                LabeledContent("日付", value: change.change_date)
                LabeledContent("クラス", value: TimetableDisplayText.className(change.displayClassName))
                LabeledContent("時限", value: change.displayPeriod)
                if times.contains(where: { $0 != nil }) {
                    ForEach(Array(times.enumerated()), id: \.offset) { _, time in
                        LabeledContent("時刻", value: time ?? "時刻未確認")
                    }
                }
                if change.personallyEdited == true { Text("個人修正を反映").font(.caption) }
            }
            ForEach(Array(comparison.groups.enumerated()), id: \.offset) { _, group in
                let prefix = comparison.groups.count > 1 ? group.periods.map(String.init).joined(separator: "・") + "限　" : ""
                if change.isCancellation || change.isMakeup {
                    Section(prefix + change.cardKindLabel) {
                        ForEach(group.pairs, id: \.field) { pair in
                            let value = change.isMakeup ? pair.after :
                                (pair.before.isEmpty && pair.field != .subject ? pair.after : pair.before)
                            if !value.isEmpty {
                                LabeledContent(pair.field.rawValue, value: TimetableDisplayText.kana(value))
                                if change.isCancellation, let source = pair.source { Text(source + "から補完").font(.caption) }
                            }
                        }
                    }
                } else {
                    let changed = group.pairs.filter(\.changed)
                    if !changed.isEmpty {
                        Section(prefix + "変更した項目") {
                            ForEach(changed, id: \.field) { pair in ChangeFieldRow(pair: pair) }
                        }
                    }
                    let remaining = group.pairs.filter { !$0.changed }
                    if !remaining.isEmpty {
                        Section(prefix + "その他の授業情報") {
                            ForEach(remaining, id: \.field) { pair in ChangeFieldRow(pair: pair) }
                        }
                    }
                }
                if !group.unresolved.isEmpty {
                    Section("変更前の候補") {
                        ForEach(Array(group.unresolved.enumerated()), id: \.offset) { _, base in
                            VStack(alignment: .leading) {
                                Text(group.periods.map(String.init).joined(separator: "・") + "限　" + base.source).font(.caption)
                                Text([base.names.detailSubject, base.names.detailTeacher, base.names.detailRoom]
                                    .filter { !$0.isEmpty }.joined(separator: "　"))
                            }
                        }
                    }
                }
            }
            Section("変更理由・備考") {
                LabeledContent("変更理由", value: change.reason ?? "記載なし")
                if change.reason != nil {
                    Text(change.personalReason == true ? "個人修正" : "元の資料").font(.caption)
                }
                let note = change.remainingNote ?? change.note
                if !note.isEmpty {
                    LabeledContent("備考", value: TimetableDisplayText.kana(note))
                }
            }
            Section("更新情報") {
                if let row = change.updated {
                    LabeledContent(row.hasTime ? "この変更の更新日時" : "この変更の更新日", value: row.display)
                    Text(change.personalUpdate == true ? "個人修正" : "元の資料").font(.caption)
                }
                if let file = displayedSourceDate {
                    LabeledContent("元ファイルの更新日時", value: ChangeTimestamp.japan(file))
                } else if change.updated == nil { LabeledContent("更新日時", value: "記載なし") }
                if let parsed = schedule.changes?.parsedAt { LabeledContent("端末での解析日時", value: ChangeTimestamp.japan(parsed)) }
            }
            Section {
                DisclosureGroup("元の記載") {
                    if !change.before_subject.isEmpty { LabeledContent("変更前", value: change.before_subject) }
                    if !change.after_subject.isEmpty { LabeledContent("変更後", value: change.after_subject) }
                    if !change.raw_text.isEmpty { Text(change.originalForDisplay).textSelection(.enabled) }
                }
            }
            if !selection.relatedChanges.isEmpty {
                Section("同じ時限のほかの変更") {
                    ForEach(Array(selection.relatedChanges.enumerated()), id: \.offset) { _, related in
                        let relatedNames = mappings.names(for: related)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimetableDisplayText.kana(related.note.isEmpty ? "時間割変更" : related.note))
                                .font(.headline)
                            Text("時限：" + related.displayPeriod)
                            if !relatedNames.before.detailSubject.isEmpty {
                                Text("変更前：" + TimetableDisplayText.kana(relatedNames.before.detailSubject))
                            }
                            if !relatedNames.after.detailSubject.isEmpty {
                                Text("変更後：" + TimetableDisplayText.kana(relatedNames.after.detailSubject))
                            }
                            if !related.raw_text.isEmpty {
                                Text("元の記載：" + related.originalForDisplay).font(.caption)
                                    .foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("時間割変更")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChangeFieldRow: View {
    let pair: ChangeComparison.Pair
    @Environment(\.dynamicTypeSize) private var size
    private var before: String { pair.before.isEmpty ? "記載なし" : TimetableDisplayText.kana(pair.before) }
    private var after: String { pair.after.isEmpty ? "記載なし" : TimetableDisplayText.kana(pair.after) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if pair.before == pair.after {
                LabeledContent(pair.field.rawValue, value: before)
            } else {
                Text(pair.field.rawValue).font(.headline)
                let layout = size.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(alignment: .top))
                layout {
                    VStack(alignment: .leading) { Text("変更前").font(.caption); Text(before) }
                    VStack(alignment: .leading) { Text("変更後").font(.caption); Text(after).fontWeight(pair.changed ? .bold : .regular) }
                }
            }
            if let source = pair.source { Text("変更前は" + source + "から補完").font(.caption).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pair.before == pair.after ? "\(pair.field.rawValue)、\(before)" :
            "\(pair.field.rawValue)、変更前、\(before)、変更後、\(after)")
        .accessibilityIdentifier("change-detail-" + (pair.field == .room ? "room" : pair.field == .teacher ? "teacher" : "subject"))
        .accessibilityValue(pair.source.map { "変更前は" + $0 + "から補完" } ?? "")
    }
}
