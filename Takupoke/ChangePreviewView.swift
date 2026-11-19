import SwiftUI

struct ChangeRecordFields: View {
    let record: ScheduleChange
    let names: ChangePresentation

    var body: some View {
        LabeledContent("日付", value: record.displayDate)
        LabeledContent("クラス", value: TimetableDisplayText.className(record.displayClassName))
        field("時限", record.period.isEmpty ? "" : record.displayPeriod)
        field("変更前", names.before.detailSubject)
        field("変更前の教員", names.before.detailTeacher)
        field("変更前の教室", names.before.detailRoom)
        field("変更後", names.after.detailSubject)
        field("変更後の教員", names.after.detailTeacher)
        field("変更後の教室", names.after.detailRoom)
        field("備考", record.note)
        DisclosureGroup("元の記載") {
            if !record.before_subject.isEmpty { LabeledContent("変更前", value: record.before_subject) }
            if !record.after_subject.isEmpty { LabeledContent("変更後", value: record.after_subject) }
            if !record.raw_text.isEmpty { Text(record.originalForDisplay).textSelection(.enabled) }
        }
    }

    @ViewBuilder private func field(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { LabeledContent(title, value: TimetableDisplayText.kana(value)) }
    }
}

struct ChangePreviewView: View {
    let table: ChangeEditTable
    let edits: [Int: ChangeRowEdit]
    let pending: Set<Int>
    let year: Int
    @ObservedObject var mappings: MappingModel
    @State private var records: [ScheduleChange] = []
    @State private var selectedClass = ""
    @State private var error: String?

    var body: some View {
        List {
            if !pending.isEmpty {
                Text("確認中の\(pending.count)行を省いたプレビューです。").foregroundStyle(.secondary)
            }
            if let error { InlineWarning(error) }
            Picker("クラス", selection: $selectedClass) {
                Text("すべて").tag("")
                ForEach(Set(records.map(\.displayClassName)).sorted(), id: \.self) { name in
                    Text(TimetableDisplayText.className(name)).tag(name)
                }
            }
            let visible = records.filter { selectedClass.isEmpty || $0.displayClassName == selectedClass }
            ForEach(Array(visible.enumerated()), id: \.offset) { _, record in
                Section { ChangeRecordFields(record: record, names: mappings.names(for: record)) }
            }
        }
        .navigationTitle("時間割のプレビュー")
        .onAppear {
            var draft = edits
            for row in pending { draft[row, default: ChangeRowEdit()].excluded = true }
            do {
                records = try table.records(edits: draft, defaultYear: year)
                error = nil
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct ChangeGroupEditor: View {
    let group: ChangeIssueGroup
    let title: String
    let table: ChangeEditTable
    let year: Int
    let activeRows: Set<Int>
    let issues: [Int: [ChangeParseError]]
    @Binding var edits: [Int: ChangeRowEdit]
    @Binding var conflicts: Set<Int>
    let verify: () -> Void
    @State private var selected: Set<Int> = []
    @State private var replacement = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text(ChangeReviewGroup.rangeLabel(group.rows))
                if group.carryover?.offersPriorExclusion == true { Text("以前は除外されていました。") }
                let allSelected = !activeRows.isEmpty && activeRows.isSubset(of: selected)
                selectionButton("すべて選択（\(activeRows.count)行）", selected: allSelected) {
                    selected = allSelected ? [] : activeRows
                }
                .disabled(activeRows.isEmpty)
                .accessibilityIdentifier("change-select-all")
                if group.saved != nil {
                    Button("選んだ行のこの修正を解除") { finish(.undo) }.disabled(selected.isDisjoint(with: activeRows))
                }
                if group.code == .weekdayMismatch {
                    Button("選んだ行の曜日を補完") { finish(.weekday) }
                        .disabled(selected.isDisjoint(with: activeRows) || !selected.intersection(activeRows).allSatisfy { row in
                            table.normalizedDate(table.values(at: row, edit: edits[row] ?? ChangeRowEdit(), defaultYear: year),
                                                 row: row, edit: edits[row] ?? ChangeRowEdit(), defaultYear: year) != nil
                        })
                }
                if group.code != .weekdayOnly && table.headers.indices.contains(group.column) {
                    TextField(table.headers[group.column] + "の修正値", text: $replacement)
                        .accessibilityIdentifier("change-group-value")
                    Button("選んだ行に入力") { finish(.value(replacement)) }
                        .disabled(selected.isDisjoint(with: activeRows) || replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let carryover = group.carryover {
                    Button(carryover.offersPriorExclusion ? "選んだ行に以前の除外を適用" : "選んだ行を今回除外") { finish(.exclude) }
                        .disabled(selected.isDisjoint(with: activeRows))
                        .accessibilityIdentifier("change-confirm-carryover-exclusion")
                } else if group.saved != .excluded {
                    Button("選んだ行を除外") { finish(.exclude) }.disabled(selected.isDisjoint(with: activeRows))
                }
            }
            Section("対象の行") {
                ForEach(group.rows, id: \.self) { row in
                    selectionButton("\(row)行目を選択", selected: selected.contains(row)) {
                        if selected.contains(row) { selected.remove(row) } else { selected.insert(row) }
                    }
                    .disabled(!activeRows.contains(row))
                    .accessibilityIdentifier("change-select-row-\(row)")
                    NavigationLink(value: row) {
                        VStack(alignment: .leading) {
                            Text("\(row)行目を編集")
                            if let count = issues[row]?.count, count > 0 {
                                Text("要確認\(count)項目").font(.callout)
                            }
                            if group.code == .weekdayMismatch, let change = table.weekdayComparison(
                                row: row, edit: edits[row] ?? ChangeRowEdit(), year: year
                            ) {
                                Text(change)
                            }
                            Text(table.summary(row: row, edit: edits[row] ?? ChangeRowEdit(), year: year))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("change-editor-row-\(row)")
                }
            }
        }
        .navigationTitle(title)
    }

    private func selectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }.contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func finish(_ action: ChangeIssueGroup.Action) {
        let targets = selected.intersection(activeRows)
        if group.carryover != nil {
            group.confirmExclusions(selecting: targets, table: table, defaultYear: year, edits: &edits, conflicts: &conflicts)
        } else {
            group.apply(action, selecting: targets, headers: table.headers, edits: &edits)
        }
        verify()
        dismiss()
    }
}
