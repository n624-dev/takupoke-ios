import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SpecialScheduleAnalysisView: View {
    @AppStorage(LocalAIFeaturePolicy.storageKey) private var useAiFeatures = false
    @ObservedObject var model: SpecialSchedulesModel
    let kind: SpecialScheduleKind
    @State private var sourceLease: SavedPDFLease?
    @State private var confirmingRemoval = false
    @State private var showingRecovery = false
    @State private var copiedReport: String?
    @State private var positionsLesson: SpecialScheduleLesson?
    @State private var positionsCopied = false
    @State private var fileRequest: FileSelectionRequest?

    private var source: SpecialScheduleSource? { model.sources[kind] }
    private var record: SpecialScheduleRecord? { model.records[kind] }
    private var selectedPDF: URL? { model.urls[kind] }
    private var analysisPDF: URL? { model.analysisPDFURLs[kind] }
    private var separateAnalysisPDF: Bool {
        guard analysisPDF != nil else { return false }
        return selectedPDF == nil || record?.digest != source?.digest
    }

    var body: some View {
        List {
            Section {
                StatusRow(title: source?.originalName ?? record?.originalName ?? kind.title, status: model.fileStatus(kind))
                if model.busy {
                    LoadingRow(title: model.cancellationRequested ? "中止して処理の終了を待っています⋯" : "ファイルを処理中⋯",
                               cancel: model.cancellationRequested ? nil : { model.cancelCurrentOperation() })
                }
                if let failure = source?.acquisitionFailure { InlineWarning(failure) }
                if model.lastOperationWasCancelled { Text("前回の処理を中止しました。").foregroundStyle(.secondary) }
                if let failure = source?.failure {
                    PDFAnalysisFailureRows(failure: failure, hasPreviousAnalysis: record != nil)
                }
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
                if let report = model.fullReadReports[kind] {
                    diagnosticButton(report)
                    Text(copiedReport == report ? "読み取り結果をコピーしました。" :
                         "PDF本文・教員名などを含む全文と位置情報を、圧縮してコピーします。開発相談へ貼り付けてください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
#endif
            } header: { Text("状態").accessibilityIdentifier("material-state-section") }
            if source?.recoveryJob?.pdfHash == source?.digest, source?.recoveryJob?.state == .pending {
                Section("復旧") {
                    Button("端末内で復旧する",systemImage:"doc.text.magnifyingglass") { showingRecovery = true }.disabled(!useAiFeatures || model.busy)
                    InlineWarning("新しい資料は未反映です。") }
            }
            if let source {
                Section {
                    if source.grant == nil {
                        InlineWarning("ファイルの自動更新確認には、このPDFをもう一度選んでください。")
                    }
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
                } header: { Text("ファイル情報").accessibilityIdentifier("material-file-section") }
            }
            Section {
                Button("更新を確認") { model.checkForUpdates(kind) }
                    .disabled(model.busy || !model.ready || source?.grant == nil)
                Button("同じファイルを再取得") { model.refresh(kind) }
                    .disabled(model.busy || !model.ready || source?.grant == nil)
                Button(separateAnalysisPDF ? "選択中のPDFを見る" : "保存済みのPDFを見る") {
                    sourceLease = selectedPDF.flatMap(SavedPDFLease.open)
                }.disabled(!model.ready || selectedPDF == nil)
                Button("ファイルを選び直す") { fileRequest = FileSelectionRequest(target: .special(kind)) }
                    .disabled(model.busy || !model.ready)
                    .accessibilityLabel("\(kind.title)のファイルを選び直す")
                if source != nil {
                    Button("選択を解除", role: .destructive) { confirmingRemoval = true }
                        .disabled(!model.canRemoveSelection(kind))
                }
            } header: { Text("操作").accessibilityIdentifier("material-actions-section") }
            if let record {
                Section {
                    LabeledContent("学校年度", value: "\(record.analysis.schoolYear)年度")
                    LabeledContent("件数", value: "\(record.analysis.lessons.count)件")
                    LabeledContent("最終解析成功") {
                        Text(record.analysis.parsedAt, format: JapaneseDateDisplay.timestamp)
                    }
                    if separateAnalysisPDF {
                        Button("この解析結果の元PDFを見る") {
                            sourceLease = analysisPDF.flatMap(SavedPDFLease.open)
                        }.disabled(!model.ready)
                    }
                    if source?.digest != record.digest || record.analysis.version != SpecialScheduleAnalysis.parserVersion {
                        InlineWarning("前回の解析結果です。現在のファイルを解析してください。")
                    }
                } header: { Text("解析結果").accessibilityIdentifier("material-analysis-section") }
                Section("授業一覧") {
                    ForEach(Array(record.analysis.lessons.enumerated()), id: \.offset) { _, lesson in
                        NavigationLink {
                            List {
                                LabeledContent("日付", value: lesson.date)
                                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                                LabeledContent("時限", value: "\(lesson.period)限")
                                if let time = record.analysis.timeRange(for: lesson) { LabeledContent("時刻", value: time) }
                                LabeledContent("科目", value: PDFDisplayText.continuous(lesson.subject))
                                LabeledContent("教員", value: lesson.teacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.teacher))
                                LabeledContent("教室", value: lesson.room.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.room))
                                DisclosureGroup("元のセルの記載") {
                                    Text(lesson.lines.joined(separator: "\n")).textSelection(.enabled)
                                }
                                if kind == .examReturn {
                                    Section("見出し混入の調査") {
                                        Text("この授業の見出し・クラス欄・罫線・採用行の位置だけを取得します。本文・教員名・教室名・画像は含みません。自動送信はしません。")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Button("位置情報を取得", systemImage:"ruler") {
                                            positionsLesson = lesson; positionsCopied = false
                                            model.diagnoseReturnLesson(lesson)
                                        }.buttonStyle(.glass).disabled(model.busy)
                                        if positionsLesson == lesson, let report = model.returnPositionsReport {
                                            Button("位置情報をコピー", systemImage:"doc.on.doc") {
                                                UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier:report]],
                                                    options:[.localOnly:true,.expirationDate:Date().addingTimeInterval(600)])
                                                positionsCopied = true
                                            }.buttonStyle(.glass).disabled(model.busy)
                                            if positionsCopied { Text("位置情報をコピーしました。") }
                                        }
                                        if model.busy { LoadingRow(title:"位置情報を取得中⋯",cancel:{ model.cancelCurrentOperation() }) }
                                        if let message = model.message, positionsLesson == lesson {
                                            if model.failed { InlineWarning(message) }
                                            else { Text(message).font(.caption) }
                                        }
                                    }
                                }
                            }
                            .navigationTitle("授業詳細")
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(PDFDisplayText.continuous(lesson.subject)).font(.headline)
                                Text("\(lesson.date) · \(TimetableDisplayText.className(lesson.className)) · \(lesson.period)限")
                                    .font(.caption).foregroundStyle(.secondary)
                                let metadata = [lesson.teacher, lesson.room].filter { !$0.isEmpty }
                                if !metadata.isEmpty {
                                    Text(PDFDisplayText.continuous(metadata.joined(separator: " / ")))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .toolbar { ToolbarItem(placement: .primaryAction) { parseButton } }
        .onChange(of: model.busy) { busy in if busy { copiedReport = nil } }
        .sheet(isPresented:$showingRecovery,onDismiss:{ ApplicationData.shared.recovery.cancel() }) { PDFRecoveryView(kind:kind == .exam ? .exam : .return) }
        .sheet(item: $sourceLease) { lease in SavedPDFView(url: lease.url, title: kind.title) }
        .onChange(of: model.ready) { ready in if !ready { sourceLease = nil } }
        .alert("\(kind.title)の選択を解除しますか？", isPresented: $confirmingRemoval) {
            Button("キャンセル", role: .cancel) {}
            Button("選択を解除", role: .destructive) { model.removeSelection(kind) }
        } message: {
            Text("端末に保存したこの資料のPDF、解析結果、訂正内容、関連する通知が削除されます。OneDriveなどの元ファイルは残ります。")
        }
        .background(
            MaterialDocumentPicker(item: $fileRequest, requestID: fileRequest?.id,
                type: { $0.type }, instruction: { $0.instruction },
                selected: { _, selection in model.importPDF(selection, kind: kind) })
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder private var parseButton: some View {
        if #available(iOS 26.0, *) {
            Button("解析する", systemImage: "doc.text.magnifyingglass") { model.analyzePDF(kind) }
                .buttonStyle(.glassProminent)
                .disabled(model.busy || source == nil)
        } else {
            Button("解析する") { model.analyzePDF(kind) }
                .buttonStyle(.borderedProminent)
                .disabled(model.busy || source == nil)
        }
    }

#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
    @ViewBuilder private func diagnosticButton(_ report: String) -> some View {
        if #available(iOS 26.0, *) {
            Button("読み取り結果をすべてコピー", systemImage: "doc.on.doc") { copy(report) }
                .buttonStyle(.glass)
                .disabled(model.busy)
        } else {
            Button("読み取り結果をすべてコピー") { copy(report) }
                .buttonStyle(.bordered)
                .disabled(model.busy)
        }
    }

    private func copy(_ report: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: report]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(600)])
        copiedReport = report
    }
#endif
}
