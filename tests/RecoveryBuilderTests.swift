import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif
@testable import TakupokeParsing

extension PDFParsingTests {
    private func genericRuledOriginals() throws -> [(record:[String:Any],pages:[PDFPageLayout],rasters:[Int:RecoveryRasterGrid])] {
        let url = Bundle.module.url(forResource:"recovery-generic-ruled-original-two",withExtension:"json",subdirectory:"fixtures")!
        let bytes = try Data(contentsOf:url)
        XCTAssertEqual(SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined(),"7a87ca9355ee2577fb3fab05cfc9dc86ab5d870a8e49f2119b54ef70d260a54c")
        let root = try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        return try (root["cases"] as! [[String:Any]]).map { record in
            var pages = [PDFPageLayout](), rasters = [Int:RecoveryRasterGrid]()
            for p in record["pages"] as! [[String:Any]] {
                let n=p["page"] as! Int,w=p["width"] as! Int,h=p["height"] as! Int
                let encoded=Array(Data(base64Encoded:p["rgbaRunsBase64"] as! String)!),limit=w*h*4
                guard (1...2048).contains(w),(1...2048).contains(h),encoded.count % 8 == 0 else { throw PDFParseError(code:.limit) }
                var rgba=[UInt8](); rgba.reserveCapacity(limit)
                for i in stride(from:0,to:encoded.count,by:8) {
                    let count=(0..<4).reduce(0) { $0 | Int(encoded[i+$1]) << (8*$1) }
                    guard count>0,count<=(limit-rgba.count)/4 else { throw PDFParseError(code:.limit) }
                    for _ in 0..<count { rgba.append(contentsOf:encoded[(i+4)..<(i+8)]) }
                }
                guard rgba.count == limit else { throw PDFParseError(code:.unreadable) }
                XCTAssertEqual(SHA256.hash(data:Data(rgba)).map { String(format:"%02x",$0) }.joined(),p["rgbaSHA256"] as? String)
                let raster=try RecoveryRasterGrid.fromRGBA(width:w,height:h,pixels:rgba),rules=try raster.rules(check:{})
                let glyphs=(p["textsAndInk"] as! [[String:Any]]).enumerated().map { i,t -> PDFGlyph in
                    let b=(t["bbox"] as! [NSNumber]).map(\.doubleValue)
                    return PDFGlyph(text:t["text"] as! String,x:b[0],y:b[1],width:b[2]-b[0],height:b[3]-b[1],sourceLine:(t["y"] as! NSNumber).intValue,sourceOrder:i)
                }
                pages.append(PDFPageLayout(width:Double(w),height:Double(h),glyphs:glyphs,lines:rules));rasters[n]=raster
            }
            return (record,pages,rasters)
        }
    }
    func testGenericRuledRecoveryPreservesOriginalTwoFortySlotFormalOracles() async throws {
        for original in try genericRuledOriginals() {
            let digest=original.record["originalPDFSHA256"] as! String
            let doc=try RecoveryDocumentBuilder.build(original.pages,kind:.timetable,hash:digest,fromOCR:Set(original.rasters.keys),rasters:original.rasters)
            XCTAssertEqual(doc.requiredSlots.count,40); XCTAssertTrue(RecoveryValidator.inputErrors(doc).isEmpty)
            let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
            let result=try XCTUnwrap(run.result); XCTAssertEqual(result.metadata.provider,"rule")
            XCTAssertTrue(RecoveryValidator.validate(doc,result).canAdopt)
            let period=SchoolDataPeriod(day:SchoolDate(iso8601:"\(doc.schoolYear)-\(doc.term == "前期" ? "04" : "10")-01")!)
            let source=RecoverySelectedSource(kind:.timetable,url:URL(fileURLWithPath:"/fictional.pdf"),digest:digest,originalName:"fictional.pdf",storedName:"fictional.pdf",period:period)
            let formal=try RecoveryConversion.timetable(RecoveryPreview(document:doc,result:result,source:source))
            // Independent literal oracle is used only after production conversion.
            let oracle=original.record["oracle"] as! [String:Any],table=oracle["timetable"] as! [String:Any]
            XCTAssertEqual(formal.schoolYear,oracle["schoolYear"] as? Int); XCTAssertEqual(formal.term,table["term"] as? String)
            let actual=formal.lessons.map { ["className":$0.className,"weekday":$0.weekday,"period":$0.period,"names":["subject":$0.names.subject,"teacher":$0.names.teacher,"room":$0.names.room]] as [String:Any] }
            XCTAssertTrue(NSDictionary(dictionary:["lessons":actual]).isEqual(to:["lessons":table["lessons"]!]))
            let expectedSlots=oracle["requiredSlotSet"] as! [[String:Any]]
            XCTAssertEqual(Set(doc.requiredSlots.map { "\($0.className):\($0.day):\($0.period)" }),Set(expectedSlots.map { "\($0["className"]!):\($0["day"]!):\($0["period"]!)" }))
        }
    }
    func testGenericRuledRecoveryRejectsIncompleteDaysDuplicateSlotsAndConflictingHeadings() throws {
        let original=try genericRuledOriginals()[0]
        func rejects(_ pages:[PDFPageLayout],_ reason:String,rasters:[Int:RecoveryRasterGrid]?=nil) {
            let pixels=rasters ?? original.rasters
            XCTAssertThrowsError(try RecoveryDocumentBuilder.build(pages,kind:.timetable,hash:String(repeating:"a",count:64),fromOCR:Set(pixels.keys),rasters:pixels),reason)
        }
        rejects(Array(original.pages.dropLast()),"missing weekday")
        var duplicate=original.pages;duplicate[4]=duplicate[0];rejects(duplicate,"duplicate slots")
        var conflicting=original.pages
        let yearIndex=conflicting[1].glyphs.firstIndex { $0.text == "7" && $0.y < 30 }!
        conflicting[1].glyphs[yearIndex].text="8";rejects(conflicting,"conflicting years")
        var missingPeriod=original.pages
        missingPeriod[0].glyphs.removeAll { $0.text == "8" && $0.y>60 && $0.y<90 };rejects(missingPeriod,"missing period")
        var brokenEdge=original.pages
        let period=brokenEdge[0].glyphs.first { $0.text == "1" && $0.y>60 && $0.y<90 }!
        let header=try PDFGrid(page:brokenEdge[0]).box(period.cx,period.cy,check:{})
        brokenEdge[0].lines.removeAll { $0.vertical && abs($0.x1-header.right)<0.3 };rejects(brokenEdge,"missing physical edge")
    }
    func testGenericRuledRecoveryRejectsNeighbourBodyUnrecognizedInkAndUnprovedBlank() throws {
        let original=try genericRuledOriginals()[1]
        func rejects(_ pages:[PDFPageLayout],_ rasters:[Int:RecoveryRasterGrid]) {
            XCTAssertThrowsError(try RecoveryDocumentBuilder.build(pages,kind:.timetable,hash:String(repeating:"a",count:64),fromOCR:Set(rasters.keys),rasters:rasters))
        }
        var crossing=original.pages
        let bodyIndex=crossing[0].glyphs.firstIndex { $0.text == "架" && $0.y>90 }!
        crossing[0].glyphs[bodyIndex].width=100;rejects(crossing,original.rasters)
        var unknownInk=original.rasters
        var raster=unknownInk[1]!;raster=RecoveryRasterGrid(width:raster.width,height:raster.height,grayscale:raster.grayscale)
        var pixels=raster.grayscale;pixels[190*raster.width+500]=0
        unknownInk[1]=RecoveryRasterGrid(width:raster.width,height:raster.height,grayscale:pixels);rejects(original.pages,unknownInk)
        var blankInk=original.rasters;pixels=raster.grayscale;pixels[130*raster.width+160]=0
        blankInk[1]=RecoveryRasterGrid(width:raster.width,height:raster.height,grayscale:pixels);rejects(original.pages,blankInk)
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(original.pages,kind:.timetable,hash:String(repeating:"a",count:64),fromOCR:Set(original.rasters.keys),rasters:[:]))
    }
    func testGenericRuledRecoveryCancellationRemainsTerminal() throws {
        let original=try genericRuledOriginals()[0];var checks=0
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(original.pages,kind:.timetable,hash:String(repeating:"a",count:64),fromOCR:Set(original.rasters.keys),rasters:original.rasters,check:{checks+=1;if checks==30 {throw PDFParseError(code:.cancelled)}})) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled)
        }
        XCTAssertEqual(checks,30)
    }
    func testGenericRuledRecoveryKeepsOriginalTopologyWorkLimit() throws {
        var original=try genericRuledOriginals()[0]
        let rules=original.pages[0].lines
        original.pages[0].lines=(0..<1100000).map { rules[$0 % rules.count] }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(original.pages,kind:.timetable,hash:String(repeating:"a",count:64))) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
    }
    func testGenericRuledRecoveryCannotDiscardAnUnknownPhysicalClassRow() throws {
        var pages=try genericRuledOriginals()[0].pages
        // A separate negative source control, leaving the original fixture intact:
        // divide a blank day's class/table band into one known and one unknown row.
        let old=pages[1]
        let period=old.glyphs.first { $0.text == "8" && $0.y>60 && $0.y<90 }!
        let right=try PDFGrid(page:old).box(period.cx,period.cy,check:{}).right
        pages[1].lines.append(PDFRule(x1:0,y1:128,x2:right,y2:128))
        for i in pages[1].glyphs.indices where pages[1].glyphs[i].x<90 && pages[1].glyphs[i].y>90 { pages[1].glyphs[i].y-=23 }
        let originalClass=old.glyphs.filter { $0.x<90 && $0.y>90 }
        pages[1].glyphs += originalClass.enumerated().map { i,g in
            var next=g;next.text=["9","_","Z","Z"][i];next.y+=20;next.sourceOrder=1000+i;next.sourceLine=1000;return next
        }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build(pages,kind:.timetable,hash:String(repeating:"a",count:64))) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.classLabel)
        }
    }
    func testDenseCalibrationIgnoresOutsideTextWithoutExhaustingWorkBudget() throws {
        var glyphs = [PDFGlyph](), references = [PDFBox](), targets = [PDFBox]()
        for row in 0..<34 {
            for column in 0..<20 {
                let x = 10+Double(column)*85, y = 10+Double(row)*60
                let target = PDFBox(left:x,top:y,right:x+40,bottom:y+60)
                targets.append(target); glyphs += text("架空A",x:x+4,y:y+12)
                references.append(PDFBox(left:x+40,top:y,right:x+80,bottom:y+60))
                for (i,line) in ["架空B","担当B","室B"].enumerated() {
                    glyphs += text(line,x:x+44,y:y+12+Double(i)*18)
                }
            }
        }
        glyphs += Array(repeating:PDFGlyph(text:"x",x:1800,y:2100,width:1,height:1),count:74000)
        XCTAssertLessThan(glyphs.count,100000)
        let grid = PDFGrid(page:PDFPageLayout(width:2200,height:2200,glyphs:glyphs,lines:[]))
        for target in targets {
            XCTAssertEqual(try grid.lessonFields(target,lines:["架空A"],referenceBoxes:references),["架空A","",""])
            XCTAssertEqual(try grid.glyphs(in:target,check:{}).map(\.text).joined(),"架空A")
        }
    }
    func testCalibrationSourceScanCancelsAndDoesNotCacheAPartialReference() throws {
        let target = PDFBox(left:10,top:10,right:50,bottom:70)
        let reference = PDFBox(left:60,top:10,right:100,bottom:70)
        var glyphs = text("架空科目A",x:14,y:22)
        for (i,line) in ["架空科目B","架空教員B","架空室B"].enumerated() {
            glyphs += text(line,x:64,y:22+Double(i)*18)
        }
        glyphs += Array(repeating:PDFGlyph(text:"x",x:110,y:100,width:1,height:1),count:99900)
        let grid = PDFGrid(page:PDFPageLayout(width:120,height:120,glyphs:glyphs,lines:[]))
        var checks = 0
        XCTAssertThrowsError(try grid.lessonFields(target,lines:["架空科目A"],referenceBoxes:[reference],check:{
            checks += 1; if checks == 50 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,50)
        XCTAssertEqual(try grid.lessonFields(target,lines:["架空科目A"],referenceBoxes:[reference]),["架空科目A","",""])
        XCTAssertEqual(try grid.lessonFields(target,lines:["架空科目A"],referenceBoxes:[reference]),["架空科目A","",""])
    }
    func testCalibrationReferenceInventoryChargesHeightMismatchAndCancels() throws {
        let box = PDFBox(left:10,top:10,right:50,bottom:70)
        let grid = PDFGrid(page:PDFPageLayout(width:100,height:100,glyphs:text("架空A",x:14,y:22),lines:[]))
        let references = (0..<10001).map { PDFBox(left:Double($0),top:0,right:Double($0)+1,bottom:1) }
        XCTAssertThrowsError(try grid.lessonFields(box,lines:["架空A"],referenceBoxes:references)) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
        var checks = 0
        XCTAssertThrowsError(try grid.lessonFields(box,lines:["架空A"],referenceBoxes:references,check:{
            checks += 1; if checks == 3 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,3)
    }
    func testBuilderNeverConvertsCancelledCalibrationIntoStructureRecovery() {
        var checks = 0
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([recoveryTimetablePage()],kind:.timetable,hash:String(repeating:"b",count:64),check:{
            checks += 1; if checks == 8 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,8)
    }
    func testMalformedAnnualNumericColumnsCannotHideBehindAValidYear() throws {
        for malformed in ["令和100年度","令和0年度","12026年度","202年度","10000年度", "999999999999999999999999年度", "令和①⓪⓪年度", "１２０２６年度", "令 和 1 0 0 年 度", "1 2 0 2 6 年 度", "令和Ⅸ年度", "ⅯⅯⅩⅩⅥ年度", "令和ⅰ年度", "令和9年度", "㋿9年度", "令和Ⅸ年度", "𝟚𝟘𝟚𝟟年度", "令和九年度", "令和年度"] {
            XCTAssertThrowsError(try PDFSchoolParser.uniqueTitleYear("令和8年度"+malformed+"前期時間割")) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.yearHeading)
            }
        }
        for title in ["令和8年度令和８年度", "２０２６年度令和8年度", "令和⑧年度2026年度", "令 和 8 年 度2 0 2 6 年 度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度"] {
            let markers = try PDFSchoolParser.yearMarkers(title)
            XCTAssertEqual(markers.count,2)
            XCTAssertTrue(markers.allSatisfy { $0.year == 2026 })
            XCTAssertEqual(try PDFSchoolParser.uniqueTitleYear(title),2026)
            XCTAssertEqual(markers.map { String(title[$0.range]) }.joined(),title)
        }
    }

    func testOrdinaryTitleYearMustBeUniqueWhileRepeatedEquivalentYearsRemainValid() throws {
        func page(_ title: String) -> PDFPageLayout {
            var value = timetable(); value.glyphs.removeAll { $0.cy == 20 }
            value.glyphs += text(title,x:200,y:20)
            return value
        }
        for title in ["令和14年度令和14年度前期時間割","2032年度令和14年度前期時間割", "令 和 1 4 年 度2 0 3 2 年 度前期時間割", "㋿14年度2032年度前期時間割"] {
            XCTAssertEqual(try parse([page(title)],kind:.timetable).schoolYear,2032)
        }
        for title in ["令和13年度令和14年度前期時間割","令和14年度令和13年度前期時間割",
                      "令和14年度令和100年度前期時間割","令和14年度12032年度前期時間割",
                      "令和14年度令和0年度前期時間割","令和14年度99999999999999999999年度前期時間割", "令和14年度令 和 1 0 0 年 度前期時間割", "令和14年度令和Ⅸ年度前期時間割", "令和14年度令和15年度前期時間割", "令和14年度㋿15年度前期時間割", "令和14年度令和九年度前期時間割", "令和14年度令和年度前期時間割"] {
            XCTAssertThrowsError(try parse([page(title)],kind:.timetable)) {
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.yearHeading)
            }
        }
    }
    func testRecoveryTitleYearEvidenceMustIncludeEveryEquivalentMarker() async throws {
        func page(_ title: String) -> PDFPageLayout {
            var value = recoveryTimetablePage(); value.glyphs.removeAll { $0.cy == 20 }
            value.glyphs += text(title,x:200,y:20)
            return value
        }
        for title in ["令和14年度令和14年度前期時間割","2032年度令和14年度前期時間割", "㋿14年度2032年度前期時間割"] {
            let doc = try RecoveryDocumentBuilder.build([page(title)],kind:.timetable,hash:String(repeating:"b",count:64))
            XCTAssertEqual(doc.schoolYear,2032); XCTAssertEqual(doc.yearEvidence.count,2)
            let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation)
        }
        for title in ["令和13年度令和14年度前期時間割","令和14年度令和13年度前期時間割",
                      "令和14年度令和100年度前期時間割","令和14年度12032年度前期時間割",
                      "令和14年度令和0年度前期時間割","令和14年度99999999999999999999年度前期時間割", "令和14年度令 和 1 0 0 年 度前期時間割", "令和14年度令和Ⅸ年度前期時間割", "令和14年度令和15年度前期時間割", "令和14年度㋿15年度前期時間割", "令和14年度令和九年度前期時間割", "令和14年度令和年度前期時間割"] {
            do {
                let doc = try RecoveryDocumentBuilder.build([page(title)],kind:.timetable,hash:String(repeating:"b",count:64))
                let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
                XCTFail("Invalid annual marker reached \(run.state.rawValue): \(run.errors)")
            } catch let error as PDFParseError { XCTAssertEqual(error.stage,.yearHeading) }

        }
        let spaced = try RecoveryDocumentBuilder.build([page("令 和 1 4 年 度2 0 3 2 年 度前期時間割")],kind:.timetable,hash:String(repeating:"b",count:64))
        XCTAssertEqual(spaced.schoolYear,2032); XCTAssertEqual(spaced.yearEvidence.count,2)
        let run = try await RecoveryEngine.run(spaced,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
    func testSourceIdentityIndexPreservesDuplicateAmbiguityAndCancellation() throws {
        let a = PDFGlyph(text:"A",x:10,y:20,width:4,height:8,sourceOrder:0)
        let b = PDFGlyph(text:"A",x:10,y:20,width:4,height:8,sourceOrder:1)
        let c = PDFGlyph(text:"A",x:20,y:20,width:4,height:8,sourceOrder:0)
        let index = try RecoveryGlyphIndex([a,b,a,c],check:{})
        XCTAssertEqual(try index.indices(for:[a],check:{}),[0,2])
        XCTAssertEqual(try index.indices(for:[b,c],check:{}),[1,3])
        XCTAssertEqual(try index.indices(for:[a,a],check:{}),[0,2])
        var checks = 0
        XCTAssertThrowsError(try RecoveryGlyphIndex(Array(repeating:a,count:100000),check:{
            checks += 1; if checks == 2 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,2)
        let dense = try RecoveryGlyphIndex(Array(repeating:a,count:100000),check:{})
        checks = 0
        XCTAssertThrowsError(try dense.indices(for:[a],check:{
            checks += 1; if checks == 2 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,2)
    }
    func testRasterRuleGraphStopsAtItsComparisonBudgetAndChecksCancellationInsidePass() {
        let lines = (0..<1100).map { PDFRule(x1:10,y1:Double($0)*4,x2:50,y2:Double($0)*4) }
        XCTAssertThrowsError(try RecoveryRasterGrid.connectedRules(lines,check:{})) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
        var checks = 0
        XCTAssertThrowsError(try RecoveryRasterGrid.connectedRules(lines,check:{
            checks += 1
            if checks == 2 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,2)
        let covered = RecoveryBox(x:0,y:0,width:128,height:128)
        let dense = RecoveryRasterGrid(width:128,height:128,grayscale:[UInt8](repeating:0,count:128*128))
        let outside = RecoveryBox(x:200,y:200,width:10,height:10)
        XCTAssertThrowsError(try dense.hasUncoveredInk(covered,text:Array(repeating:outside,count:2000)+[covered],rules:[],check:{})) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.limit)
        }
    }
    func testRasterInkAndRuleMaskCheckCancellationInsideTheirPixelLoops() throws {
        let size = 512, pixels = [UInt8](repeating:0,count:size*size)
        let raster = RecoveryRasterGrid(width:size,height:size,grayscale:pixels)
        let rules = [PDFRule(x1:0,y1:20,x2:511,y2:20)]
        var checks = 0
        XCTAssertThrowsError(try raster.preparingRules(rules,check:{
            checks += 1
            if checks == 2 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,2)
        checks = 0
        let box = RecoveryBox(x:0,y:0,width:512,height:512)
        XCTAssertThrowsError(try raster.hasUncoveredInk(box,text:[box],rules:[],check:{
            checks += 1
            if checks == 2 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,2)
    }
    func testOffscreenRecoveryLayoutFailsBeforeSourceBindingOrAI() {
        var page = recoveryTimetablePage()
        for index in page.glyphs.indices { page.glyphs[index].x += 3000 }
        for index in page.lines.indices { page.lines[index].x1 += 3000; page.lines[index].x2 += 3000 }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64))) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.rasterInput)
        }
    }
    func recoveryTimetablePage(labeled: Bool = false) -> PDFPageLayout {
        var p = timetable(); p.width = 1900
        p.glyphs.removeAll { $0.cy == 70 }
        p.lines.removeAll { $0.vertical && $0.y1 == 60 && $0.y2 == 80 }
        for i in 0..<40 {
            p.glyphs += text(String(i%8+1),x:108+Double(i)*40,y:70)
            p.lines.append(v(100+Double(i)*40,60,80))
        }
        p.lines.append(v(1700,60,80))
        p.lines.removeAll { $0.vertical && $0.x1 >= 100 && $0.y1 == 100 }
        for i in 0...40 { p.lines.append(v(100+Double(i)*40,100,280)) }
        for i in p.lines.indices where p.lines[i].horizontal { p.lines[i].x2 = 1700 }
        for i in p.glyphs.indices {
            if p.glyphs[i].x == 70 && [130.0,190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "C" }
            if p.glyphs[i].x == 74 && [130.0,190.0].contains(p.glyphs[i].cy) { p.glyphs[i].text = "N" }
            if p.glyphs[i].x == 70 && p.glyphs[i].cy == 250 { p.glyphs[i].text = "2" }
        }
        for (i,label) in ["月","火","水","木","金"].enumerated() { p.glyphs += text(label,x:200+Double(i)*320,y:50) }
        if labeled {
            p.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
            for (i,line) in ["教員:架空担当R","教室:架空室S","科目:架空科目T"].enumerated() { p.glyphs += text(line,x:102,y:110+Double(i)*18,step:3) }
        }
        return p
    }
    func testLayoutRecoveryPreservesParallelLessonsAndAllSlots() async throws {
        let p = recoveryTimetablePage()
        let d = try RecoveryDocumentBuilder.build([p],kind:.timetable,hash:String(repeating:"b",count:64))
        XCTAssertEqual(d.classes.count,3); XCTAssertEqual(d.cells.flatMap(\.slots).count,120)
        XCTAssertTrue(d.cells.contains { $0.parallelCount == 2 && $0.parallelSeparators.count == 3 })
        let run = try await RecoveryEngine.run(d,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
        XCTAssertEqual(run.result?.metadata.provider,"rule")
    }
    private func recoveryTimetableReplacingParallelFields(_ fields: [String]) -> PDFPageLayout {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 160 && $0.cy < 220 }
        for (index, value) in fields.enumerated() {
            page.glyphs += text(value, x: 104, y: 172 + Double(index) * 18, step: 2)
        }
        return page
    }
    func testLayoutRecoveryCannotBypassUnalignedParallelEvidenceRefusal() {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let paired = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for unchangedRole in 0..<3 {
            var fields = paired
            fields[unchangedRole] = single[unchangedRole]
            XCTAssertThrowsError(try RecoveryDocumentBuilder.build([recoveryTimetableReplacingParallelFields(fields)],
                kind: .timetable, hash: String(repeating: "b", count: 64))) {
                XCTAssertEqual(($0 as? PDFParseError)?.code, .ambiguous)
                XCTAssertEqual(($0 as? PDFParseError)?.stage, .parallelLessons)
            }
        }
    }
    func testLayoutRecoveryKeepsACompoundSingleRoleLiteralThroughRulesAndValidator() async throws {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let compound = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for compoundRole in 0..<3 {
            var fields = single
            fields[compoundRole] = compound[compoundRole]
            let doc = try RecoveryDocumentBuilder.build([recoveryTimetableReplacingParallelFields(fields)],
                kind: .timetable, hash: String(repeating: "b", count: 64))
            let cell = try XCTUnwrap(doc.cells.first { $0.slots.contains { $0.className == "2_CN" && $0.day == "1" && $0.period == 1 } })
            XCTAssertEqual(cell.parallelCount, 1)
            let run = try await RecoveryEngine.run(doc, os: "ios", osMajor: 26, foreground: true,
                providers: [], rule: { _ in nil }, check: {})
            XCTAssertEqual(run.state, .awaitingConfirmation)
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc, result).errors.isEmpty)
            let recovered = try XCTUnwrap(result.cells.first { $0.cellId == cell.id })
            XCTAssertEqual(recovered.lessons.count, 1)
            XCTAssertEqual(recovered.lessons[0].subject.value, fields[0])
            XCTAssertEqual(recovered.lessons[0].teacher.value, fields[1])
            XCTAssertEqual(recovered.lessons[0].room.value, fields[2])
        }
    }
    private func recoveryTimetableWithInlineFields(_ fields: [String]) -> PDFPageLayout {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { $0.x >= 100 && $0.x < 140 && $0.cy > 100 && $0.cy < 160 }
        for (index, field) in fields.enumerated() {
            let label = ["科目：", "教員：", "教室："][index]
            page.glyphs += text(label+field, x: 102, y: 110+Double(index)*18, step: 2)
        }
        return page
    }
    func testInlineRoleScopesCannotCollapseMatchedOrMismatchedMultipleBodyRoles() {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let paired = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for unchangedRole in [-1,0,1,2] {
            var fields = paired
            if unchangedRole >= 0 { fields[unchangedRole] = single[unchangedRole] }
            XCTAssertThrowsError(try RecoveryDocumentBuilder.build([recoveryTimetableWithInlineFields(fields)],
                kind:.timetable,hash:String(repeating:"b",count:64))) {
                XCTAssertEqual(($0 as? PDFParseError)?.code,.ambiguous)
                XCTAssertEqual(($0 as? PDFParseError)?.stage,.parallelLessons)
            }
        }
    }
    func testInlineRoleScopesKeepEachSingleCompoundRoleWithoutParallelInvention() async throws {
        let single = ["架空科目A", "架空教員A", "架空室A"]
        let compound = ["架空科目A・架空科目B", "架空教員A・架空教員B", "架空室A・架空室B"]
        for compoundRole in 0..<3 {
            var fields = single; fields[compoundRole] = compound[compoundRole]
            let doc = try RecoveryDocumentBuilder.build([recoveryTimetableWithInlineFields(fields)],kind:.timetable,hash:String(repeating:"b",count:64))
            let cell = try XCTUnwrap(doc.cells.first { $0.slots.contains { $0.className == "1_CN" && $0.day == "1" && $0.period == 1 } })
            XCTAssertEqual(cell.bindingMode,.roleProposal); XCTAssertEqual(cell.parallelCount,1)
            let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{_ in nil},check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation)
            let result = try XCTUnwrap(run.result)
            XCTAssertTrue(RecoveryValidator.validate(doc,result).errors.isEmpty)
            let recovered = try XCTUnwrap(result.cells.first { $0.cellId == cell.id })
            XCTAssertEqual(recovered.lessons[0].subject.value,fields[0])
            XCTAssertEqual(recovered.lessons[0].teacher.value,fields[1])
            XCTAssertEqual(recovered.lessons[0].room.value,fields[2])
        }
    }
    func testReorderedInlineRolesRequireIndependentLabels() throws {
        let d = try RecoveryDocumentBuilder.build([recoveryTimetablePage(labeled:true)],kind:.timetable,hash:String(repeating:"b",count:64))
        let cell = try XCTUnwrap(d.cells.first { $0.bindingMode == .roleProposal })
        XCTAssertEqual(Set(cell.roleScopes.map(\.role)),Set(RecoveryRole.allCases))
        XCTAssertNotNil(RecoveryRules.recover(d,cell))
    }
    func testMultiCharacterTermGlyphFailsWithoutOutOfBoundsAccess() {
        var page = recoveryTimetablePage()
        let prefix = page.glyphs.firstIndex { $0.text == "前" }!
        let suffix = page.glyphs.firstIndex { $0.text == "期" }!
        page.glyphs[prefix].text = "前期"
        page.glyphs[prefix].y = 30
        page.glyphs.remove(at:suffix)
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64))) { error in
            XCTAssertEqual((error as? PDFParseError)?.code,.ambiguous)
        }
    }
    func testPartialReorderedRoleLabelsCannotBecomeFixedOrParallelBindings() {
        for parallel in [false,true] {
          for label in RecoveryRole.teacher.labels {
            var page = recoveryTimetablePage()
            page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 }
            let lines = parallel ? [label+":A・B","C・D","E・F"] : [label+":A","C","E"]
            for (i,line) in lines.enumerated() { page.glyphs += text(line,x:102,y:110+Double(i)*18,step:3) }
            XCTAssertThrowsError(try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64)))
          }
        }
    }
    func testTeacherOnlyCellCannotUseOutsideTableOrConflictingRoleCalibration() {
        for outside in [true,false] {
            var page = timetable()
            page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 && $0.cy != 130 }
            let x = outside ? 920.0 : 144.0, top = outside ? 400.0 : 100.0
            if outside { page.lines += [h(top,920,1040),h(top+60,920,1040),v(920,top,top+60),v(1040,top,top+60)] }
            for (index,line) in ["架空注記A","架空注記B","架空注記C"].enumerated() {
                page.glyphs += text(line,x:x+4,y:top+30+Double(index)*12)
            }
            XCTAssertThrowsError(try parse([page],kind:.timetable)) { error in
                XCTAssertEqual((error as? PDFParseError)?.stage,.lessonLines)
            }
        }
    }
    func testRecoveryCannotCalibrateTeacherOnlyCellFromOutsideTable() {
        var page = recoveryTimetablePage()
        page.glyphs.removeAll { 100 <= $0.cx && $0.cx < 140 && 100 < $0.cy && $0.cy < 160 && $0.cy != 130 }
        page.lines += [h(400,1750,1850),h(460,1750,1850),v(1750,400,460),v(1850,400,460)]
        for (index,line) in ["架空注記A","架空注記B","架空注記C"].enumerated() {
            page.glyphs += text(line,x:1754,y:430+Double(index)*12)
        }
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64)))
    }
    func testFractionalRasterCellIncludesEveryInteriorPixelCenter() {
        let box = RecoveryBox(x:10.25,y:10.25,width:20.5,height:20.5)
        for (x,y) in [(10,15),(30,15),(15,10),(15,30)] {
            var pixels = [UInt8](repeating:255,count:50*50); pixels[y*50+x] = 254
            let raster = RecoveryRasterGrid(width:50,height:50,grayscale:pixels)
            XCTAssertTrue(raster.hasUncoveredInk(box,text:[],rules:[]))
            XCTAssertFalse(raster.isBlank(box))
        }
        let blank = RecoveryRasterGrid(width:50,height:50,grayscale:[UInt8](repeating:255,count:50*50))
        XCTAssertTrue(blank.isBlank(box))
        var outside = [UInt8](repeating:255,count:50*50); outside[15*50+9] = 254
        XCTAssertTrue(RecoveryRasterGrid(width:50,height:50,grayscale:outside).isBlank(box))
    }
    func testStrictMissingTeacherDoesNotShiftRoomIntoTeacher() throws {
        var p = timetable(); p.glyphs.removeAll { $0.cy == 130 && $0.cx >= 100 }
        let result = try parse([p],kind:.timetable)
        let lesson = try XCTUnwrap(result.lessons.first { $0.className == "1_ZZ" })
        XCTAssertEqual(lesson.names.teacher,""); XCTAssertEqual(lesson.names.room,"架空室Q")
        p.glyphs.removeAll { $0.cy == 190 && $0.cx >= 100 }
        XCTAssertThrowsError(try parse([p],kind:.timetable))
    }
}

