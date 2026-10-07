import AppKit
import CoreText
import CryptoKit
import Foundation
import Vision

// New synthetic component corpus; no source PDF, networking, adoption or LLM.
@main struct VisionConfidenceProfileProbe {
    struct Literal { let role: String; let text: String }
    static let corpus: [Literal] = [
        ("subject", ["仮想実験あ", "仮想実験い", "仮想演習う", "仮想演習え", "仮想設計お", "仮想設計か", "仮想応用き", "仮想応用く"]),
        ("teacher", ["仮想担当甲", "仮想担当乙", "仮想担当丙", "仮想担当丁", "仮想担当戊", "仮想担当己", "仮想担当庚", "仮想担当辛"]),
        ("room", ["仮室B204", "仮室B2O4", "仮室L100", "仮室L1O0", "仮室Q01", "仮室QO1", "仮室I108", "仮室1108"]),
        ("header", ["2027年度", "前期", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "1限", "3限", "7限", "8限", "2_CN", "4_ES", "AI_1", "9:10〜10:00", "13:20～14:10"])
    ].flatMap { role, texts in texts.map { Literal(role: role, text: $0) } }

    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard data.count <= 262144, let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        print(text)
    }

    static func image(_ text: String, _ size: Int) throws -> CGImage {
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, CGFloat(size), nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let width = max(48, Int(ceil(advance)) + 12), height = max(32, Int(ceil(ascent + descent)) + 12)
        guard width <= 1024, height <= 128, let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileReadCorruptFile) }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.textPosition = CGPoint(x: 6, y: 6 + descent); CTLineDraw(line, context)
        guard let result = context.makeImage() else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    static func main() async throws {
        guard #available(macOS 26.0, *) else { throw CocoaError(.featureUnsupported) }
        guard corpus.count == 40, Set(corpus.map(\.text)).count == 40 else { throw CocoaError(.fileReadCorruptFile) }
        let recipe: [String: Any] = ["recipe": "vision-confidence-profile-component-v1", "distinctLiterals": 40,
            "font": "HiraginoSans-W3", "fontPixels": [24, 16], "marginPixels": 6, "plannedImages": 80,
            "plannedCalls": 160, "minimumConfidenceDiagnostic": 0.8, "retry": false,
            "documentQuality": "UNASSESSED", "comparisonScope": "paired fonts and APIs, not independent documents or shared Windows pixels",
            "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
            "corpus": corpus.map { ["role": $0.role, "text": $0.text] }]
        try emit(recipe)
        if CommandLine.arguments == [CommandLine.arguments[0], "--preflight"] { return }
        guard CommandLine.arguments.count == 1 else { throw CocoaError(.featureUnsupported) }
        try await run()
    }

    @available(macOS 26.0, *)
    static func run() async throws {
        let start = ProcessInfo.processInfo.systemUptime
        var summaries = [String: [String: Int]](), attempted = 0, operationalErrors = 0
        for (ordinal, literal) in corpus.enumerated() {
            for size in [24, 16] {
                let input = try image(literal.text, size)
                guard let pixels = input.dataProvider?.data else { throw CocoaError(.fileReadCorruptFile) }
                let hash = SHA256.hash(data: pixels as Data).map { String(format: "%02x", $0) }.joined()
                for condition in ["documents-default", "text-accurate-auto"] {
                    try Task.checkCancellation()
                    guard ProcessInfo.processInfo.systemUptime - start < 480 else { throw CocoaError(.userCancelled) }
                    attempted += 1
                    do {
                        let lines: [RecognizedTextObservation]
                        if condition == "documents-default" {
                            let documents = try await RecognizeDocumentsRequest().perform(on: input)
                            lines = documents.flatMap { $0.document.text.lines }
                        } else {
                            var request = RecognizeTextRequest()
                            request.recognitionLevel = .accurate
                            request.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
                            request.automaticallyDetectsLanguage = true
                            request.usesLanguageCorrection = true
                            lines = try await request.perform(on: input)
                        }
                        guard lines.count <= 32 else { throw CocoaError(.fileReadCorruptFile) }
                        let top = lines.compactMap { $0.topCandidates(1).first }
                        let strings = top.map(\.string), confidence = top.map { Double($0.confidence) }
                        let exact = strings == [literal.text]
                        let passes = top.count == 1 && confidence.allSatisfy { $0.isFinite && $0 >= 0.8 && $0 <= 1 }
                        let key = condition + ":" + literal.role
                        summaries[key, default: [:]]["rows", default: 0] += 1
                        summaries[key, default: [:]][exact ? "exact" : "literalMismatch", default: 0] += 1
                        if passes { summaries[key, default: [:]][exact ? "correctAboveFloor" : "wrongAboveFloor", default: 0] += 1 }
                        if exact && !passes { summaries[key, default: [:]]["correctBelowFloor", default: 0] += 1 }
                        let alternatives = lines.map { $0.topCandidates(3).map(\.string) }
                        try emit(["type": "row", "ordinal": ordinal, "role": literal.role, "expected": literal.text,
                            "fontPixels": size, "condition": condition, "imageSHA256": hash, "width": input.width, "height": input.height,
                            "rawTop1": strings, "confidences": confidence, "candidates": alternatives,
                            "literalExact": exact, "diagnosticFloorPass": passes, "formalAdoption": "NOT_ATTEMPTED"])
                    } catch {
                        operationalErrors += 1
                        try emit(["type": "executionError", "ordinal": ordinal, "fontPixels": size,
                            "condition": condition, "errorType": String(describing: type(of: error))])
                    }
                }
            }
        }
        try emit(["type": "summary", "attemptedCalls": attempted, "operationalErrors": operationalErrors,
            "byConditionAndRole": summaries, "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start,
            "documentQuality": "UNASSESSED", "qualifiedModels": [String](), "imagesWrittenToDisk": 0])
        guard attempted == 160, operationalErrors == 0 else { throw CocoaError(.fileReadCorruptFile) }
        print("VISION_CONFIDENCE_PROFILE_COMPLETE_CALLS_160_NO_QUALIFICATION")
    }
}
