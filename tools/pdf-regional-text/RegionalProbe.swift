import Foundation
import CryptoKit
import UIKit
import PDFKit
import Vision
import ImageIO
import UniformTypeIdentifiers

struct OracleLesson:Decodable { var className:String; var day:String; var period:Int; var subject:String; var teacher:String; var room:String }
struct Oracle:Decodable { var schoolYear:Int; var term:String; var classes:[String]; var lessons:[OracleLesson]; var expectedSlots:Int }

@main struct PDFRegionalTextProbe {
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
          "providerBytes":CFDataGetLength(pixels),"providerSHA256":sha(pixels as Data),"pngBytes":png.count,"pngSHA256":sha(png),"losslessPNGBase64":png.base64EncodedString(),"source_generated":true,"originalPixelIdentityAssessedSeparatelyBeforeOCR":true])
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
        return ["type":"literalAssessment","state":"ASSESSED","literalSlotsMatched":matched,"literalSlotsAssessed":40,"extraSlots":extra,"mismatches":mismatches,"yearTermClassesMatch":metadata,"all40LiteralMatch":matched==40 && extra.isEmpty && metadata,"oracleSHA256":sha(data),"oracleUsedOnlyAfterAnalysis":true,"actualSyntheticPDFReaderAndRegionalRenderAssessed":true,"formalStorageAssessed":false,"realSchoolPDFEndpointAssessed":false,"productionAutomaticFallbackAssessed":false]
    }

    static func captureRecord(_ capture:RecoveryReadCapture)throws->[String:Any] {
        ["readerCompleted":capture.readerCompleted,"complete":capture.complete,"pages":try capture.pages.map{page in
            ["page":page.page,"state":page.state.rawValue,"actualLayout":try page.layout.map{try object($0)} ?? NSNull()] as [String:Any]
        }]
    }
    @MainActor @available(iOS 26.0,*) static func run(_ folder:URL) async throws {
        let start=Date(),check:()throws->Void={try Task.checkCancellation();guard Date().timeIntervalSince(start)<900 else {throw PDFParseError(code:.limit)}}
        let pins=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("input-pins.json"))) as! [String:Any]
        let url=folder.appendingPathComponent("unlabeled-consumed-development.pdf"),data=try Data(contentsOf:url),digest=sha(data)
        var outcome:[String:Any]=["type":"outcome","builderReturned":false,"analysisReturned":false,"formalQuality":"UNASSESSED","formalStorageAssessed":false,"manualConfirmationAssessed":false]
        var stage="inputPDFPin",attempted=0,returned=0,captured=0,readerAttempted=false,analysis:PDFAnalysis?
        do {
            guard digest==pins["PDFSHA256"] as? String,data.count==pins["PDFBytes"] as? Int else {throw NSError(domain:"SourceGeneratedPDFChanged",code:1)}
            stage="actualPDFReader";let capture=RecoveryReadCapture();var readerError:Error?
            readerAttempted=true
            do {
                let pages=try PDFKitReader.read(url,kind:.timetable,capture:capture,check:check)
                outcome["readerReturned"]=true;outcome["readerPages"]=try object(pages)
            }catch {readerError=error;outcome["readerReturned"]=false;outcome["readerFailure"]=failure(error)}
            outcome["originalReaderCapture"]=try captureRecord(capture)
            try check()
            guard let readerError else {throw NSError(domain:"UnexpectedVectorReaderReturn",code:1)}
            guard let parse=readerError as? PDFParseError,parse.code == .unsupported,parse.stage == .rasterInput,
                  !capture.readerCompleted,!capture.complete,capture.pages.count==1,
                  capture.pages[0].state == .rasterOnly,capture.pages[0].layout == nil else {throw readerError}
            outcome["expectedImageOnlyReaderRefusal"]=true
            stage="actualCoreGraphicsPDFOriginalRender"
            guard let pdf=CGPDFDocument(url as CFURL),pdf.numberOfPages==1,let page=pdf.page(at:1),page.rotationAngle==0 else {throw PDFParseError(code:.unreadable)}
            let bounds=page.getBoxRect(.cropBox)
            guard bounds==CGRect(x:0,y:0,width:3740,height:800) else {throw PDFParseError(code:.unsupported,stage:.rasterInput)}
            let basis=PhysicalBox(x:0,y:0,width:3740,height:800),original=try PDFRegionalRaster.render(page,box:basis,scale:1,maximum:4096)
            let (originalPNG,originalMetadata)=try imageRecord(original)
            try emit(["type":"inputImage","id":"actual-PDF-original-1x","pdfSHA256":digest,"image":originalMetadata,"originalBox":try object(basis),"scale":1,"actualAffine":try object(RasterAffine(sourceBox:basis,scale:1,renderedHeight:original.height)),"sourceGeneratedPDF":true])
            let rgba=try PDFRegionalRaster.rgba(original),verification=pins["verification"] as! [String:Any]
            let equal=sha(Data(rgba))==verification["actualPDFRenderedRGBA1xSHA256"] as? String
            outcome["actualAppleOriginalRGBA_SHA256"]=sha(Data(rgba));outcome["actualAppleOriginalEqualsPinnedSourceRGBA"]=equal
            guard equal else {throw NSError(domain:"ActualApplePixelIdentityMismatch",code:1)}
            _=originalPNG // Only encoded in the excluded input record; no PNG written locally.
            let raster=try ProductionPureRaster.raster(original,check:check),rules=try raster.rules(check:check),prepared=try raster.preparingRules(rules,check:check)
            outcome["originalRasterGraySHA256"]=sha(Data(raster.grayscale));outcome["originalRules"]=try object(rules)
            stage="actualCoarsePDFRailRender"
            let scale=min(2,2048/max(basis.width,basis.height)),coarse=try PDFRegionalRaster.render(page,box:basis,scale:scale,maximum:2048)
            let (_,coarseMetadata)=try imageRecord(coarse)
            try emit(["type":"inputImage","id":"actual-PDF-coarse-rails-only","image":coarseMetadata,"scale":scale,"OCRRequests":0,"actualAffine":try object(RasterAffine(sourceBox:basis,scale:scale,renderedHeight:coarse.height))])
            let coarseRaster=try ProductionPureRaster.raster(coarse,check:check),coarseRules=try coarseRaster.rules(check:check)
            stage="physicalSevenRegionPlan"
            let plan=try RegionalPlan.derive(rails:coarseRules.map{MeasuredRail(x1:$0.x1,y1:$0.y1,x2:$0.x2,y2:$0.y2)},coarseWidth:coarse.width,coarseHeight:coarse.height,originalWidth:original.width,originalHeight:original.height,coarseScale:scale,
                upperInkExtent:{try PDFRegionalRaster.upperInkExtent(raster,before:$0,check:check)},check:check)
            try emit(["type":"regionPlan","regions":try object(plan),"actualCoarseRails":try object(coarseRules),"drawingOrOraclePassedToPlan":false,"scale2AddsOriginalSourceDetail":false])
            stage="actualOrdinaryTextConfiguration"
            var configuration=RecognizeTextRequest();configuration.recognitionLevel = .accurate
            configuration.recognitionLanguages=[Locale.Language(identifier:"ja-JP"),Locale.Language(identifier:"en-US")]
            configuration.usesLanguageCorrection=false;configuration.automaticallyDetectsLanguage=false;configuration.customWords=[]
            let supported=configuration.supportedRecognitionLanguages.map(\.minimalIdentifier)
            guard Double(configuration.minimumTextHeightFraction)==0.03125,configuration.recognitionLanguages.allSatisfy({supported.contains($0.minimalIdentifier)}) else {throw NSError(domain:"FrozenSettingsUnsupported",code:1)}
            try emit(["type":"environment","api":"RecognizeTextRequest","recognitionLevel":"accurate","recognitionLanguages":["ja-JP","en-US"],"supportedRecognitionLanguages":supported,"usesLanguageCorrection":false,"automaticallyDetectsLanguage":false,"customWords":[],"minimumTextHeightFraction":Double(configuration.minimumTextHeightFraction),"minimumHeightDefaultUnchanged":true,"revision":String(describing:configuration.revision),"confidenceCrossAPICalibrationAssumed":false,"plannedRequests":7])
            var glyphs=[PDFGlyph](),owners=[NativeRangeOwner](),lineBase=0,allGuards=true,serializedCharacters=0
            for region in plan {
                try check()
                let regionStart=Date();var record:[String:Any]=["type":"region","regionId":region.id,"attempted":false,"returned":false,"captureComplete":false]
                do {
                    let image=try PDFRegionalRaster.render(page,box:region.box,scale:region.scale,maximum:2048)
                    let (_,metadata)=try imageRecord(image)
                    try emit(["type":"inputImage","id":region.id,"image":metadata,"originalBox":try object(region.box),"scale":region.scale,"actualAffine":try object(RasterAffine(sourceBox:region.box,scale:region.scale,renderedHeight:image.height)),"sameCGImagePassedOnceToOCR":true,"scale2AddsOriginalSourceDetail":false])
                    record["attempted"]=true;attempted+=1
                    var request=configuration;let observations=try await request.perform(on:image)
                    returned+=1;record["returned"]=true;try check()
                    let result=try TextRangeCapture.capture(observations,region:region,width:image.width,height:image.height,lineBase:lineBase,orderBase:glyphs.count,check:check)
                    serializedCharacters+=result.raw["capturedCandidateCharacters"] as? Int ?? 0
                    guard serializedCharacters<=100000,glyphs.count+result.glyphs.count<=100000 else {throw PDFParseError(code:.limit)}
                    captured+=1;record["captureComplete"]=true;record["rawOCR"]=result.raw;record["originalAndRegionProvenanceGuardsPass"]=result.passesAcquisitionGuards
                    glyphs+=result.glyphs;owners+=result.owners;lineBase+=result.lines;allGuards = allGuards && result.passesAcquisitionGuards
                }catch {record["executionError"]=failure(error);allGuards=false}
                record["seconds"]=Date().timeIntervalSince(regionStart);try emit(record)
                try check() // Cancellation/deadline is terminal; no retry of failed requests.
            }
            outcome["allOriginalAndRegionProvenanceGuardsPass"]=allGuards;outcome["actualNativeMappedLayout"]=try object(PDFPageLayout(width:3740,height:800,glyphs:glyphs,lines:rules))
            stage="wholeOriginalRasterDiagnostics"
            do {
                outcome["originalWholePageUncoveredInk"]=try prepared.hasUncoveredInk(RecoveryBox(x:0,y:0,width:3740,height:800),text:glyphs.map{RecoveryBox(x:$0.x,y:$0.y,width:$0.width,height:$0.height)},rules:rules,check:check)
                outcome["uniqueNativeCandidateRangeOwnership"]=try OriginalInkOwnership.measure(prepared,owners:owners,check:check)
            }catch {outcome["originalInkDiagnosticError"]=failure(error);try check()}
            stage="originalAcquisitionGuardGate"
            guard attempted==7,returned==7,captured==7,allGuards else {throw NSError(domain:"OriginalAcquisitionGuardRefused",code:1)}
            stage="actualCoverageSafeBuilder"
            let layout=PDFPageLayout(width:3740,height:800,glyphs:glyphs,lines:rules)
            let document=try RecoveryDocumentBuilder.build([layout],kind:.timetable,hash:digest,fromOCR:Set([1]),rasters:[1:prepared],check:check)
            outcome["builderReturned"]=true;outcome["actualRecoveryDocument"]=try object(document)
            stage="actualRulesEngineValidator"
            let run=try await RecoveryEngine.run(document,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:check)
            outcome["engineState"]=run.state.rawValue;outcome["engineErrors"]=run.errors
            guard run.state == .awaitingConfirmation,let result=run.result else {throw NSError(domain:"RulesIncomplete",code:1)}
            let validation=try RecoveryValidator.validate(document,result,check:check)
            outcome["actualRecoveryResult"]=try object(result);outcome["validatorCanAdopt"]=validation.canAdopt;outcome["validatorErrors"]=validation.errors
            guard validation.canAdopt else {throw NSError(domain:"ValidatorRejected",code:1)}
            stage="additionalWholeOriginalUniqueOwnershipGate"
            guard outcome["originalWholePageUncoveredInk"] as? Bool==false,
                  (outcome["uniqueNativeCandidateRangeOwnership"] as? [String:Any])?["completeUniqueCandidateRangeOwnership"] as? Bool==true else {throw NSError(domain:"OriginalInkOwnershipUnproven",code:1)}
            stage="inMemoryProductionConversion"
            guard let date=SchoolDate(year:document.schoolYear,month:document.term=="前期" ? 4:10,day:1),document.term=="前期" || document.term=="後期" else {throw PDFParseError(code:.ambiguous)}
            let source=RecoverySelectedSource(kind:.timetable,url:url,digest:digest,originalName:url.lastPathComponent,storedName:url.lastPathComponent,period:SchoolDataPeriod(day:date),captured:[RecoveryReadPage(page:1,state:.complete,layout:layout)])
            analysis=try RecoveryConversion.timetable(RecoveryPreview(document:document,result:result,source:source))
            outcome["analysisReturned"]=true;outcome["actualAnalysis"]=try object(analysis!)
            outcome["sourceStateScope"]="Original Reader capture retained separately; research regional acquisition complete only after all unchanged predicates/current production raster proof and independent original pixel ownership. Manual/storage unassessed."
        }catch {outcome["failureStage"]=stage;outcome["failure"]=failure(error)}
        outcome["seconds"]=Date().timeIntervalSince(start);try emit(outcome)
        if let analysis {do {try emit(literal(analysis,folder:folder))}catch {try emit(["type":"literalAssessment","state":"UNASSESSED","assertionError":failure(error)])}}
        else {try emit(["type":"literalAssessment","state":"UNASSESSED","reason":"Actual Analysis did not return; raw components and source pixel proofs remain separate"])}
        try emit(["type":"summary","plannedRequests":7,"attemptedRequests":attempted,"returnedRequests":returned,"capturedRegions":captured,"analysesReturned":analysis == nil ? 0:1,"externalModelInvocations":0,"formalQuality":"UNASSESSED","manualAdopted":false,"formalStorageWrites":0,"DocumentRequests":0,"ordinaryPDFReaderCalled":readerAttempted])
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count==2 else {throw NSError(domain:"Arguments",code:1)}
            if #available(iOS 26.0,*) {try await run(URL(fileURLWithPath:CommandLine.arguments[1]))}else {throw NSError(domain:"OSUnsupported",code:1)}
        }catch {try? emit(["type":"fatal","executionError":failure(error)]);exit(1)}
    }
}
