import Foundation

/// Bounds for a composed character are built only from its own UTF-16 indices.
/// A selection's highlight rectangle is not a per-character bounding box.
enum PDFCharacterGeometry {
    static func bounds(for range: NSRange, count: Int, characterBounds: (Int) -> CGRect) throws -> CGRect {
        guard range.location >= 0, range.location < count, range.length > 0,
              range.length <= count - range.location else {
            throw PDFParseError(code: .unsupported, stage: .characterMapping)
        }
        var result = CGRect.null
        for index in range.location..<(range.location + range.length) {
            let rect = characterBounds(index)
            guard !rect.isNull, !rect.isEmpty, !rect.isInfinite,
                  [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) else {
                throw PDFParseError(code: .unsupported, stage: .characterMapping)
            }
            result = result.union(rect)
        }
        return result
    }
}

#if canImport(PDFKit)
import PDFKit
import CoreGraphics

/// PDFKit opens documents and validates text; Core Graphics reads timetable
/// text placement and painted rules. Calendar selection handling stays unchanged.
/// No JavaScript, links, embedded files, or actions in a PDF are executed.
enum PDFKitReader {
    static func read(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder? = nil,
                     check: @escaping () throws -> Void = {}) throws -> [PDFPageLayout] {
        let recorder = kind == .timetable ? (diagnostics ?? PDFDiagnosticRecorder()) : nil
        do { return try readPages(url, kind: kind, diagnostics: recorder, check: check) }
        catch {
            if let recorder = recorder { throw recorder.attaching(to: error) }
            throw error
        }
    }

