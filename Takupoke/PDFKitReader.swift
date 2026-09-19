#if canImport(PDFKit)
import Foundation
import PDFKit
import CoreGraphics

/// PDFKit supplies text, Core Graphics supplies painted table rules.
/// No JavaScript, links, embedded files, or actions in a PDF are executed.
enum PDFKitReader {
    static func read(_ url: URL, check: @escaping () throws -> Void = {}) throws -> [PDFPageLayout] {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= MaterialLibrary.maximumBytes,
              let document = PDFDocument(url: url), !document.isLocked,
              document.pageCount > 0, document.pageCount <= 12 else { throw PDFParseError(code: .unreadable) }
        var output: [PDFPageLayout] = []
        for index in 0..<document.pageCount {
            try check()
            guard let page = document.page(at: index), let ref = page.pageRef,
                  let string = page.string, page.numberOfCharacters <= 100000 else {
                throw PDFParseError(code: .unreadable, page: index + 1)
            }
            let media = ref.getBoxRect(.mediaBox)
            let rotation = ((page.rotation % 360) + 360) % 360
            guard [0, 90, 180, 270].contains(rotation) else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation)
            }
            let transform = PDFDisplayTransform(media: media, rotation: rotation)
            let ns = string as NSString
            guard ns.length == page.numberOfCharacters else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
            }
            guard ns.length > 0, let pageSelection = page.selection(for: NSRange(location: 0, length: ns.length)) else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
            }
            var sourceLines = [Int?](repeating: nil, count: ns.length)
            let textLines = pageSelection.selectionsByLine()
            guard textLines.count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
            var coveredUnits = 0
            for (lineID, line) in textLines.enumerated() {
                try check()
                let count = line.numberOfTextRanges(on: page)
                guard count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
                for rangeIndex in 0..<count {
                    let range = line.range(at: rangeIndex, on: page)
                    guard range.location >= 0, range.location <= ns.length,
                          range.length >= 0, range.length <= ns.length - range.location else {
                        throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                    }
                    coveredUnits += range.length
                    guard coveredUnits <= ns.length * 2 else { throw PDFParseError(code: .limit, page: index + 1) }
                    for offset in range.location..<NSMaxRange(range) {
                        if let scalar = UnicodeScalar(UInt32(ns.character(at: offset))),
                           CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
                        guard sourceLines[offset] == nil || sourceLines[offset] == lineID else {
                            throw PDFParseError(code: .ambiguous, page: index + 1, stage: .textOrder)
                        }
                        sourceLines[offset] = lineID
                    }
                }
            }
            var glyphs: [PDFGlyph] = []
            var cursor = 0
            while cursor < ns.length {
                if cursor % 128 == 0 { try check() }
                let range = ns.rangeOfComposedCharacterSequence(at: cursor)
                let text = ns.substring(with: range)
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    guard let sourceLine = sourceLines[cursor],
                          (range.location..<NSMaxRange(range)).allSatisfy({ sourceLines[$0] == sourceLine }) else {
                        throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                    }
                    // Obtain text and bounds from the same UTF-16 selection. Do not pair
                    // page.string with a separately indexed characterBounds result: their
                    // text layout/indexing can differ between PDFKit implementations.
                    guard let selection = page.selection(for: range), selection.string == text else {
                        throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                    }
                    let box = selection.bounds(for: page)
                    guard !box.isNull, !box.isEmpty,
                          [box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite) else {
                        // Dropping a visible character could silently change a subject or date.
                        throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                    }
                    let b = transform.rect(box)
                    glyphs.append(PDFGlyph(text: text, x: Double(b.minX), y: Double(b.minY),
                                           width: Double(b.width), height: Double(b.height),
                                           sourceLine: sourceLine, sourceOrder: cursor))
                }
                cursor = NSMaxRange(range)
            }
            let reader = PDFPathReader(transform: transform, check: check)
            let lines: [PDFRule]
            do { lines = try reader.read(ref) }
            catch var error as PDFParseError { error.page = index + 1; throw error }
            guard !glyphs.isEmpty, !lines.isEmpty else { throw PDFParseError(code: .unreadable, page: index + 1) }
            output.append(PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows))
        }
        return output
    }
}

