import Foundation
import Vision
import ImageIO
import CryptoKit

// Recognizer-only study. No oracle, expected text, app or parser code is read.
@main struct LegacyLineScreen {
    struct Failure: Error {}
    static func require<T>(_ value: T?) throws -> T {
        guard let value else { throw Failure() }; return value
    }
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func box(_ rect: CGRect) -> [Double] {
        [Double(rect.origin.x), Double(rect.origin.y), Double(rect.width), Double(rect.height)]
    }
    static func originalBox(_ rect: CGRect, width: Int, height: Int) -> [Double] {
        // VN's original normalized bottom-left rectangle, mapped to source pixels.
        [Double(rect.minX)*Double(width), (1-Double(rect.maxY))*Double(height),
         Double(rect.width)*Double(width), Double(rect.height)*Double(height)]
    }
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw Failure() }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let manifest = try require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("frames.json"))) as? [String:Any])
        let all = try require(manifest["frames"] as? [[String:Any]])
        guard all.count == 288 else { throw Failure() }
        let frames = all.filter { $0["frame"] as? String == "observed-ink-margin-2" }
        guard frames.count == 144, Set(frames.compactMap { $0["id"] as? String }).count == 144 else { throw Failure() }
        // Configuration failure is a preflight failure, before any OCR call.
        let preflight = VNRecognizeTextRequest()
        preflight.revision = VNRecognizeTextRequestRevision3
        preflight.recognitionLevel = .accurate
        let supported = try preflight.supportedRecognitionLanguages()
        guard ["ja-JP","en-US"].allSatisfy({ supported.contains($0) }) else { throw Failure() }
        var records = [[String:Any]]()
        for frame in frames {
            let id = try require(frame["id"] as? String), name = try require(frame["file"] as? String)
            let expectedHash = try require(frame["sha256"] as? String)
            guard name == id+"-observed-ink-margin-2.png", !name.contains("/"), !name.contains("..") else { throw Failure() }
            let data = try Data(contentsOf: root.appendingPathComponent(name))
            guard hash(data) == expectedHash else { throw Failure() }
            let source = try require(CGImageSourceCreateWithData(data as CFData,nil))
            let image = try require(CGImageSourceCreateImageAtIndex(source,0,nil))
            let w = image.width, h = image.height
            guard w > 0, h > 0, w <= 2048, h <= 2048 else { throw Failure() }
            let color = CGColorSpaceCreateDeviceRGB()
            let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(.byteOrder32Big)
            var original = [UInt8](repeating:255,count:w*h*4)
            try original.withUnsafeMutableBytes { buffer in
                let context = try require(CGContext(data:buffer.baseAddress,width:w,height:h,bitsPerComponent:8,
                    bytesPerRow:w*4,space:color,bitmapInfo:info.rawValue))
                context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
            }
            guard stride(from:3,to:original.count,by:4).allSatisfy({ original[$0] == 255 }) else { throw Failure() }
            for factor in [1,4] {
                let record: [String:Any] = try autoreleasepool {
                    let sw = w*factor, sh = h*factor
                    var scaled = [UInt8](repeating:0,count:sw*sh*4)
                    for y in 0..<sh { for x in 0..<sw {
                        let a = ((y/factor)*w+x/factor)*4, b = (y*sw+x)*4
                        for channel in 0..<4 { scaled[b+channel] = original[a+channel] }
                    } }
                    let pixelData = Data(scaled), provider = try require(CGDataProvider(data:pixelData as CFData))
                    let input = try require(CGImage(width:sw,height:sh,bitsPerComponent:8,bitsPerPixel:32,
                        bytesPerRow:sw*4,space:color,bitmapInfo:info,provider:provider,decode:nil,
                        shouldInterpolate:false,intent:.defaultIntent))
                    let readback = try require(input.dataProvider?.data) as Data
                    guard readback == pixelData else { throw Failure() }
                    // Independently read every actual image pixel back before the API call.
                    let bytes = [UInt8](readback)
                    for y in 0..<sh { for x in 0..<sw { for channel in 0..<4 {
                        guard bytes[(y*sw+x)*4+channel] == original[((y/factor)*w+x/factor)*4+channel] else { throw Failure() }
                    } } }
                    let request = VNRecognizeTextRequest()
                    request.revision = VNRecognizeTextRequestRevision3
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["ja-JP","en-US"]
                    request.automaticallyDetectsLanguage = false
                    request.usesLanguageCorrection = false
                    request.minimumTextHeight = 0
                    request.customWords = []
                    var record: [String:Any] = ["id":id,"factor":factor,"sourceImageSHA256":expectedHash,
                        "sourceRGBAHash":hash(Data(original)),"inputRGBAHash":hash(pixelData),
                        "sourceWidth":w,"sourceHeight":h,"inputWidth":sw,"inputHeight":sh,
                        "everyScaledPixelVerified":true,"revision":request.revision,
                        "languages":request.recognitionLanguages,"usesLanguageCorrection":false]
                    let started = Date()
                    do {
                        try VNImageRequestHandler(cgImage:input,options:[:]).perform([request])
                    } catch {
                        let error = error as NSError
                        record["state"] = "nativeError"; record["errorDomain"] = error.domain; record["errorCode"] = error.code
                    }
                    if record["state"] as? String != "nativeError" {
                        record["state"] = "recognized"
                        var geometryErrors = 0
                        record["observations"] = (request.results ?? []).map { observation -> [String:Any] in
                            let candidates = observation.topCandidates(5).map { candidate -> [String:Any] in
                                let characters = candidate.string.indices.map { index -> [String:Any] in
                                    let end = candidate.string.index(after:index)
                                    let range = index..<end
                                    var atom: [String:Any] = ["text":String(candidate.string[range])]
                                    do {
                                        if let rect = try candidate.boundingBox(for:range)?.boundingBox {
                                            atom["nativeNormalizedBox"] = box(rect); atom["sourceBox"] = originalBox(rect,width:w,height:h)
                                        }
                                    } catch {
                                        let error = error as NSError
                                        atom["mappingErrorDomain"] = error.domain; atom["mappingErrorCode"] = error.code
                                        geometryErrors += 1
                                    }
                                    return atom
                                }
                                return ["text":candidate.string,"confidence":Double(candidate.confidence),"characters":characters]
                            }
                            return ["nativeNormalizedBox":box(observation.boundingBox),
                                "sourceBox":originalBox(observation.boundingBox,width:w,height:h),"candidates":candidates]
                        }
                        // A geometry error retains all raw recognition, and still fails the study.
                        record["characterMappingErrors"] = geometryErrors
                    }
                    record["seconds"] = Date().timeIntervalSince(started)
                    return record
                }
                records.append(record)
            }
        }
        guard records.count == 288 else { throw Failure() }
        let output = root.appendingPathComponent("legacy-lines.json")
        let result = try JSONSerialization.data(withJSONObject:["records":records,"actualCalls":records.count,
            "os":ProcessInfo.processInfo.operatingSystemVersionString],options:.sortedKeys)
        try result.write(to:output,options:.withoutOverwriting)
        print("LEGACY_LINE_CAPTURE_FINISHED actualCalls=\(records.count)")
    }
}
