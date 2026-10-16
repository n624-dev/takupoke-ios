import Foundation
import Vision
import CoreGraphics
import CryptoKit

// Research only. Reads original numbered RGB8 and hashes, never an oracle.
@main struct OriginalCodeEnglish {
    struct Failure: Error {}
    static func require<T>(_ value:T?) throws -> T { guard let value else { throw Failure() }; return value }
    static func hash(_ data:Data)->String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func box(_ r:CGRect)->[Double] { [Double(r.origin.x),Double(r.origin.y),Double(r.width),Double(r.height)] }
    static func pixels(_ r:CGRect,_ w:Int,_ h:Int)->[Double] {
        [Double(r.minX)*Double(w),(1-Double(r.maxY))*Double(h),Double(r.width)*Double(w),Double(r.height)*Double(h)]
    }
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw Failure() }
        let root = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let manifest = try require(JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("inputs.json"))) as? [String:Any])
        let frames = try require(manifest["frames"] as? [[String:Any]])
        guard Set(manifest.keys) == ["frames"], frames.count == 192 else { throw Failure() }
        let preflight = VNRecognizeTextRequest(); preflight.revision = VNRecognizeTextRequestRevision3; preflight.recognitionLevel = .accurate
        guard try preflight.supportedRecognitionLanguages().contains("en-US") else { throw Failure() }
        var records = [[String:Any]]()
        for (index,frame) in frames.enumerated() {
            let row: [String:Any] = try autoreleasepool {
                let id = String(format:"code-%04d",index)
                let name = try require(frame["rgb"] as? String), digest = try require(frame["rgbSHA256"] as? String)
                let w = try require(frame["width"] as? Int), h = try require(frame["height"] as? Int)
                guard Set(frame.keys) == ["id","rgb","rgbSHA256","width","height"], frame["id"] as? String == id,
                      name == id+".rgb", 1...2048 ~= w, 1...2048 ~= h else { throw Failure() }
                let data = try Data(contentsOf:root.appendingPathComponent(name))
                guard data.count == w*h*3, hash(data) == digest else { throw Failure() }
                let provider = try require(CGDataProvider(data:data as CFData))
                let image = try require(CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:24,bytesPerRow:w*3,
                    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:provider,
                    decode:nil,shouldInterpolate:false,intent:.defaultIntent))
                let readback = try require(image.dataProvider?.data) as Data
                guard readback == data, image.width == w, image.height == h else { throw Failure() }
                let request = VNRecognizeTextRequest()
                request.revision = VNRecognizeTextRequestRevision3; request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]; request.automaticallyDetectsLanguage = false
                request.usesLanguageCorrection = false; request.minimumTextHeight = 0; request.customWords = []
                var record: [String:Any] = ["id":id,"width":w,"height":h,"sourceRGBSHA256":digest,
                    "actualRGBSHA256":hash(readback),"originalPixelsReadbackVerified":true,"revision":request.revision,
                    "languages":request.recognitionLanguages,"usesLanguageCorrection":request.usesLanguageCorrection,
                    "recognitionLevel":request.recognitionLevel == .accurate ? "accurate" : "fast",
                    "automaticLanguageDetection":request.automaticallyDetectsLanguage,
                    "minimumTextHeight":Double(request.minimumTextHeight),"customWords":[] as [String]]
                let started = ProcessInfo.processInfo.systemUptime
                do { try VNImageRequestHandler(cgImage:image,options:[:]).perform([request]) }
                catch {
                    let error = error as NSError
                    record["state"] = "nativeError"; record["errorDomain"] = error.domain; record["errorCode"] = error.code
                }
                if record["state"] as? String != "nativeError" {
                    var geometryErrors = 0
                    record["state"] = "recognized"
                    record["observations"] = (request.results ?? []).map { observation -> [String:Any] in
                        let candidates = observation.topCandidates(5).map { candidate -> [String:Any] in
                            let characters = candidate.string.indices.map { i -> [String:Any] in
                                let range = i..<candidate.string.index(after:i)
                                var atom: [String:Any] = ["text":String(candidate.string[range])]
                                do {
                                    if let r = try candidate.boundingBox(for:range)?.boundingBox {
                                        atom["nativeNormalizedBox"] = box(r); atom["sourceBox"] = pixels(r,w,h)
                                    }
                                } catch {
                                    let error = error as NSError
                                    atom["mappingErrorDomain"] = error.domain; atom["mappingErrorCode"] = error.code; geometryErrors += 1
                                }
                                return atom
                            }
                            return ["text":candidate.string,"confidence":Double(candidate.confidence),"characters":characters]
                        }
                        return ["nativeNormalizedBox":box(observation.boundingBox),"sourceBox":pixels(observation.boundingBox,w,h),"candidates":candidates]
                    }
                    record["characterMappingErrors"] = geometryErrors
                }
                record["seconds"] = ProcessInfo.processInfo.systemUptime-started
                return record
            }
            records.append(row)
        }
        guard records.count == 192 else { throw Failure() }
        let data = try JSONSerialization.data(withJSONObject:["actualCalls":records.count,"records":records,
            "os":ProcessInfo.processInfo.operatingSystemVersionString],options:.sortedKeys)
        try data.write(to:root.appendingPathComponent("native.json"),options:.withoutOverwriting)
        print("CODE_ENGLISH_NATIVE_FINISHED actualCalls=192")
    }
}
