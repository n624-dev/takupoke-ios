import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(Vision) && canImport(PDFKit) && canImport(AppKit)
import Vision
import PDFKit
import AppKit
import CryptoKit
import ImageIO

final class RecoveryOrderedRasterObservationTests:XCTestCase {
    func testPairedImageFirstPageResolutionChangesOnlyRenderingDensity() async throws {
        guard #available(macOS 26.0,*),let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Requires owned invented image cohort")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        for item in try XCTUnwrap(manifest["cases"] as? [[String:Any]]) {
            let file=try XCTUnwrap(item["file"] as? String),bytes=try Data(contentsOf:directory.appendingPathComponent(file))
            XCTAssertEqual(SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),item["sha256"] as? String)
            let pdf=try XCTUnwrap(PDFDocument(data:bytes)),page=try XCTUnwrap(pdf.page(at:0)),bounds=page.bounds(for:.cropBox)
            var outputs=[(String,Int,Int,[String],Int)]()
            // No oracle, crop, confidence rule or capture limit enters recognition.
            // Only PDFKit thumbnail density changes; this is a diagnostic, not
            // permission to adopt larger pages or relax production limits.
            for (name,scale) in [("long-edge-2048",min(2,2048/max(bounds.width,bounds.height))),("source-density-2x",CGFloat(2))] {
                let image=page.thumbnail(of:CGSize(width:ceil(bounds.width*scale),height:ceil(bounds.height*scale)),for:.cropBox)
                let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
                let native=try await RecoveryVisionCapture.request().perform(on:cg)
                let lines=native.flatMap{$0.document.text.lines}
                outputs.append((name,cg.width,cg.height,lines.compactMap{$0.topCandidates(1).first?.string},lines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                // A separate diagnostic reader receives these exact same pixels.
                // No topology or formal adoption is synthesized from text lines.
                var textRequest=RecognizeTextRequest()
                textRequest.recognitionLevel = .accurate
                textRequest.recognitionLanguages = [Locale.Language(identifier:"ja"),Locale.Language(identifier:"en")]
                textRequest.automaticallyDetectsLanguage = false
                textRequest.usesLanguageCorrection = true
                let textLines=try await textRequest.perform(on:cg)
                outputs.append((name+"-accurate-text",cg.width,cg.height,textLines.compactMap{$0.topCandidates(1).first?.string},textLines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                if name == "source-density-2x" {
                    let stem=try XCTUnwrap(item["case"] as? String)
                    let png=try Data(contentsOf:directory.appendingPathComponent(stem+".first-source.png"))
                    let source=try XCTUnwrap(CGImageSourceCreateWithData(png as CFData,nil))
                    let direct=try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
                    XCTAssertEqual(direct.width,cg.width);XCTAssertEqual(direct.height,cg.height)
                    let directLines=try await textRequest.perform(on:direct)
                    outputs.append(("embedded-source-png-accurate-text",direct.width,direct.height,directLines.compactMap{$0.topCandidates(1).first?.string},directLines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                    func rgba(_ image:CGImage)throws->[UInt8] {
                        var pixels=[UInt8](repeating:255,count:image.width*image.height*4)
                        let made=pixels.withUnsafeMutableBytes { bytes -> Bool in
                            guard let context=CGContext(data:bytes.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else {return false}
                            context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height));return true
                        }
                        XCTAssertTrue(made);return pixels
                    }
                    let rendered=try rgba(cg),original=try rgba(direct)
                    var changed=0,inkChanges=0,darkChanges=0
                    for offset in stride(from:0,to:rendered.count,by:4) {
                        let r=Int(rendered[offset]),g=Int(rendered[offset+1]),b=Int(rendered[offset+2])
                        let sr=Int(original[offset]),sg=Int(original[offset+1]),sb=Int(original[offset+2])
                        if r != sr || g != sg || b != sb {changed+=1}
                        if (r != 255 || g != 255 || b != 255) != (sr != 255 || sg != 255 || sb != 255) {inkChanges+=1}
                        if (r+g+b<480) != (sr+sg+sb<480) {darkChanges+=1}
                    }
                    let report:[String:Any]=["case":stem,"width":cg.width,"height":cg.height,"renderedRGBAHash":SHA256.hash(data:Data(rendered)).map{String(format:"%02x",$0)}.joined(),"directRGBAHash":SHA256.hash(data:Data(original)).map{String(format:"%02x",$0)}.joined(),"rgbChangedPixels":changed,"inkClassificationChanges":inkChanges,"dark160Changes":darkChanges,"renderedColorSpace":String(describing:cg.colorSpace?.name),"directColorSpace":String(describing:direct.colorSpace?.name),"renderedAlpha":cg.alphaInfo.rawValue,"directAlpha":direct.alphaInfo.rawValue,"minimumTextHeightFraction":textRequest.minimumTextHeightFraction,"scope":"Same-size PNG versus PDFKit acquisition; no formal adoption"]
                    print("ORDERED_RASTER_PIXEL_COMPARE "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
                    // A fixed eight-source-pixel detection floor admits the
                    // independently drawn 18/20px body without changing pixels,
                    // ROI, language, correction or confidence/adoption rules.
                    // This is a separate native request after the baseline.
                    textRequest.minimumTextHeightFraction = 8 / Float(cg.height)
                    let smallTextLines=try await textRequest.perform(on:cg)
                    outputs.append(("source-density-2x-accurate-text-minimum8px",cg.width,cg.height,smallTextLines.compactMap{$0.topCandidates(1).first?.string},smallTextLines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                    print("ORDERED_RASTER_MINHEIGHT_INPUT case=\(stem) height=\(cg.height) fraction=\(textRequest.minimumTextHeightFraction) sourcePixels=8; identical CGImage and all other recognition options")
                }
            }
            // Expected literals are inspected only after both native calls return.
            let gold=try XCTUnwrap(item["oracle"] as? [String:Any]),slots=try XCTUnwrap(gold["slots"] as? [[String:Any]])
            let texts=slots.flatMap{($0["lessons"] as! [[String:String]]).flatMap{$0.values.map{Data($0.utf8)}}}
            for (name,width,height,lines,below) in outputs {
                let raw=lines.map{Data($0.utf8)}
                let stripped=lines.map{Data($0.filter{!$0.isWhitespace}.utf8)}
                let containing=texts.filter {text in raw.contains{$0.range(of:text) != nil}}.count
                let spacingOnly=texts.filter {text in
                    let comparable=Data(String(decoding:text,as:UTF8.self).filter{!$0.isWhitespace}.utf8)
                    return stripped.contains{$0.range(of:comparable) != nil}
                }.count
                let row:[String:Any]=["case":item["case"]!,"condition":name,"page":1,"width":width,"height":height,"lines":lines.count,"below085":below,"bodyContainedOccurrencesAcrossDocument":containing,"spacingInsensitiveDiagnosticOccurrences":spacingOnly,"documentBodyObligations":2040,"nativeCalls":1,"llmCalls":0,"formalQuality":"UNASSESSED","firstInventedLines":Array(lines.prefix(8))]
                print("ORDERED_RASTER_RESOLUTION "+String(decoding:try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]),as:UTF8.self))
            }
        }
    }
    func testPairedImagePDFObservationRetainsFailuresAndWholeDocumentDenominators() async throws {
        guard #available(macOS 26.0,*),let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Native observation requires the dedicated owned invented image cohort")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        let cases=try XCTUnwrap(manifest["cases"] as? [[String:Any]])
        XCTAssertEqual(cases.count,2)
        let defaults=RecognizeDocumentsRequest(),configured=RecoveryVisionCapture.request()
        print("ORDERED_RASTER_LANGUAGE default=\(defaults.textRecognitionOptions.recognitionLanguages) configured=\(configured.textRecognitionOptions.recognitionLanguages) nativeAuto=\(configured.textRecognitionOptions.automaticallyDetectLanguage) nativeCorrection=\(configured.textRecognitionOptions.useLanguageCorrection) nativeCandidates=\(configured.textRecognitionOptions.maximumCandidateCount) os=\(ProcessInfo.processInfo.operatingSystemVersionString); auto-language only differs from preceding fixed-language comparison")
        for item in cases {
            let name=try XCTUnwrap(item["case"] as? String),file=try XCTUnwrap(item["file"] as? String)
            let url=directory.appendingPathComponent(file),bytes=try Data(contentsOf:url)
            let hash=SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
            XCTAssertEqual(hash,item["sha256"] as? String)
            var stage="Reader/Strict",failure:String?=nil,formal:PDFAnalysis?=nil,document:RecoveryDocument?=nil
            var pages=[RecoveryOCRPage](),rasters=[Int:RecoveryRasterGrid](),pageReports=[[String:Any]]()
            var calls=0,work=0,executionError=false
            do {
                do {
                    let strict=try PDFKitReader.read(url,kind:.timetable)
                    _=try PDFSchoolParser.parse(strict,kind:.timetable,digest:hash,name:file)
                    XCTFail("Image-only input unexpectedly passed Strict");continue
                } catch let error as PDFParseError { guard RecoveryPolicy.eligible(error) else { throw error } }
                let pdf=try XCTUnwrap(PDFDocument(data:bytes));XCTAssertEqual(pdf.pageCount,5)
                stage="PDF render/Vision capture"
                for number in 1...pdf.pageCount {
                    let page=try XCTUnwrap(pdf.page(at:number-1)),bounds=page.bounds(for:.cropBox)
                    let scale=min(2,2048/max(bounds.width,bounds.height))
                    let image=page.thumbnail(of:CGSize(width:ceil(bounds.width*scale),height:ceil(bounds.height*scale)),for:.cropBox)
                    let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
                    var rgba=[UInt8](repeating:255,count:cg.width*cg.height*4)
                    let made=rgba.withUnsafeMutableBytes { pixels -> Bool in
                        guard let context=CGContext(data:pixels.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                        let rect=CGRect(x:0,y:0,width:CGFloat(cg.width),height:CGFloat(cg.height))
                        context.setFillColor(gray:1,alpha:1);context.fill(rect);context.draw(cg,in:rect);return true
                    }
                    guard made else { throw PDFParseError(code:.unreadable) }
                    let raster=try RecoveryRasterGrid.fromRGBA(width:cg.width,height:cg.height,pixels:rgba,check:{})
                    calls+=1
                    let native=try await RecoveryVisionCapture.request().perform(on:cg)
                    let captured=try RecoveryVisionCapture.page(number,width:cg.width,height:cg.height,observations:native,work:&work,check:{})
                    pages.append(captured);rasters[number]=raster
                    var atomCount=0,mappingErrors=0
                    for line in captured.lines {
                        guard let top=line.candidates.first else {mappingErrors+=1;continue}
                        do {if try RecoveryOCRLineMapping.requiresAtom(top,width:cg.width,height:cg.height,consume:{}) {atomCount+=1}}
                        catch {mappingErrors+=1}
                    }
                    let pixelHash=SHA256.hash(data:Data(rgba)).map { String(format:"%02x",$0) }.joined()
                    pageReports.append(["page":number,"width":cg.width,"height":cg.height,"rgbaSha256":pixelHash,"nativeLines":captured.lines.count,"nativeCharacters":captured.lines.reduce(0){$0+($1.candidates.first?.characters.count ?? 0)},"wholeLineAtoms":atomCount,"mappingErrors":mappingErrors,"below085":captured.lines.filter{($0.candidates.first?.confidence ?? 0)<0.85}.count])
                }
                stage="Acquisition inventory"
                let capture=RecoveryOCRAcquisitionDraft(sourcePDFHash:hash,documentPageCount:5,requiredOCRPages:Array(1...5),pages:pages)
                _=try capture.assess(check:{})
                stage="Original lines/Builder"
                var layouts=[PDFPageLayout](),prepared=[Int:RecoveryRasterGrid]()
                for page in pages {
                    var glyphs=[PDFGlyph](),order=0
                    for line in page.lines {
                        let top=line.candidates[0]
                        if try RecoveryOCRLineMapping.requiresAtom(top,width:page.width,height:page.height,consume:{}) {
                            let b=try XCTUnwrap(top.observationRange)
                            glyphs.append(PDFGlyph(text:top.text,x:b.x,y:b.y,width:b.width,height:b.height,sourceLine:line.nativeOrder,sourceOrder:order,ocrLineAtom:true));order+=1
                        } else {
                            for char in top.characters {
                                let b=try XCTUnwrap(char.range)
                                glyphs.append(PDFGlyph(text:char.text,x:b.x,y:b.y,width:b.width,height:b.height,sourceLine:line.nativeOrder,sourceOrder:order));order+=1
                            }
                        }
                    }
                    let raster=try XCTUnwrap(rasters[page.page]),rules=try raster.rules(check:{})
                    layouts.append(PDFPageLayout(width:Double(page.width),height:Double(page.height),glyphs:glyphs,lines:rules))
                    prepared[page.page]=try raster.preparingRules(rules,check:{})
                }
                var doc=try RecoveryDocumentBuilder.build(layouts,kind:.timetable,hash:hash,fromOCR:Set(1...5),rasters:prepared)
                doc=try RecoveryManualAssistance.attaching(capture,to:doc);document=doc
                stage="Engine/Validator"
                let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:{})
                if let result=run.result,RecoveryValidator.validate(doc,result).canAdopt {
                    let source=RecoverySelectedSource(kind:.timetable,url:url,digest:hash,originalName:file,storedName:file,period:SchoolDataPeriod(day:SchoolDate(iso8601:"2027-04-01")!))
                    stage="Formal";formal=try RecoveryConversion.timetable(RecoveryPreview(document:doc,result:result,source:source))
                } else { failure=run.errors.joined(separator:",") }
            } catch let error as PDFParseError { failure=String(describing:error);executionError=[.cancelled,.limit,.storage].contains(error.code) }
              catch let error as RecoveryOCRAcquisitionFailure { failure=String(describing:error);executionError=error == .limit }
              catch { failure=String(describing:error);executionError=true }
            // Assertion-only literals are not inspected until the pipeline returns.
            let gold=try XCTUnwrap(item["oracle"] as? [String:Any]),slots=try XCTUnwrap(gold["slots"] as? [[String:Any]])
            let expectedTexts=slots.flatMap { ($0["lessons"] as! [[String:String]]).flatMap { $0.values.map {Data($0.utf8)} } }
            let rootTexts=Set(pages.flatMap{$0.lines.compactMap{$0.candidates.first.map{Data($0.text.utf8)}}})
            let tableTexts=Set(pages.flatMap { page in
                (page.structure?.documents ?? []).flatMap { document in document.tables.flatMap { table in
                    table.rows.flatMap { row in row.flatMap { cell in cell.lines.compactMap{$0.candidates.first.map{Data($0.text.utf8)}} } }
                } }
            })
            let rootContained=expectedTexts.filter { expected in rootTexts.contains { $0.range(of:expected) != nil } }.count
            let tableContained=expectedTexts.filter { expected in tableTexts.contains { $0.range(of:expected) != nil } }.count
            print("ORDERED_RASTER_TEXT_DIAGNOSTIC \(name) rootExactOccurrences=\(expectedTexts.filter{rootTexts.contains($0)}.count)/2040 tableExactOccurrences=\(expectedTexts.filter{tableTexts.contains($0)}.count)/2040 rootContainedOccurrences=\(rootContained)/2040 tableContainedOccurrences=\(tableContained)/2040; textual occurrences do not establish correct cell or field ownership")
            var slotErrors=0,valueErrors=0,extraKeys=0
            if let formal {
                let actual=Dictionary(grouping:formal.lessons,by:{"\($0.className):\($0.weekday):\($0.period)"});var keys=Set<String>()
                for slot in slots {
                    let key="\(slot["className"] as! String):\(slot["weekday"] as! Int):\(slot["period"] as! Int)";keys.insert(key)
                    let expected=(slot["lessons"] as! [[String:String]])[0]
                    guard let got=actual[key],got.count==1 else {slotErrors+=1;valueErrors+=3;continue}
                    let values=["subject":got[0].names.subject,"teacher":got[0].names.teacher,"room":got[0].names.room]
                    let wrong=values.filter{expected[$0.key] != $0.value}.count;valueErrors+=wrong;if wrong>0 {slotErrors+=1}
                }
                extraKeys=Set(actual.keys).subtracting(keys).count
                if formal.schoolYear != gold["schoolYear"] as? Int || formal.term != gold["term"] as? String {slotErrors+=1}
            }
            let exact=formal != nil && slotErrors==0 && extraKeys==0
            let row:[String:Any]=["case":name,"pdfSha256":hash,"stage":stage,"failure":failure ?? NSNull(),"classification":executionError ? "execution-error":formal == nil ? "recovery-failure":exact ? "correct-formal":"incorrect-formal","accepted":formal != nil,"literalExact":formal == nil ? NSNull():exact,"slotObligations":680,"bodyValueObligations":2040,"slotErrors":formal == nil ? NSNull():slotErrors,"bodyValueErrors":formal == nil ? NSNull():valueErrors,"extraKeys":extraKeys,"nativeOcrCalls":calls,"llmCalls":0,"pages":pageReports,"builderCells":document?.cells.count ?? 0]
            print("ORDERED_RASTER_NATIVE "+String(decoding:try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]),as:UTF8.self))
        }
        print("ORDERED_RASTER_SCOPE Native macOS Vision/common capture/layout/builder/validator observation. Not iPhone acquisition, human adoption, local-model qualification or a quality-pass assertion.")
    }
}
#endif
