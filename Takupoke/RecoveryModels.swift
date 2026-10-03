import Foundation

enum RecoveryDocumentKind: String, Codable, Sendable { case timetable, exam, `return` }
enum RecoveryValueState: String, Codable, Sendable { case present, empty, unreadable, missing, ambiguous }
enum RecoveryInputState: String, Codable, Sendable { case complete, partial, rasterOnly }
enum RecoveryJobState: String, Codable, Sendable { case pending, preparing, awaitingModel, running, awaitingConfirmation, adopted, failed, superseded }
enum LocalProviderState: String, Codable, Sendable { case ready, notReady, disabled, unsupported, downloadRequired, insufficientMemory }
struct RecoveryBox: Codable, Equatable, Sendable {
    var x: Double; var y: Double; var width: Double; var height: Double
    var valid: Bool { [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0 }
    func contains(_ other: Self) -> Bool { valid && other.valid && other.x >= x && other.y >= y && other.x + other.width <= x + width && other.y + other.height <= y + height }
}
struct RecoverySource: Codable, Equatable, Sendable { var id: String; var cellId: String; var page: Int; var text: String; var box: RecoveryBox; var fromOcr = false; var sourceLine: Int? = nil; var sourceOrder: Int? = nil }
struct RecoveryField: Codable, Equatable, Sendable { var state: RecoveryValueState; var value: String; var evidence: [String] }
struct RecoverySlot: Codable, Hashable, Sendable { var className: String; var day: String; var period: Int }
enum RecoveryHeaderAxis: String, Codable, Sendable { case above, left }
struct RecoveryHeaderRegion: Codable, Equatable, Sendable { var page: Int; var box: RecoveryBox; var axis: RecoveryHeaderAxis }
struct RecoveryClockBinding: Codable, Equatable, Sendable {
    var page: Int; var box: RecoveryBox; var day: String; var spanStart: Int; var spanEnd: Int
    var dayHeaderIds: [String]; var dayRegion: RecoveryHeaderRegion?
    var periodHeaderIds: [String]; var periodRegion: RecoveryHeaderRegion
    var commonScope: Bool = false
    var derivedSpan: Bool = false
}
struct RecoveryLessonBinding: Codable, Equatable, Sendable { var subject: [String]; var teacher: [String]; var room: [String] }
enum RecoveryBindingMode: String, Codable, Sendable { case fixed, roleProposal }
enum RecoveryRole: String, Codable, CaseIterable, Sendable { case subject, teacher, room
    var labels: [String] { switch self { case .subject: return ["科目", "科目名", "授業名"]; case .teacher: return ["教員", "教員名", "教師名", "担当", "担当者", "担当教員"]; case .room: return ["教室", "教室名", "会場"] } }
}
extension RecoveryRole {
    static func hasLabelPrefix(_ value: String) -> Bool {
        let compact = value.filter { !$0.isWhitespace }.replacingOccurrences(of:"･",with:"・")
        return compact.components(separatedBy:"・").contains { part in
            allCases.flatMap(\.labels).contains { part.hasPrefix($0+":") || part.hasPrefix($0+"：") }
        }
    }
}
enum RecoveryRoleProof: String, Codable, Sendable { case inlineLabel, columnHeader }
struct RecoveryRoleScope: Codable, Equatable, Sendable {
    var lessonIndex: Int; var role: RecoveryRole; var page: Int; var box: RecoveryBox
    var labelSourceIds: [String]; var labelRegion: RecoveryHeaderRegion; var proof: RecoveryRoleProof
    var emptyVerified: Bool
}
struct RecoveryAnnotation: Codable, Equatable, Sendable {
    var page: Int; var box: RecoveryBox; var sourceIds: [String]
    /// A region outside the independently bounded table; never an ignored body cell.
    var tableBox: RecoveryBox
}
struct RecoveryCell: Codable, Equatable, Sendable {
    var id: String; var page: Int; var box: RecoveryBox; var inputState: RecoveryInputState; var slots: [RecoverySlot]
    var sourceIds: [String]; var blankFields: [String]; var confirmedEmpty = false; var parallelCount = 1
    var classHeaderIds: [String] = []; var dayHeaderIds: [String] = []; var periodHeaderIds: [String] = []
    var lessonBindings: [RecoveryLessonBinding] = []
    var classRegion: RecoveryHeaderRegion? = nil; var dayRegion: RecoveryHeaderRegion? = nil
    var periodRegions: [String: RecoveryHeaderRegion] = [:]
    var bindingMode: RecoveryBindingMode = .fixed
    var roleScopes: [RecoveryRoleScope] = []
    var parallelSeparators: [String:String] = [:]
}
struct RecoveryDocument: Codable, Equatable, Sendable {
    var pdfHash: String; var kind: RecoveryDocumentKind; var schoolYear: Int; var term: String?
    var classes: [String]; var days: [String]; var requiredSlots: [RecoverySlot]; var cells: [RecoveryCell]
    var sources: [RecoverySource]; var complete: Bool; var yearEvidence: [String]; var termEvidence: [String]
    var dayEvidence: [String: [String]]; var classEvidence: [String: [String]]; var periodEvidence: [String: [String]]
    var times: [String: String]; var timeEvidence: [String]; var normalTimeNoteEvidence: [String]
    var clockEvidence: [String: [String]] = [:]
    var spanTimes: [String: String] = [:]
    var clockBindings: [String: RecoveryClockBinding] = [:]
    var clockReplicas: [String: [RecoveryClockBinding]] = [:]
    var annotations: [RecoveryAnnotation] = []
    var commonClockEvidence: [String] = []
    var commonClockRegions: [String: RecoveryHeaderRegion] = [:]
}
struct RecoveryLesson: Codable, Equatable, Sendable {
    var subject: RecoveryField; var teacher: RecoveryField; var room: RecoveryField
    var dateEvidence: [String]; var periodEvidence: [String]
}
struct RecoveredCell: Codable, Equatable, Sendable { var cellId: String; var state: RecoveryValueState; var lessons: [RecoveryLesson] }
struct RecoveryMetadata: Codable, Equatable, Sendable {
    var provider: String; var modelId: String; var modelVersion: String; var runtimeVersion: String; var promptVersion: String
    var recoverySchemaVersion: Int; var validatorVersion: Int; var osVersion: String; var recoveryVersion = "1"
}
struct RecoveryResult: Codable, Equatable, Sendable {
    var pdfHash: String; var kind: RecoveryDocumentKind; var schoolYear: Int; var term: String?
    var cells: [RecoveredCell]; var metadata: RecoveryMetadata
}
struct RecoveryJob: Codable, Equatable, Sendable {
    var pdfHash: String; var kind: RecoveryDocumentKind; var state: RecoveryJobState; var createdAt: Date; var resultHash: String? = nil
}
struct RecoveryAcceptance: Codable, Equatable, Sendable {
    var pdfHash: String; var resultHash: String; var scopeHash: String; var metadata: RecoveryMetadata; var acceptedAt: Date
}
struct RecoveryAdopted: Codable, Equatable, Sendable {
    var document: RecoveryDocument; var result: RecoveryResult; var acceptance: RecoveryAcceptance
}
struct RecoveryPreview: Identifiable, Sendable {
    var id = UUID(); var document: RecoveryDocument; var result: RecoveryResult
    var source: RecoverySelectedSource
}
struct RecoverySelectedSource: Sendable {
    var kind: RecoveryDocumentKind; var url: URL; var digest: String; var originalName: String
    var storedName: String; var period: SchoolDataPeriod; var captured: [RecoveryReadPage] = []
}
struct RecoveryValidation: Equatable { var errors: [String]; var canAdopt: Bool { errors.isEmpty } }

enum RecoveryPolicy {
    static func providers(os: String, majorVersion: Int = 0) -> [String] {
        switch os {
        case "ios": return majorVersion >= 27 ? ["systemLanguageModel", "coreAI", "llamaCpp"] : ["systemLanguageModel", "llamaCpp"]
        case "android": return ["liteRtLm"]
        case "windows": return ["windowsLanguageModel", "foundryLocal"]
        default: return []
        }
    }
    static func eligible(_ failure: PDFParseError) -> Bool {
        guard failure.code == .unsupported || failure.code == .ambiguous else { return false }
        return failure.stage != .duplicateClass && failure.stage != .eventColumns && failure.stage != .monthHeading
    }
    static func mayRecover(digest: String, kind: RecoveryDocumentKind, parserVersion: Int,
                           attemptDigest: String?, attemptVersion: Int?, failure: PDFParseError?, job: RecoveryJob?) -> Bool {
        attemptDigest == digest && attemptVersion == parserVersion && failure.map(eligible) == true &&
            job?.pdfHash == digest && job?.kind == kind
    }
    static func mayTryNext(_ state: LocalProviderState) -> Bool { state == .unsupported || state == .insufficientMemory }
}

/// Ephemeral reader output. Never persisted as a complete RecoveryDocument after a reader error.
struct RecoveryReadPage: Sendable { var page: Int; var state: RecoveryInputState; var layout: PDFPageLayout? }
final class RecoveryReadCapture {
    private(set) var pages: [RecoveryReadPage] = []
    private(set) var readerCompleted = false
    var complete: Bool { readerCompleted && !pages.isEmpty && pages.allSatisfy { $0.state == .complete } }
    func reset() { pages = []; readerCompleted = false }
    func begin(pageCount: Int) { guard (1...12).contains(pageCount) else { reset(); return }; pages = (1...pageCount).map { RecoveryReadPage(page: $0, state: .rasterOnly, layout: nil) }; readerCompleted = false }
    func record(page: Int, state: RecoveryInputState, layout: PDFPageLayout) { guard pages.indices.contains(page - 1) else { return }; pages[page - 1] = RecoveryReadPage(page: page, state: state, layout: layout) }
    func finish() { readerCompleted = true }
}

// Recovery documents were not yet adopted in schema 1. Decode the old internal
// fixtures as fixed bindings; schema/version validation still gates adoption.
extension RecoveryCell {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), page: try c.decode(Int.self, forKey: .page), box: try c.decode(RecoveryBox.self, forKey: .box), inputState: try c.decode(RecoveryInputState.self, forKey: .inputState), slots: try c.decode([RecoverySlot].self, forKey: .slots), sourceIds: try c.decode([String].self, forKey: .sourceIds), blankFields: try c.decode([String].self, forKey: .blankFields), confirmedEmpty: try c.decodeIfPresent(Bool.self, forKey: .confirmedEmpty) ?? false, parallelCount: try c.decodeIfPresent(Int.self, forKey: .parallelCount) ?? 1,
            classHeaderIds: try c.decodeIfPresent([String].self, forKey: .classHeaderIds) ?? [], dayHeaderIds: try c.decodeIfPresent([String].self, forKey: .dayHeaderIds) ?? [], periodHeaderIds: try c.decodeIfPresent([String].self, forKey: .periodHeaderIds) ?? [], lessonBindings: try c.decodeIfPresent([RecoveryLessonBinding].self, forKey: .lessonBindings) ?? [], classRegion: try c.decodeIfPresent(RecoveryHeaderRegion.self, forKey: .classRegion), dayRegion: try c.decodeIfPresent(RecoveryHeaderRegion.self, forKey: .dayRegion), periodRegions: try c.decodeIfPresent([String: RecoveryHeaderRegion].self, forKey: .periodRegions) ?? [:], bindingMode: try c.decodeIfPresent(RecoveryBindingMode.self, forKey: .bindingMode) ?? .fixed, roleScopes: try c.decodeIfPresent([RecoveryRoleScope].self, forKey: .roleScopes) ?? [], parallelSeparators: try c.decodeIfPresent([String:String].self, forKey: .parallelSeparators) ?? [:])
    }
}
extension RecoveryDocument {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(pdfHash: try c.decode(String.self, forKey: .pdfHash), kind: try c.decode(RecoveryDocumentKind.self, forKey: .kind), schoolYear: try c.decode(Int.self, forKey: .schoolYear), term: try c.decodeIfPresent(String.self, forKey: .term), classes: try c.decode([String].self, forKey: .classes), days: try c.decode([String].self, forKey: .days), requiredSlots: try c.decode([RecoverySlot].self, forKey: .requiredSlots), cells: try c.decode([RecoveryCell].self, forKey: .cells), sources: try c.decode([RecoverySource].self, forKey: .sources), complete: try c.decode(Bool.self, forKey: .complete), yearEvidence: try c.decode([String].self, forKey: .yearEvidence), termEvidence: try c.decode([String].self, forKey: .termEvidence), dayEvidence: try c.decode([String: [String]].self, forKey: .dayEvidence), classEvidence: try c.decode([String: [String]].self, forKey: .classEvidence), periodEvidence: try c.decode([String: [String]].self, forKey: .periodEvidence), times: try c.decode([String: String].self, forKey: .times), timeEvidence: try c.decode([String].self, forKey: .timeEvidence), normalTimeNoteEvidence: try c.decode([String].self, forKey: .normalTimeNoteEvidence), clockEvidence: try c.decodeIfPresent([String: [String]].self, forKey: .clockEvidence) ?? [:], spanTimes: try c.decodeIfPresent([String: String].self, forKey: .spanTimes) ?? [:], clockBindings: try c.decodeIfPresent([String: RecoveryClockBinding].self, forKey: .clockBindings) ?? [:], clockReplicas: try c.decodeIfPresent([String: [RecoveryClockBinding]].self, forKey: .clockReplicas) ?? [:], annotations: try c.decodeIfPresent([RecoveryAnnotation].self, forKey: .annotations) ?? [], commonClockEvidence: try c.decodeIfPresent([String].self, forKey: .commonClockEvidence) ?? [], commonClockRegions: try c.decodeIfPresent([String: RecoveryHeaderRegion].self, forKey: .commonClockRegions) ?? [:])
    }
}

extension RecoveryClockBinding {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(page: try c.decode(Int.self, forKey: .page), box: try c.decode(RecoveryBox.self, forKey: .box), day: try c.decode(String.self, forKey: .day), spanStart: try c.decode(Int.self, forKey: .spanStart), spanEnd: try c.decode(Int.self, forKey: .spanEnd), dayHeaderIds: try c.decode([String].self, forKey: .dayHeaderIds), dayRegion: try c.decodeIfPresent(RecoveryHeaderRegion.self, forKey: .dayRegion), periodHeaderIds: try c.decode([String].self, forKey: .periodHeaderIds), periodRegion: try c.decode(RecoveryHeaderRegion.self, forKey: .periodRegion), commonScope: try c.decodeIfPresent(Bool.self, forKey: .commonScope) ?? false, derivedSpan: try c.decodeIfPresent(Bool.self, forKey: .derivedSpan) ?? false)
    }
}

final class RecoverySourceCapture { var source: RecoverySelectedSource? }
