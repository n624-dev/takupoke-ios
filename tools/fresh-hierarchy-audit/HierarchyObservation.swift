import Foundation
import Vision

/// Output accounting only. Nothing here selects a recognition candidate or constructs a recovery source.
final class HierarchyCaptureBudget {
    private(set) var counts: [String:Int] = [:]
    private(set) var omissions = [[String:Any]]()
    private(set) var omissionCount = 0
    private(set) var estimatedBytes = 0
    private(set) var outputExhausted = false
    let limits = ["containers":1024,"textRegions":4096,"lines":8192,"candidates":49152,"characters":20000,"cells":8192,"rows":2048,"columnMetadata":2048,"points":4096,"textUTF8Bytes":1048576]
    func omit(_ path:String,_ reason:String,available:Int,captured:Int = 0) {
        omissionCount += 1
        if omissions.count < 2048 { omissions.append(["path":path,"reason":reason,"available":available,"captured":captured]) }
    }
    func take(_ kind:String,_ amount:Int = 1,path:String,estimatedBytes:Int = 0) -> Bool {
        let used=counts[kind,default:0],limit=limits[kind]!
        guard amount >= 0,amount <= limit-used,estimatedBytes >= 0,estimatedBytes <= 4194304-self.estimatedBytes else {
            if estimatedBytes > 4194304-self.estimatedBytes { outputExhausted = true }
            omit(path,"\(kind) or estimated output byte cap",available:amount);return false
        }
        counts[kind]=used+amount;self.estimatedBytes += estimatedBytes;return true
    }
}

