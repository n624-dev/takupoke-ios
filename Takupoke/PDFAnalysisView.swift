import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PDFAnalysisFailureRows: View {
    let failure: PDFParseError
    let hasPreviousAnalysis: Bool

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                if failure.code == .cancelled {
                    Text(failure.userMessage).foregroundStyle(.secondary)
                        .accessibilityIdentifier("pdf-failure-message")
                } else {
                    InlineWarning(failure.userMessage)
                        .accessibilityIdentifier("pdf-failure-message")
                }
                if hasPreviousAnalysis {
                    Text(failure.retentionMessage).font(.callout).foregroundStyle(.secondary)
                }
            }
            if let code = failure.userCode {
                LabeledContent("エラーコード") {
                    Text(code).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pdf-failure-code")
                }
            }
        }
    }
}

struct PDFAnalysisView: View {
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    @ObservedObject var model: MaterialsModel
    @ObservedObject var mappings: MappingModel
    let kind: MaterialKind
    @AppStorage("pdfAnalysisSelectedClass") private var selectedClass = ""
    @AppStorage("pdfAnalysisSelectedWeekday") private var selectedWeekday = 0
    @State private var sourceLease: SavedPDFLease?
    @State private var showingRecovery = false
    @State private var copiedDiagnostic: String?
    @State private var fileRequest: FileSelectionRequest?
    private var analysis: PDFAnalysis? { model.state.pdfAnalyses?[kind.rawValue] }
    private var failure: PDFParseError? {
        (kind == .timetable ? model.timetableFailure : nil) ?? model.state.pdfParseAttempts?[kind.rawValue]?.failure
    }
    private var classes: [String] { Set(analysis?.lessons.map(\.className) ?? []).sorted() }
    private var visibleLessons: [PDFLesson] {
        (analysis?.lessons ?? []).filter { (selectedClass.isEmpty || $0.className == selectedClass) &&
            (selectedWeekday == 0 || $0.weekday == selectedWeekday) }
    }
    private let weekdays = ["すべて", "月", "火", "水", "木", "金"]
    private var selectedPDF: URL? { model.pdfURLs[kind.rawValue] }
    private var analysisPDF: URL? { model.analysisPDFURLs[kind.rawValue] }
    private var separateAnalysisPDF: Bool { analysisPDF != nil && analysisPDF != selectedPDF }

