import UIKit

/// New drawing design, independent of every former PDF/image and any real school data.
/// These drawing records are post-observation oracle only; Vision receives only the CGImage.
enum FreshFixture {
    @MainActor static func make() throws -> (CGImage, [[String:Any]]) {
        let width=2000,height=1000
        let format=UIGraphicsImageRendererFormat(); format.scale=1; format.opaque=true; format.preferredRange = .standard
        var expected=[[String:Any]]()
        let image=UIGraphicsImageRenderer(size:CGSize(width:CGFloat(width),height:CGFloat(height)),format:format).image { renderer in
            let context=renderer.cgContext
            UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:CGFloat(width),height:CGFloat(height)))
            UIColor.black.setStroke();context.setLineWidth(2)
            func text(_ id:String,_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat) {
                let font=UIFont.systemFont(ofSize:size,weight:.regular)
                let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:UIColor.black]
                let bounds=(value as NSString).size(withAttributes:attributes)
                (value as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:attributes)
                expected.append(["id":id,"text":value,"pixelTopLeft":["x":Double(x),"y":Double(y),"width":Double(bounds.width),"height":Double(bounds.height)],"boxScope":"UIKit typographic drawing bounds, not exact glyph ink","fontPointSize":Double(size)])
            }
            func line(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat) {
                context.move(to:CGPoint(x:x1,y:y1));context.addLine(to:CGPoint(x:x2,y:y2));context.strokePath()
            }
            text("title","完全架空 観測用時間割",61,37,36)
            text("yearTerm","2035年度 前期",61,98,30)
            text("roleSubject","科目：架空科目琥",760,36,28)
            text("roleTeacher","教員：架空教員朔",760,89,28)
            text("roleRoom","教室：架空室R73",760,142,28)
            let x:CGFloat=48,y:CGFloat=254,classWidth:CGFloat=180,col:CGFloat=216
            let body=y+106,bottom=body+350,right=x+classWidth+8*col
            for yy in [y,y+52,body,body+175,bottom] { line(x,yy,right,yy) }
            line(x,y,x,bottom);line(x+classWidth,y,x+classWidth,bottom);line(right,y,right,bottom)
            for i in 1..<8 {
                let xx=x+classWidth+CGFloat(i)*col
                // The first body row merges periods 3 and 4; never draw a hidden divider there.
                line(xx,y+52,xx,body)
                if i != 3 { line(xx,body,xx,body+175) }
                line(xx,body+175,xx,bottom)
            }
            text("weekday","月",x+classWidth+824,y+7,32)
            text("classHeader","クラス",x+20,y+54,28)
            for i in 0..<8 { text("period-\(i+1)","\(i+1)",x+classWidth+CGFloat(i)*col+96,y+61,30) }
            text("class-a","2_XM",x+31,body+55,30)
            text("class-b","3_ZQ",x+31,body+231,30)
            for i in [0,1,2,4,5,6,7] {
                let xx=x+classWidth+CGFloat(i)*col+10
                text("subject-a-\(i)","架空科目\(["青","紅","紫","灰","翠","橙","紺","銀"][i])",xx,body+18,23)
                text("teacher-a-\(i)","架空教員\(["甲","乙","丙","丁","戊","己","庚","辛"][i])",xx,body+64,23)
                text("room-a-\(i)","架空室R\(71+i)",xx,body+110,23)
            }
            for i in 0..<8 { text("subject-b-\(i)","架空科目\(["白","黒","桃","藍","緑","黄","赤","茶"][i])",x+classWidth+CGFloat(i)*col+10,body+236,23) }
            text("paragraph","これは新規に描画した架空の比較用ページです。",61,790,29)
            text("english","Fictional amber lesson and fictional room R73",61,859,30)
            text("list-1","1. 架空の観測項目",1330,792,27)
            text("list-2","2. 架空の比較項目",1330,851,27)
        }
        guard let cg=image.cgImage,cg.width==width,cg.height==height else { throw NSError(domain:"FixtureImageUnavailable",code:1) }
        return (cg,expected)
    }
}
