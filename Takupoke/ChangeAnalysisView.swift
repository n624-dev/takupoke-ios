import SwiftUI

struct ChangeAnalysisView: View {
    @ObservedObject var model: MaterialsModel
    @AppStorage("changeDefaultSchoolYear") private var year = ""
    @AppStorage("changeAnalysisSelectedClass") private var selectedClass = ""
    @State private var confirmingPreview = false

    private var defaultYear: Int {
        ChangeNormalizer.effectiveSchoolYear(configured: year, today: SchoolDate.today())
    }
    private var validYear: Bool {
        year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            Int(year.trimmingCharacters(in: .whitespacesAndNewlines)).map { (1900...9998).contains($0) } == true
    }
    private var analysis: ChangeAnalysis? { model.state.changeAnalysis }
    private var classes: [String] { Set(analysis?.records.map(\.displayClassName) ?? []).sorted() }
    private var visible: [ScheduleChange] {
        (analysis?.records ?? []).filter { selectedClass.isEmpty || $0.displayClassName == selectedClass }
    }

    var body: some View {
        List {
            Section {
                TextField("年なし日付を補完する学校年度（例：2032）", text: $year)
                    .keyboardType(.numberPad).disabled(model.busy)
                Text("空欄なら今日の学校年度（\(SchoolDate.today().schoolYear)年度）を使います。4〜12月は入力年度、1〜3月は翌年の日付として解析します。")
                    .font(.caption).foregroundStyle(.secondary)
                if !validYear { Text("西暦1900〜9998の学校年度を入力してください。").foregroundStyle(.orange) }
                Text("ファイル選択後は自動解析します。必要なときは右上の「解析する」から再実行できます。")
                    .font(.caption).foregroundStyle(.secondary)
                if model.busy {
                    HStack { ProgressView(); Text("処理中…"); Spacer(); Button("中止") { model.cancel() } }
                }
                if let failure = model.state.changeParseAttempt?.failure {
                    Label(failure.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                if model.canPreviewChanges {
                    Button("警告を確認して内容を見る") { confirmingPreview = true }
                        .disabled(model.busy || !model.ready)
                }
                if let message = model.message, message != model.state.changeParseAttempt?.failure?.localizedDescription {
                    Text(message).font(.caption).foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
            } header: { Text("解析") }
            if let source = model.state.record(for: .changes) {
                Section("選択したファイル") {
                    Text(source.originalName)
                    LabeledContent("サイズ", value: ByteCountFormatter.string(
                        fromByteCount: Int64(source.byteCount), countStyle: .file))
                    LabeledContent("最終取得") {
                        Text(source.acquiredAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    if let date = source.lastCheckedAt {
                        LabeledContent("最終確認") {
                            Text(date, format: .dateTime.year().month().day().hour().minute())
                        }
                    }
                    if let date = source.sourceModifiedAt {
                        LabeledContent("元ファイルの更新") {
                            Text(date, format: .dateTime.year().month().day().hour().minute())
                        }
                    }
                    if let failure = model.state.attempts[MaterialKind.changes.rawValue]?.failure {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Button("同じファイルを再取得") { model.refresh(.changes) }
                        .disabled(model.busy || !model.ready)
                }
            }
            if let analysis = analysis {
                Section {
                    Text(analysis.sourceName)
                    LabeledContent("最終解析成功") { Text(analysis.parsedAt, format: .dateTime.year().month().day().hour().minute()) }
                    LabeledContent("年なし日付の補完", value: analysis.defaultYear.map(String.init) ?? "指定なし")
                    LabeledContent("解析件数", value: "\(analysis.records.count)件")
                    if analysis.sourceDigest != model.state.record(for: .changes)?.digest || analysis.version != ChangeAnalysis.parserVersion {
                        Label("前回の解析結果です。現在の資料を解析してください。", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                    Text("正常な解析結果を時間割の週表示に反映します。通知はまだ行いません。教員欄が空の場合、科目の併記から推測して補いません。")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("解析結果") }
                Section {
                    Picker("クラス", selection: $selectedClass) {
                        Text("すべて").tag("")
                        if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                            Text("\(selectedClass)（保存済み・現在の資料に該当なし）").tag(selectedClass)
                        }
                        ForEach(classes, id: \.self) { Text($0).tag($0) }
                    }
                    if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                        Label("選択したクラスは現在の解析結果にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                // Use positions so identical source rows remain visible as distinct records.
                ForEach(Array(visible.enumerated()), id: \.offset) { _, record in
                    Section { ChangeRecordFields(record: record) }
                }
            } else {
                Text("まだ正常な解析結果はありません。").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("時間割変更")
        .toolbar { ToolbarItem(placement: .primaryAction) { parseButton } }
        .scrollDismissesKeyboard(.interactively)
        .alert("曜日を確認できない資料です", isPresented: $confirmingPreview) {
            Button("確認して表示") { model.previewChanges() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("日付と曜日が合わないか、曜日の計算結果が保存されていません。日付欄を基準に内容を表示しますが、正しい内容かは元資料で確認してください。前回の正常データは置き換えません。")
        }
        .sheet(isPresented: Binding(get: { model.changePreview != nil }, set: { if !$0 { model.dismissPreview() } })) {
            if let preview = model.changePreview { ChangePreviewView(preview: preview) }
        }
    }

    @ViewBuilder private var parseButton: some View {
        if #available(iOS 26.0, *) {
            Button("解析する", systemImage: "doc.text.magnifyingglass") {
                model.analyzeChanges(defaultYear: defaultYear)
            }
            .buttonStyle(.glassProminent)
            .disabled(model.busy || !model.ready || !validYear || model.state.record(for: .changes) == nil)
        } else {
            Button("解析する") { model.analyzeChanges(defaultYear: defaultYear) }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy || !model.ready || !validYear || model.state.record(for: .changes) == nil)
        }
    }
}

private struct ChangePreviewView: View {
    let preview: ChangePreview
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
                    Label("警告のある資料を閲覧しています", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("日付欄を基準に表示しています。正常な解析結果としては保存せず、前回の正常データを保持しています。この画面を閉じるとプレビューは破棄します。")
                    Text(preview.sourceName)
                    LabeledContent("年なし日付の補完", value: preview.defaultYear.map(String.init) ?? "指定なし")
                    LabeledContent("表示件数", value: "\(preview.records.count)件")
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
                        ForEach(classes, id: \.self) { Text($0).tag($0) }
                    }
                }
                ForEach(Array(visible.enumerated()), id: \.offset) { _, record in
                    Section { ChangeRecordFields(record: record) }
                }
            }
            .navigationTitle("プレビュー（閲覧のみ）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}

private struct ChangeRecordFields: View {
    let record: ScheduleChange

    var body: some View {
        LabeledContent("日付", value: record.change_date)
        LabeledContent("クラス", value: record.displayClassName)
        field("時限", record.period)
        field("変更前", record.before_subject)
        field("変更後", record.after_subject)
        field("教員", record.teacher)
        field("教室", record.room)
        field("備考・変更内容", record.note)
    }

    @ViewBuilder private func field(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { LabeledContent(title, value: value) }
    }
}
