import Foundation
import XCTest
@testable import TakupokeParsing

extension PDFParsingTests {
    private func foldedPage(interleaved:Bool = true) -> PDFPageLayout {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
        page.glyphs += text("科目:",x:102,y:108,step:2)+text("架空科目A",x:118,y:108,step:2)
        page.glyphs += text("担当教",x:102,y:120,step:2)
        page.glyphs += text("員:",x:102,y:interleaved ? 132:126,step:2)
        page.glyphs += text("架空担当B",x:118,y:interleaved ? 126:120,step:2)
        page.glyphs += text("教室:",x:102,y:150,step:2)+text("架空室C",x:118,y:150,step:2)
        return page
    }
    /// Immutable, entirely fictional preparation captured before the bounded
    /// rule was extended. Provider contract tests still exercise a real pending
    /// request without disabling Rules or removing any validation evidence.
    private func preparedStructureInput() throws -> RecoveryStructurePreparation {
        struct Unit:Decodable { var id:String;var glyphs:[PDFGlyph];var box:RecoveryBox }
        struct Request:Decodable { var id:String;var page:Int;var box:RecoveryBox;var slots:[RecoverySlot];var units:[Unit];var cuts:[RecoveryStructureCut] }
        struct Snapshot:Decodable { var document:RecoveryDocument;var requests:[Request] }
        let url=try XCTUnwrap(Bundle.module.url(forResource:"recovery-folded-preparation",withExtension:"json",subdirectory:"fixtures"))
        let value=try JSONDecoder().decode(Snapshot.self,from:Data(contentsOf:url))
        return RecoveryStructurePreparation(document:value.document,requests:value.requests.map {
            RecoveryStructureRequest(id:$0.id,page:$0.page,box:$0.box,slots:$0.slots,units:$0.units.map {
                RecoveryStructureUnit(id:$0.id,glyphs:$0.glyphs,box:$0.box)
            },cuts:$0.cuts)
        })
    }
    private func proposal(_ request:RecoveryStructureRequest) throws -> [RecoveryLesson] {
        func field(_ parts:[String]) throws -> RecoveryField {
            let units = try parts.map { part in try XCTUnwrap(request.units.first { $0.text == part }) }
            let b = try RecoveryStructure.bounds(units.flatMap(\.glyphs))
            let top = try XCTUnwrap(request.cuts.last { $0.axis == "horizontal" && $0.position <= b.y })
            let bottom = try XCTUnwrap(request.cuts.first { $0.axis == "horizontal" && $0.position >= b.y+b.height })
            let left = try XCTUnwrap(request.cuts.first { $0.axis == "vertical" && $0.position >= b.x+b.width })
            return RecoveryField(state:.present,value:"",evidence:units.map(\.id)+[top.id,bottom.id,left.id])
        }
        return [RecoveryLesson(subject:try field(["科目:"]),teacher:try field(["担当教","員:"]),room:try field(["教室:"]),dateEvidence:[],periodEvidence:[])]
    }
    private final class StructureProvider:LocalRecoveryProvider, @unchecked Sendable {
        var id="systemLanguageModel"; var localOnly=true; var calls=0; var availabilityCalls=0
        var metadata=RecoveryMetadata(provider:"systemLanguageModel",modelId:"synthetic-guided-probe",modelVersion:"1",runtimeVersion:"test",promptVersion:"3",recoverySchemaVersion:RecoveryValidator.schemaVersion,validatorVersion:RecoveryValidator.version,osVersion:"test")
        var failure:Error?
        var answer:[RecoveryLesson]
        init(_ answer:[RecoveryLesson]) { self.answer=answer }
        func availability() async throws -> LocalProviderState { availabilityCalls += 1; return .ready }
        func recoverCell(_ cell:RecoveryPromptCell) async throws -> [RecoveryLesson] {
            XCTAssertEqual(cell.mode,.structureProposal); XCTAssertFalse(cell.structureCuts.isEmpty)
            calls += 1; if let failure { throw failure }; return answer
        }
    }
    func testStructureResourceLimitDoesNotLoadAnotherRuntime() async throws {
        let input=try preparedStructureInput()
        let provider = StructureProvider([]), fallback = StructureProvider([])
        provider.failure = PDFParseError(code:.limit); fallback.id = "coreAI"
        do {
            _ = try await RecoveryStructure.resolve(input,providers:[provider,fallback],os:"ios",osMajor:27,check:{})
            XCTFail("Resource limit retried a runtime")
        } catch let error as PDFParseError { XCTAssertEqual(error.code,.limit) }
        XCTAssertEqual(provider.calls,1); XCTAssertEqual(fallback.availabilityCalls,0)
    }
    func testFoldedInterleavedLabelsUseBoundedRulesBeforeProviders() async throws {
        let page=foldedPage(),hash=String(repeating:"a",count:64)
        let immutable=try preparedStructureInput(),request=try XCTUnwrap(immutable.requests.first)
        let provider=StructureProvider(try proposal(request))
        XCTAssertNotNil(RecoveryStructure.cheap(request))
        let doc=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash)
        let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[provider],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let result=try XCTUnwrap(run.result),lesson=try XCTUnwrap(result.cells.first { $0.lessons.first?.subject.value == "架空科目A" }?.lessons.first)
        XCTAssertEqual(lesson.teacher.value,"架空担当B");XCTAssertEqual(lesson.room.value,"架空室C")
        XCTAssertEqual(result.metadata.provider,"rule")
        XCTAssertEqual(result.metadata.modelVersion,"3");XCTAssertEqual(result.metadata.runtimeVersion,"3")
        XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        XCTAssertEqual(provider.calls,0);XCTAssertEqual(provider.availabilityCalls,0)
    }
    func testImmutablePreparedRequestStillValidatesProviderStructureMetadata() async throws {
        let input=try preparedStructureInput(),request=try XCTUnwrap(input.requests.first)
        let provider=StructureProvider(try proposal(request))
        provider.metadata.promptVersion = "4" // fieldExtraction uses the new shared instruction.
        let resolution=try await RecoveryStructure.resolve(input,providers:[provider],os:"ios",osMajor:26,check:{})
        XCTAssertEqual(provider.calls,1);XCTAssertEqual(resolution.state,.awaitingConfirmation)
        XCTAssertEqual(provider.metadata.promptVersion,"4")
        XCTAssertEqual(resolution.metadata?.promptVersion,"3")
        XCTAssertEqual(resolution.metadata?.recoveryVersion,"2")
        var doc=try RecoveryDocumentBuilder.build([foldedPage()],kind:.timetable,hash:input.document.pdfHash,structureProposals:try XCTUnwrap(resolution.proposals))
        doc.structureMetadata=resolution.metadata
        let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        let result=try XCTUnwrap(run.result)
        XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        var wrong=result;wrong.metadata.provider="rule"
        XCTAssertTrue(RecoveryValidator.validate(doc,wrong).errors.contains("structureMetadata"))
    }
    func testFoldedLabelsInTwoPhysicalParallelBandsPreserveLessonPairing() async throws {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
        page.lines.append(h(130,100,140))
        func small(_ value:String,x:Double,y:Double) -> [PDFGlyph] {
            text(value,x:x,y:y,step:2).map { g in var glyph=g; glyph.y=y-1; glyph.height=2; return glyph }
        }
        for start in [100.0,130.0] {
            page.glyphs += small("科目:",x:102,y:start+4)+small("架空科目A",x:118,y:start+4)
            page.glyphs += small("担当教",x:102,y:start+10)+small("員:",x:102,y:start+18)
            page.glyphs += small("架空担当B",x:118,y:start+14)
            page.glyphs += small("教室:",x:102,y:start+25)+small("架空室C",x:118,y:start+25)
        }
        let hash=String(repeating:"b",count:64)
        let doc=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let cell = try XCTUnwrap(run.result?.cells.first { $0.lessons.count == 2 && $0.lessons.first?.subject.value == "架空科目A" })
        XCTAssertEqual(cell.lessons.map { $0.teacher.value },["架空担当B","架空担当B"])
    }
    func testInvalidCoverageOrHeaderStopsBeforeProviderAvailabilityOrGeneration() async throws {
        let input=try preparedStructureInput()
        let provider = StructureProvider(try proposal(input.requests[0]))
        for coverage in [true,false] {
            var invalid=input
            if coverage { invalid.document.classes.removeLast() }
            else { invalid.document.cells[0].dayRegion?.axis = .left }
            let resolution = try await RecoveryStructure.resolve(invalid,providers:[provider],os:"ios",osMajor:26,check:{})
            XCTAssertEqual(resolution.state,.failed)
        }
        XCTAssertEqual(provider.calls,0); XCTAssertEqual(provider.availabilityCalls,0)
    }
    func testAdjacentWrappedLabelRemainsCheapRulesOnly() async throws {
        let doc = try RecoveryDocumentBuilder.build([foldedPage(interleaved:false)],kind:.timetable,hash:String(repeating:"b",count:64))
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation); XCTAssertEqual(run.result?.metadata.provider,"rule")
    }
    func testStructureProposalRejectsInventedCoordinatesSwappedLabelAndMissingOriginalBody() throws {
        let p = foldedPage(),grid = PDFGrid(page:p)
        let request = try RecoveryStructure.request(id:"c",page:1,box:RecoveryBox(x:100,y:100,width:40,height:60),slots:[RecoverySlot(className:"3_CN",day:"1",period:1)],glyphs:grid.glyphs(in:PDFBox(left:100,top:100,right:140,bottom:160)))
        var answer = try proposal(request)
        XCTAssertNoThrow(try RecoveryStructure.verify(request,answer))
        answer[0].teacher.evidence[answer[0].teacher.evidence.count-1]="x999"
        XCTAssertThrowsError(try RecoveryStructure.verify(request,answer))
        answer=try proposal(request); let original=answer[0].subject; answer[0].subject=answer[0].teacher; answer[0].teacher=original
        XCTAssertThrowsError(try RecoveryStructure.verify(request,answer))
        var orphan=request; orphan.units.append(RecoveryStructureUnit(id:"orphan",glyphs:text("未読",x:118,y:141,step:2),box:RecoveryBox(x:118,y:138,width:4,height:6)))
        XCTAssertThrowsError(try RecoveryStructure.verify(orphan,try proposal(request)))
    }
    func testBoundedLabelRulesRejectUnknownLabelsAndOverlappingRoleFootprints() throws {
        let input=try preparedStructureInput(),request=try XCTUnwrap(input.requests.first)
        XCTAssertNotNil(RecoveryStructure.cheap(request))
        var unknown=request
        let index=try XCTUnwrap(unknown.units.firstIndex { $0.text == "担当教" })
        unknown.units[index].glyphs[0].text="未"
        XCTAssertNil(RecoveryStructure.cheap(unknown))
        var overlapping=request
        let roomIndex=try XCTUnwrap(overlapping.units.firstIndex { $0.text == "教室:" })
        let teacherIndex=try XCTUnwrap(overlapping.units.firstIndex { $0.text == "担当教" })
        overlapping.units[roomIndex].box.y=overlapping.units[teacherIndex].box.y
        for i in overlapping.units[roomIndex].glyphs.indices { overlapping.units[roomIndex].glyphs[i].y=overlapping.units[teacherIndex].box.y }
        XCTAssertNil(RecoveryStructure.cheap(overlapping))
        var missing=request;missing.units.removeAll { $0.text == "員:" }
        XCTAssertNil(RecoveryStructure.cheap(missing))
        var orphan=request
        orphan.units.append(RecoveryStructureUnit(id:"unknown-left",glyphs:text("未読",x:102,y:141,step:2),box:RecoveryBox(x:102,y:138,width:4,height:6)))
        XCTAssertNil(RecoveryStructure.cheap(orphan))
    }
    func testBoundedLabelRulesPropagateLimitsAndInnerCancellation() throws {
        let input=try preparedStructureInput(),request=try XCTUnwrap(input.requests.first)
        var oversized=request
        while oversized.units.count <= 64 {
            var unit=oversized.units.last!;unit.id="extra-\(oversized.units.count)";oversized.units.append(unit)
        }
        XCTAssertThrowsError(try RecoveryStructure.cheap(oversized,check:{})) { XCTAssertEqual(($0 as? PDFParseError)?.code,.limit) }
        var checks=0
        XCTAssertThrowsError(try RecoveryStructure.cheap(request,check:{ checks += 1;if checks == 3 { throw PDFParseError(code:.cancelled) } })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,3)
    }
    func testBoundedLabelRulesRespectTheBuildersSharedWorkBudget() throws {
        let input=try preparedStructureInput(),request=try XCTUnwrap(input.requests.first)
        let work=RecoveryValidationWork()
        XCTAssertNotNil(try RecoveryStructure.cheap(request,work:work))
        // Finish the remaining shared budget, then prove a second request cannot
        // reset it and continue candidate enumeration in the same document.
        while work.charge(1024) {}
        XCTAssertThrowsError(try RecoveryStructure.cheap(request,work:work)) { XCTAssertEqual(($0 as? PDFParseError)?.code,.limit) }
    }
    func testBoundedLabelRulesUseMeasuredCutsIndependentOfInputOrdering() throws {
        let input=try preparedStructureInput(),request=try XCTUnwrap(input.requests.first)
        var reordered=request;reordered.units.reverse();reordered.cuts.reverse()
        let answer=try XCTUnwrap(RecoveryStructure.cheap(reordered))
        XCTAssertNoThrow(try RecoveryStructure.verify(reordered,answer))
        XCTAssertEqual(answer[0].teacher.evidence.prefix(2),try proposal(request)[0].teacher.evidence.prefix(2))
        var noInteriorRail=request;noInteriorRail.cuts.removeAll { $0.axis == "vertical" && $0.position > request.box.x && $0.position < request.box.x+request.box.width }
        XCTAssertNil(RecoveryStructure.cheap(noInteriorRail))
    }

}

