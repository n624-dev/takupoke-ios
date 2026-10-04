import Foundation
import CryptoKit
import UIKit
import Vision
import PDFKit

struct InputFixture: Decodable { var id: String; var pdfSha256: String }
struct Inputs: Decodable { var fixtures: [InputFixture] }
struct LineROI: Decodable { var id: String; var x: Int; var y: Int; var width: Int; var height: Int; var sourceRegion: String; var sourceNativeOrder: Int; var sourceConfidence: Double }
struct OriginalImage: Decodable { var width: Int; var height: Int; var bitsPerComponent: Int; var bitsPerPixel: Int; var bytesPerRow: Int; var bitmapInfoRawValue: UInt32; var alphaInfoRawValue: UInt32; var colorSpaceName: String; var colorSpaceModel: String; var colorSpaceComponents: Int; var shouldInterpolate: Bool }
struct LineManifest: Decodable { var fixture: String; var page: Int; var pdfSha256: String; var capturedRawSHA256: String; var originalPNG_SHA256: String; var originalRGBA_SHA256: String; var originalImage: OriginalImage; var requestCount: Int; var maxRequests: Int; var paddingPixels: Int; var rois: [LineROI] }

@main
struct TextLineProbe {
    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
        FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
    }
    static func sha(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func imageMetadata(_ image: CGImage) -> [String:Any] {
        ["width":image.width,"height":image.height,"bitsPerComponent":image.bitsPerComponent,
         "bitsPerPixel":image.bitsPerPixel,"bytesPerRow":image.bytesPerRow,
         "bitmapInfoRawValue":image.bitmapInfo.rawValue,"alphaInfoRawValue":image.alphaInfo.rawValue,
         "colorSpaceName":image.colorSpace?.name as String? ?? "unnamed",
         "colorSpaceModel":image.colorSpace.map { String(describing:$0.model) } ?? "missing",
         "colorSpaceComponents":image.colorSpace?.numberOfComponents ?? 0,
         "shouldInterpolate":image.shouldInterpolate]
    }
    static func png(_ image: CGImage) throws -> [String:Any] {
        guard let data = UIImage(cgImage:image).pngData(), data.count <= 4*1024*1024 else { throw NSError(domain:"BoundedPNG",code:1) }
        return ["encoding":"base64","bytes":data.count,"sha256":sha(data),"data":data.base64EncodedString()]
    }
    static func rect(_ b: CGRect, width: Int, height: Int, offsetX: Int, offsetY: Int) -> [String: Any] {
        let values = [Double(b.minX),Double(b.minY),Double(b.width),Double(b.height)]
        guard values.allSatisfy(\.isFinite) else { return ["finite":false] }
        let x=values[0]*Double(width), y=(1-Double(b.maxY))*Double(height), w=values[2]*Double(width), h=values[3]*Double(height)
        return ["finite":true,"normalizedLowerLeft":["x":values[0],"y":values[1],"width":values[2],"height":values[3]],
                "cropPixelTopLeft":["x":x,"y":y,"width":w,"height":h],
                "originalPixelTopLeft":["x":x+Double(offsetX),"y":y+Double(offsetY),"width":w,"height":h]]
    }
    @available(iOS 26.0, *)
    static func run(_ folder: URL) async throws {
        let inputs = try JSONDecoder().decode(Inputs.self,from:Data(contentsOf:folder.appendingPathComponent("inputs.json")))
        guard inputs.fixtures.count==2, let fixture=inputs.fixtures.first(where:{ $0.id=="independent-Timetable-literal-乙" }) else { throw NSError(domain:"SelectedOriginalInput",code:1) }
        let url=folder.appendingPathComponent(fixture.id+".pdf"), digest=sha(try Data(contentsOf:folder.appendingPathComponent(fixture.id+".pdf")))
        guard digest==fixture.pdfSha256, let document=PDFDocument(url:url), document.pageCount==5, !document.isLocked, let page=document.page(at:0) else { throw NSError(domain:"OriginalPDFChanged",code:1) }
        let image=try OriginalTextRaster.render(page,index:0)
        let manifestData=try Data(contentsOf:folder.appendingPathComponent("line-rois.json"))
        let manifest=try JSONDecoder().decode(LineManifest.self,from:manifestData)
        guard manifest.fixture==fixture.id, manifest.pdfSha256==digest, manifest.page==1,
              manifest.paddingPixels==2, manifest.maxRequests==16, manifest.requestCount==manifest.rois.count,
              (1...16).contains(manifest.rois.count), Set(manifest.rois.map(\.id)).count==manifest.rois.count else { throw NSError(domain:"FiniteROIManifest",code:1) }
        let expected=manifest.originalImage
        guard image.width==expected.width, image.height==expected.height, image.bitsPerComponent==expected.bitsPerComponent,
              image.bitsPerPixel==expected.bitsPerPixel, image.bytesPerRow==expected.bytesPerRow,
              image.bitmapInfo.rawValue==expected.bitmapInfoRawValue, image.alphaInfo.rawValue==expected.alphaInfoRawValue,
              (image.colorSpace?.name as String?) == expected.colorSpaceName,
              image.colorSpace.map({ String(describing:$0.model) })==expected.colorSpaceModel,
              image.colorSpace?.numberOfComponents==expected.colorSpaceComponents, image.shouldInterpolate==expected.shouldInterpolate,
              image.bitsPerComponent==8, image.bitsPerPixel==32, image.bitmapInfo.rawValue==8194,
              let provider=image.dataProvider, let data=provider.data else { throw NSError(domain:"OriginalCGFormatChanged",code:1) }
        // Verification only: original BGRA provider bytes are read into canonical
        // RGBA for comparison; the ORIGINAL CGImage still enters cropping/OCR.
        let originalBytes=Array(data as Data), stride=image.bytesPerRow
        guard originalBytes.count>=stride*image.height else { throw NSError(domain:"OriginalPixelBytesMissing",code:1) }
        var rgba=Data();rgba.reserveCapacity(image.width*image.height*4)
        for y in 0..<image.height { for x in 0..<image.width {
            let i=y*stride+x*4
            guard originalBytes[i+3]==255 else { throw NSError(domain:"OriginalOpacityChanged",code:1) }
            rgba.append(contentsOf:[originalBytes[i+2],originalBytes[i+1],originalBytes[i],originalBytes[i+3]])
        } }
        let originalPNG=try png(image), pixelSHA=sha(rgba)
        guard originalPNG["sha256"] as? String==manifest.originalPNG_SHA256, pixelSHA==manifest.originalRGBA_SHA256 else { throw NSError(domain:"OriginalRenderedPixelsChanged",code:1) }
        for roi in manifest.rois {
            guard roi.sourceConfidence.isFinite, roi.sourceConfidence>=0, roi.sourceConfidence<0.85,
                  roi.x>=0, roi.y>=0, roi.width>0, roi.height>0,
                  roi.width<=image.width, roi.height<=image.height,
                  roi.x<=image.width-roi.width, roi.y<=image.height-roi.height else { throw NSError(domain:"ROIOutsideOriginal",code:1) }
        }
        var configuration=RecognizeTextRequest()
        configuration.recognitionLevel = .accurate
        configuration.recognitionLanguages = [Locale.Language(identifier:"ja-JP"),Locale.Language(identifier:"en-US")]
        configuration.usesLanguageCorrection = false; configuration.automaticallyDetectsLanguage = false; configuration.customWords = []
        guard Double(configuration.minimumTextHeightFraction)==0.03125 else { throw NSError(domain:"MinimumTextHeightChanged",code:1) }
        let supported=configuration.supportedRecognitionLanguages.map(\.minimalIdentifier)
        guard configuration.recognitionLanguages.allSatisfy({ supported.contains($0.minimalIdentifier) }) else { throw NSError(domain:"RequestedLanguageUnsupported",code:1) }
        try emit(["type":"environment","scope":"Captured low-confidence line component diagnostic only; no full-page OCR or formal recovery qualification","api":"RecognizeTextRequest","revision":String(describing:configuration.revision),"os":ProcessInfo.processInfo.operatingSystemVersionString,"deviceSystemVersion":UIDevice.current.systemVersion,"simulator":true,"fixture":fixture.id,"pdfSHA256":digest,"page":1,"plannedRegions":manifest.rois.count,"recognitionLevel":"accurate","recognitionLanguages":["ja-JP","en-US"],"supportedRecognitionLanguages":supported,"usesLanguageCorrection":false,"automaticallyDetectsLanguage":false,"customWords":[],"minimumTextHeightFraction":Double(configuration.minimumTextHeightFraction),"confidenceCrossAPICalibrationAssumed":false,"confidenceGuard":"Post-observation only: finite and 0.85...1, unchanged","originalImage":imageMetadata(image),"originalPNG":originalPNG,"originalRGBA_SHA256":pixelSHA,"originalPNGAndPixelsMatchCaptured":true,"roiManifestSHA256":sha(manifestData),"capturedRawSHA256":manifest.capturedRawSHA256,"cropRule":"Captured low-confidence observation bounds, floor(min)-2 / ceil(max)+2 clipped to original; CGImage.cropping without resizing","inverseRule":"Original top-left x/y = crop top-left x/y + offsetX/Y","rangeBoxPrecisionAssumed":false])
        var requests=0, returned=0, complete=0, failed=0
        for roi in manifest.rois {
            let name=roi.id, offsetX=roi.x, offsetY=roi.y, width=roi.width, height=roi.height
            let started=Date()
            var record:[String:Any]=["type":"region","fixture":fixture.id,"pdfSHA256":digest,"page":1,"region":name,"offsetX":offsetX,"offsetY":offsetY,"cropWidth":width,"cropHeight":height,"sourceRegion":roi.sourceRegion,"sourceNativeOrder":roi.sourceNativeOrder,"sourceConfidence":roi.sourceConfidence,"requestAttempted":false,"readReturned":false,"serializationCompleted":false,"formalEvaluation":"unassessed"]
            do {
                let bounds=CGRect(x:CGFloat(offsetX),y:CGFloat(offsetY),width:CGFloat(width),height:CGFloat(height))
                guard let crop=image.cropping(to:bounds), crop.width==width, crop.height==height else { throw NSError(domain:"LosslessCropFailed",code:1) }
                record["cropImage"]=imageMetadata(crop); record["cropPNG"]=try png(crop)
                var request=configuration;requests += 1;record["requestAttempted"]=true
                let observations=try await request.perform(on:crop); returned += 1;record["readReturned"]=true
                guard observations.count<=1000 else { throw NSError(domain:"OriginalObservationLimit",code:1) }
                var lines=[[String:Any]](),failures=[String](),characters=0
                for (index,observation) in observations.enumerated() {
                    guard let candidate=observation.topCandidates(1).first else { lines.append(["nativeOrder":index,"candidateMissing":true]); failures.append("candidateMissing");continue }
                    let text=candidate.string,confidence=Double(candidate.confidence),good=confidence.isFinite && confidence>=0.85 && confidence<=1
                    if !good { failures.append("lineConfidence") }
                    var boxes=[[String:Any]]()
                    for start in text.indices {
                        characters += 1;guard characters<=100000 else { throw NSError(domain:"OriginalGlyphLimit",code:1) }
                        let end=text.index(after:start)
                        var box:[String:Any]=["text":String(text[start..<end]),"rangeUnit":"Swift Character","utf16Start":start.utf16Offset(in:text),"utf16End":end.utf16Offset(in:text)]
                        if let rectangle=candidate.boundingBox(for:start..<end) {
                            let b=rectangle.boundingBox.cgRect
                            box.merge(rect(b,width:crop.width,height:crop.height,offsetX:offsetX,offsetY:offsetY)) { _,new in new }
                            let x=b.minX*CGFloat(crop.width),y=(1-b.maxY)*CGFloat(crop.height),w=b.width*CGFloat(crop.width),h=b.height*CGFloat(crop.height)
                            let valid=w>0 && h>0 && x+CGFloat(offsetX)>=0 && y+CGFloat(offsetY)>=0
                            box["cropLocalCharacterPredicate"]=w>0 && h>0 && x>=0 && y>=0
                            box["originalLayoutsCharacterPredicate"]=valid
                            if !valid { failures.append("characterRectangle") }
                        } else { box["missing"]=true;failures.append("characterBoundingBoxMissing") }
                        boxes.append(box)
                    }
                    lines.append(["nativeOrder":index,"rawText":text,"confidence":confidence.isFinite ? confidence as Any : NSNull(),"passesOriginalConfidencePredicate":good,"observationBox":rect(observation.boundingBox.cgRect,width:crop.width,height:crop.height,offsetX:offsetX,offsetY:offsetY),"characters":boxes])
                }
                record["lines"]=lines;record["observations"]=observations.count;record["characterCount"]=characters;record["diagnosticFailures"]=failures
                record["originalLayoutsDiagnosticPredicatesPass"]=failures.isEmpty;record["diagnosticComplete"]=true;record["serializationCompleted"]=true;complete += 1
            } catch { failed += 1;record["operationalError"]=String(describing:error) }
            record["seconds"]=Date().timeIntervalSince(started);try emit(record)
        }
        try emit(["type":"summary","plannedRegions":manifest.rois.count,"requestCount":requests,"readReturnedRegions":returned,"diagnosticCompletedRegions":complete,"serializationCompletedRegions":complete,"operationalErrors":failed,"formalAssessed":0,"qualityQualification":false])
        guard requests==manifest.rois.count else { throw NSError(domain:"IncompleteFiniteDiagnostic",code:1) }
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count==2 else { throw NSError(domain:"Arguments",code:1) }
            if #available(iOS 26.0,*) { try await run(URL(fileURLWithPath:CommandLine.arguments[1])) } else { throw NSError(domain:"UnsupportedSimulator",code:1) }
        } catch { try? emit(["type":"fatal","operationalError":String(describing:error),"qualityQualification":false]);exit(1) }
    }
}
