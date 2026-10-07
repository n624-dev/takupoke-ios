import AppKit
import CoreText
import CryptoKit
import Foundation
import Vision

// Independent fictional 2x3 table, no PDF, fixture image or school input.
// This is a raw-recognition comparison, not a timetable or model qualification.
@main struct VisionTextSecondaryProbe {
    static func main() async throws {
        guard #available(macOS 26.0, *) else { throw CocoaError(.featureUnsupported) }
        try await run()
    }
    @available(macOS 26.0, *)
    static func run() async throws {
        let expected = ["4_ES", "火", "3", "仮想演習", "仮想担当乙", "Q102"]
        guard let context = CGContext(data: nil, width: 1200, height: 800, bitsPerComponent: 8,
            bytesPerRow: 4800, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileReadCorruptFile) }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1)); context.setLineWidth(4)
        for x in [40,400,760,1120] { context.move(to:CGPoint(x:CGFloat(x),y:40)); context.addLine(to:CGPoint(x:CGFloat(x),y:760)) }
        for y in [40,400,760] { context.move(to:CGPoint(x:40,y:CGFloat(y))); context.addLine(to:CGPoint(x:1120,y:CGFloat(y))) }
        context.strokePath()
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 48, nil)
        for (index,text) in expected.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String):font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0,alpha:1)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attrs) as CFAttributedString)
            context.textPosition = CGPoint(x:CGFloat(70+(index%3)*360),y:CGFloat(800-(160+(index/3)*360)-48))
            CTLineDraw(line,context)
        }
        guard let image = context.makeImage() else { throw CocoaError(.fileReadCorruptFile) }
        guard let bytes=image.dataProvider?.data else { throw CocoaError(.fileReadCorruptFile) }
        let inputSHA=SHA256.hash(data:bytes as Data).map { String(format:"%02x",$0) }.joined()
        let start=ProcessInfo.processInfo.systemUptime
        func emit(_ condition:String,_ lines:[RecognizedTextObservation],_ configuration:[String:Any]) throws {
            guard lines.count<=100 else { throw CocoaError(.fileReadCorruptFile) }
            let top=lines.compactMap { $0.topCandidates(1).first },literal=top.map(\.string)
            let result:[String:Any]=["condition":condition,"configuration":configuration,
                "inputSHA256":inputSHA,"rawTop1":literal,"confidences":top.map { Double($0.confidence) },
                "rawExactLiterals":expected.filter { literal.contains($0) }.count,"expectedLiterals":expected.count,
                "elapsedSeconds":ProcessInfo.processInfo.systemUptime-start,"recognitionCalls":1,
                "wholeDocumentQuality":"UNASSESSED","runtime":ProcessInfo.processInfo.operatingSystemVersionString]
            let output=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
            guard output.count<=65536 else { throw CocoaError(.fileReadCorruptFile) }
            print(String(data:output,encoding:.utf8)!)
        }
        let documents=try await RecognizeDocumentsRequest().perform(on:image)
        guard documents.count<=100 else { throw CocoaError(.fileReadCorruptFile) }
        try emit("documents-default",documents.flatMap { $0.document.text.lines },["API":"RecognizeDocumentsRequest"])
        for condition in ["text-accurate-auto","text-accurate-raw"] {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime-start<240 else { throw CocoaError(.userCancelled) }
            var request=RecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages=[Locale.Language(identifier:"ja"),Locale.Language(identifier:"en")]
            request.automaticallyDetectsLanguage=true
            request.usesLanguageCorrection=condition != "text-accurate-raw"
            let lines=try await request.perform(on:image)
            try emit(condition,lines,["API":"RecognizeTextRequest","recognitionLevel":"accurate",
                "languages":request.recognitionLanguages.map { $0.languageCode?.identifier ?? "?" },
                "automaticLanguage":request.automaticallyDetectsLanguage,"languageCorrection":request.usesLanguageCorrection])
        }
        print("VISION_TEXT_SECONDARY_COMPLETE_CALLS_3_NO_QUALIFICATION")
    }
}
