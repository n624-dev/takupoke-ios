import Foundation

extension SpecialScheduleParser {
    static func parseExamPage(_ page: PDFPageLayout, schoolYear: Int, pageNumber: Int,
                                      times: Times, check: () throws -> Void) throws -> ParsedPage {
        let columns = pageNumber == 6 ? 2 : 3
        let periods = try periodHeader(page, sequence: "123456", repeats: columns)
        let headerY = periods[0].cy
        let labels = runs(page.glyphs.filter { $0.cy < headerY - 3 && $0.cy > headerY - page.height / 10 })
            .filter { run in
                if pageNumber == 6 { return run.text.range(of: "^[12]年$", options: .regularExpression) != nil }
                return run.text.range(of: "^[1-5]-(?:[1-3]|[A-Z]{2})$", options: .regularExpression) != nil
            }.sorted { $0.cx < $1.cx }
        guard labels.count == columns else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .classLabel) }
        let names = labels.map { pageNumber == 6 ? "AI_" + String($0.text.prefix(1)) : $0.text.replacingOccurrences(of: "-", with: "_") }
        let dateRuns = runs(page.glyphs.filter { $0.cy > headerY + 5 && $0.cy < page.height * 0.7 })
            .compactMap { run -> (Run, SchoolDate)? in
                guard run.cx < periods[0].cx, let day = date(run.text, schoolYear: schoolYear, slash: false) else { return nil }
                return (run, day)
            }.sorted { $0.0.cy < $1.0.cy }
        guard dateRuns.count == 5, Set(dateRuns.map { $0.1 }).count == 5 else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .calendarDates)
        }
        let grid = PDFGrid(page: page)
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
                                        times: Times, check: () throws -> Void) throws -> ParsedPage {
        let periods = try periodHeader(page, sequence: "12345678", repeats: 5)
        let headerY = periods[0].cy
        let step = periods[1].cx - periods[0].cx
        guard step > 5 else { throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading) }
        let dates = runs(page.glyphs.filter { $0.cy < headerY && $0.cy > headerY - page.height / 20 })
            .compactMap { run -> (Run, SchoolDate)? in
                guard let day = date(run.text, schoolYear: schoolYear, slash: true) else { return nil }
                return (run, day)
            }.sorted { $0.0.cx < $1.0.cx }
        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5 else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .calendarDates)
        }
        let note = PDFSchoolParser.key(PDFGrid.rows(page.glyphs).map { $0.map(\.text).joined() }.joined())
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "〜", with: "~")
        guard let specialDay = dates.first?.1, let ordinaryStart = dates.dropFirst().first?.1,
              let ordinaryEnd = dates.last?.1,
              ordinaryStart.month == ordinaryEnd.month,
              note.contains("\(specialDay.month)月\(specialDay.day)日の時間割は以下のとおり"),
              note.contains("\(ordinaryStart.month)月\(ordinaryStart.day)日~\(ordinaryEnd.day)日は通常の授業日どおりの授業時間") else {
            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
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
            throw PDFParseError(code: .unsupported, page: 1, stage: .classLabel)
        }
        let grid = PDFGrid(page: page)
        var seenClasses: Set<String> = []
        var result: [SpecialScheduleLesson] = []
        for run in classRuns {
            try check()
            guard let grade = grades.min(by: { abs($0.cy - run.cy) < abs($1.cy - run.cy) }),
                  abs(grade.cy - run.cy) < step * 2.5 else {
                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel)
            }
            let name = grade.text == "AI" ? "AI_" + run.text : grade.text + "_" + run.text
            guard seenClasses.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass) }
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
                        result += try lessons(in: page, box: box, date: day, className: name,
                                              period: period, periodXs: periodXs,
                                              times: dayTimes, pageNumber: 1)
                    }
                }
            }
        }
        return ParsedPage(dates: dates.map { $0.1.iso8601 },
                          classes: seenClasses.sorted(), lessons: result)
    }
}
