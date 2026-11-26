import Foundation

struct RecoveryManualTarget: Codable, Hashable, Sendable {
    let cellId: String
    let lessonIndex: Int
    let role: RecoveryRole
    var key: String { "\(cellId):\(lessonIndex):\(role.rawValue)" }
}
enum RecoveryHumanProvenance: String, Codable, Sendable { case user }
struct RecoveryHumanCorrection: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let target: RecoveryManualTarget
    let pdfHash: String
    let acquisitionHash: String
    let documentSnapshotHash: String
    let page: Int
    let parentSourceIds: [String]
    let crop: RecoveryBox
    let value: String
    let provenance: RecoveryHumanProvenance
    let confirmedAt: Date
}
struct RecoveryManualField: Identifiable, Equatable, Sendable {
    let target: RecoveryManualTarget
    let page: Int
    let parentSourceIds: [String]
    let crop: RecoveryBox
    let originalText: String
    var id: String { target.key }
}
struct RecoveryManualDraft: Identifiable, Sendable {
    let document: RecoveryDocument
    let originalResult: RecoveryResult
    let fields: [RecoveryManualField]
    let acquisitionHash: String
    let snapshotHash: String
    var id: String { snapshotHash }
}

/// UIKit may synchronize an unchanged TextField value when a List row is reused.
/// Only a byte-level transcription change revokes the user's acknowledgement.
enum RecoveryManualInput {
    static func update(_ value:String, id:String, original:String,
                       values:inout [String:String], acknowledged:inout [String:Bool]) {
        guard !value.utf8.elementsEqual((values[id] ?? original).utf8) else { return }
        values[id] = value
        acknowledged[id] = false
    }
}

/// Human transcription is a separate, bounded overlay. Native text, ranges,
/// confidence and structural evidence remain unchanged in the saved document.
enum RecoveryManualAssistance {
    static let schemaVersion = 1
    static let maximumFields = 3
    static let maximumCorrectedUTF16 = 256
    private static func fingerprint<T:Encodable>(_ value:T) throws -> String {
        #if canImport(CryptoKit) || canImport(Crypto)
        return try RecoveryValidator.fingerprint(value)
        #else
        throw PDFParseError(code:.unsupported)
        #endif
    }

    static func attaching(_ capture:RecoveryOCRAcquisitionDraft?, to original:RecoveryDocument,
                          check:@escaping () throws -> Void = {}) throws -> RecoveryDocument {
        guard let capture else { return original }
        _ = try capture.assess(check:check)
        guard capture.sourcePDFHash == original.pdfHash, original.nativeCapture == nil,
              original.sources.allSatisfy({ $0.nativeConfidence == nil }) else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
        let confidences = Dictionary(uniqueKeysWithValues:capture.pages.flatMap { page in page.lines.map { ("\(page.page):\($0.nativeOrder)",$0.candidates[0].confidence) } })
        var doc = original; doc.nativeCapture = capture
        for i in doc.sources.indices where doc.sources[i].fromOcr {
            if i % 128 == 0 { try check() }
            let source = doc.sources[i]
            guard let line = source.sourceLine, let confidence = confidences["\(source.page):\(line)"] else { throw PDFParseError(code:.ambiguous,stage:.textOrder) }
            doc.sources[i].nativeConfidence = confidence
        }
        // Atom lines must prove BODY ownership before becoming model/manual input.
        if !(doc.ocrLineAtomSourceIds ?? []).isEmpty || capture.pages.contains(where: { $0.lines.contains { $0.candidates[0].characters.contains { $0.range == nil } } }) {
            _ = try fields(doc,check:check)
        }
        return doc
    }

