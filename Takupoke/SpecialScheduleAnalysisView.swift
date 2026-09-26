import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SpecialScheduleAnalysisView: View {
    @ObservedObject var model: SpecialSchedulesModel
    let kind: SpecialScheduleKind
    @State private var showingSource = false
    @State private var copiedReport: String?

    private var source: SpecialScheduleSource? { model.sources[kind] }
    private var record: SpecialScheduleRecord? { model.records[kind] }

    var body: some View {
        List {
            Section("解析") {
                Text("ファイル選択後は自動解析します。必要なときは右上の「解析する」から再実行できます。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.busy {
                    HStack { ProgressView(); Text("処理中…"); Spacer(); Button("中止") { model.cancel() } }
                }
                if let failure = source?.failure {
                    Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let message = model.message, message != source?.failure?.localizedDescription {
                    Text(message).font(.caption)
                        .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
                if let report = model.fullReadReports[kind] {
                    diagnosticButton(report)
                    Text(copiedReport == report ? "読み取り結果をコピーしました。" :
                         "PDF本文・教員名などを含む全文と位置情報を、圧縮してコピーします。開発相談へ貼り付けてください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let source {
                Section("選択したファイル") {
                    Text(source.originalName)
                    if source.grant == nil {
                        Label("ファイルの自動更新確認には、このPDFをもう一度選んでください。", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
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
                    Button("保存済みのPDFを見る") { showingSource = true }
                        .disabled(model.busy || model.urls[kind] == nil)
                }
            }
            if let record {
                Section("解析結果") {
                    LabeledContent("学校年度", value: "\(record.analysis.schoolYear)年度")
                    LabeledContent("件数", value: "\(record.analysis.lessons.count)件")
                    LabeledContent("最終解析成功") {
                        Text(record.analysis.parsedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    if source?.digest != record.digest || record.analysis.version != SpecialScheduleAnalysis.parserVersion {
                        Label("前回の解析結果です。現在のファイルを解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                Section("授業一覧") {
                    ForEach(Array(record.analysis.lessons.enumerated()), id: \.offset) { _, lesson in
                        NavigationLink {
                            List {
                                LabeledContent("日付", value: lesson.date)
                                LabeledContent("クラス", value: TimetableDisplayText.className(lesson.className))
                                LabeledContent("時限", value: "\(lesson.period)限")
                                if let time = lesson.timeRange { LabeledContent("時刻", value: time) }
                                LabeledContent("科目", value: PDFDisplayText.continuous(lesson.subject))
                                LabeledContent("教員", value: lesson.teacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.teacher))
                                LabeledContent("教室", value: lesson.room.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.room))
                                DisclosureGroup("元のセルの記載") {
                                    Text(lesson.lines.joined(separator: "\n")).textSelection(.enabled)
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
        .sheet(isPresented: $showingSource) {
            if let url = model.urls[kind] { SavedPDFView(url: url, title: kind.title) }
        }
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
}
