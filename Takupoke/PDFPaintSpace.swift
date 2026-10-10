import Foundation
#if canImport(CoreGraphics)
import CoreGraphics

/// Color conversion certifies paint against the supported white page background;
/// it does not decode glyphs or supply Unicode evidence.
struct PDFPaintSpace {
    let count: Int
    let space: CGColorSpace?
    let device: Bool
    private let definition: String
    private let profile: Data?
    private final class Samples { var values = [String:Double]() }
    private let samples = Samples()
    init(count: Int, space: CGColorSpace?, device: Bool = false, definition: String = "", profile: Data? = nil) {
        self.count = count; self.space = space; self.device = device
        self.definition = definition; self.profile = profile
    }
    static func device(_ count: Int) -> PDFPaintSpace {
        switch count {
        case 1: return PDFPaintSpace(count:1,space:CGColorSpaceCreateDeviceGray(),device:true,definition:"/DeviceGray")
        case 3: return PDFPaintSpace(count:3,space:CGColorSpaceCreateDeviceRGB(),device:true,definition:"/DeviceRGB")
        case 4: return PDFPaintSpace(count:4,space:CGColorSpaceCreateDeviceCMYK(),device:true,definition:"/DeviceCMYK")
        default: return PDFPaintSpace(count:0,space:nil)
        }
    }
    func brightness(_ values: [Double], intent: CGColorRenderingIntent) -> Double? {
        guard space != nil, !definition.isEmpty, values.count == count else { return nil }
        let key = String(intent.rawValue) + ":" + values.map { String($0) }.joined(separator:",")
        if let sample = samples.values[key] { return sample }
        let sample = PDFPaintSample.brightness(definition:definition,profile:profile,count:count,values:values,intent:intent)
        if let sample, samples.values.count < 256 { samples.values[key] = sample }
        return sample
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
        case "DeviceGray": return .device(1)
        case "DeviceRGB": return .device(3)
        case "DeviceCMYK": return .device(4)
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
            guard let dictionary = CGPDFStreamGetDictionary(stream) else { return unsupported }
            var count: CGPDFInteger = 0, length: CGPDFInteger = 0
            guard CGPDFDictionaryGetInteger(dictionary,"N",&count), [1,3,4].contains(Int(count)) else { return unsupported }
            let invalid = PDFPaintSpace(count:Int(count),space:nil)
            // A nondefault Range can turn apparently dark component values
            // into white. Do not certify a profile after dropping that setting.
            var rangeObject: CGPDFObjectRef?, alternateObject: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,"Range",&rangeObject) {
                guard let range = vector(dictionary,"Range",count:2*Int(count)),
                      range.enumerated().allSatisfy({ $0.element == ($0.offset % 2 == 0 ? 0 : 1) }) else { return invalid }
            }
            if CGPDFDictionaryGetObject(dictionary,"Alternate",&alternateObject) {
                var name: UnsafePointer<CChar>?
                let expected = count == 1 ? "DeviceGray" : count == 3 ? "DeviceRGB" : "DeviceCMYK"
                guard CGPDFDictionaryGetName(dictionary,"Alternate",&name), let name,
                      String(cString:name) == expected else { return invalid }
            }
            guard CGPDFDictionaryGetInteger(dictionary,"Length",&length), length > 0 else { return invalid }
            guard length <= 1_048_576 else { throw PDFParseError(code:.limit) }
            var format = CGPDFDataFormat.raw
            guard let data = CGPDFStreamCopyData(stream,&format), format == .raw else { return invalid }
            let bytes = CFDataGetLength(data)
            guard bytes <= 1_048_576, profileBytes <= 4_194_304 - bytes else { throw PDFParseError(code:.limit) }
            profileBytes += bytes
            guard let space = CGColorSpace(iccData:data), space.numberOfComponents == Int(count) else { return invalid }
            return PDFPaintSpace(count:Int(count),space:space,definition:"[/ICCBased 5 0 R]",profile:data as Data)
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
                let definition = "[/CalRGB << /WhitePoint \(literal(white)) /BlackPoint \(literal(black)) /Gamma \(literal(gamma)) /Matrix \(literal(matrix)) >>]"
                return PDFPaintSpace(count:3,space:CGColorSpace(calibratedRGBWhitePoint:white,
                    blackPoint:black,gamma:gamma,matrix:matrix),definition:definition)
            }
            var gamma: CGPDFReal = 1, object: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,"Gamma",&object) {
                guard CGPDFDictionaryGetNumber(dictionary,"Gamma",&gamma), gamma.isFinite, gamma > 0 else { return invalid }
            }
            let definition = "[/CalGray << /WhitePoint \(literal(white)) /BlackPoint \(literal(black)) /Gamma \(PDFPaintNumber.literal(Double(gamma))) >>]"
            return PDFPaintSpace(count:1,space:CGColorSpace(calibratedGrayWhitePoint:white,blackPoint:black,gamma:gamma),definition:definition)
        default: return unsupported
        }
    }
    private func literal(_ values: [CGFloat]) -> String {
        "[" + values.map { PDFPaintNumber.literal(Double($0)) }.joined(separator:" ") + "]"
    }
}
#endif
