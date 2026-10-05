// Appended only to the generated QA app. Entirely fictional source controls;
// native recognition and user-device OCR quality are deliberately unmeasured.
@MainActor
enum SimulatorManualFixture {
    static let processIdentity = UUID().uuidString
    private static var eventCount = 0
    static func event(_ kind:String,id:String,old:String,new:String) {
        guard enabled else { return }
        eventCount += 1
        guard eventCount <= 64 else {
            if eventCount == 65 {
                let previous=UserDefaults.standard.string(forKey:"fixture.manualEvents") ?? ""
                UserDefaults.standard.set(previous+"limited=64\n",forKey:"fixture.manualEvents")
                print("TAKUPOKE-MANUAL-EVENT limited=64")
            }
            return
        }
        func digest(_ text:String) -> String { SHA256.hash(data:Data(text.utf8)).map { String(format:"%02x",$0) }.joined() }
        let record="count=\(eventCount);kind=\(kind);id=\(id);oldBytes=\(old.utf8.count);newBytes=\(new.utf8.count);oldSHA=\(digest(old));newSHA=\(digest(new));equalBytes=\(old.utf8.elementsEqual(new.utf8))"
        let previous=UserDefaults.standard.string(forKey:"fixture.manualEvents") ?? ""
        UserDefaults.standard.set(previous+record+"\n",forKey:"fixture.manualEvents")
        print("TAKUPOKE-MANUAL-EVENT "+record)
    }
    static var enabled:Bool { ProcessInfo.processInfo.arguments.contains("--manual-ui") }
    static var count:Int {
        let args=ProcessInfo.processInfo.arguments
        return args.contains("--manual-four") ? 4 : args.contains("--manual-three") ? 3 : 1
    }
    struct Prepared { let source:RecoverySelectedSource; let draft:RecoveryManualDraft; let raster:RecoveryRasterGrid }
    static func trace(_ message:String) {
        UserDefaults.standard.set(message,forKey:"fixture.manualStage")
        print("TAKUPOKE-MANUAL-QA "+message)
    }
    static func failed(_ error:Error) {
        let stage=UserDefaults.standard.string(forKey:"fixture.manualStage") ?? "unknown"
        trace(stage+";error="+String(reflecting:error))
    }

