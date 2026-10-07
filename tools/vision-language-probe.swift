import AppKit
import CoreText
import Foundation
import Vision

// Independent fictional 2x3 table, no PDF, fixture image or school input.
// This is a raw-recognition comparison, not a timetable or model qualification.
@main struct VisionLanguageProbe {
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
        for x in [40,400,760,1120] { context.move(to:CGPoint(x:x,y:40)); context.addLine(to:CGPoint(x:x,y:760)) }
        for y in [40,400,760] { context.move(to:CGPoint(x:40,y:y)); context.addLine(to:CGPoint(x:1120,y:y)) }
        context.strokePath()
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 48, nil)
        for (index,text) in expected.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String):font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0,alpha:1)]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attrs))
            context.textPosition = CGPoint(x:70+(index%3)*360,y:800-(160+(index/3)*360)-48)
            CTLineDraw(line,context)
        }
        guard let image = context.makeImage() else { throw CocoaError(.fileReadCorruptFile) }
        let start=ProcessInfo.processInfo.systemUptime
        for condition in ["default", "japanese-english", "japanese-english-raw"] {
            try Task.checkCancellation()
            guard ProcessInfo.processInfo.systemUptime-start<240 else { throw CocoaError(.userCancelled) }
            var request=RecognizeDocumentsRequest()
            let supported=request.supportedRecognitionLanguages.map { $0.languageCode?.identifier ?? "?" }
            if condition != "default" {
                guard supported.contains("ja") else { throw CocoaError(.featureUnsupported) }
                request.textRecognitionOptions.recognitionLanguages=[Locale.Language(identifier:"ja"),Locale.Language(identifier:"en")]
                request.textRecognitionOptions.automaticallyDetectLanguage=false
            }
            if condition == "japanese-english-raw" { request.textRecognitionOptions.useLanguageCorrection=false }
            let configuration: [String:Any] = ["condition":condition,
                "languages":request.textRecognitionOptions.recognitionLanguages.map { $0.languageCode?.identifier ?? "?" },
                "automaticLanguage":request.textRecognitionOptions.automaticallyDetectLanguage,
                "languageCorrection":request.textRecognitionOptions.useLanguageCorrection,"supportedLanguages":supported]
            print(String(data:try JSONSerialization.data(withJSONObject:configuration,options:[.sortedKeys]),encoding:.utf8)!)
            let observations=try await request.perform(on:image)
            guard observations.count<=100 else { throw CocoaError(.fileReadCorruptFile) }
            let lines=observations.flatMap { $0.document.text.lines }
            guard lines.count<=100 else { throw CocoaError(.fileReadCorruptFile) }
            let top=lines.compactMap { $0.topCandidates(1).first }
            let literal=top.map(\.string)
            let tables=observations.flatMap { $0.document.tables }
            let tableText=tables.flatMap { $0.rows.flatMap { $0.map { $0.content.text.transcript } } }
            let result:[String:Any]=["condition":condition,"rawTop1":literal,
                "confidences":top.map { Double($0.confidence) },"rawExactLiterals":expected.filter { literal.contains($0) }.count,
                "expectedLiterals":expected.count,"tables":tables.count,"tableCellText":tableText,
                "elapsedSeconds":ProcessInfo.processInfo.systemUptime-start,"recognitionCalls":1,
                "wholeDocumentQuality":"UNASSESSED","runtime":ProcessInfo.processInfo.operatingSystemVersionString]
            print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]),encoding:.utf8)!)
        }
        print("VISION_LANGUAGE_PROBE_COMPLETE_CALLS_3_NO_QUALIFICATION")
    }
}
