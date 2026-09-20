import Foundation
import SwiftUI

@MainActor
final class MaterialsModel: ObservableObject {
    @Published private(set) var state = MaterialLibraryState()
    @Published private(set) var candidates: [MaterialCandidate] = []
    @Published private(set) var folderListed = false
    @Published private(set) var busy = false
    @Published private(set) var ready = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var changePreview: ChangePreview?
    @Published private(set) var pdfURLs: [String: URL] = [:]
    @Published private(set) var timetableReadReport: String?
    @Published private(set) var timetableFailure: PDFParseError?

    var canPreviewChanges: Bool {
        guard let attempt = state.changeParseAttempt, attempt.failure?.permitsPreview == true,
              let record = state.record(for: .changes) else { return false }
        return attempt.sourceDigest == record.digest
    }

    private let worker = MaterialWorker()
    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.materials", qos: .userInitiated)
    private var control: AcquisitionControl?

    func loadIfNeeded() {
        guard !ready else { return }
        perform(success: nil) { worker, _ in try worker.open() }
    }

    func selectFolder(_ url: ScopedMaterialSelection) {
        perform(success: "フォルダを登録しました。資料ごとに使用するファイルを選んでください。") {
            try $0.selectFolder(url, control: $1)
        }
    }

    func refreshFolder() {
        perform(success: "フォルダ内の一覧を更新しました。") { try $0.refreshFolder(control: $1) }
    }

    func selectFile(_ url: ScopedMaterialSelection, kind: MaterialKind) {
        perform(success: "\(kind.title)を取得しました。内容の解析はまだ行っていません。") {
            try $0.selectFile(url, kind: kind, control: $1)
        }
    }

    func selectCandidate(_ name: String, kind: MaterialKind) {
        perform(success: "\(kind.title)を取得しました。内容の解析はまだ行っていません。") {
            try $0.selectCandidate(name, kind: kind, control: $1)
        }
    }

    func refresh(_ kind: MaterialKind) {
        perform(success: "\(kind.title)を再取得しました。") { try $0.refresh(kind, control: $1) }
    }

    func fetchEvents() {
        perform(success: "学校行事PDFを確認しました。変更がなければ保存済みの資料を使います。") {
            try $0.fetchEvents(control: $1)
        }
    }

    func analyzeChanges(defaultYear: Int?) {
        perform(success: "時間割変更を解析しました。解析結果から日付・クラス・科目を確認してください。") {
            try $0.analyzeChanges(defaultYear: defaultYear, control: $1)
        }
    }

    func analyzePDF(_ kind: MaterialKind) {
        perform(success: "\(kind.title)を解析しました。元PDFと解析結果を確認してください。") {
            try $0.analyzePDF(kind: kind, control: $1)
        }
    }

    func previewChanges() {
        guard canPreviewChanges else { return }
        perform(success: nil) { try $0.previewChanges(control: $1) }
    }

    func dismissPreview() { changePreview = nil }

    func cancel() {
        control?.cancel()
        message = "中止を要求しました。処理の終了を待っています。"
    }

    private func perform(success: String?, operation: @escaping (MaterialWorker, AcquisitionControl) throws -> Void) {
        guard !busy else { return }
        busy = true
        failed = false
        message = nil
        changePreview = nil
        let worker = self.worker
        let control = AcquisitionControl()
        self.control = control
        queue.async {
            let result = Result { try operation(worker, control) }
            let preview = worker.changePreview
            worker.clearPreview()
            let snapshot = worker.library?.state
            let timetableReport = worker.timetableReadReport
            let timetableFailure = worker.timetableFailure
            var pdfURLs: [String: URL] = [:]
            for kind in [MaterialKind.timetable, .events] { pdfURLs[kind.rawValue] = worker.pdfURL(for: kind) }
            let candidates = worker.candidates
            let listed = worker.folderListed
            DispatchQueue.main.async {
                self.ready = snapshot != nil
                if let snapshot = snapshot { self.state = snapshot }
                self.pdfURLs = pdfURLs
                self.timetableReadReport = timetableReport
                self.timetableFailure = timetableFailure
                self.candidates = candidates
                self.folderListed = listed
                self.busy = false
                self.control = nil
                switch result {
                case .success:
                    self.message = success
                    self.changePreview = preview
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? ChangeParseError)?.localizedDescription
                        ?? (error as? PDFParseError)?.localizedDescription
                        ?? ((error as? MaterialError) ?? .unavailable).localizedDescription
                }
            }
        }
    }
}