    private static func readPages(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder?,
                                  check: @escaping () throws -> Void) throws -> [PDFPageLayout] {
        diagnostics?.record(.file)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        diagnostics?.record(.file, values: [Double(size ?? -1)])
        guard let size = size, size > 0, size <= MaterialLibrary.maximumBytes else { throw PDFParseError(code: .unreadable) }
        let opened = PDFDocument(url: url)
        diagnostics?.record(.document, values: [Double(opened?.pageCount ?? -1), opened?.isLocked == true ? 1 : 0])
        guard let document = opened, !document.isLocked,
              document.pageCount > 0, document.pageCount <= 12 else { throw PDFParseError(code: .unreadable) }
        var output: [PDFPageLayout] = []
        for index in 0..<document.pageCount {
            try check()
            diagnostics?.record(.page, page: index + 1)
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
            diagnostics?.record(.pageText, page: index + 1,
                values: [Double(string.utf16.count), Double(page.numberOfCharacters), Double(rotation)], bounds: media)
            var glyphs: [PDFGlyph]
            if kind == .timetable {
                do {
                    glyphs = try PDFDrawnTextReader(check: check).read(ref, expectedText: string).map { glyph in
                        let b = transform.rect(CGRect(x: glyph.x, y: glyph.y, width: glyph.width, height: glyph.height))
                        return PDFGlyph(text: glyph.text, x: Double(b.minX), y: Double(b.minY),
                                        width: Double(b.width), height: Double(b.height),
                                        sourceLine: glyph.sourceLine, sourceOrder: glyph.sourceOrder)
                    }
                } catch var error as PDFParseError { error.page = index + 1; throw error }
            } else {
                let ns = string as NSString
                guard ns.length == page.numberOfCharacters else {
                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                }
                diagnostics?.record(.pageSelection, page: index + 1)
                guard ns.length > 0, let pageSelection = page.selection(for: NSRange(location: 0, length: ns.length)) else {
                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                }
                var sourceLines = [Int?](repeating: nil, count: ns.length)
                let textLines = pageSelection.selectionsByLine()
                diagnostics?.record(.lines, page: index + 1, values: [Double(textLines.count)])
                guard textLines.count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
                var coveredUnits = 0
                for (lineID, line) in textLines.enumerated() {
                    try check()
                    let count = line.numberOfTextRanges(on: page)
                    diagnostics?.record(.lineRanges, page: index + 1, line: lineID, values: [Double(count)])
                    guard count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
                    for rangeIndex in 0..<count {
                        let range = line.range(at: rangeIndex, on: page)
                        diagnostics?.record(.lineRange, page: index + 1, index: range.location, length: range.length, line: lineID)
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
                                diagnostics?.record(.lineOffset, page: index + 1, index: offset, line: lineID,
                                                    values: [Double(sourceLines[offset] ?? -1)])
                                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .textOrder)
                            }
                            sourceLines[offset] = lineID
                        }
                    }
                }
                glyphs = []
                var cursor = 0
                while cursor < ns.length {
                    if cursor % 128 == 0 { try check() }
                    let range = ns.rangeOfComposedCharacterSequence(at: cursor)
                    let text = ns.substring(with: range)
                    diagnostics?.record(.characterRange, page: index + 1, index: range.location, length: range.length,
                        line: sourceLines[cursor], values: [text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0,
                        text.unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) } ? 1 : 0])
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        guard let sourceLine = sourceLines[cursor],
                              (range.location..<NSMaxRange(range)).allSatisfy({ sourceLines[$0] == sourceLine }) else {
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                        }
                        // Keep the calendar's UTF-16 selection verification.
                        let selected = page.selection(for: range)
                        diagnostics?.record(.selection, page: index + 1, index: range.location, length: range.length,
                            line: sourceLine, values: [selected == nil ? 0 : 1, selected?.string == text ? 1 : 0],
                            bounds: selected?.bounds(for: page))
                        guard let selection = selected, selection.string == text else {
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                        }
                        // The calendar path is intentionally kept unchanged.
                        let box = selection.bounds(for: page)
                        guard !box.isNull, !box.isEmpty,
                              [box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite) else {
                            // Dropping a visible character could silently change a subject or date.
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                        }
                        let b = transform.rect(box)
                        diagnostics?.record(.displayBounds, page: index + 1, index: range.location, length: range.length,
                                            line: sourceLine, bounds: b)
                        glyphs.append(PDFGlyph(text: text, x: Double(b.minX), y: Double(b.minY),
                                               width: Double(b.width), height: Double(b.height),
                                               sourceLine: sourceLine, sourceOrder: cursor))
                    }
                    cursor = NSMaxRange(range)
                }
            }
            let reader = PDFPathReader(transform: transform, check: check)
            diagnostics?.record(.paths, page: index + 1)
            let lines: [PDFRule]
            do { lines = try reader.read(ref) }
            catch var error as PDFParseError { error.page = index + 1; throw error }
            guard !glyphs.isEmpty, !lines.isEmpty else { throw PDFParseError(code: .unreadable, page: index + 1) }
            diagnostics?.record(.pageComplete, page: index + 1,
                values: [Double(glyphs.count), Double(lines.count), Double(reader.arrows.count), Double(reader.operations)])
            output.append(PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows))
        }
        diagnostics?.record(.readComplete, values: [Double(output.count)])
        return output
    }

    /// Independent inspection continues past invalid character bounds. It never
    /// creates lessons, saves an analysis, or substitutes data into the parser.
    static func diagnose(_ url: URL, check: @escaping () throws -> Void = {}) -> PDFFullReadDiagnostic {
        var report = PDFFullReadDiagnostic()
        report.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        report.appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        report.commit = Bundle.main.object(forInfoDictionaryKey: "TakupokeCommit") as? String
        let os = ProcessInfo.processInfo.operatingSystemVersion
        report.osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        do {
            try check()
            report.fileBytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard let size = report.fileBytes, size > 0, size <= MaterialLibrary.maximumBytes,
                  let document = PDFDocument(url: url) else {
                report.incomplete.append(.unavailable); return report
            }
            report.pageCount = document.pageCount
            report.locked = document.isLocked
            guard !document.isLocked else { report.incomplete.append(.locked); return report }
            if document.pageCount > 12 { report.incomplete.append(.pageLimit) }
            var characterBudget = 100_000
            var rangeBudget = 100_000
            for index in 0..<min(document.pageCount, 12) {
                try check()
                var output = PDFFullReadDiagnostic.Page(number: index + 1)
                // Preserve a partially inspected page if cancellation/error occurs.
                defer { report.pages.append(output) }
                guard let page = document.page(at: index), let ref = page.pageRef else {
                    output.issues.append(PDFParseError(code: .unreadable, page: index + 1))
                    report.incomplete.append(.unavailable); continue
                }
                let rotation = ((page.rotation % 360) + 360) % 360
                let media = ref.getBoxRect(.mediaBox)
                output.rotation = rotation
                output.mediaBox = .init(media)
                output.nativeCharacterCount = page.numberOfCharacters
                let ns = (page.string ?? "") as NSString
                output.utf16Count = ns.length
                guard ns.length <= 100_000 else { report.incomplete.append(.characterLimit); continue }
                output.text = page.string
                if let selection = page.selection(for: NSRange(location: 0, length: ns.length)) {
                    for line in selection.selectionsByLine() {
                        try check()
                        guard rangeBudget > 0 else { report.incomplete.append(.rangeLimit); break }
                        let count = min(line.numberOfTextRanges(on: page), rangeBudget)
                        if count < line.numberOfTextRanges(on: page) { report.incomplete.append(.rangeLimit) }
                        let ranges = (0..<count).map { PDFFullReadDiagnostic.Range(line.range(at: $0, on: page)) }
                        rangeBudget -= max(1, count)
                        output.lines.append(.init(text: line.string, ranges: ranges, bounds: .init(line.bounds(for: page))))
                    }
                }
                var cursor = 0
                while cursor < ns.length {
                    try check()
                    let range = ns.rangeOfComposedCharacterSequence(at: cursor)
                    guard range.length <= characterBudget else { report.incomplete.append(.characterLimit); break }
                    let text = ns.substring(with: range)
                    let selection = NSMaxRange(range) <= page.numberOfCharacters ? page.selection(for: range) : nil
                    let bounds: [PDFDiagnosticSnapshot.Rect?] = (range.location..<NSMaxRange(range)).map { offset in
                        offset < page.numberOfCharacters ? .init(page.characterBounds(at: offset)) : nil
                    }
                    output.characters.append(.init(range: .init(range), text: text,
                        whitespace: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        selectionText: selection?.string, selectionBounds: selection.map { .init($0.bounds(for: page)) },
                        characterBounds: bounds))
                    characterBudget -= range.length
                    cursor = NSMaxRange(range)
                }
                if [0, 90, 180, 270].contains(rotation) {
                    let reader = PDFPathReader(transform: PDFDisplayTransform(media: media, rotation: rotation), check: check)
                    do { _ = try reader.read(ref) }
                    catch {
                        var failure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
                        failure.page = index + 1
                        output.issues.append(failure)
                        report.incomplete.append(.drawingFailure)
                        if failure.code == .cancelled { throw failure }
                    }
                    output.rules = reader.lines
                    output.arrows = reader.arrows
                    output.drawingOperations = reader.operations
                } else {
                    output.issues.append(PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation))
                    report.incomplete.append(.drawingFailure)
                }
            }
        } catch {
            let failure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
            report.issues.append(failure)
            report.incomplete.append(failure.code == .cancelled ? .cancelled : .unavailable)
        }
        return report
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
