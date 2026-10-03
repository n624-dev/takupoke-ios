import Foundation

struct RecoveryPromptSource: Codable, Sendable { var id: String; var text: String; var box: RecoveryBox? = nil }
struct RecoveryPromptCell: Codable, Sendable {
    var cellId: String; var slots: [RecoverySlot]; var sources: [RecoveryPromptSource]; var blankFields: [String]; var parallelCount: Int; var lessonBindings: [RecoveryLessonBinding]
    var roleScopes: [RecoveryRoleScope] = []
}
protocol LocalRecoveryProvider {
    var id: String { get }; var localOnly: Bool { get }; var metadata: RecoveryMetadata { get }
    func availability() async throws -> LocalProviderState
    func recoverCell(_ cell: RecoveryPromptCell) async throws -> [RecoveryLesson]
}
enum RecoveryProviderError: Error { case invalidOutput }
struct RecoveryRun { var state: RecoveryJobState; var result: RecoveryResult?; var errors: [String] }
enum RecoveryRules {
    static func recover(_ doc: RecoveryDocument, _ cell: RecoveryCell) -> RecoveredCell? {
        guard cell.bindingMode == .fixed, cell.inputState == .complete, !cell.confirmedEmpty, cell.lessonBindings.count == cell.parallelCount else { return nil }
        let sources = Dictionary(doc.sources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func field(_ ids: [String], _ name: String) -> RecoveryField? {
            if ids.isEmpty { return name != "subject" && cell.blankFields.contains(name) ? RecoveryField(state: .empty, value: "", evidence: []) : nil }
            guard ids.allSatisfy({ sources[$0]?.cellId == cell.id }) else { return nil }
            return RecoveryField(state: .present, value: ids.compactMap { sources[$0]?.text }.joined(), evidence: ids)
        }
        var lessons = [RecoveryLesson]()
        for binding in cell.lessonBindings {
            guard let subject = field(binding.subject, "subject"), let teacher = field(binding.teacher, "teacher"), let room = field(binding.room, "room") else { return nil }
            lessons.append(RecoveryLesson(subject: subject, teacher: teacher, room: room, dateEvidence: cell.dayHeaderIds, periodEvidence: cell.periodHeaderIds))
        }
        return RecoveredCell(cellId: cell.id, state: .present, lessons: lessons)
    }
}
enum RecoveryEngine {
    static func run(_ doc: RecoveryDocument, os: String, osMajor: Int, foreground: Bool,
                    providers: [any LocalRecoveryProvider], rule: (RecoveryCell) throws -> RecoveredCell?,
                    check: () throws -> Void) async throws -> RecoveryRun {
        try check(); try Task.checkCancellation()
        if ["ios", "android"].contains(os) && !foreground { return RecoveryRun(state: .pending, result: nil, errors: []) }
        guard doc.complete, doc.cells.allSatisfy({ $0.inputState == .complete }) else { return RecoveryRun(state: .failed, result: nil, errors: ["incompleteDocument"]) }
        let inputErrors = RecoveryValidator.inputErrors(doc)
        guard inputErrors.isEmpty else { return RecoveryRun(state: .failed, result: nil, errors: inputErrors) }
        var recovered: [RecoveredCell?] = try doc.cells.map { cell in try check(); try Task.checkCancellation(); return cell.confirmedEmpty && cell.sourceIds.isEmpty ? RecoveredCell(cellId: cell.id, state: .empty, lessons: []) : try (RecoveryRules.recover(doc, cell) ?? rule(cell)) }
        let missing = recovered.indices.filter { recovered[$0] == nil }
        func result(_ metadata: RecoveryMetadata) -> RecoveryResult {
            RecoveryResult(pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: doc.schoolYear, term: doc.term, cells: recovered.compactMap { $0 }, metadata: metadata)
        }
        func validated(_ value: RecoveryResult) throws -> RecoveryRun {
            try check(); try Task.checkCancellation()
            let validation = RecoveryValidator.validate(doc, value)
            try check(); try Task.checkCancellation()
            return RecoveryRun(state: validation.canAdopt ? .awaitingConfirmation : .failed, result: validation.canAdopt ? value : nil, errors: validation.errors)
        }
        if missing.isEmpty { return try validated(result(RecoveryMetadata(provider: "rule", modelId: "rules", modelVersion: "1", runtimeVersion: "1", promptVersion: "1", recoverySchemaVersion: RecoveryValidator.schemaVersion, validatorVersion: RecoveryValidator.version, osVersion: "\(os):\(osMajor)"))) }
        var runtimeFailed = false
        for id in RecoveryPolicy.providers(os: os, majorVersion: osMajor) {
            try check(); try Task.checkCancellation()
            let matching = providers.filter { $0.id == id && $0.localOnly }
            guard matching.count <= 1 else { return RecoveryRun(state: .failed, result: nil, errors: ["duplicateProviders"]) }
            guard let provider = matching.first else { continue }
            let availability: LocalProviderState
            do { availability = try await provider.availability(); try check(); try Task.checkCancellation() }
            catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled { throw error }
            catch { runtimeFailed = true; continue }
            if availability != .ready {
                if RecoveryPolicy.mayTryNext(availability) || os == "windows" && availability == .notReady { continue }
                return RecoveryRun(state: .awaitingModel, result: nil, errors: [availability.rawValue])
            }
            do {
                for index in missing {
                    try check(); try Task.checkCancellation()
                    let cell = doc.cells[index]; let ids = Set(cell.sourceIds + cell.roleScopes.flatMap(\.labelSourceIds))
                    let prompt = RecoveryPromptCell(cellId: cell.id, slots: cell.slots, sources: doc.sources.filter { ids.contains($0.id) }.map { RecoveryPromptSource(id: $0.id, text: $0.text, box:$0.box) }, blankFields: cell.blankFields, parallelCount: cell.parallelCount, lessonBindings: cell.lessonBindings, roleScopes: cell.roleScopes)
                    guard try JSONEncoder().encode(prompt).count <= 8192 else { return RecoveryRun(state: .failed, result: nil, errors: ["promptLimit"]) }
                    var lessons = try await provider.recoverCell(prompt)
                    try check(); try Task.checkCancellation()
                    for i in lessons.indices {
                        if cell.bindingMode == .roleProposal {
                            let sourceMap = Dictionary(doc.sources.map { ($0.id, $0.text) }, uniquingKeysWith: { first, _ in first })
                            func original(_ field: RecoveryField) -> RecoveryField {
                                var value = field
                                value.value = field.state == .present ? field.evidence.compactMap { sourceMap[$0] }.joined() : ""
                                return value
                            }
                            lessons[i].subject = original(lessons[i].subject)
                            lessons[i].teacher = original(lessons[i].teacher)
                            lessons[i].room = original(lessons[i].room)
                        }
                        lessons[i].dateEvidence = cell.dayHeaderIds
                        lessons[i].periodEvidence = cell.periodHeaderIds
                    }
                    recovered[index] = RecoveredCell(cellId: cell.id, state: .present, lessons: lessons)
                }
                return try validated(result(provider.metadata))
            } catch is CancellationError { throw CancellationError() }
            catch let error as PDFParseError where error.code == .cancelled { throw error }
            catch RecoveryProviderError.invalidOutput { return RecoveryRun(state: .failed, result: nil, errors: ["invalidOutput"]) }
            catch { runtimeFailed = true }
        }
        try check(); try Task.checkCancellation()
        return RecoveryRun(state: runtimeFailed ? .failed : .awaitingModel, result: nil, errors: [runtimeFailed ? "runtimeFailure" : "noLocalProvider"])
    }
}
