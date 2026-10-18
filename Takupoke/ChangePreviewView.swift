import SwiftUI

struct ChangePreviewView: View {
    let preview: ChangePreview
    @ObservedObject var mappings: MappingModel
    var actionFailure: String? = nil
    var operationFailure: String? = nil
    var processing = false
    var cancelProcessing: (() -> Void)? = nil
    var correctWeekdays: (() -> String?)? = nil
    var skipRows: ((Set<Int>) -> String?)? = nil
    var skipRowsWithCorrection: ((Set<Int>, Bool) -> String?)? = nil
    @State private var rejectedAction: String?
    @State private var confirmingCorrection = false
    @State private var confirmingSkip = false
    @State private var excludedRows = Set<Int>()
    @State private var correctRemainingWeekdays = false
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
                    if let failure = actionFailure ?? rejectedAction {
                        Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    if let operationFailure {
                        Label(operationFailure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    if processing { LoadingRow(title: "確認した原本を再取得・解析中⋯", cancel: cancelProcessing) }
                    if skipRows != nil {
                        Text("選択した行を今回の除外対象として保存します。以前の除外対象も選択済みで表示します。")
                        if preview.usesDateDerivedWeekdays {
                            Text("この資料の曜日は、確認済みの日付から計算します。")
                        } else if skipRowsWithCorrection != nil && preview.warnings.contains(where: \.canCorrectWeekday) {
                            Toggle("残す行の曜日を日付から求める", isOn: $correctRemainingWeekdays)
                                .disabled(actionFailure != nil)
                        }
                    }
                    LabeledContent("年なし日付の補完", value: preview.defaultYear.map { "\($0)年度" } ?? "指定なし")
                    LabeledContent("件数", value: "\(preview.records.count)件")
                    if correctWeekdays != nil {
                        Button("日付から曜日を求めて読み込む") { confirmingCorrection = true }
                            .buttonStyle(.glassProminent)
                            .disabled(actionFailure != nil)
                    }
                    DisclosureGroup("曜日の警告：\(preview.warnings.count)件") {
                        ForEach(preview.reviewGroups) { group in
                            let warning = group.rows[0].warning
                            if let printed = warning.printedWeekday, let calculated = warning.calculatedWeekday {
                                Text("\(group.rangeLabel)：\(printed) → \(calculated)曜日")
                            }
                            Text(group.rangeLabel + "：" +
                                 (warning.code == .weekdayOnly ? "曜日以外の値がありません。" :
                                  warning.code == .formulaCache ? "曜日の計算結果がありません。" : "曜日と月日が一致しないか、曜日の表記を確認できません。"))
                        }
                    }
                }
                ForEach(preview.reviewGroups) { group in
                    let row = group.rows[0]
                    Section("\(group.rangeLabel)の元の記載") {
                        ForEach(Array(row.fields.enumerated()), id: \.offset) { _, field in
                            LabeledContent(field.title, value: field.value)
                        }
                        if row.fields.isEmpty { Text("曜日の数式があります。保存された値はありません。") }
                        if group.rows.count > 1 {
                            Text("\(group.rows.count)行とも、曜日以外の値はありません。")
                        }
                        if skipRows != nil && row.canSkip {
                            Toggle(group.rows.count == 1 ? "この行を除外する" : "この\(group.rows.count)行をまとめて除外する", isOn: Binding(get: { group.rowIDs.isSubset(of: excludedRows) }, set: { value in
                                if value { excludedRows.formUnion(group.rowIDs) } else { excludedRows.subtract(group.rowIDs) }
                            }))
                            .accessibilityIdentifier(group.accessibilityID)
                            .disabled(actionFailure != nil)
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
                Button("この曜日で読み込む") { rejectedAction = correctWeekdays?() }
                    .disabled(actionFailure != nil)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("日付欄を基準に曜日を計算して、時間割変更へ反映します。ファイルの内容が更新されるまで自動的に適用します。")
            }
            .navigationTitle(correctWeekdays == nil && skipRows == nil ? "プレビュー（閲覧のみ）" : "内容の確認")
            .alert("選んだ行を除外して読み込む", isPresented: $confirmingSkip) {
                Button("除外して読み込む") {
                    if let skipRowsWithCorrection {
                        rejectedAction = skipRowsWithCorrection(excludedRows, correctRemainingWeekdays)
                    } else { rejectedAction = skipRows?(excludedRows) }
                }
                    .disabled(actionFailure != nil)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(excludedRows.count)行を時間割変更から除外します。除外する行：\(ChangeReviewGroup.rangeLabel(Array(excludedRows)))。ファイルの内容が更新されるまで適用します。")
                if correctRemainingWeekdays { Text("残す行の曜日は日付から計算します。") }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(processing ? "解析を中止" : (correctWeekdays == nil && skipRows == nil ? "閉じる" : "キャンセル")) {
                        if processing { cancelProcessing?() } else { dismiss() }
                    }
                }
                if skipRows != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("除外して読み込む") { confirmingSkip = true }
                            .buttonStyle(.glassProminent)
                            .disabled((excludedRows.isEmpty && !correctRemainingWeekdays) || actionFailure != nil)
                            .accessibilityIdentifier("change-apply-skips")
                    }
                }
            }
        }
        .onAppear {
            excludedRows = preview.excludedRows
            correctRemainingWeekdays = preview.usesDateDerivedWeekdays
        }
        .interactiveDismissDisabled(processing)
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