    var body: some View {
        List {
            Section {
                if let source = model.state.record(for: kind) {
                    StatusRow(title: source.originalName, status: model.fileStatus(kind))
                }
                if model.busy { LoadingRow(title: model.cancellationRequested ? "中止して処理の終了を待っています⋯" : "ファイルを処理中⋯") }
                if model.lastOperationWasCancelled { Text("前回の処理を中止しました。").foregroundStyle(.secondary) }
                if let attempt = model.state.attempts[kind.rawValue], let failure = attempt.failure {
                    if attempt.wasCancelled { Text(failure).foregroundStyle(.secondary) }
                    else { InlineWarning(failure) }
                }
                if let failure = failure {
                    PDFAnalysisFailureRows(failure: failure, hasPreviousAnalysis: analysis != nil)
                }
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
                if kind == .timetable, let report = model.timetableReadReport {
                    diagnosticButton(report, title: "読み取り結果をすべてコピー")
                    Text(copiedDiagnostic == report ? "読み取り結果をコピーしました。" : "PDF本文・教員名などを含む全文と位置情報を、圧縮してコピーします。開発相談へ貼り付けてください。")
                        .font(.caption).foregroundStyle(.secondary)
                } else if kind == .timetable, let report = failure?.diagnosticReport {
                    diagnosticButton(report, title: "保存済みのエラー診断をコピー")
                    Text("全読み取り結果をコピーするには、保存済みPDFを再解析してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
#endif
            } header: { Text("状態").accessibilityIdentifier("material-state-section") }
            if model.state.pdfParseAttempts?[kind.rawValue]?.recoveryJob?.pdfHash == model.state.record(for: kind)?.digest,
               model.state.pdfParseAttempts?[kind.rawValue]?.recoveryJob?.state == .pending {
                Section("復旧") {
                    InlineWarning("新しい資料は未反映です。")
                    Button("端末内で復旧する",systemImage:"doc.text.magnifyingglass") { showingRecovery = true }.disabled(!useAiFeatures || model.busy)
                }
            }
            if let source = model.state.record(for: kind) {
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
                Button("更新を確認") { model.checkForUpdates(kind) }
                    .disabled(model.busy || !model.ready || model.state.record(for: kind) == nil)
                Button("同じファイルを再取得") { model.refresh(kind) }
                    .disabled(model.busy || !model.ready || model.state.record(for: kind) == nil)
                Button(separateAnalysisPDF ? "選択中のPDFを見る" : "保存済みのPDFを見る") {
                    sourceLease = selectedPDF.flatMap(SavedPDFLease.open)
                }.disabled(!model.ready || selectedPDF == nil)
                Button("ファイルを選び直す") { fileRequest = FileSelectionRequest(target: .material(kind)) }
                    .disabled(model.busy || !model.ready)
                    .accessibilityLabel("\(kind.title)のファイルを選び直す")
            } header: { Text("操作").accessibilityIdentifier("material-actions-section") }
            if let analysis = analysis {
                Section {
                    Text(analysis.sourceName)
                    LabeledContent("学校年度", value: "\(analysis.schoolYear)年度")
                    if let term = analysis.term { LabeledContent("学期", value: term) }
                    LabeledContent("最終解析成功") { Text(analysis.parsedAt, format: JapaneseDateDisplay.timestamp) }
                    LabeledContent("件数", value: "\(analysis.lessons.count + analysis.events.count)件")
                    if separateAnalysisPDF {
                        Button("この解析結果の元PDFを見る") {
                            sourceLease = analysisPDF.flatMap(SavedPDFLease.open)
                        }.disabled(!model.ready)
                    }
                    if analysis.version < 3 {
                        InlineWarning("旧版の解析結果には文字順の誤りが含まれる場合があります。保存済みPDFを再解析してください。")
                    } else if analysis.sourceDigest != model.state.record(for: kind)?.digest || analysis.version != PDFAnalysis.currentVersion(for: kind) {
                        InlineWarning("前回の解析結果です。現在のファイルを解析してください。")
                    }
                    ForEach(analysis.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                } header: { Text("解析結果").accessibilityIdentifier("material-analysis-section") }
                if kind == .timetable {
                    Section("絞り込み") {
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
                        Picker("曜日", selection: $selectedWeekday) {
                            ForEach(0..<weekdays.count, id: \.self) { Text(weekdays[$0]).tag($0) }
                        }
                    }
                    ForEach(Array(visibleLessons.enumerated()), id: \.offset) { _, lesson in
                        NavigationLink {
                            PDFLessonDetail(lesson: lesson, mappings: mappings)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(PDFDisplayText.continuous(lesson.names.cellSubject)).font(.headline)
                                Text("\(TimetableDisplayText.className(lesson.className)) · \(weekdays[lesson.weekday])曜 · \(lesson.period)限")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                let metadata = [lesson.names.cellTeacher, lesson.names.cellRoom].filter { !$0.isEmpty }
                                if !metadata.isEmpty { Text(PDFDisplayText.continuous(metadata.joined(separator: " / "))).font(.caption) }
                            }.padding(.vertical, 4)
                        }
                    }
                } else {
                    ForEach(Array(analysis.events.enumerated()), id: \.offset) { _, event in
                        Section {
                            Text(event.title).font(.headline)
                            LabeledContent("対象欄", value: event.scope)
                            if let classification = event.classification {
                                if classification.needsReview {
                                    InlineWarning(classification.label)
                                } else {
                                    Label(classification.label, systemImage: classification.type == .noClass ? "calendar.badge.minus" : "tag")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if classification.type == .supplementary {
                                    Text("基本時間割は使わず、時間割変更で指定された授業だけを扱う日です。")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let endDate = event.endDate {
                                LabeledContent("期間", value: event.date + " 〜 " + endDate)
                                Text("終了日を含みます。確認元：" + (event.periodEvidence ?? "PDF"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if event.periodNeedsReview {
                                InlineWarning("終了日を確認できません。元PDFを確認してください。")
                            }
                        } header: { Text(event.date) }
                    }
                }
            } else {
                Section { Text("解析結果がありません。").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { parseButton }
            if model.busy { ToolbarItem(placement: .cancellationAction) {
                Button("中止") { model.cancelCurrentOperation() }.disabled(model.cancellationRequested)
            } }
        }
        .onChange(of: model.busy) { busy in if busy { copiedDiagnostic = nil } }
        .sheet(isPresented:$showingRecovery,onDismiss:{ ApplicationData.shared.recovery.cancel() }) { PDFRecoveryView(kind:.timetable) }
        .sheet(item: $sourceLease) { lease in SavedPDFView(url: lease.url, title: kind.title) }
        .onChange(of: model.ready) { ready in if !ready { sourceLease = nil } }
        .background(
            MaterialDocumentPicker(item: $fileRequest, requestID: fileRequest?.id,
                type: { $0.type }, instruction: { $0.instruction },
                selected: { _, selection in model.selectFile(selection, kind: kind) })
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder private var parseButton: some View {
        if #available(iOS 26.0, *) {
            Button("解析する", systemImage: "doc.text.magnifyingglass") { model.analyzePDF(kind) }
                .buttonStyle(.glassProminent)
                .disabled(model.busy || !model.ready || model.state.record(for: kind) == nil)
        } else {
            Button("解析する") { model.analyzePDF(kind) }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy || !model.ready || model.state.record(for: kind) == nil)
        }
    }

#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
    @ViewBuilder private func diagnosticButton(_ report: String, title: String) -> some View {
        if #available(iOS 26.0, *) {
            Button(title, systemImage: "doc.on.doc") { copyDiagnostic(report) }
                .buttonStyle(.glass)
                .disabled(model.busy)
        } else {
            Button(title) { copyDiagnostic(report) }
                .buttonStyle(.bordered)
                .disabled(model.busy)
        }
    }

    private func copyDiagnostic(_ report: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: report]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(600)])
        copiedDiagnostic = report
    }
#endif
}
