import Foundation

/// One shared budget covers index construction and every candidate, including rejected ones.
/// The synchronous compatibility API fails closed; checked callers rethrow cancellation.
final class RecoveryValidationWork {
    static let maximum = 32_000_000
    private var count = 0
    private let check: () throws -> Void
    private(set) var failure: Error?
    init(check: @escaping () throws -> Void = {}) { self.check = check }
    func charge(_ amount: Int = 1) -> Bool {
        guard failure == nil else { return false }
        guard amount >= 0, amount <= Self.maximum - count else { failure = PDFParseError(code:.limit); return false }
        let old = count; count += amount
        if old == 0 || old / 128 != count / 128 {
            do { try check(); try Task.checkCancellation() } catch { failure = error; return false }
        }
        return true
    }
    func finish() throws { if let failure { throw failure }; try check(); try Task.checkCancellation() }
}

/// Owner groups retain the document's original order. The spatial index never drops
/// a tall span: prefix maximum bottoms keep it in every intersecting query.
struct RecoverySourceIndex: Sendable {
    var byId: [String:RecoverySource] = [:]
    var byCell: [String:[RecoverySource]] = [:]
    var order: [String:Int] = [:]
    private var pages: [Int:[RecoverySource]] = [:]
    private var bottoms: [Int:[Double]] = [:]
    init(_ sources: [RecoverySource], work: RecoveryValidationWork) throws {
        guard sources.count <= 100000 else { throw PDFParseError(code:.limit) }
        var indexed = [Int:[(Int,RecoverySource)]]()
        for (position,source) in sources.enumerated() {
            guard work.charge(source.text.utf8.count + source.id.utf8.count + source.cellId.utf8.count + 1) else { try work.finish(); return }
            byId[source.id] = source
            if order[source.id] == nil { order[source.id] = position }
            byCell[source.cellId,default:[]].append(source)
            indexed[source.page,default:[]].append((position,source))
        }
        // Bottom-up merge sort allows cancellation inside comparison work.
        for (page,values) in indexed {
            var sorted = values, width = 1
            while width < sorted.count {
                var merged = [(Int,RecoverySource)](); merged.reserveCapacity(sorted.count)
                var start = 0
                while start < sorted.count {
                    let mid = min(start+width,sorted.count), end = min(start+width*2,sorted.count)
                    var left = start, right = mid
                    while left < mid || right < end {
                        guard work.charge() else { try work.finish(); return }
                        let takeLeft = right == end || left < mid && (sorted[left].1.box.y < sorted[right].1.box.y || sorted[left].1.box.y == sorted[right].1.box.y && sorted[left].0 < sorted[right].0)
                        if takeLeft { merged.append(sorted[left]); left += 1 } else { merged.append(sorted[right]); right += 1 }
                    }
                    start = end
                }
                sorted = merged; width *= 2
            }
            var maximum = -Double.infinity, prefix = [Double](), spans = [RecoverySource]()
            for (_,source) in sorted {
                guard work.charge() else { try work.finish(); return }
                maximum = max(maximum,source.box.y+source.box.height)
                prefix.append(maximum); spans.append(source)
            }
            pages[page] = spans; bottoms[page] = prefix
        }
        try work.finish()
    }
    func original(_ ids:[String],work:RecoveryValidationWork) -> String? {
        guard work.charge(ids.count) else { return nil }
        var parts = [String](); parts.reserveCapacity(ids.count)
        for id in ids {
            guard let source = byId[id], work.charge(source.text.utf8.count + id.utf8.count + 1) else { return nil }
            parts.append(source.text)
        }
        return parts.joined()
    }
    func intersections(page: Int, box: RecoveryBox, work: RecoveryValidationWork, accept: (RecoverySource) -> Bool) -> Bool {
        guard let spans = pages[page], let prefix = bottoms[page] else { return true }
        guard box.valid else { return false }
        var low = 0, high = spans.count
        while low < high {
            guard work.charge() else { return false }
            let mid = low+(high-low)/2
            if spans[mid].box.y < box.y+box.height { low = mid+1 } else { high = mid }
        }
        let end = low; low = 0; high = end
        while low < high {
            guard work.charge() else { return false }
            let mid = low+(high-low)/2
            if prefix[mid] <= box.y { low = mid+1 } else { high = mid }
        }
        for position in low..<end {
            guard work.charge() else { return false }
            let source = spans[position], other = source.box
            if min(other.x+other.width,box.x+box.width) > max(other.x,box.x) && min(other.y+other.height,box.y+box.height) > max(other.y,box.y), !accept(source) { return false }
        }
        return true
    }
}

