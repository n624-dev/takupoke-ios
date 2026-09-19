import Foundation

struct PDFGlyph: Codable {
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var cx: Double { x + width / 2 }
    var cy: Double { y + height / 2 }
}
struct PDFRule: Codable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
    var horizontal: Bool { abs(y1 - y2) < 0.2 }
    var vertical: Bool { abs(x1 - x2) < 0.2 }
}
struct PDFPageLayout: Codable {
    var width: Double
    var height: Double
    var glyphs: [PDFGlyph]
    var lines: [PDFRule]
    var arrows: [PDFArrow]? = nil
}
struct PDFArrow: Codable { var x: Double; var top: Double; var bottom: Double }
struct PDFBox: Hashable {
    var left: Double
    var top: Double
    var right: Double
    var bottom: Double
}
struct PDFLesson: Codable, Equatable {
    var className: String
    var weekday: Int
    var period: Int
    var names: TimetableLessonNames
    var sourceText: String
    var page: Int
}
struct PDFSchoolEvent: Codable, Equatable {
    var date: String
    var scope: String
    var title: String
    var page: Int
    var endDate: String? = nil
    var periodNeedsReview: Bool = false
    var periodEvidence: String? = nil
}
struct PDFAnalysis: Codable {
    static let parserVersion = 1
    var version = parserVersion
    var kind: MaterialKind
    var sourceDigest: String
    var sourceName: String
    var parsedAt: Date
    var schoolYear: Int
    var term: String?
    var lessons: [PDFLesson]
    var events: [PDFSchoolEvent]
    var notices: [String]
}
struct PDFParseAttempt: Codable {
    var date: Date
    var sourceDigest: String?
    var failure: PDFParseError?
}
struct PDFParseError: Error, LocalizedError, Codable, Equatable {
    enum Code: String, Codable { case unreadable, unsupported, ambiguous, limit, cancelled, storage }
    var code: Code
    var page: Int? = nil
    var errorDescription: String? {
        let reason: String
        switch code {
        case .unreadable: reason = "PDFを読み取れません。暗号化・破損・画像だけの資料には対応していません。"
        case .unsupported: reason = "未対応のPDF書式です。年度・見出し・表の構造を確認できません。"
        case .ambiguous: reason = "表の内容を一意に読み取れません。推測せず解析を停止しました。"
        case .limit: reason = "PDFの解析上限を超えています。"
        case .cancelled: reason = "PDF解析を中止しました。"
        case .storage: reason = "PDF解析結果を保存できませんでした。"
        }
        return (page.map { "\($0)ページ目：" } ?? "") + reason + "前回の正常な解析結果は保持しています。"
    }
}