extension SpecialScheduleTests {
    func testDenseRecoverySourceGroupsUseOneIndexAndRemainCancellable() async throws {
        let bands = [0..<3,3..<6,6..<9,9..<12,12..<17]
        let pages = bands.map { rows -> PDFPageLayout in
            var page = returnPageWithSplitCell()
            page.glyphs.removeAll { glyph in
                guard glyph.cy >= 120 && glyph.cy < 545 else { return false }
                return glyph.x >= 140 || !rows.contains(Int((glyph.cy-120)/25))
            }
            page.lines.removeAll { $0.y1 >= 110 && $0.y1 <= 545 }
            for column in 0...40 { page.lines.append(PDFRule(x1:140+Double(column)*40,y1:120,x2:140+Double(column)*40,y2:545)) }
            page.lines.append(PDFRule(x1:110,y1:120,x2:110,y2:545))
            for row in 0...17 { page.lines.append(PDFRule(x1:0,y1:120+Double(row)*25,x2:1740,y2:120+Double(row)*25)) }
            for i in page.glyphs.indices { page.glyphs[i].x *= 3; page.glyphs[i].width *= 3 }
            for i in page.lines.indices { page.lines[i].x1 *= 3; page.lines[i].x2 *= 3 }
            page.width *= 3
            for row in rows {
                for column in 0..<40 {
                    for (role,line) in ["架S","架T","架R"].enumerated() {
                        for group in 0..<24 {
                            for (letter,char) in line.enumerated() {
                                page.glyphs.append(PDFGlyph(text:String(char),x:423+Double(column)*120+Double(group)*3.5+Double(letter)*0.2,y:123+Double(row)*25+Double(role)*6,width:0.2,height:2))
                            }
                        }
                    }
                }
            }
            return page
        }
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.return,hash:String(repeating:"e",count:64))
        XCTAssertEqual(doc.cells.count,680)
        // Actual iOS Builder reachability: one original span per fixed field.
        XCTAssertEqual(doc.sources.count,2388)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation,run.errors.joined(separator:","))
        let result = try XCTUnwrap(run.result)
        XCTAssertEqual(result.cells.count,680)
        XCTAssertEqual(result.cells[0].lessons[0].subject.value,String(repeating:"架S",count:24))
        // Independent schema-contract fixture, distinct from the shipping
        // Builder's coarser field spans. Text, order, and atom geometry remain
        // those of the entirely fictional original layout above.
        var atoms = doc, atomResult = result, split = [String:[String]](), expanded = [RecoverySource]()
        for source in doc.sources {
            if source.cellId.hasPrefix("cell-"), source.text.count == 48 {
                var ids = [String]()
                for group in 0..<24 {
                    var atom = source; atom.id += "-atom-\(group)"
                    atom.text = String(source.text.prefix(2)); atom.box.x += Double(group)*3.5; atom.box.width = 0.4
                    ids.append(atom.id); expanded.append(atom)
                }
                split[source.id] = ids
            } else { expanded.append(source) }
        }
        func expand(_ ids:[String]) -> [String] { ids.flatMap { split[$0] ?? [$0] } }
        atoms.sources = expanded
        for i in atoms.cells.indices {
            atoms.cells[i].sourceIds = expand(atoms.cells[i].sourceIds)
            for j in atoms.cells[i].lessonBindings.indices {
                atoms.cells[i].lessonBindings[j].subject = expand(atoms.cells[i].lessonBindings[j].subject)
                atoms.cells[i].lessonBindings[j].teacher = expand(atoms.cells[i].lessonBindings[j].teacher)
                atoms.cells[i].lessonBindings[j].room = expand(atoms.cells[i].lessonBindings[j].room)
            }
        }
        for i in atomResult.cells.indices {
            for j in atomResult.cells[i].lessons.indices {
                atomResult.cells[i].lessons[j].subject.evidence = expand(atomResult.cells[i].lessons[j].subject.evidence)
                atomResult.cells[i].lessons[j].teacher.evidence = expand(atomResult.cells[i].lessons[j].teacher.evidence)
                atomResult.cells[i].lessons[j].room.evidence = expand(atomResult.cells[i].lessons[j].room.evidence)
            }
        }
        XCTAssertEqual(atoms.sources.count,49308)
        let contractStart = Date()
        XCTAssertEqual(RecoveryValidator.validate(atoms,atomResult).errors,[])
        print("RECOVERY PERFORMANCE: actualBuilderCells=\(doc.cells.count) actualBuilderSources=\(doc.sources.count) independentContractSources=\(atoms.sources.count) contractValidationSeconds=\(Date().timeIntervalSince(contractStart))")
        let atomRun = try await RecoveryEngine.run(atoms,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(atomRun.state,.awaitingConfirmation,atomRun.errors.joined(separator:","))
        XCTAssertEqual(atomRun.result,atomResult)
        var innerChecks = -1000000
        let indexedWork = RecoveryValidationWork(check:{ if innerChecks >= 0 { innerChecks += 1; if innerChecks == 30 { throw PDFParseError(code:.cancelled) } } })
        let indexed = try RecoverySourceIndex(atoms.sources,work:indexedWork)
        innerChecks = 0
        XCTAssertThrowsError(try RecoveryValidator.validate(atoms,atomResult,index:indexed,work:indexedWork)) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(innerChecks,30)

        var checks = 0
        XCTAssertThrowsError(try RecoveryValidator.validate(doc,result,check:{
            checks += 1; if checks == 50 { throw PDFParseError(code:.cancelled) }
        })) { XCTAssertEqual(($0 as? PDFParseError)?.code,.cancelled) }
        XCTAssertEqual(checks,50)
        var checksDuringEngine = 0
        do {
            _ = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{
                checksDuringEngine += 1; if checksDuringEngine == 50 { throw PDFParseError(code:.cancelled) }
            })
            XCTFail("Cancelled recovery continued")
        } catch let error as PDFParseError { XCTAssertEqual(error.code,.cancelled) }
        XCTAssertEqual(checksDuringEngine,50)
    }


    func testRecoverySpecialTitleYearEvidenceCannotIgnoreASecondYear() async throws {
        for kind: RecoveryDocumentKind in [.exam,.return] {
            let originals = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            func pages(_ years: String) -> [PDFPageLayout] {
                var result = originals; result[0].glyphs.removeAll { $0.y == 20 }
                let title = years+(kind == .exam ? "試験時間割":"試験返却時間割")
                result[0].glyphs += title.enumerated().map { PDFGlyph(text:String($0.element),x:20+Double($0.offset)*4,y:20,width:4,height:4) }
                return result
            }
            for years in ["令和8年度令和8年度","2026年度令和8年度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度"] {
                let doc = try RecoveryDocumentBuilder.build(pages(years),kind:kind,hash:String(repeating:"c",count:64))
                XCTAssertEqual(doc.schoolYear,2026)
                XCTAssertEqual(doc.yearEvidence.count,kind == .exam ? 7:2)
                let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
                XCTAssertEqual(run.state,.awaitingConfirmation)
            }
            for years in ["令和7年度令和8年度","令和8年度令和7年度",
                          "令和8年度令和100年度","令和8年度12026年度",
                          "令和8年度令和0年度","令和8年度99999999999999999999年度", "令和8年度令 和 1 0 0 年 度", "令和8年度令和Ⅸ年度", "令和8年度令和9年度", "令和8年度㋿9年度", "令和8年度𝟚𝟘𝟚𝟟年度", "令和8年度令和九年度", "令和8年度令和年度"] {
                do {
                    let doc = try RecoveryDocumentBuilder.build(pages(years),kind:kind,hash:String(repeating:"c",count:64))
                    let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
                    XCTFail("Invalid annual marker reached \(run.state.rawValue): \(run.errors)")
                } catch let error as PDFParseError { XCTAssertEqual(error.stage,.yearHeading) }

            }
            let spaced = try RecoveryDocumentBuilder.build(pages("令 和 8 年 度2 0 2 6 年 度"),kind:kind,hash:String(repeating:"c",count:64))
            XCTAssertEqual(spaced.schoolYear,2026); XCTAssertEqual(spaced.yearEvidence.count,kind == .exam ? 7:2)
            let run = try await RecoveryEngine.run(spaced,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
            XCTAssertEqual(run.state,.awaitingConfirmation)
        }
    }
    func testSpecialTitleYearMustBeUniqueAndEquivalentYearMarkersRemainValid() throws {
        for kind: SpecialScheduleKind in [.exam,.examReturn] {
            let originals = kind == .exam ? (1...6).map { examPage($0) } : [returnPageWithSplitCell()]
            func pages(_ years: String) -> [PDFPageLayout] {
                var result = originals
                result[0].glyphs.removeAll { $0.y == 20 }
                let title = years+(kind == .exam ? "試験時間割":"試験返却時間割")
                result[0].glyphs += title.enumerated().map { PDFGlyph(text:String($0.element),x:20+Double($0.offset)*4,y:20,width:4,height:8) }
                return result
            }
            for years in ["令和8年度令和8年度","2026年度令和8年度", "令 和 8 年 度2 0 2 6 年 度", "㋿8年度2026年度", "令和8年度𝟚𝟘𝟚𝟞年度"] {
                XCTAssertEqual(try SpecialScheduleParser.parse(pages(years),kind:kind,digest:"fictional",name:"fictional.pdf").schoolYear,2026)
            }
            for years in ["令和7年度令和8年度","令和8年度令和7年度",
                          "令和8年度令和100年度","令和8年度12026年度",
                          "令和8年度令和0年度","令和8年度99999999999999999999年度", "令和8年度令 和 1 0 0 年 度", "令和8年度令和Ⅸ年度", "令和8年度令和9年度", "令和8年度㋿9年度", "令和8年度𝟚𝟘𝟚𝟟年度", "令和8年度令和九年度", "令和8年度令和年度"] {
                XCTAssertThrowsError(try SpecialScheduleParser.parse(pages(years),kind:kind,digest:"fictional",name:"fictional.pdf")) {
                    XCTAssertEqual(($0 as? PDFParseError)?.stage,.yearHeading)
                }
            }
        }
    }
    func testExamLayoutRecoveryReusesAllRepeatedClockCharts() async throws {
        let pages = (1...6).map { examPage($0,mergedFirstTwo:$0 == 1) }
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.exam,hash:String(repeating:"c",count:64))
        XCTAssertEqual(doc.classes.count,17); XCTAssertEqual(doc.days.count,5)
        XCTAssertEqual(doc.clockReplicas["2026-04-01:1"]?.count,5)
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
    func testExamDerivedSpanOnLaterPageUsesVerifiedPrimaryEndpointChart() async throws {
        var pages = (1...6).map { examPage($0,mergedFirstTwo:$0 == 2) }
        for i in pages.indices { pages[i].glyphs.removeAll { $0.x >= 300 && $0.y == 470 } }
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.exam,hash:String(repeating:"c",count:64))
        XCTAssertEqual(doc.spanTimes["2026-04-01:1-2"],"08:50〜10:35")
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
    func testReturnDerivedSpanOnLaterPageUsesApplicableNormalNote() async throws {
        var pages = [returnPageWithSplitCell(),returnPageWithSplitCell()]
        for i in pages.indices {
            pages[i].glyphs.removeAll { glyph in
                guard glyph.cy >= 120 && glyph.cy < 545 else { return false }
                let row = Int((glyph.cy-120)/25)
                return i == 0 ? row >= 9 : row < 9
            }
        }
        pages[1].lines.removeAll { $0.vertical && $0.x1 == 660 }
        pages[1].lines += [PDFRule(x1:660,y1:110,x2:660,y2:345),PDFRule(x1:660,y1:370,x2:660,y2:545)]
        let doc = try RecoveryDocumentBuilder.build(pages,kind:.return,hash:String(repeating:"d",count:64))
        XCTAssertEqual(doc.spanTimes["2026-04-02:5-6"],"12:50〜14:20")
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
    }
    func testReturnLayoutRecoveryRequiresNormalTimeNoteAndSpanEndpoints() async throws {
        let doc = try RecoveryDocumentBuilder.build([returnPageWithSplitCell()],kind:.return,hash:String(repeating:"d",count:64))
        XCTAssertEqual(doc.classes.count,17)
        XCTAssertEqual(doc.spanTimes["2026-04-02:5-6"],"12:50〜14:20")
        let run = try await RecoveryEngine.run(doc,os:"ios",osMajor:26,foreground:true,providers:[],rule:{ _ in nil },check:{})
        XCTAssertEqual(run.state,.awaitingConfirmation)
        var changed = doc
        changed.spanTimes["2026-04-02:5-6"] = "12:50〜15:15"
        XCTAssertTrue(RecoveryValidator.validate(changed,try XCTUnwrap(run.result)).errors.contains("normalSpanTimeCondition"))
    }
}

