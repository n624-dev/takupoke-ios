import Foundation
#if canImport(CoreGraphics) && canImport(CoreText)
import CoreGraphics
import CoreText

extension PDFDrawnTextReader {
    /// Uses the embedded font actually addressed by the PDF's encoded codes.
    /// No system font substitution and no Unicode -> glyph guess is permitted.
    func embeddedGlyphBounds(font: CGPDFDictionaryRef, metrics: CGPDFDictionaryRef,
                             descriptor: CGPDFDictionaryRef, composite: Bool,
                             codes: [Int]) throws -> [Int: PDFBox]? {
        try engine.check()
        var stream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(descriptor, "FontFile2", &stream), let stream else { return nil }
        var format = CGPDFDataFormat.raw
        guard let raw = CGPDFStreamCopyData(stream, &format), format == .raw,
              CFDataGetLength(raw) <= 8_000_000 else { return nil }
        let data = raw as Data
        var mapping: [Int: UInt16]?
        if composite {
            var subtype: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(metrics, "Subtype", &subtype), let subtype,
                  String(cString:subtype) == "CIDFontType2" else { return nil }
            var object: CGPDFObjectRef?, mapStream: CGPDFStreamRef?, mapName: UnsafePointer<CChar>?
            if !CGPDFDictionaryGetObject(metrics, "CIDToGIDMap", &object) ||
                (CGPDFDictionaryGetName(metrics, "CIDToGIDMap", &mapName) && mapName.map { String(cString:$0) } == "Identity") {
                mapping = Dictionary(uniqueKeysWithValues: codes.map { ($0, UInt16($0)) })
            } else if CGPDFDictionaryGetStream(metrics, "CIDToGIDMap", &mapStream), let mapStream {
                guard let rawMap = CGPDFStreamCopyData(mapStream, &format), format == .raw else { return nil }
                mapping = try PDFEncodedGlyphMap.cidToGID(rawMap as Data, check:engine.check)
            } else { return nil }
        } else {
            var encoding: CGPDFObjectRef?, flags: CGPDFInteger = 0
            guard !CGPDFDictionaryGetObject(font, "Encoding", &encoding),
                  CGPDFDictionaryGetInteger(descriptor, "Flags", &flags), flags & 4 != 0, flags & 32 == 0 else { return nil }
            mapping = try PDFEncodedGlyphMap.symbolicTrueType(data, check:engine.check)
        }
        guard let mapping, let provider = CGDataProvider(data:data as CFData), let cgFont = CGFont(provider) else { return nil }
        let ctFont = CTFontCreateWithGraphicsFont(cgFont, 1000, nil, nil)
        var result: [Int: PDFBox] = [:]
        for code in codes.sorted() {
            try engine.check()
            guard let gid = mapping[code], gid != 0, Int(gid) < cgFont.numberOfGlyphs,
                  let path = CTFontCreatePathForGlyph(ctFont, gid, nil) else { continue }
            let box = path.boundingBoxOfPath
            guard !box.isNull, !box.isEmpty,
                  [box.minX,box.minY,box.maxX,box.maxY].allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { continue }
            result[code] = PDFBox(left:Double(box.minX),top:Double(box.minY),right:Double(box.maxX),bottom:Double(box.maxY))
        }
        // A supported physical map with missing/empty glyphs is not rescued by
        // the whole-font box. Geometry rejects it when outlined text uses it.
        return result
    }
}
#endif
