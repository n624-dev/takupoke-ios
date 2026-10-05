import Foundation

enum RecoveryOCRSnapshotFailure: Error, Equatable { case unreadable, limit }
enum RecoveryOCRSourceSnapshot {
    /// Copy into owned bytes; never map mutable file storage or open the PDF first.
    static func read(_ url: URL, maximumBytes: Int, check: () throws -> Void = {}) throws -> Data {
        try check(); try Task.checkCancellation()
        guard maximumBytes > 0, maximumBytes <= 50 * 1024 * 1024 else { throw RecoveryOCRSnapshotFailure.limit }
        guard let stream = InputStream(url: url) else { throw RecoveryOCRSnapshotFailure.unreadable }
        stream.open(); defer { stream.close() }
        var snapshot = Data(), buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            try check(); try Task.checkCancellation()
            let count = stream.read(&buffer, maxLength: min(buffer.count, maximumBytes - snapshot.count + 1))
            guard count >= 0 else { throw RecoveryOCRSnapshotFailure.unreadable }
            if count == 0 { break }
            guard count <= maximumBytes - snapshot.count else { throw RecoveryOCRSnapshotFailure.limit }
            snapshot.append(contentsOf: buffer.prefix(count))
        }
        guard !snapshot.isEmpty else { throw RecoveryOCRSnapshotFailure.unreadable }
        try check(); try Task.checkCancellation()
        return snapshot
    }
}

/// Ephemeral native output. User edits must never replace these records or their confidence.
struct RecoveryOCRRange: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    func isInside(width pageWidth: Int, height pageHeight: Int) -> Bool {
        [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite) &&
        x >= 0 && y >= 0 && width > 0 && height > 0 &&
        x + width <= Double(pageWidth) && y + height <= Double(pageHeight)
    }
}
struct RecoveryOCRCharacter: Codable, Equatable, Sendable {
    let text: String
    let range: RecoveryOCRRange?
}
struct RecoveryOCRCandidate: Codable, Equatable, Sendable {
    let text: String
    let confidence: Double
    let characters: [RecoveryOCRCharacter]
}
struct RecoveryOCRLine: Codable, Equatable, Sendable {
    let nativeOrder: Int
    /// Original native ranking, without deduplication or alternate selection.
    let candidates: [RecoveryOCRCandidate]
}
struct RecoveryOCRPage: Codable, Equatable, Sendable {
    let page: Int
    let width: Int
    let height: Int
    let nativeDocumentCount: Int
    let lines: [RecoveryOCRLine]
    let captureComplete: Bool
    /// Optional acquisition evidence only. Nil preserves exact legacy JSON bytes.
    var structure: RecoveryOCRPageStructure? = nil
}

enum RecoveryOCRAcquisitionFailure: Error, Equatable {
    case incomplete, invalidInventory, limit, characterMapping, confidence
}
struct RecoveryOCRAcquisitionAssessment: Codable, Equatable, Sendable {
    let documentPageCount: Int
    let requiredOCRPages: [Int]
    let top1Count: Int
    let top1CharacterCount: Int
    /// This is an acquisition count, not a count of independently owned semantic fields.
    let lowConfidenceNativeOrders: [Int: [Int]]
    var directLayoutsAllowed: Bool { lowConfidenceNativeOrders.values.allSatisfy(\.isEmpty) }
}
struct RecoveryOCRAcquisitionDraft: Codable, Equatable, Sendable {
    let sourcePDFHash: String
    let documentPageCount: Int
    let requiredOCRPages: [Int]
    let pages: [RecoveryOCRPage]

    func canonicalData() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Full inventory and mapping validation precedes the confidence count. A page or
    /// candidate omitted after an early failure can never appear as one correctable item.
    func assess(check: () throws -> Void = {}) throws -> RecoveryOCRAcquisitionAssessment {
        try check(); try Task.checkCancellation()
        guard sourcePDFHash.utf8.count == 64, sourcePDFHash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              (1...12).contains(documentPageCount), !requiredOCRPages.isEmpty,
              requiredOCRPages.count <= documentPageCount, pages.count == requiredOCRPages.count,
              requiredOCRPages == requiredOCRPages.sorted(),
              Set(requiredOCRPages).count == requiredOCRPages.count,
              requiredOCRPages.allSatisfy({ (1...documentPageCount).contains($0) }),
              pages.map(\.page) == requiredOCRPages else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
        var work = 0, top1Count = 0, characterCount = 0, low = [Int: [Int]]()
        func consume() throws {
            work += 1
            guard work <= 2_000_000 else { throw RecoveryOCRAcquisitionFailure.limit }
            if work % 128 == 0 { try check(); try Task.checkCancellation() }
        }
        for page in pages {
            try consume()
            guard page.captureComplete else { throw RecoveryOCRAcquisitionFailure.incomplete }
            guard (1...2048).contains(page.width), (1...2048).contains(page.height),
                  (0...1000).contains(page.nativeDocumentCount), page.lines.count <= 100_000 else {
                throw RecoveryOCRAcquisitionFailure.limit
            }
            var pageCharacters = 0, pageBytes = 0
            low[page.page] = []
            for (order, line) in page.lines.enumerated() {
                try consume()
                guard line.nativeOrder == order, (1...5).contains(line.candidates.count) else {
                    throw RecoveryOCRAcquisitionFailure.invalidInventory
                }
                for candidate in line.candidates {
                    try consume()
                    guard !candidate.text.isEmpty, candidate.confidence.isFinite, (0...1).contains(candidate.confidence),
                          candidate.characters.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                    var nativeText = ""
                    for character in candidate.characters {
                        try consume()
                        pageCharacters += 1
                        guard pageCharacters <= 100_000, !character.text.isEmpty else { throw RecoveryOCRAcquisitionFailure.limit }
                        for _ in character.text.utf8 {
                            try consume(); pageBytes += 1
                            guard pageBytes <= 1_048_576 else { throw RecoveryOCRAcquisitionFailure.limit }
                        }
                        nativeText += character.text
                    }
                    guard nativeText.utf8.elementsEqual(candidate.text.utf8) else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                }
                let top1 = line.candidates[0]
                // Alternate ranges remain raw observations, never a substitute for top1.
                for character in top1.characters {
                    try consume()
                    guard character.range?.isInside(width: page.width, height: page.height) == true else {
                        throw RecoveryOCRAcquisitionFailure.characterMapping
                    }
                }
                top1Count += 1; characterCount += top1.characters.count
                if top1.confidence < 0.85 { low[page.page, default: []].append(order) }
            }
            if let structure = page.structure {
                _ = try RecoveryOCRStructure.links(structure, page: page, consume: consume)
            }
        }
        try check(); try Task.checkCancellation()
        return RecoveryOCRAcquisitionAssessment(documentPageCount: documentPageCount,
                                               requiredOCRPages: requiredOCRPages,
                                               top1Count: top1Count, top1CharacterCount: characterCount,
                                               lowConfidenceNativeOrders: low)
    }
}
