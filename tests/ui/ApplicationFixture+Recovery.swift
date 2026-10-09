import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

// This fixture injects a validated preview into only the temporary simulator
// app. Runtime/recognition correctness is exercised separately by core tests.
// Adoption, original PDF viewer and displayed field states use production UI.
@MainActor
enum SimulatorRecoveryFixture {
    static func payload() -> (RecoveryDocument, RecoveryResult) {
        let slots = (1...5).flatMap { d in
            (1...8).map { RecoverySlot(className: "3_IT", day: String(d), period: $0) }
        }
        let box = RecoveryBox(x: 110, y: 110, width: 60, height: 10)
        var sources = [
            RecoverySource(
                id: "heading", cellId: "header", page: 1, text: "\(SchoolDataPeriod.current().schoolYear)年度",
                box: RecoveryBox(x: 0, y: 0, width: 90, height: 10)),
            RecoverySource(id: "subject", cellId: "c0", page: 1, text: "架空科目A", box: box),
            RecoverySource(id: "teacher", cellId: "c0", page: 1, text: "架空教員A", box: box),
            RecoverySource(id: "room", cellId: "c0", page: 1, text: "架空教室A", box: box),
        ]
        sources.append(
            RecoverySource(
                id: "term", cellId: "header", page: 1,
                text: SchoolDataPeriod.current().half == 1 ? "前期" : "後期",
                box: RecoveryBox(x: 0, y: 20, width: 40, height: 10)))
        sources.append(
            RecoverySource(
                id: "class", cellId: "header", page: 1, text: "3_IT",
                box: RecoveryBox(x: 10, y: 110, width: 20, height: 10)))
        for day in 1...5 {
            sources.append(
                RecoverySource(
                    id: "day\(day)", cellId: "header", page: 1, text: ["月", "火", "水", "木", "金"][day - 1],
                    box: RecoveryBox(x: Double(day * 100 + 10), y: 20, width: 60, height: 10)))
        }
        for period in 1...8 {
            sources.append(
                RecoverySource(
                    id: "period\(period)", cellId: "header", page: 1, text: String(period),
                    box: RecoveryBox(x: 50, y: Double(period * 100 + 10), width: 20, height: 10)))
        }
        let cells = slots.enumerated().map { i, slot in
            RecoveryCell(
                id: "c\(i)", page: 1,
                box: RecoveryBox(
                    x: Double(Int(slot.day)! * 100), y: Double(slot.period * 100), width: 100, height: 100),
                inputState: .complete, slots: [slot],
                sourceIds: i == 0 ? ["subject", "teacher", "room"] : [], blankFields: [],
                confirmedEmpty: i != 0, classHeaderIds: ["class"], dayHeaderIds: ["day\(slot.day)"],
                periodHeaderIds: ["period\(slot.period)"],
                lessonBindings: i == 0
                    ? [RecoveryLessonBinding(subject: ["subject"], teacher: ["teacher"], room: ["room"])]
                    : [],
                classRegion: RecoveryHeaderRegion(
                    page: 1, box: RecoveryBox(x: 0, y: 100, width: 40, height: 800), axis: .left),
                dayRegion: RecoveryHeaderRegion(
                    page: 1, box: RecoveryBox(x: Double(Int(slot.day)! * 100), y: 0, width: 100, height: 50),
                    axis: .above),
                periodRegions: [
                    String(slot.period): RecoveryHeaderRegion(
                        page: 1,
                        box: RecoveryBox(x: 40, y: Double(slot.period * 100), width: 40, height: 100),
                        axis: .left)
                ])
        }
        var doc = RecoveryDocument(
            pdfHash: String(repeating: "a", count: 64), kind: .timetable,
            schoolYear: SchoolDataPeriod.current().schoolYear,
            term: SchoolDataPeriod.current().half == 1 ? "前期" : "後期", classes: ["3_IT"],
            days: (1...5).map(String.init), requiredSlots: slots, cells: cells, sources: sources,
            complete: true, yearEvidence: ["heading"], termEvidence: ["term"],
            dayEvidence: Dictionary(uniqueKeysWithValues: (1...5).map { (String($0), ["day\($0)"]) }),
            classEvidence: ["3_IT": ["class"]],
            periodEvidence: Dictionary(uniqueKeysWithValues: (1...8).map { (String($0), ["period\($0)"]) }),
            times: [:], timeEvidence: [], normalTimeNoteEvidence: [])
        let lesson = RecoveryLesson(
            subject: RecoveryField(state: .present, value: "架空科目A", evidence: ["subject"]),
            teacher: RecoveryField(state: .present, value: "架空教員A", evidence: ["teacher"]),
            room: RecoveryField(state: .present, value: "架空教室A", evidence: ["room"]), dateEvidence: ["day1"],
            periodEvidence: ["period1"])
        var result = RecoveryResult(
            pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: SchoolDataPeriod.current().schoolYear,
            term: SchoolDataPeriod.current().half == 1 ? "前期" : "後期",
            cells: cells.enumerated().map { i, cell in
                RecoveredCell(
                    cellId: cell.id, state: i == 0 ? .present : .empty, lessons: i == 0 ? [lesson] : [])
            },
            metadata: RecoveryMetadata(
                provider: "rule", modelId: "rules", modelVersion: "1", runtimeVersion: "1",
                promptVersion: "1", recoverySchemaVersion: RecoveryValidator.schemaVersion,
                validatorVersion: RecoveryValidator.version, osVersion: "test"))
        // A blank teacher is independently asserted in this UI-only input.
        doc.sources.removeAll { $0.id == "teacher" }
        doc.sources[doc.sources.firstIndex { $0.id == "room" }!].box.y = 145
        doc.cells[0].sourceIds.removeAll { $0 == "teacher" }
        doc.cells[0].blankFields = ["teacher"]
        doc.cells[0].lessonBindings[0].teacher = []
        result.cells[0].lessons[0].teacher = RecoveryField(state: .empty, value: "", evidence: [])
        if ProcessInfo.processInfo.arguments.contains("--recovery-parallel") {
            var atoms: [RecoverySource] = []
            var bindings: [RecoveryLessonBinding] = []
            var lessons: [RecoveryLesson] = []
            for index in 0..<2 {
                let suffix = index == 0 ? "A" : "B"
                let ids = [
                    "parallel-subject-\(index)", "parallel-teacher-\(index)", "parallel-room-\(index)",
                ]
                let values = ["架空並記科目\(suffix)", "架空並記担当\(suffix)", "架空並記教室\(suffix)"]
                for role in 0..<3 {
                    atoms.append(
                        RecoverySource(
                            id: ids[role], cellId: "c0", page: 1, text: values[role],
                            box: RecoveryBox(
                                x: 110, y: Double(110 + index * 45 + role * 15), width: 80, height: 10)))
                }
                bindings.append(RecoveryLessonBinding(subject: [ids[0]], teacher: [ids[1]], room: [ids[2]]))
                lessons.append(
                    RecoveryLesson(
                        subject: RecoveryField(state: .present, value: values[0], evidence: [ids[0]]),
                        teacher: RecoveryField(state: .present, value: values[1], evidence: [ids[1]]),
                        room: RecoveryField(state: .present, value: values[2], evidence: [ids[2]]),
                        dateEvidence: ["day1"], periodEvidence: ["period1"]))
            }
            doc.sources.removeAll { $0.cellId == "c0" }
            doc.sources.append(contentsOf: atoms)
            doc.cells[0].parallelCount = 2
            doc.cells[0].sourceIds = atoms.map(\.id)
            doc.cells[0].blankFields = []
            doc.cells[0].lessonBindings = bindings
            result.cells[0].lessons = lessons
        }
        return (doc, result)
    }

