// Strict parsing contract from 239.1 (bfc599fd5a552ced0c140497c703199547c30fd4).
// Font acceptance is unchanged; the CMap receives its caller's cancellation check.
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics

extension PDF239DrawnTextReader {
    func resource(_ scanner: CGPDFScannerRef, _ category: String, _ name: String) throws -> CGPDFDictionaryRef {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let object = CGPDFContentStreamGetResource(stream, category, name) else { throw PDF239TextFailure.unsupported(.b285) }
        var dict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(object, .dictionary, &dict), let dict = dict else { throw PDF239TextFailure.unsupported(.b286) }
        return dict
    }
    private func named(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var value: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dict, key, &value), let value = value else { return nil }
        return String(cString: value)
    }
    func number(_ dict: CGPDFDictionaryRef, _ key: String, fallback: Double? = nil) throws -> Double {
        var value: CGPDFReal = 0, object: CGPDFObjectRef?
        if CGPDFDictionaryGetNumber(dict, key, &value), value.isFinite { return Double(value) }
        guard !CGPDFDictionaryGetObject(dict, key, &object), let fallback = fallback else { throw PDF239TextFailure.unsupported(.b287) }
        return fallback
    }
    func font(_ scanner: CGPDFScannerRef) throws {
        let size = try numbers(scanner, 1)[0], key = try name(scanner)
        if let cached = fonts[key] { try engine.font(cached, size: size); return }
        guard fonts.count < 128 else { throw PDFParseError(code: .limit, branch:.b304) }
        let dict = try resource(scanner, "Font", key)
        var mapStream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream), let mapStream = mapStream else {
            throw PDF239TextFailure.unsupported(.b288)
        }
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(mapStream, &format), format == .raw else { throw PDF239TextFailure.unsupported(.b289) }
        let mapping = try PDF239UnicodeMap.read(data as Data, check: engine.check)
        var metrics = dict
        let composite = named(dict, "Subtype") == "Type0"
        if composite {
            var descendants: CGPDFArrayRef?, descendant: CGPDFDictionaryRef?
            guard named(dict, "Encoding") == "Identity-H", mapping.bytes == 2,
                  CGPDFDictionaryGetArray(dict, "DescendantFonts", &descendants), let descendants = descendants,
                  CGPDFArrayGetCount(descendants) == 1,
                  CGPDFArrayGetDictionary(descendants, 0, &descendant), let descendant = descendant,
                  ["CIDFontType0", "CIDFontType2"].contains(named(descendant, "Subtype") ?? "") else {
                throw PDF239TextFailure.unsupported(.b290)
            }
            metrics = descendant
        } else {
            guard ["TrueType", "Type1"].contains(named(dict, "Subtype") ?? ""), mapping.bytes == 1 else {
                throw PDF239TextFailure.unsupported(.b291)
            }
        }
        var descriptor: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(metrics, "FontDescriptor", &descriptor), let descriptor = descriptor else {
            throw PDF239TextFailure.unsupported(.b292)
        }
        var widths: [Int: Double] = [:]
        var array: CGPDFArrayRef?
        if composite {
            if CGPDFDictionaryGetArray(metrics, "W", &array), let array = array {
                let count = CGPDFArrayGetCount(array)
                guard count <= 200_000 else { throw PDFParseError(code: .limit, branch:.b303) }
                var i = 0
                func integer(_ index: Int) throws -> Int {
                    var n: CGPDFInteger = 0
                    guard index < count, CGPDFArrayGetInteger(array, index, &n), (0...65535).contains(n) else {
                        throw PDF239TextFailure.unsupported(.b293)
                    }
                    return n
                }
                func put(_ cid: Int, _ value: Double) throws {
                    guard (0...65535).contains(cid), value.isFinite, value >= 0, widths[cid] == nil else {
                        throw PDF239TextFailure.unsupported(.b294)
                    }
                    widths[cid] = value
                }
                while i < count {
                    try engine.check()
                    let start = try integer(i); i += 1
                    var list: CGPDFArrayRef?
                    guard i < count else { throw PDF239TextFailure.unsupported(.b295) }
                    if CGPDFArrayGetArray(array, i, &list), let list = list {
                        let length = CGPDFArrayGetCount(list)
                        guard length > 0, length <= 65536 - start else { throw PDF239TextFailure.unsupported(.b296) }
                        for offset in 0..<length {
                            var value: CGPDFReal = 0
                            guard CGPDFArrayGetNumber(list, offset, &value) else { throw PDF239TextFailure.unsupported(.b297) }
                            try put(start + offset, Double(value))
                        }
                        i += 1
                    } else {
                        let end = try integer(i); i += 1
                        var value: CGPDFReal = 0
                        guard end >= start, i < count, CGPDFArrayGetNumber(array, i, &value) else { throw PDF239TextFailure.unsupported(.b298) }
                        for cid in start...end { try put(cid, Double(value)) }
                        i += 1
                    }
                }
            } else {
                var object: CGPDFObjectRef?
                guard !CGPDFDictionaryGetObject(metrics, "W", &object) else { throw PDF239TextFailure.unsupported(.b299) }
            }
        } else {
            let first = try number(dict, "FirstChar"), last = try number(dict, "LastChar")
            guard first.rounded() == first, last.rounded() == last, first >= 0, last <= 255, last >= first,
                  CGPDFDictionaryGetArray(dict, "Widths", &array), let array = array,
                  CGPDFArrayGetCount(array) == Int(last - first + 1) else { throw PDF239TextFailure.unsupported(.b300) }
            for index in 0..<CGPDFArrayGetCount(array) {
                var value: CGPDFReal = 0
                guard CGPDFArrayGetNumber(array, index, &value) else { throw PDF239TextFailure.unsupported(.b301) }
                widths[Int(first) + index] = Double(value)
            }
            guard mapping.values.keys.allSatisfy({ widths[$0] != nil }) else { throw PDF239TextFailure.unsupported(.b302) }
        }
        let decoded = try PDF239TextFont(unicode: mapping.values, codeBytes: mapping.bytes, widths: widths,
            defaultWidth: composite ? number(metrics, "DW", fallback: 1000) : 0,
            ascent: number(descriptor, "Ascent"), descent: number(descriptor, "Descent"))
        fonts[key] = decoded
        try engine.font(decoded, size: size)
    }
}
#endif