    private static func parents(_ cell: RecoveryCell, lesson: Int, role: RecoveryRole,
                                sources: [String: RecoverySource]) -> [String]? {
        if cell.bindingMode == .fixed {
            guard cell.lessonBindings.indices.contains(lesson) else { return nil }
            let binding = cell.lessonBindings[lesson]
            switch role { case .subject: return binding.subject; case .teacher: return binding.teacher; case .room: return binding.room }
        }
        let scopes = cell.roleScopes.filter { $0.lessonIndex == lesson && $0.role == role }
        guard scopes.count == 1 else { return nil }
        let labels = Set(cell.roleScopes.flatMap(\.labelSourceIds))
        return cell.sourceIds.filter { id in
            !labels.contains(id) && sources[id].map { scopes[0].page == $0.page && scopes[0].box.contains($0.box) } == true
        }
    }

    static func fields(_ doc: RecoveryDocument, check: @escaping () throws -> Void = {}, work suppliedWork: RecoveryValidationWork? = nil) throws -> [RecoveryManualField] {
        guard let capture = doc.nativeCapture else {
            guard (doc.ocrLineAtomSourceIds ?? []).isEmpty else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
            return []
        }
        let assessment = try capture.assess(check: check)
        guard capture.sourcePDFHash == doc.pdfHash,
              capture.documentPageCount == (doc.sources.map(\.page).max() ?? 0),
              Set(capture.requiredOCRPages) == Set(doc.sources.filter(\.fromOcr).map(\.page)),
              doc.complete, doc.cells.count <= 20000, doc.sources.count <= 100000,
              doc.cells.allSatisfy({ $0.inputState == .complete && (1...4).contains($0.parallelCount) && $0.roleScopes.count <= 12 }),
              doc.ocrCoverageProof.map({ Set($0.pages.map(\.page)) == Set(capture.requiredOCRPages) }) == true else {
            throw PDFParseError(code:.ambiguous,stage:.rasterInput)
        }
        let work = suppliedWork ?? RecoveryValidationWork(check:check)
        let index = try RecoverySourceIndex(doc.sources,work:work)
        let requiredAtoms = doc.ocrLineAtomSourceIds ?? []
        guard requiredAtoms.count <= doc.sources.count, Set(requiredAtoms).count == requiredAtoms.count else {
            throw PDFParseError(code:.ambiguous,stage:.characterMapping)
        }
        let requiredAtomIds = Set(requiredAtoms)
        var provenAtomIds = Set<String>()
        let confidences = Dictionary(uniqueKeysWithValues:capture.pages.flatMap { page in page.lines.map { ("\(page.page):\($0.nativeOrder)",$0.candidates[0].confidence) } })
        for source in doc.sources {
            guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
            if source.fromOcr {
                guard let line = source.sourceLine, let native = confidences["\(source.page):\(line)"],
                      let confidence = source.nativeConfidence, confidence.isFinite, confidence == native else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
            } else if source.nativeConfidence != nil { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
        }
        let cellsById = Dictionary(doc.cells.map { ($0.id,$0) },uniquingKeysWith:{ first,_ in first })
        var ownership = [String:RecoveryManualTarget]()
        var targets = [RecoveryManualTarget:RecoveryManualField]()
        for cell in doc.cells {
            guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
            if cell.confirmedEmpty && cell.sourceIds.isEmpty { continue }
            for lesson in 0..<cell.parallelCount { for role in RecoveryRole.allCases {
                guard let ids = parents(cell,lesson:lesson,role:role,sources:index.byId) else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                let target = RecoveryManualTarget(cellId:cell.id,lessonIndex:lesson,role:role)
                for id in ids {
                    guard work.charge(), ownership[id] == nil else { try work.finish(); throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                    ownership[id] = target
                }
            } }
        }
        let byLine = Dictionary(grouping:doc.sources.filter(\.fromOcr),by:{ "\($0.page):\($0.sourceLine ?? -1)" })
        for page in capture.pages {
            var atomOrders = Set<Int>()
            for line in page.lines {
                for source in byLine["\(page.page):\(line.nativeOrder)",default:[]] {
                    guard work.charge(), source.nativeConfidence == line.candidates[0].confidence else { try work.finish(); throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
                }
                let top1 = line.candidates[0]
                let atom = try RecoveryOCRLineMapping.requiresAtom(top1,width:page.width,height:page.height,consume:{
                    guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                })
                if atom {
                    let members = byLine["\(page.page):\(line.nativeOrder)",default:[]]
                    guard members.count == 1, let source = members.first, requiredAtomIds.contains(source.id),
                          let candidate = top1.lineRange, let native = top1.observationRange,
                          source.text.utf8.elementsEqual(top1.text.utf8),
                          [source.box.x.bitPattern,source.box.y.bitPattern,source.box.width.bitPattern,source.box.height.bitPattern] ==
                            [native.x.bitPattern,native.y.bitPattern,native.width.bitPattern,native.height.bitPattern],
                          let target = ownership[source.id], target.cellId == source.cellId,
                          let cell = cellsById[source.cellId], cell.page == page.page, cell.box.contains(source.box) else {
                        throw PDFParseError(code:.ambiguous,stage:.characterMapping)
                    }
                    let ranges = [candidate,native] + top1.characters.compactMap(\.range)
                    let scopes = cell.roleScopes.filter { $0.lessonIndex == target.lessonIndex && $0.role == target.role }
                    if cell.bindingMode == .roleProposal {
                        guard scopes.count == 1, scopes[0].page == page.page else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
                    }
                    for range in ranges {
                        guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                        let box = RecoveryBox(x:range.x,y:range.y,width:range.width,height:range.height)
                        guard cell.box.contains(box), box.x > cell.box.x, box.y > cell.box.y,
                              box.x+box.width < cell.box.x+cell.box.width, box.y+box.height < cell.box.y+cell.box.height,
                              cell.bindingMode == .fixed || scopes[0].box.contains(box) else {
                            throw PDFParseError(code:.ambiguous,stage:.characterMapping)
                        }
                        for scope in cell.roleScopes where scope.lessonIndex != target.lessonIndex || scope.role != target.role {
                            guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                            guard !(box.x <= scope.box.x+scope.box.width && scope.box.x <= box.x+box.width &&
                                box.y <= scope.box.y+scope.box.height && scope.box.y <= box.y+box.height) else {
                                throw PDFParseError(code:.ambiguous,stage:.characterMapping)
                            }
                        }
                    }
                    // Fixed three-line fields and verified role scopes remain the
                    // independent authority. A whole line cannot cover another
                    // role's ink, a label, another lesson, or a structural source.
                    for id in cell.sourceIds where id != source.id {
                        guard work.charge(), let other = index.byId[id] else { try work.finish(); throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                        if ownership[id] == target { continue }
                        for range in ranges {
                            guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                            let overlaps = range.x <= other.box.x+other.box.width && other.box.x <= range.x+range.width &&
                                range.y <= other.box.y+other.box.height && other.box.y <= range.y+range.height
                            guard !overlaps else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
                        }
                    }
                    provenAtomIds.insert(source.id)
                    atomOrders.insert(line.nativeOrder)
                }
            }
            let low = Set(assessment.lowConfidenceNativeOrders[page.page,default:[]])
            for line in page.lines where low.contains(line.nativeOrder) {
                guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                let members = byLine["\(page.page):\(line.nativeOrder)",default:[]]
                let mapped = Set(members.compactMap { ownership[$0.id] })
                guard !members.isEmpty, mapped.count == 1, members.allSatisfy({ ownership[$0.id] != nil && !$0.cellId.isEmpty }),
                      let target = mapped.first,
                      let cell = cellsById[target.cellId],
                      let ids = parents(cell,lesson:target.lessonIndex,role:target.role,sources:index.byId),
                      !ids.isEmpty, Set(members.map(\.id)).isSubset(of:Set(ids)) else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
                // Each original returned character must belong to exactly one
                // original source in this field. Overlap or clipped ranges fail.
                if !atomOrders.contains(line.nativeOrder) {
                    var assigned = [String:[String]]()
                    for character in line.candidates[0].characters {
                        guard let range = character.range else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
                        let b = RecoveryBox(x:range.x,y:range.y,width:range.width,height:range.height)
                        var owners = [RecoverySource]()
                        for source in members {
                            guard work.charge() else { try work.finish(); throw PDFParseError(code:.limit) }
                            if source.box.contains(b) { owners.append(source) }
                        }
                        guard owners.count == 1 else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
                        assigned[owners[0].id,default:[]].append(character.text)
                    }
                    guard members.allSatisfy({ assigned[$0.id]?.joined().utf8.elementsEqual($0.text.utf8) == true }) else { throw PDFParseError(code:.ambiguous,stage:.textOrder) }
                }
                let originals = ids.compactMap { index.byId[$0] }
                guard originals.count == ids.count, originals.allSatisfy({ $0.page == page.page && $0.cellId == cell.id }),
                      let originalText = index.original(ids,work:work),
                      let left = originals.map({ $0.box.x }).min(), let top = originals.map({ $0.box.y }).min(),
                      let right = originals.map({ $0.box.x+$0.box.width }).max(), let bottom = originals.map({ $0.box.y+$0.box.height }).max() else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                let crop = originals.contains(where:{ requiredAtomIds.contains($0.id) }) ? cell.box : RecoveryBox(x:left,y:top,width:right-left,height:bottom-top)
                guard cell.box.contains(crop) else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                targets[target] = RecoveryManualField(target:target,page:page.page,parentSourceIds:ids,crop:crop,originalText:originalText)
            }
        }
        try work.finish()
        guard provenAtomIds == requiredAtomIds else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
        guard targets.count <= maximumFields else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
        return targets.values.sorted { $0.id < $1.id }
    }

    static func prepare(_ document: RecoveryDocument, os: String, check:@escaping () throws -> Void = {}) throws -> RecoveryManualDraft? {
        guard let capture = document.nativeCapture else {
            guard (document.ocrLineAtomSourceIds ?? []).isEmpty else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
            return nil
        }
        _ = try capture.assess(check:check)
        let work = RecoveryValidationWork(check:check), index = try RecoverySourceIndex(document.sources,work:work)
        let cells = try document.cells.map { cell -> RecoveredCell in
            try check()
            if cell.confirmedEmpty && cell.sourceIds.isEmpty { return RecoveredCell(cellId:cell.id,state:.empty,lessons:[]) }
            guard let result = try RecoveryRules.recover(cell,index:index,work:work) else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
            return result
        }
        let result = RecoveryResult(pdfHash:document.pdfHash,kind:document.kind,schoolYear:document.schoolYear,term:document.term,cells:cells,
                                    metadata:document.structureMetadata ?? RecoveryMetadata(provider:"rule",modelId:"rules",modelVersion:"3",runtimeVersion:"3",promptVersion:"1",recoverySchemaVersion:RecoveryValidator.schemaVersion,validatorVersion:RecoveryValidator.version,osVersion:os))
        let proof = try RecoveryValidator.pendingManualBaseline(document,result,index:index,work:work)
        guard proof.errors.isEmpty else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
        let fields = proof.fields
        guard !fields.isEmpty else { return nil }
        return RecoveryManualDraft(document:document,originalResult:result,fields:fields,
                                   acquisitionHash:try fingerprint(document.nativeCapture!),snapshotHash:try fingerprint(document))
    }

    static func complete(_ draft: RecoveryManualDraft, values: [String:String], now: Date = Date(),
                         check:@escaping () throws -> Void = {}) throws -> RecoveryResult {
        try check()
        let currentFields = try fields(draft.document,check:check)
        guard values.count == draft.fields.count, Set(values.keys) == Set(draft.fields.map(\.id)),
              draft.snapshotHash == (try fingerprint(draft.document)),
              draft.fields == currentFields else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
        var result = draft.originalResult, corrections = [RecoveryHumanCorrection]()
        for field in draft.fields {
            guard let value = values[field.id], !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, value.utf16.count <= maximumCorrectedUTF16,
                  let cellIndex = result.cells.firstIndex(where:{ $0.cellId == field.target.cellId }),
                  result.cells[cellIndex].lessons.indices.contains(field.target.lessonIndex) else { throw PDFParseError(code:.ambiguous) }
            let corrected = RecoveryField(state:.present,value:value,evidence:field.parentSourceIds)
            switch field.target.role {
            case .subject: result.cells[cellIndex].lessons[field.target.lessonIndex].subject = corrected
            case .teacher: result.cells[cellIndex].lessons[field.target.lessonIndex].teacher = corrected
            case .room: result.cells[cellIndex].lessons[field.target.lessonIndex].room = corrected
            }
            corrections.append(RecoveryHumanCorrection(schemaVersion:schemaVersion,target:field.target,pdfHash:draft.document.pdfHash,
                acquisitionHash:draft.acquisitionHash,documentSnapshotHash:draft.snapshotHash,page:field.page,parentSourceIds:field.parentSourceIds,
                crop:field.crop,value:value,provenance:.user,confirmedAt:now))
        }
        result.humanCorrections = corrections
        guard try RecoveryValidator.validate(draft.document,result,check:check).canAdopt else { throw PDFParseError(code:.ambiguous) }
        return result
    }

    static func validationErrors(_ doc: RecoveryDocument, _ result: RecoveryResult, inputOnly: Bool,
                                 check:@escaping () throws -> Void = {}, work: RecoveryValidationWork? = nil) throws -> [String] {
        if doc.nativeCapture == nil, result.humanCorrections == nil {
            if !(doc.ocrLineAtomSourceIds ?? []).isEmpty { return ["atomCapture"] }
            return doc.sources.allSatisfy({ $0.nativeConfidence == nil }) ? [] : ["nativeConfidence"]
        }
        guard doc.nativeCapture != nil else { return ["manualCapture"] }
        let fields = try fields(doc,check:check,work:work)
        if inputOnly { return result.humanCorrections == nil ? [] : ["manualInput"] }
        guard !fields.isEmpty else { return result.humanCorrections == nil ? [] : ["manualUnexpected"] }
        guard let corrections = result.humanCorrections, corrections.count == fields.count,
              corrections.count <= maximumFields, Set(corrections.map(\.target)).count == corrections.count,
              Set(corrections.map(\.target)) == Set(fields.map(\.target)) else { return ["manualMissing"] }
        let snapshot = try fingerprint(doc), capture = try fingerprint(doc.nativeCapture!)
        for field in fields {
            guard let edit = corrections.first(where:{ $0.target == field.target }), edit.schemaVersion == schemaVersion,
                  edit.pdfHash == doc.pdfHash, edit.acquisitionHash == capture, edit.documentSnapshotHash == snapshot,
                  edit.page == field.page, edit.parentSourceIds == field.parentSourceIds, edit.crop == field.crop,
                  edit.provenance == .user, edit.confirmedAt.timeIntervalSince1970.isFinite, edit.confirmedAt.timeIntervalSince1970 > 0,
                  !edit.value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, edit.value.utf16.count <= maximumCorrectedUTF16 else { return ["manualProvenance"] }
            guard let cell = result.cells.first(where:{ $0.cellId == field.target.cellId }), cell.lessons.indices.contains(field.target.lessonIndex) else { return ["manualTarget"] }
            let lesson = cell.lessons[field.target.lessonIndex]
            let output:RecoveryField
            switch field.target.role { case .subject: output = lesson.subject; case .teacher: output = lesson.teacher; case .room: output = lesson.room }
            guard output.state == .present, output.value.utf8.elementsEqual(edit.value.utf8), output.evidence == edit.parentSourceIds else { return ["manualValue"] }
        }
        return []
    }
}
