import Foundation

struct PhysicalBox:Codable,Equatable {
    var x:Double;var y:Double;var width:Double;var height:Double
    var right:Double{x+width};var bottom:Double{y+height}
}
/// Exact forward PDF render mapping including the ceil-height padding. Raw ranges are never clipped.
struct RasterAffine:Codable {
    var sourceBox:PhysicalBox;var scale:Double;var offsetX:Double;var offsetY:Double
    init(sourceBox:PhysicalBox,scale:Double,renderedHeight:Int) {
        self.sourceBox=sourceBox;self.scale=scale;offsetX=0;offsetY=Double(renderedHeight)-sourceBox.height*scale
    }
    func original(_ local:PhysicalBox)->PhysicalBox {
        PhysicalBox(x:sourceBox.x+(local.x-offsetX)/scale,y:sourceBox.y+(local.y-offsetY)/scale,width:local.width/scale,height:local.height/scale)
    }
    static func localRangeProvenance(_ b:PhysicalBox,width:Int,height:Int)->Bool {
        [b.x,b.y,b.width,b.height,b.right,b.bottom].allSatisfy(\.isFinite) && b.x>=0 && b.y>=0 && b.width>0 && b.height>0 && b.right<=Double(width) && b.bottom<=Double(height)
    }
}
struct MeasuredRail {var x1:Double;var y1:Double;var x2:Double;var y2:Double}
struct PlannedRegion:Codable {var id:String;var box:PhysicalBox;var scale:Double}
enum RegionPlanFailure:Error {case invalidBasis,ambiguousBand,incompleteBottom,invalidMetadata,oversizedRegion}

