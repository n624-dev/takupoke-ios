import Foundation
import PDFKit
import Vision
import AppKit
import ImageIO
import CryptoKit

// Research executable only. No app, Strict, routing or acceptance code is linked.
// The reader accepts physical regions, never expected strings or an oracle path.
@available(macOS 26.0, *)
@main struct VisionScreen {
    static func fail(_ message: String) throws -> Never {
        throw NSError(domain: "FictionalOCRScreen", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func load(_ url: URL) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else {
            try fail("Invalid research manifest")
        }
        return value
    }
    static func save(_ value: Any, _ url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { try fail("Output already exists") }
        let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
        try bytes.write(to: url, options: .withoutOverwriting)
    }
    static func hash(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
    static func png(_ image: CGImage, _ url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            try fail("Cannot create owned PNG")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { try fail("PNG write failed") }
    }
    static func image(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { try fail("Cannot read owned crop") }
        return image
    }
    static func capture(_ lines: [RecognizedTextObservation], width: Int, height: Int) -> [[String: Any]] {
        lines.enumerated().map { order, line in
            let b = line.boundingBox.cgRect
            let candidates: [[String: Any]] = line.topCandidates(5).map { candidate in
                ["text": candidate.string, "confidence": Double(candidate.confidence)]
            }
            return ["nativeOrder": order, "box": [Double(b.minX) * Double(width), Double(1-b.maxY) * Double(height),
                Double(b.width) * Double(width), Double(b.height) * Double(height)], "candidates": candidates]
        }
    }
    static func configuration(_ request: RecognizeDocumentsRequest) -> [String: Any] {
        ["minimumTextHeightFraction": Double(request.textRecognitionOptions.minimumTextHeightFraction),
         "recognitionLanguages": request.textRecognitionOptions.recognitionLanguages.map { String(describing: $0) },
         "automaticallyDetectLanguage": request.textRecognitionOptions.automaticallyDetectLanguage,
         "useLanguageCorrection": request.textRecognitionOptions.useLanguageCorrection]
    }
    static func extract(_ root: URL) async throws {
        let manifest = try load(root.appendingPathComponent("inputs.json"))
        guard let pdfName = manifest["pdf"] as? String, pdfName == "fictional.pdf",
              let expectedHash = manifest["pdfSHA256"] as? String,
              let pages = manifest["pages"] as? [[String: Any]], pages.count == 6 else { try fail("Invalid page inventory") }
        let pdfURL = root.appendingPathComponent(pdfName)
        guard try hash(pdfURL) == expectedHash, let document = PDFDocument(url: pdfURL),
              !document.isLocked, document.pageCount == pages.count else { try fail("PDF identity mismatch") }
        var crops = [[String: Any]](), records = [[String: Any]]()
        for (index, specification) in pages.enumerated() {
            guard let number = specification["page"] as? Int, number == index + 1,
                  let width = specification["width"] as? Int, let height = specification["height"] as? Int,
                  let regions = specification["regions"] as? [[String: Any]], regions.count == 24,
                  let page = document.page(at: index) else { try fail("Incomplete page") }
            let bounds = page.bounds(for: .cropBox)
            let scale = min(2, 2048 / max(bounds.width, bounds.height))
            let thumbnail = page.thumbnail(of: NSSize(width: ceil(bounds.width * scale), height: ceil(bounds.height * scale)), for: .cropBox)
            guard let raster = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  raster.width == width, raster.height == height, width <= 2048, height <= 2048 else {
                try fail("Native PDF raster size changed; never silently rescale")
            }
            let pageFile = root.appendingPathComponent("native-page-\(number).png")
            try png(raster, pageFile)
            let started = Date()
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: raster)
            let lines = capture(observations.flatMap { $0.document.text.lines }, width: width, height: height)
            records.append(["page": number, "reader": "vision-documents-page-default", "rasterSHA256": try hash(pageFile),
                            "width": width, "height": height, "seconds": Date().timeIntervalSince(started),
                            "configuration": configuration(request), "lines": lines])
            for region in regions {
                guard let id = region["id"] as? String, id == "p\(number)-f\(crops.count % 24 + 1)",
                      let b = region["box"] as? [Int], b.count == 4 else { try fail("Invalid region manifest") }
                let rect = CGRect(x: b[0], y: b[1], width: b[2], height: b[3])
                guard CGRect(x: 0, y: 0, width: width, height: height).contains(rect),
                      let crop = raster.cropping(to: rect), crop.width == b[2], crop.height == b[3] else {
                    try fail("Physical region cannot be cropped exactly")
                }
                let filename = "physical-\(id).png", url = root.appendingPathComponent(filename)
                try png(crop, url)
                crops.append(["id": id, "file": filename, "sha256": try hash(url), "page": number, "box": b])
            }
        }
        guard try hash(pdfURL) == expectedHash, crops.count == 144 else { try fail("Acquisition changed or incomplete") }
        try save(["crops": crops], root.appendingPathComponent("physical.json"))
        try save(["pages": records, "calls": pages.count, "os": ProcessInfo.processInfo.operatingSystemVersionString],
                 root.appendingPathComponent("vision-pages.json"))
        print("EXTRACTED pages=\(pages.count) physicalCrops=\(crops.count) actualDocumentsCalls=\(pages.count)")
    }
    static func crops(_ root: URL) async throws {
        guard let frames = try load(root.appendingPathComponent("frames.json"))["frames"] as? [[String: Any]], frames.count == 288 else {
            try fail("Incomplete framed inventory")
        }
        var records = [[String: Any]]()
        for frame in frames {
            guard let filename = frame["file"] as? String, let identity = frame["id"] as? String,
                  let framing = frame["frame"] as? String, let expectedHash = frame["sha256"] as? String,
                  !filename.contains("/"), !filename.contains("..") else { try fail("Invalid crop path") }
            let url = root.appendingPathComponent(filename)
            guard try hash(url) == expectedHash else { try fail("Crop changed") }
            let raster = try image(url)
            let started = Date()
            let documentRequest = RecognizeDocumentsRequest()
            let observations = try await documentRequest.perform(on: raster)
            records.append(["id": identity, "frame": framing, "reader": "vision-documents-crop-default",
                "imageSHA256": expectedHash, "width": raster.width, "height": raster.height,
                "configuration": configuration(documentRequest),
                "seconds": Date().timeIntervalSince(started),
                "lines": capture(observations.flatMap { $0.document.text.lines }, width: raster.width, height: raster.height)])
            var request = RecognizeTextRequest()
            request.recognitionLevel = .accurate
            let textStarted = Date()
            let textLines = try await request.perform(on: raster)
            records.append(["id": identity, "frame": framing, "reader": "vision-text-crop-accurate-default",
                "imageSHA256": expectedHash, "width": raster.width, "height": raster.height,
                "configuration": ["recognitionLevel": "accurate", "minimumTextHeightFraction": Double(request.minimumTextHeightFraction),
                    "recognitionLanguages": request.recognitionLanguages.map { String(describing: $0) },
                    "automaticallyDetectsLanguage": request.automaticallyDetectsLanguage,
                    "usesLanguageCorrection": request.usesLanguageCorrection],
                "seconds": Date().timeIntervalSince(textStarted), "lines": capture(textLines, width: raster.width, height: raster.height)])
        }
        try save(["records": records, "calls": frames.count * 2, "os": ProcessInfo.processInfo.operatingSystemVersionString],
                 root.appendingPathComponent("vision-crops.json"))
        print("CROP_READERS actualNativeCalls=\(records.count)")
    }
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { try fail("Use extract|crops <owned study directory>") }
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        switch CommandLine.arguments[1] {
        case "extract": try await extract(root)
        case "crops": try await crops(root)
        default: try fail("Unknown study phase")
        }
    }
}