/// Geometry is in displayed page coordinates: top-left origin, after page rotation.
/// This core has no network access and never opens another document.
struct PDFGrid {
    let page: PDFPageLayout
    func column(_ x: Double, _ y: Double) throws -> PDFBox {
        let vs = page.lines.filter { $0.vertical && $0.y1 - 0.8 <= y && y <= $0.y2 + 0.8 }
        guard let l = vs.filter({ $0.x1 < x - 0.5 }).map(\.x1).max(),
              let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min() else { throw PDFParseError(code: .unsupported) }
        return PDFBox(left: l, top: 0, right: r, bottom: page.height)
    }
    func dateRow(_ x: Double, _ y: Double, headerBottom: Double) throws -> PDFBox {
        let hs = page.lines.filter { $0.horizontal && $0.x1 - 0.8 <= x && x <= $0.x2 + 0.8 }
        guard let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else { throw PDFParseError(code: .unsupported) }
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
            throw PDFParseError(code: .unsupported)
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
    func text(_ box: PDFBox) -> [String] {
        Self.rows(glyphs(in: box)).map { $0.map(\.text).joined() }
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

enum PDFSchoolParser {
    private struct CalendarArrow {
        var start: String
        var end: String
        var scope: String
        var relativeX: Double
    }
    static let maximumRecords = 10000
    static func key(_ s: String) -> String {
        s.precomposedStringWithCompatibilityMapping.components(separatedBy: .whitespacesAndNewlines).joined()
    }
    static func parse(_ pages: [PDFPageLayout], kind: MaterialKind, digest: String, name: String,
                      check: () throws -> Void = {}) throws -> PDFAnalysis {
        guard kind != .changes, !pages.isEmpty, pages.count <= 12 else { throw PDFParseError(code: .unsupported) }
        for (index, page) in pages.enumerated() {
            try check()
            guard page.width.isFinite, page.height.isFinite, page.width > 0, page.height > 0,
                  page.width <= 5000, page.height <= 5000,
                  !page.glyphs.isEmpty, page.glyphs.count <= 100000, page.lines.count <= 100000,
                  page.glyphs.allSatisfy({ [$0.x, $0.y, $0.width, $0.height].allSatisfy(\.isFinite) &&
                      $0.width >= 0 && $0.height >= 0 && $0.text.utf8.count <= 64 }),
                  page.lines.allSatisfy({ [$0.x1, $0.y1, $0.x2, $0.y2].allSatisfy(\.isFinite) }),
                  (page.arrows?.count ?? 0) <= 1000,
                  (page.arrows ?? []).allSatisfy({ [$0.x, $0.top, $0.bottom].allSatisfy(\.isFinite) && $0.top < $0.bottom }) else {
                throw PDFParseError(code: .limit, page: index + 1)
            }
        }
        let top = PDFGrid.rows(pages[0].glyphs.filter { $0.cy < pages[0].height / 8 }).map { $0.map(\.text).joined() }.joined()
        let normalized = key(top)
        guard let range = normalized.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
              let era = Int(normalized[range].dropFirst(2).dropLast(2)), (1...99).contains(era) else {
            throw PDFParseError(code: .unsupported, page: 1)
        }
        let year = 2018 + era
        for (index, page) in pages.enumerated() {
            let heading = key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 8 }).map { $0.map(\.text).joined() }.joined())
            guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
                  Int(heading[range].dropFirst(2).dropLast(2)) == era else {
                throw PDFParseError(code: .unsupported, page: index + 1)
            }
        }
        var result = PDFAnalysis(kind: kind, sourceDigest: digest, sourceName: name, parsedAt: Date(),
                                 schoolYear: year, term: nil, lessons: [], events: [], notices: [])
        if kind == .timetable {
            guard pages.count == 1, normalized.contains("時間割"),
                  normalized.contains("前期") != normalized.contains("後期") else { throw PDFParseError(code: .unsupported) }
            result.term = normalized.contains("前期") ? "前期" : "後期"
            result.lessons = try timetable(pages[0], check: check)
            result.notices = ["PDFの記載名を表示しています。正式名称の対応表はまだ取り込んでいません。",
                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更との統合はまだ行いません。"]
        } else {
            guard normalized.contains("行事予定表"), pages.count == 2 else { throw PDFParseError(code: .unsupported) }
            var months: Set<Int> = []
            var arrows: [CalendarArrow] = []
            for (i, page) in pages.enumerated() {
                do {
                    let parsed = try events(page, year: year, pageNumber: i + 1, check: check)
                    guard months.isDisjoint(with: parsed.months) else { throw PDFParseError(code: .ambiguous) }
                    months.formUnion(parsed.months)
                    result.events += parsed.records
                    arrows += parsed.arrows
                } catch let e as PDFParseError { throw PDFParseError(code: e.code, page: i + 1) }
            }
            guard months == Set(1...12), !result.events.isEmpty else { throw PDFParseError(code: .unsupported) }
            result.events.sort { ($0.date, $0.scope) < ($1.date, $1.scope) }
            attachPeriods(to: &result.events, arrows: arrows)
            result.notices = ["共通・詫間欄の記載を日付ごとに表示しています。行事名から休講を推測しません。",
                              "休業の終了日は期間表記・矢印から確認し、その日を含む期間として表示します。終了日未確認の項目は元PDFで確認してください。日別の休講反映はまだ行いません。"]
        }
        guard result.lessons.count + result.events.count <= maximumRecords else { throw PDFParseError(code: .limit) }
        try check()
        return result
    }

    private static func timetable(_ page: PDFPageLayout, check: () throws -> Void) throws -> [PDFLesson] {
        let grid = PDFGrid(page: page)
        let headers = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 5 }).filter {
            key($0.map(\.text).joined()) == String(repeating: "12345678", count: 5)
        }
        guard headers.count == 1, headers[0].count == 40 else { throw PDFParseError(code: .unsupported, page: 1) }
        let header = headers[0]
        let first = try grid.box(header[0].cx, header[0].cy)
        let classBox = try grid.box(first.left - 2, first.bottom + 20)
        guard let bodyBottom = page.lines.filter({ $0.vertical && abs($0.x1 - classBox.right) < 0.3 }).map(\.y2).max() else {
            throw PDFParseError(code: .unsupported, page: 1)
        }
        let classRows = PDFGrid.rows(page.glyphs.filter { classBox.left < $0.cx && $0.cx < classBox.right &&
            $0.cy > first.bottom && $0.cy < bodyBottom })
        var output: [PDFLesson] = []
        var classes: Set<String> = []
        for glyphs in classRows {
            try check()
            let label = key(glyphs.map(\.text).joined())
            guard label.range(of: "^(?:[1-9]|[A-Z]{2,8})$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1)
            }
            let y = glyphs.map(\.cy).reduce(0, +) / Double(glyphs.count)
            var row = try grid.box((classBox.left + classBox.right) / 2, y)
            let grade = key(grid.text(try grid.box(classBox.left - 2, y)).joined())
            guard grade == "AI" || grade.range(of: "^[1-9]$", options: .regularExpression) != nil else {
                throw PDFParseError(code: .ambiguous, page: 1)
            }
            let name = ChangeNormalizer.canonicalClassName(grade + "_" + label)
            guard classes.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1) }
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
                    let lines = grid.text(box)
                    if lines.isEmpty { continue }
                    guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, page: 1) }
                    guard lines.count <= 3, !lines[0].isEmpty else { throw PDFParseError(code: .ambiguous, page: 1) }
                    let fields = lines + Array(repeating: "", count: 3 - lines.count)
                    let parts = fields.map { $0.replacingOccurrences(of: "･", with: "・").components(separatedBy: "・") }
                    let parallel = lines.count == 3 && parts.allSatisfy { $0.count == 2 }
                    if parts[0].count > 1 && parts[1].count > 1 && !parallel {
                        throw PDFParseError(code: .ambiguous, page: 1)
                    }
                    if parallel && parts[0].contains(where: { $0.isEmpty }) { throw PDFParseError(code: .ambiguous, page: 1) }
                    for variant in 0..<(parallel ? 2 : 1) {
                        let f = parallel ? parts.map { $0[variant] } : fields
                        output.append(PDFLesson(className: name, weekday: column / 8 + 1, period: column % 8 + 1,
                                                names: TimetableLessonNames(subject: f[0], teacher: f[1], room: f[2]),
                                                sourceText: lines.joined(separator: "\n"), page: 1))
                    }
                    if output.count > maximumRecords { throw PDFParseError(code: .limit) }
                }
            }
        }
        guard !classes.isEmpty, !output.isEmpty else { throw PDFParseError(code: .unsupported, page: 1) }
        return output
    }

    private static func events(_ page: PDFPageLayout, year: Int, pageNumber: Int, check: () throws -> Void)
        throws -> (months: Set<Int>, records: [PDFSchoolEvent], arrows: [CalendarArrow]) {
        let grid = PDFGrid(page: page)
        let common = grid.anchors("共通", above: page.height / 8).sorted { $0.left < $1.left }
        let takuma = grid.anchors("詫間", above: page.height / 8).sorted { $0.left < $1.left }
        let takamatsu = grid.anchors("高松", above: page.height / 8).sorted { $0.left < $1.left }
        guard common.count == 6, takuma.count == 6, takamatsu.count == 6,
              let headerBottom = common.map(\.bottom).max(),
              let dayHeader = grid.anchors("日", above: headerBottom + 1).filter({ $0.right < common[0].left }).min(by: { $0.left < $1.left }) else {
            throw PDFParseError(code: .unsupported)
        }
        let dayX = (dayHeader.left + dayHeader.right) / 2
        let dateGlyphs = page.glyphs.filter { abs($0.cx - dayX) < 7 && $0.cy > headerBottom + 2 }
        let dateRows = PDFGrid.rows(dateGlyphs).compactMap { row -> (Int, Double)? in
            guard let day = Int(key(row.map(\.text).joined())), (1...31).contains(day) else { return nil }
            return (day, row.map(\.cy).reduce(0, +) / Double(row.count))
        }
        guard dateRows.map(\.0) == Array(1...31) else { throw PDFParseError(code: .unsupported) }
        var output: [PDFSchoolEvent] = []
        var arrows: [CalendarArrow] = []
        var months: Set<Int> = []
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        for i in 0..<6 {
            try check()
            let left = common[i].left, right = takuma[i].right
            let monthTexts = PDFGrid.rows(page.glyphs.filter { left < $0.cx && $0.cx < right &&
                $0.cy < common[i].top && $0.cy > common[i].top - 22 }).map { key($0.map(\.text).joined()) }.filter { $0.range(of: "^(?:[1-9]|1[0-2])月$", options: .regularExpression) != nil }
            guard monthTexts.count == 1 else { throw PDFParseError(code: .unsupported) }
            let monthText = monthTexts[0]
            guard monthText.range(of: "^(?:[1-9]|1[0-2])月$", options: .regularExpression) != nil,
                  let month = Int(monthText.dropLast()), months.insert(month).inserted else { throw PDFParseError(code: .unsupported) }
            for (scope, anchor) in [("共通", common[i]), ("詫間", takuma[i])] {
                var column: PDFBox
                if scope == "詫間" {
                    let other = takamatsu[i]
                    let preceding = try grid.column((other.left + other.right) / 2, (other.top + other.bottom) / 2)
                    column = PDFBox(left: preceding.right, top: 0, right: preceding.right * 2 - preceding.left, bottom: page.height)
                } else {
                    column = try grid.column((anchor.left + anchor.right) / 2, (anchor.top + anchor.bottom) / 2)
                }
                let calendarYear = month < 4 ? year + 1 : year
                var dayBoxes: [(Int, PDFBox)] = []
                for (day, y) in dateRows {
                    guard let date = cal.date(from: DateComponents(year: calendarYear, month: month, day: day)),
                          cal.component(.month, from: date) == month else { continue }
                    var box = try grid.dateRow(dayX, y, headerBottom: headerBottom)
                    box.top = max(headerBottom + 1, box.top)
                    dayBoxes.append((day, box))
                }
                for arrow in page.arrows ?? [] where column.left < arrow.x && arrow.x < column.right {
                    // Arrow tips can overhang a row border by up to two points; approach from above.
                    let start = dayBoxes.filter { $0.1.top - 2 <= arrow.top && arrow.top < $0.1.bottom - 0.5 }
                    let end = dayBoxes.filter { $0.1.top <= arrow.bottom - 2 && arrow.bottom - 2 <= $0.1.bottom }
                    if start.count == 1, end.count == 1, start[0].0 <= end[0].0 {
                        arrows.append(CalendarArrow(start: String(format: "%04d-%02d-%02d", calendarYear, month, start[0].0),
                            end: String(format: "%04d-%02d-%02d", calendarYear, month, end[0].0), scope: scope,
                            relativeX: (arrow.x - column.left) / (column.right - column.left)))
                    }
                }
                for (day, y) in dateRows {
                    try check()
                    let calendarYear = month < 4 ? year + 1 : year
                    let components = DateComponents(year: calendarYear, month: month, day: day)
                    guard let date = cal.date(from: components), cal.component(.month, from: date) == month else { continue }
                    let row = try grid.dateRow(dayX, y, headerBottom: headerBottom)
                    let rect = PDFBox(left: column.left, top: max(headerBottom + 1, row.top), right: column.right, bottom: row.bottom)
                    let glyphs = grid.glyphs(in: rect).filter { g in
                        !(scope == "詫間" && g.cx > column.right - 7 &&
                          (Int(key(g.text)) != nil || ["〇", "○"].contains(g.text)))
                    }
                    let title = PDFGrid.rows(glyphs).map { $0.map(\.text).joined() }.joined()
                    if !title.isEmpty {
                        output.append(PDFSchoolEvent(date: String(format: "%04d-%02d-%02d", calendarYear, month, day),
                                                     scope: scope, title: title, page: pageNumber))
                    }
                }
            }
        }
        return (months, output, arrows)
    }

    private static func attachPeriods(to events: inout [PDFSchoolEvent], arrows: [CalendarArrow]) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let pattern = try! NSRegularExpression(pattern: "(?:([0-9]{1,2})/)?([0-9]{1,2})日?まで")
        for i in events.indices {
            let title = key(events[i].title)
            guard title.contains("休業"), let startDate = formatter.date(from: events[i].date) else { continue }
            let ns = title as NSString
            let matches = pattern.matches(in: title, range: NSRange(location: 0, length: ns.length))
            var explicitEnd: String?
            if matches.count == 1 {
                let m = matches[0]
                let startMonth = cal.component(.month, from: startDate)
                let month = m.range(at: 1).location == NSNotFound ? startMonth : Int(ns.substring(with: m.range(at: 1)))!
                let day = Int(ns.substring(with: m.range(at: 2)))!
                let year = cal.component(.year, from: startDate) + (month < startMonth ? 1 : 0)
                if let end = cal.date(from: DateComponents(year: year, month: month, day: day)),
                   cal.component(.month, from: end) == month, cal.component(.day, from: end) == day, end >= startDate {
                    explicitEnd = formatter.string(from: end)
                }
            }
            let starts = arrows.filter { $0.start == events[i].date && $0.scope == events[i].scope }
            var arrowEnd: String?
            var ambiguousArrow = starts.count > 1
            if starts.count == 1 {
                var segment = starts[0]
                var visited: Set<String> = [segment.start]
                while let end = formatter.date(from: segment.end), let next = cal.date(byAdding: .day, value: 1, to: end),
                      cal.component(.day, from: next) == 1 {
                    let nextDate = formatter.string(from: next)
                    let nextSegments = arrows.filter { $0.start == nextDate && $0.scope == segment.scope &&
                        abs($0.relativeX - segment.relativeX) <= 0.15 }
                    if nextSegments.count > 1 { ambiguousArrow = true; break }
                    guard nextSegments.count == 1, visited.insert(nextDate).inserted else { break }
                    segment = nextSegments[0]
                }
                arrowEnd = segment.end
            }
            let expectsRange = !matches.isEmpty || title.contains("夏季休業") || title.contains("冬季休業") || title.contains("学年末休業") || !starts.isEmpty
            guard expectsRange else { continue }
            if ambiguousArrow { events[i].periodNeedsReview = true; continue }
            if let explicitEnd = explicitEnd {
                if let arrowEnd = arrowEnd, arrowEnd != explicitEnd {
                    events[i].periodNeedsReview = true
                } else {
                    events[i].endDate = explicitEnd
                    events[i].periodEvidence = "期間表記"
                }
            } else if matches.isEmpty, let arrowEnd = arrowEnd {
                events[i].endDate = arrowEnd
                events[i].periodEvidence = "矢印"
            } else { events[i].periodNeedsReview = true }
        }
    }
}
