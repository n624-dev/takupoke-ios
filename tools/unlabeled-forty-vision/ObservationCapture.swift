import Foundation
import Vision

@available(iOS 26.0,*) enum ObservationCapture {
    static func capture(_ observations:[DocumentObservation],width:Int,height:Int) -> [String:Any] {
        var regions=[[String:Any]](),lineNumber=0,characters=0,bytes=0,omissions=[[String:Any]](),lines=0
        func candidate(_ value:RecognizedText,path:String) -> [String:Any] {
            let text=value.string,c=Double(value.confidence)
            bytes+=text.utf8.count
            guard bytes<=1048576 else { omissions.append(["path":path,"reason":"shared UTF8 string cap"]);return ["path":path,"captureComplete":false] }
            var boxes=[[String:Any]]()
            for start in text.indices {
                characters+=1
                guard characters<=20000 else { omissions.append(["path":path,"reason":"shared20000 character cap"]);break }
                let end=text.index(after:start)
                var entry:[String:Any]=["text":String(text[start..<end]),"nativeCharacterIndex":boxes.count]
                if let rectangle=value.boundingBox(for:start..<end) {
                    let b=rectangle.boundingBox.cgRect
                    entry.merge(UnlabeledFortyProbe.rect(b,width:width,height:height)) { _,new in new }
                    entry["originalCharacterPredicate"]=b.width*CGFloat(width)>0 && b.height*CGFloat(height)>0 && b.minX*CGFloat(width)>=0 && (1-b.maxY)*CGFloat(height)>=0
                } else { entry["missingBoundingBox"]=true }
                boxes.append(entry)
            }
            return ["path":path,"rawText":text,"confidence":c.isFinite ? c as Any:NSNull(),"confidenceScope":"whole native candidate, not individual character","passesOriginalConfidencePredicate":c.isFinite && c>=0.85 && c<=1,"characters":boxes,"nativeCharacterCount":text.count,"captureComplete":boxes.count==text.count]
        }
        for (o,observation) in observations.enumerated() {
            let document=observation.document,text=document.text
            bytes+=text.transcript.utf8.count
            guard bytes<=1048576 else { omissions.append(["path":"observations[\(o)]","reason":"transcript UTF8 cap"]);break }
            var kept=[[String:Any]]()
            for (i,line) in text.lines.enumerated() {
                lines+=1
                guard lines<=2000 else { omissions.append(["path":"observations[\(o)].lines","reason":"shared2000 line cap"]);break }
                let path="observations[\(o)].document.text.lines[\(i)]"
                let top1=line.topCandidates(1).first,top5=line.topCandidates(5)
                kept.append(["path":path,"nativeOrder":i,"sourceLine":lineNumber,"boundingBox":UnlabeledFortyProbe.rect(line.boundingRegion.boundingBox.cgRect,width:width,height:height),
                  "top1":top1.map { candidate($0,path:path+".top1") } ?? ["missingCandidate":true],
                  "top5":top5.prefix(5).enumerated().map { rank,value in candidate(value,path:"\(path).top5[\(rank)]") },"returnedTop5Count":top5.count,"alternativesAdopted":false])
                lineNumber+=1
            }
            regions.append(["nativeObservationOrder":o,"transcript":text.transcript,"nativeLineCount":text.lines.count,"lines":kept,"nativeTableCount":document.tables.count,"nativeParagraphCount":document.paragraphs.count,"nativeListCount":document.lists.count])
        }
        return ["observations":regions,"nativeObservationCount":observations.count,"captureComplete":omissions.isEmpty,"omissions":Array(omissions.prefix(2048)),"omissionCount":omissions.count,"capturedLineCount":lineNumber,"capturedCandidateCharacterCount":characters,
         "scope":"All captured global lines/top1/orderedtop5/character-range boxes; no nested extraction rerun or candidate adoption","limits":["globalLines":2000,"candidateCharacters":20000,"stringUTF8Bytes":1048576],"glyphPrecision":"Native returned ranges, not exact glyph ink or unique ownership"]
    }
}
