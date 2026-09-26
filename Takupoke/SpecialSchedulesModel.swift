import Foundation
import SwiftUI

/// Written only by the serial import worker, then read once on the main queue.
final class SpecialDiagnosticCapture {
    var report: String?
    var failure: PDFParseError?
    var store: SpecialScheduleStore?
}

@MainActor
final class SpecialSchedulesModel: ObservableObject {
    @Published private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    @Published private(set) var sources: [SpecialScheduleKind: SpecialScheduleSource] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published var fullReadReports: [SpecialScheduleKind: String] = [:]

    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.special-schedules", qos: .userInitiated)
    private var store: SpecialScheduleStore?
    private var control: AcquisitionControl?
    var fileRefreshQueue = FileRefreshQueue()
    lazy var fileMonitor = SelectedFileMonitor { [weak self] id in
        self?.fileRefreshQueue.request(id)
        self?.runPendingFileRefresh()
    }

    func loadIfNeeded() {
        guard !ready, !busy else { return }
        perform(success: nil) { store, _, _ in _ = store }
    }

    func importPDF(_ selection: ScopedMaterialSelection, kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: selection)
    }

    func analyzePDF(_ kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: nil)
    }

    func cancel() {
        control?.cancel()
        message = "中止を要求しました。処理の終了を待っています。"
    }

    func perform(success: String?, reporting kind: SpecialScheduleKind? = nil,
                         operation: @escaping (SpecialScheduleStore, AcquisitionControl,
                                               SpecialDiagnosticCapture) throws -> Void) {
        guard !busy else { return }
        busy = true
        failed = false
        message = nil
        let control = AcquisitionControl()
        self.control = control
        let existingStore = store
        queue.async {
            let capture = SpecialDiagnosticCapture()
            let result = Result { () throws -> Void in
                let store: SpecialScheduleStore
                if let existing = existingStore { store = existing }
                else {
                    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
                    store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite", isDirectory: true))
                }
                capture.store = store
                try operation(store, control, capture)
            }
            DispatchQueue.main.async {
                self.busy = false
                self.control = nil
                if let kind { self.fullReadReports[kind] = capture.report }
                if let store = capture.store {
                    self.store = store
                    self.records = store.records
                    self.sources = store.sources
                    self.urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                        store.selectedURL(for: kind).map { (kind, $0) }
                    })
                    self.ready = true
                }
                self.updateFileMonitoring()
                defer { self.runPendingFileRefresh() }
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "\(kind?.title ?? "試験時間割・試験返却時間割")を保存できませんでした。前回の解析結果は保持しています。"
                }
            }
        }
    }

}
