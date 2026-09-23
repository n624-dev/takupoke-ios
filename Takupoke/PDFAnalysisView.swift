import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct PDFAnalysisView: View {
    @ObservedObject var model: MaterialsModel
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
            Section {
                Text("ファイル選択後は自動解析します。必要なときは右上の「解析する」から再実行できます。")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.busy { HStack { ProgressView(); Text("処理中…") } }
                if let failure = failure {
                    Label(failure.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                if kind == .timetable, let report = model.timetableReadReport {
                    diagnosticButton(report, title: "読み取り結果をすべてコピー")
                    Text(copiedDiagnostic == report ? "読み取り結果をコピーしました。" : "PDF本文・教員名などを含む全文と位置情報を、圧縮してコピーします。開発相談へ貼り付けてください。")
                        .font(.caption).foregroundStyle(.secondary)
                } else if kind == .timetable, let report = failure?.diagnosticReport {
                    diagnosticButton(report, title: "保存済みのエラー診断をコピー")
                    Text("全読み取り結果をコピーするには、保存済みPDFを再解析してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = model.message, message != failure?.localizedDescription {
                    Text(message).font(.caption).foregroundStyle(model.failed ? Color.orange : Color.secondary)
                }
            }
            if let source = model.state.record(for: kind) {
                Section("選択した資料") {
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
                    Button("同じ資料を再取得") { model.refresh(kind) }
                        .disabled(model.busy || !model.ready)
                    Button { showingSource = true } label: { Label("保存済みの元PDFを見る", systemImage: "doc.richtext") }
                        .disabled(model.pdfURLs[kind.rawValue] == nil || model.busy)
                }
            }
            if let analysis = analysis {
                Section("解析結果") {
                    Text(analysis.sourceName)
                    LabeledContent("年度", value: "\(String(analysis.schoolYear))年度" + (analysis.term.map { "・" + $0 } ?? ""))
                    LabeledContent("最終解析成功") { Text(analysis.parsedAt, format: .dateTime.year().month().day().hour().minute()) }
                    LabeledContent("件数", value: "\(analysis.lessons.count + analysis.events.count)件")
                    if analysis.version < 3 {
                        Label("旧版の解析結果には文字順の誤りが含まれる場合があります。保存済みPDFを再解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if analysis.sourceDigest != model.state.record(for: kind)?.digest || analysis.version != PDFAnalysis.currentVersion(for: kind) {
                        Label("前回の解析結果です。現在の資料を解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    ForEach(analysis.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                if kind == .timetable {
                    Section("絞り込み") {
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
                        Picker("曜日", selection: $selectedWeekday) {
                            ForEach(0..<weekdays.count, id: \.self) { Text(weekdays[$0]).tag($0) }
                        }
                    }
                    ForEach(Array(visibleLessons.enumerated()), id: \.offset) { _, lesson in
                        NavigationLink {
                            PDFLessonDetail(lesson: lesson)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(PDFDisplayText.continuous(lesson.names.cellSubject)).font(.headline)
                                Text("\(lesson.className) · \(weekdays[lesson.weekday])曜 · \(lesson.period)限")
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
                Section { Text("まだ正常な解析結果はありません。右上の「解析する」から読み取れます。").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(kind.title + "の解析")
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
}

private struct PDFLessonDetail: View {
    let lesson: PDFLesson
    var body: some View {
        List {
            Section {
                Text(PDFDisplayText.continuous(lesson.names.detailSubject)).font(.title3)
                LabeledContent("クラス", value: lesson.className)
                LabeledContent("時限", value: "\(lesson.period)限")
                LabeledContent("教員", value: lesson.names.detailTeacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.detailTeacher))
                LabeledContent("教室", value: lesson.names.detailRoom.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.detailRoom))
            }
            Section("PDFの記載名") {
                LabeledContent("科目", value: PDFDisplayText.continuous(lesson.names.subject))
                LabeledContent("教員", value: lesson.names.teacher.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.teacher))
                LabeledContent("教室", value: lesson.names.room.isEmpty ? "記載なし" : PDFDisplayText.continuous(lesson.names.room))
            }
            Section {
                DisclosureGroup("元のセルの記載") { Text(PDFDisplayText.continuous(lesson.sourceText)).textSelection(.enabled) }
                Text("同時刻に複数の授業がある場合も、授業ごとに表示しています。空欄は他の授業から補っていません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("授業の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavedPDFView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            LocalPDFCanvas(url: url)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
private struct LocalPDFCanvas: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {}
}
