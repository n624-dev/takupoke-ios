import XCTest
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
@testable import TakupokeParsing

// Entirely invented geometry/values. No PDF, OCR, providers or private input.
final class RecoveryRecertificationTests: XCTestCase {
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
    private let acceptedAt = Date(timeIntervalSince1970: 1_776_340_800)

    private func accepted(_ document: RecoveryDocument, _ result: RecoveryResult) throws -> RecoveryAdopted {
        RecoveryAdopted(document: document, result: result, acceptance: RecoveryAcceptance(
            pdfHash: document.pdfHash, resultHash: try RecoveryValidator.fingerprint(result),
            scopeHash: try RecoveryValidator.fingerprint(document), metadata: result.metadata, acceptedAt: acceptedAt))
    }
    private func oldGood(structured: Bool = false) throws -> RecoveryAdopted {
        var (d,r) = fixture()
        r.metadata.validatorVersion = 4; r.metadata.promptVersion = "4"
        if structured { d.structureMetadata = r.metadata }
        return try accepted(d,r)
    }
    private func source(_ hash: String) -> RecoverySelectedSource {
        RecoverySelectedSource(kind: .timetable, url: URL(fileURLWithPath: "/fictional-unused.pdf"),
            digest: hash, originalName: "fictional.pdf", storedName: "fictional.pdf",
            period: SchoolDataPeriod(day: SchoolDate(iso8601: "2026-04-16")!))
    }
    private func projection(_ adopted: RecoveryAdopted) throws -> PDFAnalysis {
        var d = adopted.document, r = adopted.result
        r.metadata.validatorVersion = RecoveryValidator.version
        if d.structureMetadata != nil { d.structureMetadata!.validatorVersion = RecoveryValidator.version }
        var analysis = try RecoveryConversion.timetable(RecoveryPreview(document: d, result: r, source: source(d.pdfHash)))
        analysis.version = 23; analysis.recovery = adopted; analysis.parsedAt = adopted.acceptance.acceptedAt
        return analysis
    }

    func testLegalOldConfirmationCarriesForwardExactlyWithoutAnotherConfirmation() throws {
        for structured in [false,true] {
            let old = try oldGood(structured: structured)
            XCTAssertFalse(try RecoveryValidator.canReuse(old.acceptance,document:old.document,result:old.result))
            let current = try XCTUnwrap(RecoveryValidator.recertify(old,hash:old.document.pdfHash))
            var expected = old
            expected.result.metadata.validatorVersion = 5
            if expected.document.structureMetadata != nil { expected.document.structureMetadata!.validatorVersion = 5 }
            expected.previousAcceptance = old.acceptance
            expected.acceptance = RecoveryAcceptance(pdfHash:old.document.pdfHash,
                resultHash:try RecoveryValidator.fingerprint(expected.result), scopeHash:try RecoveryValidator.fingerprint(expected.document),
                metadata:expected.result.metadata, acceptedAt:old.acceptance.acceptedAt)
            XCTAssertEqual(current,expected)
            XCTAssertTrue(try RecoveryValidator.canReuse(current.acceptance,document:current.document,result:current.result))
            XCTAssertEqual(current.acceptance.acceptedAt,acceptedAt)
            XCTAssertEqual(current.previousAcceptance,old.acceptance)
            XCTAssertEqual(try RecoveryValidator.recertify(current,hash:current.document.pdfHash),current)
            XCTAssertEqual(try JSONDecoder().decode(RecoveryAdopted.self,from:JSONEncoder().encode(current)),current)
        }
    }

    func testFixedAndScopedInlineCompoundCannotRetainOldOrForgedCurrentConfirmation() throws {
        for scoped in [false,true] {
            for version in [4,5] {
                var (d,r) = scoped ? roleFixture() : fixture()
                for (id,text) in [("subject","架空科目A・架空科目B"),("room","架空教室A・架空教室B")] {
                    d.sources[d.sources.firstIndex { $0.id == id }!].text = text
                }
                r.cells[0].lessons[0].subject.value = "架空科目A・架空科目B"
                r.cells[0].lessons[0].room.value = "架空教室A・架空教室B"
                r.metadata.validatorVersion = version
                let validation = RecoveryValidator.validate(d,r)
                XCTAssertTrue(validation.errors.contains("parallelLessons"))
                XCTAssertTrue(Set(validation.errors).isSubset(of: ["versions","parallelLessons"]))
                let bad = try accepted(d,r)
                XCTAssertNil(try RecoveryValidator.recertify(bad,hash:d.pdfHash))
                XCTAssertFalse(RecoveryValidator.previouslyAccepted(bad,hash:d.pdfHash))
            }
        }
    }

