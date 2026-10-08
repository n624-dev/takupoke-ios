import Foundation
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

// Recovery metadata only. Visibility, location and acquisition completeness
// must still be established by the drawing interpreter and document validator.
struct PDFTrueTypeRecoveryMap {
    enum Failure: Error { case unsupported, limit }
    static let maximumFontBytes = 20_000_000
    private static let maximumWork = 1_200_000
    let fontHash: String
    let uniqueScalars: [Int: Int]
    let ambiguousGlyphs: Set<Int>
    let glyphCount: Int

    func resolve(cid: Int, cidToGid: Data?) throws -> (glyph: Int, text: String) {
        guard (0...65535).contains(cid) else { throw Failure.unsupported }
        var glyph = cid
        if let cidToGid {
            let position = cid * 2
            guard cidToGid.count <= 131072, cidToGid.count % 2 == 0, position + 2 <= cidToGid.count else { throw Failure.unsupported }
            glyph = Int(cidToGid[cidToGid.startIndex + position]) * 256 + Int(cidToGid[cidToGid.startIndex + position + 1])
        }
        guard glyph > 0, glyph < glyphCount, !ambiguousGlyphs.contains(glyph),
              let number = uniqueScalars[glyph], let scalar = Unicode.Scalar(number) else { throw Failure.unsupported }
        return (glyph, String(scalar))
    }

