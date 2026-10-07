#if canImport(Vision)
import Foundation
import Vision
import CoreGraphics

/// The same production acquisition adapter is compiled for iPhone and exercised
/// on macOS. No table region becomes timetable topology and no candidate changes.
@available(iOS 26.0, macOS 26.0, *)
enum RecoveryVisionCapture {
    static func request() -> RecognizeDocumentsRequest {
        var request = RecognizeDocumentsRequest()
        // Source text includes Japanese names and Latin class/room symbols.
        // Keep native correction, candidate count and confidence unchanged.
        request.textRecognitionOptions.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
        request.textRecognitionOptions.automaticallyDetectLanguage = false
        return request
    }
    static func page(_ number: Int, width: Int, height: Int, observations: [DocumentObservation],
                     work: inout Int, check: () throws -> Void) throws -> RecoveryOCRPage {
        guard (1...12).contains(number), (1...2048).contains(width), (1...2048).contains(height),
              observations.count <= 1000, (0...2_000_000).contains(work) else {
            throw RecoveryOCRAcquisitionFailure.limit
        }
        try check(); try Task.checkCancellation()
        var structureWork = work
        defer { work = structureWork }
        var lines = [RecoveryOCRLine](), capturedCharacters = 0, capturedBytes = 0
        var hierarchyCharacters = 0, hierarchyBytes = 0
        func consumeStructure() throws {
            structureWork += 1
            guard structureWork <= 2_000_000 else { throw RecoveryOCRAcquisitionFailure.limit }
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
                    guard capturedCharacters <= 100_000, hierarchyCharacters <= 200_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                    let end = text.index(after: start), characterText = String(text[start..<end])
                    for _ in characterText.utf8 {
                        if hierarchy { hierarchyBytes += 1; try consumeStructure() } else { capturedBytes += 1 }
                        guard capturedBytes <= 1_048_576, hierarchyBytes <= 2_097_152 else { throw RecoveryOCRAcquisitionFailure.limit }
                        if capturedBytes % 128 == 0 { try check(); try Task.checkCancellation() }
                    }
                    let range = candidate.boundingBox(for: start..<end).map { rectangle -> RecoveryOCRRange in
                        let b = rectangle.boundingBox.cgRect
                        return RecoveryOCRRange(x: Double(b.minX * CGFloat(width)),
                            y: Double((1 - b.maxY) * CGFloat(height)),
                            width: Double(b.width * CGFloat(width)), height: Double(b.height * CGFloat(height)))
                    }
                    characters.append(RecoveryOCRCharacter(text: characterText, range: range))
                }
                try check(); try Task.checkCancellation()
                let wholeRange = text.isEmpty ? nil : candidate.boundingBox(for: text.startIndex..<text.endIndex).map { rectangle -> RecoveryOCRRange in
                    let b = rectangle.boundingBox.cgRect
                    return RecoveryOCRRange(x: Double(b.minX * CGFloat(width)),
                        y: Double((1 - b.maxY) * CGFloat(height)),
                        width: Double(b.width * CGFloat(width)), height: Double(b.height * CGFloat(height)))
                }
                try check(); try Task.checkCancellation()
                let observed = line.boundingBox.cgRect
                let observationRange = RecoveryOCRRange(x:Double(observed.minX * CGFloat(width)),
                    y:Double((1-observed.maxY)*CGFloat(height)),width:Double(observed.width*CGFloat(width)),
                    height:Double(observed.height*CGFloat(height)))
                candidates.append(RecoveryOCRCandidate(text: text, confidence: Double(candidate.confidence),
                    characters: characters, lineRange: wholeRange, observationRange:observationRange))
            }
            return RecoveryOCRLine(nativeOrder: order, candidates: candidates)
        }
        func captureRegion(_ region: NormalizedRegion) throws -> [RecoveryOCRNativePoint] {
            guard region.pointCount <= 4096 else { throw RecoveryOCRAcquisitionFailure.limit }
            return try region.normalizedPoints.map { point in
                try consumeStructure()
                return RecoveryOCRNativePoint(x: Double(point.x), y: Double(point.y))
            }
        }
        func captureCell(_ cell: DocumentObservation.Container.Table.Cell) throws -> RecoveryOCRNativeCell {
            try consumeStructure()
            let content = cell.content
            guard content.text.lines.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
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
            guard groups.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
            return try groups.map { group in
                try consumeStructure()
                guard group.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                return try group.map(captureCell)
            }
        }
        var documents = [RecoveryOCRNativeDocument]()
        for (documentOrder, observation) in observations.enumerated() {
            try consumeStructure()
            let firstLine = lines.count
            for line in observation.document.text.lines {
                guard lines.count < 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                lines.append(try captureLine(line, order: lines.count, hierarchy: false))
            }
            guard observation.document.tables.count <= 1000 else { throw RecoveryOCRAcquisitionFailure.limit }
            var tables = [RecoveryOCRNativeTable]()
            for (tableOrder, table) in observation.document.tables.enumerated() {
                try consumeStructure()
                let region = try captureRegion(table.boundingRegion)
                let rows = try captureAxis(table.rows)
                let columns = try captureAxis(table.columns)
                let capturedTable = RecoveryOCRNativeTable(nativeOrder: tableOrder, region: region, rows: rows, columns: columns)
                tables.append(capturedTable)
            }
            documents.append(RecoveryOCRNativeDocument(nativeOrder: documentOrder, nativeUUID: observation.uuid.uuidString,
                lineOrders: Array(firstLine..<lines.count), tables: tables))
        }
        return RecoveryOCRPage(page: number, width: width, height: height,
            nativeDocumentCount: observations.count, lines: lines, captureComplete: true,
            structure: RecoveryOCRPageStructure(documents: documents))
    }
}
#endif
