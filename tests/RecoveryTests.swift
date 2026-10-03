import XCTest
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
@testable import TakupokeParsing

final class RecoveryTests: XCTestCase {
    private func fixture() -> (RecoveryDocument, RecoveryResult) {
        let slots = (1...5).flatMap { d in (1...8).map { RecoverySlot(className: "3_CN", day: String(d), period: $0) } }
        let box = RecoveryBox(x: 110, y: 110, width: 60, height: 10)
        var sources = [RecoverySource(id: "heading", cellId: "header", page: 1, text: "2026年度", box: RecoveryBox(x: 0, y: 0, width: 90, height: 10)),
                       RecoverySource(id: "subject", cellId: "c0", page: 1, text: "架空科目A", box: box),
                       RecoverySource(id: "teacher", cellId: "c0", page: 1, text: "架空教員A", box: box),
                       RecoverySource(id: "room", cellId: "c0", page: 1, text: "架空教室A", box: box)]
        sources.append(RecoverySource(id: "term", cellId: "header", page: 1, text: "前期", box: RecoveryBox(x: 0, y: 20, width: 40, height: 10)))
        sources.append(RecoverySource(id: "class", cellId: "header", page: 1, text: "3_CN", box: RecoveryBox(x: 10, y: 110, width: 20, height: 10)))
        for day in 1...5 { sources.append(RecoverySource(id: "day\(day)", cellId: "header", page: 1, text: ["月", "火", "水", "木", "金"][day - 1], box: RecoveryBox(x: Double(day * 100 + 10), y: 20, width: 60, height: 10))) }
        for period in 1...8 { sources.append(RecoverySource(id: "period\(period)", cellId: "header", page: 1, text: String(period), box: RecoveryBox(x: 50, y: Double(period * 100 + 10), width: 20, height: 10))) }
        let cells = slots.enumerated().map { i, slot in RecoveryCell(id: "c\(i)", page: 1, box: RecoveryBox(x: Double(Int(slot.day)! * 100), y: Double(slot.period * 100), width: 100, height: 100), inputState: .complete, slots: [slot], sourceIds: i == 0 ? ["subject", "teacher", "room"] : [], blankFields: [], confirmedEmpty: i != 0, classHeaderIds: ["class"], dayHeaderIds: ["day\(slot.day)"], periodHeaderIds: ["period\(slot.period)"], lessonBindings: i == 0 ? [RecoveryLessonBinding(subject: ["subject"], teacher: ["teacher"], room: ["room"])] : [], classRegion: RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: 0, y: 100, width: 40, height: 800), axis: .left), dayRegion: RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: Double(Int(slot.day)! * 100), y: 0, width: 100, height: 50), axis: .above), periodRegions: [String(slot.period): RecoveryHeaderRegion(page: 1, box: RecoveryBox(x: 40, y: Double(slot.period * 100), width: 40, height: 100), axis: .left)]) }
        let doc = RecoveryDocument(pdfHash: String(repeating: "a", count: 64), kind: .timetable, schoolYear: 2026, term: "前期", classes: ["3_CN"], days: (1...5).map(String.init), requiredSlots: slots, cells: cells, sources: sources, complete: true, yearEvidence: ["heading"], termEvidence: ["term"], dayEvidence: Dictionary(uniqueKeysWithValues: (1...5).map { (String($0), ["day\($0)"]) }), classEvidence: ["3_CN": ["class"]], periodEvidence: Dictionary(uniqueKeysWithValues: (1...8).map { (String($0), ["period\($0)"]) }), times: [:], timeEvidence: [], normalTimeNoteEvidence: [])
        let lesson = RecoveryLesson(subject: RecoveryField(state: .present, value: "架空科目A", evidence: ["subject"]), teacher: RecoveryField(state: .present, value: "架空教員A", evidence: ["teacher"]), room: RecoveryField(state: .present, value: "架空教室A", evidence: ["room"]), dateEvidence: ["day1"], periodEvidence: ["period1"])
        let result = RecoveryResult(pdfHash: doc.pdfHash, kind: doc.kind, schoolYear: 2026, term: "前期", cells: cells.enumerated().map { i, cell in RecoveredCell(cellId: cell.id, state: i == 0 ? .present : .empty, lessons: i == 0 ? [lesson] : []) }, metadata: RecoveryMetadata(provider: "rule", modelId: "rules", modelVersion: "1", runtimeVersion: "1", promptVersion: "1", recoverySchemaVersion: RecoveryValidator.schemaVersion, validatorVersion: RecoveryValidator.version, osVersion: "test"))
        return (doc, result)
    }
    private final class ProbeProvider: LocalRecoveryProvider {
        let id: String; var metadata: RecoveryMetadata; let localOnly = true
        var state: LocalProviderState = .ready; var availabilityCalls = 0; var recoveryCalls = 0
        init(_ id: String, _ metadata: RecoveryMetadata) { self.id = id; self.metadata = metadata; self.metadata.provider = id }
        func availability() async throws -> LocalProviderState { availabilityCalls += 1; return state }
        func recoverCell(_ cell: RecoveryPromptCell) async throws -> [RecoveryLesson] { recoveryCalls += 1; throw RecoveryProviderError.invalidOutput }
    }
    private func uncertain() -> RecoveryDocument { var (d, _) = fixture(); d.sources.removeAll { $0.id == "teacher" }; d.cells[0].sourceIds.removeAll { $0 == "teacher" }; d.cells[0].lessonBindings[0].teacher = []; return d }
    func testGroundedRulesDoNotLoadLanguageModel() async throws { let (d, r) = fixture(); let p = ProbeProvider("systemLanguageModel", r.metadata); let run = try await RecoveryEngine.run(d, os: "ios", osMajor: 27, foreground: true, providers: [p], rule: { _ in nil }, check: {}); XCTAssertEqual(run.state, .awaitingConfirmation); XCTAssertEqual(run.result?.metadata.provider, "rule"); XCTAssertEqual(p.availabilityCalls, 0) }
    func testModelNotReadyWaitsWithoutDownloadingFallback() async throws { let (_, r) = fixture(); let p = ProbeProvider("systemLanguageModel", r.metadata); p.state = .notReady; let fallback = ProbeProvider("coreAI", r.metadata); let run = try await RecoveryEngine.run(uncertain(), os: "ios", osMajor: 27, foreground: true, providers: [p, fallback], rule: { _ in nil }, check: {}); XCTAssertEqual(run.state, .awaitingModel); XCTAssertEqual(fallback.availabilityCalls, 0) }
    func testMalformedOutputIsTerminalBeforeNextProvider() async throws { let (_, r) = fixture(); let p = ProbeProvider("windowsLanguageModel", r.metadata); let fallback = ProbeProvider("foundryLocal", r.metadata); let run = try await RecoveryEngine.run(uncertain(), os: "windows", osMajor: 10, foreground: true, providers: [p, fallback], rule: { _ in nil }, check: {}); XCTAssertEqual(run.errors, ["invalidOutput"]); XCTAssertNil(run.result); XCTAssertEqual(fallback.availabilityCalls, 0) }
    func testCompleteGroundedResultCanBePreviewed() { let (d, r) = fixture(); XCTAssertEqual(RecoveryValidator.validate(d, r).errors, []) }
    func testUnknownIsNeverFreePeriod() { for state in [RecoveryValueState.unreadable, .missing, .ambiguous] { var (d, r) = fixture(); r.cells[0].state = state; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("cellState")) } }
    func testIncompleteReaderIsRejected() { var (d, r) = fixture(); d.complete = false; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("incompleteDocument")) }
    func testPartialCellIsRejected() { var (d, r) = fixture(); d.cells[0].inputState = .partial; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("incompleteCell")) }
    func testMissingSlotIsRejected() { var (d, r) = fixture(); d.cells.removeFirst(); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("coverage")) }
    func testMissingResultCellIsRejected() { var (d, r) = fixture(); r.cells.removeFirst(); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("resultCoverage")) }
    func testDuplicateIdsRejectWithoutThrowing() { var (d, r) = fixture(); d.sources.append(d.sources[0]); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("duplicateIds")) }
    func testNeighbourEvidenceIsRejected() { var (d, r) = fixture(); d.sources[3].cellId = "c1"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("sourcePosition")) }
    func testInventedValueIsRejected() { var (d, r) = fixture(); r.cells[0].lessons[0].room.value = "架空教室B"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("fieldEvidence")) }
    func testContentCannotBecomeEmpty() { var (d, r) = fixture(); r.cells[0].state = .empty; r.cells[0].lessons = []; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("falseEmpty")) }
    func testChangedYearIsRejected() { var (d, r) = fixture(); r.schoolYear = 2025; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("documentIdentity")) }
    func testChangedHashIsRejected() { var (d, r) = fixture(); r.pdfHash = String(repeating: "b", count: 64); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("sourceHash")) }
    func testWrongSchemaRejects() { var (d, r) = fixture(); r.metadata.recoverySchemaVersion = RecoveryValidator.schemaVersion + 1; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("versions")) }
    func testTemporaryNotReadyNeverTriggersDownloadFallback() { XCTAssertFalse(RecoveryPolicy.mayTryNext(.notReady)); XCTAssertFalse(RecoveryPolicy.mayTryNext(.disabled)); XCTAssertEqual(RecoveryPolicy.providers(os: "android"), ["liteRtLm"]) }
    func testRecoveryMetadataRoundTrips() throws { let (d, r) = fixture(); XCTAssertEqual(try JSONDecoder().decode(RecoveryResult.self, from: JSONEncoder().encode(r)), r); XCTAssertEqual(try JSONDecoder().decode(RecoveryDocument.self, from: JSONEncoder().encode(d)), d) }
    func testWrongHeaderTextIsRejected() { var (d, r) = fixture(); d.sources[d.sources.firstIndex { $0.id == "class" }!].text = "3_ES"; XCTAssertFalse(RecoveryValidator.validate(d, r).canAdopt) }
    func testFieldsCannotSwapRoles() { var (d, r) = fixture(); let l = r.cells[0].lessons[0]; r.cells[0].lessons[0].subject = l.teacher; r.cells[0].lessons[0].teacher = l.subject; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("fieldEvidence")) }
    func testTruncatedNamesAreRejected() { var (d, r) = fixture(); r.cells[0].lessons[0].teacher.value = "架空教"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("fieldEvidence")) }
    func testKnownTextCannotBecomeBlank() { var (d, r) = fixture(); d.cells[0].blankFields = ["teacher"]; r.cells[0].lessons[0].teacher = RecoveryField(state: .empty, value: "", evidence: []); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("falseBlankField")) }
    func testOverlappingCellsAreRejected() { var (d, r) = fixture(); d.cells[1].box = d.cells[0].box; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("cellOverlap")) }
    func testWrongHeadingAxisIsRejected() { var (d, r) = fixture(); d.cells[0].dayRegion?.axis = .left; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("dayBinding")) }
    func testOverflowingBoundsReject() { XCTAssertFalse(RecoveryBox(x: Double.greatestFiniteMagnitude, y: 1, width: Double.greatestFiniteMagnitude, height: 1).valid) }
    func testCancelledRuleRecoveryDoesNotReturnPreview() async {
        let (d, r) = fixture()
        do { _ = try await RecoveryEngine.run(d, os: "ios", osMajor: 26, foreground: true, providers: [], rule: { c in r.cells.first { $0.cellId == c.id } }, check: { throw PDFParseError(code: .cancelled) }); XCTFail("cancelled") }
        catch let e as PDFParseError { XCTAssertEqual(e.code, .cancelled) } catch { XCTFail("unexpected error") }
    }
    func testIncompleteAndCancelledAnalysisResumeButDefinitiveFailureDoesNotLoop() {
        func retry(_ analysisDigest: String?, _ version: Int?, _ failure: PDFParseError?, _ attempted: Int?) -> Bool { PDFParseAttempt.needsAnalysis(digest: "current", parserVersion: 8, analysisDigest: analysisDigest, analysisVersion: version, attemptDigest: "current", failure: failure, attemptVersion: attempted) }
        XCTAssertTrue(retry(nil, nil, PDFParseError(code: .storage), 8)); XCTAssertTrue(retry(nil, nil, nil, nil)); XCTAssertTrue(retry("old", 8, PDFParseError(code: .cancelled), 8))
        XCTAssertTrue(retry("current", 7, PDFParseError(code: .unsupported), 7)); XCTAssertFalse(retry("old", 8, PDFParseError(code: .unsupported), 8)); XCTAssertFalse(retry("current", 8, nil, 8))
    }
    func testSpecialScopeVersionRetriesSameHashEarlierSuccessfulAnalysis() {
        XCTAssertEqual(SpecialScheduleAnalysis.parserVersion,9)
        XCTAssertTrue(PDFParseAttempt.needsAnalysis(digest:"unchanged",parserVersion:SpecialScheduleAnalysis.parserVersion,
            analysisDigest:"unchanged",analysisVersion:8,attemptDigest:"unchanged",failure:nil,attemptVersion:8))
        XCTAssertFalse(PDFParseAttempt.needsAnalysis(digest:"unchanged",parserVersion:SpecialScheduleAnalysis.parserVersion,
            analysisDigest:"unchanged",analysisVersion:SpecialScheduleAnalysis.parserVersion,attemptDigest:"unchanged",failure:nil,
            attemptVersion:SpecialScheduleAnalysis.parserVersion))
    }
    func testRecoverySourceRequiresCurrentStrictFailureForSameDocument() {
        let version = SpecialScheduleAnalysis.parserVersion
        let job = RecoveryJob(pdfHash:"current",kind:.exam,state:.pending,createdAt:Date())
        func allowed(_ digest: String? = "current",_ attempt: Int? = nil,_ failure: PDFParseError? = PDFParseError(code:.unsupported),_ pending: RecoveryJob? = nil) -> Bool {
            RecoveryPolicy.mayRecover(digest:"current",kind:.exam,parserVersion:version,attemptDigest:digest,attemptVersion:attempt ?? version,failure:failure,job:pending ?? job)
        }
        XCTAssertTrue(allowed())
        XCTAssertFalse(allowed("old")); XCTAssertFalse(allowed("current",version-1)); XCTAssertFalse(allowed("current",version,nil))
        var wrong = job; wrong.kind = .return; XCTAssertFalse(allowed("current",version,PDFParseError(code:.unsupported),wrong))
        XCTAssertFalse(RecoveryPolicy.mayRecover(digest:"current",kind:.exam,parserVersion:version,attemptDigest:"current",attemptVersion:version,failure:PDFParseError(code:.unsupported),job:nil))
    }
    func testRecoveryDocumentCannotReplaceAnotherYearOrHalf() throws {
        var (document,result) = fixture()
        let first = SchoolDataPeriod(day:SchoolDate(iso8601:"2026-04-01")!), second = SchoolDataPeriod(day:SchoolDate(iso8601:"2026-10-01")!)
        XCTAssertTrue(RecoveryConversion.matchesPeriod(document,first)); XCTAssertFalse(RecoveryConversion.matchesPeriod(document,second))
        document.schoolYear = 2025; XCTAssertFalse(RecoveryConversion.matchesPeriod(document,first))
        let source = RecoverySelectedSource(kind:.timetable,url:URL(fileURLWithPath:"/fictional.pdf"),digest:document.pdfHash,originalName:"fictional.pdf",storedName:"fictional.pdf",period:first)
        XCTAssertThrowsError(try RecoveryConversion.timetable(RecoveryPreview(document:document,result:result,source:source)))
        let (exam,_) = try special()
        XCTAssertTrue(RecoveryConversion.matchesPeriod(exam,second)); XCTAssertFalse(RecoveryConversion.matchesPeriod(exam,first))
    }
    func testFixedBindingCannotHideAnExplicitRoleLabel() {
        var (d,r) = fixture()
        d.sources[d.sources.firstIndex { $0.id == "subject" }!].text = "教員:架空担当"
        r.cells[0].lessons[0].subject.value = "教員:架空担当"
        XCTAssertTrue(RecoveryValidator.validate(d,r).errors.contains("unboundRoleLabel"))
    }
    func testManifestRequiresKnownBackendAndMinimumOS() {
        var m = RecoveryModelManifest(modelId: "synthetic", version: "1", url: "https://models.example.invalid/model", size: 1, sha256: String(repeating: "a", count: 64), runtime: "llamaCpp", minimumOs: "26.1", minimumMemory: 1, recommendedBackend: "Metal", license: "test-only", validated: true)
        XCTAssertTrue(m.isUsable(runtime: "llamaCpp", availableMemory: 1)); XCTAssertFalse(m.supportsOs("26.0")); XCTAssertTrue(m.supportsOs("27")); m.recommendedBackend = "BOGUS"; XCTAssertFalse(m.isUsable(runtime: "llamaCpp", availableMemory: 1))
    }
    private struct SpecialFixture: Decodable { var document: RecoveryDocument; var result: RecoveryResult }
    private func special(_ kind: String = "exam") throws -> (RecoveryDocument, RecoveryResult) {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "recovery-" + kind, withExtension: "json", subdirectory: "fixtures"))
        let fixture = try JSONDecoder().decode(SpecialFixture.self, from: Data(contentsOf: url)); return (fixture.document, fixture.result)
    }
    func testSpecialSchedulesWithFullScopeAndExplicitSpanTimesPass() throws { for kind in ["exam", "return"] { let (d, r) = try special(kind); XCTAssertEqual(RecoveryValidator.validate(d, r).errors, [], kind) } }
    func testInventoryCannotDiscardTextToClaimEmpty() { var (d, r) = fixture(); d.cells[0].sourceIds = []; d.cells[0].lessonBindings = []; d.cells[0].confirmedEmpty = true; r.cells[0].state = .empty; r.cells[0].lessons = []; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("sourceInventory")) }
    func testUnassignedTextInBlankCellRejects() { var (d, r) = fixture(); d.sources.append(RecoverySource(id: "unassigned", cellId: "unassigned", page: d.cells[1].page, text: "架空の未割当文字", box: d.cells[1].box)); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("unassignedCellText")) }
    func testUnboundLiteralCannotBeClassifiedAsPeriodHeader() { var (d, r) = fixture(); d.sources.append(RecoverySource(id: "orphan", cellId: "unassigned", page: 1, text: "1", box: RecoveryBox(x: 650, y: 200, width: 10, height: 10))); d.periodEvidence["1"]?.append("orphan"); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("periodHeaderCoverage")) }
    func testUnusedSpanCannotClassifyOrphanAsClock() throws { var (d, r) = try special(); d.sources.append(RecoverySource(id: "orphan", cellId: "unassigned", page: 1, text: "架空の授業漏れ", box: RecoveryBox(x: 360, y: 200, width: 10, height: 10))); d.spanTimes["2026-10-02:3-4"] = "架空の授業漏れ"; d.clockEvidence["2026-10-02:3-4"] = ["orphan"]; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("clockScope")) }
    func testOrphanCannotBeHiddenInYearOrClassEvidence() { var (d, r) = fixture(); d.sources.append(RecoverySource(id: "orphan", cellId: "unassigned", page: 1, text: "架空の授業漏れ", box: RecoveryBox(x: 650, y: 200, width: 10, height: 10))); d.yearEvidence.append("orphan"); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("yearEvidenceText")); d.yearEvidence.removeLast(); d.classEvidence["3_CN"]?.append("orphan"); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("classEvidence")) }
    func testOrphanCannotBeHiddenInReturnNote() throws { var (d, r) = try special("return"); d.sources.append(RecoverySource(id: "orphan", cellId: "unassigned", page: 1, text: "架空の授業漏れ", box: RecoveryBox(x: 360, y: 200, width: 10, height: 10))); d.normalTimeNoteEvidence.append("orphan"); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("normalTimeNote")) }
    func testOrphanTextOutsideCellsRejects() { var (d, r) = fixture(); d.sources.append(RecoverySource(id: "orphan", cellId: "unassigned", page: 1, text: "架空の授業漏れ", box: RecoveryBox(x: 650, y: 200, width: 10, height: 10))); XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("unclassifiedSource")) }
    func testCommonClockCannotOverrideDateSpecificTime() throws { var (d, r) = try special(); let first = "2026-10-01:1", second = "2026-10-02:1"; d.times[second] = d.times[first]; d.clockEvidence[second] = d.clockEvidence[first]; d.clockBindings[second] = d.clockBindings[first]; d.clockBindings[second]?.day = "*"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("clockEvidence")) }
    func testAnotherDayClockCannotBeQuoted() throws { var (d, r) = try special(); let first = "2026-10-01:1", second = "2026-10-02:1"; d.times[first] = d.times[second]; d.clockEvidence[first] = d.clockEvidence[second]; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("clockEvidence")) }
    func testReversedSpanClockCannotPassEvenWhenTextExists() throws { var (d, r) = try special(); d.spanTimes["2026-10-01:1-2"] = "18:00〜08:00"; d.sources[d.sources.firstIndex { $0.id == "span-clock" }!].text = "18:00〜08:00"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("spanTimeEvidence")) }
    func testReturnNormalTimeRequiresActualApplicableNote() throws { var (d, r) = try special("return"); d.sources[d.sources.firstIndex { $0.id == "normal-note" }!].text = "架空の無関係な注記"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("normalTimeNote")) }
    func testSeventeenClassesCannotIncludeAnUnexpectedReplacement() throws { var (d, r) = try special(); d.classes[0] = "1_CN"; XCTAssertTrue(RecoveryValidator.validate(d, r).errors.contains("specialScope")) }
    #if canImport(CryptoKit) || canImport(Crypto)
    func testModelUpdateSameBytesRemovesOldVersionAndFailureKeepsActiveModel() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-model-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data("synthetic-model".utf8), store = RecoveryModelStore(root: root)
        func manifest(_ version: String) -> RecoveryModelManifest { RecoveryModelManifest(modelId: "synthetic", version: version, url: "https://models.example.invalid/model", size: Int64(bytes.count), sha256: SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), runtime: "llamaCpp", minimumOs: "26", minimumMemory: 1, recommendedBackend: "CPU", license: "test-only", validated: true) }
        let first = try await store.install(manifest("1"), runtime: "llamaCpp", availableMemory: 1, osSupported: true, foreground: true, openModel: { _ in InputStream(data: bytes) }, prepareAndSmokeTest: { _ in }, check: {})
        let second = try await store.install(manifest("2"), runtime: "llamaCpp", availableMemory: 1, osSupported: true, foreground: true, openModel: { _ in InputStream(data: bytes) }, prepareAndSmokeTest: { _ in }, check: {})
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        let pointer = root.appendingPathComponent("active.llamaCpp.json"), previous = try Data(contentsOf: pointer)
        var prepared = false, afterPreparation = 0
        do { _ = try await store.install(manifest("3"), runtime: "llamaCpp", availableMemory: 1, osSupported: true, foreground: true, openModel: { _ in InputStream(data: bytes) }, prepareAndSmokeTest: { _ in prepared = true }, check: { if prepared { afterPreparation += 1; if afterPreparation == 2 { throw CancellationError() } } }); XCTFail("cancelled") } catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf: pointer), previous); XCTAssertTrue(FileManager.default.fileExists(atPath: second.path)); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasSuffix(".model") }.count, 1)
        let abandoned = root.appendingPathComponent("staging-" + UUID().uuidString), other = root.appendingPathComponent("unrelated.txt")
        try bytes.write(to: abandoned); try bytes.write(to: other)
        try await store.cleanupAbandonedFiles(inUse: [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: second.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
        try await store.delete(runtime: "llamaCpp"); XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }
    func testCoreAIArchiveAndPreparedBundleSwitchTogetherAndCancelledUpdateKeepsBoth() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-coreai-store-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let bytes = Data("synthetic-coreai-archive".utf8), store = RecoveryModelStore(root:root)
        func manifest(_ version: String) -> RecoveryModelManifest {
            .init(modelId:"synthetic",version:version,url:"https://models.example.invalid/coreai",size:Int64(bytes.count),sha256:SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined(),runtime:"coreAI",minimumOs:"27",minimumMemory:1,recommendedBackend:"CPU",license:"test-only",validated:true)
        }
        func prepare(_ artifact: URL) throws {
            let bundle = artifact.appendingPathExtension("bundle")
            try FileManager.default.createDirectory(at:bundle.appendingPathComponent("tokenizer"),withIntermediateDirectories:true)
            try Data("{}".utf8).write(to:bundle.appendingPathComponent("metadata.json"))
            try Data("{}".utf8).write(to:bundle.appendingPathComponent("tokenizer/tokenizer.json"))
        }
        let first = try await store.install(manifest("1"),runtime:"coreAI",availableMemory:1,osSupported:true,foreground:true,openModel:{ _ in InputStream(data:bytes) },prepareAndSmokeTest:{ try prepare($0) },check:{})
        XCTAssertTrue(FileManager.default.fileExists(atPath:first.path))
        let active = try await store.active(runtime:"coreAI"); XCTAssertEqual(active?.1,first)
        let pointer = root.appendingPathComponent("active.coreAI.json"), oldPointer = try Data(contentsOf:pointer)
        var prepared = false
        do { _ = try await store.install(manifest("2"),runtime:"coreAI",availableMemory:1,osSupported:true,foreground:true,openModel:{ _ in InputStream(data:bytes) },prepareAndSmokeTest:{ try prepare($0); prepared = true },check:{ if prepared { throw CancellationError() } }); XCTFail("cancelled") } catch is CancellationError { }
        XCTAssertEqual(try Data(contentsOf:pointer),oldPointer)
        XCTAssertTrue(FileManager.default.fileExists(atPath:first.path))
        let second = try await store.install(manifest("3"),runtime:"coreAI",availableMemory:1,osSupported:true,foreground:true,openModel:{ _ in InputStream(data:bytes) },prepareAndSmokeTest:{ try prepare($0) },check:{})
        XCTAssertFalse(FileManager.default.fileExists(atPath:first.path)); XCTAssertTrue(FileManager.default.fileExists(atPath:second.path))
        try await store.cleanupAbandonedFiles(inUse:[])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:root.path).filter { $0.hasSuffix(".bundle") }.count,1)
        try await store.delete(runtime:"coreAI")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:root.path).isEmpty)
    }
    func testOriginalHashVerificationRejectsADataPeriodChangeDuringRead() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-period-hash-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:url) }
        let bytes = Data("entirely fictional PDF bytes".utf8); try bytes.write(to:url)
        let before = SchoolDataPeriod(day:SchoolDate(iso8601:"2032-09-30")!), after = SchoolDataPeriod(day:SchoolDate(iso8601:"2032-10-01")!)
        let source = RecoverySelectedSource(kind:.timetable,url:url,digest:SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined(),originalName:"fictional.pdf",storedName:"fictional.pdf",period:before,captured:[])
        var calls = 0
        XCTAssertThrowsError(try RecoveryConversion.verifyFile(source,currentPeriod:{ calls += 1; return calls == 1 ? before:after },check:{})) { error in
            XCTAssertEqual((error as? PDFParseError)?.code,.cancelled)
        }
        XCTAssertEqual(calls,2)
        XCTAssertNoThrow(try RecoveryConversion.verifyFile(source,currentPeriod:{ before },check:{}))
    }
    func testApprovalOnlyReusesExactValidatedResult() throws {
        var (d, r) = fixture()
        let a = RecoveryAcceptance(pdfHash: d.pdfHash, resultHash: try RecoveryValidator.fingerprint(r), scopeHash: try RecoveryValidator.fingerprint(d), metadata: r.metadata, acceptedAt: Date())
        XCTAssertTrue(try RecoveryValidator.canReuse(a, document: d, result: r)); r.metadata.modelVersion = "2"
        XCTAssertFalse(try RecoveryValidator.canReuse(a, document: d, result: r))
        r.metadata = a.metadata; d.cells[0].box.width -= 1
        XCTAssertFalse(try RecoveryValidator.canReuse(a, document: d, result: r))
    }
    #endif
    private func roleFixture() -> (RecoveryDocument,RecoveryResult) {
        var (d,r) = fixture()
        d.cells[0].bindingMode = .roleProposal; d.cells[0].lessonBindings = []
        for (index,role) in RecoveryRole.allCases.enumerated() {
            let source = ["subject","teacher","room"][index], y = 110.0+Double(index)*25
            d.sources[d.sources.firstIndex { $0.id == source }!].box = RecoveryBox(x:140,y:y,width:40,height:10)
            let label = RecoverySource(id:"label-"+source,cellId:"c0",page:1,text:role.labels[0]+":",box:RecoveryBox(x:110,y:y,width:20,height:10))
            d.sources.append(label); d.cells[0].sourceIds.append(label.id)
            d.cells[0].roleScopes.append(RecoveryRoleScope(lessonIndex:0,role:role,page:1,box:RecoveryBox(x:135,y:y-2,width:55,height:20),labelSourceIds:[label.id],labelRegion:RecoveryHeaderRegion(page:1,box:label.box,axis:.left),proof:.inlineLabel,emptyVerified:false))
        }
        r.metadata.provider = "systemLanguageModel"
        return (d,r)
    }
    func testUniqueRoleScopePartitionUsesRulesWithoutLoadingLocalAI() async throws {
        let (d,r) = roleFixture(), provider = ProbeProvider("systemLanguageModel",r.metadata)
        XCTAssertEqual(RecoveryValidator.inputErrors(d),[])
        XCTAssertNotNil(RecoveryRules.recover(d,d.cells[0]))
        let run = try await RecoveryEngine.run(d,os:"ios",osMajor:26,foreground:true,providers:[provider],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
        XCTAssertEqual(run.result?.cells[0].lessons.first?.subject.value,"架空科目A")
        XCTAssertEqual(run.result?.metadata.provider,"rule")
        XCTAssertEqual(provider.availabilityCalls,0); XCTAssertEqual(provider.recoveryCalls,0)
    }
    func testRoleProposalCannotSwapRolesOrOmitAnOriginalAtom() {
        let (d,r) = roleFixture()
        var swapped = r
        swapped.cells[0].lessons[0].subject = r.cells[0].lessons[0].teacher
        swapped.cells[0].lessons[0].teacher = r.cells[0].lessons[0].subject
        XCTAssertFalse(RecoveryValidator.validate(d,swapped).canAdopt)
        var omitted = r; omitted.cells[0].lessons[0].room = RecoveryField(state:.empty,value:"",evidence:[])
        XCTAssertFalse(RecoveryValidator.validate(d,omitted).canAdopt)
    }
    func testExternalColumnLabelIsStructuralEvidenceOutsideTheCell() {
        var (d,r) = roleFixture()
        for i in d.cells[0].roleScopes.indices {
            let labelId = d.cells[0].roleScopes[i].labelSourceIds[0], index = d.sources.firstIndex { $0.id == labelId }!
            d.sources[index].cellId = "header"; d.sources[index].box.x = 75
            d.cells[0].sourceIds.removeAll { $0 == labelId }
            d.cells[0].roleScopes[i].proof = .columnHeader
            d.cells[0].roleScopes[i].labelRegion.box = d.sources[index].box
        }
        XCTAssertEqual(RecoveryValidator.validate(d,r).errors,[])
        d.sources[d.sources.firstIndex { $0.id == "label-teacher" }!].text = "教室:"
        XCTAssertTrue(RecoveryValidator.validate(d,r).errors.contains("roleEvidence"))
    }
    func testFaintOrColoredUnrecognizedInkCannotProveAnEmptyRasterCell() throws {
        let box = RecoveryBox(x:0,y:0,width:40,height:40)
        let colors: [[UInt8]] = [[254,254,254,255],[255,255,254,255],[255,0,0,255],[255,255,0,255]]
        for color in colors {
            var pixels = [UInt8](repeating:255,count:40*40*4)
            pixels.replaceSubrange((20*40+20)*4..<(20*40+20)*4+4,with:color)
            let raster = try RecoveryRasterGrid.fromRGBA(width:40,height:40,pixels:pixels)
            XCTAssertFalse(raster.isBlank(box),"color \(color)")
            XCTAssertTrue(raster.hasUncoveredInk(box,text:[],rules:[]),"color \(color)")
        }
        let white = try RecoveryRasterGrid.fromRGBA(width:40,height:40,pixels:[UInt8](repeating:255,count:40*40*4))
        XCTAssertTrue(white.isBlank(box)); XCTAssertFalse(white.hasUncoveredInk(box,text:[],rules:[]))
        XCTAssertFalse(RecoveryRasterGrid(width:40,height:40,grayscale:[]).isBlank(box))
        XCTAssertTrue(RecoveryRasterGrid(width:40,height:40,grayscale:[]).hasUncoveredInk(box,text:[],rules:[]))
    }
    func testRasterRulesRetainLinesTouchingRightAndBottomEdge() throws {
        var bytes = [UInt8](repeating:255,count:50*50)
        for x in 0..<50 { bytes[x] = 0; bytes[10*50+x] = 0; bytes[49*50+x] = 0 }
        for y in 0..<50 { bytes[y*50] = 0; bytes[y*50+30] = 0; bytes[y*50+49] = 0 }
        let grid = RecoveryRasterGrid(width:50,height:50,grayscale:bytes), rules = try grid.rules(check:{})
        XCTAssertTrue(rules.contains { $0.horizontal && $0.y1 == 10 && $0.x2 == 49 })
        XCTAssertTrue(rules.contains { $0.vertical && $0.x1 == 30 && $0.y2 == 49 })
    }
    func testIsolatedOrDanglingCharacterStrokesCannotMaskUnrecognizedInk() throws {
        let box = RecoveryBox(x:0,y:0,width:80,height:80)
        for shape in ["horizontal","vertical","H"] {
            var bytes = [UInt8](repeating:255,count:80*80)
            if shape != "vertical" { for x in 10...60 { bytes[40*80+x] = 0 } }
            if shape != "horizontal" { for y in 10...65 { bytes[y*80+10] = 0 } }
            if shape == "H" { for y in 10...65 { bytes[y*80+60] = 0 } }
            let raster = RecoveryRasterGrid(width:80,height:80,grayscale:bytes), rules = try raster.rules(check:{})
            XCTAssertTrue(rules.isEmpty,shape)
            XCTAssertTrue(raster.hasUncoveredInk(box,text:[],rules:rules),shape)
        }
        var borderInk = [UInt8](repeating:255,count:80*80); borderInk[40*80+1] = 254
        let raster = RecoveryRasterGrid(width:80,height:80,grayscale:borderInk)
        XCTAssertFalse(raster.isBlank(box)); XCTAssertTrue(raster.hasUncoveredInk(box,text:[],rules:[]))
    }
    func testOCRUnrecognizedInkCannotBecomeAnEmptyField() {
        let box = RecoveryBox(x:0,y:0,width:40,height:40)
        var bytes = [UInt8](repeating:255,count:40*40); bytes[20*40+20] = 0
        let raster = RecoveryRasterGrid(width:40,height:40,grayscale:bytes)
        XCTAssertFalse(raster.isBlank(box)); XCTAssertTrue(raster.hasUncoveredInk(box,text:[RecoveryBox(x:5,y:5,width:5,height:5)],rules:[]))
    }
    func testConnectedBorderCannotHideOnePixelOfFaintContentBesideIt() throws {
        let size = 50, box = RecoveryBox(x:0,y:0,width:50,height:50)
        var bytes = [UInt8](repeating:255,count:size*size)
        for i in 0..<size { bytes[i] = 0; bytes[(size-1)*size+i] = 0; bytes[i*size] = 0; bytes[i*size+size-1] = 0 }
        let blank = RecoveryRasterGrid(width:size,height:size,grayscale:bytes), rules = try blank.rules(check:{})
        XCTAssertEqual(rules.count,4)
        XCTAssertTrue(try blank.preparingRules(rules).isBlank(box,rules:rules))
        for pixel in [size+20,20*size+1,(size-2)*size+20,20*size+size-2] {
            var changed = bytes; changed[pixel] = 254
            let raster = try RecoveryRasterGrid(width:size,height:size,grayscale:changed).preparingRules(rules)
            XCTAssertFalse(raster.isBlank(box,rules:rules)); XCTAssertTrue(raster.hasUncoveredInk(box,text:[],rules:rules))
        }
    }

}