/// Physical geometry only: no source drawing, literal, role, weekday or period value argument.
enum RegionalPlan {
    static func derive(rails:[MeasuredRail],coarseWidth:Int,coarseHeight:Int,originalWidth:Int,originalHeight:Int,coarseScale:Double,
                       upperInkExtent:(Double)throws->PhysicalBox?,check:()throws->Void)throws->[PlannedRegion] {
        try check()
        guard coarseWidth>0,coarseHeight>0,coarseWidth<=2048,coarseHeight<=2048,
              originalWidth>0,originalHeight>0,originalWidth<=4096,originalHeight<=4096,rails.count<=100000,coarseScale.isFinite,coarseScale>0,coarseScale<=2,
              Int(ceil(Double(originalWidth)*coarseScale))==coarseWidth,Int(ceil(Double(originalHeight)*coarseScale))==coarseHeight else {throw RegionPlanFailure.invalidBasis}
        var work=0
        func consume(_ count:Int=1)throws {
            guard count>=0,count<=1000000-work else {throw RegionPlanFailure.ambiguousBand}
            let next=work+count
            while work<next {work+=1;if work%128==0 {try check()}}
        }
        var horizontal=[MeasuredRail](),vertical=[MeasuredRail](),ySet=Set<Double>(),xSet=Set<Double>()
        for rail in rails {
            try consume(5)
            guard [rail.x1,rail.y1,rail.x2,rail.y2].allSatisfy(\.isFinite),rail.x1>=0,rail.y1>=0,rail.x2<=Double(coarseWidth),rail.y2<=Double(coarseHeight),rail.x1<=rail.x2,rail.y1<=rail.y2 else {throw RegionPlanFailure.invalidBasis}
            if rail.y1==rail.y2 && rail.x2>rail.x1 {horizontal.append(rail);ySet.insert(rail.y1)}
            if rail.x1==rail.x2 && rail.y2>rail.y1 {vertical.append(rail);xSet.insert(rail.x1)}
        }
        guard ySet.count<=1000,xSet.count<=1000 else {throw RegionPlanFailure.ambiguousBand}
        func sortCharge(_ count:Int)->Int {count*max(1,Int(ceil(log2(Double(max(1,count))))))*2}
        try consume(sortCharge(ySet.count)+sortCharge(xSet.count));try check()
        let ys=ySet.sorted(),xs=xSet.sorted(),gap=3.0
        func covered(_ y:Double,_ left:Double,_ right:Double)throws->Bool {
            try horizontal.contains{try consume();return abs($0.y1-y)<=gap && $0.x1<=left+gap && $0.x2>=right-gap}
        }
        func support(_ x:Double,_ top:Double,_ bottom:Double)throws->Bool {
            try vertical.contains{try consume();return abs($0.x1-x)<=gap && $0.y1<=top+gap && $0.y2>=bottom-gap}
        }
        var bands=[[PhysicalBox]]()
        for (i,top) in ys.enumerated() {
            for bottom in ys.dropFirst(i+1) {
                try check();var cells=[PhysicalBox]()
                let crossing=try xs.filter{try support($0,top,bottom)}
                for (left,right) in zip(crossing,crossing.dropFirst()) {
                    try consume()
                    if try (right-left)/(bottom-top)>=4 && covered(top,left,right) && covered(bottom,left,right) {
                        cells.append(PhysicalBox(x:left,y:top,width:right-left,height:bottom-top))
                    }
                }
                guard cells.count==5 else {continue}
                let widths=cells.map(\.width),mean=widths.reduce(0,+)/5
                guard widths.allSatisfy({abs($0-mean)<=mean*0.05}),zip(cells,cells.dropFirst()).allSatisfy({abs($0.right-$1.x)<=gap}) else {continue}
                bands.append(cells)
            }
        }
        guard let minimum=bands.map({$0[0].height}).min() else {throw RegionPlanFailure.ambiguousBand}
        let selected=bands.filter{abs($0[0].height-minimum)<0.001}
        guard selected.count==1,let band=selected.first else {throw RegionPlanFailure.ambiguousBand}
        let edges=[band[0].x]+band.map(\.right),top=band[0].y
        let bottoms=try ys.filter{y in try y>band[0].bottom && covered(y,edges[0],edges.last!) && edges.allSatisfy{x in try support(x,top,y)}}
        guard let bottom=bottoms.max() else {throw RegionPlanFailure.incompleteBottom}
        let affine=RasterAffine(sourceBox:PhysicalBox(x:0,y:0,width:Double(originalWidth),height:Double(originalHeight)),scale:coarseScale,renderedHeight:coarseHeight)
        func original(_ box:PhysicalBox)->PhysicalBox {affine.original(box)}
        let originalTop=original(PhysicalBox(x:0,y:top,width:1,height:1)).y
        func padded(_ b:PhysicalBox)throws->PhysicalBox {
            guard [b.x,b.y,b.width,b.height,b.right,b.bottom].allSatisfy(\.isFinite),b.x>=0,b.y>=0,b.width>0,b.height>0,b.right<=Double(originalWidth),b.bottom<=Double(originalHeight) else {throw RegionPlanFailure.invalidBasis}
            let left=max(0,floor(b.x)-2),upper=max(0,floor(b.y)-2),right=min(Double(originalWidth),ceil(b.right)+2),lower=min(Double(originalHeight),ceil(b.bottom)+2)
            guard left<right,upper<lower,(right-left)*2<=2048,(lower-upper)*2<=2048 else {throw RegionPlanFailure.oversizedRegion}
            return PhysicalBox(x:left,y:upper,width:right-left,height:lower-upper)
        }
        var output=[PlannedRegion]()
        for (index,cell) in band.enumerated() {output.append(PlannedRegion(id:"measured-strip-\(index)",box:try padded(original(PhysicalBox(x:cell.x,y:top,width:cell.width,height:bottom-top))),scale:2))}
        let classMargin=original(PhysicalBox(x:0,y:top,width:band[0].x,height:bottom-top))
        output.append(PlannedRegion(id:"measured-left-margin",box:try padded(classMargin),scale:2))
        guard let metadata=try upperInkExtent(originalTop-2),[metadata.x,metadata.y,metadata.width,metadata.height].allSatisfy(\.isFinite),metadata.width>0,metadata.height>0,metadata.x>=0,metadata.y>=0,metadata.right<=Double(originalWidth),metadata.bottom<=originalTop-2 else {throw RegionPlanFailure.invalidMetadata}
        output.append(PlannedRegion(id:"measured-upper-ink",box:try padded(metadata),scale:2))
        guard output.count==7 else {throw RegionPlanFailure.ambiguousBand}
        return output
    }
}
