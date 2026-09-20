import Foundation

/// Timetable geometry comes from PDF text drawing instructions, not selection
/// highlights or PDFKit's synthetic newline indices. All failures are text-free.
enum PDFTextFailure {
    static var unsupported: PDFParseError { PDFParseError(code: .unsupported, stage: .characterMapping) }
}

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

/// Affine math also runs in the Foundation-only regression tests.
struct PDFTextMatrix {
    var a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0
    init(_ n: [Double] = [1, 0, 0, 1, 0, 0]) throws {
        guard n.count == 6, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported }
        a = n[0]; b = n[1]; c = n[2]; d = n[3]; tx = n[4]; ty = n[5]
    }
    func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: a * x + c * y + tx, y: b * x + d * y + ty) }
    func followed(by m: Self) throws -> Self {
        try Self([m.a*a + m.c*b, m.b*a + m.d*b, m.a*c + m.c*d, m.b*c + m.d*d,
                  m.a*tx + m.c*ty + m.tx, m.b*tx + m.d*ty + m.ty])
    }
    mutating func translate(_ x: Double, _ y: Double) { tx += a*x + c*y; ty += b*x + d*y }
}

final class PDFTextGeometry {
    struct State {
        var ctm = try! PDFTextMatrix()
        var font: PDFTextFont?
        var size = 0.0, spacing = 0.0, wordSpacing = 0.0, scale = 1.0, leading = 0.0, rise = 0.0
        var rendering = 0.0
    }
    var state = State()
    private var stack: [State] = []
    private var matrix = try! PDFTextMatrix(), lineMatrix = try! PDFTextMatrix()
    private var inText = false
    private var line = 0, order = 0, operations = 0
    private(set) var glyphs: [PDFGlyph] = []
    private var drawnText = ""
    private var textUnits = 0
    let check: () throws -> Void
    init(check: @escaping () throws -> Void = {}) { self.check = check }

    func operation(_ op: String, _ n: [Double] = []) throws {
        operations += 1
        guard operations <= 1_000_000 else { throw PDFParseError(code: .limit) }
        if operations % 128 == 0 { try check() }
        let counts = ["q": 0, "Q": 0, "cm": 6, "BT": 0, "ET": 0, "Tm": 6, "Td": 2, "TD": 2,
                      "T*": 0, "Tc": 1, "Tw": 1, "Tz": 1, "TL": 1, "Ts": 1, "Tr": 1]
        guard let count = counts[op], n.count == count, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported }
        switch op {
        case "q":
            guard stack.count < 64 else { throw PDFParseError(code: .limit) }
            stack.append(state)
        case "Q":
            guard let saved = stack.popLast() else { throw PDFTextFailure.unsupported }; state = saved
            line += 1
        case "cm": state.ctm = try PDFTextMatrix(n).followed(by: state.ctm); line += 1
        case "BT":
            guard !inText else { throw PDFTextFailure.unsupported }
            inText = true; matrix = try PDFTextMatrix(); lineMatrix = matrix; line += 1
        case "ET":
            guard inText else { throw PDFTextFailure.unsupported }; inText = false
        case "Tm":
            guard inText else { throw PDFTextFailure.unsupported }
            matrix = try PDFTextMatrix(n); lineMatrix = matrix; line += 1
        case "Td", "TD", "T*":
            guard inText else { throw PDFTextFailure.unsupported }
            if op == "TD" { state.leading = -n[1] }
            lineMatrix.translate(op == "T*" ? 0 : n[0], op == "T*" ? -state.leading : n[1])
            matrix = lineMatrix; line += 1
        case "Tc": state.spacing = n[0]
        case "Tw": state.wordSpacing = n[0]
        case "Tz": state.scale = n[0] / 100
        case "TL": state.leading = n[0]
        case "Ts": state.rise = n[0]; line += 1
        case "Tr":
            guard [0, 1, 2].contains(n[0]) else { throw PDFTextFailure.unsupported }
            state.rendering = n[0]
        default: throw PDFTextFailure.unsupported
        }
    }
    func font(_ font: PDFTextFont, size: Double) throws {
        guard size.isFinite, size > 0 else { throw PDFTextFailure.unsupported }
        state.font = font; state.size = size
    }
    func adjust(_ amount: Double) throws {
        guard inText, amount.isFinite else { throw PDFTextFailure.unsupported }
        matrix.translate(-amount / 1000 * state.size * state.scale, 0)
    }
    func show(_ bytes: [UInt8]) throws {
        guard inText, let font = state.font, state.size > 0, state.scale > 0,
              bytes.count % font.codeBytes == 0, order + bytes.count / font.codeBytes <= 100_000 else {
            throw PDFTextFailure.unsupported
        }
        for offset in stride(from: 0, to: bytes.count, by: font.codeBytes) {
            if order % 128 == 0 { try check() }
            let cid = bytes[offset..<(offset + font.codeBytes)].reduce(0) { $0 * 256 + Int($1) }
            guard let text = font.unicode[cid], !text.isEmpty,
                  textUnits + text.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported }
            let width = (font.widths[cid] ?? font.defaultWidth) / 1000 * state.size
            let total = try matrix.followed(by: state.ctm)
            let bottom = font.descent / 1000 * state.size + state.rise
            let top = font.ascent / 1000 * state.size + state.rise
            let points = [total.point(0, bottom), total.point(width * state.scale, bottom),
                          total.point(0, top), total.point(width * state.scale, top)]
            let xs = points.map { Double($0.x) }, ys = points.map { Double($0.y) }
            guard (xs + ys).allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { throw PDFTextFailure.unsupported }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard width > 0, let x = xs.min(), let y = ys.min(), let right = xs.max(), let upper = ys.max(),
                      right > x, upper > y else { throw PDFTextFailure.unsupported }
                glyphs.append(PDFGlyph(text: text, x: x, y: y, width: right - x, height: upper - y,
                                       sourceLine: line, sourceOrder: order))
            }
            drawnText += text; textUnits += text.utf16.count; order += 1
            // Word spacing applies only to a single-byte character code 32 (PDF 9.3.3).
            let word = font.codeBytes == 1 && cid == 32 ? state.wordSpacing : 0
            matrix.translate((width + state.spacing + word) * state.scale, 0)
        }
    }
    func finish(expectedText: String) throws -> [PDFGlyph] {
        try check()
        guard !inText, stack.isEmpty, !glyphs.isEmpty, expectedText.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported }
        func content(_ text: String) -> [UInt32: Int] {
            text.precomposedStringWithCanonicalMapping.unicodeScalars.reduce(into: [:]) {
                if !CharacterSet.whitespacesAndNewlines.contains($1) { $0[$1.value, default: 0] += 1 }
            }
        }
        // PDFKit can reorder lines and insert whitespace. It must nevertheless
        // account for every visible scalar drawn by the supported text operators.
        guard content(drawnText) == content(expectedText) else { throw PDFTextFailure.unsupported }
        return glyphs
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

