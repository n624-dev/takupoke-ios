import SwiftUI

extension TimetableView {
    func lessonDetail(_ selection: LessonSelection) -> some View {
        let lesson = selection.lesson
        let names = mappings.names(for: lesson)
        return List {
            Section("通常の授業") {
                LabeledContent("日付", value: selection.date.iso8601)
                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                LabeledContent("時限", value: selection.startPeriod == selection.endPeriod
                               ? "\(selection.startPeriod)限" : "\(selection.startPeriod)〜\(selection.endPeriod)限")
                LabeledContent("時刻", value: normalTime(from: selection.startPeriod, to: selection.endPeriod))
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
        let names = mappings.names(for: change)
        let specialTimes = Set(selection.baseSpecialLessons.compactMap(\.timeRange))
        return List {
            Section("変更内容") {
                LabeledContent("日付", value: change.change_date)
                LabeledContent("クラス", value: TimetableDisplayText.className(change.displayClassName))
                LabeledContent("時限", value: change.displayPeriod)
                if let periods = change.gridPeriods, let first = periods.first, let last = periods.last,
                   !selection.baseLessons.isEmpty {
                    LabeledContent("時刻", value: normalTime(from: first, to: last))
                } else if specialTimes.count == 1, let time = specialTimes.first {
                    LabeledContent("時刻", value: time)
                }
                LabeledContent("変更前", value: TimetableDisplayText.kana(
                    change.before_subject.isEmpty ? beforeSubject(selection) : names.before.detailSubject))
                if change.before_subject.isEmpty && !selection.baseLessons.isEmpty {
                    Text("変更前は通常時間割から表示しています。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !names.before.detailTeacher.isEmpty {
                    LabeledContent("変更前の教員", value: TimetableDisplayText.kana(names.before.detailTeacher))
                }
                if !names.before.detailRoom.isEmpty {
                    LabeledContent("変更前の教室", value: TimetableDisplayText.kana(names.before.detailRoom))
                }
                LabeledContent("変更後", value: names.after.detailSubject.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailSubject))
                LabeledContent("変更後の教員", value: names.after.detailTeacher.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailTeacher))
                LabeledContent("変更後の教室", value: names.after.detailRoom.isEmpty ? "記載なし" : TimetableDisplayText.kana(names.after.detailRoom))
                if !change.note.isEmpty { LabeledContent("備考", value: TimetableDisplayText.kana(change.note)) }
                DisclosureGroup("元の記載") {
                    if !change.before_subject.isEmpty { LabeledContent("変更前", value: change.before_subject) }
                    if !change.after_subject.isEmpty { LabeledContent("変更後", value: change.after_subject) }
                    if !change.raw_text.isEmpty { Text(change.raw_text).textSelection(.enabled) }
                }
            }
            if !selection.baseLessons.isEmpty {
                Section("通常の時間割") {
                    ForEach(Array(selection.baseLessons.enumerated()), id: \.offset) { _, lesson in
                        let names = mappings.names(for: lesson)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimetableDisplayText.kana(names.detailSubject)).font(.headline)
                            if !names.detailTeacher.isEmpty { Text("教員：" + TimetableDisplayText.kana(names.detailTeacher)) }
                            if !names.detailRoom.isEmpty { Text("教室：" + TimetableDisplayText.kana(names.detailRoom)) }
                        }
                    }
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
                                Text("元の記載：" + related.raw_text).font(.caption)
                                    .foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            if !selection.baseSpecialLessons.isEmpty {
                Section("変更前の試験時間割・試験返却時間割") {
                    ForEach(Array(selection.baseSpecialLessons.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TimetableDisplayText.kana(item.lesson.subject)).font(.headline)
                            Text(item.kind.title).font(.caption).foregroundStyle(.secondary)
                            if let time = item.timeRange { Text("時刻：" + time) }
                            if !item.lesson.teacher.isEmpty { Text("教員：" + TimetableDisplayText.kana(item.lesson.teacher)) }
                            if !item.lesson.room.isEmpty { Text("教室：" + TimetableDisplayText.kana(item.lesson.room)) }
                        }
                    }
                }
            }
        }
        .navigationTitle("時間割変更")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LessonSelection: Identifiable {
    let id = UUID()
    let lesson: PDFLesson
    let date: SchoolDate
    let startPeriod: Int
    let endPeriod: Int
}

struct ChangeSelection: Identifiable {
    let id = UUID()
    let change: ScheduleChange
    let baseLessons: [PDFLesson]
    let baseSpecialLessons: [TimetableSchedule.SpecialItem]
    let relatedChanges: [ScheduleChange]
}

struct SpecialSelection: Identifiable {
    let id = UUID()
    let item: TimetableSchedule.SpecialItem
    let startPeriod: Int
    let endPeriod: Int
    let timeRange: String?
}