extension PDFParsingTests {
    // Independent synthetic ink markers test coverage, not font recognition accuracy.
    private func twoClassRasterCoverage(annotation:Bool = false,unknownAnnotation:Bool = false) throws -> (PDFPageLayout,RecoveryRasterGrid) {
        let width=740,height=480
 var glyphs=[PDFGlyph](),rules=[PDFRule](),sourceLine=0
 func text(_ value:String,_ x:Double,_ y:Double,_ charWidth:Double=3,_ charHeight:Double=6) {
  for (i,c) in value.enumerated() { glyphs.append(PDFGlyph(text:String(c),x:x+Double(i)*charWidth,y:y,width:charWidth,height:charHeight,sourceLine:sourceLine,sourceOrder:glyphs.count)) };sourceLine+=1
 }
 text("令和14年度",20,8,5,8);text("前期",80,8,5,8)
 for y in [40.0,72.0,96.0,148.0,200.0] { rules.append(PDFRule(x1:20,y1:y,x2:720,y2:y)) }
 for x in [20.0,44.0,80.0] { rules.append(PDFRule(x1:x,y1:40,x2:x,y2:200)) }
 for p in 0...40 { let x=80+Double(p)*16; rules.append(PDFRule(x1:x,y1:p%8==0 ? 40:72,x2:x,y2:200)) }
 for (day,label) in ["月曜日","火曜日","水曜日","木曜日","金曜日"].enumerated() {
  text(label,80+Double(day)*128+55,48)
  for p in 1...8 { text(String(p),80+Double(day*8+p-1)*16+6,78,4,8) }
 }
 for row in 0..<2 {
  let top=96+Double(row)*52
  text(String(row+1),28,top+22,4,8);text(row==0 ? "2":"CN",58,top+22,4,8)
  for p in 0..<40 { for (line,value) in ["架空科","架空師","架空室"].enumerated() { text(value,80+Double(p)*16+3,top+6+Double(line)*16,3,6) } }
 }
 var gray=[UInt8](repeating:255,count:width*height)
 for r in rules {
  if r.horizontal { for x in Int(r.x1)...min(width-1,Int(r.x2)) { gray[Int(r.y1)*width+x]=0 } }
  else { for y in Int(r.y1)...Int(r.y2) { gray[y*width+Int(r.x1)]=0 } }
 }
 for g in glyphs { gray[Int(g.cy)*width+Int(g.cx)]=0 }
 if annotation {
  text("架空注記",24,240,4,8)
  for g in glyphs where g.y >= 240 { gray[Int(g.cy)*width+Int(g.cx)]=0 }
 }
 if unknownAnnotation { gray[260*width+24]=0 }
 let raster=try RecoveryRasterGrid(width:width,height:height,grayscale:gray).preparingRules(rules)
 return (PDFPageLayout(width:Double(width),height:Double(height),glyphs:glyphs,lines:rules),raster)

    }
    func testOCRRecoveryRejectsAnEntireUnobservedClassRow() throws {
        let (original,raster)=try twoClassRasterCoverage()
        var omitted=original; omitted.glyphs.removeAll { $0.cy >= 148 }
        XCTAssertTrue(try raster.hasUncoveredInk(RecoveryBox(x:0,y:0,width:original.width,height:original.height),text:omitted.glyphs.map { RecoveryBox(x:$0.x,y:$0.y,width:$0.width,height:$0.height) },rules:original.lines,check:{}))
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([omitted],kind:.timetable,hash:String(repeating:"b",count:64),fromOCR:[1],rasters:[1:raster])) {
            XCTAssertEqual(($0 as? PDFParseError)?.code,.ambiguous)
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.rasterInput)
        }
    }
    func testOCRRecoveryAccountsForBothClassRowsRulesAndKnownAnnotation() async throws {
        for annotation in [false,true] {
            let (page,raster)=try twoClassRasterCoverage(annotation:annotation)
            let doc=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64),fromOCR:[1],rasters:[1:raster])
            XCTAssertEqual(doc.classes,["1_2","2_CN"]); XCTAssertEqual(doc.requiredSlots.count,80)
            XCTAssertEqual(doc.annotations.count,annotation ? 1:0)
            let proof=try XCTUnwrap(doc.ocrCoverageProof)
            XCTAssertEqual(proof.version,1); XCTAssertEqual(proof.pages.count,1)
            XCTAssertEqual(proof.pages[0].page,1); XCTAssertEqual(proof.pages[0].width,740); XCTAssertEqual(proof.pages[0].height,480)
            XCTAssertEqual(proof.pages[0].grayscaleSHA256,SHA256.hash(data:Data(raster.grayscale)).map { String(format:"%02x",$0) }.joined())
            let run=try await RecoveryEngine.run(doc,os:"ios",osMajor:27,foreground:true,providers:[],rule:{_ in nil},check:{})
            let result=try XCTUnwrap(run.result); XCTAssertTrue(RecoveryValidator.validate(doc,result).canAdopt)
            XCTAssertEqual(result.cells.flatMap(\.lessons).count,80)
            for lesson in result.cells.flatMap(\.lessons) {
                XCTAssertEqual(lesson.subject.value,"架空科"); XCTAssertEqual(lesson.teacher.value,"架空師"); XCTAssertEqual(lesson.room.value,"架空室")
            }
        }
    }
    func testOCRRecoveryRejectsUnobservedAnnotationInkOutsideRecognizedCells() throws {
        let (page,raster)=try twoClassRasterCoverage(unknownAnnotation:true)
        XCTAssertThrowsError(try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64),fromOCR:[1],rasters:[1:raster])) {
            XCTAssertEqual(($0 as? PDFParseError)?.stage,.rasterInput)
        }
    }
    func testVectorRecoveryDoesNotTreatUnrequestedRasterAsOCRProof() throws {
        let (page,raster)=try twoClassRasterCoverage(unknownAnnotation:true)
        let doc=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:String(repeating:"b",count:64),rasters:[1:raster])
        XCTAssertEqual(doc.requiredSlots.count,80); XCTAssertFalse(doc.sources.contains { $0.fromOcr }); XCTAssertNil(doc.ocrCoverageProof)
    }
}
