import Foundation
import CryptoKit
import UIKit
import Vision
import ImageIO
import UniformTypeIdentifiers

struct OracleLesson:Decodable { var className:String; var day:String; var period:Int; var subject:String; var teacher:String; var room:String }
struct Oracle:Decodable { var schoolYear:Int; var term:String; var classes:[String]; var lessons:[OracleLesson]; var expectedSlots:Int }

@main struct UnlabeledFortyProbe {
    static func sha(_ data:Data)->String { SHA256.hash(data:data).map {String(format:"%02x",$0)}.joined() }
    static func object<T:Encodable>(_ value:T)throws->Any { let e=JSONEncoder();e.outputFormatting=[.sortedKeys];return try JSONSerialization.jsonObject(with:e.encode(value)) }
    static func emit(_ value:[String:Any])throws {
        let data=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
        guard data.count<=16*1024*1024 else { throw NSError(domain:"RecordByteCap",code:1) }
        FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data([10]))
    }
    static func rect(_ b:CGRect,width:Int,height:Int)->[String:Any] {
        let v=[Double(b.minX),Double(b.minY),Double(b.width),Double(b.height)]
        guard v.allSatisfy(\.isFinite) else {return ["finite":false]}
        return ["finite":true,"normalizedLowerLeft":["x":v[0],"y":v[1],"width":v[2],"height":v[3]],"pixelTopLeft":["x":v[0]*Double(width),"y":(1-Double(b.maxY))*Double(height),"width":v[2]*Double(width),"height":v[3]*Double(height)]]
    }
    static func failure(_ error:Error)->[String:Any] {
        if let p=error as? PDFParseError {return ["type":"PDFParseError","code":p.code.rawValue,"stage":p.stage?.rawValue as Any? ?? NSNull()]}
        let n=error as NSError;return ["type":String(describing:type(of:error)),"domain":n.domain,"code":n.code,"description":String(describing:error)]
    }
    static func imageRecord(_ cg:CGImage)throws->(Data,[String:Any]) {
        let bytes=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(bytes,UTType.png.identifier as CFString,1,nil) else { throw NSError(domain:"PNGDestination",code:1) }
        CGImageDestinationAddImage(destination,cg,nil)
        guard CGImageDestinationFinalize(destination),let pixels=cg.dataProvider?.data else {throw NSError(domain:"PNGOrProvider",code:1)}
        let png=bytes as Data
        guard png.count<=4*1024*1024 else {throw NSError(domain:"PNGByteCap",code:1)}
        return (png,["width":cg.width,"height":cg.height,"bitsPerComponent":cg.bitsPerComponent,"bitsPerPixel":cg.bitsPerPixel,"bytesPerRow":cg.bytesPerRow,"bitmapInfo":cg.bitmapInfo.rawValue,"alphaInfo":cg.alphaInfo.rawValue,"colorSpace":cg.colorSpace?.name as String? ?? "unnamed",
          "providerBytes":CFDataGetLength(pixels),"providerSHA256":sha(pixels as Data),"pngBytes":png.count,"pngSHA256":sha(png),"losslessPNGBase64":png.base64EncodedString(),"source_generated":true,"sameAsPillowPixels":false])
    }
    /// No drawing records/oracle parameter: every construction value below comes from actual native OCR/raster/source APIs.
    @available(iOS 26.0,*) static func acquire(_ cg:CGImage,pngURL:URL,digest:String) async -> ([String:Any],PDFAnalysis?) {
        let start=Date()
        let check:()throws->Void={try Task.checkCancellation();guard Date().timeIntervalSince(start)<180 else {throw PDFParseError(code:.limit)}}
        var record:[String:Any]=["type":"page","requestAttempted":false,"requestReturned":false,"pureLayoutsReturned":false,"builderReturned":false,"analysisReturned":false,
          "formalQuality":"UNASSESSED","ordinaryPDFEndpointAssessed":false,"manualConfirmationAssessed":false,"formalStorageAssessed":false,"modelInvocations":0]
        var stage="originalRasterStatements",analysis:PDFAnalysis?
        do {
            try check()
            let raster=try ProductionPureLayouts.raster(cg,check:check)
            record["actualRaster"]=["width":raster.width,"height":raster.height,"grayBytes":raster.grayscale.count,"graySHA256":sha(Data(raster.grayscale))]
            stage="nativeDocumentRequest";record["requestAttempted"]=true
            let observations=try await RecognizeDocumentsRequest().perform(on:cg)
            record["requestReturned"]=true;try check()
            stage="rawGlobalCapture"
            let raw=ObservationCapture.capture(observations,width:cg.width,height:cg.height);record["rawOCR"]=raw
            guard raw["captureComplete"] as? Bool==true else {throw NSError(domain:"RawCaptureIncomplete",code:1)}
            stage="originalLayoutsObservationStatements"
            let acquired=try ProductionPureLayouts.convert(cg,observations:observations,raster:raster,check:check)
            record["pureLayoutsReturned"]=true;record["actualLayout"]=try object(acquired.layout);record["actualRuleCount"]=acquired.layout.lines.count
            // Additional conservative diagnostic, absent from legacy f8's page-global caller.
            // The original raster API/threshold/bounds remain unchanged. Never infer missing text as blank.
            stage="additionalGlobalInkDiagnostic"
            let allText=acquired.layout.glyphs.map {RecoveryBox(x:$0.x,y:$0.y,width:$0.width,height:$0.height)}
            let unknown=try acquired.raster.hasUncoveredInk(RecoveryBox(x:0,y:0,width:Double(cg.width),height:Double(cg.height)),text:allText,rules:acquired.layout.lines,check:check)
            record["additionalGlobalInkDiagnostic"]=["uncoveredInk":unknown,"legacyF8GlobalCallerGuard":false,"requiredForThisDiagnosticProjection":true]
            stage="actualRasterBuilder"
            let document=try RecoveryDocumentBuilder.build([acquired.layout],kind:.timetable,hash:digest,fromOCR:Set([1]),rasters:[1:acquired.raster],check:check)
            record["builderReturned"]=true;record["recoveryDocument"]=try object(document)
            record["builderInputErrors"]=try RecoveryValidator.inputErrors(document,check:check)
            stage="actualRulesEngine"
            let run=try await RecoveryEngine.run(document,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:check)
            record["engineState"]=run.state.rawValue;record["engineErrors"]=run.errors
            guard run.state == .awaitingConfirmation,let result=run.result else {throw NSError(domain:"RulesNotComplete",code:1)}
            record["recoveryResult"]=try object(result)
            stage="actualValidatorV5"
            let validation=try RecoveryValidator.validate(document,result,check:check)
            record["validatorCanAdopt"]=validation.canAdopt;record["validatorErrors"]=validation.errors
            guard validation.canAdopt else {throw NSError(domain:"ValidatorRejected",code:1)}
            stage="additionalGlobalInkProjectionGate"
            guard !unknown else {throw NSError(domain:"AdditionalGlobalInkUnproven",code:1)}
            stage="inMemoryConversion"
            guard let day=SchoolDate(year:document.schoolYear,month:document.term=="前期" ? 4:10,day:1),document.term=="前期" || document.term=="後期" else {throw PDFParseError(code:.ambiguous)}
            let source=RecoverySelectedSource(kind:.timetable,url:pngURL,digest:digest,originalName:pngURL.lastPathComponent,storedName:pngURL.lastPathComponent,period:SchoolDataPeriod(day:day),captured:[RecoveryReadPage(page:1,state:.complete,layout:acquired.layout)])
            analysis=try RecoveryConversion.timetable(RecoveryPreview(document:document,result:result,source:source))
            record["analysisReturned"]=true;record["actualAnalysis"]=try object(analysis!)
            record["conversionScope"]="In-memory production projection guard only; source-generated PNG identity, not PDF Reader/file endpoint/manual confirmation/storage"
        } catch {
            record["failureStage"]=stage;record["failure"]=failure(error)
            if let preparation=error as? RecoveryStructurePreparation {record["structureInputErrors"]=(try? RecoveryValidator.inputErrors(preparation.document,unresolvedCellIds:Set(preparation.requests.map(\.ownerCellId)),check:check)) ?? [];record["structureProposalAssessed"]=false}
        }
        record["seconds"]=Date().timeIntervalSince(start)
        return(record,analysis)
    }
    /// Assertion-only oracle is opened AFTER acquire returned an actual Analysis; it never repairs any value.
    static func literal(_ analysis:PDFAnalysis,folder:URL)throws->[String:Any] {
        let data=try Data(contentsOf:folder.appendingPathComponent("literal-formal-oracle.json"))
        let pins=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("fixture-pins.json"))) as! [String:Any]
        guard sha(data)==(pins["files"] as! [String:String])["literal-formal-oracle.json"] else {throw NSError(domain:"OracleChanged",code:1)}
        let oracle=try JSONDecoder().decode(Oracle.self,from:data)
        func key(_ cls:String,_ day:String,_ period:Int)->String {"\(cls)|\(day)|\(period)"}
        let observed=Dictionary(grouping:analysis.lessons,by:{key($0.className,String($0.weekday),$0.period)})
        var matched=0,mismatches=[[String:Any]]()
        let expectedKeys=Set(oracle.lessons.map {key($0.className,$0.day,$0.period)})
        guard oracle.expectedSlots==40,oracle.lessons.count==40,expectedKeys.count==40 else {throw NSError(domain:"OracleShape",code:1)}
        for e in oracle.lessons {
            let actual=observed[key(e.className,e.day,e.period)] ?? []
            let good=actual.count==1 && actual[0].names.subject==e.subject && actual[0].names.teacher==e.teacher && actual[0].names.room==e.room
            if good {matched+=1}else {mismatches.append(["slot":key(e.className,e.day,e.period),"actual":try object(actual)])}
        }
        let extra=observed.keys.filter {!expectedKeys.contains($0)}.sorted()
        let metadata=analysis.schoolYear==oracle.schoolYear && analysis.term==oracle.term && Set(analysis.lessons.map(\.className))==Set(oracle.classes)
        return ["type":"literalAssessment","state":"ASSESSED","literalSlotsMatched":matched,"literalSlotsAssessed":40,"extraSlots":extra,"mismatches":mismatches,"yearTermClassesMatch":metadata,"all40LiteralMatch":matched==40 && extra.isEmpty && metadata,"oracleSHA256":sha(data),"oracleUsedOnlyAfterAnalysis":true,"formalStorageOrPDFEndpointAssessed":false]
    }
    @MainActor @available(iOS 26.0,*) static func run(_ folder:URL) async throws {
        let (cg,drawings,scale)=try FortyFixture.make(folder.appendingPathComponent("drawing-source.json"))
        let (png,image)=try imageRecord(cg);let url=folder.appendingPathComponent("new-unlabeled.png");try png.write(to:url)
        try emit(["type":"input","image":image,"sourceBasis":[3740,800],"productionLayoutsScale":scale,"recipe":"min(2,2048/max(sourcebasis)),ceil dimensions; UIKit source drawing, no PDF thumbnail","requestConstruction":"RecognizeDocumentsRequest()","settingOverrides":[],"plannedRequests":1,"ordinaryPDFEndpointAssessed":false,"expectedPassedToNativeOrBuilder":false])
        let (record,analysis)=await acquire(cg,pngURL:url,digest:sha(png));try emit(record)
        try emit(["type":"drawing","records":drawings,"postObservationOnly":true,"geometryScope":"Source-generated UIKit typography/physical boxes, not supplied glyph/binding/role scopes"])
        if let analysis {do {try emit(literal(analysis,folder:folder))}catch {try emit(["type":"literalAssessment","state":"UNASSESSED","assertionError":failure(error)])}}
        else {try emit(["type":"literalAssessment","state":"UNASSESSED","reason":"Actual Analysis did not return; raw recognition comparison remains separate"])}
        try emit(["type":"summary","plannedRequests":1,"attemptedRequests":record["requestAttempted"] as? Bool==true ? 1:0,"returnedRequests":record["requestReturned"] as? Bool==true ? 1:0,"analysesReturned":analysis == nil ? 0:1,"externalModelInvocations":0,"formalQuality":"UNASSESSED","manualAdopted":false,"formalStorageWrites":0])
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count==2 else {throw NSError(domain:"Arguments",code:1)}
            if #available(iOS 26.0,*) {try await run(URL(fileURLWithPath:CommandLine.arguments[1]))}else {throw NSError(domain:"OSUnsupported",code:1)}
        } catch {try? emit(["type":"fatal","executionError":failure(error)]);exit(1)}
    }
}
