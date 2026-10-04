import Foundation
import CryptoKit
import UIKit
import Vision
import PDFKit

struct InputPage: Decodable { var page: Int }
struct InputFixture: Decodable { var id: String; var pdfSha256: String; var pages: [InputPage] }
struct Inputs: Decodable { var fixtures: [InputFixture] }

@main
struct TextOCRProbe {
    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
        FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
    }
    static func sha(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func rect(_ b: CGRect, width: Int, height: Int) -> [String: Any] {
        let v = [Double(b.minX), Double(b.minY), Double(b.width), Double(b.height)]
        guard v.allSatisfy(\.isFinite) else { return ["finite":false] }
        return ["finite":true,"normalizedLowerLeft":["x":v[0],"y":v[1],"width":v[2],"height":v[3]],
                "pixelTopLeft":["x":v[0]*Double(width),"y":(1-Double(b.maxY))*Double(height),"width":v[2]*Double(width),"height":v[3]*Double(height)]]
    }
    @available(iOS 26.0, *)
    static func run(_ folder: URL) async throws {
        let inputs = try JSONDecoder().decode(Inputs.self,from:Data(contentsOf:folder.appendingPathComponent("inputs.json")))
        guard inputs.fixtures.count == 2, inputs.fixtures.allSatisfy({ $0.pages.map(\.page) == [1,2,3,4,5] }) else { throw NSError(domain:"ProbeInput",code:1) }
        var configuration = RecognizeTextRequest()
        configuration.recognitionLevel = .accurate
        configuration.recognitionLanguages = [Locale.Language(identifier:"ja-JP"),Locale.Language(identifier:"en-US")]
        configuration.usesLanguageCorrection = false
        configuration.automaticallyDetectsLanguage = false
        configuration.customWords = []
        let supported = configuration.supportedRecognitionLanguages.map(\.minimalIdentifier)
        guard configuration.recognitionLanguages.allSatisfy({ supported.contains($0.minimalIdentifier) }) else { throw NSError(domain:"RequestedLanguageUnsupported",code:1) }
        try emit(["type":"environment","scope":"ordinary accurate text OCR only; no formal recovery qualification", "api":"RecognizeTextRequest","revision":String(describing:configuration.revision),"os":ProcessInfo.processInfo.operatingSystemVersionString,"deviceSystemVersion":UIDevice.current.systemVersion,"simulator":true,"plannedPages":10,"recognitionLevel":"accurate","recognitionLanguages":["ja-JP","en-US"],"supportedRecognitionLanguages":supported,"usesLanguageCorrection":false,"automaticallyDetectsLanguage":false,"customWords":[],"rasterRoute":"Exact original.read fractional thumbnail statements; same CGImage encoded to PNG before OCR and passed once","confidenceGuard":"post-observation diagnostic only: finite and 0.85...1","rangeBoxContract":"Unmodified API per-Character range responses; precision is not assumed; accurate APIs may return whole word boxes","inkCoverageVerified":false])
        var completed = 0, failed = 0, requestCount = 0
        for fixture in inputs.fixtures {
            let url = folder.appendingPathComponent(fixture.id + ".pdf")
            let digest = sha(try Data(contentsOf:url))
            guard digest == fixture.pdfSha256, let document = PDFDocument(url:url), !document.isLocked, document.pageCount == 5 else { throw NSError(domain:"OriginalPDFChanged",code:1) }
            for pageNumber in 1...5 {
                let started = Date()
                var record: [String:Any] = ["type":"page","fixture":fixture.id,"pdfSHA256":digest,"page":pageNumber,"readReturned":false,"serializationCompleted":false,"formalEvaluation":"unassessed"]
                do {
                    guard let page = document.page(at:pageNumber-1) else { throw NSError(domain:"MissingPage",code:1) }
                    let raster = try OriginalTextRaster.render(page,index:pageNumber-1)
                    let width = raster.width, height = raster.height
                    guard let png = UIImage(cgImage:raster).pngData(), png.count <= 4*1024*1024 else { throw NSError(domain:"BoundedRasterPNG",code:1) }
                    record["width"] = width; record["height"] = height
                    record["renderPNG"] = ["encoding":"base64","bytes":png.count,"sha256":sha(png),"data":png.base64EncodedString(),"source":"Same CGImage sent to OCR; lossless PNG before recognition"]
                    var request = configuration
                    requestCount += 1
                    let observations = try await request.perform(on:raster)
                    record["readReturned"] = true
                    guard observations.count <= 1000 else { throw NSError(domain:"OriginalObservationLimit",code:1) }
                    var lines = [[String:Any]](), diagnosticFailures = [String](), characterCount = 0
                    for (index,observation) in observations.enumerated() {
                        guard let candidate = observation.topCandidates(1).first else {
                            lines.append(["nativeOrder":index,"candidateMissing":true]); diagnosticFailures.append("candidateMissing"); continue
                        }
                        let confidence = Double(candidate.confidence), text = candidate.string
                        let good = confidence.isFinite && confidence >= 0.85 && confidence <= 1
                        if !good { diagnosticFailures.append("lineConfidence") }
                        var boxes = [[String:Any]]()
                        for start in text.indices {
                            characterCount += 1
                            guard characterCount <= 100000 else { throw NSError(domain:"OriginalGlyphLimit",code:1) }
                            let end = text.index(after:start)
                            var box: [String:Any] = ["text":String(text[start..<end]),"rangeUnit":"Swift Character","utf16Start":start.utf16Offset(in:text),"utf16End":end.utf16Offset(in:text)]
                            if let rectangle = candidate.boundingBox(for:start..<end) {
                                let b = rectangle.boundingBox.cgRect
                                box.merge(rect(b,width:width,height:height)) { _,new in new }
                                let x = b.minX*CGFloat(width), y = (1-b.maxY)*CGFloat(height), w = b.width*CGFloat(width), h = b.height*CGFloat(height)
                                let valid = w > 0 && h > 0 && x >= 0 && y >= 0
                                box["originalLayoutsCharacterPredicate"] = valid
                                if !valid { diagnosticFailures.append("characterRectangle") }
                            } else { box["missing"] = true; diagnosticFailures.append("characterBoundingBoxMissing") }
                            boxes.append(box)
                        }
                        lines.append(["nativeOrder":index,"rawText":text,"confidence":confidence.isFinite ? confidence as Any : NSNull(),"passesOriginalConfidencePredicate":good,"observationBox":rect(observation.boundingBox.cgRect,width:width,height:height),"characters":boxes])
                    }
                    record["lines"] = lines; record["observations"] = observations.count; record["characterCount"] = characterCount
                    record["diagnosticFailures"] = diagnosticFailures
                    record["originalLayoutsDiagnosticPredicatesPass"] = diagnosticFailures.isEmpty
                    record["diagnosticComplete"] = true; record["serializationCompleted"] = true
                    completed += 1
                } catch { failed += 1; record["operationalError"] = String(describing:error) }
                record["seconds"] = Date().timeIntervalSince(started)
                try emit(record)
            }
        }
        try emit(["type":"summary","plannedPages":10,"requestCount":requestCount,"diagnosticCompletedPages":completed,"serializationCompletedPages":completed,"operationalErrors":failed,"formalAssessed":0,"qualityQualification":false])
        guard requestCount == 10 else { throw NSError(domain:"IncompleteFiniteDiagnostic",code:1) }
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else { throw NSError(domain:"Arguments",code:1) }
            if #available(iOS 26.0, *) { try await run(URL(fileURLWithPath:CommandLine.arguments[1])) }
            else { throw NSError(domain:"UnsupportedSimulator",code:1) }
        } catch { try? emit(["type":"fatal","operationalError":String(describing:error),"qualityQualification":false]); exit(1) }
    }
}
