import Foundation

/// Geometry is in displayed page coordinates: top-left origin, after page rotation.
/// This core has no network access and never opens another document.

struct PDFGrid {
    let page: PDFPageLayout
    private final class Calibration {
        var visits = 0
        var orderedGlyphIndices: [Int]?
        var valid: [PDFBox:[Double]] = [:]
        var invalid = Set<PDFBox>()
        func consume(_ check: () throws -> Void) throws {
            visits += 1
            guard visits <= 64_000_000 else { throw PDFParseError(code:.limit,stage:.gridCell) }
            if visits % 128 == 0 { try check() }
        }
    }
    private let calibration = Calibration()
    init(page: PDFPageLayout) { self.page = page }
    private func checkedRules(_ predicate: (PDFRule) -> Bool, check: () throws -> Void) throws -> [PDFRule] {
        var result = [PDFRule]()
        for rule in page.lines { try calibration.consume(check); if predicate(rule) { result.append(rule) } }
        return result
    }
    func box(_ x: Double, _ y: Double, check: () throws -> Void) throws -> PDFBox {
        try check()
        let vs = try checkedRules({ $0.vertical && $0.y1-0.8 <= y && y <= $0.y2+0.8 },check:check)
        let hs = try checkedRules({ $0.horizontal && $0.x1-0.8 <= x && x <= $0.x2+0.8 },check:check)
        guard let l = vs.filter({ $0.x1 < x-0.5 }).map(\.x1).max(),
              let r = vs.filter({ $0.x1 > x+0.5 }).map(\.x1).min(),
              let t = hs.filter({ $0.y1 < y-0.5 }).map(\.y1).max(),
              let b = hs.filter({ $0.y1 > y+0.5 }).map(\.y1).min() else {
            throw PDFParseError(code:.unsupported,stage:.gridCell)
        }
        return PDFBox(left:l,top:t,right:r,bottom:b)
    }
    func glyphs(in box: PDFBox, check: () throws -> Void) throws -> [PDFGlyph] {
        try check()
        if calibration.orderedGlyphIndices == nil {
            var indices = [Int](); indices.reserveCapacity(page.glyphs.count)
            for index in page.glyphs.indices { try calibration.consume(check); indices.append(index) }
            try indices.sort { a,b in
                try calibration.consume(check)
                let ay = page.glyphs[a].cy, by = page.glyphs[b].cy
                return ay == by ? a < b : ay < by
            }
            calibration.orderedGlyphIndices = indices
        }
        let indices = calibration.orderedGlyphIndices!
        func boundary(_ y: Double, inclusive: Bool) throws -> Int {
            var left = 0, right = indices.count
            while left < right {
                try calibration.consume(check)
                let middle = left+(right-left)/2, value = page.glyphs[indices[middle]].cy
                if value < y || (inclusive && value == y) { left = middle+1 } else { right = middle }
            }
            return left
        }
        let first = try boundary(box.top+0.3,inclusive:true)
        let end = try boundary(box.bottom-0.3,inclusive:false)
        var selected = [Int]()
        if first < end {
            for offset in first..<end {
                try calibration.consume(check)
                let index = indices[offset], glyph = page.glyphs[index]
                if box.left+0.3 < glyph.cx && glyph.cx < box.right-0.3 {
                    if glyph.ocrLineAtom == true {
                        guard glyph.x >= box.left, glyph.y >= box.top, glyph.x + glyph.width <= box.right,
                              glyph.y + glyph.height <= box.bottom else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                    }
                    selected.append(index)
                }
            }
        }
        // Spatial lookup cannot change the original PDF reading/drawing order.
        try selected.sort { a,b in try calibration.consume(check); return a < b }
        return selected.map { page.glyphs[$0] }
    }
    func column(_ x: Double, _ y: Double) throws -> PDFBox {
        let vs = page.lines.filter { $0.vertical && $0.y1 - 0.8 <= y && y <= $0.y2 + 0.8 }
        guard let l = vs.filter({ $0.x1 < x - 0.5 }).map(\.x1).max(),
              let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min() else { throw PDFParseError(code: .unsupported, stage: .gridColumn) }
        return PDFBox(left: l, top: 0, right: r, bottom: page.height)
    }
    func dateRow(_ x: Double, _ y: Double, headerBottom: Double) throws -> PDFBox {
        let hs = page.lines.filter { $0.horizontal && $0.x1 - 0.8 <= x && x <= $0.x2 + 0.8 }
        guard let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else { throw PDFParseError(code: .unsupported, stage: .gridRow) }
        let t = max(headerBottom + 1, hs.filter({ $0.y1 < y - 0.5 }).map(\.y1).max() ?? headerBottom + 1)
        return PDFBox(left: 0, top: t, right: page.width, bottom: b)
    }
    func box(_ x: Double, _ y: Double) throws -> PDFBox {
        let vs = page.lines.filter { $0.vertical && $0.y1 - 0.8 <= y && y <= $0.y2 + 0.8 }
        let hs = page.lines.filter { $0.horizontal && $0.x1 - 0.8 <= x && x <= $0.x2 + 0.8 }
        guard let l = vs.filter({ $0.x1 < x - 0.5 }).map(\.x1).max(),
              let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min(),
              let t = hs.filter({ $0.y1 < y - 0.5 }).map(\.y1).max(),
              let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else {
            throw PDFParseError(code: .unsupported, stage: .gridCell)
        }
        return PDFBox(left: l, top: t, right: r, bottom: b)
    }
    func glyphs(in box: PDFBox) -> [PDFGlyph] {
        page.glyphs.filter { box.left + 0.3 < $0.cx && $0.cx < box.right - 0.3 &&
            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 &&
            ($0.ocrLineAtom != true || $0.x >= box.left && $0.y >= box.top &&
                $0.x + $0.width <= box.right && $0.y + $0.height <= box.bottom) }
    }
    static func rows(_ glyphs: [PDFGlyph]) -> [[PDFGlyph]] {
        var rows: [[PDFGlyph]] = []
        for g in glyphs.sorted(by: { $0.cy < $1.cy }) {
            if let last = rows.last?.first, abs(last.cy - g.cy) <= 2 {
                rows[rows.count - 1].append(g)
            } else { rows.append([g]) }
        }
        return rows.map { $0.sorted { $0.cx < $1.cx } }
    }
    /// Cell content follows the PDF text ranges, not glyph centres. Small type,
    /// punctuation and overlapping selection boxes must not shuffle the text.
    static func contentRows(_ glyphs: [PDFGlyph]) throws -> [[PDFGlyph]] {
        guard glyphs.contains(where: { $0.sourceLine != nil || $0.sourceOrder != nil }) else { return rows(glyphs) }
        guard glyphs.allSatisfy({ ($0.sourceLine ?? -1) >= 0 && ($0.sourceOrder ?? -1) >= 0 }),
              Set(glyphs.compactMap(\.sourceOrder)).count == glyphs.count else {
            throw PDFParseError(code: .ambiguous, stage: .textOrder)
        }
        let groups = Dictionary(grouping: glyphs, by: { $0.sourceLine! })
            .values.map { $0.sorted { $0.sourceOrder! < $1.sourceOrder! } }
        // PDF drawing/selection order can place the room before the subject.
        // Place whole lines vertically, but never merge them or sort characters
        // within a line by their variable-sized selection rectangles.
        func center(_ row: [PDFGlyph]) -> Double {
            let values = row.map(\.cy).sorted()
            return values[values.count / 2]
        }
        return groups.sorted {
            let a = center($0), b = center($1)
            return a == b ? $0[0].sourceOrder! < $1[0].sourceOrder! : a < b
        }
    }
    func text(_ box: PDFBox, check: () throws -> Void) throws -> [String] {
        try Self.contentRows(try glyphs(in:box,check:check)).map { $0.map(\.text).joined() }
    }
    func text(_ box: PDFBox) throws -> [String] {
        try Self.contentRows(glyphs(in: box)).map { $0.map(\.text).joined() }
    }
    /// Timetable-only: one visual line may arrive as several disjoint PDF text
    /// selections. Selection rectangles can overlap at a character boundary;
    /// that alone does not imply two conflicting lines of text.
    func timetableText(_ box: PDFBox, check: () throws -> Void = {}) throws -> [String] {
        try timetableText(try glyphs(in:box,check:check),check:check)
    }
    private func timetableText(_ input: [PDFGlyph], check: () throws -> Void) throws -> [String] {
        guard input.reduce(0, { $0 + $1.text.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit) }
        let rows = try Self.contentRows(input)
        guard input.contains(where: { $0.sourceLine != nil }) else { return rows.map { $0.map(\.text).joined() } }
        struct Fragment {
            let glyphs: [PDFGlyph]
            var left: Double { glyphs.map(\.x).min()! }
            var right: Double { glyphs.map { $0.x + $0.width }.max()! }
            var top: Double { glyphs.map(\.y).min()! }
            var bottom: Double { glyphs.map { $0.y + $0.height }.max()! }

            func precedes(_ next: Fragment) -> Bool {
                if right <= next.left + 0.1 { return true }
                // Allow a boundary overhang only when BOTH the text ranges and
                // boundary glyph edges advance left to right. Do not guess an
                // order for contained, overprinted or backwards fragments.
                let end = glyphs.last!, start = next.glyphs.first!
                return left < next.left && right < next.right &&
                    end.sourceOrder! < start.sourceOrder! &&
                    end.x < start.x && end.x + end.width < start.x + start.width
            }
        }
        let fragments = rows.map { Fragment(glyphs: $0) }.sorted { ($0.top, $0.left) < ($1.top, $1.left) }
        var bands: [[Fragment]] = []
        for fragment in fragments {
            try check()
            let aligned = bands.indices.filter { index in
                bands[index].allSatisfy { abs($0.top - fragment.top) <= 0.35 && abs($0.bottom - fragment.bottom) <= 0.35 }
            }
            guard aligned.count <= 1 else { throw PDFParseError(code: .ambiguous, stage: .fragmentAlignment) }
            if let index = aligned.first {
                guard bands[index].allSatisfy({ existing in
                    existing.left < fragment.left ? existing.precedes(fragment) : fragment.precedes(existing)
                }) else {
                    throw PDFParseError(code: .ambiguous, stage: .fragmentOverlap)
                }
                bands[index].append(fragment)
            } else { bands.append([fragment]) }
        }
        return bands.map { band in
            band.sorted { $0.left < $1.left }.flatMap(\.glyphs).map(\.text).joined()
        }
    }
    /// Build calibration cells only inside the independently identified lesson
    /// rows and period columns. Page annotations cannot establish field roles.
    func lessonBoxes(rows: [PDFBox], columns: [Double], check: () throws -> Void = {}) throws -> [PDFBox] {
        var boxes = Set<PDFBox>()
        for row in rows {
            for x in columns {
                try calibration.consume(check)
                let rules = try checkedRules({ $0.horizontal && $0.x1-0.5 <= x && x <= $0.x2+0.5 && row.top+1 < $0.y1 && $0.y1 < row.bottom-1 },check:check)
                let cuts = Set(rules.map(\.y1)).sorted()
                let edges = [row.top]+cuts+[row.bottom]
                for index in 0..<(edges.count-1) where edges[index+1]-edges[index] >= 2 {
                    let cell = try box(x,(edges[index]+edges[index+1])/2,check:check)
                    guard cell.top >= row.top-0.8, cell.bottom <= row.bottom+0.8 else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
                    boxes.insert(cell)
                    guard boxes.count <= 10_000 else { throw PDFParseError(code:.limit) }
                }
            }
        }
        return Array(boxes)
    }
    /// A missing line cannot shift the following field into its place. Only
    /// complete lesson cells of the same height establish the role baselines.
    func lessonFields(_ box: PDFBox, lines: [String], referenceBoxes: [PDFBox], check: () throws -> Void = {}) throws -> [String] {
        try check()
        if lines.count == 3 { return lines }
        guard !lines.isEmpty, lines.count < 3 else { throw PDFParseError(code: .ambiguous, stage: .lessonLines) }
        let height = box.bottom - box.top
        var references: [[Double]] = []
        var seen = Set<PDFBox>()
        for other in referenceBoxes {
            try calibration.consume(check)
            guard seen.insert(other).inserted else { continue }
            guard seen.count <= 10000 else { throw PDFParseError(code:.limit,stage:.gridCell) }
            guard abs(other.bottom-other.top-height) < 0.5, !calibration.invalid.contains(other) else { continue }
            if let cached = calibration.valid[other] { references.append(cached); continue }
            let input = try glyphs(in:other,check:check)
            let text: [String]
            do { text = try timetableText(input,check:check) }
            catch let error as PDFParseError where error.code == .ambiguous || error.code == .unsupported {
                calibration.invalid.insert(other); continue
            }
            let rows = Self.rows(input)
            guard text.count == 3, !text.contains(where:RecoveryRole.hasLabelPrefix), rows.count == 3 else {
                calibration.invalid.insert(other); continue
            }
            let centers = rows.map { row in row.map(\.cy).reduce(0,+)/Double(row.count)-other.top }
            calibration.valid[other] = centers; references.append(centers)
        }
        let rows = Self.rows(try glyphs(in:box,check:check))
        guard rows.count == lines.count else { throw PDFParseError(code:.ambiguous,stage:.lessonLines) }
        var candidates = [[String]]()
        for reference in references {
            try calibration.consume(check)
            guard zip(reference,reference.dropFirst()).allSatisfy({ $0.1-$0.0 > 2 }) else { continue }
            let tolerance = min(0.75, zip(reference, reference.dropFirst()).map { ($0.1 - $0.0) / 3 }.min()!)
            var fields = ["", "", ""], assigned: Set<Int> = [], valid = true
            for (row, text) in zip(rows, lines) {
                let center = row.map(\.cy).reduce(0,+) / Double(row.count) - box.top
                let matches = reference.indices.filter { abs(reference[$0] - center) <= tolerance }
                guard matches.count == 1, assigned.insert(matches[0]).inserted else { valid = false; break }
                fields[matches[0]] = text
            }
            // A matching reference that places this line in teacher/room is
            // conflicting evidence, even when it would leave subject absent.
            if valid { candidates.append(fields) }
        }
        guard let fields = candidates.first, !fields[0].isEmpty, candidates.allSatisfy({ $0 == fields }) else {
            throw PDFParseError(code: .ambiguous, stage: .lessonLines)
        }
        return fields
    }

    func anchors(_ word: String, above: Double) -> [PDFBox] {
        let target = Array(word)
        return Self.rows(page.glyphs.filter { $0.cy < above }).flatMap { row -> [PDFBox] in
            guard row.count >= target.count else { return [] }
            var hits: [PDFBox] = []
            for i in 0...(row.count - target.count) {
                let part = Array(row[i..<(i + target.count)])
                if part.map(\.text).joined() == word {
                    hits.append(PDFBox(left: part.map(\.x).min()!, top: part.map(\.y).min()!,
                                       right: part.map { $0.x + $0.width }.max()!, bottom: part.map { $0.y + $0.height }.max()!))
                }
            }
            return hits
        }
    }
}