    func testStaleAcceptanceFingerprintsCannotRecertifyChangedSourceOrResult() throws {
        let old = try oldGood()
        for mutation in 0..<7 {
            var bad = old
            switch mutation {
            case 0: bad.acceptance.pdfHash = String(repeating:"b",count:64)
            case 1: bad.acceptance.resultHash = String(repeating:"b",count:64)
            case 2: bad.acceptance.scopeHash = String(repeating:"b",count:64)
            case 3: bad.acceptance.metadata.modelId = "fictional-tampered-model"
            case 4: bad.document.sources[1].text = "架空改変科目"
            case 5: bad.result.cells[0].lessons[0].subject.value = "架空改変科目"
            default: bad.previousAcceptance = old.acceptance
            }
            XCTAssertNil(try RecoveryValidator.recertify(bad,hash:old.document.pdfHash),"mutation \(mutation)")
        }
        XCTAssertNil(try RecoveryValidator.recertify(old,hash:String(repeating:"b",count:64)))
    }

    func testCurrentCertificateMustStillProveItsOriginalConfirmation() throws {
        let old = try oldGood(structured:true)
        let current = try XCTUnwrap(RecoveryValidator.recertify(old,hash:old.document.pdfHash))
        for mutation in 0..<3 {
            var bad = current
            if mutation == 0 { bad.previousAcceptance!.scopeHash = String(repeating:"b",count:64) }
            else if mutation == 1 { bad.previousAcceptance!.acceptedAt.addTimeInterval(1) }
            else { bad.previousAcceptance!.metadata.promptVersion = "fictional-tampered-prompt" }
            // The current fingerprint gate alone still passes; consent ancestry must also pass.
            XCTAssertTrue(try RecoveryValidator.canReuse(bad.acceptance,document:bad.document,result:bad.result))
            XCTAssertNil(try RecoveryValidator.recertify(bad,hash:bad.document.pdfHash))
        }
    }

    func testHistoricallyImpossibleDistinctMetadataCannotInventOldConfirmation() throws {
        var old = try oldGood(structured:true)
        old.document.structureMetadata!.provider = "fictional-structure-provider"
        old.document.structureMetadata!.promptVersion = "3"
        old = try accepted(old.document,old.result)
        XCTAssertNil(try RecoveryValidator.recertify(old,hash:old.document.pdfHash))
    }

    func testCurrentIndependentStructureAndFieldHistoriesAreRetainedExactly() throws {
        var (d,r) = fixture()
        r.metadata.promptVersion = "4"
        var structure = r.metadata
        structure.provider = "fictional-structure-provider"; structure.modelId = "fictional-structure-model"
        structure.modelVersion = "2"; structure.runtimeVersion = "fictional-structure-runtime"; structure.promptVersion = "3"
        d.structureMetadata = structure
        XCTAssertEqual(RecoveryValidator.validate(d,r).errors,[])
        let current = try accepted(d,r)
        XCTAssertEqual(try RecoveryValidator.recertify(current,hash:d.pdfHash),current)
        XCTAssertEqual(current.document.structureMetadata,structure)
        XCTAssertEqual(current.result.metadata,r.metadata)
        for badField in [false,true] {
            var bad = current
            if badField { bad.result.metadata.runtimeVersion = "" }
            else { bad.document.structureMetadata!.validatorVersion = 4 }
            bad = try accepted(bad.document,bad.result)
            XCTAssertNil(try RecoveryValidator.recertify(bad,hash:d.pdfHash))
        }
    }

