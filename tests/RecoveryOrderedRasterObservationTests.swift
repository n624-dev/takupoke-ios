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
    func testPhysicalClassColumnReadersRetainTheirOwnCandidatesAndScores() async throws {
        guard #available(macOS 26.0,*),
              ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_HEADER_PAIR"] == "1",
              let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Requires the owned physical class-column comparison")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        for item in try XCTUnwrap(manifest["cases"] as? [[String:Any]]) {
            let bytes=try Data(contentsOf:directory.appendingPathComponent(try XCTUnwrap(item["file"] as? String)))
            XCTAssertEqual(SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),item["sha256"] as? String)
            let pdf=try XCTUnwrap(PDFDocument(data:bytes)),page=try XCTUnwrap(pdf.page(at:0)),bounds=page.bounds(for:.cropBox)
            let scale=min(2,2048/max(bounds.width,bounds.height))
            let image=page.thumbnail(of:CGSize(width:ceil(bounds.width*scale),height:ceil(bounds.height*scale)),for:.cropBox)
            let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
            var rgba=[UInt8](repeating:255,count:cg.width*cg.height*4)
            let made=rgba.withUnsafeMutableBytes { pixels -> Bool in
                guard let context=CGContext(data:pixels.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else {return false}
                let rect=CGRect(x:0,y:0,width:CGFloat(cg.width),height:CGFloat(cg.height))
                context.setFillColor(gray:1,alpha:1);context.fill(rect);context.draw(cg,in:rect);return true
            }
            XCTAssertTrue(made)
            let raster=try RecoveryRasterGrid.fromRGBA(width:cg.width,height:cg.height,pixels:rgba,check:{})
            let rules=try raster.rules(check:{}),prepared=try raster.preparingRules(rules,check:{})
            // Select every ink-bearing closed cell of the leftmost tall column
            // solely from observed rules/pixels. No class vocabulary, OCR answer,
            // generator dimensions or expected class order selects a crop.
            let vertical=rules.filter{$0.vertical && $0.y2-$0.y1>Double(cg.height)/2}.sorted{$0.x1<$1.x1}
            XCTAssertGreaterThanOrEqual(vertical.count,2)
            let left=try XCTUnwrap(vertical.first).x1,right=try XCTUnwrap(vertical.dropFirst().first).x1
            let horizontal=rules.filter{$0.horizontal && $0.x1<=left+0.3 && $0.x2>=right-0.3}.map(\.y1).sorted()
            var captures=[(RecoveryBox,[[String:Any]],[[String:Any]])]()
            // Diagnostic only: quantify whether native character boxes share
            // original ink. A shared baseline/cell is never a merge permission.
            // Pixel centers and every original nonwhite pixel are used without
            // clipping native boxes, suppressing faint ink or OCR-driven crops.
            func characterInk(_ lines:[[String:Any]],crop:RecoveryBox) -> [String:Any] {
                let characters=lines.flatMap { $0["topCandidateCharacters"] as? [[String:Any]] ?? [] }
                let boxes=characters.compactMap { character -> (Int,[Double])? in
                    guard let line=character["observationOrder"] as? Int,
                          let b=character["originalPageBox"] as? [Double],b.count == 4,
                          b.allSatisfy(\.isFinite),b[2]>0,b[3]>0 else {return nil}
                    return (line,b)
                }
                var total=0,uncovered=0,once=0,shared=0,sharedObservations=0
                for y in Int(crop.y)..<Int(crop.y+crop.height) {
                    for x in Int(crop.x)..<Int(crop.x+crop.width) where raster.grayscale[y*cg.width+x]<255 {
                        total+=1
                        let centerX=Double(x)+0.5,centerY=Double(y)+0.5
                        let owners=boxes.filter { _,b in centerX>=b[0] && centerX<b[0]+b[2] && centerY>=b[1] && centerY<b[1]+b[3] }
                        if owners.isEmpty {uncovered+=1} else if owners.count==1 {once+=1} else {shared+=1}
                        if Set(owners.map { $0.0 }).count>1 {sharedObservations+=1}
                    }
                }
                XCTAssertEqual(total,uncovered+once+shared)
                return ["characters":characters.count,"usableRawBoxes":boxes.count,
                    "originalNonwhitePixels":total,"uncoveredInkPixels":uncovered,
                    "singleOwnerInkPixels":once,"multipleCharacterOwnerInkPixels":shared,
                    "multipleObservationOwnerInkPixels":sharedObservations,"assemblyPermitted":false]
            }
            var calls=0
            func observed(_ lines:[RecognizedTextObservation],crop:RecoveryBox,parent:RecoveryBox) throws -> [[String:Any]] {
                try lines.enumerated().map { order,line in
                    let b=line.boundingBox.cgRect
                    let global=RecoveryBox(x:crop.x+Double(b.minX)*crop.width,
                        y:crop.y+Double(1-b.maxY)*crop.height,width:Double(b.width)*crop.width,height:Double(b.height)*crop.height)
                    XCTAssertTrue(global.valid)
                    // Vision's observed quadrilateral may extend beyond the
                    // supplied crop. Preserve it unchanged and distinguish that
                    // diagnostic from escape into another physical cell.
                    let insideCrop=global.x>=crop.x && global.y>=crop.y &&
                        global.x+global.width<=crop.x+crop.width && global.y+global.height<=crop.y+crop.height
                    XCTAssertGreaterThanOrEqual(global.x,parent.x);XCTAssertGreaterThanOrEqual(global.y,parent.y)
                    XCTAssertLessThanOrEqual(global.x+global.width,parent.x+parent.width)
                    XCTAssertLessThanOrEqual(global.y+global.height,parent.y+parent.height)
                    return ["lineOrder":order,"originalPageBox":[global.x,global.y,global.width,global.height],
                        "containedInInputCrop":insideCrop,
                        "candidates":line.topCandidates(5).map{["text":$0.string,"nativeScore":Double($0.confidence)]},
                        "topCandidateCharacters":line.topCandidates(1).flatMap { candidate in
                            candidate.string.indices.enumerated().map { characterOrder,start -> [String:Any] in
                                let end=candidate.string.index(after:start)
                                let range=candidate.boundingBox(for:start..<end)?.boundingBox.cgRect
                                let rawBox=range.map { b in [crop.x+Double(b.minX)*crop.width,
                                    crop.y+Double(1-b.maxY)*crop.height,Double(b.width)*crop.width,Double(b.height)*crop.height] }
                                return ["sourceId":"line-\(order)-character-\(characterOrder)",
                                    "observationOrder":order,"text":String(candidate.string[start..<end]),
                                    "originalPageBox":rawBox as Any? ?? NSNull()]
                            }
                        }]
                }
            }
            for (top,bottom) in zip(horizontal,horizontal.dropFirst()) {
                let cell=RecoveryBox(x:left,y:top,width:right-left,height:bottom-top)
                guard cell.valid,cell.width>8,cell.height>8,
                      !prepared.isBlank(cell,rules:rules) else {continue}
                let physical=RecoveryBox(x:ceil(left)+2,y:ceil(top)+2,
                    width:floor(right)-ceil(left)-4,height:floor(bottom)-ceil(top)-4)
                // New fixed recipe: retain every original nonwhite pixel and
                // four pixels of margin, without resampling or OCR-driven bounds.
                var minX=Int(physical.x+physical.width),minY=Int(physical.y+physical.height),maxX = -1,maxY = -1
                for y in Int(physical.y)..<Int(physical.y+physical.height) {
                    for x in Int(physical.x)..<Int(physical.x+physical.width) where raster.grayscale[y*cg.width+x]<255 {
                        minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)
                    }
                }
                XCTAssertGreaterThanOrEqual(maxX,minX);XCTAssertGreaterThanOrEqual(maxY,minY)
                let x=max(Int(physical.x),minX-4),y=max(Int(physical.y),minY-4)
                let crop=RecoveryBox(x:Double(x),y:Double(y),
                    width:Double(min(Int(physical.x+physical.width),maxX+5)-x),
                    height:Double(min(Int(physical.y+physical.height),maxY+5)-y))
                XCTAssertTrue(crop.valid)
                let pixels=try XCTUnwrap(cg.cropping(to:CGRect(x:crop.x,y:crop.y,width:crop.width,height:crop.height)))
                var documents=RecoveryVisionCapture.request()
                documents.textRecognitionOptions.minimumTextHeightFraction=8/Float(pixels.height)
                let documentLines=try await documents.perform(on:pixels).flatMap{$0.document.text.lines};calls+=1
                var text=RecognizeTextRequest()
                text.recognitionLevel = .accurate
                text.recognitionLanguages=[Locale.Language(identifier:"ja"),Locale.Language(identifier:"en")]
                text.automaticallyDetectsLanguage=false;text.usesLanguageCorrection=false
                text.minimumTextHeightFraction=8/Float(pixels.height)
                let textLines=try await text.perform(on:pixels);calls+=1
                captures.append((crop,try observed(documentLines,crop:crop,parent:physical),try observed(textLines,crop:crop,parent:physical)))
            }
            // Expected order is read only after every fixed recognition call.
            // Never use it to choose a candidate, rewrite a source or adopt.
            let layout=try XCTUnwrap(item["layout"] as? [String:Any])
            let expected=Array(try XCTUnwrap(layout["classOrder"] as? [String]).prefix(9))
            XCTAssertEqual(captures.count,expected.count)
            for (index,capture) in captures.enumerated() {
                let report:[String:Any]=["case":item["case"]!,"page":1,"physicalRow":index,
                    "cropBox":[capture.0.x,capture.0.y,capture.0.width,capture.0.height],
                    "documents":capture.1,"accurateNoCorrection":capture.2,
                    "documentsCharacterInk":characterInk(capture.1,crop:capture.0),
                    "accurateCharacterInk":characterInk(capture.2,crop:capture.0),
                    "expectedAfterRecognition":index<expected.count ? expected[index]:"",
                    "inputRegion":"all original nonwhite pixels plus fixed4px margin",
                    "qualified":false,"scoreSubstitution":false,"adoptionCalls":0]
                print("ORDERED_RASTER_CLASS_PAIR "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
            }
            print("ORDERED_RASTER_CLASS_PAIR_SCOPE \(item["case"]!) crops=\(captures.count) nativeCalls=\(calls); two fixed local readers on original pixels; no resampling, vocabulary correction, formal topology or adoption")
        }
    }
    func testReadablePhysicalHeaderPixelsWithoutRepeatingOCR() throws {
        guard ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_RULE_PIXELS"] == "1",
              let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Requires the dedicated physical-rule observation")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        let cases=try XCTUnwrap(manifest["cases"] as? [[String:Any]])
        XCTAssertEqual(cases.count,2)
        for item in cases {
            let bytes=try Data(contentsOf:directory.appendingPathComponent(try XCTUnwrap(item["file"] as? String)))
            XCTAssertEqual(SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),item["sha256"] as? String)
            let pdf=try XCTUnwrap(PDFDocument(data:bytes)),page=try XCTUnwrap(pdf.page(at:0))
            let bounds=page.bounds(for:.cropBox),scale=min(2,2048/max(bounds.width,bounds.height))
            let image=page.thumbnail(of:CGSize(width:ceil(bounds.width*scale),height:ceil(bounds.height*scale)),for:.cropBox)
            let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
            var rgba=[UInt8](repeating:255,count:cg.width*cg.height*4)
            let made=rgba.withUnsafeMutableBytes { pixels -> Bool in
                guard let context=CGContext(data:pixels.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                let rect=CGRect(x:0,y:0,width:CGFloat(cg.width),height:CGFloat(cg.height))
                context.setFillColor(gray:1,alpha:1);context.fill(rect);context.draw(cg,in:rect);return true
            }
            XCTAssertTrue(made)
            let raster=try RecoveryRasterGrid.fromRGBA(width:cg.width,height:cg.height,pixels:rgba,check:{})
            let rules=try raster.rules(check:{})
            let grid=PDFGrid(page:PDFPageLayout(width:Double(cg.width),height:Double(cg.height),glyphs:[],lines:rules))
            // Probe points select printed bands in this independent source.
            // They never become OCR text, Builder candidates or adoption evidence.
            let day=try grid.box(Double(cg.width)/2,100,check:{}),period=try grid.box(300,150,check:{})
            let checks=["top":rules.contains{$0.horizontal && abs($0.y1-day.top)<0.3 && $0.x1<=day.left+0.3 && $0.x2>=day.right-0.3},
                        "bottom":rules.contains{$0.horizontal && abs($0.y1-day.bottom)<0.3 && $0.x1<=day.left+0.3 && $0.x2>=day.right-0.3},
                        "left":rules.contains{$0.vertical && abs($0.x1-day.left)<0.3 && $0.y1<=day.top+0.3 && $0.y2>=day.bottom-0.3},
                        "right":rules.contains{$0.vertical && abs($0.x1-day.right)<0.3 && $0.y1<=day.top+0.3 && $0.y2>=day.bottom-0.3}]
            let neighbors=rules.filter { ($0.horizontal && $0.y1<=period.top+2) || ($0.vertical && (abs($0.x1-day.left)<2 || abs($0.x1-day.right)<2)) }
            var scans=[[String:Any]]()
            for y in Array(68...76)+Array(119...127) {
                var runs=[[Int]](),start:Int?=nil
                for x in 0...cg.width {
                    if x<cg.width && raster.dark(x,y) { if start==nil {start=x} }
                    else if let first=start { if x-first>=24 {runs.append([first,x-1])};start=nil }
                }
                scans.append(["y":y,"actualDarkRuns":runs])
            }
            let report:[String:Any]=["case":item["case"]!,"nativeOcrCalls":0,"llmCalls":0,"width":cg.width,"height":cg.height,
                "rgbaSHA256":SHA256.hash(data:Data(rgba)).map{String(format:"%02x",$0)}.joined(),"closedEdges":checks,
                "dayBox":[day.left,day.top,day.right,day.bottom],"periodBox":[period.left,period.top,period.right,period.bottom],
                "originalPixelRows":scans,"rules":neighbors.map{[$0.x1,$0.y1,$0.x2,$0.y2]},"qualified":false]
            print("ORDERED_RASTER_RULE_PIXELS "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
        }
    }
    func testNativeMinimumHeightCandidateConfidenceIsMeasuredWithoutSubstitution() async throws {
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_HEADER_PAIR"] == "1" {
            throw XCTSkip("Closed whole-page scores are not repeated for the local header comparison")
        }
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_HEADER_TRACE"] == "1" {
            throw XCTSkip("Native confidence recipe already measured; this observation traces only the failed header predicate")
        }
        guard #available(macOS 26.0,*),
              (ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_CONFIDENCE_ONLY"] == "1" || ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_READABLE"] == "1"),
              let root=ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_FIXTURES"] else {
            throw XCTSkip("Requires dedicated owned confidence observation")
        }
        let directory=URL(fileURLWithPath:root,isDirectory:true)
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("raster-manifest.json"))) as? [String:Any])
        // No literals/oracle are consulted. These are native candidate scores,
        // not calibrated probabilities or permission to adopt a text/table.
        func distribution(_ candidates:[Float?]) -> [String:Any] {
            let finite=candidates.compactMap{$0}.filter{$0.isFinite}
            var values=[String:Int]()
            for value in finite {values[String(value),default:0]+=1}
            return ["observations":candidates.count,"missingTopCandidate":candidates.filter{$0 == nil}.count,
                    "nonfinite":candidates.compactMap{$0}.filter{!$0.isFinite}.count,
                    "zero":finite.filter{$0 == 0}.count,"below085":finite.filter{$0 < 0.85}.count,
                    "minimum":finite.min().map{Double($0)} as Any? ?? NSNull(),
                    "maximum":finite.max().map{Double($0)} as Any? ?? NSNull(),
                    "nativeDistinctValues":values.count,"mostCommonNativeValues":Dictionary(uniqueKeysWithValues:values.sorted { a,b in a.value != b.value ? a.value > b.value : a.key < b.key }.prefix(6).map{($0.key,$0.value)})]
        }
        for item in try XCTUnwrap(manifest["cases"] as? [[String:Any]]) {
            let name=try XCTUnwrap(item["case"] as? String),file=try XCTUnwrap(item["file"] as? String)
            let bytes=try Data(contentsOf:directory.appendingPathComponent(file))
            XCTAssertEqual(SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined(),item["sha256"] as? String)
            let pdf=try XCTUnwrap(PDFDocument(data:bytes)),page=try XCTUnwrap(pdf.page(at:0)),bounds=page.bounds(for:.cropBox)
            let image=page.thumbnail(of:CGSize(width:ceil(bounds.width*2),height:ceil(bounds.height*2)),for:.cropBox)
            let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
            var documentRequest=RecoveryVisionCapture.request()
            documentRequest.textRecognitionOptions.minimumTextHeightFraction=8/Float(cg.height)
            var textRequest=RecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.recognitionLanguages=[Locale.Language(identifier:"ja"),Locale.Language(identifier:"en")]
            textRequest.automaticallyDetectsLanguage=false
            textRequest.usesLanguageCorrection=true
            textRequest.minimumTextHeightFraction=8/Float(cg.height)
            let documents=try await documentRequest.perform(on:cg)
            let text=try await textRequest.perform(on:cg)
            let rootLines=documents.flatMap{$0.document.text.lines}
            let tables=documents.flatMap{$0.document.tables}
            let tableLines=tables.flatMap{$0.rows.flatMap{$0}}.flatMap{$0.content.text.lines}
            let report:[String:Any]=["case":name,"width":cg.width,"height":cg.height,"nativeCalls":2,
                "minimumTextHeightFraction":8/Float(cg.height),"documents":documents.count,"tables":tables.count,
                "documentObservationScores":distribution(documents.map{Optional($0.confidence)}),
                "documentsRootCandidateScores":distribution(rootLines.map{$0.topCandidates(1).first?.confidence}),
                "documentsTableCandidateScores":distribution(tableLines.map{$0.topCandidates(1).first?.confidence}),
                "accurateTextCandidateScores":distribution(text.map{$0.topCandidates(1).first?.confidence}),
                "missingIsNotZero":true,"crossReaderScoreSubstitution":false,"formalQuality":"UNASSESSED",
                "scope":"Same first-page CGImage; native scores and hierarchy only, no oracle or adoption"]
            print("ORDERED_RASTER_CONFIDENCE "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
        }
    }
    func testPairedImageFirstPageResolutionChangesOnlyRenderingDensity() async throws {
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_CONFIDENCE_ONLY"] == "1" || ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_READABLE"] == "1" {
            throw XCTSkip("Prior fixed recipes are not repeated in this dedicated observation")
        }
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
                    // Separate the Documents engine's height effect from the
                    // Text engine comparison. Keep its native table hierarchy;
                    // this oversized research raster cannot enter app capture.
                    var documentRequest=RecoveryVisionCapture.request()
                    let defaultHeight=documentRequest.textRecognitionOptions.minimumTextHeightFraction
                    documentRequest.textRecognitionOptions.minimumTextHeightFraction = 8 / Float(cg.height)
                    let smallDocuments=try await documentRequest.perform(on:cg)
                    let smallDocumentLines=smallDocuments.flatMap{$0.document.text.lines}
                    outputs.append(("source-density-2x-documents-minimum8px",cg.width,cg.height,smallDocumentLines.compactMap{$0.topCandidates(1).first?.string},smallDocumentLines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                    for (condition,documents) in [("default-height",native),("minimum8px",smallDocuments)] {
                        let tables=documents.flatMap{$0.document.tables}
                        XCTAssertLessThanOrEqual(tables.count,1000)
                        let rowCells=tables.flatMap{$0.rows.flatMap{$0}}
                        XCTAssertLessThanOrEqual(rowCells.count,100_000)
                        let tableLines=rowCells.flatMap{$0.content.text.lines}
                        outputs.append(("source-density-2x-documents-table-"+condition,cg.width,cg.height,tableLines.compactMap{$0.topCandidates(1).first?.string},tableLines.filter{($0.topCandidates(1).first?.confidence ?? 0)<0.85}.count))
                        let report:[String:Any]=["case":stem,"condition":condition,"width":cg.width,"height":cg.height,
                            "documents":documents.count,"tables":tables.count,"rows":tables.reduce(0){$0+$1.rows.count},
                            "rowCells":rowCells.count,"mergedCells":rowCells.filter{$0.rowRange.count>1 || $0.columnRange.count>1}.count,
                            "rootLines":documents.reduce(0){$0+$1.document.text.lines.count},"tableLines":tableLines.count,
                            "minimumTextHeightFraction":condition == "default-height" ? defaultHeight : documentRequest.textRecognitionOptions.minimumTextHeightFraction,
                            "formalQuality":"UNASSESSED","scope":"Root and row-axis table output counted separately; no column-axis duplicate or adoption"]
                        print("ORDERED_RASTER_DOCUMENT_HEIGHT "+String(decoding:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys]),as:UTF8.self))
                    }
                }
            }
            // Expected literals are inspected only after all fixed requests return.
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
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_HEADER_PAIR"] == "1" {
            throw XCTSkip("Closed whole-document measurements are not repeated for the local header comparison")
        }
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_RULE_PIXELS_ONLY"] == "1" {
            throw XCTSkip("Closed whole-document OCR measurements are not repeated for physical-pixel diagnostics")
        }
        if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_CONFIDENCE_ONLY"] == "1" {
            throw XCTSkip("Prior whole-document recipe is not repeated in confidence-only observation")
        }
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
            var headerTrace=[[String:Any]]()
            do {
                do {
                    let strict=try PDFKitReader.read(url,kind:.timetable)
                    _=try PDFSchoolParser.parse(strict,kind:.timetable,digest:hash,name:file)
                    XCTFail("Image-only input unexpectedly passed Strict");continue
                } catch let error as PDFParseError { guard RecoveryPolicy.eligible(error) else { throw error } }
                let pdf=try XCTUnwrap(PDFDocument(data:bytes));XCTAssertEqual(pdf.pageCount,ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_READABLE"] == "1" ? 10 : 5)
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
                    var request=RecoveryVisionCapture.request()
                    if ProcessInfo.processInfo.environment["TAKUPOKE_ORDERED_RASTER_READABLE"] == "1" {
                        request.textRecognitionOptions.minimumTextHeightFraction=8/Float(cg.height)
                    }
                    let native=try await request.perform(on:cg)
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
                let capture=RecoveryOCRAcquisitionDraft(sourcePDFHash:hash,documentPageCount:pdf.pageCount,requiredOCRPages:Array(1...pdf.pageCount),pages:pages)
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
                var doc=try RecoveryDocumentBuilder.build(layouts,kind:.timetable,hash:hash,fromOCR:Set(pages.map(\.page)),rasters:prepared,observer:{ number,trace in
                    headerTrace.append(["page":number,"stage":trace.stage,"texts":trace.texts,"lineIds":trace.lineIds,"checks":trace.checks,
                        "boxes":trace.boxes.map { ["x":$0.x,"y":$0.y,"width":$0.width,"height":$0.height] }])
                })
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
            for trace in headerTrace {
                print("ORDERED_RASTER_HEADER_TRACE \(name) "+String(decoding:try JSONSerialization.data(withJSONObject:trace,options:[.sortedKeys]),as:UTF8.self))
            }
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
