import Foundation
import CryptoKit
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Vision

@main struct FreshHierarchyProbe {
    static func emit(_ value:[String:Any]) throws {
        let data=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
        FileHandle.standardOutput.write(data);FileHandle.standardOutput.write(Data([10]))
    }
    static func sha(_ data:Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func rect(_ b:CGRect,width:Int,height:Int) -> [String:Any] {
        let v=[Double(b.minX),Double(b.minY),Double(b.width),Double(b.height)]
        guard v.allSatisfy(\.isFinite) else { return ["finite":false] }
        return ["finite":true,"normalizedLowerLeft":["x":v[0],"y":v[1],"width":v[2],"height":v[3]],"pixelTopLeft":["x":v[0]*Double(width),"y":(1-Double(b.maxY))*Double(height),"width":v[2]*Double(width),"height":v[3]*Double(height)]]
    }
    static func imageRecord(_ cg:CGImage) throws -> ([String:Any],Data) {
        let png=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(png,UTType.png.identifier as CFString,1,nil) else { throw NSError(domain:"PNGDestination",code:1) }
        CGImageDestinationAddImage(destination,cg,nil)
        guard CGImageDestinationFinalize(destination),let pixels=cg.dataProvider?.data else { throw NSError(domain:"PNGEncodeOrProvider",code:1) }
        let data=png as Data
        guard data.count <= 4*1024*1024 else { throw NSError(domain:"PNGBound",code:1) }
        return (["width":cg.width,"height":cg.height,"bitsPerComponent":cg.bitsPerComponent,"bitsPerPixel":cg.bitsPerPixel,"bytesPerRow":cg.bytesPerRow,"bitmapInfo":cg.bitmapInfo.rawValue,"alphaInfo":cg.alphaInfo.rawValue,"colorSpace":cg.colorSpace?.name as String? ?? "unnamed","providerBytes":CFDataGetLength(pixels),"providerSHA256":sha(pixels as Data),"pngBytes":data.count,"pngSHA256":sha(data),"losslessPNGBase64":data.base64EncodedString(),"resized":false,"source":"fresh UIKit system-font source drawing; no PDF or former image input"],data)
    }
    @MainActor @available(iOS 26.0,*) static func run(_ folder:URL) async throws {
        let (cg,expected)=try FreshFixture.make()
        let (input,png)=try imageRecord(cg)
        try png.write(to:folder.appendingPathComponent("fresh-input.png"))
        // Persist and emit the exact request image before starting the one native call.
        try emit(["type":"input","image":input,"os":ProcessInfo.processInfo.operatingSystemVersionString,"plannedRequests":1,"requestConstruction":"RecognizeDocumentsRequest()","settingOverrides":[],"expectedDataPassedToVision":false,"modelInvocations":0,"pdfInputs":0,"originalOrPriorImageInputs":0])
        let started=Date()
        var attempted=0,returned=0,captureComplete=false,errors=0
        do {
            try Task.checkCancellation()
            attempted=1
            let observations=try await RecognizeDocumentsRequest().perform(on:cg)
            returned=1
            guard observations.count <= 1000 else { throw NSError(domain:"ObservationCountBound",code:1) }
            let hierarchy=HierarchyObservation.capture(observations,width:cg.width,height:cg.height)
            captureComplete=hierarchy["captureComplete"] as? Bool == true
            try emit(["type":"page","requestReturned":true,"observationCount":observations.count,"seconds":Date().timeIntervalSince(started),"hierarchy":hierarchy,"serializationCompleted":true,"selectedHierarchyCaptureComplete":captureComplete,"formalEvaluation":"unassessed","candidateAdopted":false,"confidencePredicate":"posthoc diagnostic only: finite 0.85...1","rangeBoxScope":"native API returned ranges; not exact glyph extent or unique ink ownership"])
        } catch {
            captureComplete=false;errors=1
            try emit(["type":"page","requestReturned":returned==1,"serializationCompleted":false,"selectedHierarchyCaptureComplete":false,"seconds":Date().timeIntervalSince(started),"operationalError":String(describing:error),"formalEvaluation":"unassessed"])
        }
        // Drawing values/positions become available for independent posthoc comparison only.
        try emit(["type":"oracle","drawingRecords":expected,"source":"fresh source drawing","oracleEnteredVision":false,"notExactGlyphBoxes":true])
        try emit(["type":"summary","plannedRequests":1,"attemptedRequests":attempted,"returnedRequests":returned,"hierarchyCaptureCompletePages":captureComplete ? 1 : 0,"operationalErrors":errors,"formalAssessed":0,"qualityQualification":false,"modelInvocations":0])
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count==2 else { throw NSError(domain:"Arguments",code:1) }
            if #available(iOS 26.0,*) { try await run(URL(fileURLWithPath:CommandLine.arguments[1])) }
            else { throw NSError(domain:"UnsupportedSimulator",code:1) }
        } catch {
            try? emit(["type":"fatal","operationalError":String(describing:error),"qualityQualification":false]);exit(1)
        }
    }
}
