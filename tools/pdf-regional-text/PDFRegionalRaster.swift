import Foundation
import PDFKit
import CoreGraphics

enum PDFRegionalRaster {
    /// PDF coordinates are bottom-left; our recorded original/region basis is top-left pixels.
    static func render(_ page:CGPDFPage,box:PhysicalBox,scale:Double,maximum:Int)throws->CGImage {
        let bounds=page.getBoxRect(.cropBox)
        guard bounds.minX==0,bounds.minY==0,scale.isFinite,scale>0,[box.x,box.y,box.width,box.height].allSatisfy(\.isFinite),box.x>=0,box.y>=0,box.width>0,box.height>0,box.right<=bounds.width,box.bottom<=bounds.height else {throw PDFParseError(code:.unsupported,stage:.rasterInput)}
        let width=Int(ceil(box.width*scale)),height=Int(ceil(box.height*scale))
        guard width>0,height>0,width<=maximum,height<=maximum else {throw PDFParseError(code:.limit)}
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue) else {throw PDFParseError(code:.unreadable)}
        context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:width,height:height))
        context.translateBy(x:0,y:CGFloat(height));context.scaleBy(x:scale,y:-scale)
        context.translateBy(x:-box.x,y:-(bounds.height-box.bottom))
        context.drawPDFPage(page)
        guard let image=context.makeImage() else {throw PDFParseError(code:.unreadable)}
        return image
    }
    static func rgba(_ image:CGImage)throws->[UInt8] {
        guard image.bitsPerComponent==8,image.bitsPerPixel==32,image.bytesPerRow==image.width*4,
              let data=image.dataProvider?.data,CFDataGetLength(data)==image.width*image.height*4 else {throw PDFParseError(code:.unsupported,stage:.rasterInput)}
        return Array(data as Data)
    }
    /// Upper metadata extent uses only original nonwhite pixels, never text or drawing boxes.
    static func upperInkExtent(_ raster:RecoveryRasterGrid,before:Double,check:()throws->Void)throws->PhysicalBox? {
        guard before.isFinite,before>0,before<=Double(raster.height) else {return nil}
        var left=raster.width,right = -1,top=raster.height,bottom = -1
        for y in 0..<Int(floor(before)) {
            if y%64==0 {try check()}
            for x in 0..<raster.width where raster.grayscale[y*raster.width+x] != 255 {
                left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
            }
        }
        guard right>=left,bottom>=top else {return nil}
        return PhysicalBox(x:Double(left),y:Double(top),width:Double(right-left+1),height:Double(bottom-top+1))
    }
}
