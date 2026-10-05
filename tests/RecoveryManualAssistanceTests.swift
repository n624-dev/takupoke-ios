import Foundation
import XCTest
@testable import TakupokeParsing

extension PDFParsingTests {
    func testManualInputIdenticalRebindPreservesThreeIndividualAcknowledgements() {
        var values=["room":"架空室一","subject":"架空科目二","teacher":"架空教員三"]
        var acknowledged=Dictionary(uniqueKeysWithValues:values.keys.map { ($0,true) })
        for id in ["room","subject","teacher","room","subject"] {
            RecoveryManualInput.update(values[id]!,id:id,original:"旧架空本文",values:&values,acknowledged:&acknowledged)
        }
        XCTAssertEqual(acknowledged.count,3)
        XCTAssertTrue(acknowledged.values.allSatisfy { $0 })
        RecoveryManualInput.update("架空科目改",id:"subject",original:"旧架空本文",values:&values,acknowledged:&acknowledged)
        XCTAssertEqual(values["subject"],"架空科目改")
        XCTAssertEqual(acknowledged,["room":true,"subject":false,"teacher":true])
    }
    func testManualInputRawUnicodeChangeRequiresNewAcknowledgement() {
        var values=["subject":"Ae\u{301}"]
        var acknowledged=["subject":true]
        RecoveryManualInput.update("Aé",id:"subject",original:"",values:&values,acknowledged:&acknowledged)
        XCTAssertEqual(Array(values["subject"]!.utf8),Array("Aé".utf8))
        XCTAssertEqual(acknowledged["subject"],false)
        acknowledged["subject"]=true
        RecoveryManualInput.update("Aé",id:"subject",original:"",values:&values,acknowledged:&acknowledged)
        XCTAssertEqual(acknowledged["subject"],true)
        RecoveryManualInput.update("",id:"subject",original:"",values:&values,acknowledged:&acknowledged)
        XCTAssertEqual(acknowledged["subject"],false)
    }

