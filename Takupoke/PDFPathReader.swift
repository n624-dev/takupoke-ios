import Foundation

/// Broad-phase lookup only: every candidate still uses the original inclusive
/// collision predicate. Index creation/search consume the caller's same budget.
struct PDFTextCollisionIndex {
    private let boxes: [PDFBox]
    private let xOrder: [Int]
    private let yOrder: [Int]
    private let maximumWidth: Double
    private let maximumHeight: Double

    init(_ boxes: [PDFBox], work: () throws -> Void) throws {
        guard boxes.count <= 100000 else { throw PDFParseError(code:.limit, branch:.b113) }
        var width = 0.0, height = 0.0
        for box in boxes {
            try work()
            guard [box.left,box.top,box.right,box.bottom].allSatisfy(\.isFinite),
                  box.left <= box.right, box.top <= box.bottom,
                  (box.right-box.left).isFinite, (box.bottom-box.top).isFinite else { throw PDFParseError(code:.unreadable, branch:.b114) }
            width = max(width,box.right-box.left); height = max(height,box.bottom-box.top)
        }
        self.boxes = boxes; maximumWidth = width.nextUp; maximumHeight = height.nextUp
        xOrder = try boxes.indices.sorted { a,b in try work(); return boxes[a].left < boxes[b].left }
        yOrder = try boxes.indices.sorted { a,b in try work(); return boxes[a].top < boxes[b].top }
    }
    private func range(_ order: [Int], horizontal: Bool, lower: Double, upper: Double,
                       work: () throws -> Void) throws -> Range<Int> {
        func bound(_ target: Double, afterEqual: Bool) throws -> Int {
            var start = 0, end = order.count
            while start < end {
                try work()
                let mid = start+(end-start)/2
                let coordinate = horizontal ? boxes[order[mid]].left : boxes[order[mid]].top
                if coordinate < target || afterEqual && coordinate == target { start = mid+1 } else { end = mid }
            }
            return start
        }
        return try bound(lower,afterEqual:false)..<bound(upper,afterEqual:true)
    }
    func overlaps(_ query: PDFBox, pad: Double, excluding: Int? = nil, work: () throws -> Void) throws -> Bool {
        guard [query.left,query.top,query.right,query.bottom,pad].allSatisfy(\.isFinite),
              query.left <= query.right, query.top <= query.bottom, pad >= 0,
              (query.left-pad).isFinite, (query.top-pad).isFinite,
              (query.right+pad).isFinite, (query.bottom+pad).isFinite else { throw PDFParseError(code:.unreadable, branch:.b115) }
        // An overlapping box starts no earlier than query-min minus the largest
        // original extent. Outward rounding only broadens candidates; the exact
        // collision predicate below still includes the same touching edges.
        let xs = try range(xOrder,horizontal:true,lower:(query.left-pad-maximumWidth).nextDown,upper:(query.right+pad).nextUp,work:work)
        let ys = try range(yOrder,horizontal:false,lower:(query.top-pad-maximumHeight).nextDown,upper:(query.bottom+pad).nextUp,work:work)
        let horizontal = xs.count < ys.count
        let selected = horizontal ? xs : ys, order = horizontal ? xOrder : yOrder
        for index in selected {
            try work()
            if order[index] == excluding { continue }
            let box = boxes[order[index]]
            if box.left <= query.right+pad && query.left-pad <= box.right &&
               box.top <= query.bottom+pad && query.top-pad <= box.bottom { return true }
        }
        return false
    }
}
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
    private var colors = PDFPaintColors()
    private var colorStack: [PDFPaintColors] = []
    private var uncertifiedOverprint = false
    private var overprintStack: [Bool] = []
    private var markedContent = PDFMarkedContent()
    private var clips: [PDFBox] = []
    private var paintedBoxes: [PDFBox] = []
    private var collisionBoxes: [PDFBox] = []
    private var backgroundBrightness: ClosedRange<Double>?
    private let paintResolver = PDFPaintSpaceResolver()
    var paths: [[CGPoint]] = []
    var lines: [PDFRule] = []
    var arrows: [PDFArrow] = []
    var failure: Error?
    var operations = 0
    private var textSeen = false
    private var textMode = 0.0
    private var textModeStack: [Double] = []
    private var solidDash = true
    private var dashStack: [Bool] = []
    private var curvedPath = false
    private(set) var hasOutlinedText = false
    private(set) var paintWork = 0
    private var textIndex: PDFTextCollisionIndex?
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
        if s.operations > 1000000 { s.failure = PDFParseError(code: .limit, branch:.b116); return nil }
        if s.operations % 128 == 0 { do { try s.check() } catch { s.failure = error } }
        return s.failure == nil ? s : nil
    }
    func numbers(_ scanner: CGPDFScannerRef, _ count: Int) -> [CGFloat]? {
        var result: [CGFloat] = []
        for _ in 0..<count {
            var n: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &n), n.isFinite else { failure = PDFParseError(code: .unreadable, branch:.b117); return nil }
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
        if lines.count > 100000 { failure = PDFParseError(code: .limit, branch:.b118) }
    }
    // Operator limits do not cover work within one paint callback. Charge point
    // visits, path visits, stem comparisons and stroke segments across the page.
    private func consumePaintWork() -> Bool {
        guard failure == nil else { return false }
        paintWork += 1
        guard paintWork <= Self.maximumPaintWork else {
            failure = PDFParseError(code: .limit, branch:.b119)
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
        do {
            let work = { [self] in
                guard consumePaintWork() else { throw failure ?? PDFParseError(code:.limit, branch:.b120) }
            }
            if textIndex == nil { textIndex = try PDFTextCollisionIndex(textBoxes,work:work) }
            return try textIndex!.overlaps(PDFBox(left:Double(left),top:Double(top),right:Double(right),bottom:Double(bottom)),pad:pad,work:work)
        } catch {
            if failure == nil { failure = error }
            return true
        }
    }
    func paint(fill: Bool, stroke: Bool) {
        defer { paths.removeAll(keepingCapacity: true); curvedPath = false }
        guard failure == nil else { return }
        do { try check() } catch { failure = error; return }
        if verifyVisibility && (curvedPath || stroke && !solidDash && !paths.isEmpty) {
            failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b121); return
        }
        if verifyVisibility && !paths.isEmpty {
            // A white page background is harmless only before any retained ink.
            if fill && !stroke && colors.fill.isWhite && !textSeen && lines.isEmpty && arrows.isEmpty && paintedBoxes.isEmpty,
               paths.count == 1, let box = rectangularPathBox(),
               box == PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height)) { return }
            guard (!fill || colors.fill.isVisibleInk) && (!stroke || colors.stroke.isVisibleInk) else {
                failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b122); return
            }
        }
        if verifyVisibility && fill && !paths.isEmpty {
            guard !textSeen || !textBoxes.isEmpty else {
                failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b123); return
            }
            // Certify rectangles against all original text, including later
            // glyphs. Only thin fills become rules below; a disjoint decoration
            // must not fail merely because it is too broad to be a table rule.
            for path in paths {
                if !stroke && isSupportedArrowHead(path) {
                    guard requireBackgroundContrast(colors.fill) else { return }
                    guard let box = bounds(of:path),
                          !overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0) else {
                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b124) }; return
                    }
                    collisionBoxes.append(PDFBox(left:Double(box.left),top:Double(box.top),right:Double(box.right),bottom:Double(box.bottom)))
                    continue
                }
                guard let first = path.first, path.count == 5, path.last == first,
                      Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
                      let box = bounds(of:path) else {
                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b125) }; return
                }
                let corners = [CGPoint(x:box.left,y:box.top),CGPoint(x:box.right,y:box.top),CGPoint(x:box.right,y:box.bottom),CGPoint(x:box.left,y:box.bottom)]
                let uniqueCorners = corners.allSatisfy { corner in path.dropLast().filter { $0 == corner }.count == 1 }
                let axisEdges = zip(path,path.dropFirst()).allSatisfy { a,b in (a.x == b.x) != (a.y == b.y) }
                let width = box.right-box.left, height = box.bottom-box.top
                let thinRule = (width <= 2.1 && height > 3) || (height <= 2.1 && width > 3)
                // Standalone scans without acquired text bounds cannot certify
                // a decoration against text that may be painted later.
                guard uniqueCorners else {
                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b126) }; return
                }
                guard axisEdges else {
                    failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b263); return
                }
                guard thinRule || !textBoxes.isEmpty else {
                    failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b264); return
                }
                let overlaps = overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0)
                guard failure == nil else { return }
                if overlaps {
                    // A broad opaque rectangle before the first text operation
                    // is a background, never a rule. Subsequent text must also
                    // prove contrast; paint order alone does not prove visibility.
                    guard !textSeen, !stroke, !thinRule else {
                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b265); return
                    }
                    // One simple rectangle fills under both winding rules.
                    // Multiple subpaths can cancel or cut holes (f / f*).
                    guard paths.count == 1 else {
                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b270); return
                    }
                    guard !uncertifiedOverprint else {
                        failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b271); return
                    }
                    // Do not retain grid ink which an opaque background could
                    // have erased. Earlier certified backgrounds alone are safe.
                    guard lines.isEmpty, arrows.isEmpty, collisionBoxes.isEmpty else {
                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b268); return
                    }
                    guard let brightness = colors.fill.renderedBrightness,
                          brightness.isFinite, (0...1).contains(brightness) else {
                        failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b266); return
                    }
                    if let previous = backgroundBrightness {
                        backgroundBrightness = min(previous.lowerBound,brightness)...max(previous.upperBound,brightness)
                    } else {
                        // White remains a possible surface outside a partial
                        // background; do not certify light text against dark
                        // paint which might belong to a different cell.
                        backgroundBrightness = brightness...1
                    }
                } else {
                    guard requireBackgroundContrast(colors.fill) else { return }
                    collisionBoxes.append(PDFBox(left:Double(box.left),top:Double(box.top),right:Double(box.right),bottom:Double(box.bottom)))
                }
            }
        }
        if verifyVisibility && stroke && !paths.isEmpty {
            guard requireBackgroundContrast(colors.stroke) else { return }
            guard PDFTextVisibility.similarStrokeTransform(a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)),
                  let pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) else {
                failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b127); return
            }
            for path in paths where path.count >= 2 {
                for index in 1..<path.count {
                    guard consumePaintWork() else { return }
                    let a = path[index-1], b = path[index]
                    guard (a.x == b.x || a.y == b.y),
                          !overlapsText(left:min(a.x,b.x),top:min(a.y,b.y),right:max(a.x,b.x),bottom:max(a.y,b.y),pad:pad) else {
                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b128) }; return
                    }
                    collisionBoxes.append(PDFBox(left:Double(min(a.x,b.x))-pad,top:Double(min(a.y,b.y))-pad,
                                                 right:Double(max(a.x,b.x))+pad,bottom:Double(max(a.y,b.y))+pad))
                }
            }
        }
        if collisionBoxes.count > 100_000 { failure = PDFParseError(code:.limit, branch:.b129); return }
        if verifyVisibility {
            let pad: Double
            if stroke {
                pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) ?? 0
            } else { pad = 0 }
            for path in paths where path.count >= 2 {
                guard let box = bounds(of:path), paintedBoxes.count < 100_000 else {
                    if failure == nil { failure = PDFParseError(code:.limit, branch:.b130) }; return
                }
                paintedBoxes.append(PDFBox(left:Double(box.left)-pad,top:Double(box.top)-pad,
                                           right:Double(box.right)+pad,bottom:Double(box.bottom)+pad))
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
    private func isSupportedArrowHead(_ path: [CGPoint]) -> Bool {
        var vertices = path
        if vertices.count == 4, vertices.first == vertices.last { vertices.removeLast() }
        guard vertices.count == 3 else { return false }
        let sorted = vertices.sorted { $0.y < $1.y }
        let a = sorted[0], b = sorted[1], tip = sorted[2]
        guard abs(a.y-b.y) < 1, (3...12).contains(abs(a.x-b.x)),
              (3...12).contains(tip.y-max(a.y,b.y)), abs(tip.x-(a.x+b.x)/2) < 1 else { return false }
        var matches = 0
        for stem in paths {
            guard consumePaintWork() else { return false }
            guard stem.count == 5, stem.first == stem.last,
                  Set(stem.map(\.x)).count == 2, Set(stem.map(\.y)).count == 2,
                  zip(stem,stem.dropFirst()).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }),
                  let box = bounds(of:stem), box.right-box.left < 2.1, box.bottom-box.top > 5,
                  abs((box.left+box.right)/2-tip.x) < 2, abs(box.bottom-max(a.y,b.y)) < 2 else { continue }
            matches += 1
            if matches > 1 { return false }
        }
        return matches == 1
    }
    private func contrastsWithBackground(_ paint: PDFDevicePaint) -> Bool {
        guard let background = backgroundBrightness else { return true }
        guard !uncertifiedOverprint else { return false }
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055,2.4)
        }
        guard let value = paint.renderedBrightness, value.isFinite, (0...1).contains(value) else { return false }
        // Check the nearest brightness in the entire background interval,
        // including combinations conservatively, without per-glyph guesses.
        let nearest = min(max(value,background.lowerBound),background.upperBound)
        let a = linear(value), b = linear(nearest)
        return (max(a,b)+0.05)/(min(a,b)+0.05) >= 4.5
    }
    private func requireBackgroundContrast(_ paint: PDFDevicePaint) -> Bool {
        guard contrastsWithBackground(paint) else {
            failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b269); return false
        }
        return true
    }
    private func textContrastsWithBackground() -> Bool {
        switch textMode {
        case 0: return contrastsWithBackground(colors.fill)
        case 1: return contrastsWithBackground(colors.stroke)
        case 2: return contrastsWithBackground(colors.fill) && contrastsWithBackground(colors.stroke)
        default: return false
        }
    }
    private func rectangularPathBox() -> PDFBox? {
        guard paths.count == 1, let path = paths.first, path.count == 5, path.first == path.last,
              Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
              zip(path,path.dropFirst()).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }),
              path.dropLast().allSatisfy({ point in path.dropLast().filter { $0 == point }.count == 1 }) else { return nil }
        return PDFBox(left:Double(path.map(\.x).min()!),top:Double(path.map(\.y).min()!),
                      right:Double(path.map(\.x).max()!),bottom:Double(path.map(\.y).max()!))
    }
    private func recordClip() {
        guard let box = rectangularPathBox() else { failure = PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b131); return }
        let page = PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height))
        guard PDFClipValidation.contains(box,page) else {
            failure = PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b132); return
        }
        guard clips.count < 128 else { failure = PDFParseError(code:.limit, branch:.b133); return }
        clips.append(box)
    }
    private func color(_ scanner: CGPDFScannerRef, stroke: Bool, count: Int? = nil, space: Bool = false) {
        do {
            var paint = stroke ? colors.stroke : colors.fill
            if space {
                try paint.space(scanner,resolver:paintResolver)
            } else {
                if let count {
                    guard let n = numbers(scanner,count) else { return }
                    try paint.device(n.map(Double.init),count:count)
                    try paint.applyDefault(scanner,resolver:paintResolver)
                } else { try paint.color(scanner) }
            }
            if stroke { colors.stroke = paint } else { colors.fill = paint }
        } catch { failure = error }
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
        do { try colors.applyIntent(dictionary) } catch { return false }
        // The single-color probe does not model overprint compositing. Keep
        // existing no-background reads unchanged, but do not certify a new
        // background or subsequent ink under enabled/unknown overprint.
        for key in ["OP", "op"] {
            var object: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,key,&object) {
                var value: CGPDFBoolean = 0
                if !CGPDFDictionaryGetBoolean(dictionary,key,&value) || value != 0 {
                    uncertifiedOverprint = true
                }
            }
        }
        for key in ["Font", "SMask", "TR", "TR2"] {
            var value: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary,key,&value) { return false }
        }
        var dashObject: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(dictionary,"D",&dashObject) {
            var dash: CGPDFArrayRef?, pattern: CGPDFArrayRef?, phase: CGPDFReal = 0
            guard CGPDFDictionaryGetArray(dictionary,"D",&dash), let dash, CGPDFArrayGetCount(dash) == 2,
                  CGPDFArrayGetArray(dash,0,&pattern), let pattern,
                  CGPDFArrayGetNumber(dash,1,&phase) else { return false }
            do { solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase)) } catch { return false }
        }
        var width: CGPDFReal = 0, widthObject: CGPDFObjectRef?
        if CGPDFDictionaryGetNumber(dictionary,"LW",&width) {
            guard width.isFinite, width >= 0 else { return false }
            lineWidth = Double(width)
        } else if CGPDFDictionaryGetObject(dictionary,"LW",&widthObject) { return false }
        guard PDFPaintColors.hasNormalBlendMode(dictionary) else { return false }
        for key in ["ca", "CA"] {
            var value: CGPDFReal = 0, object: CGPDFObjectRef?
            if CGPDFDictionaryGetNumber(dictionary,key,&value) {
                guard value.isFinite, value == 1 else { return false }
            } else if CGPDFDictionaryGetObject(dictionary,key,&object) { return false }
        }
        return true
    }
    func read(_ page: CGPDFPage) throws -> [PDFRule] {
        guard let table = CGPDFOperatorTableCreate() else { throw PDFParseError(code: .unreadable, branch:.b134) }
        defer { CGPDFOperatorTableRelease(table) }
        CGPDFOperatorTableSetCallback(table, "q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit, branch:.b135) } else {
                s.stack.append(s.ctm); s.widthStack.append(s.lineWidth); s.colorStack.append(s.colors)
                s.overprintStack.append(s.uncertifiedOverprint)
                s.textModeStack.append(s.textMode); s.dashStack.append(s.solidDash)
            }
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            if let value = s.stack.popLast(), let width = s.widthStack.popLast(), let colors = s.colorStack.popLast(),
               let mode = s.textModeStack.popLast(), let dash = s.dashStack.popLast(),
               let overprint = s.overprintStack.popLast() {
                s.ctm = value; s.lineWidth = width; s.colors = colors
                s.uncertifiedOverprint = overprint
                s.textMode = mode; s.solidDash = dash
            } else { s.failure = PDFParseError(code: .unreadable, branch:.b136) }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 6) else { return }
            s.ctm = CGAffineTransform(a: n[0], b: n[1], c: n[2], d: n[3], tx: n[4], ty: n[5]).concatenating(s.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "m") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 2) else { return }
            s.paths.append([s.position(n[0], n[1])])
            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b137) }
        }
        CGPDFOperatorTableSetCallback(table, "l") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 2), !s.paths.isEmpty else { return }
            s.paths[s.paths.count - 1].append(s.position(n[0], n[1]))
            if s.paths[s.paths.count - 1].count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b138) }
        }
        CGPDFOperatorTableSetCallback(table, "re") { scanner, p in
            guard let s = PDFPathReader.state(p), let n = s.numbers(scanner, 4) else { return }
            let x = n[0], y = n[1], w = n[2], h = n[3]
            s.paths.append([s.position(x, y), s.position(x + w, y), s.position(x + w, y + h), s.position(x, y + h), s.position(x, y)])
            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b139) }
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
        CGPDFOperatorTableSetCallback(table, "n") { _, p in
            guard let s = PDFPathReader.state(p) else { return }
            s.paths.removeAll(keepingCapacity:true); s.curvedPath = false
        }
        // Curves cannot form supported table rules. Drop that subpath instead of joining across a curve.
        for op in ["c", "v", "y"] {
            CGPDFOperatorTableSetCallback(table, op) { _, p in
                guard let s = PDFPathReader.state(p) else { return }
                if s.verifyVisibility { s.curvedPath = true }
                if !s.paths.isEmpty { s.paths[s.paths.count - 1].removeAll() }
            }
        }
        // Form XObjects may contain an otherwise unseen part of the table. Fail closed.
        CGPDFOperatorTableSetCallback(table, "Do") { _, p in
            PDFPathReader.state(p)?.failure = PDFParseError(code: .unsupported, stage: .vectorObjects, branch:.b140)
        }
        if verifyVisibility {
            CGPDFOperatorTableSetCallback(table,"d") { scanner, p in
                guard let s = PDFPathReader.state(p), let phase = s.numbers(scanner,1)?.first else { return }
                var pattern: CGPDFArrayRef?
                guard CGPDFScannerPopArray(scanner,&pattern), let pattern else {
                    s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b141); return
                }
                do { s.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase)) }
                catch { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b142) }
            }
            CGPDFOperatorTableSetCallback(table, "w") { scanner, p in
                guard let s = PDFPathReader.state(p), let width = s.numbers(scanner,1)?.first else { return }
                guard width >= 0 else { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b143); return }
                s.lineWidth = Double(width)
            }
            CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in
                guard let s = PDFPathReader.state(p) else { return }
                if !s.graphicsStateIsVisible(scanner) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b144) }
            }
            CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
                guard let s = PDFPathReader.state(p), let mode = s.numbers(scanner,1)?.first else { return }
                guard [0.0,1,2].contains(Double(mode)) else {
                    s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b145); return
                }
                s.textMode = Double(mode)
            }
            for op in ["Tj", "TJ", "'", "\""] {
                CGPDFOperatorTableSetCallback(table, op) { _, p in
                    guard let s = PDFPathReader.state(p) else { return }
                    s.textSeen = true
                    if !s.colors.canPaintText(mode:s.textMode) {
                        s.failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b146)
                    }
                    if s.failure == nil && !s.textContrastsWithBackground() {
                        s.failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b267)
                    }
                    if s.textMode != 0 {
                        s.hasOutlinedText = true
                        if !s.solidDash || PDFTextVisibility.strokePad(s.lineWidth,a:Double(s.ctm.a),b:Double(s.ctm.b),c:Double(s.ctm.c),d:Double(s.ctm.d)) == nil {
                            s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b147)
                        }
                    }
                }
            }
            CGPDFOperatorTableSetCallback(table,"g") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:1) }
            CGPDFOperatorTableSetCallback(table,"ri") { scanner,p in
                guard let s = PDFPathReader.state(p) else { return }
                do { try s.colors.intent(scanner) } catch { s.failure = error }
            }
            CGPDFOperatorTableSetCallback(table,"G") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:1) }
            CGPDFOperatorTableSetCallback(table,"rg") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:3) }
            CGPDFOperatorTableSetCallback(table,"RG") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:3) }
            CGPDFOperatorTableSetCallback(table,"k") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:4) }
            CGPDFOperatorTableSetCallback(table,"K") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:4) }
            CGPDFOperatorTableSetCallback(table,"cs") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,space:true) }
            CGPDFOperatorTableSetCallback(table,"CS") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,space:true) }
            for op in ["sc", "scn"] {
                CGPDFOperatorTableSetCallback(table,op) { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false) }
            }
            for op in ["SC", "SCN"] {
                CGPDFOperatorTableSetCallback(table,op) { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true) }
            }
            for op in ["W", "W*"] {
                CGPDFOperatorTableSetCallback(table,op) { _,p in PDFPathReader.state(p)?.recordClip() }
            }
            CGPDFOperatorTableSetCallback(table,"BMC") { scanner,p in
                guard let s = PDFPathReader.state(p) else { return }
                do { try s.markedContent.begin(scanner,properties:false) } catch { s.failure = error }
            }
            CGPDFOperatorTableSetCallback(table,"BDC") { scanner,p in
                guard let s = PDFPathReader.state(p) else { return }
                do { try s.markedContent.begin(scanner,properties:true) } catch { s.failure = error }
            }
            CGPDFOperatorTableSetCallback(table,"EMC") { _,p in
                guard let s = PDFPathReader.state(p) else { return }
                do { try s.markedContent.end() } catch { s.failure = error }
            }
            // Unsupported painted objects still require separate verification.
            for op in ["BI", "ID", "EI", "sh"] {
                CGPDFOperatorTableSetCallback(table, op) { _, p in
                    PDFPathReader.state(p)?.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b148)
                }
            }
        }
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        if verifyVisibility {
            try colors.fill.applyDefault(scanner,resolver:paintResolver)
            try colors.stroke.applyDefault(scanner,resolver:paintResolver)
        }
        let succeeded = CGPDFScannerScan(scanner)
        if let failure = failure { throw failure }
        try check()
        guard succeeded else { throw PDFParseError(code: .unreadable, branch:.b149) }
        if verifyVisibility {
            guard stack.isEmpty else { throw PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b150) }
            do {
                try markedContent.finish()
                try PDFClipValidation.requireContains(textBoxes+paintedBoxes,clips:clips,work:{
                    guard self.consumePaintWork() else { throw self.failure ?? PDFParseError(code:.limit, branch:.b151) }
                },check:check)
            } catch var error as PDFParseError {
                if error.stage == .characterMapping { error.stage = .vectorObjects }
                throw error
            }
        }
        return lines
    }

    func validateTextPaintBounds(_ boxes: [PDFBox]) throws {
        let work = { [self] in
            guard consumePaintWork() else { throw failure ?? PDFParseError(code:.limit, branch:.b152) }
        }
        let page = PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height))
        try PDFClipValidation.requireContains(boxes,clips:[page]+clips,work:work,check:check)
        let index = try PDFTextCollisionIndex(boxes,work:work)
        for box in collisionBoxes {
            if try index.overlaps(box,pad:0,work:work) {
                throw PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b153)
            }
        }
    }
}
#endif