    private struct SpecialPayload: Decodable {
        var document: RecoveryDocument
        var result: RecoveryResult
    }
    static func specialPayload(_ kind: RecoveryDocumentKind) throws -> (RecoveryDocument, RecoveryResult) {
        guard
            let path = Bundle.main.url(
                forResource: kind == .exam ? "recovery-exam" : "recovery-return", withExtension: "json")
        else { throw PDFParseError(code: .storage) }
        let period = SchoolDataPeriod.current()
        let month = period.half == 1 ? "04" : "10"
        let json = try String(contentsOf: path, encoding: .utf8)
            .replacingOccurrences(of: "2026-10-", with: "\(period.schoolYear)-\(month)-")
            .replacingOccurrences(of: "10月", with: period.half == 1 ? "4月" : "10月")
            .replacingOccurrences(of: "10/", with: period.half == 1 ? "4/" : "10/")
            .replacingOccurrences(of: "2026", with: String(period.schoolYear))
        var payload = try JSONDecoder().decode(SpecialPayload.self, from: Data(json.utf8))
        payload.result.metadata.validatorVersion = RecoveryValidator.version
        payload.document.structureMetadata?.validatorVersion = RecoveryValidator.version
        return (payload.document, payload.result)
    }
    static func seed(_ base: URL) throws {
        if ProcessInfo.processInfo.arguments.contains("--recovery-exam")
            || ProcessInfo.processInfo.arguments.contains("--recovery-return")
        {
            let kind: RecoveryDocumentKind =
                ProcessInfo.processInfo.arguments.contains("--recovery-exam") ? .exam : .return
            let special: SpecialScheduleKind = kind == .exam ? .exam : .examReturn
            let store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite"))
            let (document, _) = try specialPayload(kind)
            let width = document.sources.map { $0.box.x + $0.box.width }.max()! + 30
            let height = document.sources.map { $0.box.y + $0.box.height }.max()! + 30
            let raw = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: width, height: height)).pdfData
            { context in
                for page in Set(document.sources.map(\.page)).sorted() {
                    context.beginPage()
                    for source in document.sources where source.page == page {
                        (source.text as NSString).draw(
                            at: CGPoint(x: source.box.x, y: source.box.y),
                            withAttributes: [.font: UIFont.systemFont(ofSize: 8)])
                    }
                }
            }
            let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
            let staging = store.newStagingURL()
            try raw.write(to: staging)
            try store.saveSelection(
                staged: staging, kind: special, originalName: "fictional-recovery-\(kind.rawValue).pdf",
                byteCount: raw.count, digest: digest)
            try store.recordFailure(PDFParseError(code: .ambiguous), kind: special)
            return
        }
        let library = try LocalMaterialDatabase.openLibrary(
            root: base.appendingPathComponent("SchoolMaterialsSQLite"))
        let (document, _) = payload()
        let raw = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 650, height: 950)).pdfData {
            context in
            context.beginPage()
            for source in document.sources {
                (source.text as NSString).draw(
                    at: CGPoint(x: source.box.x, y: source.box.y),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            }
        }
        let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        let staging = library.newStagingURL()
        try raw.write(to: staging)
        try library.commit(
            staged: staging, kind: .timetable, source: .init(grant: nil, childName: nil),
            originalName: "fictional-recovery.pdf", byteCount: raw.count, digest: digest, modifiedAt: nil)
        try library.recordPDFFailure(PDFParseError(code: .ambiguous), kind: .timetable)
    }
    static func preview(_ kind: RecoveryDocumentKind) async throws -> RecoveryPreview {
        let app = ApplicationData.shared
        let selected =
            kind == .timetable
            ? await app.materials.recoverySource()
            : await app.specialSchedules.recoverySource(kind == .exam ? .exam : .examReturn)
        guard let source = selected else { throw PDFParseError(code: .storage) }
        if kind != .timetable {
            var (document, result) = try specialPayload(kind)
            document.pdfHash = source.digest
            result.pdfHash = source.digest
            let validation = RecoveryValidator.validate(document, result)
            guard validation.canAdopt else {
                throw NSError(
                    domain: "SyntheticRecoveryPreview", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: validation.errors.joined(separator: ",")])
            }
            return RecoveryPreview(document: document, result: result, source: source)
        }
        var (document, result) = payload()
        document.pdfHash = source.digest
        result.pdfHash = source.digest
        let validation = RecoveryValidator.validate(document, result)
        guard validation.canAdopt else {
            throw NSError(
                domain: "SyntheticRecoveryPreview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: validation.errors.joined(separator: ",")])
        }
        return RecoveryPreview(document: document, result: result, source: source)
    }
}
struct FixtureRecoveryProbe: View {
    @ObservedObject private var model = ApplicationData.shared.materials
    @ObservedObject private var specials = ApplicationData.shared.specialSchedules
    var body: some View {
        let adopted: Bool = {
            if ProcessInfo.processInfo.arguments.contains("--recovery-exam") {
                return specials.records[.exam]?.analysis.recovery != nil
            }
            if ProcessInfo.processInfo.arguments.contains("--recovery-return") {
                return specials.records[.examReturn]?.analysis.recovery != nil
            }
            return model.state.pdfAnalyses?[MaterialKind.timetable.rawValue]?.recovery != nil
        }()
        Text(adopted ? "確認後に正式採用済み" : "前回の正式結果を保持")
            .font(.caption2).accessibilityIdentifier("fixture-recovery-formal")
            .allowsHitTesting(false)
    }
}
