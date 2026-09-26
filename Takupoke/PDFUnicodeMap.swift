import Foundation

struct PDFTextFont {
    let unicode: [Int: String]
    let codeBytes: Int
    let widths: [Int: Double]
    let defaultWidth: Double
    let ascent: Double
    let descent: Double

    init(unicode: [Int: String], codeBytes: Int, widths: [Int: Double], defaultWidth: Double,
         ascent: Double, descent: Double) throws {
        guard [1, 2].contains(codeBytes), !unicode.isEmpty, unicode.count <= 65536,
              [defaultWidth, ascent, descent].allSatisfy(\.isFinite), defaultWidth >= 0,
              ascent > descent, widths.values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw PDFTextFailure.unsupported
        }
        self.unicode = unicode; self.codeBytes = codeBytes; self.widths = widths
        self.defaultWidth = defaultWidth; self.ascent = ascent; self.descent = descent
    }
}

/// The supported ToUnicode subset has one-byte or two-byte code spaces,
/// bfchar and bfrange mappings. A missing or inherited map is never guessed.
enum PDFUnicodeMap {
    static func read(_ data: Data) throws -> (bytes: Int, values: [Int: String]) {
        guard data.count <= 2_000_000, let source = String(data: data, encoding: .ascii) else {
            throw PDFTextFailure.unsupported
        }
        let noComments = source.replacingOccurrences(of: "%[^\\r\\n]*", with: "", options: .regularExpression)
        let regex = try NSRegularExpression(pattern: "<[^<>]*>|\\[|\\]|[^\\s<>\\[\\]]+")
        let ns = noComments as NSString
        let tokens = regex.matches(in: noComments, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        guard !tokens.contains("usecmap"), !tokens.contains("beginnotdefrange"),
              !tokens.contains("beginnotdefchar") else { throw PDFTextFailure.unsupported }
        var spaces: [(Int, Int)] = [], byteCount: Int?, values: [Int: String] = [:]
        var i = 0
        func hex(_ value: String) throws -> [UInt8] {
            guard value.first == "<", value.last == ">" else { throw PDFTextFailure.unsupported }
            let body = value.dropFirst().dropLast().filter { !$0.isWhitespace }
            guard !body.isEmpty, body.count % 2 == 0, body.count <= 128 else { throw PDFTextFailure.unsupported }
            var result: [UInt8] = [], cursor = body.startIndex
            while cursor < body.endIndex {
                let end = body.index(cursor, offsetBy: 2)
                guard let b = UInt8(body[cursor..<end], radix: 16) else { throw PDFTextFailure.unsupported }
                result.append(b); cursor = end
            }
            return result
        }
        func code(_ token: String) throws -> Int {
            let b = try hex(token)
            guard let count = byteCount, b.count == count else { throw PDFTextFailure.unsupported }
            return b.reduce(0) { $0 * 256 + Int($1) }
        }
        func insert(_ key: Int, _ bytes: [UInt8]) throws {
            guard values[key] == nil, values.count < 65536, bytes.count % 2 == 0,
                  spaces.contains(where: { $0.0 <= key && key <= $0.1 }),
                  let text = String(data: Data(bytes), encoding: .utf16BigEndian), !text.isEmpty,
                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw PDFTextFailure.unsupported
            }
            values[key] = text
        }
        func next() throws -> String {
            guard i < tokens.count else { throw PDFTextFailure.unsupported }
            defer { i += 1 }; return tokens[i]
        }
        while i < tokens.count {
            let token = tokens[i]; i += 1
            if token == "/WMode" {
                guard try next() == "0" else { throw PDFTextFailure.unsupported }
            }
            guard ["begincodespacerange", "beginbfchar", "beginbfrange"].contains(token) else { continue }
            guard i >= 2, let count = Int(tokens[i - 2]), (1...65536).contains(count) else { throw PDFTextFailure.unsupported }
            for _ in 0..<count {
                if token == "begincodespacerange" {
                    let low = try hex(next()), high = try hex(next())
                    guard [1, 2].contains(low.count), high.count == low.count,
                          byteCount == nil || byteCount == low.count else { throw PDFTextFailure.unsupported }
                    byteCount = low.count
                    let l = low.reduce(0) { $0 * 256 + Int($1) }, h = high.reduce(0) { $0 * 256 + Int($1) }
                    guard l <= h, !spaces.contains(where: { l <= $0.1 && h >= $0.0 }) else { throw PDFTextFailure.unsupported }
                    spaces.append((l, h))
                } else if token == "beginbfchar" {
                    let key = try code(next()), bytes = try hex(next())
                    try insert(key, bytes)
                } else {
                    let low = try code(next()), high = try code(next())
                    guard high >= low, high - low < 65536 else { throw PDFTextFailure.unsupported }
                    let destination = try next()
                    if destination == "[" {
                        for key in low...high { try insert(key, hex(next())) }
                        guard try next() == "]" else { throw PDFTextFailure.unsupported }
                    } else {
                        var bytes = try hex(destination)
                        for key in low...high {
                            try insert(key, bytes)
                            if key != high {
                                var carry = true
                                for index in bytes.indices.reversed() where carry {
                                    if bytes[index] == 255 { bytes[index] = 0 } else { bytes[index] += 1; carry = false }
                                }
                                guard !carry else { throw PDFTextFailure.unsupported }
                            }
                        }
                    }
                }
            }
            let ending = token.replacingOccurrences(of: "begin", with: "end")
            guard try next() == ending else { throw PDFTextFailure.unsupported }
        }
        guard let bytes = byteCount, !values.isEmpty else { throw PDFTextFailure.unsupported }
        return (bytes, values)
    }
}
