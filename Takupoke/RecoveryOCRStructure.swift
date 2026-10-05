import Foundation

/// Original Vision normalized polygon points. These are recognition regions,
/// never physical schedule-cell boundaries or evidence that a cell is blank.
struct RecoveryOCRNativePoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}
struct RecoveryOCRNativeCell: Codable, Equatable, Sendable {
    let rowLower: Int
    let rowUpper: Int
    let columnLower: Int
    let columnUpper: Int
    let contentRegion: [RecoveryOCRNativePoint]
    let transcript: String
    /// Original local line order and all ranked candidates, without selection.
    let lines: [RecoveryOCRLine]
    let nestedTableCount: Int
}
struct RecoveryOCRNativeTable: Codable, Equatable, Sendable {
    let nativeOrder: Int
    let region: [RecoveryOCRNativePoint]
    /// Keep both native enumerations, including repeated merged-cell appearances.
    let rows: [[RecoveryOCRNativeCell]]
    let columns: [[RecoveryOCRNativeCell]]
}
struct RecoveryOCRNativeDocument: Codable, Equatable, Sendable {
    let nativeOrder: Int
    let nativeUUID: String
    let lineOrders: [Int]
    let tables: [RecoveryOCRNativeTable]
}
struct RecoveryOCRPageStructure: Codable, Equatable, Sendable {
    let documents: [RecoveryOCRNativeDocument]
}
struct RecoveryOCRNativeCellLink: Equatable, Sendable {
    let documentOrder: Int
    let tableOrder: Int
    let rowLower: Int
    let rowUpper: Int
    let columnLower: Int
    let columnUpper: Int
    /// The unchanged page-global nativeOrder used by glyph/source provenance.
    let lineOrders: [Int]
}

enum RecoveryOCRStructure {
    private struct CharacterKey: Hashable {
        let text: Data
        let range: [UInt64]?
    }
    private struct CandidateKey: Hashable {
        let text: Data
        let confidence: UInt64
        let characters: [CharacterKey]
        let lineRange: [UInt64]?
        let observationRange: [UInt64]?
    }
    private struct CellRange: Hashable {
        let rowLower: Int; let rowUpper: Int
        let columnLower: Int; let columnUpper: Int
    }
    private struct CellKey: Equatable {
        let region: [[UInt64]]
        let transcript: Data
        let lines: [[CandidateKey]]
    }

