import Foundation
import SwiftUI
import UIKit

@MainActor
final class PDFRecoveryCoordinator: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var status = ""
    @Published var preview: RecoveryPreview?
    @Published private(set) var failure: String?
    @Published private(set) var awaitingModel = false
    private var task: Task<Void,Never>?
    private var preparationControl: AcquisitionControl?
    private var operation = UUID()
    private var source: RecoverySelectedSource?
    private var pendingDocument: RecoveryDocument?
    private var pendingPages: RecoveryPreparedPages?

    func start(_ kind: RecoveryDocumentKind) {
        guard !running else { return }
        let previous = task
        cancel(); failure = nil; preview = nil; awaitingModel = false
        let operation = UUID(); self.operation = operation
        let preparationControl = AcquisitionControl(); self.preparationControl = preparationControl
        running = true; status = "保存済みのPDFを確認しています⋯"
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            await previous?.value
            do {
                try Task.checkCancellation()
                guard self.operation == operation else { return }
                let app = ApplicationData.shared
                let source = kind == .timetable ? await app.materials.recoverySource() : await app.specialSchedules.recoverySource(kind == .exam ? .exam : .examReturn)
                try Task.checkCancellation()
                guard self.operation == operation else { return }
                guard let source else {
                    self.running = false
                    self.failure = "最新の通常解析の失敗を確認できませんでした。この画面を閉じ、資料の解析画面で再解析してから復旧を開始してください。前回の正常結果を保持しています。"
                    return
                }
                self.source = source
                try self.check(operation)
                let prepared = try await Task.detached(priority:.userInitiated) { () throws -> RecoveryPreparedPages in
                    try RecoveryConversion.verifyFile(source,check:{ try preparationControl.check(); try Task.checkCancellation() })
                    let capture = RecoveryReadCapture()
                    var pages = source.captured
                    if pages.isEmpty {
                        do {
                            if kind == .timetable { _ = try PDFKitReader.read(source.url,kind:.timetable,capture:capture,check:{ try preparationControl.check(); try Task.checkCancellation() }) }
                            else { _ = try PDFKitReader.readSpecial(source.url,capture:capture,check:{ try preparationControl.check(); try Task.checkCancellation() }) }
                        } catch let error as PDFParseError where error.code == .cancelled { throw error }
                        catch { /* The capture explicitly records incomplete pages. */ }
                        pages = capture.pages
                    }
                    let missing = Set(pages.filter { $0.state != .complete || $0.layout == nil }.map(\.page))
                    var layouts = Dictionary(uniqueKeysWithValues:pages.compactMap { p in p.state == .complete ? p.layout.map { (p.page,$0) } : nil })
                    let needsOCR = pages.isEmpty || !missing.isEmpty
                    var ocrPages = Set<Int>(), rasters = [Int:RecoveryRasterGrid]()
                    if needsOCR {
                        let recognized = try await PDFRecoveryRecognition.layouts(source.url,only:pages.isEmpty ? nil : missing,check:{ try preparationControl.check(); try Task.checkCancellation() })
                        for p in recognized { layouts[p.page] = p.layout; ocrPages.insert(p.page); rasters[p.page] = p.raster }
                    }
                    guard !layouts.isEmpty, layouts.count == layouts.keys.max(), layouts.keys.sorted() == Array(1...layouts.count) else { throw PDFParseError(code:.ambiguous) }
                    return RecoveryPreparedPages(pages:layouts.keys.sorted().compactMap { layouts[$0] },fromOCR:ocrPages,rasters:rasters)
                }.value
                try self.check(operation)
                self.pendingPages = prepared
                await self.buildAndRun(prepared,source:source,operation:operation,control:preparationControl)
            } catch {
                guard self.operation == operation else { return }
                self.running = false
                self.failure = error is CancellationError ? "復旧を中止しました。前回の正常結果を保持しています。" : "資料の内容と位置を安全に確認できませんでした。前回の正常結果を保持しています。"
            }
        }
    }
    func retryModel() {
        guard !running, let source, pendingDocument != nil || pendingPages != nil else { return }
        running = true; awaitingModel = false
        let operation = self.operation
        let control = AcquisitionControl(); preparationControl = control
        task = Task {
            if let doc = pendingDocument { await run(doc,source:source,operation:operation) }
            else if let pages = pendingPages { await buildAndRun(pages,source:source,operation:operation,control:control) }
        }
    }
    private func buildAndRun(_ prepared: RecoveryPreparedPages,source:RecoverySelectedSource,operation:UUID,control:AcquisitionControl) async {
        defer { LocalRecoveryModelManager.shared.release(lease:operation) }
        do {
            try check(operation)
            let attempt = try await Task.detached(priority:.userInitiated) { () throws -> RecoveryBuildAttempt in
                do { return .document(try RecoveryDocumentBuilder.build(prepared.pages,kind:source.kind,hash:source.digest,fromOCR:prepared.fromOCR,rasters:prepared.rasters,check:{ try control.check(); try Task.checkCancellation() })) }
                catch let input as RecoveryStructurePreparation { return .structure(input) }
            }.value
            try check(operation)
            let doc:RecoveryDocument
            switch attempt {
            case .document(let value): doc = value
            case .structure(let input):
                guard RecoveryConversion.matchesPeriod(input.document,source.period), RecoveryValidator.inputErrors(input.document,unresolvedCellIds:Set(input.requests.map(\.ownerCellId))).isEmpty else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) }
                status = "折り返された見出しの構造を端末内で確認しています⋯"
                let providers:[any LocalRecoveryProvider] = [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation))
                let proposed = try await RecoveryStructure.resolve(input,providers:providers,os:"ios",osMajor:ProcessInfo.processInfo.operatingSystemVersion.majorVersion,check:{ try self.check(operation) })
                try check(operation)
                guard let proposals = proposed.proposals,let metadata = proposed.metadata else {
                    running = false; awaitingModel = proposed.state == .awaitingModel
                    if awaitingModel { modelStatus(proposed.errors) }
                    else { failure = "資料の見出しと位置を安全に確認できませんでした。前回の正常結果を保持しています。" }
                    return
                }
                var rebuilt = try await Task.detached(priority:.userInitiated) {
                    try RecoveryDocumentBuilder.build(prepared.pages,kind:source.kind,hash:source.digest,fromOCR:prepared.fromOCR,rasters:prepared.rasters,structureProposals:proposals,check:{ try control.check(); try Task.checkCancellation() })
                }.value
                rebuilt.structureMetadata = metadata
                doc = rebuilt
            }
            try check(operation)
            guard RecoveryConversion.matchesPeriod(doc,source.period), RecoveryValidator.inputErrors(doc).isEmpty else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
            pendingDocument = doc; pendingPages = nil
            await run(doc,source:source,operation:operation)
        } catch {
            guard self.operation == operation else { return }
            running = false; failure = "資料の内容と位置を安全に確認できませんでした。前回の正常結果を保持しています。"
        }
    }
    private func modelStatus(_ errors:[String]) {
        if errors.contains("notReady") { status = "OSのAIモデルが準備中です。準備が完了してから再試行してください。" }
        else if errors.contains("disabled") { status = "端末の設定でApple Intelligenceを有効にしてから再確認してください。" }
        else { status = "この端末では追加のローカルAIモデルが必要です。" }
    }
    private func run(_ doc: RecoveryDocument, source: RecoverySelectedSource, operation: UUID) async {
        defer { LocalRecoveryModelManager.shared.release(lease:operation) }
        do {
            try check(operation); status = "端末内で読み取り、原文を検証しています⋯"
            let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            let providers: [any LocalRecoveryProvider] = [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation))
            let result = try await RecoveryEngine.run(doc,os:"ios",osMajor:major,foreground:true,providers:providers,rule:{ _ in nil },check:{ try self.check(operation) })
            try check(operation)
            running = false
            if let result = result.result {
                preview = RecoveryPreview(document:doc,result:result,source:source); status = "採用前に元のPDFと内容を確認してください。"
            } else if result.state == .awaitingModel {
                awaitingModel = true
                modelStatus(result.errors)
                // A temporarily unready system model never triggers an automatic download.
            } else { failure = "原文に基づいて結果を確認できませんでした。前回の正常結果を保持しています。" }
        } catch {
            guard self.operation == operation else { return }; running = false
            failure = "復旧を終了しました。前回の正常結果を保持しています。"
        }
    }
    func adopt() {
        guard !running, let preview else { return }
        running = true; status = "確認済みの結果を保存しています⋯"
        let operation = self.operation
        task = Task { @MainActor in
            do {
                try check(operation)
                let success = preview.document.kind == .timetable ? await ApplicationData.shared.materials.adoptRecovery(preview) : await ApplicationData.shared.specialSchedules.adoptRecovery(preview)
                try check(operation); running = false
                if success { self.preview = nil; pendingDocument = nil; pendingPages = nil; source = nil; status = "復旧結果を採用しました。" }
                else { failure = "資料の選択や保存状態が変わったため採用できませんでした。元のPDFから再試行してください。" }
            } catch { guard self.operation == operation else { return }; running = false; failure = "採用を中止しました。" }
        }
    }
    func cancel() {
        task?.cancel(); preparationControl?.cancel(); preparationControl = nil; operation = UUID(); running = false
        preview = nil; pendingDocument = nil; pendingPages = nil; source = nil; awaitingModel = false
        status = "復旧を開始してください。"; failure = nil
    }
    private func check(_ operation: UUID) throws {
        try Task.checkCancellation()
        guard self.operation == operation, UIApplication.shared.applicationState == .active,
              UIApplication.shared.isProtectedDataAvailable,
              let source, source.period == ApplicationData.shared.loadedPeriod,
              source.period == SchoolDataPeriod.current() else { throw CancellationError() }
        if source.kind == .timetable {
            let current = ApplicationData.shared.materials.state.record(for:.timetable)
            guard current?.digest == source.digest, current?.storedName == source.storedName else { throw CancellationError() }
        } else {
            let current = ApplicationData.shared.specialSchedules.sources[source.kind == .exam ? .exam : .examReturn]
            guard current?.digest == source.digest, current?.storedName == source.storedName else { throw CancellationError() }
        }
    }
}
