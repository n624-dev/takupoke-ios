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
    @Published private(set) var status = ""
    @Published var preview: RecoveryPreview?
    @Published private(set) var failure: String?
    @Published private(set) var awaitingModel = false
    @Published private(set) var manualDraft: RecoveryManualDraft?
    @Published private(set) var manualImages = [String:UIImage]()
    @Published private(set) var manualContextImages = [String:RecoveryManualImage]()
    @Published private(set) var manualReview: RecoveryManualReview?
    var manualSourceURL: URL? { manualDraft == nil ? nil : source?.url }
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
                    var nativeCapture: RecoveryOCRAcquisitionDraft?
                    if needsOCR {
                        let acquisition = try await PDFRecoveryRecognition.acquire(source.url,only:pages.isEmpty ? nil : missing,expectedPDFHash:source.digest,check:{ try preparationControl.check(); try Task.checkCancellation() })
                        nativeCapture = acquisition.acquisition
                        let recognized = try acquisition.capturedLayouts(check:{ try preparationControl.check(); try Task.checkCancellation() })
                        for p in recognized { layouts[p.page] = p.layout; ocrPages.insert(p.page); rasters[p.page] = p.raster }
                    }
                    guard !layouts.isEmpty, layouts.count == layouts.keys.max(), layouts.keys.sorted() == Array(1...layouts.count) else { throw PDFParseError(code:.ambiguous) }
                    return RecoveryPreparedPages(pages:layouts.keys.sorted().compactMap { layouts[$0] },fromOCR:ocrPages,rasters:rasters,nativeCapture:nativeCapture)
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
            if let doc = pendingDocument { await run(doc,source:source,operation:operation,control:control) }
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
            var doc:RecoveryDocument
            switch attempt {
            case .document(let value): doc = value
            case .structure(let input):
                if let capture = prepared.nativeCapture, try !capture.assess().directLayoutsAllowed { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                let inputErrors = try await Task.detached(priority:.userInitiated) {
                    try RecoveryValidator.inputErrors(input.document,unresolvedCellIds:Set(input.requests.map(\.ownerCellId)),check:{ try control.check(); try Task.checkCancellation() })
                }.value
                try check(operation)
                guard RecoveryConversion.matchesPeriod(input.document,source.period), inputErrors.isEmpty else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) }
                status = "折り返された見出しの構造を端末内で確認しています⋯"
                let providers:[any LocalRecoveryProvider] = [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation))
                try check(operation)
                let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
                let worker = Task.detached(priority:.userInitiated) {
                    try await RecoveryStructure.resolve(input,providers:providers,os:"ios",osMajor:major,check:{ try control.check(); try Task.checkCancellation() })
                }
                let proposed = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
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
            doc = try RecoveryManualAssistance.attaching(prepared.nativeCapture,to:doc,check:{ try control.check(); try Task.checkCancellation() })
            let completedDocument = doc
            try check(operation)
            let inputErrors = try await Task.detached(priority:.userInitiated) {
                try RecoveryValidator.inputErrors(completedDocument,check:{ try control.check(); try Task.checkCancellation() })
            }.value
            try check(operation)
            guard RecoveryConversion.matchesPeriod(doc,source.period), inputErrors.isEmpty else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
            let draft = try await Task.detached(priority:.userInitiated) {
                try RecoveryManualAssistance.prepare(completedDocument,os:"ios",check:{ try control.check(); try Task.checkCancellation() })
            }.value
            try check(operation)
            if let draft {
                var images = [String:UIImage]()
                for field in draft.fields {
                    guard let raster = prepared.rasters[field.page], let image = Self.crop(field.crop,raster:raster) else { throw PDFParseError(code:.unreadable,stage:.rasterInput) }
                    images[field.id] = image
                }
                manualContextImages = try Self.contextImages(draft,rasters:prepared.rasters)
                manualDraft = draft; manualImages = images; running = false
                pendingDocument = nil; pendingPages = nil
                status = "原本と照合して、確認が必要な\(draft.fields.count)項目を入力してください。"
                return
            }
            pendingDocument = doc; pendingPages = nil
            await run(doc,source:source,operation:operation,control:control)
        } catch {
            guard self.operation == operation else { return }
            running = false; failure = "資料の内容と位置を安全に確認できませんでした。前回の正常結果を保持しています。"
        }
    }
    func submitManual(_ values: [String:String], acknowledged:Set<String>) {
        guard !running, manualReview == nil, let draft = manualDraft, let source,
              acknowledged == Set(draft.fields.map(\.id)) else { return }
        running = true; failure = nil; status = "原本と入力内容を確認しています⋯"
        let operation = self.operation, control = AcquisitionControl(); preparationControl = control
        let app = ApplicationData.shared
        let previousTimetable = app.materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue]
        let previousSpecial = app.specialSchedules.records[source.kind == .exam ? .exam : .examReturn]?.analysis
        task = Task { @MainActor in
            do {
                try check(operation)
                let result = try await Task.detached(priority:.userInitiated) {
                    try RecoveryConversion.verifyFile(source,check:{ try control.check(); try Task.checkCancellation() })
                    return try RecoveryManualAssistance.complete(draft,values:values,check:{ try control.check(); try Task.checkCancellation() })
                }.value
                try check(operation)
                guard manualDraft?.id == draft.id else { throw CancellationError() }
                let candidate = RecoveryPreview(document:draft.document,result:result,source:source)
                let comparison = try await Task.detached(priority:.userInitiated) {
                    try Self.comparison(candidate,previousTimetable:previousTimetable,previousSpecial:previousSpecial,check:{ try control.check(); try Task.checkCancellation() })
                }.value
                try check(operation)
                guard manualDraft?.id == draft.id else { throw CancellationError() }
                manualReview = RecoveryManualReview(draftID:draft.id,candidate:candidate,comparison:comparison,previousDate:source.kind == .timetable ? previousTimetable?.parsedAt : previousSpecial?.parsedAt)
                running = false
                status = "訂正箇所と前回からの変更を先に確認してください。"
            } catch {
                guard self.operation == operation else { return }
                manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; self.source = nil
                running = false; failure = "原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"
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
        running = true; failure = nil
        let operation = self.operation, control = AcquisitionControl(); preparationControl = control
        task = Task { @MainActor in
            do {
                try check(operation)
                try await Task.detached(priority:.userInitiated) {
                    try RecoveryConversion.verifyFile(review.candidate.source,check:{ try control.check(); try Task.checkCancellation() })
                }.value
                try check(operation)
                guard manualReview?.id == review.id, manualDraft?.id == draft.id else { throw CancellationError() }
                preview = review.candidate
                manualReview = nil; manualDraft = nil; manualImages = [:]; manualContextImages = [:]; running = false
                status = "採用前に元のPDFと資料全体の内容を確認してください。"
            } catch {
                guard self.operation == operation else { return }
                cancel()
                failure = "原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"
            }
        }
    }
    func suspendForInactivity() {
        guard manualDraft != nil else { cancel(); return }
        task?.cancel(); preparationControl?.cancel(); preparationControl = nil
        operation = UUID(); running = false
        status = "原本と照合して、確認が必要な項目を入力してください。"
    }
    func invalidateManualIfSourceChanged() {
        guard manualDraft != nil, !selectedSourceIsCurrent else { return }
        cancel()
        failure = "資料の選択や保存状態が変わりました。元のPDFから再試行してください。前回の正常結果を保持しています。"
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
    nonisolated private static func snapshot(_ doc:RecoveryDocument,_ result:RecoveryResult) -> RecoveryManualComparison.Snapshot {
        typealias C = RecoveryManualComparison
        let slots=doc.requiredSlots.map { C.Slot(className:$0.className,day:$0.day,period:$0.period) }
        var entries=[C.Slot:[C.Lesson]]()
        for cell in doc.cells {
            guard let output=result.cells.first(where:{ $0.cellId == cell.id }),let start=cell.slots.map(\.period).min(),let end=cell.slots.map(\.period).max() else { continue }
            for slot in cell.slots {
                let time=doc.kind == .timetable ? nil : (start == end ? doc.times["\(slot.day):\(start)"] : doc.spanTimes["\(slot.day):\(start)-\(end)"])
                entries[C.Slot(className:slot.className,day:slot.day,period:slot.period)]=output.lessons.map { C.Lesson(subject:$0.subject.value,teacher:$0.teacher.value,room:$0.room.value,spanStart:start,spanEnd:end,time:time) }
            }
        }
        return C.Snapshot(scope:C.Scope(kind:doc.kind.rawValue,schoolYear:doc.schoolYear,term:doc.term,classes:doc.classes,days:doc.days,slots:slots),entries:entries)
    }
    nonisolated private static func comparison(_ candidate:RecoveryPreview,previousTimetable:PDFAnalysis?,previousSpecial:SpecialScheduleAnalysis?,check:() throws -> Void) throws -> RecoveryManualComparison.Result {
        typealias C = RecoveryManualComparison
        try check()
        let current=snapshot(candidate.document,candidate.result)
        var previous:C.Snapshot?
        if candidate.document.kind == .timetable, let old=previousTimetable,old.kind == .timetable {
            if old.recovery != nil {
                if let certified=try RecoveryValidator.recertifiedTimetable(old,hash:old.sourceDigest),let adopted=certified.recovery { previous=snapshot(adopted.document,adopted.result) }
            } else if old.version == PDFAnalysis.parserVersion,MaterialLibrary.validPDFAnalysis(old) {
                var entries=[C.Slot:[C.Lesson]]()
                for lesson in old.lessons {
                    try check()
                    let slot=C.Slot(className:lesson.className,day:String(lesson.weekday),period:lesson.period)
                    entries[slot,default:[]].append(C.Lesson(subject:lesson.names.subject,teacher:lesson.names.teacher,room:lesson.names.room,spanStart:lesson.period,spanEnd:lesson.period,time:nil))
                }
                // Strict storage does not enumerate blank cells. Compare only
                // when every required slot is actually represented, never fill gaps.
                previous=C.Snapshot(scope:C.Scope(kind:RecoveryDocumentKind.timetable.rawValue,schoolYear:old.schoolYear,term:old.term,classes:Array(Set(entries.keys.map(\.className))),days:Array(Set(entries.keys.map(\.day))),slots:Array(entries.keys)),entries:entries)
            }
        } else if let old=previousSpecial,(old.kind == .exam ? RecoveryDocumentKind.exam : .return) == candidate.document.kind {
            if old.recovery != nil {
                if let certified=try RecoveryConversion.recertifiedSpecial(old,hash:old.sourceDigest),let adopted=certified.recovery { previous=snapshot(adopted.document,adopted.result) }
            } else if old.version == SpecialScheduleAnalysis.parserVersion {
                var entries=[C.Slot:[C.Lesson]]()
                for lesson in old.lessons {
                    try check()
                    let slot=C.Slot(className:lesson.className,day:lesson.date,period:lesson.period)
                    entries[slot,default:[]].append(C.Lesson(subject:lesson.subject,teacher:lesson.teacher,room:lesson.room,spanStart:lesson.spanStart,spanEnd:lesson.spanEnd,time:old.timeRange(for:lesson)))
                }
                previous=C.Snapshot(scope:C.Scope(kind:(old.kind == .exam ? RecoveryDocumentKind.exam : .return).rawValue,schoolYear:old.schoolYear,term:nil,classes:old.coveredClasses,days:old.coveredDates,slots:Array(entries.keys)),entries:entries)
            }
        }
        try check()
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
    private func modelStatus(_ errors:[String]) {
        if errors.contains("notReady") { status = "OSのAIモデルが準備中です。準備が完了してから再試行してください。" }
        else if errors.contains("disabled") { status = "端末の設定でApple Intelligenceを有効にしてから再確認してください。" }
        else { status = "この端末では追加のローカルAIモデルが必要です。" }
    }
    private func run(_ doc: RecoveryDocument, source: RecoverySelectedSource, operation: UUID, control:AcquisitionControl) async {
        defer { LocalRecoveryModelManager.shared.release(lease:operation) }
        do {
            try check(operation); status = "端末内で読み取り、原文を検証しています⋯"
            let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            let providers: [any LocalRecoveryProvider] = [SystemLanguageRecoveryProvider()] + (await LocalRecoveryModelManager.shared.providers(lease:operation))
            try check(operation)
            let worker = Task.detached(priority:.userInitiated) {
                try await RecoveryEngine.run(doc,os:"ios",osMajor:major,foreground:true,providers:providers,rule:{ _ in nil },check:{ try control.check(); try Task.checkCancellation() })
            }
            let result = try await withTaskCancellationHandler(operation:{ try await worker.value },onCancel:{ worker.cancel() })
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
                else { self.preview = nil; source = nil; failure = "資料の選択や保存状態が変わったため採用できませんでした。元のPDFから再試行してください。" }
            } catch { guard self.operation == operation else { return }; running = false; failure = "採用を中止しました。" }
        }
    }
    func cancel() {
        task?.cancel(); preparationControl?.cancel(); preparationControl = nil; operation = UUID(); running = false
        preview = nil; manualDraft = nil; manualImages = [:]; manualContextImages = [:]; manualReview = nil; pendingDocument = nil; pendingPages = nil; source = nil; awaitingModel = false
        status = "復旧を開始してください。"; failure = nil
    }
    private func check(_ operation: UUID) throws {
        try Task.checkCancellation()
        guard self.operation == operation, UIApplication.shared.applicationState == .active,
              UIApplication.shared.isProtectedDataAvailable,
              selectedSourceIsCurrent else { throw CancellationError() }
    }
}