struct RecoveryPromptSource: Codable, Sendable { var id: String; var text: String; var box: RecoveryBox? = nil; var sourceLine: Int? = nil; var sourceOrder: Int? = nil }
struct RecoveryPromptCell: Codable, Sendable {
    var cellId: String; var slots: [RecoverySlot]; var sources: [RecoveryPromptSource]; var blankFields: [String]; var parallelCount: Int; var lessonBindings: [RecoveryLessonBinding]
    var roleScopes: [RecoveryRoleScope] = []
    var mode: RecoveryPromptMode = .fieldExtraction
    var structureCuts: [RecoveryStructureCut] = []
}
protocol LocalRecoveryProvider: Sendable {
    var id: String { get }; var localOnly: Bool { get }; var metadata: RecoveryMetadata { get }
    func availability() async throws -> LocalProviderState
    func recoverCell(_ cell: RecoveryPromptCell) async throws -> [RecoveryLesson]
}
enum RecoveryProviderError: Error { case invalidOutput }
struct RecoveryRun: Sendable { var state: RecoveryJobState; var result: RecoveryResult?; var errors: [String] }
enum RecoveryRules {
    static func recover(_ doc: RecoveryDocument, _ cell: RecoveryCell) -> RecoveredCell? {
        let work = RecoveryValidationWork()
        guard let index = try? RecoverySourceIndex(doc.sources,work:work) else { return nil }
        return try? recover(cell,index:index,work:work)
    }
    static func recover(_ cell: RecoveryCell,index:RecoverySourceIndex,work:RecoveryValidationWork) throws -> RecoveredCell? {
        guard work.charge(cell.sourceIds.count + 1) else { try work.finish(); return nil }
        guard cell.inputState == .complete, !cell.confirmedEmpty, (1...4).contains(cell.parallelCount) else { return nil }
        let sources = index.byId
        func field(_ ids: [String], _ name: String) -> RecoveryField? {
            if ids.isEmpty { return name != "subject" ? RecoveryField(state: .empty, value: "", evidence: []) : nil }
            guard ids.allSatisfy({ sources[$0]?.cellId == cell.id }) else { return nil }
            guard let value = index.original(ids,work:work) else { return nil }
            return RecoveryField(state: .present, value: value, evidence: ids)
        }
        var bindings = cell.lessonBindings
        if cell.bindingMode == .roleProposal {
            let labels = Set(cell.roleScopes.flatMap(\.labelSourceIds)), body = Set(cell.sourceIds).subtracting(labels)
            guard cell.roleScopes.count == cell.parallelCount*3,
                  body.allSatisfy({ id in sources[id].map { atom in cell.roleScopes.filter { $0.page == atom.page && $0.box.contains(atom.box) }.count == 1 } ?? false }) else { return nil }
            bindings = []
            for lessonIndex in 0..<cell.parallelCount {
                var ids = [RecoveryRole:[String]]()
                for role in RecoveryRole.allCases {
                    let candidates = cell.roleScopes.filter { $0.lessonIndex == lessonIndex && $0.role == role }
                    guard candidates.count == 1 else { return nil }
                    let scope = candidates[0]
                    var assigned = [String]()
                    for atom in index.byCell[cell.id,default:[]] {
                        guard work.charge() else { try work.finish(); return nil }
                        if body.contains(atom.id) && scope.page == atom.page && scope.box.contains(atom.box) { assigned.append(atom.id) }
                    }
                    ids[role] = assigned
                    guard !ids[role]!.isEmpty || role != .subject && scope.emptyVerified else { return nil }
                }
                bindings.append(RecoveryLessonBinding(subject:ids[.subject]!,teacher:ids[.teacher]!,room:ids[.room]!))
            }
        }
        guard bindings.count == cell.parallelCount else { return nil }
        var lessons = [RecoveryLesson]()
        for (index,binding) in bindings.enumerated() {
            if cell.bindingMode == .fixed {
                guard (!binding.teacher.isEmpty || cell.blankFields.contains("teacher")) && (!binding.room.isEmpty || cell.blankFields.contains("room")) else { return nil }
            } else {
                guard cell.roleScopes.filter({ $0.lessonIndex == index }).count == 3 else { return nil }
            }
            guard let subject = field(binding.subject, "subject"), let teacher = field(binding.teacher, "teacher"), let room = field(binding.room, "room") else { return nil }
            lessons.append(RecoveryLesson(subject: subject, teacher: teacher, room: room, dateEvidence: cell.dayHeaderIds, periodEvidence: cell.periodHeaderIds))
        }
        return RecoveredCell(cellId: cell.id, state: .present, lessons: lessons)
    }
}
enum RecoveryEngine {
    static func run(_ doc: RecoveryDocument, os: String, osMajor: Int, foreground: Bool,
                    providers: [any LocalRecoveryProvider], rule: (RecoveryCell) throws -> RecoveredCell?,
                    check: @escaping () throws -> Void) async throws -> RecoveryRun {
        try check(); try Task.checkCancellation()
        if ["ios", "android"].contains(os) && !foreground { return RecoveryRun(state: .pending, result: nil, errors: []) }
        guard doc.complete, doc.cells.allSatisfy({ $0.inputState == .complete }) else { return RecoveryRun(state: .failed, result: nil, errors: ["incompleteDocument"]) }
        let work = RecoveryValidationWork(check:check)
        let sourceIndex = try RecoverySourceIndex(doc.sources,work:work)
        let inputErrors = try RecoveryValidator.inputErrors(doc,index:sourceIndex,work:work)
        guard inputErrors.isEmpty else { return RecoveryRun(state: .failed, result: nil, errors: inputErrors) }
        var recovered: [RecoveredCell?] = try doc.cells.map { cell in try check(); try Task.checkCancellation(); return cell.confirmedEmpty && cell.sourceIds.isEmpty ? RecoveredCell(cellId: cell.id, state: .empty, lessons: []) : try (RecoveryRules.recover(cell,index:sourceIndex,work:work) ?? rule(cell)) }
        try work.finish()
        let missing = recovered.indices.filter { recovered[$0] == nil }
        func result(_ metadata: RecoveryMetadata) -> RecoveryResult {
            RecoveryResult(pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: doc.schoolYear, term: doc.term, cells: recovered.compactMap { $0 }, metadata: metadata)
        }
        func validated(_ value: RecoveryResult) throws -> RecoveryRun {
            try check(); try Task.checkCancellation()
            let validation = try RecoveryValidator.validate(doc,value,index:sourceIndex,work:work)
            try check(); try Task.checkCancellation()
            return RecoveryRun(state: validation.canAdopt ? .awaitingConfirmation : .failed, result: validation.canAdopt ? value : nil, errors: validation.errors)
        }
        if missing.isEmpty { return try validated(result(doc.structureMetadata ?? RecoveryMetadata(provider: "rule", modelId: "rules", modelVersion: "3", runtimeVersion: "3", promptVersion: "1", recoverySchemaVersion: RecoveryValidator.schemaVersion, validatorVersion: RecoveryValidator.version, osVersion: "\(os):\(osMajor)"))) }
        var runtimeFailed = false
        for id in RecoveryPolicy.providers(os: os, majorVersion: osMajor) {
            try check(); try Task.checkCancellation()
            let matching = providers.filter { $0.id == id && $0.localOnly }
            guard matching.count <= 1 else { return RecoveryRun(state: .failed, result: nil, errors: ["duplicateProviders"]) }
            guard let provider = matching.first else { continue }
            let availability: LocalProviderState
            do { availability = try await provider.availability(); try check(); try Task.checkCancellation() }
            catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled || error.code == .limit { throw error }
            catch { runtimeFailed = true; continue }
            if availability != .ready {
                if RecoveryPolicy.mayTryNext(availability) || os == "windows" && availability == .notReady { continue }
                return RecoveryRun(state: .awaitingModel, result: nil, errors: [availability.rawValue])
            }
            do {
                for index in missing {
                    try check(); try Task.checkCancellation()
                    let cell = doc.cells[index]; let ids = Set(cell.sourceIds + cell.roleScopes.flatMap(\.labelSourceIds))
                    let prompt = RecoveryPromptCell(cellId: cell.id, slots: cell.slots, sources: ids.compactMap { sourceIndex.byId[$0] }.sorted { sourceIndex.order[$0.id,default:0] < sourceIndex.order[$1.id,default:0] }.map { RecoveryPromptSource(id: $0.id, text: $0.text, box:$0.box) }, blankFields: cell.blankFields, parallelCount: cell.parallelCount, lessonBindings: cell.lessonBindings, roleScopes: cell.roleScopes)
                    guard try JSONEncoder().encode(prompt).count <= 8192 else { return RecoveryRun(state: .failed, result: nil, errors: ["promptLimit"]) }
                    var lessons = try await provider.recoverCell(prompt)
                    guard lessons.count <= 4 else { throw RecoveryProviderError.invalidOutput }
                    try check(); try Task.checkCancellation()
                    for i in lessons.indices {
                        if cell.bindingMode == .roleProposal {
                            func original(_ field: RecoveryField) throws -> RecoveryField {
                                var value = field
                                if field.state == .present {
                                    guard let text = sourceIndex.original(field.evidence,work:work) else {
                                        try work.finish(); throw RecoveryProviderError.invalidOutput
                                    }
                                    value.value = text
                                } else { value.value = "" }
                                return value
                            }
                            lessons[i].subject = try original(lessons[i].subject)
                            lessons[i].teacher = try original(lessons[i].teacher)
                            lessons[i].room = try original(lessons[i].room)
                        }
                        lessons[i].dateEvidence = cell.dayHeaderIds
                        lessons[i].periodEvidence = cell.periodHeaderIds
                    }
                    recovered[index] = RecoveredCell(cellId: cell.id, state: .present, lessons: lessons)
                }
                return try validated(result(provider.metadata))
            } catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled || error.code == .limit { throw error }
            catch RecoveryProviderError.invalidOutput { return RecoveryRun(state: .failed, result: nil, errors: ["invalidOutput"]) }
            catch { runtimeFailed = true }
        }
        try check(); try Task.checkCancellation()
        return RecoveryRun(state: runtimeFailed ? .failed : .awaitingModel, result: nil, errors: [runtimeFailed ? "runtimeFailure" : "noLocalProvider"])
    }
}
