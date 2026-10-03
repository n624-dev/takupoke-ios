import Foundation
#if canImport(PDFKit)
import PDFKit
import CoreGraphics

struct PDFDisplayTransform {
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

final class PDFPathReader {
    let transform: PDFDisplayTransform
    let check: () throws -> Void
    let verifyVisibility: Bool
    let textBoxes: [PDFBox]
    var ctm = CGAffineTransform.identity
    var stack: [CGAffineTransform] = []
    private var widthStack: [Double] = []
    private var lineWidth = 1.0
    var paths: [[CGPoint]] = []
    var lines: [PDFRule] = []
    var arrows: [PDFArrow] = []
    var failure: Error?
    var operations = 0
    private var textSeen = false
    private var paintWork = 0
    private static let maximumPaintWork = 1_000_000

    private struct PathBounds {
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var bottom: CGFloat
    }

    init(transform: PDFDisplayTransform, verifyVisibility: Bool = false, textBoxes: [PDFBox] = [], check: @escaping () throws -> Void) {
        self.transform = transform; self.verifyVisibility = verifyVisibility; self.textBoxes = textBoxes; self.check = check
    }
    static func state(_ info: UnsafeMutableRawPointer?) -> PDFPathReader? {
        guard let info = info else { return nil }
        let s = Unmanaged<PDFPathReader>.fromOpaque(info).takeUnretainedValue()
        guard s.failure == nil else { return nil }
        s.operations += 1
        if s.operations > 1000000 { s.failure = PDFParseError(code: .limit); return nil }
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
    // Operator limits do not cover work within one paint callback. Charge point
    // visits, path visits, stem comparisons and stroke segments across the page.
    private func consumePaintWork() -> Bool {
        guard failure == nil else { return false }
        paintWork += 1
        guard paintWork <= Self.maximumPaintWork else {
            failure = PDFParseError(code: .limit)
            return false
        }
        if paintWork % 128 == 0 {
            do { try check() } catch { failure = error; return false }
        }
        return true
    }

    private func bounds(of path: [CGPoint]) -> PathBounds? {
        guard let first = path.first else { return nil }
        var result = PathBounds(left: first.x, right: first.x, top: first.y, bottom: first.y)
        for point in path {
            guard consumePaintWork() else { return nil }
            result.left = min(result.left, point.x); result.right = max(result.right, point.x)
            result.top = min(result.top, point.y); result.bottom = max(result.bottom, point.y)
        }
        return result
    }

    private func overlapsText(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat, pad: Double) -> Bool {
        for box in textBoxes {
            // The collision loop is part of the page work budget, even when
            // every glyph is disjoint. Fail closed and preserve its first error.
            guard consumePaintWork() else { return true }
            if box.left <= Double(right)+pad && Double(left)-pad <= box.right && box.top <= Double(bottom)+pad && Double(top)-pad <= box.bottom { return true }
        }
        return false
    }
    func paint(fill: Bool, stroke: Bool) {
        defer { paths.removeAll(keepingCapacity: true) }
        guard failure == nil else { return }
        do { try check() } catch { failure = error; return }
        if verifyVisibility && fill && !paths.isEmpty {
            guard !textSeen else { failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return }
            // Only independent thin rectangular table rules are supported before
            // text. A broad background fill may make black text invisible too.
            for path in paths {
                guard let first = path.first, path.count == 5, path.last == first,
                      Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
                      let box = bounds(of:path) else {
                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
                }
                let width = box.right-box.left, height = box.bottom-box.top
                guard ((width <= 2.1 && height > 3) || (height <= 2.1 && width > 3)),
                      !overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0) else {
                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
                }
            }
        }
        if verifyVisibility && stroke && !paths.isEmpty {
            guard let pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) else {
                failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return
            }
            for path in paths where path.count >= 2 {
                for index in 1..<path.count {
                    guard consumePaintWork() else { return }
                    let a = path[index-1], b = path[index]
                    guard (abs(a.x-b.x) < 0.2 || abs(a.y-b.y) < 0.2),
                          !overlapsText(left:min(a.x,b.x),top:min(a.y,b.y),right:max(a.x,b.x),bottom:max(a.y,b.y),pad:pad) else {
                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
                    }
                }
            }
        }
        var pathBounds: [PathBounds?] = []
        if fill {
            var stems: [PathBounds] = []
            pathBounds.reserveCapacity(paths.count)
            for path in paths {
                guard consumePaintWork() else { return }
                let box = bounds(of: path)
                guard failure == nil else { return }
                pathBounds.append(box)
                if path.count >= 4, let box, box.right - box.left < 2.1, box.bottom - box.top > 5 {
                    stems.append(box)
                }
            }
            // The supported calendar draws each arrow as a narrow stem and a filled triangle.
            for path in paths {
                guard consumePaintWork() else { return }
                var vertices = path
                if vertices.count == 4, vertices.first == vertices.last { vertices.removeLast() }
                guard vertices.count == 3 else { continue }
                let sorted = vertices.sorted { $0.y < $1.y }
                let a = sorted[0], b = sorted[1], tip = sorted[2]
                guard abs(a.y - b.y) < 1, (3...12).contains(abs(a.x - b.x)),
                      (3...12).contains(tip.y - max(a.y, b.y)),
                      abs(tip.x - (a.x + b.x) / 2) < 1 else { continue }
                var matchedStem: PathBounds?
                var ambiguous = false
                for stem in stems {
                    guard consumePaintWork() else { return }
                    guard abs((stem.left + stem.right) / 2 - tip.x) < 2,
                          abs(stem.bottom - max(a.y, b.y)) < 2 else { continue }
                    if matchedStem != nil { ambiguous = true; break }
                    matchedStem = stem
                }
                if let stem = matchedStem, !ambiguous {
                    arrows.append(PDFArrow(x: Double(tip.x), top: Double(stem.top), bottom: Double(tip.y)))
                }
            }
        }
        for (index, path) in paths.enumerated() {
            guard consumePaintWork() else { return }
            guard path.count >= 2 else { continue }
            if fill, let box = pathBounds[index] {
                let l = box.left, r = box.right, t = box.top, b = box.bottom
                // Thin painted rectangles form the grid; ignore broad fills and highlights.
                if r - l <= 2.1, b - t > 3 { line(CGPoint(x: (l + r) / 2, y: t), CGPoint(x: (l + r) / 2, y: b)) }
                else if b - t <= 2.1, r - l > 3 { line(CGPoint(x: l, y: (t + b) / 2), CGPoint(x: r, y: (t + b) / 2)) }
            }
            if stroke {
                for i in 1..<path.count {
                    guard consumePaintWork() else { return }
                    line(path[i - 1], path[i])
                }
            }
        }
    }
    // PDFKit selections also expose text that is not painted. A special schedule
    // can reuse them only when the content stream has independently proved that
    // opacity, text rendering and visibility are within this reader's subset.
    private func graphicsStateIsVisible(_ scanner: CGPDFScannerRef) -> Bool {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &name), let name,
              let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "ExtGState", String(cString:name)) else { return false }
        var dictionary: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary else { return false }
        for key in ["Font", "SMask", "TR", "TR2"] {
            var value: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,key,&value) { return false }
        }
        var width: CGPDFReal = 0, widthObject: CGPDFObjectRef?
        if CGPDFDictionaryGetNumber(dictionary,"LW",&width) {
            guard width.isFinite, width >= 0 else { return false }
            lineWidth = Double(width)
        } else if CGPDFDictionaryGetObject(dictionary,"LW",&widthObject) { return false }
        var blendMode: UnsafePointer<CChar>?, blendObject: CGPDFObjectRef?
        if CGPDFDictionaryGetName(dictionary,"BM",&blendMode), let blendMode {
            guard String(cString:blendMode) == "Normal" else { return false }
        } else if CGPDFDictionaryGetObject(dictionary,"BM",&blendObject) { return false }
        for key in ["ca", "CA"] {
            var value: CGPDFReal = 0, object: CGPDFObjectRef?
            if CGPDFDictionaryGetNumber(dictionary,key,&value) {
                guard value.isFinite, value == 1 else { return false }
            } else if CGPDFDictionaryGetObject(dictionary,key,&object) { return false }
        }
        return true
    }
    func read(_ page: CGPDFPage) throws -> [PDFRule] {
        guard let table = CGPDFOperatorTableCreate() else { throw PDFParseError(code: .unreadable) }
        defer { CGPDFOperatorTableRelease(table) }
        CGPDFOperatorTableSetCallback(table, "q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit) } else { s.stack.append(s.ctm); s.widthStack.append(s.lineWidth) }
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if let value = s.stack.popLast(), let width = s.widthStack.popLast() { s.ctm = value; s.lineWidth = width } else { s.failure = PDFParseError(code: .unreadable) }
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
                guard let s = PDFPathReader.state(p) else { return }
                if s.verifyVisibility { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return }
                if !s.paths.isEmpty { s.paths[s.paths.count - 1].removeAll() }
            }
        }
        // Form XObjects may contain an otherwise unseen part of the table. Fail closed.
        CGPDFOperatorTableSetCallback(table, "Do") { _, p in
            PDFPathReader.state(p)?.failure = PDFParseError(code: .unsupported, stage: .vectorObjects)
        }
        if verifyVisibility {
            CGPDFOperatorTableSetCallback(table, "w") { scanner, p in
                guard let s = PDFPathReader.state(p), let width = s.numbers(scanner,1)?.first else { return }
                guard width >= 0 else { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return }
                s.lineWidth = Double(width)
            }
            CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in
                guard let s = PDFPathReader.state(p) else { return }
                if !s.graphicsStateIsVisible(scanner) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
            }
            CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
                guard let s = PDFPathReader.state(p), let mode = s.numbers(scanner,1)?.first else { return }
                if mode != 0 { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
            }
            for op in ["Tj", "TJ", "'", "\""] {
                CGPDFOperatorTableSetCallback(table, op) { _, p in PDFPathReader.state(p)?.textSeen = true }
            }
            for op in ["g", "G"] {
                CGPDFOperatorTableSetCallback(table, op) { scanner, p in
                    guard let s = PDFPathReader.state(p), let n = s.numbers(scanner,1) else { return }
                    if !PDFTextVisibility.blackColor(n.map { Double($0) },count:1) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
                }
            }
            for op in ["rg", "RG"] {
                CGPDFOperatorTableSetCallback(table, op) { scanner, p in
                    guard let s = PDFPathReader.state(p), let n = s.numbers(scanner,3) else { return }
                    if !PDFTextVisibility.blackColor(n.map { Double($0) },count:3) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
                }
            }
            for op in ["k", "K"] {
                CGPDFOperatorTableSetCallback(table, op) { scanner, p in
                    guard let s = PDFPathReader.state(p), let n = s.numbers(scanner,4) else { return }
                    if !PDFTextVisibility.blackColor(n.map { Double($0) },count:4) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
                }
            }
            // Clipping or optional/marked content requires raster verification;
            // a selectable character does not establish that it is visible.
            for op in ["W", "W*", "BDC", "BMC", "BI", "ID", "EI", "sh", "cs", "CS", "sc", "SC", "scn", "SCN"] {
                CGPDFOperatorTableSetCallback(table, op) { _, p in
                    PDFPathReader.state(p)?.failure = PDFParseError(code:.unsupported,stage:.vectorObjects)
                }
            }
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
