import Foundation
import Vision

struct RegionTextCapture {var raw:[String:Any];var glyphs:[PDFGlyph];var owners:[NativeRangeOwner];var passesAcquisitionGuards:Bool;var lines:Int}
@available(iOS 26.0,*) enum TextRangeCapture {
    static func capture(_ observations:[RecognizedTextObservation],region:PlannedRegion,width:Int,height:Int,
                        lineBase:Int,orderBase:Int,check:()throws->Void)throws->RegionTextCapture {
        guard observations.count<=1000 else {throw PDFParseError(code:.limit)}
        var lines=[[String:Any]](),glyphs=[PDFGlyph](),owners=[NativeRangeOwner](),allGuards=true,characters=0,utf8Bytes=0
        let affine=RasterAffine(sourceBox:region.box,scale:region.scale,renderedHeight:height)
        func geometry(_ b:CGRect)->(PhysicalBox,PhysicalBox,[String:Any]) {
            let local=PhysicalBox(x:Double(b.minX)*Double(width),y:(1-Double(b.maxY))*Double(height),width:Double(b.width)*Double(width),height:Double(b.height)*Double(height))
            let original=affine.original(local)
            let values=[local.x,local.y,local.width,local.height,original.x,original.y,original.width,original.height]
            guard values.allSatisfy(\.isFinite) else {return(local,original,["finite":false])}
            return(local,original,["finite":true,"normalizedLowerLeft":[Double(b.minX),Double(b.minY),Double(b.width),Double(b.height)],"localPixelTopLeft":[local.x,local.y,local.width,local.height],"originalPixelTopLeft":[original.x,original.y,original.width,original.height],"transformScope":"Inverse of actual direct PDF region render; no resize or bbox correction"])
        }
        func candidate(_ value:RecognizedText,id:String,construct:Bool)throws->[String:Any] {
            let text=value.string,c=Double(value.confidence),confidenceGood=c.isFinite && c>=0.85 && c<=1
            utf8Bytes+=text.utf8.count;guard utf8Bytes<=1048576 else {throw PDFParseError(code:.limit)}
            var entries=[[String:Any]](),boxes=[RecoveryBox](),good=confidenceGood,provenanceGood=true
            for start in text.indices {
                characters+=1;guard characters<=100000 else {throw PDFParseError(code:.limit)}
                if characters%128==0 {try check()}
                let end=text.index(after:start);var entry:[String:Any]=["text":String(text[start..<end]),"nativeCharacterIndex":entries.count,"rangeUnit":"Swift Character"]
                if let range=value.boundingBox(for:start..<end) {
                    let (local,original,metadata)=geometry(range.boundingBox.cgRect);entry.merge(metadata){_,new in new}
                    let localGood=[local.x,local.y,local.width,local.height].allSatisfy(\.isFinite) && local.width>0 && local.height>0 && local.x>=0 && local.y>=0
                    let originalGood=[original.x,original.y,original.width,original.height].allSatisfy(\.isFinite) && original.x>=0 && original.y>=0 && original.width>0 && original.height>0
                    let provenance=RasterAffine.localRangeProvenance(local,width:width,height:height);provenanceGood = provenanceGood && provenance
                    entry["actualRegionRangeProvenancePredicate"]=provenance
                    entry["originalLayoutsLocalRangePredicate"]=localGood;entry["inverseOriginalRangePredicate"]=originalGood;good = good && localGood && originalGood
                    if construct && localGood && originalGood && provenance {
                        glyphs.append(PDFGlyph(text:String(text[start..<end]),x:original.x,y:original.y,width:original.width,height:original.height,sourceLine:lineBase+lines.count,sourceOrder:orderBase+glyphs.count))
                        boxes.append(RecoveryBox(x:original.x,y:original.y,width:original.width,height:original.height))
                    }
                }else {entry["missingBoundingBox"]=true;good=false;provenanceGood=false}
                entries.append(entry)
            }
            if construct {allGuards=allGuards && good && provenanceGood;owners.append(NativeRangeOwner(id:id,boxes:boxes))}
            return ["path":id,"rawText":text,"confidence":c.isFinite ? c as Any:NSNull(),"passesOriginalConfidencePredicate":confidenceGood,"passesOriginalLocalRangeAndInverseGuards":good,"passesActualRegionRangeProvenance":provenanceGood,"characters":entries,"confidenceScope":"Whole native accurate candidate; not per-character and not calibrated as Document confidence","rangePrecision":"Native returned ranges; accurate word precision not relabelled precise glyph ink"]
        }
        for (index,observation) in observations.enumerated() {
            try check();let id=region.id+".native[\(index)]",top1=observation.topCandidates(1).first,top5=observation.topCandidates(5)
            var raw:[String:Any]=["nativeOrder":index,"sourceLine":lineBase+index,"path":id,"observationBox":geometry(observation.boundingBox.cgRect).2,"returnedTop5Count":top5.count,"alternativesAdopted":false]
            if let top1 {raw["top1"]=try candidate(top1,id:id+".top1",construct:true)}else {raw["top1"]=["missingCandidate":true];allGuards=false}
            raw["top5"]=try top5.prefix(5).enumerated().map{try candidate($0.element,id:id+".top5[\($0.offset)]",construct:false)}
            lines.append(raw)
        }
        return RegionTextCapture(raw:["regionId":region.id,"nativeLineCount":observations.count,"lines":lines,"captureComplete":true,"omissions":[],"capturedCandidateCharacters":characters],glyphs:glyphs,owners:owners,passesAcquisitionGuards:allGuards,lines:observations.count)
    }
}