/// Resource decoding stays separate from the portable text-state interpreter.
final class PDFDrawnTextReader {
    let engine: PDFTextGeometry
    private var failure: Error?
    private var fonts: [String: PDFTextFont] = [:]
    init(check: @escaping () throws -> Void) { engine = PDFTextGeometry(check: check) }

    private static func run(_ info: UnsafeMutableRawPointer?, _ action: (PDFDrawnTextReader) throws -> Void) {
        guard let info = info else { return }
        let reader = Unmanaged<PDFDrawnTextReader>.fromOpaque(info).takeUnretainedValue()
        guard reader.failure == nil else { return }
        do { try reader.engine.check(); try action(reader) } catch { reader.failure = error }
    }
    private func numbers(_ scanner: CGPDFScannerRef, _ count: Int) throws -> [Double] {
        var result: [Double] = []
        for _ in 0..<count {
            var value: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw PDFTextFailure.unsupported }
            result.insert(Double(value), at: 0)
        }
        return result
    }
    private func name(_ scanner: CGPDFScannerRef) throws -> String {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw PDFTextFailure.unsupported }
        return String(cString: pointer)
    }
    private func string(_ scanner: CGPDFScannerRef) throws {
        var value: CGPDFStringRef?
        guard CGPDFScannerPopString(scanner, &value), let value = value else { throw PDFTextFailure.unsupported }
        try show(value)
    }
    private func show(_ value: CGPDFStringRef) throws {
        let length = CGPDFStringGetLength(value)
        guard length <= 200_000 else { throw PDFParseError(code: .limit) }
        if length == 0 { return }
        guard let bytes = CGPDFStringGetBytePtr(value) else { throw PDFTextFailure.unsupported }
        try engine.show(Array(UnsafeBufferPointer(start: bytes, count: length)))
    }
    private func array(_ scanner: CGPDFScannerRef) throws {
        var array: CGPDFArrayRef?
        guard CGPDFScannerPopArray(scanner, &array), let array = array,
              CGPDFArrayGetCount(array) <= 100_000 else { throw PDFTextFailure.unsupported }
        for index in 0..<CGPDFArrayGetCount(array) {
            try engine.check()
            var text: CGPDFStringRef?, amount: CGPDFReal = 0
            if CGPDFArrayGetString(array, index, &text), let text = text { try show(text) }
            else if CGPDFArrayGetNumber(array, index, &amount) { try engine.adjust(Double(amount)) }
            else { throw PDFTextFailure.unsupported }
        }
    }
    private func resource(_ scanner: CGPDFScannerRef, _ category: String, _ name: String) throws -> CGPDFDictionaryRef {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let object = CGPDFContentStreamGetResource(stream, category, name) else { throw PDFTextFailure.unsupported }
        var dict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(object, .dictionary, &dict), let dict = dict else { throw PDFTextFailure.unsupported }
        return dict
    }
    private func named(_ dict: CGPDFDictionaryRef, _ key: String) -> String? {
        var value: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dict, key, &value), let value = value else { return nil }
        return String(cString: value)
    }
    private func number(_ dict: CGPDFDictionaryRef, _ key: String, fallback: Double? = nil) throws -> Double {
        var value: CGPDFReal = 0, object: CGPDFObjectRef?
        if CGPDFDictionaryGetNumber(dict, key, &value), value.isFinite { return Double(value) }
        guard !CGPDFDictionaryGetObject(dict, key, &object), let fallback = fallback else { throw PDFTextFailure.unsupported }
        return fallback
    }
    private func font(_ scanner: CGPDFScannerRef) throws {
        let size = try numbers(scanner, 1)[0], key = try name(scanner)
        if let cached = fonts[key] { try engine.font(cached, size: size); return }
        guard fonts.count < 128 else { throw PDFParseError(code: .limit) }
        let dict = try resource(scanner, "Font", key)
        var mapStream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream), let mapStream = mapStream else {
            throw PDFTextFailure.unsupported
        }
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(mapStream, &format), format == .raw else { throw PDFTextFailure.unsupported }
        let mapping = try PDFUnicodeMap.read(data as Data)
        var metrics = dict
        let composite = named(dict, "Subtype") == "Type0"
        if composite {
            var descendants: CGPDFArrayRef?, descendant: CGPDFDictionaryRef?
            guard named(dict, "Encoding") == "Identity-H", mapping.bytes == 2,
                  CGPDFDictionaryGetArray(dict, "DescendantFonts", &descendants), let descendants = descendants,
                  CGPDFArrayGetCount(descendants) == 1,
                  CGPDFArrayGetDictionary(descendants, 0, &descendant), let descendant = descendant,
                  ["CIDFontType0", "CIDFontType2"].contains(named(descendant, "Subtype") ?? "") else {
                throw PDFTextFailure.unsupported
            }
            metrics = descendant
        } else {
            guard ["TrueType", "Type1"].contains(named(dict, "Subtype") ?? ""), mapping.bytes == 1 else {
                throw PDFTextFailure.unsupported
            }
        }
        var descriptor: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(metrics, "FontDescriptor", &descriptor), let descriptor = descriptor else {
            throw PDFTextFailure.unsupported
        }
        var widths: [Int: Double] = [:]
        var array: CGPDFArrayRef?
        if composite {
            if CGPDFDictionaryGetArray(metrics, "W", &array), let array = array {
                let count = CGPDFArrayGetCount(array)
                guard count <= 200_000 else { throw PDFParseError(code: .limit) }
                var i = 0
                func integer(_ index: Int) throws -> Int {
                    var n: CGPDFInteger = 0
                    guard index < count, CGPDFArrayGetInteger(array, index, &n), (0...65535).contains(n) else {
                        throw PDFTextFailure.unsupported
                    }
                    return n
                }
                func put(_ cid: Int, _ value: Double) throws {
                    guard (0...65535).contains(cid), value.isFinite, value >= 0, widths[cid] == nil else {
                        throw PDFTextFailure.unsupported
                    }
                    widths[cid] = value
                }
                while i < count {
                    try engine.check()
                    let start = try integer(i); i += 1
                    var list: CGPDFArrayRef?
                    guard i < count else { throw PDFTextFailure.unsupported }
                    if CGPDFArrayGetArray(array, i, &list), let list = list {
                        let length = CGPDFArrayGetCount(list)
                        guard length > 0, length <= 65536 - start else { throw PDFTextFailure.unsupported }
                        for offset in 0..<length {
                            var value: CGPDFReal = 0
                            guard CGPDFArrayGetNumber(list, offset, &value) else { throw PDFTextFailure.unsupported }
                            try put(start + offset, Double(value))
                        }
                        i += 1
                    } else {
                        let end = try integer(i); i += 1
                        var value: CGPDFReal = 0
                        guard end >= start, i < count, CGPDFArrayGetNumber(array, i, &value) else { throw PDFTextFailure.unsupported }
                        for cid in start...end { try put(cid, Double(value)) }
                        i += 1
                    }
                }
            } else {
                var object: CGPDFObjectRef?
                guard !CGPDFDictionaryGetObject(metrics, "W", &object) else { throw PDFTextFailure.unsupported }
            }
        } else {
            let first = try number(dict, "FirstChar"), last = try number(dict, "LastChar")
            guard first.rounded() == first, last.rounded() == last, first >= 0, last <= 255, last >= first,
                  CGPDFDictionaryGetArray(dict, "Widths", &array), let array = array,
                  CGPDFArrayGetCount(array) == Int(last - first + 1) else { throw PDFTextFailure.unsupported }
            for index in 0..<CGPDFArrayGetCount(array) {
                var value: CGPDFReal = 0
                guard CGPDFArrayGetNumber(array, index, &value) else { throw PDFTextFailure.unsupported }
                widths[Int(first) + index] = Double(value)
            }
            guard mapping.values.keys.allSatisfy({ widths[$0] != nil }) else { throw PDFTextFailure.unsupported }
        }
        let decoded = try PDFTextFont(unicode: mapping.values, codeBytes: mapping.bytes, widths: widths,
            defaultWidth: composite ? number(metrics, "DW", fallback: 1000) : 0,
            ascent: number(descriptor, "Ascent"), descent: number(descriptor, "Descent"))
        fonts[key] = decoded
        try engine.font(decoded, size: size)
    }
    private func graphicsState(_ scanner: CGPDFScannerRef) throws {
        let dict = try resource(scanner, "ExtGState", name(scanner))
        // These entries change text state or visibility beyond this interpreter.
        for key in ["Font", "SMask", "TR", "TR2"] {
            var object: CGPDFObjectRef?
            guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw PDFTextFailure.unsupported }
        }
        guard try number(dict, "ca", fallback: 1) == 1, number(dict, "CA", fallback: 1) == 1 else {
            throw PDFTextFailure.unsupported
        }
    }
    func read(_ page: CGPDFPage, expectedText: String) throws -> [PDFGlyph] {
        guard let table = CGPDFOperatorTableCreate() else { throw PDFTextFailure.unsupported }
        defer { CGPDFOperatorTableRelease(table) }
        CGPDFOperatorTableSetCallback(table, "q") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("q", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Q") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Q", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("cm", s.numbers(scanner, 6)) }
        }
        CGPDFOperatorTableSetCallback(table, "BT") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("BT", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "ET") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("ET", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tm") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tm", s.numbers(scanner, 6)) }
        }
        CGPDFOperatorTableSetCallback(table, "Td") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Td", s.numbers(scanner, 2)) }
        }
        CGPDFOperatorTableSetCallback(table, "TD") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("TD", s.numbers(scanner, 2)) }
        }
        CGPDFOperatorTableSetCallback(table, "T*") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("T*", s.numbers(scanner, 0)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tc") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tc", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tw") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tw", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tz") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tz", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "TL") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("TL", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Ts") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Ts", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("Tr", s.numbers(scanner, 1)) }
        }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, p in PDFDrawnTextReader.run(p) { try $0.font(scanner) } }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, p in PDFDrawnTextReader.run(p) { try $0.string(scanner) } }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, p in PDFDrawnTextReader.run(p) { try $0.array(scanner) } }
        CGPDFOperatorTableSetCallback(table, "'") { scanner, p in
            PDFDrawnTextReader.run(p) { s in try s.engine.operation("T*"); try s.string(scanner) }
        }
        CGPDFOperatorTableSetCallback(table, "\"") { scanner, p in
            PDFDrawnTextReader.run(p) { s in
                var text: CGPDFStringRef?
                guard CGPDFScannerPopString(scanner, &text), let text = text else { throw PDFTextFailure.unsupported }
                let n = try s.numbers(scanner, 2)
                try s.engine.operation("Tw", [n[0]]); try s.engine.operation("Tc", [n[1]])
                try s.engine.operation("T*"); try s.show(text)
            }
        }
        CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in PDFDrawnTextReader.run(p) { try $0.graphicsState(scanner) } }
        // Form XObjects, optional/replacement text and clipping can conceal or
        // replace drawn text. Do not silently emit a partial timetable.
        for op in ["Do", "BDC", "BMC", "W", "W*"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw PDFTextFailure.unsupported } }
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        let succeeded = CGPDFScannerScan(scanner)
        if let failure = failure { throw failure }
        guard succeeded else { throw PDFTextFailure.unsupported }
        return try engine.finish(expectedText: expectedText)
    }
}
#endif
