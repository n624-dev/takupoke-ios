import Foundation

extension PDFSchoolParser {
    struct CalendarArrow {
        var start: String
        var end: String
        var scope: String
        var relativeX: Double
    }
    static func events(_ page: PDFPageLayout, year: Int, pageNumber: Int, check: () throws -> Void)
        throws -> (months: Set<Int>, records: [PDFSchoolEvent], arrows: [CalendarArrow]) {
        let grid = PDFGrid(page: page)
        let common = grid.anchors("共通", above: page.height / 8).sorted { $0.left < $1.left }
        let takuma = grid.anchors("詫間", above: page.height / 8).sorted { $0.left < $1.left }
        let takamatsu = grid.anchors("高松", above: page.height / 8).sorted { $0.left < $1.left }
        guard common.count == 6, takuma.count == 6, takamatsu.count == 6,
              let headerBottom = common.map(\.bottom).max(),
              let dayHeader = grid.anchors("日", above: headerBottom + 1).filter({ $0.right < common[0].left }).min(by: { $0.left < $1.left }) else {
            throw PDFParseError(code: .unsupported, stage: .eventColumns)
        }
        let dayX = (dayHeader.left + dayHeader.right) / 2
        let dateGlyphs = page.glyphs.filter { abs($0.cx - dayX) < 7 && $0.cy > headerBottom + 2 }
        let dateRows = PDFGrid.rows(dateGlyphs).compactMap { row -> (Int, Double)? in
            guard let day = Int(key(row.map(\.text).joined())), (1...31).contains(day) else { return nil }
            return (day, row.map(\.cy).reduce(0, +) / Double(row.count))
        }
        guard dateRows.map(\.0) == Array(1...31) else { throw PDFParseError(code: .unsupported, stage: .calendarDates) }
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
            guard monthTexts.count == 1 else { throw PDFParseError(code: .unsupported, stage: .monthHeading) }
            let monthText = monthTexts[0]
            guard monthText.range(of: "^(?:[1-9]|1[0-2])月$", options: .regularExpression) != nil,
                  let month = Int(monthText.dropLast()), months.insert(month).inserted else { throw PDFParseError(code: .unsupported, stage: .monthHeading) }
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
                    let title = try PDFGrid.contentRows(glyphs).map { $0.map(\.text).joined() }.joined(separator: "\n")
                    if !title.isEmpty {
                        output.append(PDFSchoolEvent(date: String(format: "%04d-%02d-%02d", calendarYear, month, day),
                                                     scope: scope, title: title, page: pageNumber))
                    }
                }
            }
        }
        return (months, output, arrows)
    }

    static func attachPeriods(to events: inout [PDFSchoolEvent], arrows: [CalendarArrow]) {
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
