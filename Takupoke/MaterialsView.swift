import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialDocumentPicker: UIViewControllerRepresentable {
    var type: UTType
    var selected: (ScopedMaterialSelection) -> Void
    var cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [type], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: MaterialDocumentPicker
        init(parent: MaterialDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.selected(ScopedMaterialSelection(url)) } else { parent.cancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.cancelled() }
    }
}

struct MaterialsView: View {
    @ObservedObject var model: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel
    @ObservedObject var mappings: MappingModel
    @State private var picker: MaterialKind?
    @State private var specialPickerKind: SpecialScheduleKind?

    var body: some View {
        List {
            Section {
                Text("通常時間割・時間割変更・試験時間割・試験返却時間割は「ファイル」から個別に選びます。学校行事はAPIから取得します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if model.busy {
                    HStack {
                        ProgressView()
                        Text("処理中…")
                        Spacer()
                        Button("中止") { model.cancel() }
                    }
                }
                if let message = model.message {
                    Label(message, systemImage: model.failed ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(model.failed ? Color.orange : Color.secondary)
                        .font(.subheadline)
                        .accessibilityLabel(message)
                }
                if !model.ready && !model.busy {
                    Button("保存情報を再読み込み") { model.loadIfNeeded() }
                }
                if specialSchedules.busy {
                    HStack {
                        ProgressView()
                        Text("試験時間割・試験返却時間割を処理中…")
                        Spacer()
                        Button("中止") { specialSchedules.cancel() }
                    }
                }
                if let message = specialSchedules.message {
                    Label(message, systemImage: specialSchedules.failed ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(specialSchedules.failed ? Color.orange : Color.secondary)
                        .font(.subheadline)
                }
                if !specialSchedules.ready && !specialSchedules.busy {
                    Button("試験時間割・試験返却時間割を再読み込み") { specialSchedules.loadIfNeeded() }
                }
            }

            ForEach([MaterialKind.timetable, .changes]) { kind in
                Section(kind.title) {
                    if let record = model.state.record(for: kind) {
                        fileSummary(name: record.originalName, status: materialStatus(kind, record: record),
                                    needsAttention: materialNeedsAttention(kind, record: record))
                        NavigationLink {
                            if kind == .changes { ChangeAnalysisView(model: model) }
                            else { PDFAnalysisView(model: model, mappings: mappings, kind: kind) }
                        } label: { Text("詳細を見る") }
                        .accessibilityLabel("\(kind.title)の詳細を見る")
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                        if let failure = model.state.attempts[kind.rawValue]?.failure {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Button(model.state.record(for: kind) == nil ? "ファイルを選ぶ" : "ファイルを選び直す") {
                        picker = kind
                    }
                    .accessibilityLabel("\(kind.title)のファイルを\(model.state.record(for: kind) == nil ? "選ぶ" : "選び直す")")
                }
                .disabled(model.busy || !model.ready)
            }
            SchoolEventsSettingsSection(model: schoolEvents)
            ForEach(SpecialScheduleKind.allCases) { kind in
                Section(kind.title) {
                    if let source = specialSchedules.sources[kind] {
                        fileSummary(name: source.originalName, status: specialStatus(kind, source: source),
                                    needsAttention: specialStatus(kind, source: source) != "解析済み" || source.grant == nil)
                        NavigationLink {
                            SpecialScheduleAnalysisView(model: specialSchedules, kind: kind)
                        } label: { Text("詳細を見る") }
                        .accessibilityLabel("\(kind.title)の詳細を見る")
                        if source.grant == nil {
                            Label("再選択が必要", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                    }
                    Button(specialSchedules.sources[kind] == nil ? "ファイルを選ぶ" : "ファイルを選び直す") {
                        specialPickerKind = kind
                    }
                    .accessibilityLabel("\(kind.title)のファイルを\(specialSchedules.sources[kind] == nil ? "選ぶ" : "選び直す")")
                    .disabled(specialSchedules.busy || !specialSchedules.ready)
                }
            }
            Section {
                Text("OneDriveで読み取れない場合は「ファイル」で一度開くか、OneDriveの「オフラインで利用可能」を試してからファイルを選び直してください。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("選択したファイルは端末内に保存します。解析に成功した結果を時間割に反映します。1ファイル50 MiBまで。解析に失敗しても選択したファイルと前回の正常な結果を残します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ファイル選択")
        .task { model.loadIfNeeded() }
        .task { specialSchedules.loadIfNeeded() }
        .task { schoolEvents.loadIfNeeded() }
        .sheet(item: $picker) { kind in
            MaterialDocumentPicker(type: kind == .changes ? (UTType(filenameExtension: "xlsx") ?? .data) : .pdf,
                                   selected: { selection in
                                       picker = nil
                                       model.selectFile(selection, kind: kind)
                                   }, cancelled: { picker = nil })
        }
        .sheet(item: $specialPickerKind) { kind in
            MaterialDocumentPicker(type: .pdf, selected: { selection in
                specialPickerKind = nil
                specialSchedules.importPDF(selection, kind: kind)
            }, cancelled: { specialPickerKind = nil })
        }
    }

    private func specialStatus(_ kind: SpecialScheduleKind, source: SpecialScheduleSource) -> String {
        if source.failure != nil {
            return specialSchedules.records[kind] == nil
                ? "解析失敗" : "解析失敗（前回結果あり）"
        }
        guard let record = specialSchedules.records[kind] else {
            return "未解析"
        }
        return record.digest == source.digest && record.analysis.version == SpecialScheduleAnalysis.parserVersion
            ? "解析済み" : "未解析（前回結果あり）"
    }

    private func materialStatus(_ kind: MaterialKind, record: MaterialRecord) -> String {
        let hasAnalysis: Bool
        let isCurrent: Bool
        if kind == .changes {
            let analysis = model.state.changeAnalysis
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == ChangeAnalysis.parserVersion
        } else {
            let analysis = model.state.pdfAnalyses?[kind.rawValue]
            hasAnalysis = analysis != nil
            isCurrent = analysis?.sourceDigest == record.digest && analysis?.version == PDFAnalysis.currentVersion(for: kind)
        }
        let parseFailed = kind == .changes ? model.state.changeParseAttempt?.failure != nil :
            model.state.pdfParseAttempts?[kind.rawValue]?.failure != nil
        if model.state.attempts[kind.rawValue]?.failure != nil {
            return hasAnalysis ? "取得失敗（前回結果あり）" : "取得失敗"
        }
        if parseFailed { return hasAnalysis ? "解析失敗（前回結果あり）" : "解析失敗" }
        if isCurrent { return "解析済み" }
        return hasAnalysis ? "未解析（前回結果あり）" : "未解析"
    }

    private func materialNeedsAttention(_ kind: MaterialKind, record: MaterialRecord) -> Bool {
        model.state.attempts[kind.rawValue]?.failure != nil ||
            materialStatus(kind, record: record) != "解析済み"
    }

    private func fileSummary(name: String, status: String, needsAttention: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).lineLimit(2)
            Label(status, systemImage: needsAttention ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(needsAttention ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct SpecialScheduleAnalysisView: View {
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
                        Label("起動時の変更確認には、このPDFをもう一度選んでください。", systemImage: "exclamationmark.triangle")
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