    private func manualFixture(lowCount:Int = 1, lowHeader:Bool = false) throws -> RecoveryDocument {
        let (page,raster) = try twoClassRasterCoverage()
        let hash = String(repeating:"a",count:64)
        let doc = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash,fromOCR:[1],rasters:[1:raster])
        let groups = Dictionary(grouping:page.glyphs,by:{ $0.sourceLine! })
        let eligible = groups.keys.sorted().filter { key in
            let g = groups[key]!.first!
            return g.x >= 83 && g.x <= 99 && g.y >= 102 && g.y <= 134
        }
        let low = lowHeader ? Set([0]) : Set(eligible.prefix(lowCount))
        let lines = groups.keys.sorted().map { key -> RecoveryOCRLine in
            let glyphs = groups[key]!.sorted { $0.sourceOrder! < $1.sourceOrder! }
            return RecoveryOCRLine(nativeOrder:key,candidates:[RecoveryOCRCandidate(text:glyphs.map(\.text).joined(),confidence:low.contains(key) ? 0.4:0.95,
                characters:glyphs.map { RecoveryOCRCharacter(text:$0.text,range:RecoveryOCRRange(x:$0.x,y:$0.y,width:$0.width,height:$0.height)) })])
        }
        let capture = RecoveryOCRAcquisitionDraft(sourcePDFHash:hash,documentPageCount:1,requiredOCRPages:[1],
            pages:[RecoveryOCRPage(page:1,width:Int(page.width),height:Int(page.height),nativeDocumentCount:1,lines:lines,captureComplete:true)])
        return try RecoveryManualAssistance.attaching(capture,to:doc)
    }

    func testManualOneTwoThreeFieldsReachFormalConversionWithSeparateHumanProvenance() throws {
        for count in 1...3 {
            let doc = try manualFixture(lowCount:count)
            let draft = try XCTUnwrap(RecoveryManualAssistance.prepare(doc,os:"test"))
            XCTAssertEqual(draft.fields.count,count)
            let values = Dictionary(uniqueKeysWithValues:draft.fields.map { ($0.id,"架空手入力"+$0.target.role.rawValue) })
            let result = try RecoveryManualAssistance.complete(draft,values:values,now:Date(timeIntervalSince1970:1770000000))
            XCTAssertTrue(RecoveryValidator.validate(doc,result).canAdopt)
            XCTAssertEqual(result.humanCorrections?.count,count)
            XCTAssertEqual(draft.document.sources,doc.sources)
            XCTAssertEqual(draft.document.nativeCapture,doc.nativeCapture)
            XCTAssertEqual(result.metadata.provider,"rule") // Human overlay is never credited as native/model output.
            let source = RecoverySelectedSource(kind:.timetable,url:URL(fileURLWithPath:"/fictional-unused.pdf"),digest:doc.pdfHash,originalName:"fictional",storedName:"",period:SchoolDataPeriod(day:SchoolDate(year:2032,month:4,day:1)!))
            let formal = try RecoveryConversion.timetable(RecoveryPreview(document:doc,result:result,source:source))
            XCTAssertEqual(formal.lessons.count,80)
            XCTAssertEqual(formal.recovery?.result.humanCorrections,result.humanCorrections)
            let decoded = try JSONDecoder().decode(RecoveryAdopted.self,from:JSONEncoder().encode(try XCTUnwrap(formal.recovery)))
            XCTAssertEqual(decoded.document.nativeCapture,doc.nativeCapture)
            XCTAssertEqual(decoded.result.humanCorrections,result.humanCorrections)
            XCTAssertTrue(try RecoveryValidator.canReuse(decoded.acceptance,document:decoded.document,result:decoded.result))
        }
    }
    func testManualFourthFieldAndAnyHeaderUncertaintyAreTerminal() throws {
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(manualFixture(lowCount:4),os:"test"))
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(manualFixture(lowHeader:true),os:"test"))
    }
    func testManualPendingRawLowConfidenceCannotBeAdoptedWithoutCorrections() async throws {
        let doc = try manualFixture(lowCount:1)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.failed)
        XCTAssertNil(run.result)
        XCTAssertTrue(run.errors.contains("manualMissing"))
    }
    func testManualPrintedFieldCannotBecomeBlankOrPartialOverlay() throws {
        let draft = try XCTUnwrap(RecoveryManualAssistance.prepare(manualFixture(lowCount:2),os:"test"))
        var values = Dictionary(uniqueKeysWithValues:draft.fields.map { ($0.id,$0.originalText) })
        values[draft.fields[0].id] = ""
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:values))
        values.removeValue(forKey:draft.fields[0].id)
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:values))
    }
    func testManualEverySourceHashSnapshotParentCropAndTargetIsBound() throws {
        let doc = try manualFixture(lowCount:1), draft = try XCTUnwrap(RecoveryManualAssistance.prepare(doc,os:"test"))
        let result = try RecoveryManualAssistance.complete(draft,values:[draft.fields[0].id:"架空確認科目"])
        let original = try XCTUnwrap(result.humanCorrections?.first)
        for mutation in 0..<8 {
            var changed = result
            changed.humanCorrections = [RecoveryHumanCorrection(schemaVersion:mutation == 0 ? 2:original.schemaVersion,
                target:mutation == 1 ? RecoveryManualTarget(cellId:original.target.cellId,lessonIndex:original.target.lessonIndex,role:.room):original.target,
                pdfHash:mutation == 2 ? String(repeating:"b",count:64):original.pdfHash,
                acquisitionHash:mutation == 3 ? String(repeating:"b",count:64):original.acquisitionHash,
                documentSnapshotHash:mutation == 4 ? String(repeating:"b",count:64):original.documentSnapshotHash,
                page:original.page,parentSourceIds:mutation == 5 ? []:original.parentSourceIds,
                crop:mutation == 6 ? RecoveryBox(x:0,y:0,width:1,height:1):original.crop,
                value:mutation == 7 ? "架空改変":original.value,provenance:.user,confirmedAt:original.confirmedAt)]
            XCTAssertFalse(RecoveryValidator.validate(doc,changed).canAdopt,"mutation \(mutation)")
        }
        var duplicate = result; duplicate.humanCorrections = [original,original]
        XCTAssertFalse(RecoveryValidator.validate(doc,duplicate).canAdopt)
        var changedDoc = doc; changedDoc.sources[0].text += "架空変更"
        XCTAssertFalse(RecoveryValidator.validate(changedDoc,result).canAdopt)
    }
    func testManualIncompleteCaptureAndMissingCoverageCannotOfferItems() throws {
        let original = try manualFixture()
        var missing = original; missing.ocrCoverageProof = nil
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(missing,os:"test"))
        let capture = try XCTUnwrap(original.nativeCapture), page = capture.pages[0]
        var incomplete = original
        incomplete.nativeCapture = RecoveryOCRAcquisitionDraft(sourcePDFHash:capture.sourcePDFHash,documentPageCount:1,requiredOCRPages:[1],
            pages:[RecoveryOCRPage(page:1,width:page.width,height:page.height,nativeDocumentCount:page.nativeDocumentCount,lines:page.lines,captureComplete:false)])
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(incomplete,os:"test"))
        var changed = original; changed.pdfHash = String(repeating:"b",count:64)
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(changed,os:"test"))
    }
    func testManualCancellationPropagatesBeforeDraftOrOverlay() throws {
        let doc = try manualFixture()
        var checks = 0
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(doc,os:"test",check:{ checks += 1; if checks == 3 { throw PDFParseError(code:.cancelled) } })) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled)
        }
        let draft = try XCTUnwrap(RecoveryManualAssistance.prepare(doc,os:"test"))
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:[draft.fields[0].id:"架空確認"],check:{ throw PDFParseError(code:.cancelled) })) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled)
        }
    }
    func testManualCorrectedUTF16BoundAndExplicitTimestampAreEnforced() throws {
        let draft = try XCTUnwrap(RecoveryManualAssistance.prepare(manualFixture(),os:"test")), key = draft.fields[0].id
        let boundary = String(repeating:"🧪",count:128)
        XCTAssertNoThrow(try RecoveryManualAssistance.complete(draft,values:[key:boundary]))
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:[key:boundary+"A"]))
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:[key:"架空確認"],now:Date(timeIntervalSince1970:0)))
        XCTAssertThrowsError(try RecoveryManualAssistance.complete(draft,values:[key:"架空確認"],now:Date(timeIntervalSince1970:.nan)))
    }
    func testManualFullFieldParentsPreserveOriginalOrderAndNativeConfidence() throws {
        var doc = try manualFixture()
        let lowLine = try XCTUnwrap(doc.nativeCapture?.assess().lowConfidenceNativeOrders[1]?.first)
        let sourceIndex = try XCTUnwrap(doc.sources.firstIndex { $0.fromOcr && $0.sourceLine == lowLine })
        let original = doc.sources[sourceIndex]
        var head = original, tail = original
        head.text = "架"; head.box.width = 3
        tail.id += "-tail"; tail.text = "空科"; tail.box.x += 3; tail.box.width -= 3; tail.sourceOrder = (original.sourceOrder ?? 0)+1
        doc.sources[sourceIndex] = head; doc.sources.insert(tail,at:sourceIndex+1)
        let cellIndex = try XCTUnwrap(doc.cells.firstIndex { $0.id == original.cellId })
        doc.cells[cellIndex].sourceIds = doc.cells[cellIndex].sourceIds.flatMap { $0 == original.id ? [head.id,tail.id]:[$0] }
        doc.cells[cellIndex].lessonBindings[0].subject = [head.id,tail.id]
        let draft = try XCTUnwrap(RecoveryManualAssistance.prepare(doc,os:"test"))
        XCTAssertEqual(draft.fields[0].parentSourceIds,[head.id,tail.id])
        XCTAssertEqual(draft.fields[0].originalText,"架空科")
        let result = try RecoveryManualAssistance.complete(draft,values:[draft.fields[0].id:"架空確認科目"])
        XCTAssertEqual(result.humanCorrections?.first?.parentSourceIds,[head.id,tail.id])
        var reversed = doc; reversed.sources.swapAt(sourceIndex,sourceIndex+1)
        XCTAssertThrowsError(try RecoveryManualAssistance.prepare(reversed,os:"test"))
        var changedConfidence = doc; changedConfidence.sources[sourceIndex].nativeConfidence = 0.9
        XCTAssertFalse(RecoveryValidator.validate(changedConfidence,result).canAdopt)
    }
    func testManualEverySourceRequiresExactNativePageOrderAndConfidenceMembership() throws {
        let doc = try manualFixture(), draft = try XCTUnwrap(RecoveryManualAssistance.prepare(doc,os:"test"))
        let result = try RecoveryManualAssistance.complete(draft,values:[draft.fields[0].id:"架空確認"])
        for mutation in 0..<5 {
            var changed = doc
            switch mutation {
            case 0: changed.sources[0].sourceLine = 999999
            case 1: changed.sources[0].sourceLine = nil
            case 2: changed.sources[0].nativeConfidence = nil
            case 3: changed.sources[0].nativeConfidence = .nan
            default: changed.sources[0].fromOcr = false
            }
            XCTAssertFalse(RecoveryValidator.validate(changed,result).canAdopt,"mutation \(mutation)")
        }
    }
    func testOptionalManualReceiptAbsencePreservesHistoricalJSON() async throws {
        let (page,raster) = try twoClassRasterCoverage()
        let doc = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"a",count:64),fromOCR:[1],rasters:[1:raster])
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        let result = try XCTUnwrap(run.result)
        let documentJSON = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(doc)) as? [String:Any])
        let resultJSON = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(result)) as? [String:Any])
        XCTAssertNil(documentJSON["nativeCapture"]); XCTAssertNil(resultJSON["humanCorrections"])
        XCTAssertTrue((documentJSON["sources"] as? [[String:Any]])?.allSatisfy { $0["nativeConfidence"] == nil } == true)
        var oldResult = result; oldResult.metadata.validatorVersion = 5
        let acceptance = RecoveryAcceptance(pdfHash:doc.pdfHash,resultHash:try RecoveryValidator.fingerprint(oldResult),scopeHash:try RecoveryValidator.fingerprint(doc),metadata:oldResult.metadata,acceptedAt:Date(timeIntervalSince1970:1770000000))
        let old = RecoveryAdopted(document:doc,result:oldResult,acceptance:acceptance)
        let recertified = try XCTUnwrap(RecoveryValidator.recertify(old,hash:doc.pdfHash))
        XCTAssertNil(recertified.document.nativeCapture); XCTAssertNil(recertified.result.humanCorrections)
        XCTAssertEqual(recertified.previousAcceptance,acceptance)
        XCTAssertEqual(recertified.acceptance.acceptedAt,acceptance.acceptedAt)
        var forged = doc; forged.sources[0].nativeConfidence = 0.95
        let forgedAcceptance = RecoveryAcceptance(pdfHash:doc.pdfHash,resultHash:try RecoveryValidator.fingerprint(oldResult),scopeHash:try RecoveryValidator.fingerprint(forged),metadata:oldResult.metadata,acceptedAt:acceptance.acceptedAt)
        XCTAssertNil(try RecoveryValidator.recertify(RecoveryAdopted(document:forged,result:oldResult,acceptance:forgedAcceptance),hash:doc.pdfHash))
    }
}
