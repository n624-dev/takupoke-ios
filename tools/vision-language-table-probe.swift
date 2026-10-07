import AppKit
import CoreText
import CryptoKit
import Foundation
import Vision

// Unseen fictional values in a ruled 8x3 body table. No field-name labels,
// source PDF, inference retry, production adoption or threshold changes.
@main struct VisionLanguageTableProbe {
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
        try emit(["type": "recipe", "recipe": "vision-ja-auto-unseen-body-table-v1", "plannedImages": 2,
            "plannedCalls": 4, "fontPixels": [24, 16], "font": "HiraginoSans-W3", "expected": expected,
            "literalEvaluation": "positions and source table, not inferred aliases", "retry": false,
            "documentQuality": "UNASSESSED", "runtime": ProcessInfo.processInfo.operatingSystemVersionString])
        if CommandLine.arguments == [CommandLine.arguments[0], "--preflight"] { return }
        guard CommandLine.arguments.count == 1 else { throw CocoaError(.featureUnsupported) }
        let start = ProcessInfo.processInfo.systemUptime; var attempted = 0
        for size in [24, 16] {
            let input = try image(size: size)
            guard let pixels = input.dataProvider?.data else { throw CocoaError(.fileReadCorruptFile) }
            let hash = SHA256.hash(data: pixels as Data).map { String(format: "%02x", $0) }.joined()
            for condition in ["documents-default", "documents-ja-en-auto"] {
                try Task.checkCancellation()
                guard ProcessInfo.processInfo.systemUptime - start < 240 else { throw CocoaError(.userCancelled) }
                var request = RecognizeDocumentsRequest()
                if condition == "documents-ja-en-auto" {
                    guard request.supportedRecognitionLanguages.contains(where: { $0.languageCode?.identifier == "ja" }) else { throw CocoaError(.featureUnsupported) }
                    request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
                    request.textRecognitionOptions.automaticallyDetectLanguage = true
                }
                attempted += 1
                let observations = try await request.perform(on: input)
                guard observations.count <= 100 else { throw CocoaError(.fileReadCorruptFile) }
                let lines = observations.flatMap { $0.document.text.lines }
                guard lines.count <= 100 else { throw CocoaError(.fileReadCorruptFile) }
                var output = [[String: Any]]()
                for line in lines {
                    let box = line.boundingBox.cgRect
                    output.append(["top1": line.topCandidates(1).first?.string ?? "",
                        "confidence": Double(line.topCandidates(1).first?.confidence ?? 0),
                        "box": [Double(box.minX), Double(1 - box.maxY), Double(box.width), Double(box.height)],
                        "candidates": line.topCandidates(3).map(\.string)])
                }
                var tables = [[String: Any]]()
                for table in observations.flatMap({ $0.document.tables }) {
                    guard tables.count < 100 else { throw CocoaError(.fileReadCorruptFile) }
                    var cells = [[String: Any]]()
                    for row in table.rows {
                        for cell in row {
                            guard cells.count < 100 else { throw CocoaError(.fileReadCorruptFile) }
                            cells.append(["text": cell.content.text.transcript,
                                "row": [cell.rowRange.lowerBound, cell.rowRange.upperBound],
                                "column": [cell.columnRange.lowerBound, cell.columnRange.upperBound],
                                "region": cell.content.text.boundingRegion.normalizedPoints.map { [Double($0.x), Double($0.y)] }])
                        }
                    }
                    tables.append(["rowCount": table.rows.count, "columnCount": table.columns.count, "cells": cells])
                }
                try emit(["type": "result", "condition": condition, "fontPixels": size, "imageSHA256": hash,
                    "lines": output, "tables": tables, "newRecognizerCalls": 1, "formalAdoption": "NOT_ATTEMPTED"])
            }
        }
        guard attempted == 4 else { throw CocoaError(.fileReadCorruptFile) }
        try emit(["type": "summary", "attemptedCalls": attempted, "elapsedSeconds": ProcessInfo.processInfo.systemUptime - start,
            "wholeDocumentQuality": "UNASSESSED", "qualifiedModels": [String](), "imagesWrittenToDisk": 0])
        print("VISION_JA_AUTO_TABLE_COMPLETE_CALLS_4_NO_QUALIFICATION")
    }
}
