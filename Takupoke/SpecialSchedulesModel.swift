import Foundation
import SwiftUI

/// Written only by the serial import worker, then read once on the main queue.
final class SpecialDiagnosticCapture {
    var report: String?
    var positionsReport: String?
    var failure: PDFParseError?
    var store: SpecialScheduleStore?
    var recoveryPages: [RecoveryReadPage]?
}

@MainActor
final class SpecialSchedulesModel: ObservableObject {
    @Published private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:] {
        didSet {
            let next = records.values.map(\.analysis).sorted { $0.kind.rawValue < $1.kind.rawValue }
            if scheduleAnalyses != next { scheduleAnalyses = next; scheduleGeneration = UUID() }
        }
    }
    private(set) var scheduleAnalyses = [SpecialScheduleAnalysis]()
    private(set) var scheduleGeneration = UUID()
    @Published private(set) var sources: [SpecialScheduleKind: SpecialScheduleSource] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var cancellationRequested = false
    @Published private(set) var lastOperationWasCancelled = false
    private(set) var rejectedRecoveryKinds = Set<SpecialScheduleKind>()
    @Published private(set) var returnPositionsReport: String?
    @Published var fullReadReports: [SpecialScheduleKind: String] = [:]

    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.special-schedules", qos: .userInitiated)
    private var recoveryCaptures: [SpecialScheduleKind: (String, [RecoveryReadPage])] = [:]
    private var store: SpecialScheduleStore?
    private var retired = false
    private var generation = UUID()
    private var control: AcquisitionControl?
    private var backgroundRefreshID: UUID?
    private var pendingSelections = PendingFileSelections<SpecialScheduleKind, ScopedMaterialSelection>()
    @Published var fileRefreshQueue = FileRefreshQueue()
    lazy var fileMonitor = SelectedFileMonitor { [weak self] id in
        guard self?.cancellationRequested == false else { return }
        self?.fileRefreshQueue.request(id)
        self?.runPendingFileRefresh()
    }

    var availability: SpecialScheduleAvailability {
        SpecialScheduleAvailability(ready: ready, busy: busy, failed: failed, sources: sources, records: records)
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
        store = nil; recoveryCaptures = [:]; records = [:]; sources = [:]; urls = [:]; fullReadReports = [:]; returnPositionsReport = nil
        ready = false; busy = false; cancellationRequested = false; lastOperationWasCancelled = false; control = nil; message = nil; failed = false
        fileMonitor.update([])
    }

    func resumeAfterRetention() { retired = false }

    func cancel() {
        pauseAutomaticChecks()
        cancelCurrentOperation()
    }

    func pauseAutomaticChecks() {
        fileRefreshQueue.suspend()
        fileMonitor.suspend()
    }

    func resumeAutomaticChecks() {
        guard !retired else { return }
        fileRefreshQueue.resume()
        fileMonitor.resume()
    }

    func cancelCurrentOperation() {
        guard busy else { return }
        FileRefreshDiagnostics.shared.record(.cancelled)
        cancellationRequested = true
        fileRefreshQueue.discardPending()
        fileMonitor.discardPendingRefreshes()
        pendingSelections.clear()
        control?.cancel()
        message = "中止を要求しました。処理の終了を待っています。"
    }

    func refreshInBackground() async -> Bool {
        guard !fileRefreshQueue.suspended, !busy, !retired, !Task.isCancelled else { return false }
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
        cancellationRequested = false
        lastOperationWasCancelled = false
        returnPositionsReport = nil
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
            let projection = capture.store?.displayableRecords()
            DispatchQueue.main.async {
                guard !self.retired, operationGeneration == self.generation else { completion?(false); return }
                self.busy = false
                self.control = nil
                if self.cancellationRequested {
                    self.fileRefreshQueue.discardPending()
                    self.fileMonitor.discardPendingRefreshes()
                }
                self.cancellationRequested = false
                self.returnPositionsReport = capture.positionsReport
                if let kind { self.fullReadReports[kind] = capture.report }
                if let store = capture.store {
                    self.store = store
                    self.records = projection?.records ?? [:]
                    self.rejectedRecoveryKinds = projection?.rejected ?? []
                    self.sources = store.sources
                    self.urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                        store.selectedURL(for: kind).map { (kind, $0) }
                    })
                    self.ready = true
                    if let kind, let pages = capture.recoveryPages, let source = store.sources[kind] { self.recoveryCaptures[kind] = (source.storedName,pages) }
                }
                self.updateFileMonitoring(retryFailedFor: control.acquiredProviderSources)
                defer { self.runPendingSelection(); self.runPendingFileRefresh() }
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.lastOperationWasCancelled = FileOperationOutcome.isCancellation(error)
                    self.failed = !self.lastOperationWasCancelled
                    self.message = self.lastOperationWasCancelled ? MaterialError.cancelled.localizedDescription :
                        (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "\(kind?.title ?? "試験時間割・試験返却時間割")を保存できませんでした。前回の解析結果は保持しています。"
                }
                if case .success = result { completion?(true) } else { completion?(false) }
            }
        }
    }

}


