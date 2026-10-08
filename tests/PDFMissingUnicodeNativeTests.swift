import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit)
import PDFKit
import CoreGraphics
import CoreText

final class PDFMissingUnicodeNativeTests: XCTestCase {
    func testEqualGlyphPixelsDoNotAuthenticateUnicodeMeaning() throws {
        let original=try inventedFont(),swapped=try inventedFont(swappedMapping:true)
        let originalMap=try PDFTrueTypeRecoveryMap.read(original)
        let swappedMap=try PDFTrueTypeRecoveryMap.read(swapped)
        XCTAssertEqual(try originalMap.resolve(cid:1,cidToGid:nil).text,"A")
        XCTAssertEqual(try originalMap.resolve(cid:2,cidToGid:nil).text,"B")
        XCTAssertEqual(try swappedMap.resolve(cid:1,cidToGid:nil).text,"B")
        XCTAssertEqual(try swappedMap.resolve(cid:2,cidToGid:nil).text,"A")
        XCTAssertNotEqual(originalMap.fontHash,swappedMap.fontHash)
        XCTAssertEqual(try pagePixels(pdf(original)),try pagePixels(pdf(swapped)),
            "Changing only cmap meaning can preserve every final PDF pixel")

        let identical=try inventedFont(identicalGlyphs:true)
        let identicalMap=try PDFTrueTypeRecoveryMap.read(identical)
        XCTAssertEqual(try identicalMap.resolve(cid:1,cidToGid:nil).text,"A")
        XCTAssertEqual(try identicalMap.resolve(cid:2,cidToGid:nil).text,"B")
        let pixels=try pagePixels(pdf(identical))
        XCTAssertTrue(isolatedGlyphRegion.contains { pixels[$0]<255 })
        XCTAssertEqual(pixels,try pagePixels(pdf(identical,reversedGlyphs:true)),
            "Distinct uniquely mapped GIDs can have indistinguishable visible outlines")
        // Neither font-declared Unicode nor same-font pixels provide independent
        // semantic authentication. This observation enables no adoption path.
    }
    func testLaterOpaquePaintingRemovesMappedVisibleGlyphEvidence() throws {
        let font=try inventedFont()
        let map=try PDFTrueTypeRecoveryMap.read(font)
        XCTAssertEqual(try map.resolve(cid:1,cidToGid:nil).text,"A")
        let visible=try pagePixels(pdf(font))
        let overpainted=try pagePixels(pdf(font,overpaint:true))
        XCTAssertTrue(isolatedGlyphRegion.contains { visible[$0]<255 })
        XCTAssertFalse(isolatedGlyphRegion.contains { overpainted[$0]<255 },
            "Normal text rendering mode does not prove that final page pixels retain the text")
        XCTAssertNotEqual(visible,overpainted)
    }
    func testMissingUnicodePixelsRequireExactEmbeddedGlyphAndPlacement() throws {
        let font=try inventedFont()
        let provider=try XCTUnwrap(CGDataProvider(data:font as CFData))
        let graphicsFont=try XCTUnwrap(CGFont(provider))
        let document=try XCTUnwrap(PDFDocument(data:pdf(font)))
        let page=try XCTUnwrap(document.page(at:0)?.pageRef)
        func render(_ draw:(CGContext)->Void) throws -> [UInt8] {
            var bytes=[UInt8](repeating:255,count:800*800)
            try bytes.withUnsafeMutableBytes { buffer in
                let context=try XCTUnwrap(CGContext(data:buffer.baseAddress,width:800,height:800,
                    bitsPerComponent:8,bytesPerRow:800,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0))
                context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:800,height:800))
                context.scaleBy(x:4,y:4)
                context.setFillColor(gray:0,alpha:1);context.setStrokeColor(gray:0,alpha:1)
                draw(context)
            }
            return bytes
        }
        let original=try render { $0.drawPDFPage(page) }
        func glyphPixels(_ glyphs:[CGGlyph],shift:CGFloat=0,font:CGFont?=nil) throws -> [UInt8] {
            try render { context in
                context.setFont(font ?? graphicsFont);context.setFontSize(10)
                context.textMatrix = .identity
                context.showGlyphs(glyphs,at:[CGPoint(x:20+shift,y:100),CGPoint(x:26+shift,y:100)])
                context.stroke(CGRect(x:10,y:10,width:100,height:120))
            }
        }
        let exact=try glyphPixels([1,2])
        let difference=zip(original,exact).filter { $0 != $1 }.count
        print("FONT_PIXEL_OBSERVATION invented=true;grid=800x800;exactDifferentPixels=\(difference)")
        // Check the isolated glyph region, not the border's unrelated ink.
        let glyphRegion=(360..<440).flatMap { y in (80..<136).map { x in y*800+x } }
        XCTAssertTrue(glyphRegion.contains { original[$0]<255 },"The border alone is not glyph evidence")
        XCTAssertEqual(difference,0,"The original PDF must agree with directly painted actual embedded GIDs")
        XCTAssertNotEqual(original,try glyphPixels([2,1]),"Swapping distinguishable source glyphs must fail")
        XCTAssertNotEqual(original,try glyphPixels([1,2],shift:0.25),"Changing the pixel-grid phase must fail")
        XCTAssertNotEqual(original,try glyphPixels([0,2]),"An absent visible glyph must fail")
        let wrongProvider=try XCTUnwrap(CGDataProvider(data:try inventedFont(firstWidth:450) as CFData))
        let wrongFont=try XCTUnwrap(CGFont(wrongProvider))
        XCTAssertNotEqual(original,try glyphPixels([1,2],font:wrongFont),"The same GIDs from a different font must fail")
        let hiddenDocument=try XCTUnwrap(PDFDocument(data:pdf(font,textMode:3)))
        let hiddenPage=try XCTUnwrap(hiddenDocument.page(at:0)?.pageRef)
        let hidden=try render { $0.drawPDFPage(hiddenPage) }
        XCTAssertFalse(glyphRegion.contains { hidden[$0]<255 },"Invisible text must not be counted as visible glyph evidence")
        XCTAssertNotEqual(hidden,exact,"Mapped but invisible original text must fail the visible pixel proof")
    }
    func testNativeFontAndPDFKitMissingUnicodeObservation() throws {
        let font=try inventedFont()
        let map=try PDFTrueTypeRecoveryMap.read(font)
        XCTAssertEqual(try map.resolve(cid:1,cidToGid:nil).text,"A")
        XCTAssertEqual(try map.resolve(cid:2,cidToGid:nil).text,"B")
        let provider=try XCTUnwrap(CGDataProvider(data:font as CFData))
        let graphicsFont=try XCTUnwrap(CGFont(provider))
        let textFont=CTFontCreateWithGraphicsFont(graphicsFont,10,nil,nil)
        var characters:[UniChar]=[65,66],glyphs:[CGGlyph]=[0,0]
        XCTAssertTrue(CTFontGetGlyphsForCharacters(textFont,&characters,&glyphs,2))
        XCTAssertEqual(glyphs,[1,2])
        XCTAssertNotNil(CTFontCreatePathForGlyph(textFont,1,nil))
        let bytes=pdf(font)
        let document=try XCTUnwrap(PDFDocument(data:bytes)),page=try XCTUnwrap(document.page(at:0))
        let raw=page.string ?? ""
        print("FONT_NATIVE_OBSERVATION synthetic=AB;scalars=\(raw.unicodeScalars.map(\.value));characters=\(page.numberOfCharacters)")
        let owned=FileManager.default.temporaryDirectory.appendingPathComponent("font-native-owned-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:owned,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:owned) }
        let url=owned.appendingPathComponent("invented.pdf");try bytes.write(to:url)
        let capture=RecoveryReadCapture()
        XCTAssertThrowsError(try PDFKitReader.read(url,kind:.timetable,capture:capture))
        XCTAssertFalse(capture.complete)
        // Observation only: no new extraction/adoption route is enabled here.
    }
    private var isolatedGlyphRegion:[Int] {
        (360..<440).flatMap { y in (80..<136).map { x in y*800+x } }
    }
    private func pagePixels(_ bytes:Data) throws -> [UInt8] {
        let document=try XCTUnwrap(PDFDocument(data:bytes))
        let page=try XCTUnwrap(document.page(at:0)?.pageRef)
        var pixels=[UInt8](repeating:255,count:800*800)
        try pixels.withUnsafeMutableBytes { buffer in
            let context=try XCTUnwrap(CGContext(data:buffer.baseAddress,width:800,height:800,
                bitsPerComponent:8,bytesPerRow:800,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0))
            context.setFillColor(gray:1,alpha:1);context.fill(CGRect(x:0,y:0,width:800,height:800))
            context.scaleBy(x:4,y:4)
            context.setFillColor(gray:0,alpha:1);context.setStrokeColor(gray:0,alpha:1)
            context.drawPDFPage(page)
        }
        return pixels
    }
    private func inventedFont(firstWidth:Int=500,swappedMapping:Bool=false,identicalGlyphs:Bool=false) throws -> Data {
        // These tables describe invented rectangle outlines and A/B cmap entries.
        // They are authored test data, not an embedded font copied from a PDF.
        let encoded:[(String,String)]=[
            ("glyf", "AAAAAAAAAAAAAAAAAAEAAAAAAfQCvAADAAAxIREhAfT+DAK8AAEAAAAAAfQCvAADAAAxIREhAfT+DAK8AAAAAAAAAAAAAAAA"),
            ("head", "AAEAAAAAAAAAAAAAXw889QAAA+gAAAAAAAAAAAAAAAAAAAAAAAAAAAH0ArwAAAAIAAAAAAAA"),
            ("hhea", "AAEAAAMg/zgAAAJYAAAAAAH0AAEAAAAAAAAAAAAAAAAAAAAE"),
            ("hmtx", "AlgAAAJYAAACWAAAAlgAAA=="),
            ("loca", "AAAABgASAB4AJA=="),
            ("maxp", "AAEAAAAEAAQAAQAAAAAAAQAAAAAAAAAAAAAAAAAAAAA="),
            ("name", "AAAAAwAqAAMAAQQJAAEALAAAAAMAAQQJAAIADgAsAAMAAQQJAAYALAA6AEkAbgB2AGUAbgB0AGUAZABFAHgAdAByAGEAYwB0AGkAbwBuAEYAbwBuAHQAUgBlAGcAdQBsAGEAcgBJAG4AdgBlAG4AdABlAGQARQB4AHQAcgBhAGMAdABpAG8AbgBGAG8AbgB0"),
            ("post", "AAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="),
        ]
        var tables=try encoded.map { entry -> (String,Data) in
            var data=try XCTUnwrap(Data(base64Encoded:entry.1))
            if entry.0=="glyf" {
                // The usual GID 2 is distinguishable (300 x 400). The separate
                // homograph observation deliberately makes its outline equal.
                var bytes=Array(data)
                u16(&bytes,12+6,firstWidth);u16(&bytes,12+18,firstWidth)
                u16(&bytes,12+20,65536-firstWidth)
                let secondWidth=identicalGlyphs ? firstWidth : 300
                let secondHeight=identicalGlyphs ? 700 : 400
                u16(&bytes,36+6,secondWidth);u16(&bytes,36+8,secondHeight)
                u16(&bytes,36+18,secondWidth);u16(&bytes,36+20,65536-secondWidth);u16(&bytes,36+22,secondHeight)
                data=Data(bytes)
            }
            return (entry.0,data)
        }
        tables.insert(("cmap",authoredCmap(swapped:swappedMapping)),at:0)
        var bytes=[UInt8](repeating:0,count:12+tables.count*16)
        u32(&bytes,0,0x10000);u16(&bytes,4,tables.count);u16(&bytes,6,128);u16(&bytes,8,3);u16(&bytes,10,16)
        var headOffset=0
        for (i,table) in tables.enumerated() {
            while bytes.count%4 != 0 { bytes.append(0) }
            let entry=12+i*16
            bytes.replaceSubrange(entry..<(entry+4),with:Array(table.0.utf8))
            u32(&bytes,entry+4,checksum(Array(table.1)))
            u32(&bytes,entry+8,UInt32(bytes.count));u32(&bytes,entry+12,UInt32(table.1.count))
            if table.0=="head" { headOffset=bytes.count }
            bytes+=table.1
        }
        u32(&bytes,headOffset+8,0xb1b0afba &- checksum(bytes))
        return Data(bytes)
    }
    private func authoredCmap(swapped:Bool) -> Data {
        // Two independently authored Unicode tables, each with one A and B
        // entry. Both are changed together; outlines and PDF GIDs stay fixed.
        let glyphs=swapped ? [2,1] : [1,2]
        var bytes=[UInt8](repeating:0,count:100)
        u16(&bytes,2,2)
        u16(&bytes,4,0);u16(&bytes,6,4);u32(&bytes,8,20)
        u16(&bytes,12,3);u16(&bytes,14,1);u32(&bytes,16,60)
        u16(&bytes,20,12);u32(&bytes,24,40);u32(&bytes,32,2)
        for i in 0..<2 {
            u32(&bytes,36+i*12,UInt32(65+i));u32(&bytes,40+i*12,UInt32(65+i))
            u32(&bytes,44+i*12,UInt32(glyphs[i]))
        }
        u16(&bytes,60,4);u16(&bytes,62,40);u16(&bytes,66,6)
        u16(&bytes,68,4);u16(&bytes,70,1);u16(&bytes,72,2)
        for i in 0..<2 {
            u16(&bytes,74+i*2,65+i);u16(&bytes,82+i*2,65+i)
            u16(&bytes,88+i*2,(glyphs[i]-65-i)&65535)
        }
        u16(&bytes,78,65535);u16(&bytes,86,65535);u16(&bytes,92,1)
        return Data(bytes)
    }
    private func checksum(_ original:[UInt8]) -> UInt32 {
        var bytes=original;while bytes.count%4 != 0 { bytes.append(0) }
        var result:UInt32=0
        for i in stride(from:0,to:bytes.count,by:4) {
            let word=bytes[i..<(i+4)].reduce(UInt32(0)){($0<<8)|UInt32($1)};result=result &+ word
        }
        return result
    }
    private func u16(_ bytes:inout [UInt8],_ offset:Int,_ value:Int) {
        bytes[offset]=UInt8((value>>8)&255);bytes[offset+1]=UInt8(value&255)
    }
    private func u32(_ bytes:inout [UInt8],_ offset:Int,_ value:UInt32) {
        for i in 0..<4 { bytes[offset+i]=UInt8((value>>UInt32(24-i*8))&255) }
    }
    private func pdf(_ font:Data,textMode:Int=0,reversedGlyphs:Bool=false,overpaint:Bool=false) -> Data {
        func ascii(_ s:String)->Data { Data(s.utf8) }
        func stream(_ bytes:Data,font:Bool=false)->Data {
            ascii("<< /Length \(bytes.count) \(font ? "/Length1 \(bytes.count)" : "") >>\nstream\n")+bytes+ascii("\nendstream")
        }
        let objects=[
            ascii("<< /Type /Catalog /Pages 2 0 R >>"),ascii("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
            ascii("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>"),
            ascii("<< /Type /Font /Subtype /Type0 /BaseFont /InventedExtractionFont /Encoding /Identity-H /DescendantFonts [6 0 R] >>"),
            stream(ascii("BT /F1 10 Tf \(textMode) Tr 1 0 0 1 20 100 Tm <\(reversedGlyphs ? "00020001":"00010002")> Tj ET \(overpaint ? "q 1 g 18 98 14 12 re f Q":"") 10 10 100 120 re S")),
            ascii("<< /Type /Font /Subtype /CIDFontType2 /BaseFont /InventedExtractionFont /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /FontDescriptor 7 0 R /DW 600 >>"),
            ascii("<< /Type /FontDescriptor /FontName /InventedExtractionFont /Flags 32 /FontBBox [0 -200 600 800] /ItalicAngle 0 /Ascent 800 /Descent -200 /CapHeight 700 /StemV 80 /FontFile2 8 0 R >>"),stream(font,font:true)
        ]
        var output=ascii("%PDF-1.7\n"),offsets:[Int]=[]
        for (i,value) in objects.enumerated() { offsets.append(output.count);output+=ascii("\(i+1) 0 obj\n")+value+ascii("\nendobj\n") }
        let xref=output.count;output+=ascii("xref\n0 \(objects.count+1)\n0000000000 65535 f \n")
        for offset in offsets { output+=ascii(String(format:"%010d 00000 n \n",offset)) }
        output+=ascii("trailer\n<< /Size \(objects.count+1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n")
        return output
    }
}
#endif
