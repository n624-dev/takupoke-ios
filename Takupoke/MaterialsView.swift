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

private struct MaterialDocumentPicker: UIViewControllerRepresentable {
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
    @State private var picker: MaterialPicker?

    var body: some View {
        List {
            Section {
                Text("通常時間割と時間割変更は「ファイル」から個別に選びます。学校行事は学校サイトのPDFを端末内に保存します。")
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
            }

            ForEach(MaterialKind.allCases) { kind in
                Section {
                    if let record = model.state.record(for: kind) {
                        Text(record.originalName).font(.headline)
                        Text(kind == .changes ? changeStatus(record) : "取得済み・未解析")
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent("サイズ", value: ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                        dateRow("最終取得", record.acquiredAt)
                        if let date = record.lastCheckedAt { dateRow("最終確認", date) }
                        if let date = record.sourceModifiedAt { dateRow("元ファイルの更新", date) }
                        if let failure = model.state.attempts[kind.rawValue]?.failure {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if kind != .events {
                            Button("同じ資料を再取得") { model.refresh(kind) }
                        }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                        if let failure = model.state.attempts[kind.rawValue]?.failure {
                            Text(failure).font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if kind == .changes, model.state.record(for: .changes) != nil {
                        NavigationLink("XLSXを解析・結果を確認") { ChangeAnalysisView(model: model) }
                        if let failure = model.state.changeParseAttempt?.failure {
                            Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if kind != .events && model.folderListed {
                        NavigationLink("フォルダ内から選ぶ") {
                            MaterialCandidatesView(model: model, kind: kind)
                        }
                    }
                    if kind == .events {
                        Button(model.state.record(for: .events)?.source.remoteURL == nil ? "学校サイトから取得" : "更新を確認") {
                            model.fetchEvents()
                        }
                        Link("学校サイトのPDFを開く", destination: WebPDFDownloader.eventsURL)
                        Text("一度取得したPDFは端末内に保持します。更新確認で変更がなければ、PDF本体を再取得しません。")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("\(kind.fileExtension.uppercased())ファイルを選ぶ") { picker = .file(kind) }
                    }
                } header: {
                    Text(kind.title)
                }
                .disabled(model.busy || !model.ready)
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
                Text("資料は端末内に保存します。時間割変更XLSXは取得後に解析できます。PDF解析・時間割への反映はまだ行いません。1ファイル50 MiBまで。取得に失敗した場合は前回の資料を残します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("学校資料")
        .task { model.loadIfNeeded() }
        .sheet(item: $picker) { selection in
            MaterialDocumentPicker(type: selection.contentType, selected: { url in
                picker = nil
                switch selection {
                case .folder: model.selectFolder(url)
                case .file(let kind): model.selectFile(url, kind: kind)
                }
            }, cancelled: { picker = nil })
        }
    }

    private func changeStatus(_ record: MaterialRecord) -> String {
        guard let analysis = model.state.changeAnalysis else { return "取得済み・未解析" }
        return analysis.sourceDigest == record.digest && analysis.version == ChangeAnalysis.parserVersion
            ? "取得済み・解析結果あり" : "取得済み・新しい資料は未解析（前回結果を保持）"
    }

    private func dateRow(_ title: String, _ date: Date) -> some View {
        LabeledContent(title) {
            Text(date, format: .dateTime.year().month().day().hour().minute())
                .foregroundStyle(.secondary)
        }
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
