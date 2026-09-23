import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum MaterialPicker: Identifiable {
    case folder
    case file(MaterialKind)

    var id: String {
        switch self {
        case .folder: return "folder"
        case .file(let kind): return kind.rawValue
        }
    }
    var contentType: UTType {
        switch self {
        case .folder: return .folder
        case .file(let kind): return kind == .changes ? (UTType(filenameExtension: "xlsx") ?? .data) : .pdf
        }
    }
}

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
    @State private var picker: MaterialPicker?
    @State private var specialPickerKind: SpecialScheduleKind?

    var body: some View {
        List {
            Section {
                Text("通常時間割・時間割変更・試験・返却は「ファイル」から個別に選びます。学校行事は行事予定APIから取得します。")
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
                        Text("試験・返却資料を処理中…")
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
                    Button("試験・返却資料を再読み込み") { specialSchedules.loadIfNeeded() }
                }
            }

            ForEach([MaterialKind.timetable, .changes]) { kind in
                Section {
                    if let record = model.state.record(for: kind) {
                        Text(record.originalName).font(.headline)
                        Text(kind == .changes ? changeStatus(record) : pdfStatus(record))
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent("サイズ", value: ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                        dateRow("最終取得", record.acquiredAt)
                        if let date = record.lastCheckedAt { dateRow("最終確認", date) }
                        if let date = record.sourceModifiedAt { dateRow("元ファイルの更新", date) }
                        if let failure = model.state.attempts[kind.rawValue]?.failure, failure != model.message {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Button("同じ資料を再取得") { model.refresh(kind) }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                        if let failure = model.state.attempts[kind.rawValue]?.failure, failure != model.message {
                            Text(failure).font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if kind == .changes, model.state.record(for: .changes) != nil {
                        NavigationLink("XLSXを解析・結果を確認") { ChangeAnalysisView(model: model) }
                        if let failure = model.state.changeParseAttempt?.failure, failure.localizedDescription != model.message {
                            Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if kind != .changes, model.state.record(for: kind) != nil {
                        NavigationLink("PDFを解析・結果を確認") { PDFAnalysisView(model: model, kind: kind) }
                        if let failure = model.state.pdfParseAttempts?[kind.rawValue]?.failure, failure.localizedDescription != model.message {
                            Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if model.folderListed {
                        NavigationLink("フォルダ内から選ぶ") {
                            MaterialCandidatesView(model: model, kind: kind)
                        }
                    }
                    Button("\(kind.fileExtension.uppercased())ファイルを選ぶ") { picker = .file(kind) }
                } header: {
                    Text(kind.title)
                }
                .disabled(model.busy || !model.ready)
            }
            SchoolEventsSettingsSection(model: schoolEvents)
            ForEach(SpecialScheduleKind.allCases) { kind in
                Section(kind.title) {
                    if let source = specialSchedules.sources[kind] {
                        Text(source.originalName).font(.headline)
                        Text(specialStatus(kind, source: source))
                            .font(.caption).foregroundStyle(.secondary)
                        if source.grant == nil {
                            Label("起動時の変更確認には、このPDFをもう一度選んでください。", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if let failure = source.failure {
                            Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        LabeledContent("サイズ", value: ByteCountFormatter.string(
                            fromByteCount: Int64(source.byteCount), countStyle: .file))
                        dateRow("最終取得", source.acquiredAt)
                        if let date = source.lastCheckedAt { dateRow("最終確認", date) }
                        NavigationLink("PDFを解析・結果を確認") {
                            SpecialScheduleAnalysisView(model: specialSchedules, kind: kind)
                        }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                    }
                    Button("PDFファイルを選ぶ") { specialPickerKind = kind }
                        .disabled(specialSchedules.busy || !specialSchedules.ready)
                }
            }
            Section {
                DisclosureGroup("フォルダから選ぶ（対応サービスのみ）") {
                    if let folder = model.state.folder {
                        Label(folder.name, systemImage: "folder")
                        Button("フォルダ内の一覧を取得") { model.refreshFolder() }
                        if model.folderListed {
                            Text("対象ファイル：\(model.candidates.count)件")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("資料フォルダを選ぶ") { picker = .folder }
                    Text("OneDriveでフォルダが選べない場合は、上の各資料からファイルを個別に選択してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(model.busy || !model.ready)

            Section {
                Text("OneDriveで読み取れない場合は「ファイル」で一度開くか、OneDriveの「オフラインで利用可能」を試してから再選択してください。")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("資料は端末内に保存します。解析に成功した結果を時間割に反映します。1ファイル50 MiBまで。解析に失敗しても選択した資料と前回の正常な結果を残します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("ファイル選択")
        .task { model.loadIfNeeded() }
        .task { specialSchedules.loadIfNeeded() }
        .task { schoolEvents.loadIfNeeded() }
        .sheet(item: $picker) { selection in
            MaterialDocumentPicker(type: selection.contentType, selected: { url in
                picker = nil
                switch selection {
                case .folder: model.selectFolder(url)
                case .file(let kind): model.selectFile(url, kind: kind)
                }
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
                ? "取得済み・解析失敗" : "取得済み・解析失敗（前回結果を保持）"
        }
        guard let record = specialSchedules.records[kind] else {
            return "取得済み・未解析"
        }
        return record.digest == source.digest && record.analysis.version == SpecialScheduleAnalysis.parserVersion
            ? "取得済み・解析結果あり" : "取得済み・新しい資料は未解析（前回結果を保持）"
    }

    private func changeStatus(_ record: MaterialRecord) -> String {
        guard let analysis = model.state.changeAnalysis else { return "取得済み・未解析" }
        return analysis.sourceDigest == record.digest && analysis.version == ChangeAnalysis.parserVersion
            ? "取得済み・解析結果あり" : "取得済み・新しい資料は未解析（前回結果を保持）"
    }

    private func pdfStatus(_ record: MaterialRecord) -> String {
        guard let analysis = model.state.pdfAnalyses?[record.kind.rawValue] else { return "取得済み・未解析" }
        return analysis.sourceDigest == record.digest && analysis.version == PDFAnalysis.currentVersion(for: record.kind)
            ? "取得済み・解析結果あり" : "取得済み・新しい資料は未解析（前回結果を保持）"
    }

    private func dateRow(_ title: String, _ date: Date) -> some View {
        LabeledContent(title) {
            Text(date, format: .dateTime.year().month().day().hour().minute())
                .foregroundStyle(.secondary)
        }
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
                Text("保存済みのPDFを解析します。ファイルを選ぶと解析も始まります。")
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
                if #available(iOS 26.0, *) {
                    Button("保存済みPDFを解析", systemImage: "doc.text.magnifyingglass") {
                        model.analyzePDF(kind)
                    }
                    .buttonStyle(.glass)
                    .disabled(model.busy || source == nil)
                } else {
                    Button("保存済みPDFを解析") { model.analyzePDF(kind) }
                        .buttonStyle(.bordered)
                        .disabled(model.busy || source == nil)
                }
                Button("保存済みの元PDFを見る") { showingSource = true }
                    .disabled(model.busy || model.urls[kind] == nil)
                if let report = model.fullReadReports[kind] {
                    diagnosticButton(report)
                    Text(copiedReport == report ? "読み取り結果をコピーしました。" :
                         "PDF本文・教員名などを含む全文と位置情報を、圧縮してコピーします。開発相談へ貼り付けてください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let source {
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
                }
            }
            if let record {
                Section("解析結果") {
                    LabeledContent("年度", value: "\(record.analysis.schoolYear)年度")
                    LabeledContent("授業枠", value: "\(record.analysis.lessons.count)件")
                    LabeledContent("最終解析成功") {
                        Text(record.analysis.parsedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                    if source?.digest != record.digest || record.analysis.version != SpecialScheduleAnalysis.parserVersion {
                        Label("前回の解析結果です。現在の資料を解析してください。", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                Section("授業一覧") {
                    ForEach(Array(record.analysis.lessons.enumerated()), id: \.offset) { _, lesson in
                        NavigationLink {
                            List {
                                LabeledContent("日付", value: lesson.date)
                                LabeledContent("クラス", value: lesson.className)
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
                                Text("\(lesson.date) · \(lesson.className) · \(lesson.period)限")
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
        .onChange(of: model.busy) { busy in if busy { copiedReport = nil } }
        .sheet(isPresented: $showingSource) {
            if let url = model.urls[kind] { SavedPDFView(url: url, title: kind.title) }
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

private struct MaterialCandidatesView: View {
    @ObservedObject var model: MaterialsModel
    let kind: MaterialKind
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var matches: [MaterialCandidate] {
        model.candidates.filter {
            $0.fileExtension == kind.fileExtension && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        List {
            if matches.isEmpty {
                Text("対象ファイルがありません。別のフォルダを選ぶか、ファイルを個別に選択してください。")
                    .foregroundStyle(.secondary)
            }
            ForEach(matches) { candidate in
                Button(candidate.name) {
                    model.selectCandidate(candidate.name, kind: kind)
                    dismiss()
                }
                .disabled(model.busy)
            }
        }
        .navigationTitle(kind.title + "を選ぶ")
        .searchable(text: $query, prompt: "ファイル名を検索")
    }
}