extension SpecialSchedulesModel {
    func recoverySource(_ kind: SpecialScheduleKind) async -> RecoverySelectedSource? {
        guard ready, !busy, !retired, let period = ApplicationData.shared.loadedPeriod else { return nil }
        let captured = recoveryCaptures[kind]
        let capturedSource = RecoverySourceCapture()
        return await withCheckedContinuation { continuation in
            perform(success:nil,completion:{ success in continuation.resume(returning:success ? capturedSource.source : nil) }) { store,control,_ in
                guard let source = store.sources[kind],
                      RecoveryPolicy.mayRecover(digest:source.digest,kind:kind == .exam ? .exam : .return,parserVersion:SpecialScheduleAnalysis.parserVersion,
                        attemptDigest:source.digest,attemptVersion:source.attemptParserVersion,failure:source.failure,job:source.recoveryJob),
                      let url = store.selectedURL(for:kind) else { throw PDFParseError(code:.unsupported) }
                let selected = RecoverySelectedSource(kind:kind == .exam ? .exam : .return,url:url,digest:source.digest,originalName:source.originalName,storedName:source.storedName,period:period,captured:captured?.0 == source.storedName ? captured?.1 ?? [] : [])
                try control.check(); capturedSource.source = selected
            }
        }
    }
    func adoptRecovery(_ preview: RecoveryPreview) async -> RecoveryAdoptionResult {
        guard LocalAIFeaturePolicy.enabled else { return .invalidated }
        let kind: SpecialScheduleKind = preview.document.kind == .exam ? .exam : .examReturn
        let ticket = LocalAIFeaturePolicy.capture()
        let cancelled = AcquisitionControl()
        let save = RecoverySaveAttempt()
        return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            perform(success:"復旧結果を採用しました。",completion:{ continuation.resume(returning:save.result(saved:$0)) }) { store,control,_ in
                guard let selected = store.sources[kind], selected.attemptParserVersion == SpecialScheduleAnalysis.parserVersion,
                      selected.failure.map(RecoveryPolicy.eligible) == true, selected.recoveryJob?.pdfHash == selected.digest,
                      let selectedURL = store.selectedURL(for:kind), selectedURL == preview.source.url else { throw PDFParseError(code:.storage) }
                let analysis = try RecoveryConversion.special(preview, selected:selected)
                try RecoveryConversion.verifyFile(preview.source,check:{ try cancelled.check(); try control.check() })
                guard preview.source.period == SchoolDataPeriod.current() else { throw PDFParseError(code:.cancelled) }
                try cancelled.check(); try control.check(); try LocalAIFeaturePolicy.check(ticket)
                try save.persist { try store.saveAnalysis(analysis) }
            }
        }
        } onCancel: { cancelled.cancel() }
    }
}
