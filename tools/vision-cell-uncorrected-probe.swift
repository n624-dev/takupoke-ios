import AppKit
import CoreText
import CryptoKit
import Foundation
import Vision

// Unseen fictional values in a ruled 8x3 body table. No field-name labels,
// source PDF, inference retry, production adoption or threshold changes.
@main struct VisionCellUncorrectedProbe {
    static let subjects = ["仮想回路け", "仮想回路こ", "仮想解析さ", "仮想解析し", "仮想製図す", "仮想製図せ", "仮想設計そ", "仮想設計た"]
    static let teachers = ["仮想担当子", "仮想担当丑", "仮想担当寅", "仮想担当卯", "仮想担当辰", "仮想担当巳", "仮想担当午", "仮想担当未"]
    static let rooms = ["仮室C307", "仮室C3O7", "仮室T200", "仮室T2O0", "仮室R01", "仮室RO1", "仮室I209", "仮室1209"]
    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard data.count < 524288, let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        print(text)
    }
    static func image(size: Int) throws -> CGImage {
        guard let context = CGContext(data: nil, width: 1200, height: 1000, bitsPerComponent: 8,
            bytesPerRow: 4800, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1000))
        context.setStrokeColor(CGColor(gray: 0, alpha: 1)); context.setLineWidth(2)
        for x in [30, 410, 790, 1170] {
            context.move(to: CGPoint(x: CGFloat(x), y: 80)); context.addLine(to: CGPoint(x: CGFloat(x), y: 960))
        }
        for y in stride(from: 80, through: 960, by: 110) {
            context.move(to: CGPoint(x: 30, y: CGFloat(y))); context.addLine(to: CGPoint(x: 1170, y: CGFloat(y)))
        }
        context.strokePath()
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, CGFloat(size), nil)
        for row in 0..<8 {
            for (column, text) in [subjects[row], teachers[row], rooms[row]].enumerated() {
                let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
                context.textPosition = CGPoint(x: CGFloat(60 + column * 380), y: CGFloat(920 - row * 110))
                CTLineDraw(line, context)
            }
        }
        guard let result = context.makeImage() else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }
    static func main() async throws {
        guard #available(macOS 26.0, *) else { throw CocoaError(.featureUnsupported) }
        try await run()
    }
    @available(macOS 26.0, *)
    static func run() async throws {
        let expected = (0..<8).flatMap { [subjects[$0], teachers[$0], rooms[$0]] }
        guard Set(expected).count == 24 else { throw CocoaError(.fileReadCorruptFile) }
        try emit(["type": "recipe", "recipe": "vision-fixed-physical-cell-uncorrected-v1", "plannedImages": 48,
            "plannedCalls": 48, "fontPixels": [24, 16], "expected": expected,
            "crop": "one physical cell, two pixels inside ruled boundaries, no scaling",
            "answerSelection": false, "retry": false, "runtime": ProcessInfo.processInfo.operatingSystemVersionString,
            "documentQuality": "UNASSESSED"])
        if CommandLine.arguments == [CommandLine.arguments[0], "--preflight"] { return }
        guard CommandLine.arguments.count == 1 else { throw CocoaError(.featureUnsupported) }
        let start = ProcessInfo.processInfo.systemUptime; var attempted = 0
        for size in [24, 16] {
            let parent = try image(size: size)
            guard let pixels = parent.dataProvider?.data else { throw CocoaError(.fileReadCorruptFile) }
            let parentHash = SHA256.hash(data: pixels as Data).map { String(format: "%02x", $0) }.joined()
            for row in 0..<8 {
                for column in 0..<3 {
                    // CGImage cropping uses its top-left raster coordinate system.
                    let rectangle = CGRect(x: 32 + column * 380, y: 42 + row * 110, width: 376, height: 106)
                    guard let crop = parent.cropping(to: rectangle), let data = crop.dataProvider?.data,
                        crop.width == 376, crop.height == 106 else { throw CocoaError(.fileReadCorruptFile) }
                    let cropHash = SHA256.hash(data: data as Data).map { String(format: "%02x", $0) }.joined()
                    for condition in ["text-accurate-auto-uncorrected-cell"] {
                        try Task.checkCancellation()
                        guard ProcessInfo.processInfo.systemUptime - start < 240 else { throw CocoaError(.userCancelled) }
                        let lines: [RecognizedTextObservation]
                        attempted += 1
                        var request = RecognizeTextRequest()
                        request.recognitionLevel = .accurate
                        request.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
                        request.automaticallyDetectsLanguage = true
                        request.usesLanguageCorrection = false
                        lines = try await request.perform(on: crop)
                        guard lines.count <= 32 else { throw CocoaError(.fileReadCorruptFile) }
                        let output = lines.map { line -> [String: Any] in
                            let box = line.boundingBox.cgRect
                            return ["top1": line.topCandidates(1).first?.string ?? "",
                                "confidence": Double(line.topCandidates(1).first?.confidence ?? 0),
                                "box": [Double(box.minX), Double(1 - box.maxY), Double(box.width), Double(box.height)],
                                "candidates": line.topCandidates(3).map(\.string)]
                        }
                        try emit(["type": "row", "condition": condition, "fontPixels": size, "sourceCell": [row, column],
                            "parentSHA256": parentHash, "imageSHA256": cropHash, "lines": output,
                            "cropTopLeftPixels": [Int(rectangle.minX), Int(rectangle.minY), Int(rectangle.width), Int(rectangle.height)],
                            "formalAdoption": "NOT_ATTEMPTED"])
                    }
                }
            }
        }
        guard attempted == 48 else { throw CocoaError(.fileReadCorruptFile) }
        try emit(["type": "summary", "attemptedCalls": attempted, "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start,
            "wholeDocumentQuality": "UNASSESSED", "qualifiedModels": [String](), "imagesWrittenToDisk": 0])
        print("VISION_PHYSICAL_CELL_UNCORRECTED_COMPLETE_CALLS_48_NO_QUALIFICATION")
    }
}
