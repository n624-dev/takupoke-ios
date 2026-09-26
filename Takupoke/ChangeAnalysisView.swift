import SwiftUI

struct ChangeAnalysisView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var mappings: MappingModel
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
                TextField("補完年度（自動：\(SchoolDate.today().schoolYear)年度）", text: $year)
                    .keyboardType(.numberPad).disabled(model.busy)
                if !validYear { Text("西暦1900〜9998の学校年度を入力してください。").foregroundStyle(.orange) }
                if model.busy {
                    LoadingRow(title: "処理中⋯", cancel: { model.cancel() })
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
                    LabeledContent("年なし日付の補完", value: analysis.defaultYear.map { "\($0)年度" } ?? "指定なし")
                    LabeledContent("件数", value: "\(analysis.records.count)件")
                    if analysis.sourceDigest != model.state.record(for: .changes)?.digest || analysis.version != ChangeAnalysis.parserVersion {
                        Label("前回の解析結果です。現在のファイルを解析してください。", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                } header: { Text("解析結果") }
                Section {
                    Picker("クラス", selection: $selectedClass) {
                        Text("すべて").tag("")
                        if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                            Text("\(TimetableDisplayText.className(selectedClass))（保存済み・現在のファイルに該当なし）").tag(selectedClass)
                        }
                        ForEach(classes, id: \.self) { Text(TimetableDisplayText.className($0)).tag($0) }
                    }
                    if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                        Label("選択したクラスは現在の解析結果にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                // Use positions so identical source rows remain visible as distinct records.
                ForEach(Array(visible.enumerated()), id: \.offset) { _, record in
                    Section { ChangeRecordFields(record: record, names: mappings.names(for: record)) }
                }
            } else {
                Text("まだ正常な解析結果はありません。").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("時間割変更")
        .toolbar { ToolbarItem(placement: .primaryAction) { parseButton } }
        .scrollDismissesKeyboard(.interactively)
        .alert("曜日を確認できないファイルです", isPresented: $confirmingPreview) {
            Button("確認して表示") { model.previewChanges() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("日付と曜日が合わないか、曜日の計算結果が保存されていません。日付欄を基準に内容を表示しますが、正しい内容かは元ファイルで確認してください。前回の正常データは置き換えません。")
        }
        .sheet(isPresented: Binding(get: { model.changePreview != nil }, set: { if !$0 { model.dismissPreview() } })) {
            if let preview = model.changePreview { ChangePreviewView(preview: preview, mappings: mappings) }
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
