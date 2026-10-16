import Foundation
import PDFKit
import Vision
import AppKit
import ImageIO
import CoreText
import CryptoKit
import Darwin

// A bounded diagnostic, not an app fallback or a qualification run.
// All input/reader pairs run once; errors are reported and make the job fail.
@available(macOS 26.0, *)
@main struct NativeImageDiagnostic {
    static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw NSError(domain: "FictionalImageDiagnostic", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]) }
        return value
    }
    static func emit(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        print("OCR_IMAGE_DIAGNOSTIC " + String(decoding: data, as: UTF8.self))
        fflush(stdout)
    }
    static func metadata(_ image: CGImage) -> [String: Any] {
        let providerHash: String
        if let data = image.dataProvider?.data {
            providerHash = SHA256.hash(data: data as Data).map { String(format: "%02x", $0) }.joined()
        } else { providerHash = "unavailable" }
        return ["width": image.width, "height": image.height, "bitsPerComponent": image.bitsPerComponent,
         "bitsPerPixel": image.bitsPerPixel, "bytesPerRow": image.bytesPerRow,
         "bitmapInfo": image.bitmapInfo.rawValue, "alphaInfo": image.alphaInfo.rawValue,
         "colorSpace": image.colorSpace.map { String(describing: $0) } ?? "nil",
         "providerSHA256": providerHash]
    }
    static func context(_ width: Int, _ height: Int) throws -> CGContext {
        try require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue), "No RGBA8 context")
    }
    static func output(_ lines: [RecognizedTextObservation]) -> [[String: Any]] {
        lines.map { line in
            let candidates: [[String: Any]] = line.topCandidates(5).map { ["text": $0.string, "confidence": Double($0.confidence)] }
            return ["candidates": candidates]
        }
    }
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw NSError(domain: "FictionalImageDiagnostic", code: 2)
            }
            let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            let pdf = try require(PDFDocument(url: root.appendingPathComponent("fictional.pdf")), "No fictional PDF")
            let page = try require(pdf.page(at: 0), "No first page")
            let b = page.bounds(for: .cropBox)
            let scale = min(2, 2048 / max(b.width, b.height))
            let thumbnail = page.thumbnail(of: NSSize(width: ceil(b.width * scale), height: ceil(b.height * scale)), for: .cropBox)
            let original = try require(thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil), "No native raster")
            let png = root.appendingPathComponent("diagnostic-original.png")
            let destination = try require(CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil), "No PNG output")
            CGImageDestinationAddImage(destination, original, nil)
            guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "PNG", code: 1) }
            let source = try require(CGImageSourceCreateWithURL(png as CFURL, nil), "No PNG source")
            let decoded = try require(CGImageSourceCreateImageAtIndex(source, 0, nil), "No PNG image")
            let rgba = try context(original.width, original.height)
            rgba.setFillColor(gray: 1, alpha: 1)
            rgba.fill(CGRect(x: 0, y: 0, width: original.width, height: original.height))
            rgba.draw(original, in: CGRect(x: 0, y: 0, width: original.width, height: original.height))
            let copied = try require(rgba.makeImage(), "No RGBA8 copy")
            let control = try context(512, 160)
            control.setFillColor(gray: 1, alpha: 1)
            control.fill(CGRect(x: 0, y: 0, width: 512, height: 160))
            let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 32, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: "架空文字対照 Fiction", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]) as CFAttributedString)
            control.textPosition = CGPoint(x: 20, y: 70)
            CTLineDraw(line, control)
            let clean = try require(control.makeImage(), "No control image")
            var errors = 0, calls = 0
            for (name, image) in [("native-pdfkit", original), ("png-roundtrip", decoded), ("rgba8-copy", copied), ("coretext-rgba8-control", clean)] {
                try emit(["phase": "input", "format": name, "metadata": metadata(image),
                          "os": ProcessInfo.processInfo.operatingSystemVersionString])
                for reader in ["documents-default", "documents-ja-en-no-autodetect", "text-accurate-default"] {
                    calls += 1
                    try emit(["phase": "call-start", "format": name, "reader": reader, "ordinal": calls])
                    do {
                        let lines: [RecognizedTextObservation]
                        if reader == "text-accurate-default" {
                            var request = RecognizeTextRequest(); request.recognitionLevel = .accurate
                            lines = try await request.perform(on: image)
                        } else {
                            var request = RecognizeDocumentsRequest()
                            if reader == "documents-ja-en-no-autodetect" {
                                request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
                                request.textRecognitionOptions.automaticallyDetectLanguage = false
                            }
                            lines = try await request.perform(on: image).flatMap { $0.document.text.lines }
                        }
                        try emit(["phase": "call-result", "format": name, "reader": reader,
                                  "error": NSNull(), "nativeLines": output(lines)])
                    } catch {
                        errors += 1
                        try emit(["phase": "call-result", "format": name, "reader": reader,
                                  "error": String(reflecting: error), "nativeLines": NSNull()])
                    }
                }
            }
            try emit(["phase": "finished", "actualCalls": calls, "executionErrors": errors,
                      "qualification": false, "appChanged": false])
            if errors > 0 { exit(1) }
        } catch {
            try? emit(["phase": "setup-error", "error": String(reflecting: error), "qualification": false])
            exit(1)
        }
    }
}
