// Appended only to the generated QA app. Entirely fictional source controls;
// native recognition and user-device OCR quality are deliberately unmeasured.
@MainActor
enum SimulatorManualFixture {
    static var enabled:Bool { ProcessInfo.processInfo.arguments.contains("--manual-ui") }
    static var count:Int {
        let args=ProcessInfo.processInfo.arguments
        return args.contains("--manual-four") ? 4 : args.contains("--manual-three") ? 3 : 1
    }
    struct Prepared { let source:RecoverySelectedSource; let draft:RecoveryManualDraft; let raster:RecoveryRasterGrid }
    static func input() throws -> (PDFPageLayout,RecoveryRasterGrid,UIImage,Set<Int>) {
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
            for r in rules { let path=UIBezierPath();path.move(to:CGPoint(x:r.x1,y:r.y1));path.addLine(to:CGPoint(x:r.x2,y:r.y2));path.lineWidth=1;path.stroke() }
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
        return (PDFPageLayout(width:Double(width),height:Double(height),glyphs:glyphs,lines:rules),raster,image,uncertain)
    }
    static func seed(_ base:URL) throws {
        // Never overwrite an already adopted result on relaunch.
        if !ProcessInfo.processInfo.arguments.contains("--reset-fixture") { return }
        let (_,_,image,_)=try input()
        let raw=UIGraphicsPDFRenderer(bounds:CGRect(x:0,y:0,width:1480,height:960)).pdfData { context in
            context.beginPage();image.draw(in:CGRect(x:0,y:0,width:1480,height:960))
        }
        let library=try LocalMaterialDatabase.openLibrary(root:base.appendingPathComponent("SchoolMaterialsSQLite"))
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
        print("TAKUPOKE-MANUAL-QA stage=source")
        guard let source=await ApplicationData.shared.materials.recoverySource() else { throw PDFParseError(code:.storage) }
        print("TAKUPOKE-MANUAL-QA stage=raster")
        let (page,raster,_,low)=try input()
        print("TAKUPOKE-MANUAL-QA stage=builder;width=\(raster.width);height=\(raster.height)")
        let original=try RecoveryDocumentBuilder.build([page],kind:.timetable,hash:source.digest,fromOCR:[1],rasters:[1:raster])
        print("TAKUPOKE-MANUAL-QA stage=builder-returned;cells=\(original.cells.count)")
        let groups=Dictionary(grouping:page.glyphs,by:{$0.sourceLine!})
        let lines=groups.keys.sorted().map { key -> RecoveryOCRLine in
            let glyphs=groups[key]!.sorted{$0.sourceOrder!<$1.sourceOrder!}
            return RecoveryOCRLine(nativeOrder:key,candidates:[RecoveryOCRCandidate(text:glyphs.map(\.text).joined(),confidence:low.contains(key) ? 0.4:0.95,characters:glyphs.map{RecoveryOCRCharacter(text:$0.text,range:RecoveryOCRRange(x:$0.x,y:$0.y,width:$0.width,height:$0.height))})])
        }
        let capture=RecoveryOCRAcquisitionDraft(sourcePDFHash:source.digest,documentPageCount:1,requiredOCRPages:[1],pages:[RecoveryOCRPage(page:1,width:raster.width,height:raster.height,nativeDocumentCount:1,lines:lines,captureComplete:true)])
        print("TAKUPOKE-MANUAL-QA stage=attach")
        let document=try RecoveryManualAssistance.attaching(capture,to:original)
        print("TAKUPOKE-MANUAL-QA stage=prepare")
        guard let draft=try RecoveryManualAssistance.prepare(document,os:"ios") else { throw PDFParseError(code:.ambiguous) }
        print("TAKUPOKE-MANUAL-QA stage=prepared;fields=\(draft.fields.count)")
        return Prepared(source:source,draft:draft,raster:raster)
    }
}
struct FixtureManualProbe:View {
    @ObservedObject private var materials=ApplicationData.shared.materials
    var body:some View {
        let analysis=materials.state.pdfAnalyses?[MaterialKind.timetable.rawValue]
        let adopted=analysis?.recovery
        let currentHash=analysis.flatMap{try? RecoveryValidator.fingerprint($0)}
        let priorHash=UserDefaults.standard.string(forKey:"fixture.manualPriorAnalysisHash")
        let lastgood=currentHash != nil && priorHash != nil && currentHash==priorHash
        let corrections=adopted?.result.humanCorrections ?? []
        let valid=adopted.map{(try? RecoveryValidator.canReuse($0.acceptance,document:$0.document,result:$0.result))==true} ?? false
        Text(adopted==nil ? (lastgood ? "lastgood-preserved":"lastgood-mismatch"):"adopted=\(corrections.count);valid=\(valid);values="+corrections.map(\.value).joined(separator:"|"))
            .font(.caption2).accessibilityIdentifier("manual-persisted-proof").allowsHitTesting(false)
    }
}
