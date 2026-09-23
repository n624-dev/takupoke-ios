import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SpecialSchedulesModel: ObservableObject {
    @Published private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false

    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.special-schedules", qos: .userInitiated)
    private var store: SpecialScheduleStore?
    private var control: AcquisitionControl?

    func loadIfNeeded() {
        guard !ready, !busy else { return }
        perform(success: nil) { store, _ in _ = store }
    }

    func importPDF(_ selection: ScopedMaterialSelection, kind: SpecialScheduleKind) {
        perform(success: "\(kind.title)を解析して保存しました。") { store, control in
            let staged = store.newStagingURL()
            defer { store.discardStaging(staged) }
            let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
            let pages = try PDFKitReader.read(staged, kind: .timetable, check: { try control.check() })
            let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: digest,
                                                           name: name, check: { try control.check() })
            try control.check()
            try store.save(staged: staged, analysis: analysis, originalName: name,
                           byteCount: count, digest: digest)
        }
    }

    func cancel() {
        control?.cancel()
        message = "中止を要求しました。処理の終了を待っています。"
    }

    private func perform(success: String?, operation: @escaping (SpecialScheduleStore, AcquisitionControl) throws -> Void) {
        guard !busy else { return }
        busy = true
        failed = false
        message = nil
        let control = AcquisitionControl()
        self.control = control
        let existingStore = store
        queue.async {
            let result = Result { () throws -> (SpecialScheduleStore, [SpecialScheduleKind: SpecialScheduleRecord], [SpecialScheduleKind: URL]) in
                let store: SpecialScheduleStore
                if let existing = existingStore { store = existing }
                else {
                    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
                    store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite", isDirectory: true))
                }
                try operation(store, control)
                let urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                    store.savedURL(for: kind).map { (kind, $0) }
                })
                return (store, store.records, urls)
            }
            DispatchQueue.main.async {
                self.busy = false
                self.control = nil
                switch result {
                case .success(let snapshot):
                    self.store = snapshot.0
                    self.records = snapshot.1
                    self.urls = snapshot.2
                    self.ready = true
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "試験資料を保存できませんでした。前回の解析結果は保持しています。"
                }
            }
        }
    }

    private nonisolated static func copy(_ selection: ScopedMaterialSelection, to staged: URL,
                                         control: AcquisitionControl) throws -> (String, Int, String) {
        try selection.access { url in
            try control.check()
            let coordinator = NSFileCoordinator(filePresenter: nil)
            control.attach(coordinator)
            defer { control.attach(nil) }
            var error: NSError?
            var result: Result<(String, Int, String), Error>?
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { safeURL in
                result = Result {
                    try control.check()
                    let values = try safeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true,
                          url.pathExtension.lowercased() == "pdf" else { throw MaterialError.invalidFile }
                    let input = try FileHandle(forReadingFrom: safeURL)
                    defer { try? input.close() }
                    guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
                    let output = try FileHandle(forWritingTo: staged)
                    defer { try? output.close() }
                    var hasher = SHA256()
                    var count = 0
                    var header = Data()
                    while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        try control.check()
                        count += chunk.count
                        guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
                        if header.count < 5 { header.append(chunk.prefix(5 - header.count)) }
                        hasher.update(data: chunk)
                        try output.write(contentsOf: chunk)
                    }
                    guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
                    try output.synchronize()
                    return (url.lastPathComponent, count,
                            hasher.finalize().map { String(format: "%02x", $0) }.joined())
                }
            }
            try control.check()
            if let error { throw error }
            guard let result else { throw MaterialError.unavailable }
            return try result.get()
        }
    }
}

struct SpecialScheduleMaterialsView: View {
    @ObservedObject var model: SpecialSchedulesModel
    @State private var pickerKind: SpecialScheduleKind?
    @State private var showingSource: SpecialScheduleKind?

    var body: some View {
        List {
            if !model.ready && model.busy { HStack { ProgressView(); Text("保存済み資料を読み込み中…") } }
            if !model.ready && !model.busy { Button("保存済み資料を再読み込み") { model.loadIfNeeded() } }
            if model.busy { Button("取込を中止") { model.cancel() } }
            if let message = model.message {
                Label(message, systemImage: model.failed ? "exclamationmark.triangle" : "info.circle")
                    .foregroundStyle(model.failed ? Color.orange : Color.secondary)
            }
            ForEach(SpecialScheduleKind.allCases) { kind in
                Section(kind.title) {
                    if let record = model.records[kind] {
                        Text(record.originalName)
                        LabeledContent("年度", value: "\(record.analysis.schoolYear)年度")
                        LabeledContent("授業枠", value: "\(record.analysis.lessons.count)件")
                        Button("保存済みの元PDFを見る") { showingSource = kind }
                    } else {
                        Text("未選択").foregroundStyle(.secondary)
                    }
                    Button("PDFファイルを選ぶ") { pickerKind = kind }
                        .disabled(model.busy || !model.ready)
                }
            }
            Text("「ファイル」から選んだPDFを端末内で解析します。読めない書式の場合は前回の正常な結果を保持します。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("試験・返却資料")
        .task { model.loadIfNeeded() }
        .sheet(item: $pickerKind) { kind in
            MaterialDocumentPicker(type: .pdf, selected: { selection in
                pickerKind = nil
                model.importPDF(selection, kind: kind)
            }, cancelled: { pickerKind = nil })
        }
        .sheet(item: $showingSource) { kind in
            if let url = model.urls[kind] { SavedPDFView(url: url, title: kind.title) }
        }
    }
}
