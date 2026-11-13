// Strict parsing contract from 239.1 (bfc599fd5a552ced0c140497c703199547c30fd4).
// Return-only: separate column headings from class-table content.
// Exam scope is discovered from headers and ruled rows; no recovery proof is implied.
import Foundation

extension PDF239SpecialScheduleParser {
    /// Spreadsheet exporters often draw one top edge per cell, not one path
    /// across the entire table. Sweep aligned rule segments over period centres.
    static func examBodyTop(_ page: PDFPageLayout, periods: [PDFGlyph]) -> Double? {
        guard let first=periods.first else { return nil }
        let rules=page.lines.filter { $0.horizontal && $0.y1 > first.cy }.sorted { $0.y1 < $1.y1 }
        var start=0
        while start < rules.count {
            let y=rules[start].y1
            var end=start+1
            while end < rules.count && rules[end].y1-y <= 0.8 { end += 1 }
            var column=0
            for rule in rules[start..<end].sorted(by:{ $0.x1 < $1.x1 }) {
                if column == periods.count { break }
                if rule.x1-0.8 > periods[column].cx { break }
                while column < periods.count && rule.x1-0.8 <= periods[column].cx && periods[column].cx <= rule.x2+0.8 { column += 1 }
            }
            if column == periods.count { return y }
            start=end
        }
        return nil
    }

    static func examRowsReachBoundaries(_ page: PDFPageLayout, periods: [PDFGlyph], rows: [PDFBox]) -> Bool {
        guard periods.count >= 6, let first=rows.first, let last=rows.last,
              let top=examBodyTop(page,periods:periods) else { return false }
        var bottom=first.top
        for rule in page.lines.filter({ $0.vertical && abs($0.x1-first.right)<0.8 }).sorted(by:{ $0.y1 < $1.y1 }) {
            if rule.y1 <= bottom+0.8 && rule.y2 > bottom { bottom=rule.y2 }
        }
        return abs(first.top-top) <= 1 && abs(last.bottom-bottom) <= 1 &&
            zip(rows,rows.dropFirst()).allSatisfy { abs($0.bottom-$1.top) <= 1 }
    }