extension SpecialScheduleTests {
    func testExamAndReturnInterleavedLabelsUseBoundedRulesWithCompleteCoverage() async throws {
        func folded(x:Double,y:Double) -> [PDFGlyph] {
            func text(_ value:String,_ dx:Double,_ dy:Double) -> [PDFGlyph] {
                value.enumerated().map { PDFGlyph(text:String($0.element),x:x+dx+Double($0.offset),y:y+dy,width:1,height:2) }
            }
            return text("科目:",1,2)+text("架空科目Z",14,2)+text("担当教",1,8)+text("架空教員Y",14,11)+text("員:",1,14)+text("教室:",1,20)+text("架空室X",14,20)
        }
        for kind:RecoveryDocumentKind in [.exam,.return] {
            var pages=kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            let x=140.0,y=kind == .exam ? 110.0:120.0,height=kind == .exam ? 40.0:25.0
            pages[0].glyphs.removeAll { x < $0.cx && $0.cx < x+40 && y < $0.cy && $0.cy < y+height }
            pages[0].glyphs += folded(x:x,y:y)
            let doc=try RecoveryDocumentBuilder.build(pages,kind:kind,hash:String(repeating:"c",count:64))
            XCTAssertEqual(Set(doc.classes),Set(RecoveryValidator.specialClasses));XCTAssertEqual(doc.days.count,5)
            let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
            let result=try XCTUnwrap(run.result),lesson=try XCTUnwrap(result.cells.first { $0.lessons.first?.subject.value == "架空科目Z" }?.lessons.first)
            XCTAssertEqual(lesson.teacher.value,"架空教員Y");XCTAssertEqual(lesson.room.value,"架空室X")
            XCTAssertEqual(result.metadata.provider,"rule");XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        }
    }
}
