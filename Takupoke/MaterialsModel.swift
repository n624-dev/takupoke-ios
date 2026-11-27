import Foundation
import SwiftUI

@MainActor
final class MaterialsModel: ObservableObject {
    @Published private(set) var state = MaterialLibraryState() {
        didSet {
            if !TimetableSchedule.sameProjection(oldValue.pdfAnalyses?[MaterialKind.timetable.rawValue],state.pdfAnalyses?[MaterialKind.timetable.rawValue]) ||
                !TimetableSchedule.sameProjection(oldValue.changeAnalysis,state.changeAnalysis) { scheduleGeneration = UUID() }
        }
    }
    private(set) var scheduleGeneration = UUID()
    @Published private(set) var busy = false
    @Published private(set) var ready = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var lastOperationUsedPipeline = false
    private var messageOperationID: UUID?
    @Published private(set) var cancellationRequested = false
    @Published private(set) var lastOperationWasCancelled = false
    @Published private(set) var changePreview: ChangePreview?
    @Published private(set) var pdfURLs: [String: URL] = [:]
    @Published private(set) var timetableReadReport: String?
    @Published private(set) var timetableFailure: PDFParseError?
    private var changeFailureContext: (identity: String, digest: String, year: Int)?
    private(set) var rejectedRecoveryKinds = Set<String>()

    var canPreviewChanges: Bool {
        guard let year = automaticChangeSchoolYear, let record = state.record(for: .changes), let attempt = state.changeParseAttempt,
              attempt.sourceDigest == record.digest, attempt.parserVersion == ChangeAnalysis.parserVersion else { return false }
        if record.source.rowSkipConsent?.matches(sourceIdentity: record.source.selectionID ?? record.storedName,
            digest: record.digest, defaultYear: year) == true { return true }
        guard attempt.failure.map({ $0.permitsPreview || [.cancelled, .storage, .staleConfirmation].contains($0.code) }) == true else { return false }
        return attempt.matches(digest: record.digest, defaultYear: year)
    }

