import Foundation
import CryptoKit
import UIKit
import Vision
import PDFKit

struct InputPage: Decodable { var page: Int }
struct InputFixture: Decodable { var id: String; var pdfSha256: String; var pages: [InputPage] }
struct Inputs: Decodable { var fixtures: [InputFixture] }

@main
struct VisionAcquisitionProbe {
    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
        FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
    }
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
        try emit(["type":"environment","scope":"source-extracted native .read acquisition only; no CoreAI/Builder/formal quality evaluation", "os":ProcessInfo.processInfo.operatingSystemVersionString,"deviceSystemVersion":UIDevice.current.systemVersion,"pid":ProcessInfo.processInfo.processIdentifier,"readReturnDefinition":".read public API returned; a throw can occur after Vision.perform, so failures do not prove Vision did not finish","simulator":true,"plannedPages":10,"readRoute":"original thumbnail fractional CGSize; layouts ceil/raster route is not executed","confidenceGuard":"post-observation diagnostic only: finite and 0.85...1","inkCoverageVerified":false])
        var completed = 0, failed = 0, readReturns = 0, hierarchyComplete = 0
        for fixture in inputs.fixtures {
            let url = folder.appendingPathComponent(fixture.id + ".pdf")
            let digest = SHA256.hash(data:try Data(contentsOf:url)).map { String(format:"%02x",$0) }.joined()
            guard digest == fixture.pdfSha256 else { throw NSError(domain:"OriginalPDFChanged",code:1) }
            for pageNumber in 1...5 {
                let started = Date(); let deadline = started.addingTimeInterval(180)
                var readReturned = false
                var phase = "readApi"
                do {
                    // Exactly one native request for this page; earlier diagnostic rejection cannot prevent later pages.
                    let pages = try await PDFRecoveryRecognition.read(url,foreground:true,only:Set([pageNumber]),check:{
                        try Task.checkCancellation()
                        if Date() > deadline { throw NSError(domain:"CooperativePageDeadline",code:1) }
                    })
                    readReturned = true
                    readReturns += 1
                    phase = "postObservationDiagnostic"
                    guard pages.count == 1, let page = pages.first, page.page == pageNumber else { throw NSError(domain:"IncompleteRead",code:1) }
                    var lines = [[String:Any]](), diagnosticFailures = [String](), characters = 0
                    var positiveBoxArea = 0.0
                    for (observationIndex, observation) in page.observations.enumerated() {
                        for (lineIndex,line) in observation.document.text.lines.enumerated() {
                            guard let candidate = line.topCandidates(1).first else {
                                lines.append(["observation":observationIndex,"line":lineIndex,"candidateMissing":true]); diagnosticFailures.append("candidateMissing"); continue
                            }
                            let confidence = Double(candidate.confidence)
                            let good = confidence.isFinite && confidence >= 0.85 && confidence <= 1
                            if !good { diagnosticFailures.append("lineConfidence") }
                            let text = candidate.string
                            var boxes = [[String:Any]]()
                            for start in text.indices {
                                characters += 1
                                guard characters <= 100000 else { throw NSError(domain:"OriginalGlyphLimit",code:1) }
                                let end = text.index(after:start)
                                if let rectangle = candidate.boundingBox(for:start..<end) {
                                    let b = rectangle.boundingBox.cgRect
                                    var value = rect(b,width:page.width,height:page.height)
                                    value["text"] = String(text[start..<end])
                                    let x = b.minX * CGFloat(page.width), y = (1-b.maxY)*CGFloat(page.height)
                                    let w = b.width*CGFloat(page.width), h = b.height*CGFloat(page.height)
                                    let valid = w > 0 && h > 0 && x >= 0 && y >= 0
                                    value["originalLayoutsCharacterPredicate"] = valid
                                    if !valid { diagnosticFailures.append("characterRectangle") }
                                    if [x,y,w,h].allSatisfy(\.isFinite) && w > 0 && h > 0 { positiveBoxArea += Double(w*h) }
                                    boxes.append(value)
                                } else {
                                    boxes.append(["text":String(text[start..<end]),"missing":true]); diagnosticFailures.append("characterBoundingBoxMissing")
                                }
                            }
                            lines.append(["observation":observationIndex,"line":lineIndex,"rawText":text,"confidence":confidence.isFinite ? confidence as Any : NSNull(),"passesOriginalConfidencePredicate":good,"characters":boxes])
                        }
                    }
                    let hierarchy = HierarchyObservation.capture(page.observations,width:page.width,height:page.height)
                    try emit(["type":"page","fixture":fixture.id,"pdfSHA256":digest,"page":pageNumber,"width":page.width,"height":page.height,"seconds":Date().timeIntervalSince(started),"readReturned":true,"serializationCompleted":true,"hierarchyCaptureComplete":hierarchy["captureComplete"] ?? false,"hierarchy":hierarchy,"diagnosticComplete":true,"observations":page.observations.count,"lines":lines,"characterCount":characters,"summedCharacterBoxAreaPixels":positiveBoxArea,"areaIsUnion":false,"diagnosticFailures":diagnosticFailures,"originalLayoutsDiagnosticPredicatesPass":diagnosticFailures.isEmpty,"inkCoverageVerified":false,"formalEvaluation":"unassessed"])
                    completed += 1
                    if hierarchy["captureComplete"] as? Bool == true { hierarchyComplete += 1 }
                } catch {
                    failed += 1
                    try emit(["type":"page","fixture":fixture.id,"pdfSHA256":digest,"page":pageNumber,"readReturned":readReturned,"serializationCompleted":false,"hierarchyCaptureComplete":false,"failureStage":phase,"seconds":Date().timeIntervalSince(started),"operationalError":String(describing:error),"formalEvaluation":"unassessed"])
                }
            }
        }
        try emit(["type":"summary","plannedPages":10,"readReturnedPages":readReturns,"diagnosticCompletedPages":completed,"serializationCompletedPages":completed,"hierarchyCaptureCompletePages":hierarchyComplete,"operationalErrors":failed,"formalAssessed":0,"qualityQualification":false])
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else { throw NSError(domain:"Arguments",code:1) }
            if #available(iOS 26.0, *) { try await run(URL(fileURLWithPath:CommandLine.arguments[1])) }
            else { throw NSError(domain:"UnsupportedSimulator",code:1) }
        } catch {
            try? emit(["type":"fatal","operationalError":String(describing:error),"qualityQualification":false])
            exit(1)
        }
    }
}
