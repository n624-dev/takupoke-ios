import Foundation
import PDFKit
import AppKit
import ImageIO
import CryptoKit

// Pixel acquisition only; no Vision, model, oracle, app or parser code.
@main struct RasterizeFictionalPDF {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { throw NSError(domain: "FictionalRaster", code: 1) }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        func require<T>(_ value: T?) throws -> T {
            guard let value else { throw NSError(domain: "FictionalRaster", code: 2) }
            return value
        }
        func hash(_ url: URL) throws -> String {
            SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        }
        let input = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("inputs.json")))
        let manifest = try require(input as? [String: Any])
        let expectedHash = try require(manifest["pdfSHA256"] as? String)
        let pages = try require(manifest["pages"] as? [[String: Any]])
        let url = root.appendingPathComponent("fictional.pdf")
        let document = try require(PDFDocument(url: url))
        guard try hash(url) == expectedHash, document.pageCount == 6, pages.count == 6, !document.isLocked else {
            throw NSError(domain: "FictionalRaster", code: 3)
        }
        var crops = [[String: Any]]()
        for (index, spec) in pages.enumerated() {
            let page = try require(document.page(at: index))
            let width = try require(spec["width"] as? Int), height = try require(spec["height"] as? Int)
            let number = try require(spec["page"] as? Int)
            let regions = try require(spec["regions"] as? [[String: Any]])
            guard number == index + 1, regions.count == 24 else { throw NSError(domain: "FictionalRaster", code: 4) }
            let b = page.bounds(for: .cropBox), scale = min(2, 2048 / max(page.bounds(for: .cropBox).width, page.bounds(for: .cropBox).height))
            let image = page.thumbnail(of: NSSize(width: ceil(b.width * scale), height: ceil(b.height * scale)), for: .cropBox)
            let cg = try require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            guard cg.width == width, cg.height == height else { throw NSError(domain: "FictionalRaster", code: 5) }
            for (ordinal, region) in regions.enumerated() {
                let id = try require(region["id"] as? String), box = try require(region["box"] as? [Int])
                guard id == "p\(number)-f\(ordinal+1)", box.count == 4 else { throw NSError(domain: "FictionalRaster", code: 6) }
                let rectangle = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
                guard CGRect(x: 0, y: 0, width: width, height: height).contains(rectangle) else {
                    throw NSError(domain: "FictionalRaster", code: 7)
                }
                let crop = try require(cg.cropping(to: rectangle)), name = "physical-\(id).png"
                let target = root.appendingPathComponent(name)
                guard !FileManager.default.fileExists(atPath: target.path) else { throw NSError(domain: "FictionalRaster", code: 8) }
                let writer = try require(CGImageDestinationCreateWithURL(target as CFURL, "public.png" as CFString, 1, nil))
                CGImageDestinationAddImage(writer, crop, nil)
                guard CGImageDestinationFinalize(writer) else { throw NSError(domain: "FictionalRaster", code: 9) }
                crops.append(["id": id, "file": name, "sha256": try hash(target), "page": number, "box": box])
            }
        }
        guard crops.count == 144, try hash(url) == expectedHash else { throw NSError(domain: "FictionalRaster", code: 10) }
        try JSONSerialization.data(withJSONObject: ["crops": crops], options: .sortedKeys)
            .write(to: root.appendingPathComponent("physical.json"), options: .withoutOverwriting)
        print("ORT_IOS_RASTER pages=6 physicalCrops=144 actualOCRCalls=0")
    }
}
