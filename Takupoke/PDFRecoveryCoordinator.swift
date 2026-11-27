import Foundation
import SwiftUI
import UIKit

struct RecoveryManualImage {
    let image: UIImage
    let highlight: RecoveryManualImageGeometry.Bounds
}
struct RecoveryManualReview: Identifiable {
    let draftID: String
    let candidate: RecoveryPreview
    let comparison: RecoveryManualComparison.Result
    let previousDate: Date?
    var id: UUID { candidate.id }
}

@MainActor
final class PDFRecoveryCoordinator: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var previewNeedsRevalidation = false
    @Published private(set) var status = ""
    @Published var preview: RecoveryPreview? {
        didSet {
            manualCorrectionTargets = preview.map { RecoveryManualAssistance.selectableTargets($0.document,$0.result) } ?? []
        }
    }
    @Published private(set) var manualCorrectionTargets = Set<RecoveryManualTarget>()
    @Published private(set) var failureReason: RecoveryFailure?
    var failure: String? { failureReason?.message }
    @Published private(set) var modelAction: RecoveryModelAction?
    var awaitingModel: Bool { modelAction != nil }
    @Published private(set) var manualDraft: RecoveryManualDraft?
    @Published private(set) var manualImages = [String:UIImage]()
    @Published private(set) var manualContextImages = [String:RecoveryManualImage]()
    @Published private(set) var manualInitialValues = [String:String]()
    @Published private(set) var manualReview: RecoveryManualReview?
    var manualSourceURL: URL? { manualDraft == nil ? nil : source?.url }
    private var task: Task<Void,Never>?
    private var preparationControl: AcquisitionControl?
    private var operation = UUID()
    private var source: RecoverySelectedSource?
    private var pendingDocument: RecoveryDocument?
    private var aiTicket = LocalAIFeaturePolicy.capture()
    private var permissionObserver: NSObjectProtocol?
    init() {
        permissionObserver = NotificationCenter.default.addObserver(forName: LocalAIFeaturePolicy.changed, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.cancel()
                if !LocalAIFeaturePolicy.enabled { self.status = "復旧はOFFです。" }
            }
        }
    }
    deinit { if let permissionObserver { NotificationCenter.default.removeObserver(permissionObserver) } }
    private var pendingPages: RecoveryPreparedPages?
    private var previewRasters = [Int:RecoveryRasterGrid]()

    func start(_ kind: RecoveryDocumentKind) {
        guard !running else { return }
        guard LocalAIFeaturePolicy.enabled else { cancel(); status = "復旧はOFFです。"; return }
        let previous = task
        cancel(); failureReason = nil; preview = nil
        let operation = UUID(); self.operation = operation; aiTicket = LocalAIFeaturePolicy.capture()
        let ticket = aiTicket
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
                    self.failureReason = .sourceNeedsAnalysis
                    return
                }
                self.source = source
                try self.check(operation)
                let preparationWorker = Task.detached(priority:.userInitiated) { () throws -> RecoveryPreparedPages in
                    try RecoveryConversion.verifyFile(source,check:{ try preparationControl.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                    let capture = RecoveryReadCapture()
                    var pages = source.captured
                    if pages.isEmpty {
                        do {
                            if kind == .timetable { _ = try PDFKitReader.readCertified(source.url,kind:.timetable,capture:capture,check:{ try preparationControl.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) }) }
                            else { _ = try PDFKitReader.readCertifiedSpecial(source.url,capture:capture,check:{ try preparationControl.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) }) }
                        } catch let error as PDFParseError where [.cancelled, .limit, .unreadable].contains(error.code) {
                            // Invalid documents/pages and exhausted limits cannot
                            // fall through into OCR after a legacy unreadable error.
                            throw error
                        }
                        catch { /* The capture explicitly records incomplete pages. */ }
                        pages = capture.pages
                    }
                    let missing = Set(pages.filter { $0.state != .complete || $0.layout == nil }.map(\.page))
                    var layouts = Dictionary(uniqueKeysWithValues:pages.compactMap { p in p.state == .complete ? p.layout.map { (p.page,$0) } : nil })
                    let needsOCR = pages.isEmpty || !missing.isEmpty
                    var ocrPages = Set<Int>(), rasters = [Int:RecoveryRasterGrid]()
                    var nativeCapture: RecoveryOCRAcquisitionDraft?
                    if needsOCR {
                        let acquisition = try await PDFRecoveryRecognition.acquire(source.url,only:pages.isEmpty ? nil : missing,expectedPDFHash:source.digest,check:{ try preparationControl.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                        nativeCapture = acquisition.acquisition
                        let recognized = try acquisition.capturedLayouts(check:{ try preparationControl.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                        for p in recognized { layouts[p.page] = p.layout; ocrPages.insert(p.page); rasters[p.page] = p.raster }
                    }
                    guard !layouts.isEmpty, layouts.count == layouts.keys.max(), layouts.keys.sorted() == Array(1...layouts.count) else { throw PDFParseError(code:.ambiguous) }
                    return RecoveryPreparedPages(pages:layouts.keys.sorted().compactMap { layouts[$0] },fromOCR:ocrPages,rasters:rasters,nativeCapture:nativeCapture)
                }
                let prepared = try await CancellationLinkedTask.value(of: preparationWorker)
                try self.check(operation)
                self.pendingPages = prepared
                await self.buildAndRun(prepared,source:source,operation:operation,control:preparationControl)
            } catch {
                guard self.operation == operation else { return }
                self.running = false
                self.failureReason = RecoveryFailure(error)
            }
        }
    }
    func retryModel() {
        guard LocalAIFeaturePolicy.enabled, modelAction != .unavailable, !running, let source,
              pendingDocument != nil || pendingPages != nil else { return }
        running = true; modelAction = nil; failureReason = nil
        let operation = self.operation
        let control = AcquisitionControl(); preparationControl = control
        task = Task {
            if let doc = pendingDocument { await run(doc,source:source,operation:operation,control:control) }
            else if let pages = pendingPages { await buildAndRun(pages,source:source,operation:operation,control:control) }
        }
    }
    private func buildAndRun(_ prepared: RecoveryPreparedPages,source:RecoverySelectedSource,operation:UUID,control:AcquisitionControl) async {
        defer { LocalRecoveryModelManager.shared.release(lease:operation) }
        if prepared.nativeCapture != nil { previewRasters = prepared.rasters }
        let ticket = aiTicket
        do {
            try check(operation)
            let attempt = try await Task.detached(priority:.userInitiated) { () throws -> RecoveryBuildAttempt in
                do { return .document(try RecoveryDocumentBuilder.build(prepared.pages,kind:source.kind,hash:source.digest,fromOCR:prepared.fromOCR,rasters:prepared.rasters,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })) }
                catch let input as RecoveryStructurePreparation { return .structure(input) }
            }.value
            try check(operation)
            var doc:RecoveryDocument
            switch attempt {
            case .document(let value): doc = value
            case .structure(let input):
                if let capture = prepared.nativeCapture, try !capture.assess().directLayoutsAllowed { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                let inputErrors = try await Task.detached(priority:.userInitiated) {
                    try RecoveryValidator.inputErrors(input.document,unresolvedCellIds:Set(input.requests.map(\.ownerCellId)),check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }.value
                try check(operation)
                guard RecoveryConversion.matchesPeriod(input.document,source.period) else { throw RecoveryFailure.differentPeriod }
                guard inputErrors.isEmpty else { throw RecoveryFailure(validationCodes: inputErrors, providerResult: false) }
                status = "折り返された見出しの構造を端末内で確認しています⋯"
                guard LocalAIFeaturePolicy.enabled else {
                    running = false; failureReason = .settingsDisabled; return
                }
                let providers:[any LocalRecoveryProvider] = [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation))
                try check(operation)
                let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
                let worker = Task.detached(priority:.userInitiated) {
                    try await RecoveryStructure.resolve(input,providers:providers,os:"ios",osMajor:major,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }
                let proposed = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
                try check(operation)
                guard let proposals = proposed.proposals,let metadata = proposed.metadata else {
                    running = false
                    if proposed.state == .awaitingModel { modelStatus(proposed.errors) }
                    else { failureReason = RecoveryFailure(validationCodes: proposed.errors, providerResult: true) }
                    return
                }
                var rebuilt = try await Task.detached(priority:.userInitiated) {
                    try RecoveryDocumentBuilder.build(prepared.pages,kind:source.kind,hash:source.digest,fromOCR:prepared.fromOCR,rasters:prepared.rasters,structureProposals:proposals,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }.value
                rebuilt.structureMetadata = metadata
                doc = rebuilt
            }
            doc = try RecoveryManualAssistance.attaching(prepared.nativeCapture,to:doc,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
            let completedDocument = doc
            try check(operation)
            let inputErrors = try await Task.detached(priority:.userInitiated) {
                try RecoveryValidator.inputErrors(completedDocument,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
            }.value
            try check(operation)
            guard RecoveryConversion.matchesPeriod(doc,source.period) else { throw RecoveryFailure.differentPeriod }
            guard inputErrors.isEmpty else { throw RecoveryFailure(validationCodes: inputErrors, providerResult: false) }
            let draft = try await Task.detached(priority:.userInitiated) {
                try RecoveryManualAssistance.prepare(completedDocument,os:"ios",check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
            }.value
            try check(operation)
            if let draft {
                var images = [String:UIImage]()
                for field in draft.fields {
                    guard let raster = prepared.rasters[field.page], let image = Self.crop(field.crop,raster:raster) else { throw PDFParseError(code:.unreadable,stage:.rasterInput) }
                    images[field.id] = image
                }
                manualContextImages = try Self.contextImages(draft,rasters:prepared.rasters)
                manualInitialValues = [:]
                manualDraft = draft; manualImages = images; running = false
                pendingDocument = nil; pendingPages = nil
                status = "原本と照合して、確認が必要な\(draft.fields.count)項目を入力してください。"
                return
            }
            pendingDocument = doc; pendingPages = nil
            await run(doc,source:source,operation:operation,control:control)
        } catch {
            guard self.operation == operation else { return }
            running = false; failureReason = RecoveryFailure(error)
        }
    }
    func submitManual(_ values: [String:String], acknowledged:Set<String>) {
        guard !running, manualReview == nil, let draft = manualDraft, let source,
              acknowledged == Set(draft.fields.map(\.id)) else { return }
        running = true; failureReason = nil; status = "原本と入力内容を確認しています⋯"
        let operation = self.operation, control = AcquisitionControl(); preparationControl = control
        let ticket = aiTicket
        let app = ApplicationData.shared
        let previousTimetable = app.materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue]
        let previousSpecial = app.specialSchedules.records[source.kind == .exam ? .exam : .examReturn]?.analysis
        task = Task { @MainActor in
            do {
                try check(operation)
                let result = try await Task.detached(priority:.userInitiated) {
                    try RecoveryConversion.verifyFile(source,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                    return try RecoveryManualAssistance.complete(draft,values:values,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }.value
                try check(operation)
                guard manualDraft?.id == draft.id else { throw CancellationError() }
                let candidate = RecoveryPreview(document:draft.document,result:result,source:source)
                let comparison = try await Task.detached(priority:.userInitiated) {
                    try Self.comparison(candidate,previousTimetable:previousTimetable,previousSpecial:previousSpecial,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }.value
                try check(operation)
                guard manualDraft?.id == draft.id else { throw CancellationError() }
                manualReview = RecoveryManualReview(draftID:draft.id,candidate:candidate,comparison:comparison,previousDate:source.kind == .timetable ? previousTimetable?.parsedAt : previousSpecial?.parsedAt)
                running = false
                status = "訂正箇所と前回からの変更を先に確認してください。"
            } catch {
                guard self.operation == operation else { return }
                manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; self.source = nil
                previewRasters = [:]; manualInitialValues = [:]
                running = false; failureReason = .manualInputUnverified
            }
        }
    }
    /// Explicit OCR-body selection from an already validated preview only.
    /// The default parser, its failure eligibility and OCR acquisition are untouched.
    func selectManualCorrection(_ target:RecoveryManualTarget) {
        guard LocalAIFeaturePolicy.enabled, !running, !previewNeedsRevalidation, let candidate = preview,
              manualCorrectionTargets.contains(target), source != nil else { return }
        let selected = Set((candidate.result.humanCorrections ?? []).map(\.target)).union([target])
        guard selected.count <= RecoveryManualAssistance.maximumFields else {
            failureReason = nil; status = "訂正できる本文は、確認が必要な項目を含め合計3項目までです。"; return
        }
        running = true; failureReason = nil; status = "原本と訂正する本文を確認しています⋯"
        let operation = self.operation, ticket = aiTicket
        let control = AcquisitionControl(); preparationControl = control
        let retained = previewRasters
        task = Task { @MainActor in
            do {
                try check(operation)
                let prepared = try await Task.detached(priority:.userInitiated) {
                    let check = { try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) }
                    try RecoveryConversion.verifyFile(candidate.source,check:check)
                    guard let draft = try RecoveryManualAssistance.prepare(candidate.document,os:"ios",selected:selected,check:check) else {
                        throw PDFParseError(code:.ambiguous,stage:.rasterInput)
                    }
                    let rasters = try RecoveryManualAssistance.verifiedRasters(draft,rasters:retained,check:check)
                    return (draft,rasters)
                }.value
                try check(operation)
                guard preview?.id == candidate.id else { throw CancellationError() }
                let (draft,rasters) = prepared
                var images = [String:UIImage]()
                for field in draft.fields {
                    guard let raster = rasters[field.page], let image = Self.crop(field.crop,raster:raster) else {
                        throw PDFParseError(code:.unreadable,stage:.rasterInput)
                    }
                    images[field.id] = image
                }
                let previous = Dictionary(uniqueKeysWithValues:(candidate.result.humanCorrections ?? []).map { ($0.target.key,$0.value) })
                manualInitialValues = Dictionary(uniqueKeysWithValues:draft.fields.map { ($0.id,previous[$0.id] ?? $0.originalText) })
                manualContextImages = try Self.contextImages(draft,rasters:rasters)
                manualImages = images; manualDraft = draft; manualReview = nil; preview = nil
                pendingDocument = nil; pendingPages = nil; running = false
                status = "原本と照合して、選択した\(draft.fields.count)項目を確認してください。"
            } catch {
                guard self.operation == operation else { return }
                running = false; failureReason = .correctionTargetUnverified
            }
        }
    }
    func editManualReview() {
        guard !running, manualDraft != nil else { return }
        manualReview = nil
        status = "原本と入力内容を照合してください。"
    }
    func showManualPreview() {
        guard !running, let review = manualReview, let draft = manualDraft,
              draft.id == review.draftID else { return }
        running = true; failureReason = nil
        let operation = self.operation, control = AcquisitionControl(); preparationControl = control
        let ticket = aiTicket
        task = Task { @MainActor in
            do {
                try check(operation)
                try await Task.detached(priority:.userInitiated) {
                    try RecoveryConversion.verifyFile(review.candidate.source,check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
                }.value
                try check(operation)
                guard manualReview?.id == review.id, manualDraft?.id == draft.id else { throw CancellationError() }
                preview = review.candidate
                manualInitialValues = [:]
                manualReview = nil; manualDraft = nil; manualImages = [:]; manualContextImages = [:]; running = false
                status = "採用前に元のPDFと資料全体の内容を確認してください。"
            } catch {
                guard self.operation == operation else { return }
                cancel()
                failureReason = .manualInputUnverified
            }
        }
    }
    private var hasManualWork: Bool {
        manualDraft != nil || preview?.result.humanCorrections?.isEmpty == false
    }

    func suspendForInactivity() {
        guard hasManualWork else { cancel(); return }
        task?.cancel(); preparationControl?.cancel(); preparationControl = nil
        operation = UUID(); previewNeedsRevalidation = preview != nil; running = false
        if preview != nil {
            status = "採用前に元のPDFと資料全体の内容を確認してください。"
        } else if manualReview != nil {
            status = "訂正箇所と前回からの変更を先に確認してください。"
        } else {
            status = "原本と照合して、確認が必要な項目を入力してください。"
        }
    }

    func resumeAfterInactivity() {
        invalidateManualIfSourceChanged()
        guard previewNeedsRevalidation, hasManualWork, let candidate = preview, !running else { return }
        let operation = UUID()
        self.operation = operation
        let control = AcquisitionControl()
        preparationControl = control
        let ticket = aiTicket
        running = true
        status = "元のPDFを再確認しています⋯"
        task = Task { @MainActor in
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try RecoveryConversion.verifyFile(candidate.source, check: {
                        try control.check()
                        try Task.checkCancellation()
                        try LocalAIFeaturePolicy.check(ticket)
                    })
                }
                try await CancellationLinkedTask.value(of: worker)
                try check(operation)
                guard preview?.id == candidate.id else { throw CancellationError() }
                previewNeedsRevalidation = false
                running = false
                preparationControl = nil
                status = "採用前に元のPDFと資料全体の内容を確認してください。"
            } catch is CancellationError {
                guard self.operation == operation else { return }
                invalidateManualIfSourceChanged()
                if hasManualWork { suspendForInactivity() }
            } catch {
                guard self.operation == operation else { return }
                cancel()
                failureReason = .originalRevalidation
            }
        }
    }

    func invalidateManualIfSourceChanged() {
        guard hasManualWork else { return }
        guard !selectedSourceIsCurrent || (try? LocalAIFeaturePolicy.check(aiTicket)) == nil else { return }
        cancel()
        failureReason = .selectionChanged
    }
    private var selectedSourceIsCurrent:Bool {
        guard let source, source.period == ApplicationData.shared.loadedPeriod,
              source.period == SchoolDataPeriod.current() else { return false }
        if source.kind == .timetable {
            let current = ApplicationData.shared.materials.state.record(for:.timetable)
            return current?.digest == source.digest && current?.storedName == source.storedName
        }
        let current = ApplicationData.shared.specialSchedules.sources[source.kind == .exam ? .exam : .examReturn]
        return current?.digest == source.digest && current?.storedName == source.storedName
    }
    private static func contextImages(_ draft:RecoveryManualDraft,rasters:[Int:RecoveryRasterGrid]) throws -> [String:RecoveryManualImage] {
        var images = [String:RecoveryManualImage]()
        for field in draft.fields {
            guard let cell = draft.document.cells.first(where:{ $0.id == field.target.cellId }),
                  let raster = rasters[field.page], let image = crop(cell.box,raster:raster) else { throw PDFParseError(code:.unreadable,stage:.rasterInput) }
            let left=floor(cell.box.x),top=floor(cell.box.y)
            let container=RecoveryManualImageGeometry.Bounds(x:left,y:top,width:ceil(cell.box.x+cell.box.width)-left,height:ceil(cell.box.y+cell.box.height)-top)
            let target=RecoveryManualImageGeometry.Bounds(x:field.crop.x,y:field.crop.y,width:field.crop.width,height:field.crop.height)
            guard let highlight=RecoveryManualImageGeometry.normalizedHighlight(container:container,target:target) else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
            images[field.id]=RecoveryManualImage(image:image,highlight:highlight)
        }
        return images
    }
    nonisolated private static func snapshot(_ doc:RecoveryDocument,_ result:RecoveryResult,
                                            compareByTimetablePeriod: Bool = false) -> RecoveryManualComparison.Snapshot {
        typealias C = RecoveryManualComparison
        let slots=doc.requiredSlots.map { C.Slot(className:$0.className,day:$0.day,period:$0.period) }
        var entries=[C.Slot:[C.Lesson]]()
        for cell in doc.cells {
            guard let output=result.cells.first(where:{ $0.cellId == cell.id }),let start=cell.slots.map(\.period).min(),let end=cell.slots.map(\.period).max() else { continue }
            for slot in cell.slots {
                let slotStart = compareByTimetablePeriod ? slot.period : start
                let slotEnd = compareByTimetablePeriod ? slot.period : end
                let time=doc.kind == .timetable ? nil : (start == end ? doc.times["\(slot.day):\(start)"] : doc.spanTimes["\(slot.day):\(start)-\(end)"])
                entries[C.Slot(className:slot.className,day:slot.day,period:slot.period)]=output.lessons.map { C.Lesson(subject:$0.subject.value,teacher:$0.teacher.value,room:$0.room.value,spanStart:slotStart,spanEnd:slotEnd,time:time) }
            }
        }
        return C.Snapshot(scope:C.Scope(kind:doc.kind.rawValue,schoolYear:doc.schoolYear,term:doc.term,classes:doc.classes,days:doc.days,slots:slots),entries:entries)
    }
    nonisolated private static func comparison(_ candidate:RecoveryPreview,previousTimetable:PDFAnalysis?,previousSpecial:SpecialScheduleAnalysis?,check:() throws -> Void) throws -> RecoveryManualComparison.Result {
        typealias C = RecoveryManualComparison
        try check()
        var previous:C.Snapshot?
        var compareByTimetablePeriod = false
        if candidate.document.kind == .timetable, let old=previousTimetable,old.kind == .timetable {
            if old.recovery != nil {
                if let certified=try RecoveryValidator.recertifiedTimetable(old,hash:old.sourceDigest),let adopted=certified.recovery { previous=snapshot(adopted.document,adopted.result) }
            } else {
                previous = try old.strictComparisonSnapshot(check: check)
                compareByTimetablePeriod = previous != nil
            }
        } else if let old=previousSpecial,(old.kind == .exam ? RecoveryDocumentKind.exam : .return) == candidate.document.kind {
            if old.recovery != nil {
                if let certified=try RecoveryConversion.recertifiedSpecial(old,hash:old.sourceDigest),let adopted=certified.recovery { previous=snapshot(adopted.document,adopted.result) }
            } else { previous = try old.strictComparisonSnapshot(check: check) }
        }
        try check()
        let current = snapshot(candidate.document, candidate.result, compareByTimetablePeriod: compareByTimetablePeriod)
        return C.compare(current,previous:previous)
    }
    private static func crop(_ box:RecoveryBox,raster:RecoveryRasterGrid) -> UIImage? {
        guard box.valid, box.x+box.width <= Double(raster.width), box.y+box.height <= Double(raster.height) else { return nil }
        let left = Int(floor(box.x)), top = Int(floor(box.y)), right = Int(ceil(box.x+box.width)), bottom = Int(ceil(box.y+box.height))
        guard left >= 0, top >= 0, right <= raster.width, bottom <= raster.height, left < right, top < bottom else { return nil }
        var bytes = [UInt8](); bytes.reserveCapacity((right-left)*(bottom-top))
        for y in top..<bottom { bytes.append(contentsOf:raster.grayscale[(y*raster.width+left)..<(y*raster.width+right)]) }
        guard let provider = CGDataProvider(data:Data(bytes) as CFData), let image = CGImage(width:right-left,height:bottom-top,
            bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:right-left,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),
            provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent) else { return nil }
        return UIImage(cgImage:image)
    }
    var modelSourceURL: URL? { awaitingModel && selectedSourceIsCurrent ? source?.url : nil }
    var failedSourceURL: URL? { failureReason != nil && selectedSourceIsCurrent ? source?.url : nil }

    private func modelStatus(_ errors: [String]) {
        let manager = LocalRecoveryModelManager.shared
        let action = RecoveryModelAction(errors: errors,
                                         canInstall: !manager.installableCatalog.isEmpty,
                                         localStorageBusy: manager.busy)
        modelAction = action
        status = action.message
    }
    private func run(_ doc: RecoveryDocument, source: RecoverySelectedSource, operation: UUID, control:AcquisitionControl) async {
        defer { LocalRecoveryModelManager.shared.release(lease:operation) }
        let ticket = aiTicket
        do {
            try check(operation); status = "端末内で読み取り、原文を検証しています⋯"
            let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            let providers: [any LocalRecoveryProvider] = LocalAIFeaturePolicy.enabled ? [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation)) : []
            try check(operation)
            let worker = Task.detached(priority:.userInitiated) {
                try await RecoveryEngine.run(doc,os:"ios",osMajor:major,foreground:true,providers:providers,rule:{ _ in nil },check:{ try control.check(); try Task.checkCancellation(); try LocalAIFeaturePolicy.check(ticket) })
            }
            let result = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
            try check(operation)
            running = false
            if let result = result.result {
                preview = RecoveryPreview(document:doc,result:result,source:source); status = "採用前に元のPDFと内容を確認してください。"
            } else if result.state == .awaitingModel {
                if LocalAIFeaturePolicy.enabled { modelStatus(result.errors) }
                else { status = "復旧はOFFです。" }
                // A temporarily unready system model never triggers an automatic download.
            } else { failureReason = RecoveryFailure(validationCodes: result.errors, providerResult: true) }
        } catch {
            guard self.operation == operation else { return }; running = false
            failureReason = RecoveryFailure(error)
        }
    }
    func adopt() {
        guard LocalAIFeaturePolicy.enabled, !running, !previewNeedsRevalidation, let preview else { return }
        running = true; failureReason = nil; status = "確認済みの結果を保存しています⋯"
        let operation = self.operation
        task = Task { @MainActor in
            do {
                try check(operation)
                let result = preview.document.kind == .timetable ? await ApplicationData.shared.materials.adoptRecovery(preview) : await ApplicationData.shared.specialSchedules.adoptRecovery(preview)
                try check(operation); running = false
                if case .retryableFailure = result {
                    status = "確認済みの復旧結果を保存できます。"
                    failureReason = .adoptionStorageFailure
                    return
                }
                previewRasters = [:]; manualInitialValues = [:]
                self.preview = nil; source = nil
                if case .saved = result {
                    pendingDocument = nil; pendingPages = nil; status = "復旧結果を採用しました。"
                } else {
                    failureReason = .adoptionTargetChanged
                }
            } catch { guard self.operation == operation else { return }; running = false; failureReason = .adoptionCancelled }
        }
    }
    func cancel() {
        task?.cancel(); preparationControl?.cancel(); preparationControl = nil; operation = UUID(); running = false
        previewNeedsRevalidation = false
        previewRasters = [:]; manualInitialValues = [:]
        preview = nil; manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; source = nil; modelAction = nil
        status = "復旧を開始してください。"; failureReason = nil
    }
    private func check(_ operation: UUID) throws {
        try Task.checkCancellation(); try LocalAIFeaturePolicy.check(aiTicket)
        guard self.operation == operation, UIApplication.shared.applicationState == .active,
              UIApplication.shared.isProtectedDataAvailable,
              selectedSourceIsCurrent else { throw CancellationError() }
    }
}
