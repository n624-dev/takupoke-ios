import Foundation
import UIKit

struct DrawDay:Decodable { var value:String; var printed:String }
struct DrawLesson:Decodable { var day:String; var period:Int; var subject:String; var teacher:String; var room:String }
struct DrawSource:Decodable { var width:Int; var height:Int; var fontSize:Int; var className:String; var days:[DrawDay]; var lessons:[DrawLesson] }

/// Newly generated UIKit pixels, not the former Pillow pixels. Text has no role labels.
/// The construction source draws the input; its semantic boxes/IDs never enter OCR or Builder.
enum FortyFixture {
    @MainActor static func make(_ sourceURL:URL) throws -> (CGImage,[[String:Any]],Double) {
        let source=try JSONDecoder().decode(DrawSource.self,from:Data(contentsOf:sourceURL))
        guard source.width==3740,source.height==800,source.fontSize==20,source.className=="1_2",source.days.count==5,source.lessons.count==40 else { throw NSError(domain:"FixtureShape",code:1) }
        // Exactly the public layouts scale/ceil recipe applied to source page coordinates.
        let scale=min(2,2048/max(Double(source.width),Double(source.height)))
        let width=Int(ceil(Double(source.width)*scale)),height=Int(ceil(Double(source.height)*scale))
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true;format.preferredRange = .standard
        var drawings=[[String:Any]]()
        let image=UIGraphicsImageRenderer(size:CGSize(width:CGFloat(width),height:CGFloat(height)),format:format).image { renderer in
            let context=renderer.cgContext
            UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:CGFloat(width),height:CGFloat(height)))
            context.scaleBy(x:scale,y:scale)
            UIColor.black.setStroke();context.setLineWidth(2)
            let font=UIFont.systemFont(ofSize:CGFloat(source.fontSize),weight:.regular)
            let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:UIColor.black]
            func rule(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat) {
                context.move(to:CGPoint(x:x1,y:y1));context.addLine(to:CGPoint(x:x2,y:y2));context.strokePath()
            }
            func text(_ id:String,_ literal:String,_ box:[CGFloat]) {
                let bounds=(literal as NSString).size(withAttributes:attributes)
                let x=box[0]+(box[2]-box[0]-bounds.width)/2,y=box[1]+(box[3]-box[1]-bounds.height)/2
                (literal as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:attributes)
                drawings.append(["id":id,"rawText":literal,"sourceBox":box.map(Double.init),"pixelPrintedBox":[Double(box[0])*scale,Double(box[1])*scale,Double(box[2])*scale,Double(box[3])*scale],
                  "pixelTypographicDrawingBox":[Double(x)*scale,Double(y)*scale,Double(bounds.width)*scale,Double(bounds.height)*scale],"glyphInkScope":"UIKit typography, not exact original glyph ink"])
            }
            let left:CGFloat=20,gradeRight:CGFloat=60,bodyLeft:CGFloat=120,cell:CGFloat=90
            let right=bodyLeft+40*cell,dayTop:CGFloat=70,periodTop:CGFloat=104,bodyTop:CGFloat=136,bottom:CGFloat=232
            for y in [dayTop,bodyTop,bottom] { rule(left,y,right,y) }
            rule(bodyLeft,periodTop,right,periodTop)
            for x in [left,gradeRight,bodyLeft] { rule(x,dayTop,x,bottom) }
            for i in 1...40 { rule(bodyLeft+CGFloat(i)*cell,i%8==0 ? dayTop:periodTop,bodyLeft+CGFloat(i)*cell,bottom) }
            text("year","令和14年度",[20,2,280,50]);text("term","前期",[310,2,430,50]);text("title","時間割",[480,2,680,50])
            text("grade","1",[left,bodyTop,gradeRight,bottom]);text("class","2",[gradeRight,bodyTop,bodyLeft,bottom])
            for (d,day) in source.days.enumerated() {
                let x=bodyLeft+CGFloat(d)*8*cell
                text("weekday-\(d)",day.printed,[x,dayTop,x+8*cell,periodTop])
                for p in 1...8 { let cx=x+CGFloat(p-1)*cell;text("period-\(d)-\(p)","\(p)",[cx,periodTop,cx+cell,bodyTop]) }
            }
            for lesson in source.lessons {
                guard let d=source.days.firstIndex(where:{$0.value==lesson.day}) else { continue }
                let x=bodyLeft+CGFloat(d*8+lesson.period-1)*cell
                for (r,literal) in [lesson.subject,lesson.teacher,lesson.room].enumerated() {
                    let top=bodyTop+CGFloat(r)*32
                    text("body-\(d)-\(lesson.period)-\(r)",literal,[x,top,x+cell,top+32])
                }
            }
        }
        guard let cg=image.cgImage,cg.width==width,cg.height==height else { throw NSError(domain:"FixtureImageUnavailable",code:1) }
        return(cg,drawings,scale)
    }
}
