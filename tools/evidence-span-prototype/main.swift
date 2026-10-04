import Foundation
struct SpanExpected: Decodable { var parentId:String; var parentUtf8Sha256:String; var role:String; var labelStart:Int; var labelLength:Int; var bodyStart:Int; var bodyLength:Int; var bodyText:String }
struct SpanCase: Decodable { var name:String; var scene:SpanScene; var expectedError:String?; var expected:[SpanExpected]? }
struct SpanFixture: Decodable { var spec:String; var nativeCalls:Int; var cases:[SpanCase] }
struct Outcome: Codable { var name:String; var passed:Bool; var accepted:Bool?; var error:String?; var proofs:[SpanProof]? }
struct Report: Codable { var recipe:String; var fixtureSha256:String; var fixtureCases:Int; var testsPassed:Int; var testsFailed:Int; var nativeInferenceCalls:Int; var runtime:String; var scope:String; var results:[Outcome] }
func require(_ ok:Bool,_ reason:String) throws { if !ok { throw SpanRefusal(reason:reason) } }
let path=CommandLine.arguments.dropFirst().first ?? "shared-fixtures.json"
let data=try Data(contentsOf:URL(fileURLWithPath:path))
let actualHash=try sha256(data)
guard actualHash=="66ce1efcf4a415d70ec71e1eb5707ca665c91eba0f33d99a86d08dc54f59c43f" else { throw SpanRefusal(reason:"fixturePin") }
let fixture=try JSONDecoder().decode(SpanFixture.self,from:data)
var outcomes:[Outcome]=[]
for c in fixture.cases {
    do {
        let ps=try EvidenceSpans.build(c.scene)
        try require(c.expectedError==nil,"unexpectedAcceptance")
        guard let expected=c.expected else { throw SpanRefusal(reason:"missingExpected") }
        try require(ps.count==expected.count && ps.count==c.scene.parents.count,"proofCount")
        for (p,e) in zip(ps,expected) {
            try require(rawEqual(p.original.id,e.parentId) && rawEqual(p.role,e.role) && p.parentUtf8Sha256==e.parentUtf8Sha256,"parentRoleHash")
            try require(p.label.start==e.labelStart && p.label.length==e.labelLength && p.body.start==e.bodyStart && p.body.length==e.bodyLength && rawEqual(p.bodyText,e.bodyText),"expectedSpan")
            try require(p.label.start==0 && p.label.length==p.body.start && p.body.start+p.body.length==p.original.text.utf8.count,"fullCoverage")
            try require(Data(p.original.text.utf8).dropFirst(p.body.start)==Data(p.bodyText.utf8),"literalBody")
        }
        try require(try EvidenceSpans.verify(c.scene,proposed:ps),"canonicalVerify")
        outcomes.append(Outcome(name:c.name,passed:true,accepted:true,error:nil,proofs:ps))
    } catch {
        let reason=(error as? SpanRefusal)?.reason ?? String(describing:error)
        outcomes.append(Outcome(name:c.name,passed:c.expectedError==reason,accepted:false,error:reason,proofs:nil))
    }
}
func test(_ name:String,_ block:() throws -> Void) {
    do { try block(); outcomes.append(Outcome(name:name,passed:true,accepted:nil,error:nil,proofs:nil)) }
    catch { outcomes.append(Outcome(name:name,passed:false,accepted:nil,error:String(describing:error),proofs:nil)) }
}
let scene=fixture.cases[0].scene, good=try EvidenceSpans.build(scene)
func mutation(_ name:String,_ change:(inout [SpanProof])->Void) {
    test(name) { var p=good; change(&p); try require(!(try EvidenceSpans.verify(scene,proposed:p)),"tamperAccepted") }
}
mutation("verify-parent-array-order") { $0.reverse() }
mutation("verify-cut-inside-utf8") { $0[0].label.length=1 }
mutation("verify-gap") { $0[0].body.start+=1 }
mutation("verify-overlap") { $0[0].body.start-=1 }
mutation("verify-hash") { $0[0].parentUtf8Sha256=String(repeating:"0",count:64) }
mutation("verify-whole-box") { $0[0].original.wholeBox.width-=1 }
mutation("verify-native-order") { $0[0].original.sourceOrder=99 }
mutation("verify-body-repair") { $0[0].bodyText="架空修正" }
mutation("verify-reused-label") { $0[0].body=$0[0].label }
mutation("verify-missing-proof") { $0.removeLast() }
test("canonical-equivalent-identifiers-are-distinct") {
    var s=scene; s.parents[0].id="id-é"; s.parents[1].id="id-e\u{301}"
    let p=try EvidenceSpans.build(s)
    try require(p.count==3 && !rawEqual(p[0].original.id,p[1].original.id),"unicodeIDsCollapsed")
    try require(try EvidenceSpans.verify(s,proposed:p),"unicodeIDVerify")
}
test("canonical-equivalent-body-repair-refuses") {
    var s=scene; s.parents[0].text="科目:Ae\u{301}"
    var p=try EvidenceSpans.build(s); p[0].bodyText="Aé"
    try require(!(try EvidenceSpans.verify(s,proposed:p)),"normalizedBodyAccepted")
}
test("nonfinite-parent") {
    var s=scene; s.parents[0].wholeBox.x=Double.nan
    do { _=try EvidenceSpans.build(s); throw SpanRefusal(reason:"nonfiniteAccepted") }
    catch let e as SpanRefusal { try require(e.reason=="invalidParent","wrongNonfiniteFailure") }
}
test("cancel-build-and-verify") {
    for block in [{ _=try EvidenceSpans.build(scene,cancelled:{true}) }, { _=try EvidenceSpans.verify(scene,proposed:good,cancelled:{true}) }] {
        do { try block(); throw SpanRefusal(reason:"cancelIgnored") }
        catch let e as SpanRefusal { try require(e.reason=="cancelled","wrongCancelFailure") }
    }
}
test("shared-budget-no-refill-for-verification") {
    var low=1, high=100000
    while low<high {
        let mid=(low+high)/2
        do { _=try EvidenceSpans.build(scene,workLimit:mid); high=mid }
        catch let e as SpanRefusal { try require(e.reason=="workLimit","wrongBudgetFailure"); low=mid+1 }
    }
    do { _=try EvidenceSpans.verify(scene,proposed:good,workLimit:low); throw SpanRefusal(reason:"budgetRefilled") }
    catch let e as SpanRefusal { try require(e.reason=="workLimit","wrongVerifyBudgetFailure") }
}
test("identifier-cap") {
    var s=scene; s.parents[0].id=String(repeating:"x",count:129)
    do { _=try EvidenceSpans.build(s); throw SpanRefusal(reason:"idCapIgnored") }
    catch let e as SpanRefusal { try require(e.reason=="invalidParent","wrongIDFailure") }
}
test("null-transport-not-replaced") {
    let bytes=Data("{\"parents\":null,\"cells\":[],\"bands\":[],\"rules\":[]}".utf8)
    do { _=try JSONDecoder().decode(SpanScene.self,from:bytes); throw SpanRefusal(reason:"nullReplaced") }
    catch is DecodingError { }
}
test("unpaired-surrogate-transport-rejects") {
    let bytes=Data(#"{"id":"x","page":1,"text":"\uD800","wholeBox":{"x":0,"y":0,"width":1,"height":1}}"#.utf8)
    do { _=try JSONDecoder().decode(SpanParent.self,from:bytes); throw SpanRefusal(reason:"surrogateReplaced") }
    catch is DecodingError { }
}
test("all-eight-parallel-markers-refuse") {
    for marker in ["・","･","/","／",";","；","|","｜"] {
        var s=scene; s.parents[0].text="科目:架空科目A"+marker+"架空科目B"
        do { _=try EvidenceSpans.build(s); throw SpanRefusal(reason:"markerAccepted") }
        catch let e as SpanRefusal { try require(e.reason=="unsupportedParallelSyntax","wrongMarkerFailure") }
    }
}
test("cancellation-during-scan-and-comparison") {
    var checks=0
    do { _=try EvidenceSpans.build(scene,cancelled:{ checks+=1; return checks>=40 }); throw SpanRefusal(reason:"midScanCancelIgnored") }
    catch let e as SpanRefusal { try require(e.reason=="cancelled" && checks==40,"wrongMidScanFailure") }
    checks=0
    do { _=try EvidenceSpans.verify(scene,proposed:good,cancelled:{ checks+=1; return checks>=40 }); throw SpanRefusal(reason:"midVerifyCancelIgnored") }
    catch let e as SpanRefusal { try require(e.reason=="cancelled" && checks==40,"wrongMidVerifyFailure") }
}
test("unicode-line-and-paragraph-separators-refuse") {
    for separator in ["\u{2028}","\u{2029}"] {
        var s=scene; s.parents[0].text="科目:架空科目A"+separator+"架空科目B"
        do { _=try EvidenceSpans.build(s); throw SpanRefusal(reason:"lineSeparatorAccepted") }
        catch let e as SpanRefusal { try require(e.reason=="controlText","wrongSeparatorFailure") }
        s=scene; s.parents[0].id="id"+separator+"suffix"
        do { _=try EvidenceSpans.build(s); throw SpanRefusal(reason:"idSeparatorAccepted") }
        catch let e as SpanRefusal { try require(e.reason=="invalidParent","wrongIDSeparatorFailure") }
    }
}
let passed=outcomes.filter(\.passed).count
let report=Report(recipe:"evidence-span-finite-v1",fixtureSha256:actualHash,fixtureCases:fixture.cases.count,testsPassed:passed,testsFailed:outcomes.count-passed,nativeInferenceCalls:0,runtime:(ProcessInfo.processInfo.environment["SPAN_SWIFT_VERSION"] ?? "Swift compiler version not recorded")+"; "+ProcessInfo.processInfo.operatingSystemVersionString+"; Character segmentation is runtime-dependent",scope:"Textual ranges and unchanged parent ownership only. No Schema2, fullformal, OCR correctness, complete acquisition, EMPTY or AI qualification.",results:outcomes)
let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
FileHandle.standardOutput.write(try encoder.encode(report)); FileHandle.standardOutput.write(Data([10]))
if passed != outcomes.count { exit(1) }