private struct PDFDisplayTransform {
    let media: CGRect
    let rotation: Int
    var width: CGFloat { rotation == 90 || rotation == 270 ? media.height : media.width }
    var height: CGFloat { rotation == 90 || rotation == 270 ? media.width : media.height }
    func point(_ p: CGPoint) -> CGPoint {
        let x = p.x - media.minX, y = p.y - media.minY
        switch rotation {
        case 90: return CGPoint(x: y, y: x)
        case 180: return CGPoint(x: media.width - x, y: y)
        case 270: return CGPoint(x: media.height - y, y: media.width - x)
        default: return CGPoint(x: x, y: media.height - y)
        }
    }
    func rect(_ r: CGRect) -> CGRect {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX, y: r.maxY),
         CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY)].map(point).reduce(CGRect.null) {
            $0.union(CGRect(origin: $1, size: .zero))
        }
    }
}

private final class PDFPathReader {
    let transform: PDFDisplayTransform
    let check: () throws -> Void
    var ctm = CGAffineTransform.identity
    var stack: [CGAffineTransform] = []
    var paths: [[CGPoint]] = []
    var lines: [PDFRule] = []
    var arrows: [PDFArrow] = []
    var failure: Error?
    var operations = 0

    init(transform: PDFDisplayTransform, check: @escaping () throws -> Void) { self.transform = transform; self.check = check }
    static func state(_ info: UnsafeMutableRawPointer?) -> PDFPathReader? {
        guard let info = info else { return nil }
        let s = Unmanaged<PDFPathReader>.fromOpaque(info).takeUnretainedValue()
        s.operations += 1
        if s.operations > 1000000 { s.failure = PDFParseError(code: .limit) }
        if s.operations % 128 == 0 { do { try s.check() } catch { s.failure = error } }
        return s.failure == nil ? s : nil
    }
    func numbers(_ scanner: CGPDFScannerRef, _ count: Int) -> [CGFloat]? {
        var result: [CGFloat] = []
        for _ in 0..<count {
            var n: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &n), n.isFinite else { failure = PDFParseError(code: .unreadable); return nil }
            result.insert(CGFloat(n), at: 0)
        }
        return result
    }
    func position(_ x: CGFloat, _ y: CGFloat) -> CGPoint { transform.point(CGPoint(x: x, y: y).applying(ctm)) }
    func close() {
        if let start = paths.last?.first { paths[paths.count - 1].append(start) }
    }
    func line(_ a: CGPoint, _ b: CGPoint) {
        if abs(a.x - b.x) < 0.2, abs(a.y - b.y) > 0.1 {
            lines.append(PDFRule(x1: Double((a.x + b.x) / 2), y1: Double(min(a.y, b.y)), x2: Double((a.x + b.x) / 2), y2: Double(max(a.y, b.y))))
        } else if abs(a.y - b.y) < 0.2, abs(a.x - b.x) > 0.1 {
            lines.append(PDFRule(x1: Double(min(a.x, b.x)), y1: Double((a.y + b.y) / 2), x2: Double(max(a.x, b.x)), y2: Double((a.y + b.y) / 2)))
        }
        if lines.count > 100000 { failure = PDFParseError(code: .limit) }
    }
    func paint(fill: Bool, stroke: Bool) {
        defer { paths.removeAll(keepingCapacity: true) }
        if fill {
            // The supported calendar draws each arrow as a narrow stem and a filled triangle.
            for path in paths {
                var vertices = path
                if vertices.count == 4, vertices.first == vertices.last { vertices.removeLast() }
                guard vertices.count == 3 else { continue }
                let sorted = vertices.sorted { $0.y < $1.y }
                let a = sorted[0], b = sorted[1], tip = sorted[2]
                guard abs(a.y - b.y) < 1, (3...12).contains(abs(a.x - b.x)),
                      (3...12).contains(tip.y - max(a.y, b.y)),
                      abs(tip.x - (a.x + b.x) / 2) < 1 else { continue }
                let stems = paths.filter { other in
                    guard other.count >= 4 else { return false }
                    let l = other.map(\.x).min()!, r = other.map(\.x).max()!
                    let t = other.map(\.y).min()!, end = other.map(\.y).max()!
                    return r - l < 2.1 && end - t > 5 && abs((l + r) / 2 - tip.x) < 2 &&
                        abs(end - max(a.y, b.y)) < 2
                }
                if stems.count == 1, let top = stems[0].map(\.y).min() {
                    arrows.append(PDFArrow(x: Double(tip.x), top: Double(top), bottom: Double(tip.y)))
                }
            }
        }
        for path in paths where path.count >= 2 {
            if fill {
                let xs = path.map(\.x), ys = path.map(\.y)
                let l = xs.min()!, r = xs.max()!, t = ys.min()!, b = ys.max()!
                // Thin painted rectangles form the grid; ignore broad fills and highlights.
                if r - l <= 2.1, b - t > 3 { line(CGPoint(x: (l + r) / 2, y: t), CGPoint(x: (l + r) / 2, y: b)) }
                else if b - t <= 2.1, r - l > 3 { line(CGPoint(x: l, y: (t + b) / 2), CGPoint(x: r, y: (t + b) / 2)) }
            }
            if stroke { for i in 1..<path.count { line(path[i - 1], path[i]) } }
        }
    }
    func read(_ page: CGPDFPage) throws -> [PDFRule] {
        guard let table = CGPDFOperatorTableCreate() else { throw PDFParseError(code: .unreadable) }
        defer { CGPDFOperatorTableRelease(table) }
        CGPDFOperatorTableSetCallback(table, "q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit) } else { s.stack.append(s.ctm) }
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if let value = s.stack.popLast() { s.ctm = value } else { s.failure = PDFParseError(code: .unreadable) }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 6) else { return }
            s.ctm = CGAffineTransform(a: n[0], b: n[1], c: n[2], d: n[3], tx: n[4], ty: n[5]).concatenating(s.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "m") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 2) else { return }
            s.paths.append([s.position(n[0], n[1])])
            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit) }
        }
        CGPDFOperatorTableSetCallback(table, "l") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 2), !s.paths.isEmpty else { return }
            s.paths[s.paths.count - 1].append(s.position(n[0], n[1]))
            if s.paths[s.paths.count - 1].count > 10000 { s.failure = PDFParseError(code: .limit) }
        }
        CGPDFOperatorTableSetCallback(table, "re") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 4) else { return }
            let x = n[0], y = n[1], w = n[2], h = n[3]
            s.paths.append([s.position(x, y), s.position(x + w, y), s.position(x + w, y + h), s.position(x, y + h), s.position(x, y)])
            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit) }
        }
        CGPDFOperatorTableSetCallback(table, "h") { _, p in PDFPathReader.state(p)?.close() }
        CGPDFOperatorTableSetCallback(table, "S") { _, p in PDFPathReader.state(p)?.paint(fill: false, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "s") { _, p in let s = PDFPathReader.state(p); s?.close(); s?.paint(fill: false, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "f") { _, p in PDFPathReader.state(p)?.paint(fill: true, stroke: false) }
        CGPDFOperatorTableSetCallback(table, "F") { _, p in PDFPathReader.state(p)?.paint(fill: true, stroke: false) }
        CGPDFOperatorTableSetCallback(table, "f*") { _, p in PDFPathReader.state(p)?.paint(fill: true, stroke: false) }
        CGPDFOperatorTableSetCallback(table, "B") { _, p in PDFPathReader.state(p)?.paint(fill: true, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "B*") { _, p in PDFPathReader.state(p)?.paint(fill: true, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "b") { _, p in let s = PDFPathReader.state(p); s?.close(); s?.paint(fill: true, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "b*") { _, p in let s = PDFPathReader.state(p); s?.close(); s?.paint(fill: true, stroke: true) }
        CGPDFOperatorTableSetCallback(table, "n") { _, p in PDFPathReader.state(p)?.paths.removeAll(keepingCapacity: true) }
        // Curves cannot form supported table rules. Drop that subpath instead of joining across a curve.
        for op in ["c", "v", "y"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in
                guard let s = PDFPathReader.state(p), !s.paths.isEmpty else { return }
                s.paths[s.paths.count - 1].removeAll()
            }
        }
        // Form XObjects may contain an otherwise unseen part of the table. Fail closed.
        CGPDFOperatorTableSetCallback(table, "Do") { _, p in
            PDFPathReader.state(p)?.failure = PDFParseError(code: .unsupported, stage: .vectorObjects)
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        let succeeded = CGPDFScannerScan(scanner)
        if let failure = failure { throw failure }
        try check()
        guard succeeded else { throw PDFParseError(code: .unreadable) }
        return lines
    }
}
#endif
