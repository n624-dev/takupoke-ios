import Foundation

/// Physical PDF code -> glyph ID only. This never recovers or certifies Unicode.
/// Unsupported/ambiguous encodings retain the reader's conservative font bounds.
enum PDFEncodedGlyphMap {
    static func symbolicTrueType(_ data: Data, check: () throws -> Void = {}) throws -> [Int: UInt16]? {
        try check()
        guard data.count >= 12, data.count <= 8_000_000 else { return nil }
        let bytes = [UInt8](data)
        func word(_ offset: Int) -> Int? {
            guard offset >= 0, offset <= bytes.count - 2 else { return nil }
            return Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
        }
        func long(_ offset: Int) -> Int? {
            guard let high = word(offset), let low = word(offset + 2) else { return nil }
            return high * 65536 + low
        }
        guard let signature = long(0), [0x00010000, 0x74727565].contains(signature),
              let count = word(4), (1...128).contains(count), 12 + count * 16 <= bytes.count else { return nil }
        var tables: [Int: Range<Int>] = [:]
        for index in 0..<count {
            try check()
            let record = 12 + index * 16
            guard let tag = long(record), let start = long(record + 8), let length = long(record + 12),
                  start >= 12 + count * 16, start <= bytes.count, length <= bytes.count - start,
                  tables[tag] == nil else { return nil }
            let range = start..<(start + length)
            guard !tables.values.contains(where: { $0.overlaps(range) }) else { return nil }
            tables[tag] = range
        }
        guard let cmap = tables[0x636d6170], cmap.count >= 4, word(cmap.lowerBound) == 0,
              let entries = word(cmap.lowerBound + 2), (1...128).contains(entries),
              4 + entries * 8 <= cmap.count else { return nil }
        var selected: Int?
        for index in 0..<entries {
            try check()
            let record = cmap.lowerBound + 4 + index * 8
            guard let platform = word(record), let encoding = word(record + 2), let offset = long(record + 4),
                  offset >= 4 + entries * 8, offset < cmap.count else { return nil }
            // A competing symbolic table makes the PDF rendering choice uncertain.
            if platform == 3 && encoding == 0 { return nil }
            if platform == 1 && encoding == 0 {
                guard selected == nil else { return nil }
                selected = cmap.lowerBound + offset
            }
        }
        guard let start = selected, let format = word(start), let length = word(start + 2),
              length <= cmap.upperBound - start else { return nil }
        var result: [Int: UInt16] = [:]
        if format == 0 {
            guard length == 262 else { return nil }
            for code in 0..<256 { result[code] = UInt16(bytes[start + 6 + code]) }
        } else if format == 6 {
            guard length >= 10, let first = word(start + 6), let count = word(start + 8),
                  first <= 255, count <= 256 - first, length == 10 + count * 2 else { return nil }
            for offset in 0..<count {
                try check()
                guard let gid = word(start + 10 + offset * 2) else { return nil }
                result[first + offset] = UInt16(gid)
            }
        } else { return nil }
        return result
    }

    static func cidToGID(_ data: Data, check: () throws -> Void = {}) throws -> [Int: UInt16]? {
        try check()
        guard !data.isEmpty, data.count <= 131072, data.count % 2 == 0 else { return nil }
        let bytes = [UInt8](data)
        var result: [Int: UInt16] = [:]
        for offset in stride(from: 0, to: bytes.count, by: 2) {
            if offset % 256 == 0 { try check() }
            result[offset / 2] = UInt16(bytes[offset]) * 256 + UInt16(bytes[offset + 1])
        }
        return result
    }
}
