import Foundation
import XCTest
@testable import TakupokeParsing
#if canImport(PDFKit) && canImport(AppKit) && canImport(Vision) && canImport(CryptoKit)
import PDFKit
import AppKit
import Vision
import CryptoKit
import ImageIO

/// This declaration is registered only in the owned research Package copy.
/// Input is an image-only PDF, never a generator's cell boxes or an oracle.
@available(macOS 26.0, *)
final class RecoveryFullSourceProbeTests: XCTestCase {
    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func png(_ image: CGImage, to url: URL) throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
    }
    private func physicalCells(_ page: PDFPageLayout) throws -> [PDFBox] {
        let xs = Array(Set(page.lines.filter(\.vertical).map(\.x1))).sorted()
        let ys = Array(Set(page.lines.filter(\.horizontal).map(\.y1))).sorted()
        guard xs.count <= 128, ys.count <= 128, page.lines.count <= 1000 else {
            throw PDFParseError(code: .limit)
        }
        let grid = PDFGrid(page: page)
        var found = Set<PDFBox>()
        for (a, b) in zip(xs, xs.dropFirst()) {
            for (c, d) in zip(ys, ys.dropFirst()) where b-a > 1 && d-c > 1 {
                try Task.checkCancellation()
                // Missing/open graph samples stay unassigned, not empty cells.
                let box: PDFBox
                do { box = try grid.box((a+b)/2, (c+d)/2, check: { try Task.checkCancellation() }) }
                catch let error as PDFParseError where error.code == .unsupported { continue }
                // Use the production ruled-header support conditions unchanged.
                let horizontal = [box.top, box.bottom].allSatisfy { y in
                    page.lines.contains { $0.horizontal && abs($0.y1-y)<0.3 && $0.x1<=box.left+0.3 && $0.x2>=box.right-0.3 }
                }
                let vertical = [box.left, box.right].allSatisfy { x in
                    page.lines.contains { $0.vertical && abs($0.x1-x)<0.3 && $0.y1<=box.top+0.3 && $0.y2>=box.bottom-0.3 }
                }
                if horizontal && vertical { found.insert(box) }
            }
        }
        return found.sorted { $0.top == $1.top ? $0.left < $1.left : $0.top < $1.top }
    }
    func testAcquireFullOriginalPixelsNativeVisionAndPhysicalRules() async throws {
        guard let folder = ProcessInfo.processInfo.environment["TAKUPOKE_OCR_FULL_INPUTS"],
              let outputFolder = ProcessInfo.processInfo.environment["TAKUPOKE_OCR_FULL_OUTPUT"] else {
            throw XCTSkip("Dedicated independently fictional whole-source study only")
        }
        let root = URL(fileURLWithPath: folder, isDirectory: true)
        let output = URL(fileURLWithPath: outputFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("inputs.json"))) as? [String: Any])
        XCTAssertEqual(Set(manifest.keys), ["documents"])
        let entries = try XCTUnwrap(manifest["documents"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 6)
        var documents = [[String: Any]](), work = 0
        for entry in entries {
            XCTAssertEqual(Set(entry.keys), ["id", "kind", "pdf", "pdfSHA256", "pageCount"])
            let id = try XCTUnwrap(entry["id"] as? String), kind = try XCTUnwrap(entry["kind"] as? String)
            XCTAssertTrue(["f1-timetable", "f1-exam", "f1-return", "f2-timetable", "f2-exam", "f2-return"].contains(id))
            XCTAssertTrue(["timetable", "exam", "return"].contains(kind))
            let filename = try XCTUnwrap(entry["pdf"] as? String), digest = try XCTUnwrap(entry["pdfSHA256"] as? String)
            XCTAssertEqual(filename, id + ".pdf")
            let bytes = try Data(contentsOf: root.appendingPathComponent(filename))
            XCTAssertEqual(hash(bytes), digest)
            let pdf = try XCTUnwrap(PDFDocument(data: bytes))
            XCTAssertEqual(pdf.pageCount, 1)
            let page = try XCTUnwrap(pdf.page(at: 0))
            XCTAssertEqual(page.rotation, 0) // This initial cohort does not qualify rotations.
            let bounds = page.bounds(for: .cropBox), scale = min(2, 2048/max(bounds.width, bounds.height))
            let thumbnail = page.thumbnail(of: NSSize(width: ceil(bounds.width*scale), height: ceil(bounds.height*scale)), for: .cropBox)
            let cg = try XCTUnwrap(thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertLessThanOrEqual(max(cg.width, cg.height), 2048)
            var rgba = [UInt8](repeating: 255, count: cg.width*cg.height*4)
            try rgba.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                    bitsPerComponent: 8, bytesPerRow: cg.width*4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.setFillColor(gray: 1, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
                context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
            }
            let raster = try RecoveryRasterGrid.fromRGBA(width: cg.width, height: cg.height, pixels: rgba)
            let rules = try raster.rules(check: { try Task.checkCancellation() })
            let prepared = try raster.preparingRules(rules, check: { try Task.checkCancellation() })
            let mask = try XCTUnwrap(prepared.fullSourceStudyMask)
            let cells = try physicalCells(.init(width: Double(cg.width), height: Double(cg.height), glyphs: [], lines: rules))
            let request = RecognizeDocumentsRequest()
            let observations = try await request.perform(on: cg)
            let capture = try RecoveryVisionCapture.page(1, width: cg.width, height: cg.height,
                observations: observations, work: &work, check: { try Task.checkCancellation() })
            let pngName = id + ".png", grayName = id + ".gray", maskName = id + ".mask", captureName = id + "-vision.json"
            try png(cg, to: output.appendingPathComponent(pngName))
            let gray = Data(raster.grayscale), maskData = Data(mask)
            try gray.write(to: output.appendingPathComponent(grayName), options: .withoutOverwriting)
            try maskData.write(to: output.appendingPathComponent(maskName), options: .withoutOverwriting)
            let encoded = try JSONEncoder().encode(capture)
            try encoded.write(to: output.appendingPathComponent(captureName), options: .withoutOverwriting)
            for line in capture.lines {
                let first = try XCTUnwrap(line.candidates.first), box = try XCTUnwrap(first.observationRange)
                let raw: [String: Any] = ["id": id, "nativeOrder": line.nativeOrder,
                    "text": first.text, "confidence": first.confidence,
                    "box": [box.x, box.y, box.width, box.height],
                    "nativeCandidates": line.candidates.map { ["text": $0.text, "confidence": $0.confidence] as [String: Any] }]
                let data = try JSONSerialization.data(withJSONObject: raw, options: .sortedKeys)
                print("FULL_SOURCE_VISION " + String(decoding: data, as: UTF8.self))
            }
            documents.append(["id": id, "kind": kind, "sourcePDFSHA256": digest,
                "width": cg.width, "height": cg.height, "pdfWidth": Double(bounds.width), "pdfHeight": Double(bounds.height),
                "image": pngName, "imageSHA256": hash(try Data(contentsOf: output.appendingPathComponent(pngName))),
                "grayscale": grayName, "grayscaleSHA256": hash(gray), "mask": maskName, "maskSHA256": hash(maskData),
                "nativeCapture": captureName, "nativeCaptureSHA256": hash(encoded),
                "rules": rules.map { [$0.x1, $0.y1, $0.x2, $0.y2] },
                "cells": cells.map { [$0.left, $0.top, $0.right-$0.left, $0.bottom-$0.top] }])
            print("FULL_SOURCE_ACQUIRED id=\(id) cells=\(cells.count) nativeLines=\(capture.lines.count) rules=\(rules.count)")
        }
        XCTAssertEqual(Set(documents.compactMap { $0["id"] as? String }).count, 6)
        let result = try JSONSerialization.data(withJSONObject: ["documents": documents], options: .sortedKeys)
        try result.write(to: output.appendingPathComponent("acquisition.json"), options: .withoutOverwriting)
        print("FULL_SOURCE_CAPTURE_FINISHED pages=6 actualVisionCalls=6")
    }
}
#endif
