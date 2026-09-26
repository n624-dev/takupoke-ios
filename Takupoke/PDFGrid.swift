import Foundation

/// Geometry is in displayed page coordinates: top-left origin, after page rotation.
/// This core has no network access and never opens another document.

struct PDFGrid {
    let page: PDFPageLayout
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
            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 }
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
    func text(_ box: PDFBox) throws -> [String] {
        try Self.contentRows(glyphs(in: box)).map { $0.map(\.text).joined() }
    }
    /// Timetable-only: one visual line may arrive as several disjoint PDF text
    /// selections. Selection rectangles can overlap at a character boundary;
    /// that alone does not imply two conflicting lines of text.
    func timetableText(_ box: PDFBox) throws -> [String] {
        let input = glyphs(in: box)
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
