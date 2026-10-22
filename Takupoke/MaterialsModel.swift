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
    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.materials", qos: .userInitiated)
    private var retired = false
    private var generation = UUID()
    private var control: AcquisitionControl?
    private var backgroundRefreshID: UUID?
    private var pendingSelections = PendingFileSelections<MaterialKind, ScopedMaterialSelection>()
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
        guard !retired else { return }
        pendingSelections.append(url, kind: kind)
        runPendingSelection()
    }

    private func runPendingSelection() {
        guard !retired, let selected = pendingSelections.take(busy: busy) else { return }
        let (kind, url) = selected
        guard acceptsChangeYear(kind) else { return }
        let year = automaticChangeSchoolYear
        perform(success: "\(kind.title)を取得して解析しました。") { worker, control in
            try worker.selectFile(url, kind: kind, control: control)
            try Self.analyzeAfterAcquisition(kind, year: year, worker: worker, control: control)
        }
    }

    func refresh(_ kind: MaterialKind) {
        guard acceptsChangeYear(kind) else { return }
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
            try $0.analyzeChanges(defaultYear: year, control: $1)
        }
    }

    func analyzePDF(_ kind: MaterialKind) {
        perform(success: "\(kind.title)を解析しました。") {
            try $0.analyzePDF(kind: kind, control: $1)
        }
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
        perform(success: "日付から求めた曜日で読み込みました。ファイルの内容が更新されるまで適用します。", preserveChangePreview: true, dismissChangePreviewOnSuccess: true, changeYear: year) {
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
        perform(success: "選んだ\(rows.count)行を除外して読み込みました。ファイルの内容が更新されるまで適用します。", preserveChangePreview: true, dismissChangePreviewOnSuccess: true, changeYear: year) {
            try $0.skipChangeRows(preview, rows: rows, defaultYear: year, control: $1, correctWeekdays: correctWeekdays)
        }
        return nil
    }

    func closeForRetention() async {
        retired = true
        generation = UUID()
        setFileMonitoring(false)
        cancel()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.worker.close()
                DispatchQueue.main.async { continuation.resume() }
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
        pendingSelections.clear()
        control?.cancel()
        message = busy ? "中止を要求しました。処理の終了を待っています。" : "自動確認を中止しました。"
    }

    func refreshInBackground() async -> Bool {
        guard !busy, !retired, !Task.isCancelled else { return false }
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
                    try Self.refreshSelectedFiles(worker, requested: requested, year: year, control: control)
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
        failed = false
        message = nil
        changeFailureContext = changeYear.flatMap { year in
            state.record(for: .changes).map { (identity: $0.source.selectionID ?? $0.storedName, digest: $0.digest, year: year) }
        }
        if !preserveChangePreview { changePreview = nil }
        let worker = self.worker
        let operationGeneration = generation
        let control = AcquisitionControl()
        self.control = control
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
            DispatchQueue.main.async {
                guard !self.retired, operationGeneration == self.generation else { completion?(false); return }
                self.ready = snapshot != nil
                if let snapshot = snapshot { self.state = snapshot }
                self.rejectedRecoveryKinds = display?.rejected ?? []
                self.pdfURLs = pdfURLs
                self.timetableReadReport = timetableReport
                self.timetableFailure = timetableFailure
                self.busy = false
                self.control = nil
                let succeeded: Bool
                if case .success = result { succeeded = true } else { succeeded = false }
                self.updateFileMonitoring(retryFailed: succeeded)
                defer { self.runPendingSelection(); self.runPendingFileRefresh() }
                switch result {
                case .success:
                    self.message = success
                    if !preserveChangePreview || preview != nil || dismissChangePreviewOnSuccess { self.changePreview = preview }
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? ChangeParseError)?.localizedDescription
                        ?? (error as? PDFParseError)?.localizedDescription
                        ?? ((error as? MaterialError) ?? .unavailable).localizedDescription
                }
                completion?(!self.failed)
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
    func adoptRecovery(_ preview: RecoveryPreview) async -> Bool {
        guard LocalAIFeaturePolicy.enabled else { return false }
        let ticket = LocalAIFeaturePolicy.capture()
        let cancelled = AcquisitionControl()
        return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            perform(success:"復旧結果を採用しました。",completion:{ continuation.resume(returning:$0) }) { worker,control in
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
                try cancelled.check(); try control.check(); try LocalAIFeaturePolicy.check(ticket); try library.savePDFAnalysis(analysis)
            }
        }
        } onCancel: { cancelled.cancel() }
    }
}
