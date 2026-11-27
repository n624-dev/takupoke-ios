import Combine
import Foundation
import SwiftUI

/// Written only by the serial import worker, then read once on the main queue.
final class SpecialDiagnosticCapture {
    var report: String?
    var positionsReport: String?
    var failure: PDFParseError?
    var store: SpecialScheduleStore?
    var recoveryPages: [RecoveryReadPage]?
    var evidenceStoredName: String?
    var evidenceDigest: String?
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
    @Published private(set) var acquisitionAttempts: [SpecialScheduleKind: AcquisitionAttempt] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var lastOperationUsedPipeline = false
    private var pendingPipelineRequest: FilePipeline.Request?
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
    var pendingManualRefresh = Set<SpecialScheduleKind>()
    var pendingManualChecks = Set<SpecialScheduleKind>()
    private var pendingSelections = PendingFileSelections<SpecialScheduleKind, ScopedMaterialSelection>()
    @Published var fileRefreshQueue = FileRefreshQueue()
    private var pipelineEvents: AnyCancellable?
    private var pipelineObservation: FilePipeline.Observation?
    private static let pipelineSources: Set<FileRefreshDiagnostics.Source> = [.exam, .examReturn]
    var pipelineMonitorIDs: [FileRefreshDiagnostics.Source: UUID] = [:]
    func observePipeline(_ foreground: Bool) {
        guard foreground else { pipelineEvents = nil; pipelineObservation = nil; return }
        if pipelineEvents == nil {
            pipelineEvents = NotificationCenter.default.publisher(for: .filePipelineChanged).sink { [weak self] change in
                guard (change.object as? FilePipeline) === FilePipeline.shared else { return }
                Task { @MainActor [weak self] in self?.applyPipelineObservation() }
            }
        }
        applyPipelineObservation()
    }

    private func applyPipelineObservation() {
        guard pipelineEvents != nil, !retired else { return }
        let current = FilePipeline.shared.observation.restricting(to: Self.pipelineSources)
        let previous = pipelineObservation
        guard current != previous else { return }
        pipelineObservation = current
        objectWillChange.send()
        if current.completed != previous?.completed { reloadPipelineProjection() }
        runPendingSelection()
        runPendingFileRefresh()
    }
    lazy var fileMonitor = SelectedFileMonitor(registrationChanged: { [weak self] in
        guard let self, !self.retired else { return }
        self.objectWillChange.send()
        self.runPendingSelection()
        self.runPendingFileRefresh()
    }, changed: { [weak self] id in
        guard self?.cancellationRequested == false else { return }
        self?.fileRefreshQueue.request(id)
        self?.runPendingFileRefresh()
    })

    private func applyPipelineResult(_ observation: FilePipeline.Observation) {
        guard !busy, let request = pendingPipelineRequest,
              let result = observation.result(for: request.id, sources: request.sources) else { return }
        pendingPipelineRequest = nil
        switch result {
        case .succeeded: message = request.successMessage
        case .cancelled:
            lastOperationWasCancelled = true
            message = MaterialError.cancelled.localizedDescription
        case .failed(let explanation):
            failed = true
            message = explanation
        }
    }

