import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(Vision) && canImport(PDFKit) && canImport(AppKit)
import Vision
import PDFKit
import AppKit
import CryptoKit

final class RecoveryOrderedRasterObservationTests:XCTestCase {
    func testPairedImagePDFObservationRetainsFailuresAndWholeDocumentDenominators() async throws {
        guard #available(macOS 26.0,*),let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Native observation requires the dedicated owned invented image cohort")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        let cases=try XCTUnwrap(manifest["cases"] as? [[String:Any]])
        XCTAssertEqual(cases.count,2)
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
                    let native=try await RecognizeDocumentsRequest().perform(on:cg)
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
            print("ORDERED_RASTER_TEXT_DIAGNOSTIC \(name) rootExactOccurrences=\(expectedTexts.filter{rootTexts.contains($0)}.count)/2040 tableExactOccurrences=\(expectedTexts.filter{tableTexts.contains($0)}.count)/2040; textual occurrences do not establish correct cell or field ownership")
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
