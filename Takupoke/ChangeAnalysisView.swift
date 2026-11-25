import SwiftUI

struct ChangeAnalysisView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var mappings: MappingModel
    @AppStorage("changeDefaultSchoolYear") private var year = ""
    @AppStorage("changeAnalysisSelectedClass") private var selectedClass = ""
    @State private var fileRequest: FileSelectionRequest?

    private var defaultYear: Int? {
        ChangeNormalizer.effectiveSchoolYear(configured: year, today: SchoolDate.today())
    }
    private var validYear: Bool {
        defaultYear != nil
    }
    private var analysis: ChangeAnalysis? { model.state.changeAnalysis }
    private var classes: [String] { Set(analysis?.records.map(\.displayClassName) ?? []).sorted() }
    private var visible: [ScheduleChange] {
        (analysis?.records ?? []).filter { selectedClass.isEmpty || $0.displayClassName == selectedClass }
    }

    private var currentFailure: ChangeParseError? {
        guard let source = model.state.record(for: .changes), let attempt = model.state.changeParseAttempt,
              attempt.matches(digest: source.digest, defaultYear: defaultYear) else { return nil }
        return attempt.failure
    }

    private var skippedRows: [Int] {
        model.state.excludedChangeRows(year: defaultYear)
    }

    var body: some View {
        List {
            Section {
                TextField("補完年度（自動：\(SchoolDate.today().schoolYear)年度）", text: $year)
                    .keyboardType(.numberPad).disabled(model.busy)
                if !validYear { InlineWarning("西暦1900〜9998の学校年度を入力してください。") }
                if let source = model.state.record(for: .changes) {
                    StatusRow(title: source.originalName, status: model.fileStatus(.changes))
                        .accessibilityIdentifier("change-analysis-status")
                        .accessibilityValue(model.fileStatus(.changes).title)
                }
                if model.busy {
                    LoadingRow(title: model.cancellationRequested ? "中止して処理の終了を待っています⋯" : "ファイルを処理中⋯",
                               cancel: model.cancellationRequested ? nil : { model.cancelCurrentOperation() })
                }
                if let message = model.changeFailureMessage {
                    InlineWarning(message)
                } else if let attempt = model.state.attempts[MaterialKind.changes.rawValue], let failure = attempt.failure {
                    if attempt.wasCancelled { Text(failure).foregroundStyle(.secondary) }
                    else { InlineWarning(failure) }
                }
                if model.lastOperationWasCancelled { Text("前回の処理を中止しました。").foregroundStyle(.secondary) }
                if model.changeFailureMessage == nil, let failure = currentFailure {
                    if failure.code == .cancelled { Text(failure.localizedDescription).foregroundStyle(.secondary) }
                    else { InlineWarning(failure.localizedDescription) }
                }
            } header: { Text("状態").accessibilityIdentifier("material-state-section") }
            if model.state.record(for: .changes)?.source.weekdayConsent?.matches(digest: model.state.record(for: .changes)?.digest ?? "", defaultYear: defaultYear) == true {
                Section { Text("曜日は日付から計算しています。更新後も元の行の内容が同じ場合は引き継ぎます。") }
            }
            let skipped = skippedRows
            if !skipped.isEmpty {
                Section {
                    Text("\(skipped.count)行を除外して読み込んでいます。更新後も元の行の内容が同じ場合は引き継ぎます。")
                        .accessibilityIdentifier("change-skipped-count")
                    Text("除外した行：" + ChangeReviewGroup.rangeLabel(skipped))
                        .accessibilityIdentifier("change-skipped-rows")
                }
            }
            if let source = model.state.record(for: .changes) {
                Section {
                    LabeledContent("サイズ", value: ByteCountFormatter.string(
                        fromByteCount: Int64(source.byteCount), countStyle: .file))
                    LabeledContent("最終取得") {
                        Text(source.lastAcquiredAt ?? source.acquiredAt, format: JapaneseDateDisplay.timestamp)
                    }
                    if let date = source.lastCheckedAt {
                        LabeledContent("最終確認") {
                            Text(date, format: JapaneseDateDisplay.timestamp)
                        }
                    }
                    if let date = source.sourceModifiedAt {
                        LabeledContent("元ファイルの更新") {
                            Text(date, format: JapaneseDateDisplay.timestamp)
                        }
                    }
                } header: { Text("ファイル情報").accessibilityIdentifier("material-file-section") }
            }
            Section {
                Button("更新を確認") { model.checkForUpdates(.changes) }
                    .disabled(model.busy || !model.ready || !validYear || model.state.record(for: .changes) == nil)
                if model.state.record(for: .changes) != nil {
                    Button("内容を確認・修正") { model.openChangeEditor() }
                        .disabled(model.busy || !model.ready || !validYear)
                }
                Button("同じファイルを再取得") { model.refresh(.changes) }
                    .disabled(model.busy || !model.ready || !validYear || model.state.record(for: .changes) == nil)
                Button("ファイルを選び直す") { fileRequest = FileSelectionRequest(target: .material(.changes)) }
                    .disabled(model.busy || !model.ready)
                    .accessibilityLabel("時間割変更のファイルを選び直す")
            } header: { Text("操作").accessibilityIdentifier("material-actions-section") }
            if let analysis = analysis {
                Section {
                    Text(analysis.sourceName)
                    LabeledContent("最終解析成功") { Text(analysis.parsedAt, format: JapaneseDateDisplay.timestamp) }
                    LabeledContent("年なし日付の補完", value: analysis.defaultYear.map { "\($0)年度" } ?? "指定なし")
                    LabeledContent("件数", value: "\(analysis.records.count)件")
                    if model.state.record(for: .changes).map({ analysis.matches(record: $0, defaultYear: defaultYear) }) != true {
                        InlineWarning("前回の解析結果です。現在のファイルを解析してください。")
                    }
                } header: { Text("解析結果").accessibilityIdentifier("material-analysis-section") }
                Section {
                    Picker("クラス", selection: $selectedClass) {
                        Text("すべて").tag("")
                        if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                            Text("\(TimetableDisplayText.className(selectedClass))（保存済み・現在のファイルに該当なし）").tag(selectedClass)
                        }
                        ForEach(classes, id: \.self) { Text(TimetableDisplayText.className($0)).tag($0) }
                    }
                    if !selectedClass.isEmpty && !classes.contains(selectedClass) {
                        InlineWarning("選択したクラスは現在の解析結果にありません。選択は保持しています。")
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
        .sheet(isPresented: Binding(get: { model.changePreview != nil }, set: { if !$0 { model.dismissPreview() } })) {
            if let preview = model.changePreview, let editor = preview.editor {
                ChangeWorkbookEditorView(model: model, mappings: mappings, preview: preview, initial: editor).id(editor.id)
            }
        }
        .onChange(of: year) { _, _ in model.dismissPreview() }
        .background(
            MaterialDocumentPicker(item: $fileRequest, requestID: fileRequest?.id,
                type: { $0.type }, instruction: { $0.instruction },
                selected: { _, selection in model.selectFile(selection, kind: .changes) })
                .allowsHitTesting(false)
        )
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
