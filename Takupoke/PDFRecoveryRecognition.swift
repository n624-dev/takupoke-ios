#if canImport(Vision) && canImport(PDFKit) && canImport(UIKit)
import Foundation
import Vision
import PDFKit
import UIKit

@available(iOS 26.0, *)
struct RecoveryRecognizedPage: Sendable {
    var page: Int
    var width: Int
    var height: Int
    var observations: [DocumentObservation]
    // Keep words, lines, tables and merged-cell ranges intact for deterministic layout binding.
    // OCR completion does not prove that an unrecognized cell is empty.
    var inputState: RecoveryInputState = .complete
}
@available(iOS 26.0, *)
enum PDFRecoveryRecognition {
    static func read(_ url: URL, foreground: Bool, only: Set<Int>? = nil, check: () throws -> Void) async throws -> [RecoveryRecognizedPage] {
        guard foreground, let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= MaterialLibrary.maximumBytes,
              let document = PDFDocument(url: url), !document.isLocked, (1...12).contains(document.pageCount) else {
            throw PDFParseError(code: .unreadable)
        }
        var pages = [RecoveryRecognizedPage]()
        for index in 0..<document.pageCount where only == nil || only!.contains(index + 1) {
            try check(); try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw PDFParseError(code: .unreadable, page: index + 1) }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0, bounds.width.isFinite, bounds.height.isFinite else { throw PDFParseError(code: .unreadable, page: index + 1) }
            let scale = min(2, 2048 / max(bounds.width, bounds.height))
            let image = page.thumbnail(of: CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale)), for: .mediaBox)
            guard let raster = image.cgImage else { throw PDFParseError(code: .unreadable, page: index + 1) }
            // One bounded page per request; no page image goes to a language model.
            let observations = try await RecognizeDocumentsRequest().perform(on: raster)
            try check(); try Task.checkCancellation()
            guard observations.count <= 1000 else { throw PDFParseError(code: .limit, page: index + 1) }
            pages.append(RecoveryRecognizedPage(page: index + 1, width: raster.width, height: raster.height, observations: observations))
        }
        return pages
    }
    struct LayoutPage: Sendable { var page: Int; var layout: PDFPageLayout; var raster: RecoveryRasterGrid }
    static func layouts(_ url: URL, only: Set<Int>?, check: () throws -> Void) async throws -> [LayoutPage] {
        guard let document = PDFDocument(url:url), !document.isLocked, (1...12).contains(document.pageCount) else { throw PDFParseError(code:.unreadable) }
        var output = [LayoutPage]()
        for index in 0..<document.pageCount where only == nil || only!.contains(index+1) {
            try check(); try Task.checkCancellation()
            guard let page = document.page(at:index) else { throw PDFParseError(code:.unreadable) }
            let bounds = page.bounds(for:.mediaBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { throw PDFParseError(code:.limit) }
            let scale = min(2,2048/max(bounds.width,bounds.height))
            let w = Int(ceil(bounds.width*scale)), h = Int(ceil(bounds.height*scale))
            guard w > 0, h > 0, w <= 2048, h <= 2048 else { throw PDFParseError(code:.limit) }
            let image = page.thumbnail(of:CGSize(width:w,height:h),for:.mediaBox)
            guard let cg = image.cgImage else { throw PDFParseError(code:.unreadable) }
            var gray = [UInt8](repeating:255,count:cg.width*cg.height)
            let made = gray.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data:bytes.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return false }
                context.setFillColor(gray:1,alpha:1); context.fill(CGRect(x:0,y:0,width:cg.width,height:cg.height)); context.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
                return true
            }
            guard made else { throw PDFParseError(code:.unreadable) }
            let raster = RecoveryRasterGrid(width:cg.width,height:cg.height,grayscale:gray)
            let observations = try await RecognizeDocumentsRequest().perform(on:cg)
            try check(); try Task.checkCancellation()
            var glyphs = [PDFGlyph](), order = 0, lineNumber = 0
            for observation in observations {
                for line in observation.document.text.lines {
                    guard let candidate = line.topCandidates(1).first, candidate.confidence >= 0.85 else { throw PDFParseError(code:.ambiguous,stage:.rasterInput) }
                    let text = candidate.string
                    for start in text.indices {
                        let end = text.index(after:start)
                        guard let rectangle = candidate.boundingBox(for:start..<end) else { throw PDFParseError(code:.ambiguous,stage:.characterMapping) }
                        let b = rectangle.boundingBox.cgRect
                        let rect = CGRect(x:b.minX*Double(cg.width),y:(1-b.maxY)*Double(cg.height),width:b.width*Double(cg.width),height:b.height*Double(cg.height))
                        guard rect.width > 0, rect.height > 0, rect.minX >= 0, rect.minY >= 0 else { throw PDFParseError(code:.ambiguous) }
                        glyphs.append(PDFGlyph(text:String(text[start..<end]),x:rect.minX,y:rect.minY,width:rect.width,height:rect.height,sourceLine:lineNumber,sourceOrder:order)); order += 1
                    }
                    lineNumber += 1
                }
            }
            guard glyphs.count <= 100000 else { throw PDFParseError(code:.limit) }
            let rules = try raster.rules(check:check)
            output.append(LayoutPage(page:index+1,layout:PDFPageLayout(width:Double(cg.width),height:Double(cg.height),glyphs:glyphs,lines:rules),raster:raster))
        }
        return output
    }

}
#endif
