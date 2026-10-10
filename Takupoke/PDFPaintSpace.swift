import Foundation
#if canImport(CoreGraphics)
import CoreGraphics

/// Color conversion certifies paint against the supported white page background;
/// it does not decode glyphs or supply Unicode evidence.
struct PDFPaintSpace {
    let count: Int
    let space: CGColorSpace?
    var device = false
    func rgb(_ values: [Double]) -> [Double]? {
        guard let space, values.count == count,
              let color = CGColor(colorSpace: space, components: values.map(CGFloat.init) + [1]),
              let converted = color.converted(to: CGColorSpaceCreateDeviceRGB(),
                  intent: .relativeColorimetric, options: nil),
              let components = converted.components, components.count == 4,
              components.allSatisfy({ $0.isFinite }), components[3] == 1 else { return nil }
        return components.prefix(3).map { min(1,max(0,Double($0))) }
    }
}

final class PDFPaintSpaceResolver {
    private var cache = [String:PDFPaintSpace]()
    private var profileBytes = 0
    func deviceDefault(_ scanner: CGPDFScannerRef, count: Int) throws -> PDFPaintSpace? {
        let key = count == 1 ? "DefaultGray" : count == 3 ? "DefaultRGB" : "DefaultCMYK"
        guard CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner),"ColorSpace",key) != nil else { return nil }
        let result = try named(scanner,name:key)
        if result.device && result.count == count { return nil }
        return result.count == count ? result : PDFPaintSpace(count:count,space:nil)
    }
    func named(_ scanner: CGPDFScannerRef, name: String, visited: Set<String> = []) throws -> PDFPaintSpace {
        guard visited.count < 8, !visited.contains(name) else { return PDFPaintSpace(count:0,space:nil) }
        switch name {
        case "DeviceGray": return PDFPaintSpace(count:1,space:CGColorSpaceCreateDeviceGray(),device:true)
        case "DeviceRGB": return PDFPaintSpace(count:3,space:CGColorSpaceCreateDeviceRGB(),device:true)
        case "DeviceCMYK": return PDFPaintSpace(count:4,space:CGColorSpaceCreateDeviceCMYK(),device:true)
        default: break
        }
        if let result = cache[name] { return result }
        guard cache.count < 128 else { throw PDFParseError(code:.limit) }
        guard let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner),"ColorSpace",name) else {
            throw PDFParseError(code:.unsupported,stage:.paintVisibility)
        }
        var next = visited; next.insert(name)
        var alias: UnsafePointer<CChar>?, array: CGPDFArrayRef?
        let result: PDFPaintSpace
        if CGPDFObjectGetValue(object,.name,&alias), let alias {
            result = try named(scanner,name:String(cString:alias),visited:next)
        } else if CGPDFObjectGetValue(object,.array,&array), let array {
            result = try resolve(array)
        } else { result = PDFPaintSpace(count:0,space:nil) }
        cache[name] = result
        return result
    }
    private func vector(_ dictionary: CGPDFDictionaryRef, _ key: String, count: Int,
                        fallback: [CGFloat]? = nil) -> [CGFloat]? {
        var object: CGPDFObjectRef?, array: CGPDFArrayRef?
        guard CGPDFDictionaryGetObject(dictionary,key,&object) else { return fallback }
        guard CGPDFDictionaryGetArray(dictionary,key,&array), let array, CGPDFArrayGetCount(array) == count else { return nil }
        var values = [CGFloat]()
        for index in 0..<count {
            var number: CGPDFReal = 0
            guard CGPDFArrayGetNumber(array,index,&number), number.isFinite else { return nil }
            values.append(number)
        }
        return values
    }
    private func resolve(_ array: CGPDFArrayRef) throws -> PDFPaintSpace {
        let unsupported = PDFPaintSpace(count:0,space:nil)
        var name: UnsafePointer<CChar>?
        guard CGPDFArrayGetCount(array) == 2, CGPDFArrayGetName(array,0,&name), let name else { return unsupported }
        switch String(cString:name) {
        case "ICCBased":
            var stream: CGPDFStreamRef?
            guard CGPDFArrayGetStream(array,1,&stream), let stream else { return unsupported }
            let dictionary = CGPDFStreamGetDictionary(stream)
            var count: CGPDFInteger = 0, length: CGPDFInteger = 0
            guard CGPDFDictionaryGetInteger(dictionary,"N",&count), [1,3,4].contains(Int(count)) else { return unsupported }
            let invalid = PDFPaintSpace(count:Int(count),space:nil)
            guard CGPDFDictionaryGetInteger(dictionary,"Length",&length), length > 0 else { return invalid }
            guard length <= 1_048_576 else { throw PDFParseError(code:.limit) }
            var format = CGPDFDataFormat.raw
            guard let data = CGPDFStreamCopyData(stream,&format), format == .raw else { return invalid }
            let bytes = CFDataGetLength(data)
            guard bytes <= 1_048_576, profileBytes <= 4_194_304 - bytes else { throw PDFParseError(code:.limit) }
            profileBytes += bytes
            guard let space = CGColorSpace(iccData:data), space.numberOfComponents == Int(count) else { return invalid }
            return PDFPaintSpace(count:Int(count),space:space)
        case "CalRGB", "CalGray":
            let rgb = String(cString:name) == "CalRGB", count = rgb ? 3 : 1
            let invalid = PDFPaintSpace(count:count,space:nil)
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFArrayGetDictionary(array,1,&dictionary), let dictionary,
                  let white = vector(dictionary,"WhitePoint",count:3), white[0] > 0, white[1] == 1, white[2] > 0,
                  let black = vector(dictionary,"BlackPoint",count:3,fallback:[0,0,0]),
                  black.allSatisfy({ $0 >= 0 }) else { return invalid }
            if rgb {
                guard let gamma = vector(dictionary,"Gamma",count:3,fallback:[1,1,1]), gamma.allSatisfy({ $0 > 0 }),
                      let matrix = vector(dictionary,"Matrix",count:9,fallback:[1,0,0,0,1,0,0,0,1]) else { return invalid }
                return PDFPaintSpace(count:3,space:CGColorSpace(calibratedRGBWhitePoint:white,
                    blackPoint:black,gamma:gamma,matrix:matrix))
            }
            var gamma: CGPDFReal = 1, object: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,"Gamma",&object) {
                guard CGPDFDictionaryGetNumber(dictionary,"Gamma",&gamma), gamma.isFinite, gamma > 0 else { return invalid }
            }
            return PDFPaintSpace(count:1,space:CGColorSpace(calibratedGrayWhitePoint:white,blackPoint:black,gamma:gamma))
        default: return unsupported
        }
    }
}
#endif
