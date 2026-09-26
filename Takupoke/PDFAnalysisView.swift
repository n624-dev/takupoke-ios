import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PDFAnalysisView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var mappings: MappingModel
    let kind: MaterialKind
    @AppStorage("pdfAnalysisSelectedClass") private var selectedClass = ""
    @AppStorage("pdfAnalysisSelectedWeekday") private var selectedWeekday = 0
    @State private var showingSource = false
    @State private var copiedDiagnostic: String?
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

    var body: some View {
        List {
            Section("解析") {
                if model.busy { LoadingRow(title: "処理中⋯") }
                if let failure = failure {
                    Label(failure.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
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
                if let message = model.message, message != failure?.localizedDescription {
                    Text(message).font(.caption).foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
            }
            if let source = model.state.record(for: kind) {
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
                    if let failure = model.state.attempts[kind.rawValue]?.failure {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Button("同じファイルを再取得") { model.refresh(kind) }
                        .disabled(model.busy || !model.ready)
                    Button { showingSource = true } label: { Label("保存済みのPDFを見る", systemImage: "doc.richtext") }
                        .disabled(model.pdfURLs[kind.rawValue] == nil || model.busy)
                }
            }
            if let analysis = analysis {
                Section("解析結果") {
                    Text(analysis.sourceName)
                    LabeledContent("学校年度", value: "\(analysis.schoolYear)年度")
                    if let term = analysis.term { LabeledContent("学期", value: term) }
                    LabeledContent("最終解析成功") { Text(analysis.parsedAt, format: .dateTime.year().month().day().hour().minute()) }
                    LabeledContent("件数", value: "\(analysis.lessons.count + analysis.events.count)件")
                    if analysis.version < 3 {
                        Label("旧版の解析結果には文字順の誤りが含まれる場合があります。保存済みPDFを再解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if analysis.sourceDigest != model.state.record(for: kind)?.digest || analysis.version != PDFAnalysis.currentVersion(for: kind) {
                        Label("前回の解析結果です。現在のファイルを解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    ForEach(analysis.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
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
                            Label("選択したクラスは現在の解析結果にありません。選択は保持しています。", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
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
                                Label(classification.label, systemImage: classification.type == .noClass ? "calendar.badge.minus" : "tag")
                                    .font(.caption)
                                    .foregroundStyle(classification.needsReview ? Color.orange : Color.secondary)
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
                                Label("終了日を確認できません。元PDFを確認してください。", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
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
            if model.busy { ToolbarItem(placement: .cancellationAction) { Button("中止") { model.cancel() } } }
        }
        .onChange(of: model.busy) { busy in if busy { copiedDiagnostic = nil } }
        .sheet(isPresented: $showingSource) {
            if let url = model.pdfURLs[kind.rawValue] { SavedPDFView(url: url, title: kind.title) }
        }
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