    static func read(_ font: Data, cancelled: () -> Bool = { Task.isCancelled }) throws -> Self {
        func checkCancellation() throws { if cancelled() { throw CancellationError() } }
        try checkCancellation()
        guard (12...maximumFontBytes).contains(font.count) else { throw Failure.unsupported }
        let bytes = Bytes(font)
        guard try bytes.u32(0) == 0x00010000 else { throw Failure.unsupported }
        let count = try bytes.u16(4)
        guard (1...256).contains(count) else { throw Failure.unsupported }
        let directoryEnd = 12 + count * 16
        _ = try bytes.slice(0, directoryEnd)
        var tables: [String: Bytes] = [:], extents: [(start: Int, end: Int)] = []
        for index in 0..<count {
            try checkCancellation()
            let record = 12 + index * 16
            let tag = try bytes.slice(record, 4).ascii()
            let start = try bytes.u32(record + 8), size = try bytes.u32(record + 12)
            guard start >= directoryEnd, tables[tag] == nil else { throw Failure.unsupported }
            tables[tag] = try bytes.slice(start, size)
            if size > 0 { extents.append((start, start + size)) }
        }
        extents.sort { $0.start < $1.start }
        for index in extents.indices.dropFirst() {
            guard extents[index - 1].end <= extents[index].start else { throw Failure.unsupported }
        }
        guard let cmap = tables["cmap"], let maxp = tables["maxp"], tables["glyf"] != nil, tables["loca"] != nil else {
            throw Failure.unsupported
        }
        let glyphCount = try maxp.u16(4)
        guard glyphCount > 0, try cmap.u16(0) == 0 else { throw Failure.unsupported }
        let maps = try cmap.u16(2)
        guard (1...64).contains(maps) else { throw Failure.unsupported }
        let recordsEnd = 4 + maps * 8
        _ = try cmap.slice(0, recordsEnd)
        var seen: Set<Int> = [], unique: [Int: Int] = [:], ambiguous: Set<Int> = []
        var supported = 0, work = 0
        func consume(_ units: Int) throws {
            try checkCancellation()
            guard units >= 0, units <= maximumWork - work else { throw Failure.limit }
            work += units
        }
        func add(_ number: Int, _ glyph: Int) throws {
            guard glyph < glyphCount else { throw Failure.unsupported }
            if glyph == 0 { return }
            guard Unicode.Scalar(number) != nil else { throw Failure.unsupported }
            if ambiguous.contains(glyph) { return }
            if let prior = unique[glyph], prior != number { unique.removeValue(forKey: glyph); ambiguous.insert(glyph) }
            else { unique[glyph] = number }
        }
        for index in 0..<maps {
            try consume(1)
            let record = 4 + index * 8, platform = try cmap.u16(record), encoding = try cmap.u16(record + 2)
            if platform != 0 && !(platform == 3 && [1, 10].contains(encoding)) { continue }
            let offset = try cmap.u32(record + 4)
            guard offset >= recordsEnd else { throw Failure.unsupported }
            if !seen.insert(offset).inserted { continue }
            let format = try cmap.u16(offset)
            supported += 1
            if format == 4 {
                let sub = try cmap.slice(offset, cmap.u16(offset + 2)), twice = try sub.u16(6)
                guard twice > 0, twice % 2 == 0, twice <= 8192 else { throw Failure.unsupported }
                let segments = twice / 2, glyphStart = 16 + segments * 8
                _ = try sub.slice(0, glyphStart)
                guard try sub.u16(14 + segments * 2) == 0 else { throw Failure.unsupported }
                var previous = -1
                for segment in 0..<segments {
                    let end = try sub.u16(14 + segment * 2), start = try sub.u16(16 + segments * 2 + segment * 2)
                    let delta = try sub.u16(16 + segments * 4 + segment * 2)
                    let rangePosition = 16 + segments * 6 + segment * 2, range = try sub.u16(rangePosition)
                    guard start <= end, start > previous, range % 2 == 0 else { throw Failure.unsupported }
                    previous = end
                    try consume(end - start + 1)
                    for number in start...end {
                        if number & 255 == 0 { try checkCancellation() }
                        var glyph: Int
                        if range == 0 { glyph = (number + delta) & 65535 }
                        else {
                            let position = rangePosition + range + (number - start) * 2
                            guard position >= glyphStart else { throw Failure.unsupported }
                            glyph = try sub.u16(position)
                            if glyph != 0 { glyph = (glyph + delta) & 65535 }
                        }
                        try add(number, glyph)
                    }
                }
                guard previous == 65535 else { throw Failure.unsupported }
            } else if format == 12 {
                let sub = try cmap.slice(offset, cmap.u32(offset + 4))
                guard try sub.u16(2) == 0 else { throw Failure.unsupported }
                let groups = try sub.u32(12)
                guard groups <= 65536, sub.count == 16 + groups * 12 else { throw Failure.unsupported }
                var previous = -1
                for group in 0..<groups {
                    let position = 16 + group * 12, start = try sub.u32(position), end = try sub.u32(position + 4)
                    let firstGlyph = try sub.u32(position + 8)
                    guard start <= end, start > previous, end <= 0x10ffff,
                          !(start <= 0xdfff && end >= 0xd800), firstGlyph + end - start < glyphCount else { throw Failure.unsupported }
                    previous = end
                    try consume(end - start + 1)
                    for number in start...end {
                        if number & 255 == 0 { try checkCancellation() }
                        try add(number, firstGlyph + number - start)
                    }
                }
            } else { throw Failure.unsupported } // Do not ignore another potentially contradictory Unicode cmap.
        }
        guard supported > 0 else { throw Failure.unsupported }
        try checkCancellation()
        return Self(fontHash: SHA256.hash(data: font).map { String(format: "%02x", $0) }.joined(),
                    uniqueScalars: unique, ambiguousGlyphs: ambiguous, glyphCount: glyphCount)
    }

    // Slices share immutable backing bytes. Table reads do not allocate another
    // complete font for each subtable, including adversarial duplicate records.
    private struct Bytes {
        let data: [UInt8], offset: Int, count: Int
        init(_ value: Data) { data = Array(value); offset = 0; count = value.count }
        private init(data: [UInt8], offset: Int, count: Int) { self.data = data; self.offset = offset; self.count = count }
        func slice(_ start: Int, _ size: Int) throws -> Self {
            guard start >= 0, size >= 0, start <= count - size else { throw Failure.unsupported }
            return Self(data: data, offset: offset + start, count: size)
        }
        func u16(_ start: Int) throws -> Int {
            let value = try slice(start, 2)
            return Int(data[value.offset]) * 256 + Int(data[value.offset + 1])
        }
        func u32(_ start: Int) throws -> Int {
            let value = try slice(start, 4)
            return (0..<4).reduce(0) { $0 * 256 + Int(data[value.offset + $1]) }
        }
        func ascii() -> String { String(decoding: data[offset..<(offset + count)], as: UTF8.self) }
    }
}
