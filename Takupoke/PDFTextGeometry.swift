import Foundation

/// Timetable geometry comes from PDF text drawing instructions, not selection
/// highlights or PDFKit's synthetic newline indices. All failures are text-free.
enum PDFTextFailure {
    static var unsupported: PDFParseError { PDFParseError(code: .unsupported, stage: .characterMapping) }
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