    func reloadPipelineProjection() {
        guard ready, !retired, let store else { return }
        let capturedGeneration = generation
        queue.async {
            let outcomes = FilePipeline.shared.observation.restricting(to: [.exam, .examReturn]).completed
            let projection = store.displayableRecords(), sources = store.sources
            let acquisitionAttempts = store.acquisitionAttempts
            let evidence = store.pipelineEvidence
            let urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                store.selectedURL(for: kind).map { (kind, $0) }
            })
            DispatchQueue.main.async {
                guard !self.retired, self.generation == capturedGeneration else { return }
                self.records = projection.records; self.rejectedRecoveryKinds = projection.rejected
                self.sources = sources; self.urls = urls
                self.acquisitionAttempts = acquisitionAttempts

                let latest = FilePipeline.shared.observation
                let currentOutcomes = outcomes.filter { latest.completed[$0.key]?.id == $0.value.id }
                let acquired = FilePipeline.claimMonitorRegistrations(in: currentOutcomes, handled: &self.pipelineMonitorIDs)
                self.updateFileMonitoring(retryFailedFor: acquired)
                self.applyPipelineResult(latest)
                for kind in SpecialScheduleKind.allCases {
                    if let value = evidence[kind], value.storedName == sources[kind]?.storedName, value.digest == sources[kind]?.digest {
                        self.fullReadReports[kind] = value.report
                        if let pages = value.pages, let storedName = value.storedName { self.recoveryCaptures[kind] = (storedName, pages) }
                        else { self.recoveryCaptures.removeValue(forKey: kind) }
                    } else if self.recoveryCaptures[kind]?.0 != sources[kind]?.storedName {
                        self.recoveryCaptures.removeValue(forKey: kind); self.fullReadReports[kind] = nil
                    }
                }
            }
        }
    }

    var availability: SpecialScheduleAvailability {
        SpecialScheduleAvailability(ready: ready, busy: busy, failed: failed, sources: sources, records: records,
                                    acquisitionAttempts: acquisitionAttempts)
    }

    func loadIfNeeded() {
        guard !ready, !busy else { return }
        perform(success: nil) { store, _, _ in _ = store }
    }

    func importPDF(_ selection: ScopedMaterialSelection, kind: SpecialScheduleKind) {
        guard !retired else { return }
        FilePipeline.shared.cancel(kind.rawValue)
        pendingSelections.append(selection, kind: kind)
        runPendingSelection()
    }

    private func runPendingSelection() {
        guard !retired, let selected = pendingSelections.take(busy: busy, blocked: { kind in
            FilePipeline.shared.isRecovering(kind.rawValue) || fileMonitor.isRegistering(kind.rawValue)
        }) else {
            if !retired, !busy, let kind = pendingManualRefresh.first(where: { !FilePipeline.shared.isRecovering($0.rawValue) && !fileMonitor.isRegistering($0.rawValue) }) {
                pendingManualRefresh.remove(kind); refresh(kind)
            } else if !retired, !busy, let kind = pendingManualChecks.first(where: { !fileMonitor.isRegistering($0.rawValue) }) {
                pendingManualChecks.remove(kind); checkForUpdates(kind)
            }
            return
        }
        analyze(kind: selected.kind, selection: selected.selection)
    }

    func analyzePDF(_ kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: nil)
    }

    func closeForRetention() async {
        retired = true
        FilePipeline.shared.cancel([FileRefreshDiagnostics.Source.exam, .examReturn])
        FilePipeline.shared.clearStatuses([FileRefreshDiagnostics.Source.exam, .examReturn])
        generation = UUID()
        setFileMonitoring(false)
        pauseAutomaticChecks()
        cancelCurrentOperation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        store = nil; recoveryCaptures = [:]; records = [:]; sources = [:]; urls = [:]; fullReadReports = [:]; returnPositionsReport = nil
        acquisitionAttempts = [:]
        ready = false; busy = false; cancellationRequested = false; lastOperationWasCancelled = false; control = nil; message = nil; failed = false
        fileMonitor.update([])
    }

    func resumeAfterRetention() { retired = false }

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
        guard busy || ["exam", "examReturn"].contains(where: { FilePipeline.shared.isRecovering($0) }) else { return }
        FileRefreshDiagnostics.shared.record(.cancelled)
        // A delayed retry has no model operation completion to clear this flag.
        cancellationRequested = busy
        fileRefreshQueue.discardPending()
        fileMonitor.discardPendingRefreshes()
        pendingSelections.clear()
        pendingManualRefresh.removeAll()
        pendingManualChecks.removeAll()
        FilePipeline.shared.cancel([.exam, .examReturn])
        control?.cancel()
        if busy {
            message = "中止を要求しました。処理の終了を待っています。"
        } else {
            lastOperationWasCancelled = true
            failed = false
            message = MaterialError.cancelled.localizedDescription
            pendingPipelineRequest = nil
        }
    }

    func refreshInBackground() async -> Bool {
        guard !fileRefreshQueue.suspended, !busy, !retired, !Task.isCancelled else { return false }
        let blocked = fileMonitor.blockedSources
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
                    }).subtracting(blocked)
                    try Self.refreshSelectedFiles(store, requested: requested, control: control, reason: .background)
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
        let control = AcquisitionControl(intents: FilePipeline.shared.intentSnapshot)
        self.control = control
        pendingPipelineRequest = nil
        lastOperationUsedPipeline = false
        let existingStore = store
        let ownerQueue = queue
        queue.async {
            let capture = SpecialDiagnosticCapture()
            let result = Result { () throws -> Void in
                try control.check()
                let store: SpecialScheduleStore
                if let existing = existingStore { store = existing }
                else {
                    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
                    store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite", isDirectory: true), ownerQueue: ownerQueue)
                }
                capture.store = store
                try operation(store, control, capture)
            }
            let projection = capture.store?.displayableRecords()
            let frozenSources = capture.store?.sources ?? [:]
            let frozenAcquisitionAttempts = capture.store?.acquisitionAttempts ?? [:]
            let frozenURLs = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                capture.store?.selectedURL(for: kind).map { (kind, $0) }
            })
            let usedPipeline = control.usedPipeline
            let pipelineSources = control.pipelineSources
            let outcomes = FilePipeline.shared.observation
            let stillRunning = pipelineSources.contains {
                outcomes.statuses[$0]?.requestID == control.operationID && outcomes.activeSources.contains($0)
            }
            DispatchQueue.main.async {
                guard !self.retired, operationGeneration == self.generation else { completion?(false); return }
                self.busy = false
                self.lastOperationUsedPipeline = usedPipeline
                self.control = nil
                if self.cancellationRequested {
                    self.fileRefreshQueue.discardPending()
                    self.fileMonitor.discardPendingRefreshes()
                }
                let cancelled = self.cancellationRequested
                self.cancellationRequested = false
                self.returnPositionsReport = capture.positionsReport
                if let kind { self.fullReadReports[kind] = capture.report }
                if let store = capture.store {
                    self.store = store
                    self.records = projection?.records ?? [:]
                    self.rejectedRecoveryKinds = projection?.rejected ?? []
                    self.sources = frozenSources
                    self.acquisitionAttempts = frozenAcquisitionAttempts
                    self.urls = frozenURLs
                    self.ready = true
                    if let kind, let pages = capture.recoveryPages, let source = frozenSources[kind],
                       capture.evidenceStoredName == source.storedName, capture.evidenceDigest == source.digest {
                        self.recoveryCaptures[kind] = (source.storedName, pages)
                    }
                }
                let latest = FilePipeline.shared.observation
                let currentOutcomes = outcomes.restricting(to: pipelineSources).completed
                    .filter { latest.completed[$0.key]?.id == $0.value.id && $0.value.requestID == control.operationID }
                let committed = FilePipeline.claimMonitorRegistrations(in: currentOutcomes, handled: &self.pipelineMonitorIDs)
                let direct = control.acquiredProviderSources.subtracting(pipelineSources.map(\.rawValue))
                self.updateFileMonitoring(retryFailedFor: committed.union(direct))
                defer { self.runPendingSelection(); self.runPendingFileRefresh() }
                if stillRunning, !cancelled, completion == nil {
                    self.pendingPipelineRequest = .init(id: control.operationID, sources: pipelineSources, successMessage: success)
                    self.applyPipelineResult(latest)
                    return
                }
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.lastOperationWasCancelled = FileOperationOutcome.isCancellation(error)
                    self.failed = !self.lastOperationWasCancelled
                    self.message = self.lastOperationWasCancelled ? MaterialError.cancelled.localizedDescription :
                        (error as? PDFParseError)?.localizedDescription
                        ?? (error as? FilePipeline.Failure)?.localizedDescription
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
                try save.persist {
                    try store.saveAnalysis(analysis)
                    if let source = FileRefreshDiagnostics.Source(rawValue: kind.rawValue) { FilePipeline.shared.clearTerminalStatus(source) }
                }
            }
        }
        } onCancel: { cancelled.cancel() }
    }
}