    func testUnconfirmedOldPreviewCannotBecomeAcceptedThroughConversion() throws {
        let old = try oldGood()
        let preview = RecoveryPreview(document:old.document,result:old.result,source:source(old.document.pdfHash))
        XCTAssertThrowsError(try RecoveryConversion.adopted(preview)) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.ambiguous)
        }
        XCTAssertFalse(RecoveryValidator.previouslyAccepted(nil,hash:old.document.pdfHash))
    }

    func testOlderAndFutureVersionsCannotTakeTheExplicitFourToFiveTransition() throws {
        let old = try oldGood()
        for version in [3,6] {
            var result = old.result; result.metadata.validatorVersion = version
            let other = try accepted(old.document,result)
            XCTAssertNil(try RecoveryValidator.recertify(other,hash:old.document.pdfHash))
        }
    }

    func testFormalProjectionMustBeIdenticalBeforeMetadataOnlyUpgrade() throws {
        let old = try oldGood(structured:true), original = try projection(old)
        let current = try XCTUnwrap(RecoveryValidator.recertifiedTimetable(original,hash:old.document.pdfHash))
        XCTAssertEqual(current.version,25)
        XCTAssertEqual(current.lessons,original.lessons)
        XCTAssertEqual(current.parsedAt,original.parsedAt)
        XCTAssertEqual(current.notices,original.notices)
        XCTAssertEqual(current.recovery?.previousAcceptance,old.acceptance)
        for mutation in 0..<7 {
            var bad = original
            switch mutation {
            case 0: bad.lessons[0].names = TimetableLessonNames(subject:"架空改変科目",teacher:bad.lessons[0].names.teacher,room:bad.lessons[0].names.room)
            case 1: bad.lessons[0].sourceText = "架空改変原文"
            case 2: bad.lessons[0].period = 2
            case 3: bad.schoolYear = 2027
            case 4: bad.term = "後期"
            case 5: bad.parsedAt.addTimeInterval(1)
            default: bad.sourceDigest = String(repeating:"b",count:64)
            }
            XCTAssertNil(try RecoveryValidator.recertifiedTimetable(bad,hash:old.document.pdfHash),"mutation \(mutation)")
        }
    }

    func testLibraryAutomaticallyPersistsSameHashRecertificationAndReloadsWithoutPreview() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-recertify-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let bytes = Data("entirely fictional inert stored bytes, never parsed as PDF".utf8)
        let hash = SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
        var old = try oldGood(structured:true)
        old.document.pdfHash = hash; old.result.pdfHash = hash; old = try accepted(old.document,old.result)
        let original = try projection(old)
        let library = try MaterialLibrary(root:root)
        let staged = library.newStagingURL(); try bytes.write(to:staged)
        try library.commit(staged:staged,kind:.timetable,source:MaterialSource(),originalName:"fictional.pdf",byteCount:bytes.count,digest:hash,modifiedAt:nil)
        var state = library.state; state.pdfAnalyses = ["timetable":original]
        state.pdfParseAttempts = ["timetable":PDFParseAttempt(date:acceptedAt,sourceDigest:hash,failure:nil,parserVersion:23)]
        try library.persist(state)

        let reopened = try MaterialLibrary(root:root) // The actual initialization handoff recertifies, no user adoption call.
        let current = try XCTUnwrap(reopened.state.pdfAnalyses?["timetable"])
        XCTAssertEqual(current.version,25); XCTAssertEqual(current.lessons,original.lessons)
        XCTAssertEqual(current.recovery?.previousAcceptance,old.acceptance)
        XCTAssertEqual(current.recovery?.acceptance.acceptedAt,acceptedAt)
        XCTAssertNil(reopened.state.pdfParseAttempts?["timetable"]?.recoveryJob)
        XCTAssertEqual(reopened.state.pdfParseAttempts?["timetable"]?.parserVersion,25)
        XCTAssertEqual(try Data(contentsOf:try XCTUnwrap(reopened.localURL(for:.timetable))),bytes)
        let again = try MaterialLibrary(root:root)
        XCTAssertEqual(try RecoveryValidator.fingerprint(again.state.pdfAnalyses),try RecoveryValidator.fingerprint(reopened.state.pdfAnalyses))
    }

    func testDisplayFiltersRejectedRecoveryWithoutDeletingAuditAndPreservesStrictResults() throws {
        let old = try oldGood(), original = try projection(old)
        var bad = original; bad.recovery!.acceptance.scopeHash = String(repeating:"b",count:64)
        var state = MaterialLibraryState(); state.pdfAnalyses = ["timetable":bad]
        let filtered = MaterialLibrary.displayableTimetables(state)
        XCTAssertEqual(filtered.rejected,["timetable"])
        XCTAssertNil(filtered.state.pdfAnalyses?["timetable"])
        XCTAssertEqual(try RecoveryValidator.fingerprint(state.pdfAnalyses?["timetable"]),try RecoveryValidator.fingerprint(bad))
        state.pdfAnalyses = ["timetable":original]
        let valid = MaterialLibrary.displayableTimetables(state)
        XCTAssertTrue(valid.rejected.isEmpty)
        XCTAssertEqual(valid.state.pdfAnalyses?["timetable"]?.recovery?.previousAcceptance,old.acceptance)
        var strict = original; strict.recovery = nil
        state.pdfAnalyses = ["timetable":strict]
        let untouched = MaterialLibrary.displayableTimetables(state)
        XCTAssertTrue(untouched.rejected.isEmpty)
        XCTAssertEqual(try RecoveryValidator.fingerprint(untouched.state.pdfAnalyses),try RecoveryValidator.fingerprint(state.pdfAnalyses))
    }

    func testPreparedUpgradeCannotReplaceConfirmationChangedBeforeSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-recertify-handoff-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let bytes = Data("fictional inert stored bytes".utf8)
        let hash = SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
        var old = try oldGood(); old.document.pdfHash = hash; old.result.pdfHash = hash; old = try accepted(old.document,old.result)
        let original = try projection(old)
        let candidate = try XCTUnwrap(RecoveryValidator.recertifiedTimetable(original,hash:hash))
        let library = try MaterialLibrary(root:root)
        let staged = library.newStagingURL(); try bytes.write(to:staged)
        try library.commit(staged:staged,kind:.timetable,source:MaterialSource(),originalName:"fictional.pdf",byteCount:bytes.count,digest:hash,modifiedAt:nil)
        var replacement = original
        replacement.recovery!.acceptance.acceptedAt.addTimeInterval(1)
        replacement.parsedAt = replacement.recovery!.acceptance.acceptedAt
        var state = library.state; state.pdfAnalyses = ["timetable":replacement]; try library.persist(state)
        // Certification preceded a deterministic change of saved consent.
        // No concurrent sleeps; Save must reread its current commit point.
        XCTAssertThrowsError(try library.savePDFAnalysis(candidate)) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.storage)
        }
        XCTAssertEqual(try RecoveryValidator.fingerprint(library.state),try RecoveryValidator.fingerprint(state))
        XCTAssertEqual(try Data(contentsOf:try XCTUnwrap(library.localURL(for:.timetable))),bytes)
    }

    func testFailedPersistenceDoesNotMutateLastGoodOrConfirmation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("takupoke-recertify-failure-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        var reject = false
        let library = try MaterialLibrary(root:root,writeManifest:{ data,url in
            if reject { throw MaterialError.invalidState }; try data.write(to:url,options:.atomic)
        })
        let bytes = Data("fictional inert stored bytes".utf8)
        let hash = SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
        var old = try oldGood(); old.document.pdfHash = hash; old.result.pdfHash = hash; old = try accepted(old.document,old.result)
        let original = try projection(old)
        let staged = library.newStagingURL(); try bytes.write(to:staged)
        try library.commit(staged:staged,kind:.timetable,source:MaterialSource(),originalName:"fictional.pdf",byteCount:bytes.count,digest:old.document.pdfHash,modifiedAt:nil)
        var state = library.state; state.pdfAnalyses = ["timetable":original]; try library.persist(state)
        let before = try Data(contentsOf:root.appendingPathComponent("library.json"))
        reject = true
        XCTAssertThrowsError(try library.recertifyAcceptedTimetable(hash:old.document.pdfHash))
        XCTAssertEqual(try RecoveryValidator.fingerprint(library.state),try RecoveryValidator.fingerprint(state))
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("library.json")),before)
    }
    func testOldOCRConfirmationCannotAcquireCoverageFromMetadata() throws {
        for version in [4,5] {
            var (doc,result)=fixture()
            for i in doc.sources.indices { doc.sources[i].fromOcr=true }
            result.metadata.validatorVersion=version
            let old=try accepted(doc,result)
            XCTAssertTrue(RecoveryValidator.validate(doc,result).errors.contains("ocrCoverage"))
            XCTAssertFalse(try RecoveryValidator.canReuse(old.acceptance,document:doc,result:result))
            XCTAssertNil(try RecoveryValidator.recertify(old,hash:doc.pdfHash))
            let decoded=try JSONDecoder().decode(RecoveryDocument.self,from:JSONEncoder().encode(doc))
            XCTAssertNil(decoded.ocrCoverageProof) // Old optional absence remains absence.
        }
    }
    func testOCRProofIsBoundToAcceptanceAndCannotBeFilledIntoAnOldAudit() throws {
        var (doc,result)=fixture()
        for i in doc.sources.indices { doc.sources[i].fromOcr=true }
        let old=try accepted(doc,result)
        // A shape-valid marker is not permission to rewrite an old scope fingerprint.
        doc.ocrCoverageProof=RecoveryOCRCoverageProof(version:1,pages:[RecoveryOCRCoveragePage(page:1,width:700,height:1000,grayscaleSHA256:String(repeating:"b",count:64))])
        XCTAssertFalse(try RecoveryValidator.canReuse(old.acceptance,document:doc,result:result))
        var forged=old; forged.document=doc
        XCTAssertNil(try RecoveryValidator.recertify(forged,hash:doc.pdfHash))
        for mutation in 0..<7 {
            var invalid=doc
            switch mutation {
            case 0: invalid.ocrCoverageProof!.version=2
            case 1: invalid.ocrCoverageProof!.pages=[]
            case 2: invalid.ocrCoverageProof!.pages.append(invalid.ocrCoverageProof!.pages[0])
            case 3: invalid.ocrCoverageProof!.pages[0].page=2
            case 4: invalid.ocrCoverageProof!.pages[0].grayscaleSHA256="not-a-hash"
            case 5: invalid.ocrCoverageProof!.pages[0].width=1
            default: invalid.sources[0].fromOcr=false
            }
            XCTAssertTrue(RecoveryValidator.validate(invalid,result).errors.contains("ocrCoverage"),"mutation \(mutation)")
        }
    }

    func testAcquisitionCacheRechecksUnprovedOCRWhileKeepingVectorConfirmation() throws {
        let vector=try oldGood(), original=try projection(vector)
        XCTAssertTrue(RecoveryConversion.trustsAcquisitionCache(original,hash:vector.document.pdfHash))
        var ocr=vector
        for i in ocr.document.sources.indices { ocr.document.sources[i].fromOcr=true }
        ocr.result.metadata.validatorVersion=RecoveryValidator.version
        ocr=try accepted(ocr.document,ocr.result)
        var stale=original; stale.version=PDFAnalysis.parserVersion; stale.recovery=ocr
        XCTAssertFalse(RecoveryConversion.trustsAcquisitionCache(stale,hash:ocr.document.pdfHash))
        let trusted=RecoveryConversion.trustsAcquisitionCache(stale,hash:ocr.document.pdfHash) ? stale:nil
        XCTAssertTrue(PDFParseAttempt.needsAnalysis(digest:ocr.document.pdfHash,parserVersion:PDFAnalysis.parserVersion,
            analysisDigest:trusted?.sourceDigest,analysisVersion:trusted?.version,attemptDigest:ocr.document.pdfHash,failure:nil,attemptVersion:PDFAnalysis.parserVersion))
        var state=MaterialLibraryState(); state.pdfAnalyses=["timetable":stale]
        let hidden=MaterialLibrary.displayableTimetables(state)
        XCTAssertEqual(hidden.rejected,["timetable"]); XCTAssertNil(hidden.state.pdfAnalyses?["timetable"])
        XCTAssertEqual(try RecoveryValidator.fingerprint(state.pdfAnalyses?["timetable"]),try RecoveryValidator.fingerprint(stale))
        XCTAssertThrowsError(try RecoveryConversion.timetable(RecoveryPreview(document:ocr.document,result:ocr.result,source:source(ocr.document.pdfHash))))
        var strict=stale; strict.recovery=nil
        XCTAssertTrue(RecoveryConversion.trustsAcquisitionCache(strict,hash:strict.sourceDigest))
        let special=SpecialScheduleAnalysis(kind:.exam,sourceDigest:ocr.document.pdfHash,sourceName:"fictional",parsedAt:acceptedAt,
            schoolYear:2026,coveredDates:["2026-04-01"],coveredClasses:["3_CN"],periodTimes:[:],lessons:[])
        XCTAssertTrue(RecoveryConversion.trustsAcquisitionCache(special,hash:special.sourceDigest))
        var unprovedSpecial=special; unprovedSpecial.recovery=ocr
        XCTAssertFalse(RecoveryConversion.trustsAcquisitionCache(unprovedSpecial,hash:special.sourceDigest))
        XCTAssertTrue(PDFParseAttempt.needsAnalysis(digest:special.sourceDigest,parserVersion:SpecialScheduleAnalysis.parserVersion,
            analysisDigest:nil,analysisVersion:nil,attemptDigest:special.sourceDigest,failure:nil,attemptVersion:SpecialScheduleAnalysis.parserVersion))
    }

}
