import Foundation
import SwiftUI

@MainActor
final class MaterialsModel: ObservableObject {
    @Published private(set) var state = MaterialLibraryState()
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
    private var retired = false
    private var control: AcquisitionControl?
    var fileRefreshQueue = FileRefreshQueue()
    lazy var fileMonitor = SelectedFileMonitor { [weak self] id in
        self?.fileRefreshQueue.request(id)
        self?.runPendingFileRefresh()
    }

    func loadIfNeeded() {
        guard !ready else { return }
        perform(success: nil) { worker, _ in try worker.open() }
    }

    func selectFile(_ url: ScopedMaterialSelection, kind: MaterialKind) {
        let year = automaticChangeSchoolYear
        perform(success: "\(kind.title)を取得して解析しました。") { worker, control in
            try worker.selectFile(url, kind: kind, control: control)
            try Self.analyzeAfterAcquisition(kind, year: year, worker: worker, control: control)
        }
    }

    func refresh(_ kind: MaterialKind) {
        let year = automaticChangeSchoolYear
        perform(success: "\(kind.title)を再取得して解析しました。") { worker, control in
            try worker.refresh(kind, control: control)
            try Self.analyzeAfterAcquisition(kind, year: year, worker: worker, control: control)
        }
    }

    func fetchEvents() {
        perform(success: "学校行事PDFを取得・確認して解析しました。") { worker, control in
            try worker.fetchEvents(control: control)
            try worker.analyzePDF(kind: .events, control: control)
        }
    }

    var automaticChangeSchoolYear: Int {
        ChangeNormalizer.effectiveSchoolYear(
            configured: UserDefaults.standard.string(forKey: ChangeNormalizer.schoolYearSettingKey),
            today: SchoolDate.today())
    }

    private nonisolated static func analyzeAfterAcquisition(_ kind: MaterialKind, year: Int,
                                                            worker: MaterialWorker,
                                                            control: AcquisitionControl) throws {
        if kind == .changes { try worker.analyzeChanges(defaultYear: year, control: control) }
        else { try worker.analyzePDF(kind: kind, control: control) }
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

    func closeForRetention() async {
        retired = true
        setFileMonitoring(false)
        cancel()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.worker.close()
                continuation.resume()
            }
        }
        state = MaterialLibraryState(); pdfURLs = [:]; changePreview = nil
        timetableReadReport = nil; timetableFailure = nil
        ready = false; busy = false; control = nil; message = nil; failed = false
        fileMonitor.update([])
    }

    func resumeAfterRetention() { retired = false }

    func cancel() {
        FileRefreshDiagnostics.shared.record(.cancelled)
        fileRefreshQueue.suspend()
        fileMonitor.suspend()
        control?.cancel()
        message = busy ? "中止を要求しました。処理の終了を待っています。" : "自動確認を中止しました。"
    }

    func perform(success: String?, operation: @escaping (MaterialWorker, AcquisitionControl) throws -> Void) {
        guard !busy, !retired else { return }
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
            DispatchQueue.main.async {
                guard !self.retired else { self.busy = false; return }
                self.ready = snapshot != nil
                if let snapshot = snapshot { self.state = snapshot }
                self.pdfURLs = pdfURLs
                self.timetableReadReport = timetableReport
                self.timetableFailure = timetableFailure
                self.busy = false
                self.control = nil
                self.updateFileMonitoring()
                defer { self.runPendingFileRefresh() }
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
