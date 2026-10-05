#if canImport(Vision) && canImport(PDFKit) && canImport(UIKit)
import Foundation
import CryptoKit
import Vision
import PDFKit
import UIKit

@available(iOS 26.0, *)
struct RecoveryRecognizedPage: Sendable {
    var page: Int
    var width: Int
    var height: Int
    var observations: [DocumentObservation]
    // Keep words, lines, tables and merged-cell ranges intact for deterministic layout binding.
    // OCR completion does not prove that an unrecognized cell is empty.
    var inputState: RecoveryInputState = .complete
}
@available(iOS 26.0, *)
enum PDFRecoveryRecognition {
    static func read(_ url: URL, foreground: Bool, only: Set<Int>? = nil, check: () throws -> Void) async throws -> [RecoveryRecognizedPage] {
        guard foreground, let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= MaterialLibrary.maximumBytes,
              let document = PDFDocument(url: url), !document.isLocked, (1...12).contains(document.pageCount) else {
            throw PDFParseError(code: .unreadable)
        }
        var pages = [RecoveryRecognizedPage]()
        for index in 0..<document.pageCount where only == nil || only!.contains(index + 1) {
            try check(); try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw PDFParseError(code: .unreadable, page: index + 1) }
            let bounds = page.bounds(for: .cropBox)
            guard bounds.width > 0, bounds.height > 0, bounds.width.isFinite, bounds.height.isFinite else { throw PDFParseError(code: .unreadable, page: index + 1) }
            let scale = min(2, 2048 / max(bounds.width, bounds.height))
            let image = page.thumbnail(of: CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale)), for: .cropBox)
            guard let raster = image.cgImage else { throw PDFParseError(code: .unreadable, page: index + 1) }
            // One bounded page per request; no page image goes to a language model.
            let observations = try await RecognizeDocumentsRequest().perform(on: raster)
            try check(); try Task.checkCancellation()
            guard observations.count <= 1000 else { throw PDFParseError(code: .limit, page: index + 1) }
            pages.append(RecoveryRecognizedPage(page: index + 1, width: raster.width, height: raster.height, observations: observations))
        }
        return pages
    }
    struct LayoutPage: Sendable { var page: Int; var layout: PDFPageLayout; var raster: RecoveryRasterGrid }
    struct Draft: Sendable {
        let acquisition: RecoveryOCRAcquisitionDraft
        let rasters: [Int: RecoveryRasterGrid]
        let nativePages: [RecoveryRecognizedPage]

        /// Acquisition evidence only. Caller must prove topology, field ownership and
        /// full ink coverage before offering any manual correction. Not an accepted layout.
        func capturedLayouts(check: () throws -> Void) throws -> [LayoutPage] {
            _ = try acquisition.assess(check: check)
            return try makeLayouts(check: check)
        }
        func strictLayouts(check: () throws -> Void) throws -> [LayoutPage] {
            let assessment: RecoveryOCRAcquisitionAssessment
            do { assessment = try acquisition.assess(check: check) }
            catch let failure as RecoveryOCRAcquisitionFailure {
                switch failure {
                case .limit: throw PDFParseError(code: .limit)
                case .characterMapping: throw PDFParseError(code: .ambiguous, stage: .characterMapping)
                case .confidence: throw PDFParseError(code: .ambiguous, stage: .rasterInput)
                case .incomplete, .invalidInventory: throw PDFParseError(code: .ambiguous)
                }
            }
            guard assessment.directLayoutsAllowed else { throw PDFParseError(code: .ambiguous, stage: .rasterInput) }
            return try makeLayouts(check: check)
        }
        private func makeLayouts(check: () throws -> Void) throws -> [LayoutPage] {
            var output = [LayoutPage]()
            for page in acquisition.pages {
                try check(); try Task.checkCancellation()
                guard let raster = rasters[page.page] else { throw PDFParseError(code: .unreadable, page: page.page) }
                var glyphs = [PDFGlyph](), order = 0
                for line in page.lines {
                    for character in line.candidates[0].characters {
                        if order % 128 == 0 { try check(); try Task.checkCancellation() }
                        guard let range = character.range else { throw PDFParseError(code: .ambiguous, stage: .characterMapping) }
                        glyphs.append(PDFGlyph(text: character.text, x: range.x, y: range.y,
                                               width: range.width, height: range.height,
                                               sourceLine: line.nativeOrder, sourceOrder: order))
                        order += 1
                    }
                }
                let rules = try raster.rules(check: check)
                output.append(LayoutPage(page: page.page,
                    layout: PDFPageLayout(width: Double(page.width), height: Double(page.height), glyphs: glyphs, lines: rules),
                    raster: try raster.preparingRules(rules, check: check)))
            }
            return output
        }
    }
    static func layouts(_ url: URL, only: Set<Int>?, check: () throws -> Void) async throws -> [LayoutPage] {
        if only?.isEmpty == true { return [] }
        return try await acquire(url, only: only, check: check).strictLayouts(check: check)
    }
    /// Capture all required page outputs before evaluating confidence. No incomplete
    /// acquisition or early `.85` failure becomes a small human-correction count.
    static func acquire(_ url: URL, only: Set<Int>?, expectedPDFHash: String? = nil, check: () throws -> Void) async throws -> Draft {
        let snapshot: Data
        do { snapshot = try RecoveryOCRSourceSnapshot.read(url, maximumBytes: MaterialLibrary.maximumBytes, check: check) }
        catch let failure as RecoveryOCRSnapshotFailure {
            throw PDFParseError(code: failure == .limit ? .limit : .unreadable)
        }
        let pdfHash = SHA256.hash(data: snapshot).map { String(format: "%02x", $0) }.joined()
        guard expectedPDFHash == nil || expectedPDFHash == pdfHash else { throw PDFParseError(code: .cancelled) }
        guard let document = PDFDocument(data: snapshot), !document.isLocked, (1...12).contains(document.pageCount) else {
            throw PDFParseError(code: .unreadable)
        }
        let required = only?.sorted() ?? Array(1...document.pageCount)
        guard !required.isEmpty, required.allSatisfy({ (1...document.pageCount).contains($0) }) else {
            throw PDFParseError(code: .ambiguous)
        }
        var output = [RecoveryOCRPage](), native = [RecoveryRecognizedPage](), rasters = [Int: RecoveryRasterGrid]()
        var structureWork = 0
        for number in required {
            try check(); try Task.checkCancellation()
            guard let page = document.page(at: number - 1) else { throw PDFParseError(code: .unreadable, page: number) }
            let bounds = page.bounds(for: .cropBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
                throw PDFParseError(code: .limit, page: number)
            }
            let scale = min(2, 2048 / max(bounds.width, bounds.height))
            let w = Int(ceil(bounds.width * scale)), h = Int(ceil(bounds.height * scale))
            guard w > 0, h > 0, w <= 2048, h <= 2048 else { throw PDFParseError(code: .limit, page: number) }
            let image = page.thumbnail(of: CGSize(width: CGFloat(w), height: CGFloat(h)), for: .cropBox)
            guard let cg = image.cgImage, cg.width <= 2048, cg.height <= 2048 else {
                throw PDFParseError(code: .unreadable, page: number)
            }
            var rgba = [UInt8](repeating: 255, count: cg.width * cg.height * 4)
            let made = rgba.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: cg.width, height: cg.height,
                    bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
                context.setFillColor(gray: 1, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
                context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
                return true
            }
            guard made else { throw PDFParseError(code: .unreadable, page: number) }
            let raster = try RecoveryRasterGrid.fromRGBA(width: cg.width, height: cg.height, pixels: rgba, check: check)
            let observations = try await RecognizeDocumentsRequest().perform(on: cg)
            try check(); try Task.checkCancellation()
            guard observations.count <= 1000 else { throw PDFParseError(code: .limit, page: number) }
            var lines = [RecoveryOCRLine](), capturedCharacters = 0, capturedBytes = 0
            var hierarchyCharacters = 0, hierarchyBytes = 0
            func consumeStructure() throws {
                structureWork += 1
                guard structureWork <= 2_000_000 else { throw PDFParseError(code: .limit, page: number) }
                if structureWork % 128 == 0 { try check(); try Task.checkCancellation() }
            }
            func captureLine(_ line: RecognizedTextObservation, order: Int, hierarchy: Bool) throws -> RecoveryOCRLine {
                try check(); try Task.checkCancellation()
                var candidates = [RecoveryOCRCandidate]()
                for candidate in line.topCandidates(5) {
                    var characters = [RecoveryOCRCharacter]()
                    let text = candidate.string
                    for start in text.indices {
                        if capturedCharacters % 128 == 0 { try check(); try Task.checkCancellation() }
                        if hierarchy { hierarchyCharacters += 1 } else { capturedCharacters += 1 }
                        guard capturedCharacters <= 100_000, hierarchyCharacters <= 200_000 else { throw PDFParseError(code: .limit, page: number) }
                        let end = text.index(after: start), characterText = String(text[start..<end])
                        for _ in characterText.utf8 {
                            if hierarchy { hierarchyBytes += 1; try consumeStructure() } else { capturedBytes += 1 }
                            guard capturedBytes <= 1_048_576, hierarchyBytes <= 2_097_152 else { throw PDFParseError(code: .limit, page: number) }
                            if capturedBytes % 128 == 0 { try check(); try Task.checkCancellation() }
                        }
                        let range = candidate.boundingBox(for: start..<end).map { rectangle -> RecoveryOCRRange in
                            let b = rectangle.boundingBox.cgRect
                            return RecoveryOCRRange(x: Double(b.minX * CGFloat(cg.width)),
                                y: Double((1 - b.maxY) * CGFloat(cg.height)),
                                width: Double(b.width * CGFloat(cg.width)), height: Double(b.height * CGFloat(cg.height)))
                        }
                        characters.append(RecoveryOCRCharacter(text: characterText, range: range))
                    }
                    candidates.append(RecoveryOCRCandidate(text: text, confidence: Double(candidate.confidence), characters: characters))
                }
                return RecoveryOCRLine(nativeOrder: order, candidates: candidates)
            }
            func captureRegion(_ region: NormalizedRegion) throws -> [RecoveryOCRNativePoint] {
                guard region.pointCount <= 4096 else { throw PDFParseError(code: .limit, page: number) }
                return try region.normalizedPoints.map { point in
                    try consumeStructure()
                    return RecoveryOCRNativePoint(x: Double(point.x), y: Double(point.y))
                }
            }
            func captureCell(_ cell: DocumentObservation.Container.Table.Cell) throws -> RecoveryOCRNativeCell {
                try consumeStructure()
                let content = cell.content
                guard content.text.lines.count <= 100_000 else { throw PDFParseError(code: .limit, page: number) }
                for _ in content.text.transcript.utf8 { try consumeStructure() }
                let cellLines = try content.text.lines.enumerated().map {
                    try captureLine($0.element, order: $0.offset, hierarchy: true)
                }
                return RecoveryOCRNativeCell(rowLower: cell.rowRange.lowerBound, rowUpper: cell.rowRange.upperBound,
                    columnLower: cell.columnRange.lowerBound, columnUpper: cell.columnRange.upperBound,
                    contentRegion: try captureRegion(content.text.boundingRegion), transcript: content.text.transcript,
                    lines: cellLines, nestedTableCount: content.tables.count)
            }
            func captureAxis(_ groups: [[DocumentObservation.Container.Table.Cell]]) throws -> [[RecoveryOCRNativeCell]] {
                guard groups.count <= 100_000 else { throw PDFParseError(code: .limit, page: number) }
                return try groups.map { group in
                    try consumeStructure()
                    guard group.count <= 100_000 else { throw PDFParseError(code: .limit, page: number) }
                    return try group.map(captureCell)
                }
            }
            var documents = [RecoveryOCRNativeDocument]()
            for (documentOrder, observation) in observations.enumerated() {
                try consumeStructure()
                let firstLine = lines.count
                for line in observation.document.text.lines {
                    guard lines.count < 100_000 else { throw PDFParseError(code: .limit, page: number) }
                    lines.append(try captureLine(line, order: lines.count, hierarchy: false))
                }
                guard observation.document.tables.count <= 1000 else { throw PDFParseError(code: .limit, page: number) }
                let tables = try observation.document.tables.enumerated().map { tableOrder, table in
                    try consumeStructure()
                    return RecoveryOCRNativeTable(nativeOrder: tableOrder, region: try captureRegion(table.boundingRegion),
                        rows: try captureAxis(table.rows), columns: try captureAxis(table.columns))
                }
                documents.append(RecoveryOCRNativeDocument(nativeOrder: documentOrder, nativeUUID: observation.uuid.uuidString,
                    lineOrders: Array(firstLine..<lines.count), tables: tables))
            }
            output.append(RecoveryOCRPage(page: number, width: cg.width, height: cg.height,
                nativeDocumentCount: observations.count, lines: lines, captureComplete: true,
                structure: RecoveryOCRPageStructure(documents: documents)))
            native.append(RecoveryRecognizedPage(page: number, width: cg.width, height: cg.height, observations: observations))
            rasters[number] = raster
        }
        guard try snapshotHash(url, check: check) == pdfHash else { throw PDFParseError(code: .cancelled) }
        return Draft(acquisition: RecoveryOCRAcquisitionDraft(sourcePDFHash: pdfHash, documentPageCount: document.pageCount,
            requiredOCRPages: required, pages: output), rasters: rasters, nativePages: native)
    }

    private static func snapshotHash(_ url: URL, check: () throws -> Void) throws -> String {
        guard let stream = InputStream(url: url) else { throw PDFParseError(code: .unreadable) }
        stream.open(); defer { stream.close() }
        var hash = SHA256(), total = 0, buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            try check(); try Task.checkCancellation()
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw PDFParseError(code: .unreadable) }
            if count == 0 { break }
            total += count
            guard total <= MaterialLibrary.maximumBytes else { throw PDFParseError(code: .limit) }
            hash.update(data: Data(buffer.prefix(count)))
        }
        guard total > 0 else { throw PDFParseError(code: .unreadable) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }


}
#endif
