import SwiftUI
import UIKit
import CryptoKit
import UserNotifications
import PDFKit
import ZIPFoundation

// This runs the production renderer, Vision recognition and grayscale checks.
// The PDF contains only a raster image; no extracted text or preview is injected.
@MainActor
enum SimulatorRecoveryOCRFixture {
    // Generated test target only. Run on the actual production PDF bitmap,
    // before Vision can safely reject its candidate confidence.
    nonisolated static func rasterProof(_ input: RecoveryRasterGrid) -> String {
        do {
            let lines = try input.rules(check: {})
            let raster = try input.preparingRules(lines, check: {})
            let scale = Double(raster.height) / 800
            guard
                let line = lines.first(where: {
                    $0.horizontal && abs($0.y1 - 140.5 * scale) <= 3
                        && $0.x2 - $0.x1 > Double(raster.width) * 0.95
                }),
                raster.dark(raster.width / 2, Int(line.y1.rounded())),
                !raster.dark(raster.width / 2, raster.height - 1 - Int(line.y1.rounded()))
            else { return "実rasterの上端座標・罫線が不一致" }
            let text = RecoveryBox(x: 10 * scale, y: 20 * scale, width: 550 * scale, height: 70 * scale)
            let blank = RecoveryBox(x: 10 * scale, y: 550 * scale, width: 550 * scale, height: 200 * scale)
            let rule = RecoveryBox(x: 10 * scale, y: 125 * scale, width: 550 * scale, height: 30 * scale)
            guard raster.hasUncoveredInk(text, text: [], rules: lines),
                !raster.hasUncoveredInk(rule, text: [], rules: lines),
                raster.isBlank(blank), !raster.hasUncoveredInk(blank, text: [], rules: lines)
            else { return "実rasterの未読インク・空欄が不一致" }
            return "実raster・上端座標・罫線・未読インク・空欄検証済み"
        } catch { return "実raster検証失敗: " + String(describing: error) }
    }
    nonisolated static func cropRasterProof(_ input: RecoveryRasterGrid, clipped: Bool) -> String {
        let expectedHeight = clipped ? 400 : 1600
        guard input.width == 1200, input.height == expectedHeight else {
            return "CropBox寸法不一致: \(input.width)x\(input.height), expected=1200x\(expectedHeight)"
        }
        let header = RecoveryBox(x: 20, y: 40, width: 1100, height: 160)
        guard input.hasUncoveredInk(header, text: [], rules: []) else { return "CropBoxの上部本文が欠落" }
        if clipped {
            let lowerVisible = RecoveryBox(x: 400, y: 320, width: 400, height: 60)
            guard input.isBlank(lowerVisible), !input.hasUncoveredInk(lowerVisible, text: [], rules: [])
            else { return "CropBox外のfooterが混入" }
        } else {
            guard input.dark(600, 1380) else { return "全ページの架空footerが描画されていない" }
        }
        return clipped ? "CropBox1200x400・footer除外" : "MediaBox1200x1600・footer存在"
    }
    private static func checkCrop(_ root: URL, image: UIImage, size: CGSize) async throws {
        let full = root.appendingPathComponent("fictional-crop-full.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).writePDF(to: full) { context in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
            // A known footer marker is below the header-only CropBox.
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(x: 250, y: 660, width: 100, height: 60))
        }
        guard let document = PDFDocument(url: full), let page = document.page(at: 0) else {
            throw PDFParseError(code: .unreadable)
        }
        page.setBounds(CGRect(x: 0, y: 600, width: 600, height: 200), for: .cropBox)
        let cropped = root.appendingPathComponent("fictional-crop-header.pdf")
        guard document.write(to: cropped), let saved = PDFDocument(url: cropped)?.page(at: 0),
            saved.bounds(for: .mediaBox).size == size,
            saved.bounds(for: .cropBox) == CGRect(x: 0, y: 600, width: 600, height: 200)
        else { throw PDFParseError(code: .ambiguous) }
        defer {
            UserDefaults.standard.removeObject(forKey: "fixture.nativeCropMode")
            UserDefaults.standard.removeObject(forKey: "fixture.nativeCropRasterProof")
        }
        for (url, mode, expected) in [
            (full, "full", "MediaBox1200x1600・footer存在"), (cropped, "cropped", "CropBox1200x400・footer除外"),
        ] {
            UserDefaults.standard.set(mode, forKey: "fixture.nativeCropMode")
            UserDefaults.standard.removeObject(forKey: "fixture.nativeCropRasterProof")
            do { _ = try await PDFRecoveryRecognition.layouts(url, only: [1], check: {}) } catch {
                print("SYNTHETIC_NATIVE_CROP recognition ended: " + String(describing: error))
            }
            let observed = UserDefaults.standard.string(forKey: "fixture.nativeCropRasterProof") ?? "未取得"
            guard observed == expected else {
                throw NSError(
                    domain: "SyntheticNativeCrop", code: 1, userInfo: [NSLocalizedDescriptionKey: observed])
            }
            print("SYNTHETIC_NATIVE_CROP_RESULT " + observed)
        }
    }
    private static func checkTableCapture(_ root: URL) async throws {
        let size = CGSize(width: 600, height: 400)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let expected = ["3_CN", "月", "1", "架空光学", "架空担当甲", "R701"]
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.setStrokeColor(UIColor.black.cgColor)
            context.cgContext.setLineWidth(2)
            for x in [20, 200, 380, 560] {
                context.cgContext.move(to: CGPoint(x: CGFloat(x), y: 20))
                context.cgContext.addLine(to: CGPoint(x: CGFloat(x), y: 380))
            }
            for y in [20, 200, 380] {
                context.cgContext.move(to: CGPoint(x: 20, y: CGFloat(y)))
                context.cgContext.addLine(to: CGPoint(x: 560, y: CGFloat(y)))
            }
            context.cgContext.strokePath()
            for (index, text) in expected.enumerated() {
                let point = CGPoint(x: CGFloat(35 + (index % 3) * 180), y: CGFloat(80 + (index / 3) * 180))
                (text as NSString).draw(
                    at: point,
                    withAttributes: [.font: UIFont.systemFont(ofSize: 24), .foregroundColor: UIColor.black])
            }
        }
        let url = root.appendingPathComponent("fictional-unlabelled-table.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).writePDF(to: url) { context in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard (PDFDocument(url: url)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw PDFParseError(code: .ambiguous) }
        let draft = try await PDFRecoveryRecognition.acquire(url, only: [1], check: {})
        guard let captured = draft.acquisition.pages.first, let native = draft.nativePages.first,
            let structure = captured.structure, structure.documents.count == native.observations.count
        else { throw PDFParseError(code: .ambiguous) }
        let nativeTables = native.observations.flatMap { $0.document.tables }
        let capturedTables = structure.documents.flatMap { $0.tables }
        guard nativeTables.count == capturedTables.count else { throw PDFParseError(code: .ambiguous) }
        for (table, copy) in zip(nativeTables, capturedTables) {
            guard table.rows.count == copy.rows.count, table.columns.count == copy.columns.count else {
                throw PDFParseError(code: .ambiguous)
            }
            for (row, copiedRow) in zip(table.rows, copy.rows) {
                guard row.count == copiedRow.count else { throw PDFParseError(code: .ambiguous) }
                for (cell, copiedCell) in zip(row, copiedRow) {
                    guard cell.content.text.transcript == copiedCell.transcript,
                        cell.content.text.lines.count == copiedCell.lines.count,
                        cell.rowRange.lowerBound == copiedCell.rowLower,
                        cell.rowRange.upperBound == copiedCell.rowUpper,
                        cell.columnRange.lowerBound == copiedCell.columnLower,
                        cell.columnRange.upperBound == copiedCell.columnUpper
                    else { throw PDFParseError(code: .ambiguous) }
                }
            }
        }
        let raw = captured.lines.compactMap { $0.candidates.first?.text }
        let exact = expected.filter { raw.contains($0) }.count
        var linkStatus = "inventory-accepted"
        do { _ = try draft.acquisition.assess() } catch {
            linkStatus = "inventory-refused: " + String(describing: error)
        }
        let summary =
            "SYNTHETIC_NATIVE_TABLE_CAPTURE expectedLiterals=6 rawExactLiterals=\(exact) nativeTables=\(nativeTables.count) capturedTables=\(capturedTables.count) rawLines=\(raw.count) linkStatus=\(linkStatus) wholeDocumentQuality=UNASSESSED"
        UserDefaults.standard.set(summary, forKey: "fixture.nativeTableCapture")
        print(summary)
    }
    static func check() async throws -> String {
        UserDefaults.standard.removeObject(forKey: "fixture.nativeTableCapture")
        for key in [
            "fixture.nativeOCRCandidates", "fixture.nativeOCRText", "fixture.nativeOCRConfidence",
            "fixture.nativeRasterProof",
        ] { UserDefaults.standard.removeObject(forKey: key) }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "takupoke-ocr-ui-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let size = CGSize(width: 600, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ("これは架空の時間割です" as NSString).draw(
                at: CGPoint(x: 20, y: 32),
                withAttributes: [.font: UIFont.systemFont(ofSize: 32), .foregroundColor: UIColor.black])
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 140, width: 600, height: 1))
            context.cgContext.fill(CGRect(x: 0, y: 500, width: 600, height: 1))
            context.cgContext.fill(CGRect(x: 0, y: 140, width: 1, height: 361))
            context.cgContext.fill(CGRect(x: 599, y: 140, width: 1, height: 361))
        }
        try await checkTableCapture(root)
        try await checkCrop(root, image: image, size: size)
        for key in [
            "fixture.nativeOCRCandidates", "fixture.nativeOCRText", "fixture.nativeOCRConfidence",
            "fixture.nativeRasterProof",
        ] { UserDefaults.standard.removeObject(forKey: key) }
        let url = root.appendingPathComponent("fictional-image-only.pdf")
        try UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).writePDF(to: url) { context in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let pdf = PDFDocument(url: url), pdf.pageCount == 1,
            (pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw PDFParseError(code: .ambiguous) }
        let pages: [PDFRecoveryRecognition.LayoutPage]
        do { pages = try await PDFRecoveryRecognition.layouts(url, only: [1], check: {}) } catch {
            let candidates = UserDefaults.standard.stringArray(forKey: "fixture.nativeOCRCandidates") ?? []
            let text = UserDefaults.standard.string(forKey: "fixture.nativeOCRText")
            let confidence = UserDefaults.standard.object(forKey: "fixture.nativeOCRConfidence") as? Double
            let raster = UserDefaults.standard.string(forKey: "fixture.nativeRasterProof")
            if let failure = error as? PDFParseError, failure.code == .ambiguous,
                failure.stage == .rasterInput,
                text == "これは架空の時間割です", let confidence, confidence.isFinite, confidence >= 0,
                confidence < 0.85,
                raster == "実raster・上端座標・罫線・未読インク・空欄検証済み"
            {
                print("SYNTHETIC_NATIVE_OCR safelyRejected confidence=\(confidence), rasterProof=\(raster!)")
                return
                    "CropBox/footer検証済み; 低信頼OCRを安全拒否・実raster・上端座標・罫線・未読インク・空欄検証済み; confidence=\(confidence)"
            }
            throw NSError(
                domain: "SyntheticNativeOCR", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: String(describing: error) + "; candidates="
                        + candidates.joined(separator: " | ") + "; raster=" + (raster ?? "未取得")
                ])
        }
        guard pages.count == 1, let page = pages.first else { throw PDFParseError(code: .unreadable) }
        let layout = page.layout
        let raster = page.raster
        let text = layout.glyphs.map(\.text).joined().filter { !$0.isWhitespace }
        guard text == "これは架空の時間割です", !layout.glyphs.isEmpty,
            layout.glyphs.allSatisfy({
                $0.y < layout.height * 0.15 && $0.x >= 0 && $0.width > 0 && $0.height > 0
            })
        else { throw PDFParseError(code: .ambiguous, stage: .characterMapping) }
        let scale = layout.height / 800
        guard
            let line = layout.lines.first(where: {
                $0.horizontal && abs($0.y1 - 140.5 * scale) <= 3 && $0.x2 - $0.x1 > layout.width * 0.95
            }),
            raster.dark(raster.width / 2, Int(line.y1.rounded())),
            !raster.dark(raster.width / 2, raster.height - 1 - Int(line.y1.rounded()))
        else {
            let horizontal = layout.lines.filter(\.horizontal).map { String(format: "%.1f", $0.y1) }.joined(
                separator: ",")
            throw NSError(
                domain: "SyntheticOCRProbe", code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "rule/orientation h=\(layout.height), expected=\(140.5 * scale), horizontal=\(horizontal), grayAtExpected=\(raster.grayscale[Int(140.5 * scale) * raster.width + raster.width / 2])"
                ])
        }
        let textRegion = RecoveryBox(x: 10 * scale, y: 20 * scale, width: 550 * scale, height: 70 * scale)
        let blankRegion = RecoveryBox(x: 10 * scale, y: 550 * scale, width: 550 * scale, height: 200 * scale)
        let ruleRegion = RecoveryBox(x: 10 * scale, y: 125 * scale, width: 550 * scale, height: 30 * scale)
        guard raster.hasUncoveredInk(textRegion, text: [], rules: layout.lines),
            !raster.hasUncoveredInk(ruleRegion, text: [], rules: layout.lines),
            raster.isBlank(blankRegion),
            !raster.hasUncoveredInk(blankRegion, text: [], rules: layout.lines)
        else {
            throw NSError(
                domain: "SyntheticOCRProbe", code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "ink: text=\(raster.hasUncoveredInk(textRegion, text: [], rules: layout.lines)), rule=\(raster.hasUncoveredInk(ruleRegion, text: [], rules: layout.lines)), blank=\(raster.isBlank(blankRegion)), blankInk=\(raster.hasUncoveredInk(blankRegion, text: [], rules: layout.lines))"
                ])
        }
        return "CropBox/footer検証済み; OCR・上端座標・罫線・未読インク検証済み"
    }
}

