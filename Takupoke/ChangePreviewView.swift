import SwiftUI

struct ChangePreviewView: View {
    let preview: ChangePreview
    @ObservedObject var mappings: MappingModel
    var correctWeekdays: (() -> Void)? = nil
    var skipRows: ((Set<Int>) -> Void)? = nil
    @State private var confirmingCorrection = false
    @State private var confirmingSkip = false
    @State private var excludedRows = Set<Int>()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedClass = ""

    private var classes: [String] { Set(preview.records.map(\.displayClassName)).sorted() }
    private var visible: [ScheduleChange] {
        preview.records.filter { selectedClass.isEmpty || $0.displayClassName == selectedClass }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("警告のあるファイルを閲覧しています", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("曜日に問題のある行があります。元の記載を確認してください。")
                    Text(preview.sourceName)
                    LabeledContent("年なし日付の補完", value: preview.defaultYear.map { "\($0)年度" } ?? "指定なし")
                    LabeledContent("件数", value: "\(preview.records.count)件")
                    if correctWeekdays != nil {
                        Button("日付から曜日を求めて読み込む") { confirmingCorrection = true }
                            .buttonStyle(.glassProminent)
                    }
                    if skipRows != nil {
                        Button("選んだ行を除外して読み込む") { confirmingSkip = true }
                            .buttonStyle(.glassProminent)
                            .disabled(excludedRows.isEmpty)
                            .accessibilityIdentifier("change-apply-skips")
                    }
                    DisclosureGroup("曜日の警告：\(preview.warnings.count)件") {
                        ForEach(Array(preview.warnings.enumerated()), id: \.offset) { _, warning in
                            if let printed = warning.printedWeekday, let calculated = warning.calculatedWeekday {
                                Text("\(warning.row.map { "\($0)行目：" } ?? "")\(printed) → \(calculated)曜日")
                            }
                            Text((warning.row.map { "\($0)行目：" } ?? "") +
                                 (warning.code == .weekdayOnly ? "曜日以外の値がありません。" :
                                  warning.code == .formulaCache ? "曜日の計算結果がありません。" : "曜日と月日が一致しないか、曜日の表記を確認できません。"))
                        }
                    }
                }
                ForEach(preview.reviewRows) { row in
                    Section("\(row.id)行目の元の記載") {
                        ForEach(Array(row.fields.enumerated()), id: \.offset) { _, field in
                            LabeledContent(field.title, value: field.value)
                        }
                        if row.fields.isEmpty { Text("曜日の数式があります。保存された値はありません。") }
                        if skipRows != nil && row.canSkip {
                            Toggle("この行を除外する", isOn: Binding(get: { excludedRows.contains(row.id) }, set: { value in
                                if value { excludedRows.insert(row.id) } else { excludedRows.remove(row.id) }
                            }))
                            .accessibilityIdentifier("change-skip-row-\(row.id)")
                        }
                    }
                }
                Section {
                    Picker("クラス", selection: $selectedClass) {
                        Text("すべて").tag("")
                        ForEach(classes, id: \.self) { Text(TimetableDisplayText.className($0)).tag($0) }
                    }
                }
                ForEach(Array(visible.enumerated()), id: \.offset) { _, record in
                    Section { ChangeRecordFields(record: record, names: mappings.names(for: record)) }
                }
            }
            .alert("日付から求めた曜日で読み込む", isPresented: $confirmingCorrection) {
                Button("この曜日で読み込む") { correctWeekdays?() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("日付欄を基準に曜日を計算して、時間割変更へ反映します。ファイルの内容が更新されるまで自動的に適用します。")
            }
            .navigationTitle(correctWeekdays == nil && skipRows == nil ? "プレビュー（閲覧のみ）" : "内容の確認")
            .alert("選んだ行を除外して読み込む", isPresented: $confirmingSkip) {
                Button("除外して読み込む") { skipRows?(excludedRows) }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(excludedRows.count)行を時間割変更から除外します。除外する行：\(excludedRows.sorted().map(String.init).joined(separator: "、"))。ファイルの内容が更新されるまで適用します。")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}

struct ChangeRecordFields: View {
    let record: ScheduleChange
    let names: ChangePresentation

    var body: some View {
        LabeledContent("日付", value: record.change_date)
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
            if !record.raw_text.isEmpty { Text(record.raw_text).textSelection(.enabled) }
        }
    }

    @ViewBuilder private func field(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { LabeledContent(title, value: TimetableDisplayText.kana(value)) }
    }
}
