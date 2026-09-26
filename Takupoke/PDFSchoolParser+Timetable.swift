import Foundation

extension PDFSchoolParser {
    static func timetable(_ page: PDFPageLayout, check: () throws -> Void) throws -> [PDFLesson] {
        let grid = PDFGrid(page: page)
        let headers = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 5 }).filter {
            key($0.map(\.text).joined()) == String(repeating: "12345678", count: 5)
        }
        guard headers.count == 1, headers[0].count == 40 else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
        }
        let header = headers[0]
        let first = try grid.box(header[0].cx, header[0].cy)
        let classBox = try grid.box(first.left - 2, first.bottom + 20)
        guard let bodyBottom = page.lines.filter({ $0.vertical && abs($0.x1 - classBox.right) < 0.3 }).map(\.y2).max() else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .gridColumn)
        }
        let classRows = PDFGrid.rows(page.glyphs.filter { classBox.left < $0.cx && $0.cx < classBox.right &&
            $0.cy > first.bottom && $0.cy < bodyBottom })
        var output: [PDFLesson] = []
        var classes: Set<String> = []
        for (classIndex, glyphs) in classRows.enumerated() {
            try check()
            let label = key(glyphs.map(\.text).joined())
            guard label.range(of: "^(?:[1-9]|[A-Z]{2,8})$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .classLabel)
            }
            let y = glyphs.map(\.cy).reduce(0, +) / Double(glyphs.count)
            var row = try grid.box((classBox.left + classBox.right) / 2, y)
            let grade = try key(grid.text(grid.box(classBox.left - 2, y)).joined())
            guard grade == "AI" || grade.range(of: "^[1-9]$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel)
            }
            let name = ChangeNormalizer.canonicalClassName(grade + "_" + label)
            guard classes.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass) }
            // The first class spans the supplementary period header as well.
            // Use the top of its first actual subject cell to exclude that header.
            row.top = max(row.top, try grid.box(header[0].cx, y).top)
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
                    guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, page: 1) }
                    guard lines.count <= 3, !lines[0].isEmpty else { throw PDFParseError(code: .ambiguous, page: 1, stage: .lessonLines, cell: cell) }
                    let fields = lines + Array(repeating: "", count: 3 - lines.count)
                    let parts = fields.map { $0.replacingOccurrences(of: "･", with: "・").components(separatedBy: "・") }
                    let parallel = lines.count == 3 && parts.allSatisfy { $0.count == 2 }
                    if parts[0].count > 1 && parts[1].count > 1 && !parallel {
                        throw PDFParseError(code: .ambiguous, page: 1, stage: .parallelLessons, cell: cell)
                    }
                    if parallel && parts[0].contains(where: { $0.isEmpty }) { throw PDFParseError(code: .ambiguous, page: 1, stage: .emptySubject, cell: cell) }
                    for variant in 0..<(parallel ? 2 : 1) {
                        let f = parallel ? parts.map { $0[variant] } : fields
                        output.append(PDFLesson(className: name, weekday: column / 8 + 1, period: column % 8 + 1,
                                                names: TimetableLessonNames(subject: f[0], teacher: f[1],
                                                                            room: PDFTimetableRoomText.collapsingRepeatedVoicingMarks(f[2])),
                                                sourceText: lines.joined(separator: "\n"), page: 1))
                    }
                    if output.count > maximumRecords { throw PDFParseError(code: .limit) }
                }
            }
        }
        guard !classes.isEmpty, !output.isEmpty else { throw PDFParseError(code: .unsupported, page: 1) }
        return output
    }
}

enum PDFTimetableRoomText {
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
