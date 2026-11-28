// Strict parsing contract from 239.1 (bfc599fd5a552ced0c140497c703199547c30fd4).
// The acceptance conditions are unchanged. Record the physical slots already read.
import Foundation

extension PDF239SchoolParser {
    static func timetable(_ page: PDFPageLayout, check: () throws -> Void)
        throws -> (lessons: [PDFLesson], provenSlots: [PDFTimetableSlot]?) {
        let grid = PDF239Grid(page: page)
        let headers = PDF239Grid.rows(page.glyphs.filter { $0.cy < page.height / 5 }).filter {
            key($0.map(\.text).joined()) == String(repeating: "12345678", count: 5)
        }
        guard headers.count == 1, headers[0].count == 40 else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b380)
        }
        let header = headers[0]
        let first = try grid.box(header[0].cx, header[0].cy)
        let rightEdge = header.last.flatMap { entry in try? grid.box(entry.cx, entry.cy).right }
        let classBox = try grid.box(first.left - 2, first.bottom + 20)
        guard let bodyBottom = page.lines.filter({ $0.vertical && abs($0.x1 - classBox.right) < 0.3 }).map(\.y2).max() else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .gridColumn, branch:.b379)
        }
        let classRows = PDF239Grid.rows(page.glyphs.filter { classBox.left < $0.cx && $0.cx < classBox.right &&
            $0.cy > first.bottom && $0.cy < bodyBottom })
        var output: [PDFLesson] = []
        var provenSlots = [PDFTimetableSlot]()
        var fullScopeProven = true
        var classes: Set<String> = []
        for (classIndex, glyphs) in classRows.enumerated() {
            try check()
            let label = key(glyphs.map(\.text).joined())
            guard label.range(of: "^(?:[1-9]|[A-Z]{2,8})$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .classLabel, branch:.b378)
            }
            let y = glyphs.map(\.cy).reduce(0, +) / Double(glyphs.count)
            var row = try grid.box((classBox.left + classBox.right) / 2, y)
            let grade = try key(grid.text(grid.box(classBox.left - 2, y)).joined())
            guard grade == "AI" || grade.range(of: "^[1-9]$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel, branch:.b377)
            }
            let name = ChangeNormalizer.canonicalClassName(grade + "_" + label)
            guard classes.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass, branch:.b376) }
            // The first class spans the supplementary period header as well.
            // Use the top of its first actual subject cell to exclude that header.
            row.top = max(row.top, try grid.box(header[0].cx, y).top)
            var rowRegions = Set<PDFBox>()
            for (column, h) in header.enumerated() {
                try check()
                let cuts = Set(page.lines.filter { $0.horizontal && $0.x1 - 0.5 <= h.cx && h.cx <= $0.x2 + 0.5 &&
                    row.top + 1 < $0.y1 && $0.y1 < row.bottom - 1 }.map { ($0.y1 * 100).rounded() / 100 }).sorted()
                let edges = [row.top] + cuts + [row.bottom]
                var seen: Set<PDFBox> = []
                for i in 0..<(edges.count - 1) where edges[i + 1] - edges[i] >= 2 {
                    let box = try grid.box(h.cx, (edges[i] + edges[i + 1]) / 2)
                    guard seen.insert(box).inserted else { continue }
                    var cell = PDFParseError.Cell(classRow: classIndex + 1, weekday: column / 8 + 1, period: column % 8 + 1)
                    let lines: [String]
                    do { lines = try grid.timetableText(box) }
                    catch var error as PDFParseError {
                        error.cell = cell
                        if error.stage == .fragmentOverlap || error.stage == .fragmentAlignment {
                            error.geometry = PDFCellGeometryDiagnostic(grid.glyphs(in: box), box: box)
                        }
                        throw error
                    }
                    if lines.isEmpty { continue }
                    cell.detectedLines = lines.count
                    guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, page: 1, branch:.b375) }
                    guard lines.count <= 3, !lines[0].isEmpty else { throw PDFParseError(code: .ambiguous, page: 1, stage: .lessonLines, cell: cell, branch:.b374) }
                    let fields = lines + Array(repeating: "", count: 3 - lines.count)
                    let parts = fields.map { $0.replacingOccurrences(of: "･", with: "・").components(separatedBy: "・") }
                    let parallel = lines.count == 3 && parts.allSatisfy { $0.count == 2 }
                    if parts[0].count > 1 && parts[1].count > 1 && !parallel {
                        throw PDFParseError(code: .ambiguous, page: 1, stage: .parallelLessons, cell: cell, branch:.b373)
                    }
                    if parallel && parts[0].contains(where: { $0.isEmpty }) { throw PDFParseError(code: .ambiguous, page: 1, stage: .emptySubject, cell: cell, branch:.b372) }
                    for variant in 0..<(parallel ? 2 : 1) {
                        let f = parallel ? parts.map { $0[variant] } : fields
                        output.append(PDFLesson(className: name, weekday: column / 8 + 1, period: column % 8 + 1,
                                                names: TimetableLessonNames(subject: f[0], teacher: f[1],
                                                                            room: PDF239TimetableRoomText.collapsingRepeatedVoicingMarks(f[2])),
                                                sourceText: lines.joined(separator: "\n"), page: 1))
                    }
                    if output.count > maximumRecords { throw PDFParseError(code: .limit, branch:.b371) }
                }
                if fullScopeProven { rowRegions.formUnion(seen) }
            }
            if fullScopeProven {
                if let rightEdge, provenSlots.count <= maximumRecords - header.count,
                   coversFullRow(row, from: classBox.right, to: rightEdge, regions: rowRegions) {
                    provenSlots.append(contentsOf: header.indices.map {
                        .init(className: name, weekday: $0 / 8 + 1, period: $0 % 8 + 1)
                    })
                } else { fullScopeProven = false }
            }
        }
        guard !classes.isEmpty, !output.isEmpty else { throw PDFParseError(code: .unsupported, page: 1, branch:.b370) }
        return (output, fullScopeProven ? provenSlots : nil)
    }

    // Used only to record comparison evidence. A clipped strip or an
    // uninspected gap cannot certify an empty slot.
    static func coversFullRow(_ row: PDFBox, from left: Double, to right: Double, regions: Set<PDFBox>) -> Bool {
        let tolerance = 0.3
        guard left < right, row.top < row.bottom, !regions.isEmpty, regions.count <= 512,
              regions.allSatisfy({
                  $0.top < $0.bottom && $0.left < $0.right &&
                      $0.top >= row.top - tolerance && $0.bottom <= row.bottom + tolerance &&
                      $0.left >= left && $0.right <= right
              }) else { return false }
        let inside = regions.flatMap { [$0.top, $0.bottom] }.filter { row.top < $0 && $0 < row.bottom }
        let edges = Set([row.top, row.bottom] + inside).sorted()
        let ordered = regions.sorted { $0.left == $1.left ? $0.right < $1.right : $0.left < $1.left }
        for (top, bottom) in zip(edges, edges.dropFirst()) {
            let columns = ordered.filter { $0.top <= top && $0.bottom >= bottom }
            guard let first = columns.first, let last = columns.last,
                  first.left == left, last.right == right,
                  zip(columns, columns.dropFirst()).allSatisfy({ $0.0.right == $0.1.left }) else {
                return false
            }
        }
        return true
    }

    static func rightTableEdge(on page: PDFPageLayout, row: PDFBox, after lastHeading: Double) -> Double? {
        page.lines.lazy.filter {
            $0.vertical && $0.x1 > lastHeading && $0.y1 <= row.top + 0.3 && $0.y2 >= row.bottom - 0.3
        }.map(\.x1).max()
    }
}

enum PDF239TimetableRoomText {
    static func collapsingRepeatedVoicingMarks(_ room: String) -> String {
        var output = String()
        var afterHalfwidthKana = false
        var repeatedMark: UInt32?
        for scalar in room.unicodeScalars {
            let value = scalar.value
            if (0xFF66...0xFF9D).contains(value) {
                afterHalfwidthKana = true
                repeatedMark = nil
            } else if value == 0xFF9E || value == 0xFF9F {
                if afterHalfwidthKana {
                    afterHalfwidthKana = false
                    repeatedMark = value
                } else if repeatedMark == value {
                    continue
                } else {
                    repeatedMark = nil
                }
            } else {
                afterHalfwidthKana = false
                repeatedMark = nil
            }
            output.unicodeScalars.append(scalar)
        }
        return output
    }
}