@available(iOS 26.0, *)
enum HierarchyObservation {
    static let topCandidateLimit = 5
    static func capture(_ observations:[DocumentObservation],width:Int,height:Int) -> [String:Any] {
        let budget=HierarchyCaptureBudget()
        func pointValues(_ region:NormalizedRegion,path:String) -> [String:Any] {
            let points=region.normalizedPoints
            var kept=[[String:Any]]()
            for (index,p) in points.enumerated() {
                guard budget.take("points",path:"\(path).points[\(index)]",estimatedBytes:96) else { break }
                let x=Double(p.x),y=Double(p.y)
                kept.append(["x":x.isFinite ? x as Any : NSNull(),"y":y.isFinite ? y as Any : NSNull()])
            }
            return ["normalizedLowerLeftPolygon":kept,"nativePointCount":points.count,"capturedPointCount":kept.count,"boundingBox":FreshHierarchyProbe.rect(region.boundingBox.cgRect,width:width,height:height)]
        }
        func candidate(_ value:RecognizedText,path:String) -> [String:Any]? {
            guard budget.take("candidates",path:path,estimatedBytes:512+path.utf8.count) else { return nil }
            let text=value.string,confidence=Double(value.confidence)
            guard budget.take("textUTF8Bytes",text.utf8.count,path:path+".string",estimatedBytes:text.utf8.count*6) else {
                return ["path":path,"captureComplete":false,"nativeStringUTF8Bytes":text.utf8.count,"reason":"string byte cap"]
            }
            var boxes=[[String:Any]]()
            for start in text.indices {
                let end=text.index(after:start)
                guard budget.take("characters",path:"\(path).characters[\(boxes.count)]",estimatedBytes:640) else { break }
                var entry:[String:Any]=["text":String(text[start..<end]),"nativeCharacterIndex":boxes.count]
                if let rectangle=value.boundingBox(for:start..<end) {
                    let b=rectangle.boundingBox.cgRect
                    entry.merge(FreshHierarchyProbe.rect(b,width:width,height:height)) { _,new in new }
                    let x=b.minX*CGFloat(width),y=(1-b.maxY)*CGFloat(height),w=b.width*CGFloat(width),h=b.height*CGFloat(height)
                    entry["originalLayoutsCharacterPredicate"]=w>0 && h>0 && x>=0 && y>=0
                } else { entry["missingBoundingBox"]=true }
                boxes.append(entry)
            }
            return ["path":path,"rawText":text,"confidence":confidence.isFinite ? confidence as Any : NSNull(),"confidenceScope":"candidate string, not individual character","passesOriginalConfidencePredicate":confidence.isFinite && confidence>=0.85 && confidence<=1,"nativeCharacterCount":text.count,"characters":boxes,"captureComplete":boxes.count==text.count]
        }
        func text(_ value:DocumentObservation.Container.Text,path:String) -> [String:Any] {
            guard budget.take("textRegions",path:path,estimatedBytes:512+path.utf8.count) else { return ["path":path,"captureComplete":false] }
            let transcript=value.transcript
            let retainTranscript=budget.take("textUTF8Bytes",transcript.utf8.count,path:path+".transcript",estimatedBytes:transcript.utf8.count*6)
            func recognized(_ values:[RecognizedTextObservation],kind:String) -> [[String:Any]] {
                var kept=[[String:Any]]()
                for (index,line) in values.enumerated() {
                    let linePath="\(path).\(kind)[\(index)]"
                    guard budget.take("lines",path:linePath,estimatedBytes:512+linePath.utf8.count) else { break }
                    let lineTranscript=line.transcript
                    let retainLineTranscript=budget.take("textUTF8Bytes",lineTranscript.utf8.count,path:linePath+".transcript",estimatedBytes:lineTranscript.utf8.count*6)
                    let top1=line.topCandidates(1).first
                    let top5=line.topCandidates(topCandidateLimit)
                    let one=top1.flatMap { candidate($0,path:linePath+".top1") }
                    var alternatives=[[String:Any]]()
                    if top5.count > topCandidateLimit { budget.omit(linePath+".top5","unexpected accessor count above requested topN",available:top5.count,captured:topCandidateLimit) }
                    for (rank,item) in top5.prefix(topCandidateLimit).enumerated() {
                        guard let retained=candidate(item,path:"\(linePath).top5[\(rank)]") else { break }
                        alternatives.append(retained)
                    }
                    let agreement:Any
                    if let a=top1,let b=top5.first { agreement=a.string==b.string && a.confidence==b.confidence }
                    else { agreement=top1==nil && top5.isEmpty }
                    kept.append(["path":linePath,"nativeOrder":index,"transcript":retainLineTranscript ? lineTranscript as Any : NSNull(),"transcriptUTF8Bytes":lineTranscript.utf8.count,"boundingRegion":pointValues(line.boundingRegion,path:linePath+".boundingRegion"),"top1":one.map { $0 as Any } ?? NSNull(),"requestedTopN":topCandidateLimit,"returnedTopN":top5.count,"capturedTopN":alternatives.count,"top5":alternatives,"top1VsTop5FirstTextConfidenceAgreement":agreement,"alternativeAdopted":false])
                }
                return kept
            }
            let lines=recognized(value.lines,kind:"lines")
            let nativeWords=value.words
            let words=nativeWords.map { recognized($0,kind:"words") }
            return ["path":path,"transcript":retainTranscript ? transcript as Any : NSNull(),"transcriptUTF8Bytes":transcript.utf8.count,"boundingRegion":pointValues(value.boundingRegion,path:path+".boundingRegion"),"nativeLineCount":value.lines.count,"capturedLineCount":lines.count,"lines":lines,"wordsAccessorState":nativeWords == nil ? "nil" : "present","nativeWordCount":nativeWords.map { $0.count as Any } ?? NSNull(),"capturedWordCount":words.map { $0.count as Any } ?? NSNull(),"words":words.map { $0 as Any } ?? NSNull(),"wordsLanguageLimitation":"Apple: Chinese, Japanese, Korean, and Thai do not recognize individual words"]
        }

        func container(_ value:DocumentObservation.Container,path:String,depth:Int) -> [String:Any] {
            guard depth <= 8 else { budget.omit(path,"depth cap",available:depth);return ["path":path,"captureComplete":false] }
            guard budget.take("containers",path:path,estimatedBytes:1024+path.utf8.count) else { return ["path":path,"captureComplete":false] }
            var paragraphs=[[String:Any]](),tables=[[String:Any]](),lists=[[String:Any]]()
            if !value.barcodes.isEmpty { budget.omit(path+".barcodes","unsupported barcode content; no inferred text",available:value.barcodes.count) }
            let globalText=text(value.text,path:path+".text")
            let title=value.title.map { text($0,path:path+".title") }
            for (i,paragraph) in value.paragraphs.enumerated() {
                if budget.outputExhausted || budget.counts["textRegions",default:0] >= budget.limits["textRegions"]! { budget.omit(path+".paragraphs","text region cap",available:value.paragraphs.count,captured:paragraphs.count);break }
                paragraphs.append(text(paragraph,path:"\(path).paragraphs[\(i)]"))
            }
            for (tableIndex,table) in value.tables.enumerated() {
                let tablePath="\(path).tables[\(tableIndex)]"
                guard budget.take("containers",path:tablePath,estimatedBytes:1024+tablePath.utf8.count) else { break }
                func entries(_ native:[[DocumentObservation.Container.Table.Cell]],axis:String) -> [[[String:Any]]] {
                    var result=[[[String:Any]]]()
                    for (index,row) in native.enumerated() {
                        guard budget.take("rows",path:"\(tablePath).\(axis)[\(index)]",estimatedBytes:64) else { break }
                        var kept=[[String:Any]]()
                        for (entryIndex,cell) in row.enumerated() {
                            let cellPath="\(tablePath).\(axis)[\(index)][\(entryIndex)]"
                            guard budget.take("cells",path:cellPath,estimatedBytes:512+cellPath.utf8.count) else { break }
                            kept.append(["path":cellPath,"nativeOrder":entryIndex,"rowRange":[cell.rowRange.lowerBound,cell.rowRange.upperBound],"columnRange":[cell.columnRange.lowerBound,cell.columnRange.upperBound],"content":container(cell.content,path:cellPath+".content",depth:depth+1)])
                        }
                        result.append(kept)
                        if kept.count < row.count { budget.omit(tablePath+"."+axis,"cell cap",available:row.count,captured:kept.count);break }
                    }
                    return result
                }
                let rows=entries(table.rows,axis:"rows"),columns=entries(table.columns,axis:"columns")
                tables.append(["path":tablePath,"boundingRegion":pointValues(table.boundingRegion,path:tablePath+".boundingRegion"),"nativeRowCount":table.rows.count,"nativeColumnCount":table.columns.count,"rows":rows,"columns":columns,"nativeArrayOrderPreserved":true,"mergedCellsExpanded":false,"deduplicated":false])
            }

            for (listIndex,list) in value.lists.enumerated() {
                let listPath="\(path).lists[\(listIndex)]"
                guard budget.take("containers",path:listPath,estimatedBytes:512+listPath.utf8.count) else { break }
                var items=[[String:Any]]()
                for (itemIndex,item) in list.items.enumerated() {
                    if budget.outputExhausted || budget.counts["containers",default:0] >= budget.limits["containers"]! { budget.omit(listPath+".items","container cap",available:list.items.count,captured:items.count);break }
                    items.append(container(item.content,path:"\(listPath).items[\(itemIndex)].content",depth:depth+1))
                }
                lists.append(["path":listPath,"boundingRegion":pointValues(list.boundingRegion,path:listPath+".boundingRegion"),"nativeItemCount":list.items.count,"items":items])
            }
            return ["path":path,"depth":depth,"text":globalText,"title":title.map { $0 as Any } ?? NSNull(),"unsupportedBarcodeCount":value.barcodes.count,"nativeParagraphCount":value.paragraphs.count,"paragraphs":paragraphs,"nativeTableCount":value.tables.count,"tables":tables,"nativeListCount":value.lists.count,"lists":lists]
        }
        var roots=[[String:Any]]()
        for (index,observation) in observations.enumerated() {
            if budget.outputExhausted || budget.counts["containers",default:0] >= budget.limits["containers"]! { budget.omit("observations","container or estimated output cap",available:observations.count,captured:roots.count);break }
            roots.append(container(observation.document,path:"observations[\(index)].document",depth:0))
        }
        return ["roots":roots,"scope":"selected text hierarchy accessors, not all Vision content or latent candidates; repeated native representations retained; no candidate adopted","coveredAccessorInventory":["Container.text/title/paragraphs/tables.rows+columns.cell.content/lists.items.content", "Text.transcript/lines/optional words", "line.transcript/boundingRegion/topCandidates(1)/topCandidates(5)", "candidate.string/confidence/character.boundingBox"],"uncapturedContentKinds":["barcode payloads", "DataDetectorMatch metadata"],"captureCompleteDefinition":"no omission within listed text-accessor traversal; not proof of complete latent recognition or all original ink","requestedTopN":topCandidateLimit,"limits":budget.limits,"maximumDepth":8,"estimatedOutputByteCap":4194304,"byteCapScope":"conservative accounting estimate, not serialized JSON size","estimatedBytes":budget.estimatedBytes,"counts":budget.counts,"captureComplete":budget.omissionCount==0,"omissionCount":budget.omissionCount,"omissions":budget.omissions,"omissionRecordsTruncated":budget.omissionCount>budget.omissions.count,"fullFormalAssessment":"unassessed"]
    }
}
