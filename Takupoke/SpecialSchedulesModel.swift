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
    private var retired = false
    private var generation = UUID()
    private var control: AcquisitionControl?
    private var backgroundRefreshID: UUID?
    private var pendingSelections = PendingFileSelections<SpecialScheduleKind, ScopedMaterialSelection>()
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
        guard !retired else { return }
        pendingSelections.append(selection, kind: kind)
        runPendingSelection()
    }

    private func runPendingSelection() {
        guard !retired, let selected = pendingSelections.take(busy: busy) else { return }
        analyze(kind: selected.kind, selection: selected.selection)
    }

    func analyzePDF(_ kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: nil)
    }

    func closeForRetention() async {
        retired = true
        generation = UUID()
        setFileMonitoring(false)
        cancel()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        store = nil; records = [:]; sources = [:]; urls = [:]; fullReadReports = [:]
        ready = false; busy = false; control = nil; message = nil; failed = false
        fileMonitor.update([])
    }

    func resumeAfterRetention() { retired = false }

    func cancel() {
        FileRefreshDiagnostics.shared.record(.cancelled)
        fileRefreshQueue.suspend()
        fileMonitor.suspend()
        pendingSelections.clear()
        control?.cancel()
        message = busy ? "中止を要求しました。処理の終了を待っています。" : "自動確認を中止しました。"
    }

    func refreshInBackground() async -> Bool {
        guard !busy, !retired, !Task.isCancelled else { return false }
        let id = UUID()
        backgroundRefreshID = id
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                perform(success: nil, completion: {
                    if self.backgroundRefreshID == id { self.backgroundRefreshID = nil }
                    continuation.resume(returning: $0)
                }) { store, control, _ in
                    try control.check()
                    let requested = Set(SpecialScheduleKind.allCases.compactMap { kind in
                        store.sources[kind]?.grant == nil ? nil : kind.rawValue
                    })
                    try Self.refreshSelectedFiles(store, requested: requested, control: control)
                }
            }
        } onCancel: {
            Task { @MainActor in
                if self.backgroundRefreshID == id { self.control?.cancel() }
            }
        }
        if backgroundRefreshID == id { backgroundRefreshID = nil }
        return result && !Task.isCancelled
    }

    func perform(success: String?, reporting kind: SpecialScheduleKind? = nil,
                         completion: ((Bool) -> Void)? = nil,
                         operation: @escaping (SpecialScheduleStore, AcquisitionControl,
                                               SpecialDiagnosticCapture) throws -> Void) {
        guard !busy, !retired else { completion?(false); return }
        busy = true
        failed = false
        message = nil
        let operationGeneration = generation
        let control = AcquisitionControl()
        self.control = control
        let existingStore = store
        queue.async {
            let capture = SpecialDiagnosticCapture()
            let result = Result { () throws -> Void in
                try control.check()
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
                guard !self.retired, operationGeneration == self.generation else { completion?(false); return }
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
                defer { self.runPendingSelection(); self.runPendingFileRefresh() }
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "\(kind?.title ?? "試験時間割・試験返却時間割")を保存できませんでした。前回の解析結果は保持しています。"
                }
                completion?(!self.failed)
            }
        }
    }

}