    private let worker = MaterialWorker()
    private var queue: DispatchQueue { worker.ownerQueue }
    private var retired = false
    private var generation = UUID()
    private var control: AcquisitionControl?
    private var backgroundRefreshID: UUID?
    var pendingManualRefresh = Set<MaterialKind>()
    private var pendingSelections = PendingFileSelections<MaterialKind, ScopedMaterialSelection>()
    @Published var fileRefreshQueue = FileRefreshQueue()
    var pipelineTimer: Timer?
    var pipelineMonitorIDs: [FileRefreshDiagnostics.Source: UUID] = [:]
    var pipelineActive = Set<FileRefreshDiagnostics.Source>()
    var pipelineSnapshot: [FileRefreshDiagnostics.Source: FilePipeline.Status] = [:]
    func observePipeline(_ foreground: Bool) {
        pipelineTimer?.invalidate(); pipelineTimer = nil
        guard foreground else { return }
        pipelineTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let snapshot = FilePipeline.shared.snapshot
                let active = FilePipeline.shared.activeSources
                if snapshot != self.pipelineSnapshot || active != self.pipelineActive {
                    self.pipelineSnapshot = snapshot; self.pipelineActive = active; self.objectWillChange.send()
                    self.reloadPipelineProjection()
                    self.runPendingSelection(); self.runPendingFileRefresh()
                }
            }
        }
    }
    lazy var fileMonitor = SelectedFileMonitor { [weak self] id in
        guard self?.cancellationRequested == false else { return }
        self?.fileRefreshQueue.request(id)
        self?.runPendingFileRefresh()
    }

    func reloadPipelineProjection() {
        guard ready, !retired else { return }
        let capturedGeneration = generation
        queue.async {
            let outcomes = FilePipeline.shared.snapshot.filter { ["timetable", "changes"].contains($0.key.rawValue) }
            guard let library = self.worker.library else { return }
            let display = MaterialLibrary.displayableTimetables(library.state)
            let report = self.worker.timetableReadReport, failure = self.worker.timetableFailure
            let urls = Dictionary(uniqueKeysWithValues: [MaterialKind.timetable, .events].compactMap { kind in
                library.localURL(for: kind).map { (kind.rawValue, $0) }
            })
            DispatchQueue.main.async {
                guard !self.retired, self.generation == capturedGeneration else { return }
                self.state = display.state; self.rejectedRecoveryKinds = display.rejected; self.pdfURLs = urls
                self.timetableReadReport = report; self.timetableFailure = failure

                let latest = FilePipeline.shared.snapshot
                let acquired = Set<String>(outcomes.compactMap { key, value -> String? in
                    guard value.canRetryMonitorRegistration, latest[key]?.id == value.id,
                          self.pipelineMonitorIDs[key] != value.id else { return nil }
                    self.pipelineMonitorIDs[key] = value.id
                    return key.rawValue
                })
                self.updateFileMonitoring(retryFailedFor: acquired)
                if !self.busy, let request = self.messageOperationID {
                    let current = outcomes.values.filter { $0.requestID == request }
                    if current.contains(where: { $0.attempt > 0 }), current.allSatisfy({ $0.stage == .succeeded || $0.stage == .unchanged }) {
                        self.failed = false; self.message = nil; self.lastOperationWasCancelled = false; self.messageOperationID = nil
                    }
                }
            }
        }
    }

    func loadIfNeeded() {
        guard !ready else { return }
        perform(success: nil) { worker, _ in try worker.open() }
    }

    func selectFile(_ url: ScopedMaterialSelection, kind: MaterialKind) {
        guard !retired else { return }
        FilePipeline.shared.cancel(kind.rawValue)
        pendingSelections.append(url, kind: kind)
        runPendingSelection()
    }

    private func runPendingSelection() {
        while !retired, let selected = pendingSelections.take(busy: busy, blocked: { kind in
            FilePipeline.shared.isRecovering(kind.rawValue)
        }) {
            let (kind, url) = selected
            guard acceptsChangeYear(kind) else { continue }
            let year = automaticChangeSchoolYear
            perform(success: "\(kind.title)を取得して解析しました。") { worker, control in
                try worker.pipeline(kind, reason: .selection, control: control) { worker, control in
                    try worker.selectFile(url, kind: kind, control: control)
                    try Self.analyzeAfterAcquisition(kind, year: year, worker: worker, control: control)
                }
            }
            return
        }
        if !busy, let kind = pendingManualRefresh.first(where: { !FilePipeline.shared.isRecovering($0.rawValue) }) {
            pendingManualRefresh.remove(kind); refresh(kind)
        }
    }

    func refresh(_ kind: MaterialKind) {
        guard !retired else { return }
        if busy || FilePipeline.shared.isRecovering(kind.rawValue) { pendingManualRefresh.insert(kind); return }
        guard acceptsChangeYear(kind) else { return }
        let year = automaticChangeSchoolYear
        perform(success: "\(kind.title)を再取得して解析しました。") { worker, control in
            try worker.pipeline(kind, reason: .manual, control: control) { worker, control in
                try worker.refresh(kind, control: control)
                try Self.analyzeAfterAcquisition(kind, year: year, worker: worker, control: control)
            }
        }
    }

    func fetchEvents() {
        perform(success: "学校行事PDFを取得・確認して解析しました。") { worker, control in
            try worker.fetchEvents(control: control)
            try worker.analyzePDF(kind: .events, control: control)
        }
    }

    var automaticChangeSchoolYear: Int? {
        ChangeNormalizer.effectiveSchoolYear(
            configured: UserDefaults.standard.string(forKey: ChangeNormalizer.schoolYearSettingKey),
            today: SchoolDate.today())
    }

    var changeFailureMessage: String? {
        guard failed, let context = changeFailureContext, let record = state.record(for: .changes),
              context.identity == (record.source.selectionID ?? record.storedName),
              context.digest == record.digest, context.year == automaticChangeSchoolYear else { return nil }
        return message
    }

    private func acceptsChangeYear(_ kind: MaterialKind) -> Bool {
        guard kind == .changes, automaticChangeSchoolYear == nil else { return true }
        failed = true; message = ChangeParseError(code: .defaultYear).localizedDescription
        return false
    }

    private nonisolated static func analyzeAfterAcquisition(_ kind: MaterialKind, year: Int?,
                                                            worker: MaterialWorker,
                                                            control: AcquisitionControl) throws {
        if kind == .changes {
            guard let year else { throw ChangeParseError(code: .defaultYear) }
            try worker.analyzeChanges(defaultYear: year, control: control)
        }
        else { try worker.analyzePDF(kind: kind, control: control) }
    }

    func analyzeChanges(defaultYear: Int?) {
        guard let year = defaultYear ?? automaticChangeSchoolYear, (1900...9998).contains(year) else {
            failed = true; message = ChangeParseError(code: .defaultYear).localizedDescription; return
        }
        perform(success: "時間割変更を解析しました。", changeYear: year) {
            worker, control in
            try worker.pipeline(.changes, reason: .manual, control: control) { worker, control in
                try worker.analyzeChanges(defaultYear: year, control: control)
            }
        }
    }

    func analyzePDF(_ kind: MaterialKind) {
        perform(success: "\(kind.title)を解析しました。") {
            worker, control in
            try worker.pipeline(kind, reason: .manual, control: control) { worker, control in
                try worker.analyzePDF(kind: kind, control: control)
            }
        }
    }

    func openChangeEditor(sheet: String? = nil, headerRow: Int? = nil) {
        guard let year = automaticChangeSchoolYear else { return }
        perform(success: nil, preserveChangePreview: true, changeYear: year) { worker, control in
            try worker.pipeline(.changes, reason: .review, control: control) { worker, control in
                control.pipelineTicket?.enter(.parsing)
            guard let library = worker.library, let record = library.state.record(for: .changes) else { throw ChangeParseError(code: .invalidArchive) }
            let view = try library.changeEditor(year: year, sheet: sheet, headerRow: headerRow, check: { try control.check() })
            var preview = ChangePreview(sourceName: record.originalName, defaultYear: year, records: [], warnings: [],
                sourceIdentity: record.source.selectionID ?? record.storedName, sourceDigest: record.digest)
            preview.editor = view
            worker.changePreview = preview
            }
        }
    }

    func savePersonalChanges(_ preview: ChangePreview, view: ChangeWorkbookReview, edits: [Int: ChangeRowEdit]) -> String? {
        if let problem = changePreviewActionFailure(preview) { return problem }
        guard let year = preview.defaultYear, let digest = preview.sourceDigest, let identity = preview.sourceIdentity else {
            return ChangeParseError(code: .staleConfirmation).localizedDescription
        }
        perform(success: "個人修正を時間割に反映しました。", preserveChangePreview: true, dismissChangePreviewOnSuccess: true, changeYear: year) { worker, control in
            try worker.pipeline(.changes, reason: .review, control: control) { worker, control in
            try worker.refresh(.changes, control: control)
            guard let library = worker.library else { throw ChangeParseError(code: .storage) }
            control.pipelineTicket?.enter(.parsing)
            try library.saveChangeEditor(view, year: year, expectedIdentity: identity, expectedDigest: digest,
                edits: edits, manual: true, check: { try control.check() })
            }
        }
        return nil
    }

    func previewChanges() {
        guard canPreviewChanges else { return }
        guard let year = automaticChangeSchoolYear else { return }
        perform(success: nil, changeYear: year) { try $0.previewChanges(defaultYear: year, control: $1) }
    }

    func changePreviewActionFailure(_ preview: ChangePreview) -> String? {
        if retired { return "資料の画面を開き直してください。" }
        if busy { return "処理が終わってから、もう一度確定してください。" }
        guard let record = state.record(for: .changes),
              preview.sourceDigest == record.digest,
              preview.sourceIdentity == (record.source.selectionID ?? record.storedName),
              preview.defaultYear == automaticChangeSchoolYear,
              preview.parserVersion == ChangeAnalysis.parserVersion else {
            return "資料または補完年度が変わりました。内容を確認し直してください。"
        }
        return nil
    }

    @discardableResult
    func correctWeekdays(_ preview: ChangePreview) -> String? {
        if let failure = changePreviewActionFailure(preview) { return failure }
        guard let year = automaticChangeSchoolYear else { return ChangeParseError(code: .defaultYear).localizedDescription }
        guard preview.canCorrectWeekdays else { return "曜日の確認内容を開き直してください。" }
        perform(success: "日付から求めた曜日で読み込みました。同じ内容の行には更新後も適用します。", preserveChangePreview: true, dismissChangePreviewOnSuccess: true, changeYear: year) {
            try $0.correctWeekdays(preview, defaultYear: year, control: $1)
        }
        return nil
    }

    func dismissPreview() { changePreview = nil }

    @discardableResult
    func skipChangeRows(_ preview: ChangePreview, rows: Set<Int>, correctWeekdays: Bool = false) -> String? {
        if let failure = changePreviewActionFailure(preview) { return failure }
        guard let year = automaticChangeSchoolYear else { return ChangeParseError(code: .defaultYear).localizedDescription }
        guard preview.canSkipRows, !rows.isEmpty || correctWeekdays || preview.usesDateDerivedWeekdays else { return "除外する行を確認してください。" }
        perform(success: "選んだ\(rows.count)行を除外して読み込みました。同じ内容の行には更新後も適用します。", preserveChangePreview: true, dismissChangePreviewOnSuccess: true, changeYear: year) {
            try $0.skipChangeRows(preview, rows: rows, defaultYear: year, control: $1, correctWeekdays: correctWeekdays)
        }
        return nil
    }

    func closeForRetention() async {
        retired = true
        FilePipeline.shared.cancel([FileRefreshDiagnostics.Source.timetable, .changes])
        FilePipeline.shared.clearStatuses([FileRefreshDiagnostics.Source.timetable, .changes])
        generation = UUID()
        setFileMonitoring(false)
        pauseAutomaticChecks()
        cancelCurrentOperation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.worker.close()
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        state = MaterialLibraryState(); pdfURLs = [:]; changePreview = nil
        timetableReadReport = nil; timetableFailure = nil
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
        guard busy || ["timetable", "changes"].contains(where: { FilePipeline.shared.isRecovering($0) }) else { return }
        FileRefreshDiagnostics.shared.record(.cancelled)
        // A delayed retry has no model operation completion to clear this flag.
        cancellationRequested = busy
        fileRefreshQueue.discardPending()
        fileMonitor.discardPendingRefreshes()
        pendingSelections.clear()
        pendingManualRefresh.removeAll()
        FilePipeline.shared.cancel([.timetable, .changes])
        control?.cancel()
        if busy {
            message = "中止を要求しました。処理の終了を待っています。"
        } else {
            lastOperationWasCancelled = true
            failed = false
            message = MaterialError.cancelled.localizedDescription
            messageOperationID = nil
        }
    }

    func refreshInBackground() async -> Bool {
        guard !fileRefreshQueue.suspended, !busy, !retired, !Task.isCancelled else { return false }
        let id = UUID()
        backgroundRefreshID = id
        let year = automaticChangeSchoolYear
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                perform(success: "保存済みファイルの変更を確認しました。", completion: {
                    if self.backgroundRefreshID == id { self.backgroundRefreshID = nil }
                    continuation.resume(returning: $0)
                }) {
                    worker, control in
                    try control.check()
                    try worker.open()
                    let requested = Set([MaterialKind.timetable, .changes].compactMap { kind in
                        worker.library?.state.record(for: kind)?.source.grant == nil ? nil : kind.rawValue
                    })
                    try Self.refreshSelectedFiles(worker, requested: requested, year: year, control: control, reason: .background)
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

    func perform(success: String?, completion: ((Bool) -> Void)? = nil,
                 preserveChangePreview: Bool = false,
                 dismissChangePreviewOnSuccess: Bool = false,
                 changeYear: Int? = nil,
                 operation: @escaping (MaterialWorker, AcquisitionControl) throws -> Void) {
        guard !busy, !retired else { completion?(false); return }
        busy = true
        cancellationRequested = false
        lastOperationWasCancelled = false
        failed = false
        message = nil
        changeFailureContext = changeYear.flatMap { year in
            state.record(for: .changes).map { (identity: $0.source.selectionID ?? $0.storedName, digest: $0.digest, year: year) }
        }
        if !preserveChangePreview { changePreview = nil }
        let worker = self.worker
        let operationGeneration = generation
        let control = AcquisitionControl(intents: FilePipeline.shared.intentSnapshot)
        self.control = control
        messageOperationID = control.operationID
        lastOperationUsedPipeline = false
        queue.async {
            let result = Result { try operation(worker, control) }
            let preview = worker.changePreview
            worker.clearPreview()
            let display = worker.library.map { MaterialLibrary.displayableTimetables($0.state) }
            let snapshot = display?.state
            let timetableReport = worker.timetableReadReport
            let timetableFailure = worker.timetableFailure
            var pdfURLs: [String: URL] = [:]
            for kind in [MaterialKind.timetable, .events] { pdfURLs[kind.rawValue] = worker.pdfURL(for: kind) }
            let usedPipeline = control.usedPipeline
            DispatchQueue.main.async {
                guard !self.retired, operationGeneration == self.generation else { completion?(false); return }
                self.ready = snapshot != nil
                if let snapshot = snapshot { self.state = snapshot }
                self.rejectedRecoveryKinds = display?.rejected ?? []
                self.pdfURLs = pdfURLs
                self.timetableReadReport = timetableReport
                self.timetableFailure = timetableFailure
                self.busy = false
                self.lastOperationUsedPipeline = usedPipeline
                self.control = nil
                if self.cancellationRequested {
                    self.fileRefreshQueue.discardPending()
                    self.fileMonitor.discardPendingRefreshes()
                }
                self.cancellationRequested = false
                self.updateFileMonitoring(retryFailedFor: control.acquiredProviderSources)
                defer { self.runPendingSelection(); self.runPendingFileRefresh() }
                switch result {
                case .success:
                    self.message = success
                    if !preserveChangePreview || preview != nil || dismissChangePreviewOnSuccess { self.changePreview = preview }
                case .failure(let error):
                    self.lastOperationWasCancelled = FileOperationOutcome.isCancellation(error)
                    self.failed = !self.lastOperationWasCancelled
                    self.message = self.lastOperationWasCancelled ? MaterialError.cancelled.localizedDescription :
                        (error as? ChangeParseError)?.localizedDescription
                        ?? (error as? PDFParseError)?.localizedDescription
                        ?? (error as? FilePipeline.Failure)?.localizedDescription
                        ?? ((error as? MaterialError) ?? .unavailable).localizedDescription
                }
                if case .success = result { completion?(true) } else { completion?(false) }
            }
        }
    }
}


extension MaterialsModel {
    func recoverySource() async -> RecoverySelectedSource? {
        guard ready, !busy, !retired, let period = ApplicationData.shared.loadedPeriod else { return nil }
        let capturedSource = RecoverySourceCapture()
        return await withCheckedContinuation { continuation in
            perform(success:nil,completion:{ success in continuation.resume(returning:success ? capturedSource.source : nil) }) { worker,control in
                guard let library = worker.library, let source = library.state.record(for:.timetable),
                      let attempt = library.state.pdfParseAttempts?[MaterialKind.timetable.rawValue],
                      RecoveryPolicy.mayRecover(digest:source.digest,kind:.timetable,parserVersion:PDFAnalysis.currentVersion(for:.timetable),
                        attemptDigest:attempt.sourceDigest,attemptVersion:attempt.parserVersion,failure:attempt.failure,job:attempt.recoveryJob),
                      let url = library.localURL(for:.timetable) else { throw PDFParseError(code:.unsupported) }
                let selected = RecoverySelectedSource(kind:.timetable,url:url,digest:source.digest,originalName:source.originalName,storedName:source.storedName,period:period,captured:worker.recoveryCapturedStoredName == source.storedName ? worker.recoveryCapture?.pages ?? [] : [])
                try control.check()
                capturedSource.source = selected
            }
        }
    }
    func adoptRecovery(_ preview: RecoveryPreview) async -> RecoveryAdoptionResult {
        guard LocalAIFeaturePolicy.enabled else { return .invalidated }
        let ticket = LocalAIFeaturePolicy.capture()
        let cancelled = AcquisitionControl()
        let save = RecoverySaveAttempt()
        return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            perform(success:"復旧結果を採用しました。",completion:{ continuation.resume(returning:save.result(saved:$0)) }) { worker,control in
                guard let library = worker.library, let selected = library.state.record(for:.timetable),
                      selected.storedName == preview.source.storedName, selected.digest == preview.source.digest,
                      let attempt = library.state.pdfParseAttempts?[MaterialKind.timetable.rawValue],
                      attempt.sourceDigest == selected.digest, attempt.parserVersion == PDFAnalysis.currentVersion(for:.timetable),
                      attempt.failure.map(RecoveryPolicy.eligible) == true,
                      attempt.recoveryJob?.pdfHash == selected.digest,
                      preview.document.pdfHash == selected.digest else { throw PDFParseError(code:.storage) }
                try RecoveryConversion.verifyFile(preview.source,check:{ try cancelled.check(); try control.check() })
                let analysis = try RecoveryConversion.timetable(preview)
                guard preview.source.period == SchoolDataPeriod.current() else { throw PDFParseError(code:.cancelled) }
                try cancelled.check(); try control.check(); try LocalAIFeaturePolicy.check(ticket)
                try save.persist {
                    try worker.saveRecoveredTimetable(analysis, in: library)
                    FilePipeline.shared.clearTerminalStatus(.timetable)
                }
            }
        }
        } onCancel: { cancelled.cancel() }
    }
}
