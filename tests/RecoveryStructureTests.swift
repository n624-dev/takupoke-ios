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
        let input:RecoveryStructurePreparation
        do { _ = try RecoveryDocumentBuilder.build([foldedPage()],kind:.timetable,hash:String(repeating:"b",count:64)); XCTFail("requires structure proposal"); return }
        catch let value as RecoveryStructurePreparation { input = value }
        let provider = StructureProvider([]), fallback = StructureProvider([])
        provider.failure = PDFParseError(code:.limit); fallback.id = "coreAI"
        do {
            _ = try await RecoveryStructure.resolve(input,providers:[provider,fallback],os:"ios",osMajor:27,check:{})
            XCTFail("Resource limit retried a runtime")
        } catch let error as PDFParseError { XCTAssertEqual(error.code,.limit) }
        XCTAssertEqual(provider.calls,1); XCTAssertEqual(fallback.availabilityCalls,0)
    }
    func testFoldedInterleavedLabelProposalRebuildsOriginalAtomsBeforeValidation() async throws {
        let page = foldedPage(),hash = String(repeating:"a",count:64)
        let input:RecoveryStructurePreparation
        do { _ = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash); XCTFail("requires finite structure proposal"); return }
        catch let request as RecoveryStructurePreparation { input=request }
        XCTAssertEqual(input.requests.count,1)
        let request = try XCTUnwrap(input.requests.first)
        XCTAssertNil(RecoveryStructure.cheap(request))
        let provider = StructureProvider(try proposal(request))
        let resolution = try await RecoveryStructure.resolve(input,providers:[provider],os:"ios",osMajor:26,check:{})
        XCTAssertEqual(provider.calls,1)
        var doc = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash,structureProposals:try XCTUnwrap(resolution.proposals))
        doc.structureMetadata = resolution.metadata
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let result = try XCTUnwrap(run.result), lesson = try XCTUnwrap(result.cells.first { $0.lessons.first?.subject.value == "架空科目A" }?.lessons.first)
        XCTAssertEqual(lesson.teacher.value,"架空担当B"); XCTAssertEqual(lesson.room.value,"架空室C")
        XCTAssertEqual(result.metadata.provider,"systemLanguageModel"); XCTAssertEqual(result.metadata.recoveryVersion,"2")
        XCTAssertEqual(RecoveryValidator.validate(doc,result).errors,[])
        var wrong = result; wrong.metadata.provider="rule"
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
        let hash=String(repeating:"b",count:64),input:RecoveryStructurePreparation
        do { _ = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash); XCTFail("requires structural proposals"); return }
        catch let preparation as RecoveryStructurePreparation { input=preparation }
        XCTAssertEqual(input.requests.count,2)
        let proposals = try Dictionary(uniqueKeysWithValues:input.requests.map { ($0.id,try proposal($0)) })
        let doc = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:hash,structureProposals:proposals)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let cell = try XCTUnwrap(run.result?.cells.first { $0.lessons.count == 2 && $0.lessons.first?.subject.value == "架空科目A" })
        XCTAssertEqual(cell.lessons.map { $0.teacher.value },["架空担当B","架空担当B"])
    }
    func testInvalidCoverageOrHeaderStopsBeforeProviderAvailabilityOrGeneration() async throws {
        let page=foldedPage(),input:RecoveryStructurePreparation
        do { _ = try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"a",count:64)); XCTFail("requires structural proposal"); return }
        catch let preparation as RecoveryStructurePreparation { input=preparation }
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
}