    static var integralRails:Bool { ProcessInfo.processInfo.arguments.contains("--manual-integral-rails") }
    static func inkDiagnostic(_ page:PDFPageLayout,_ raster:RecoveryRasterGrid) -> String {
        let text=page.glyphs.map { RecoveryBox(x:$0.x,y:$0.y,width:$0.width,height:$0.height) }
        let hash=SHA256.hash(data:Data(raster.grayscale)).map { String(format:"%02x",$0) }.joined()
        let deadline=ProcessInfo.processInfo.systemUptime+8
        var checks=0
        func check() throws {
            checks+=1
            guard checks<=250000,ProcessInfo.processInfo.systemUptime<=deadline else { throw PDFParseError(code:.limit) }
            try Task.checkCancellation()
        }
        func uncovered(_ x:Int,_ y:Int,_ w:Int,_ h:Int) throws -> Bool {
            try check()
            return try raster.hasUncoveredInk(RecoveryBox(x:Double(x),y:Double(y),width:Double(w),height:Double(h)),text:text,rules:page.lines,check:check)
        }
        do {
            guard try uncovered(0,0,raster.width,raster.height) else { return "covered;graySHA="+hash }
            var x=0,y=0,w=raster.width,h=raster.height
            // Integer pixel partitions preserve the original predicate/mask.
            // Find the first occupied uncovered row, then the first column.
            while h>1 { let half=h/2
                if try uncovered(x,y,w,half) { h=half } else { y+=half;h-=half }
            }
            while w>1 { let half=w/2
                if try uncovered(x,y,half,h) { w=half } else { x+=half;w-=half }
            }
            guard try uncovered(x,y,1,1) else { return "unassessed:partition;graySHA="+hash }
            let px=Double(x)+0.5,py=Double(y)+0.5
            let distance=page.lines.map { rule -> Double in
                let dx=rule.x2-rule.x1,dy=rule.y2-rule.y1, length=dx*dx+dy*dy
                let t=length>0 ? max(0,min(1,((px-rule.x1)*dx+(py-rule.y1)*dy)/length)):0
                return hypot(px-(rule.x1+t*dx),py-(rule.y1+t*dy))
            }.min() ?? -1
            return "firstUncovered=\(x),\(y);gray=\(raster.grayscale[y*raster.width+x]);ruleDistance=\(distance);graySHA="+hash
        } catch { return "unassessed:"+String(reflecting:error)+";graySHA="+hash }
    }
    static func input(integralRails:Bool? = nil) throws -> (PDFPageLayout,RecoveryRasterGrid,UIImage,Set<Int>) {
        let drawIntegral=integralRails ?? SimulatorManualFixture.integralRails
        let scale=2.0,width=1480,height=960
        var glyphs=[PDFGlyph](),rules=[PDFRule](),line=0,uncertain=Set<Int>()
        func text(_ value:String,_ x:Double,_ y:Double,_ w:Double=3,_ h:Double=6,low:Bool=false) {
            if low { uncertain.insert(line) }
            for (i,c) in value.enumerated() { glyphs.append(PDFGlyph(text:String(c),x:(x+Double(i)*w)*scale,y:y*scale,width:w*scale,height:h*scale,sourceLine:line,sourceOrder:glyphs.count)) };line+=1
        }
        let period=SchoolDataPeriod.current()
        text("令和\(period.schoolYear-2018)年度",20,8,5,8);text(period.half==1 ? "前期":"後期",80,8,5,8)
        for y in [40.0,72,96,148,200] { rules.append(PDFRule(x1:20*scale,y1:y*scale,x2:720*scale,y2:y*scale)) }
        for x in [20.0,44,80] { rules.append(PDFRule(x1:x*scale,y1:40*scale,x2:x*scale,y2:200*scale)) }
        for p in 0...40 { let x=(80+Double(p)*16)*scale;rules.append(PDFRule(x1:x,y1:(p%8==0 ? 40:72)*scale,x2:x,y2:200*scale)) }
        for (day,label) in ["月曜日","火曜日","水曜日","木曜日","金曜日"].enumerated() {
            text(label,80+Double(day)*128+55,48)
            for p in 1...8 { text(String(p),80+Double(day*8+p-1)*16+6,85,4,8) }
        }
        for row in 0..<2 {
            let top=96+Double(row)*52
            text(String(row+1),28,top+22,4,8);text(row==0 ? "2":"CN",58,top+22,4,8)
            for p in 0..<40 { for (role,value) in ["架空科","架空師","架空室"].enumerated() {
                let ordinal=row*120+p*3+role
                text(value,80+Double(p)*16+3,top+6+Double(role)*16,low:ordinal<count)
            } }
        }
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:CGSize(width:width,height:height),format:format).image { context in
            UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:width,height:height));UIColor.black.setStroke()
            if drawIntegral {
                // One physical pixel row/column, including both endpoints.
                UIColor.black.setFill()
                for r in rules {
                    if r.horizontal { context.fill(CGRect(x:min(r.x1,r.x2),y:r.y1,width:abs(r.x2-r.x1)+1,height:1)) }
                    else { context.fill(CGRect(x:r.x1,y:min(r.y1,r.y2),width:1,height:abs(r.y2-r.y1)+1)) }
                }
            } else {
                // Retained original renderer for the measured A/B control.
                for r in rules { let path=UIBezierPath();path.move(to:CGPoint(x:r.x1,y:r.y1));path.addLine(to:CGPoint(x:r.x2,y:r.y2));path.lineWidth=1;path.stroke() }
            }
            for g in glyphs { (g.text as NSString).draw(at:CGPoint(x:g.x+0.5,y:g.y+1),withAttributes:[.font:UIFont.systemFont(ofSize:8*scale/3),.foregroundColor:UIColor.black]) }
        }
        guard let cg=image.cgImage else { throw PDFParseError(code:.unreadable) }
        var rgba=[UInt8](repeating:0,count:width*height*4)
        let rendered=rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let context=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg,in:CGRect(x:0,y:0,width:width,height:height));return true
        }
        guard rendered else { throw PDFParseError(code:.unreadable) }
        let raster=try RecoveryRasterGrid.fromRGBA(width:width,height:height,pixels:rgba).preparingRules(rules)
        var minX=width,minY=height,maxX = -1,maxY = -1
        for y in 0..<height { for x in 0..<width where raster.grayscale[y*width+x] < 200 {
            minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)
        } }
        // Actual bitmap row coordinates only: this does not certify ownership.
        UserDefaults.standard.set("inkBounds=\(minX),\(minY),\(maxX),\(maxY);page=\(width)x\(height)",forKey:"fixture.manualPixels")
        return (PDFPageLayout(width:Double(width),height:Double(height),glyphs:glyphs,lines:rules),raster,image,uncertain)
    }
    static func seed(_ base:URL) throws {
        eventCount=0;UserDefaults.standard.removeObject(forKey:"fixture.manualEvents")
        // Never overwrite an already adopted result on relaunch.
        if !ProcessInfo.processInfo.arguments.contains("--reset-fixture") { return }
        let (page,raster,image,_)=try input()
        // Run the two bounded measurements before fixture-ready, not while
        // the UI waits its unchanged 15 seconds for editable fields.
        if integralRails {
            let (oldPage,oldRaster,_,_)=try input(integralRails:false)
            UserDefaults.standard.set(inkDiagnostic(oldPage,oldRaster),forKey:"fixture.manualOldInk")
        }
        UserDefaults.standard.set(inkDiagnostic(page,raster),forKey:"fixture.manualCandidateInk")
        let raw=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:1480,height:960)).pdfData { context in
            context.beginPage();image.draw(in:CGRect(x:0,y:0,width:1480,height:960))
        }
        let library=try LocalMaterialDatabase.openLibrary(root:base.appendingPathComponent("SchoolMaterialsSQLite"))
        if ProcessInfo.processInfo.arguments.contains("--manual-comparable-prior") {
            guard let old=library.state.pdfAnalyses?[MaterialKind.timetable.rawValue] else { throw PDFParseError(code:.storage) }
            let scope=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:old.sourceDigest,fromOCR:[1],rasters:[1:raster])
            // An explicit dense prior is a UI comparison control, not an OCR result.
            // Every stored slot is represented; only the subsequently edited cell changes.
            let lessons=scope.requiredSlots.map { slot in
                PDFLesson(className:slot.className,weekday:Int(slot.day)!,period:slot.period,names:.init(subject:"架空科",teacher:"架空師",room:"架空室"),sourceText:"",page:1)
            }
            try library.savePDFAnalysis(PDFAnalysis(kind:.timetable,sourceDigest:old.sourceDigest,sourceName:old.sourceName,parsedAt:old.parsedAt,schoolYear:SchoolDataPeriod.current().schoolYear,term:SchoolDataPeriod.current().half == 1 ? "前期" : "後期",lessons:lessons,events:[],notices:[]))
        }
        let staged=library.newStagingURL();try raw.write(to:staged)
        let hash=SHA256.hash(data:raw).map{String(format:"%02x",$0)}.joined()
        try library.commit(staged:staged,kind:.timetable,source:.init(grant:nil,childName:nil),originalName:"fictional-manual-source.pdf",byteCount:raw.count,digest:hash,modifiedAt:nil)
        try library.recordPDFFailure(PDFParseError(code:.ambiguous),kind:.timetable)
        guard let prior=library.state.pdfAnalyses?[MaterialKind.timetable.rawValue] else { throw PDFParseError(code:.storage) }
        UserDefaults.standard.set(try RecoveryValidator.fingerprint(prior),forKey:"fixture.manualPriorAnalysisHash")
        UserDefaults.standard.set(false,forKey:"fixture.manualMutationComplete")
    }
    static func changeOriginal() async throws {
        guard let source=await ApplicationData.shared.materials.recoverySource() else { throw PDFParseError(code:.storage) }
        var bytes=try Data(contentsOf:source.url);bytes.append(Data("\n% Fictional current-hash change\n".utf8))
        try bytes.write(to:source.url,options:.atomic)
    }
    static func prepare() async throws -> Prepared {
        trace("stage=source")
        guard let source=await ApplicationData.shared.materials.recoverySource() else { throw PDFParseError(code:.storage) }
        trace("stage=raster")
        let (page,raster,_,low)=try input()
        trace("stage=builder;width=\(raster.width);height=\(raster.height)")
        let original=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:source.digest,fromOCR:[1],rasters:[1:raster])
        trace("stage=builder-returned;cells=\(original.cells.count)")
        let groups=Dictionary(grouping:page.glyphs,by:{$0.sourceLine!})
        let lines=groups.keys.sorted().map { key -> RecoveryOCRLine in
            let glyphs=groups[key]!.sorted{$0.sourceOrder!<$1.sourceOrder!}
            return RecoveryOCRLine(nativeOrder:key,candidates:[RecoveryOCRCandidate(text:glyphs.map(\.text).joined(),confidence:low.contains(key) ? 0.4:0.95,characters:glyphs.map{RecoveryOCRCharacter(text:$0.text,range:RecoveryOCRRange(x:$0.x,y:$0.y,width:$0.width,height:$0.height))})])
        }
        let capture=RecoveryOCRAcquisitionDraft(sourcePDFHash:source.digest,documentPageCount:1,requiredOCRPages:[1],pages:[RecoveryOCRPage(page:1,width:raster.width,height:raster.height,nativeDocumentCount:1,lines:lines,captureComplete:true)])
        trace("stage=attach")
        let document=try RecoveryManualAssistance.attaching(capture,to:original)
        trace("stage=prepare")
        guard let draft=try RecoveryManualAssistance.prepare(document,os:"ios") else { throw PDFParseError(code:.ambiguous) }
        trace("stage=prepared;fields=\(draft.fields.count)")
        return Prepared(source:source,draft:draft,raster:raster)
    }
}
struct FixtureManualProbe:View {
    @ObservedObject private var materials=ApplicationData.shared.materials
    @AppStorage("fixture.manualStage") private var manualStage="not-started"
    @AppStorage("fixture.manualPixels") private var manualPixels="unmeasured"
    @AppStorage("fixture.manualOldInk") private var oldInk="unmeasured"
    @AppStorage("fixture.manualCandidateInk") private var candidateInk="unmeasured"
    @AppStorage("fixture.manualEvents") private var events=""
    var body:some View {
        let analysis=materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue]
        let adopted=analysis?.recovery
        let currentHash=analysis.flatMap{try? RecoveryValidator.fingerprint($0)}
        let priorHash=UserDefaults.standard.string(forKey:"fixture.manualPriorAnalysisHash")
        let lastgood=currentHash != nil && priorHash != nil && currentHash==priorHash
        let corrections=adopted?.result.humanCorrections ?? []
        let valid=adopted.map{(try? RecoveryValidator.canReuse($0.acceptance,document:$0.document,result:$0.result))==true} ?? false
        VStack {
            Text(events).font(.system(size:1)).accessibilityIdentifier("manual-binding-events").allowsHitTesting(false)
            Text(manualStage+";"+manualPixels+";old="+oldInk+";candidate="+candidateInk).font(.caption2)
                .accessibilityIdentifier("manual-qa-diagnostic").allowsHitTesting(false)
            Text(adopted==nil ? (lastgood ? "lastgood-preserved":"lastgood-mismatch"):"adopted=\(corrections.count);valid=\(valid);values="+corrections.map(\.value).joined(separator:"|"))
                .font(.caption2).accessibilityIdentifier("manual-persisted-proof").allowsHitTesting(false)
        }
    }
}