    /// A unique exact raw-candidate/coordinate match is required. Swift String
    /// equality normalizes Unicode, so keys explicitly retain UTF-8 and Double bits.
    /// Native ranges remain observational; no inferred grid or period is emitted.
    static func links(_ structure: RecoveryOCRPageStructure, page: RecoveryOCRPage,
                      consume suppliedConsume: () throws -> Void) throws -> [RecoveryOCRNativeCellLink] {
        var work = 0
        func consume() throws {
            work += 1
            guard work <= 2_000_000 else { throw RecoveryOCRAcquisitionFailure.limit }
            try suppliedConsume()
        }
        guard structure.documents.count == page.nativeDocumentCount else {
            throw RecoveryOCRAcquisitionFailure.invalidInventory
        }
        func bytes(_ text: String) throws -> Data {
            var value = Data()
            for byte in text.utf8 {
                try consume()
                guard value.count < 1_048_576 else { throw RecoveryOCRAcquisitionFailure.limit }
                value.append(byte)
            }
            return value
        }
        func polygon(_ points: [RecoveryOCRNativePoint], allowEmpty: Bool) throws -> [[UInt64]] {
            guard points.count <= 4096, (allowEmpty && points.isEmpty) || points.count >= 3 else {
                throw RecoveryOCRAcquisitionFailure.invalidInventory
            }
            return try points.map { point in
                try consume()
                guard point.x.isFinite, point.y.isFinite,
                      (0...1).contains(point.x), (0...1).contains(point.y) else {
                    throw RecoveryOCRAcquisitionFailure.characterMapping
                }
                return [point.x.bitPattern, point.y.bitPattern]
            }
        }
        func key(_ line: RecoveryOCRLine) throws -> [CandidateKey] {
            try consume()
            guard (1...5).contains(line.candidates.count) else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
            return try line.candidates.map { candidate in
                try consume()
                guard candidate.confidence.isFinite, (0...1).contains(candidate.confidence),
                      candidate.characters.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                let text = try bytes(candidate.text)
                var joined = Data()
                let characters = try candidate.characters.map { character -> CharacterKey in
                    try consume()
                    let raw = try bytes(character.text)
                    guard !raw.isEmpty, joined.count <= 1_048_576 - raw.count else { throw RecoveryOCRAcquisitionFailure.limit }
                    joined.append(raw)
                    return CharacterKey(text: raw, range: character.range.map { [$0.x.bitPattern, $0.y.bitPattern, $0.width.bitPattern, $0.height.bitPattern] })
                }
                guard !text.isEmpty, text == joined else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                return CandidateKey(text: text, confidence: candidate.confidence.bitPattern, characters: characters,
                    lineRange: candidate.lineRange.map { [$0.x.bitPattern, $0.y.bitPattern, $0.width.bitPattern, $0.height.bitPattern] },
                    observationRange: candidate.observationRange.map { [$0.x.bitPattern, $0.y.bitPattern, $0.width.bitPattern, $0.height.bitPattern] })
            }
        }
        var output = [RecoveryOCRNativeCellLink](), nextLine = 0
        var claimedLines = Set<Int>(), documentUUIDs = Set<String>()
        for (documentOrder, document) in structure.documents.enumerated() {
            try consume()
            guard document.nativeOrder == documentOrder, document.nativeUUID.utf8.count == 36,
                  UUID(uuidString: document.nativeUUID) != nil,
                  documentUUIDs.insert(document.nativeUUID).inserted,
                  document.lineOrders.count <= page.lines.count, document.tables.count <= 1000 else {
                throw RecoveryOCRAcquisitionFailure.invalidInventory
            }
            var byKey = [[CandidateKey]: [Int]]()
            for order in document.lineOrders {
                try consume()
                guard order == nextLine, page.lines.indices.contains(order), page.lines[order].nativeOrder == order else {
                    throw RecoveryOCRAcquisitionFailure.invalidInventory
                }
                byKey[try key(page.lines[order]), default: []].append(order)
                nextLine += 1
            }
            for (tableOrder, table) in document.tables.enumerated() {
                try consume()
                guard table.nativeOrder == tableOrder, table.rows.count <= 100_000, table.columns.count <= 100_000 else {
                    throw RecoveryOCRAcquisitionFailure.limit
                }
                _ = try polygon(table.region, allowEmpty: false)
                var rows = [CellRange: CellKey](), columns = [CellRange: CellKey]()
                for (axis, groups) in [table.rows, table.columns].enumerated() {
                    for group in groups {
                        try consume()
                        guard group.count <= 100_000 else { throw RecoveryOCRAcquisitionFailure.limit }
                        for cell in group {
                            try consume()
                            guard (0..<100_000).contains(cell.rowLower), (cell.rowLower..<100_000).contains(cell.rowUpper),
                                  (0..<100_000).contains(cell.columnLower), (cell.columnLower..<100_000).contains(cell.columnUpper),
                                  cell.nestedTableCount == 0, cell.lines.count <= 100_000 else {
                                throw RecoveryOCRAcquisitionFailure.invalidInventory
                            }
                            let range = CellRange(rowLower: cell.rowLower, rowUpper: cell.rowUpper,
                                                  columnLower: cell.columnLower, columnUpper: cell.columnUpper)
                            let rawRegion = try polygon(cell.contentRegion, allowEmpty: cell.lines.isEmpty && cell.transcript.isEmpty)
                            let transcript = try bytes(cell.transcript)
                            var lineKeys = [[CandidateKey]](), orders = [Int]()
                            for (localOrder, line) in cell.lines.enumerated() {
                                guard line.nativeOrder == localOrder else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                                let signature = try key(line)
                                guard let matches = byKey[signature], matches.count == 1 else {
                                    throw RecoveryOCRAcquisitionFailure.characterMapping
                                }
                                lineKeys.append(signature); orders.append(matches[0])
                            }
                            guard Set(orders).count == orders.count else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                            let value = CellKey(region: rawRegion, transcript: transcript, lines: lineKeys)
                            let previous = axis == 0 ? rows[range] : columns[range]
                            if let previous {
                                guard previous == value else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                            } else if axis == 0 {
                                rows[range] = value
                                for order in orders {
                                    guard claimedLines.insert(order).inserted else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
                                }
                                output.append(RecoveryOCRNativeCellLink(documentOrder: documentOrder, tableOrder: tableOrder,
                                    rowLower: cell.rowLower, rowUpper: cell.rowUpper, columnLower: cell.columnLower,
                                    columnUpper: cell.columnUpper, lineOrders: orders))
                            } else { columns[range] = value }
                        }
                    }
                }
                guard rows == columns else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
            }
        }
        guard nextLine == page.lines.count else { throw RecoveryOCRAcquisitionFailure.invalidInventory }
        return output
    }
}