    static func examStructure(_ page: PDFPageLayout, schoolYear: Int, pageNumber: Int) throws
        -> ([PDFGlyph], [String], [(Run, SchoolDate)]) {
        let periods = try periodHeader(page, sequence: "123456")
        let columns = periods.count / 6
        let headerY = periods[0].cy
        let labels = runs(page.glyphs.filter { $0.cy < headerY - 3 && $0.cy > headerY - page.height / 10 })
            .filter { run in
                return run.text.range(of: "^(?:[12]年|[1-5]-(?:[1-3]|[A-Z]{2}))$", options: .regularExpression) != nil
            }.sorted { $0.cx < $1.cx }
        guard labels.count == columns else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .classLabel, branch:.b404) }
        let names = labels.map { $0.text.hasSuffix("年") ? "AI_" + String($0.text.prefix(1)) : $0.text.replacingOccurrences(of: "-", with: "_") }
        guard let bodyBottom = page.lines.filter({ $0.vertical && $0.x1 >= periods[0].cx - (periods[1].cx-periods[0].cx) && $0.x1 <= periods.last!.cx && $0.y2 > headerY }).map(\.y2).max() else {
            throw PDFParseError(code:.unsupported,page:pageNumber,stage:.gridRow,branch:.b429)
        }
        let dateRuns = runs(page.glyphs.filter { $0.cy > headerY + 5 && $0.cy < bodyBottom })
            .compactMap { run -> (Run, SchoolDate)? in
                guard run.cx < periods[0].cx, let day = date(run.text, schoolYear: schoolYear, slash: false) else { return nil }
                return (run, day)
            }.sorted { $0.0.cy < $1.0.cy }
        guard !dateRuns.isEmpty, dateRuns.count <= 31, Set(dateRuns.map { $0.1 }).count == dateRuns.count else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .calendarDates, branch:.b403)
        }
        let grid = PDF239Grid(page:page)
        let rows = try dateRuns.map { try grid.box($0.0.cx,$0.0.cy) }
        // Follow the date-column boundary of this table. A separate notes or
        // clock table lower on the page must not extend the lesson body.
        var tableBottom = rows[0].top
        for rule in page.lines.filter({ $0.vertical && abs($0.x1-rows[0].right)<0.8 }).sorted(by:{ $0.y1 < $1.y1 }) {
            if rule.y1 <= tableBottom+0.8 && rule.y2 > tableBottom { tableBottom=rule.y2 }
        }
        let left = periods[0].cx - (periods[1].cx-periods[0].cx)/2
        let right = periods.last!.cx + (periods.last!.cx-periods[periods.count-2].cx)/2
        let bodyTop = examBodyTop(page,periods:periods) ?? rows[0].top
        guard zip(rows,rows.dropFirst()).allSatisfy({ abs($0.bottom-$1.top) <= 1 }),
              page.glyphs.filter({ left < $0.cx && $0.cx < right && bodyTop < $0.cy && $0.cy < tableBottom }).allSatisfy({ g in rows.contains { $0.top < g.cy && g.cy < $0.bottom } }) else {
            throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.calendarDates,branch:.b430)
        }
        guard examRowsReachBoundaries(page,periods:periods,rows:rows) else {
            throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.calendarDates,branch:.b435)
        }
        for column in 0..<columns {
            let xs = Array(periods[(column*6)..<((column+1)*6)]).map(\.cx)
            guard zip(xs,xs.dropFirst()).allSatisfy({ $0 < $1 }),
                  xs[0]-(xs[1]-xs[0])/2 <= labels[column].cx,
                  labels[column].cx <= xs[5]+(xs[5]-xs[4])/2 else {
                throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.classLabel,branch:.b431)
            }
        }
        return (periods,names,dateRuns)
    }

    static func parseExamPage(_ page: PDFPageLayout, schoolYear: Int, pageNumber: Int,
                                      times: Times, check: () throws -> Void) throws -> ParsedPage {
        let (periods, names, dateRuns) = try examStructure(page,schoolYear:schoolYear,pageNumber:pageNumber)
        let grid = PDF239Grid(page: page)
        var result: [SpecialScheduleLesson] = []
        for (dayRun, day) in dateRuns {
            try check()
            let row = try grid.box(dayRun.cx, dayRun.cy)
            for (column, name) in names.enumerated() {
                let periodXs = (0..<6).map { periods[column * 6 + $0].cx }
                for period in 1...6 {
                    let x = periodXs[period - 1]
                    let cuts = Set(page.lines.filter { $0.horizontal && $0.x1 - 0.5 <= x && x <= $0.x2 + 0.5 &&
                        row.top + 1 < $0.y1 && $0.y1 < row.bottom - 1 }.map { ($0.y1 * 100).rounded() / 100 }).sorted()
                    let edges = [row.top] + cuts + [row.bottom]
                    var seen: Set<PDFBox> = []
                    for i in 0..<(edges.count - 1) where edges[i + 1] - edges[i] >= 2 {
                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2)
                        guard box.top >= row.top-0.8, box.bottom <= row.bottom+0.8,
                              !periods.enumerated().contains(where:{ index,g in
                                  index/6 != column && box.left+0.5 < g.cx && g.cx < box.right-0.5
                              }) else { throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.gridCell,branch:.b432) }
                        guard seen.insert(box).inserted else { continue }
                        result += try lessons(in: page, box: box, date: day, className: name,
                                              period: period, periodXs: periodXs,
                                              times: times, pageNumber: pageNumber)
                    }
                }
            }
        }
        return ParsedPage(dates: dateRuns.map { $0.1.iso8601 }, classes: names, lessons: result)
    }

    static func parseReturnPage(_ page: PDFPageLayout, schoolYear: Int,
                                        times: Times, geometry: PDFReturnGeometryRecorder? = nil, check: () throws -> Void) throws -> ParsedPage {
        let periods = try periodHeader(page, sequence: "12345678", repeats: 5)
        let headerY = periods[0].cy
        let step = periods[1].cx - periods[0].cx
        guard step > 5 else { throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b402) }
        let dates = runs(page.glyphs.filter { $0.cy < headerY && $0.cy > headerY - page.height / 20 })
            .compactMap { run -> (Run, SchoolDate)? in
                guard let day = date(run.text, schoolYear: schoolYear, slash: true) else { return nil }
                return (run, day)
            }.sorted { $0.0.cx < $1.0.cx }
        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5 else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .calendarDates, branch:.b401)
        }
        let note = PDF239SchoolParser.key(PDF239Grid.rows(page.glyphs).map { $0.map(\.text).joined() }.joined())
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "〜", with: "~")
        guard let specialDay = dates.first?.1, let ordinaryStart = dates.dropFirst().first?.1,
              let ordinaryEnd = dates.last?.1,
              ordinaryStart.month == ordinaryEnd.month,
              note.contains("\(specialDay.month)月\(specialDay.day)日の時間割は以下のとおり"),
              note.contains("\(ordinaryStart.month)月\(ordinaryStart.day)日~\(ordinaryEnd.day)日は通常の授業日どおりの授業時間") else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b400)
        }
        let ordinaryTimes = Times(single: Dictionary(uniqueKeysWithValues:
            TimetableSchedule.normalPeriodTimes.enumerated().map { ($0.offset + 1, $0.element) }),
            consecutive: [:])
        let left = runs(page.glyphs.filter { $0.cx < periods[0].cx - step * 0.15 &&
            $0.cy > headerY + 5 && $0.cy < page.height * 0.7 })
        let gradeMax = periods[0].cx - step * 0.8
        let grades = left.filter { $0.cx < gradeMax &&
            $0.text.range(of: "^(?:[1-5]|AI)$", options: .regularExpression) != nil }
        let classRuns = left.filter { $0.cx >= gradeMax &&
            $0.text.range(of: "^(?:[1-3]|CN|ES|IT)$", options: .regularExpression) != nil }
            .sorted { $0.cy < $1.cy }
        guard grades.count == 6, classRuns.count == 17 else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .classLabel, branch:.b399)
        }
        let grid = PDF239Grid(page: page)
        var seenClasses: Set<String> = []
        var result: [SpecialScheduleLesson] = []
        let firstClass = classRuns[0]
        let firstClassCell = try grid.box(firstClass.cx, firstClass.cy)
        let (contentTop, lowerHeadings) = try returnContentBand(page, firstClass: firstClass,
            classCell: firstClassCell, periods: periods, check: check)
        for (classIndex, run) in classRuns.enumerated() {
            try check()
            guard let grade = grades.min(by: { abs($0.cy - run.cy) < abs($1.cy - run.cy) }),
                  abs(grade.cy - run.cy) < step * 2.5 else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel, branch:.b398)
            }
            let name = grade.text == "AI" ? "AI_" + run.text : grade.text + "_" + run.text
            guard seenClasses.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass, branch:.b397) }
            let row = try grid.box(run.cx, run.cy)
            for (dayIndex, (_, day)) in dates.enumerated() {
                let dayTimes = dayIndex == 0 ? times : ordinaryTimes
                let periodXs = (0..<8).map { periods[dayIndex * 8 + $0].cx }
                for period in 1...8 {
                    let x = periodXs[period - 1]
                    let cuts = Set(page.lines.filter { $0.horizontal && $0.x1 - 0.5 <= x && x <= $0.x2 + 0.5 &&
                        row.top + 1 < $0.y1 && $0.y1 < row.bottom - 1 }.map { ($0.y1 * 100).rounded() / 100 }).sorted()
                    let edges = [row.top] + cuts + [row.bottom]
                    var seen: Set<PDFBox> = []
                    for i in 0..<(edges.count - 1) where edges[i + 1] - edges[i] >= 2 {
                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2)
                        guard seen.insert(box).inserted else { continue }
                        let target = geometry.flatMap {
                            $0.className == name && $0.date == day.iso8601 && $0.period == period ? $0 : nil
                        }
                        target?.begin(page:page,firstClass:firstClass.box,firstClassCell:firstClassCell,label:run.box,grade:grade.box,
                            row:row,original:box,classRow:classIndex+1,contentTop:contentTop,headings:periods+lowerHeadings,day:dayIndex,periodXs:periodXs)
                        result += try lessons(in: page, box: box, date: day, className: name,
                                              period: period, periodXs: periodXs,
                                              times: dayTimes, pageNumber: 1, contentTop: contentTop,
                                              geometry:target, dayIndex:dayIndex)
                    }
                }
            }
        }
        return ParsedPage(dates: dates.map { $0.1.iso8601 },
                          classes: seenClasses.sorted(), lessons: result)
    }

    /// The class-label cell can extend upwards through a second header band.
    /// Use its actual lower rule only when it crosses all period columns and
    /// the intervening band has explicit koma headings in multiple day groups.
    /// This does not filter lesson strings or alter original cell/span geometry.
    static func returnContentBand(_ page: PDFPageLayout, firstClass: Run,
                                  classCell: PDFBox, periods: [PDFGlyph],
                                  check: () throws -> Void) throws -> (Double, [PDFGlyph]) {
        let grid = PDF239Grid(page:page)
        guard let firstColumn = try? grid.column(periods[0].cx,firstClass.cy),
              let lastColumn = try? grid.column(periods.last!.cx,firstClass.cy) else { return (classCell.top,[]) }
        let separators = Set(page.lines.filter { $0.horizontal &&
            $0.x1 - 0.8 <= firstColumn.left && lastColumn.right <= $0.x2 + 0.8 &&
            classCell.top + 0.3 < $0.y1 && $0.y1 < firstClass.box.top
        }.map(\.y1)).sorted()
        for bottom in separators {
            try check()
            let glyphs = grid.glyphs(in:PDFBox(left:firstColumn.left,top:classCell.top,
                right:lastColumn.right,bottom:bottom))
            let annotations = runs(glyphs).filter {
                $0.text.range(of:"^[1-8]コマ(?:目)?(?:\\([^\\r\\n]*\\))?$",options:.regularExpression) != nil
            }
            let days = Set(annotations.map { run in
                periods.indices.min { abs(periods[$0].cx-run.cx) < abs(periods[$1].cx-run.cx) }! / 8
            })
            if days.count > 1 { return (bottom,glyphs) }
        }
        return (classCell.top,[])
    }
}
