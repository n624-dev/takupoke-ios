import Foundation

struct NativeRangeOwner {var id:String;var boxes:[RecoveryBox]}
/// Additional research accounting, not precise glyph ownership or a replacement for production proof1.
enum OriginalInkOwnership {
    static func measure(_ raster:RecoveryRasterGrid,owners:[NativeRangeOwner],check:()throws->Void)throws->[String:Any] {
        var nonwhite=0,ruleInk=0,unowned=0,multipleOwners=0,singlyOwned=0,work=0
        func step(_ amount:Int=1)throws {
            guard amount>=0,amount<=32000000-work else {throw PDFParseError(code:.limit)}
            let next=work+amount
            while work<next {work+=1;if work%128==0 {try check()}}
        }
        try check()
        guard owners.count<=10000 else {throw NSError(domain:"InvalidNativeRangeOwner",code:1)}
        var totalBoxes=0,ids=Set<String>()
        for owner in owners {
            try step()
            totalBoxes+=owner.boxes.count
            guard totalBoxes<=100000,owner.id.utf8.count<=256 else {throw NSError(domain:"NativeOwnerInventoryCap",code:1)}
            try step(owner.id.utf8.count)
            guard ids.insert(owner.id).inserted else {throw NSError(domain:"DuplicateNativeOwner",code:1)}
            for box in owner.boxes {
                try step(6)
                guard box.valid,box.x+box.width<=Double(raster.width),box.y+box.height<=Double(raster.height) else {throw NSError(domain:"InvalidNativeRangeOwner",code:1)}
            }
        }
        // Read-only research reflection of the exact pinned raster's already-computed physical rule mask.
        // Missing/changed private metadata is an explicit refusal, never a fabricated mask.
        guard let field=Mirror(reflecting:raster).children.first(where:{$0.label=="preparedRuleMask"}),
              let mask=field.value as? [UInt8],mask.count==raster.width*raster.height else {throw NSError(domain:"ActualRuleMaskUnavailable",code:1)}
        try check()
        var ownership=[UInt16](repeating:0,count:raster.width*raster.height),hasInk=[Bool](repeating:false,count:owners.count)
        for (ownerIndex,owner) in owners.enumerated() {
            let token=UInt16(ownerIndex+1)
            for box in owner.boxes {
                let left=max(0,Int(floor(box.x))),right=min(raster.width,Int(ceil(box.x+box.width)))
                let top=max(0,Int(floor(box.y))),bottom=min(raster.height,Int(ceil(box.y+box.height)))
                for y in top..<bottom {
                    for x in left..<right {
                        try step();let index=y*raster.width+x
                        guard raster.grayscale[index] != 255,mask[index] != 1 else {continue}
                        let px=Double(x)+0.5,py=Double(y)+0.5
                        guard box.x<=px,px<=box.x+box.width,box.y<=py,py<=box.y+box.height else {continue}
                        hasInk[ownerIndex]=true
                        if ownership[index]==0 {ownership[index]=token}
                        else if ownership[index] != token {ownership[index]=UInt16.max}
                    }
                }
            }
        }
        for index in ownership.indices {
            try step();guard raster.grayscale[index] != 255 else {continue};nonwhite+=1
            if mask[index]==1 {ruleInk+=1;continue}
            if ownership[index]==0 {unowned+=1}else if ownership[index]==UInt16.max {multipleOwners+=1}else {singlyOwned+=1}
        }
        var unsupportedOwners=[String]()
        for index in owners.indices {try step();if !hasInk[index] {unsupportedOwners.append(owners[index].id)}}
        return ["nonwhitePixels":nonwhite,"physicalRulePixels":ruleInk,"unownedNonrulePixels":unowned,"multipleCandidateOwnerPixels":multipleOwners,"singleCandidateOwnerPixels":singlyOwned,"work":work,
          "ownersWithoutNonruleInk":unsupportedOwners,"ownershipMapBytes":ownership.count*2,"completeUniqueCandidateRangeOwnership":unowned==0 && multipleOwners==0 && unsupportedOwners.isEmpty,"scope":"Exact original nonrule pixel centers inside actual returned native range boxes; same-candidate Characters share owner. No padding, bbox correction, precise glyph ownership, word-to-character precision claim or production proof replacement.","actualRuleMaskAcquisition":"Read-only reflection of exact pinned preparedRuleMask; missing metadata refuses"]
    }
}
