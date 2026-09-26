import SwiftUI

struct ChangePreviewView: View {
    let preview: ChangePreview
    @ObservedObject var mappings: MappingModel
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
                    Text("曜日に不整合があります。日付を元ファイルで確認してください。")
                    Text(preview.sourceName)
                    LabeledContent("年なし日付の補完", value: preview.defaultYear.map { "\($0)年度" } ?? "指定なし")
                    LabeledContent("件数", value: "\(preview.records.count)件")
                    DisclosureGroup("曜日の警告：\(preview.warnings.count)件") {
                        ForEach(Array(preview.warnings.enumerated()), id: \.offset) { _, warning in
                            Text((warning.row.map { "\($0)行目：" } ?? "") +
                                 (warning.code == .formulaCache ? "曜日の計算結果がありません。" : "曜日と月日が一致しないか、曜日の表記を確認できません。"))
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
            .navigationTitle("プレビュー（閲覧のみ）")
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
