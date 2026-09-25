import Foundation

enum SpecialScheduleKind: String, Codable, CaseIterable, Identifiable {
    case exam, examReturn

    var id: String { rawValue }
    var title: String { self == .exam ? "試験時間割" : "試験返却時間割" }
}

struct SpecialScheduleLesson: Codable, Equatable {
    let date: String
    let className: String
    let period: Int
    let spanStart: Int
    let spanEnd: Int
    let timeRange: String?
    let lines: [String]
    let page: Int

    var subject: String { lines.first ?? "" }
    var teacher: String { lines.count > 1 ? lines[1] : "" }
    var room: String { lines.count > 2 ? lines[2] : "" }
}

struct SpecialScheduleAnalysis: Codable, Equatable {
    static let parserVersion = 6
    var version = parserVersion
    let kind: SpecialScheduleKind
    let sourceDigest: String
    let sourceName: String
    let parsedAt: Date
    let schoolYear: Int
    let coveredDates: [String]
    let coveredClasses: [String]
    let periodTimes: [Int: String]
    let lessons: [SpecialScheduleLesson]

    func applies(date: String, className: String) -> Bool {
        coveredDates.contains(date) && coveredClasses.contains(className)
    }

    func periodTime(on date: String, period: Int) -> String? {
        guard coveredDates.contains(date) else { return nil }
        if kind == .examReturn && date != coveredDates.first {
            guard (1...TimetableSchedule.normalPeriodTimes.count).contains(period) else { return nil }
            return TimetableSchedule.normalPeriodTimes[period - 1]
        }
        return periodTimes[period]
    }

    func timeRange(for lesson: SpecialScheduleLesson) -> String? {
        guard applies(date: lesson.date, className: lesson.className) else { return nil }
        if kind != .examReturn || lesson.date == coveredDates.first,
           let recorded = lesson.timeRange { return recorded }
        guard let start = periodTime(on: lesson.date, period: lesson.spanStart)?
            .components(separatedBy: "〜").first,
              let end = periodTime(on: lesson.date, period: lesson.spanEnd)?
            .components(separatedBy: "〜").last else { return nil }
        return "\(start)〜\(end)"
    }
}

/// Reads only the two table layouts confirmed in the supplied PDFs. A changed
/// layout fails validation and never replaces the previous successful result.
enum SpecialScheduleParser {
    private struct Run {
        let text: String
        let box: PDFBox
        var cx: Double { (box.left + box.right) / 2 }
        var cy: Double { (box.top + box.bottom) / 2 }
    }

    private struct ParsedPage {
        let dates: [String]
        let classes: [String]
        let lessons: [SpecialScheduleLesson]
    }

    private struct Times: Equatable {
        let single: [Int: String]
        let consecutive: [String: String]
    }

    static func parse(_ pages: [PDFPageLayout], kind: SpecialScheduleKind, digest: String,
                      name: String, check: () throws -> Void = {}) throws -> SpecialScheduleAnalysis {
        guard !pages.isEmpty, pages.count == (kind == .exam ? 6 : 1) else {
            throw PDFParseError(code: .unsupported, stage: .documentHeading)
        }
        var year: Int?
        var lessons: [SpecialScheduleLesson] = []
        var expectedDates: [String]?
        var coveredClasses: Set<String> = []
        var periodTimes: Times?
        for (index, page) in pages.enumerated() {
            try check()
            guard page.width > 0, page.height > 0, page.width <= 5000, page.height <= 5000,
                  page.glyphs.count <= 100000, page.lines.count <= 100000,
                  page.glyphs.allSatisfy({ [$0.x, $0.y, $0.width, $0.height].allSatisfy(\.isFinite) &&
                      $0.text.utf8.count <= 64 }) else {
                throw PDFParseError(code: .limit, page: index + 1)
            }
            let header = PDFSchoolParser.key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 4 })
                .map { $0.map(\.text).joined() }.joined())
            guard let range = header.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
                  let era = Int(header[range].dropFirst(2).dropLast(2)),
                  (1...99).contains(era), header.contains("試験"),
                  header.contains("返却") == (kind == .examReturn) else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .documentHeading)
            }
            let pageYear = 2018 + era
            guard year == nil || year == pageYear else {
                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .yearHeading)
            }
            year = pageYear
            let pageTimes = try readPeriodTimes(page, count: kind == .exam ? 6 : 8,
                                                pageNumber: index + 1)
            guard periodTimes == nil || periodTimes == pageTimes else {
                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .periodHeading)
            }
            periodTimes = pageTimes
            let parsed = try kind == .exam
                ? parseExamPage(page, schoolYear: pageYear, pageNumber: index + 1,
                                times: pageTimes, check: check)
                : parseReturnPage(page, schoolYear: pageYear, times: pageTimes, check: check)
            let dates = parsed.dates.sorted()
            guard expectedDates == nil || expectedDates == dates else {
                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .calendarDates)
            }
            expectedDates = dates
            guard coveredClasses.isDisjoint(with: parsed.classes) else {
                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .duplicateClass)
            }
            coveredClasses.formUnion(parsed.classes)
            lessons += parsed.lessons
            guard lessons.count <= PDFSchoolParser.maximumRecords else { throw PDFParseError(code: .limit) }
        }
        guard let year, let dates = expectedDates, let periodTimes,
              coveredClasses.count == 17, !lessons.isEmpty else { throw PDFParseError(code: .unsupported) }
        return SpecialScheduleAnalysis(kind: kind, sourceDigest: digest, sourceName: name,
                                       parsedAt: Date(), schoolYear: year, coveredDates: dates,
                                       coveredClasses: coveredClasses.sorted(), periodTimes: periodTimes.single,
                                       lessons: lessons.sorted { ($0.date, $0.className, $0.period, $0.page) <
                                           ($1.date, $1.className, $1.period, $1.page) })
    }

    private static func readPeriodTimes(_ page: PDFPageLayout, count: Int,
                                        pageNumber: Int) throws -> Times {
        let pattern = try NSRegularExpression(pattern: "([1-8])時限目([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        let consecutivePattern = try NSRegularExpression(pattern: "([1-8])[・･]([1-8])時限連続([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        var times: [Int: String] = [:]
        var consecutive: [String: String] = [:]
        for row in PDFGrid.rows(page.glyphs) {
            let value = PDFSchoolParser.key(row.map(\.text).joined())
            let ns = value as NSString
            for match in pattern.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let period = Int(ns.substring(with: match.range(at: 1)))!
                let start = ns.substring(with: match.range(at: 2))
                let end = ns.substring(with: match.range(at: 3))
                guard period <= count, let startTime = clockMinutes(start),
                      let endTime = clockMinutes(end), startTime < endTime,
                      times[period] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
                }
                times[period] = String(format: "%02d:%02d〜%02d:%02d",
                                       startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
            for match in consecutivePattern.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let first = Int(ns.substring(with: match.range(at: 1)))!
                let last = Int(ns.substring(with: match.range(at: 2)))!
                let start = ns.substring(with: match.range(at: 3))
                let end = ns.substring(with: match.range(at: 4))
                let key = "\(first)-\(last)"
                guard first < last, last <= count,
                      let startTime = clockMinutes(start), let endTime = clockMinutes(end),
                      startTime < endTime, consecutive[key] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
                }
                consecutive[key] = String(format: "%02d:%02d〜%02d:%02d",
                                          startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
        }
        guard times.count == count else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading)
        }
        return Times(single: times, consecutive: consecutive)
    }

    private static func clockMinutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private static func runs(_ glyphs: [PDFGlyph]) -> [Run] {
        PDFGrid.rows(glyphs).flatMap { row -> [Run] in
            var chunks: [[PDFGlyph]] = []
            for glyph in row {
                if let last = chunks.last?.last,
                   glyph.x - (last.x + last.width) > max(2, min(last.height, glyph.height) * 0.55) {
                    chunks.append([])
                } else if chunks.isEmpty { chunks.append([]) }
                chunks[chunks.count - 1].append(glyph)
            }
            return chunks.compactMap { chunk in
                let text = PDFSchoolParser.key(chunk.map(\.text).joined())
                guard !text.isEmpty else { return nil }
                return Run(text: text, box: PDFBox(left: chunk.map(\.x).min()!, top: chunk.map(\.y).min()!,
                                                  right: chunk.map { $0.x + $0.width }.max()!,
                                                  bottom: chunk.map { $0.y + $0.height }.max()!))
            }
        }
    }

    private static func periodHeader(_ page: PDFPageLayout, sequence: String, repeats: Int) throws -> [PDFGlyph] {
        let rows = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 4 })
        let matching = rows.filter { PDFSchoolParser.key($0.map(\.text).joined()) == String(repeating: sequence, count: repeats) }
        guard matching.count == 1, matching[0].count == sequence.count * repeats else {
            throw PDFParseError(code: .unsupported, stage: .periodHeading)
        }
        return matching[0]
    }

    private static func date(_ text: String, schoolYear: Int, slash: Bool) -> SchoolDate? {
        let pattern = slash ? "^([0-9]{1,2})/([0-9]{1,2})$" : "^([0-9]{1,2})月([0-9]{1,2})日"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let month = Int(text[monthRange]), let day = Int(text[dayRange]) else { return nil }
        return SchoolDate(year: month >= 4 ? schoolYear : schoolYear + 1, month: month, day: day)
    }

    private static func lessons(in page: PDFPageLayout, box: PDFBox, date: SchoolDate,
                                className: String, period: Int, periodXs: [Double],
                                times: Times, pageNumber: Int) throws -> [SpecialScheduleLesson] {
        let grid = PDFGrid(page: page)
        let lines = try grid.timetableText(box).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count <= 8, lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .lessonLines)
        }
        guard !lines.isEmpty else { return [] }
        let covered = periodXs.enumerated().filter { box.left + 0.5 < $0.element &&
            $0.element < box.right - 0.5 }.map { $0.offset + 1 }
        guard let first = covered.first, let last = covered.last, covered.contains(period) else {
            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .gridCell)
        }
        let time: String?
        if first == last {
            time = times.single[period]
        } else if let explicit = times.consecutive["\(first)-\(last)"] {
            time = explicit
        } else if let start = times.single[first]?.components(separatedBy: "〜").first,
                  let end = times.single[last]?.components(separatedBy: "〜").last {
            time = "\(start)〜\(end)"
        } else {
            time = nil
        }
        return [SpecialScheduleLesson(date: date.iso8601, className: className,
                                      period: period, spanStart: first, spanEnd: last, timeRange: time,
                                      lines: lines, page: pageNumber)]
    }

    private static func parseExamPage(_ page: PDFPageLayout, schoolYear: Int, pageNumber: Int,
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

    private static func parseReturnPage(_ page: PDFPageLayout, schoolYear: Int,
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

/// The same full-content export format as the ordinary timetable. The special
/// material kind and parser version travel inside diagnostic.json.
enum SpecialScheduleDiagnosticReport {
    static func make(_ diagnostic: PDFFullReadDiagnostic, kind: SpecialScheduleKind,
                     sourceName: String?, succeeded: Bool, failure: PDFParseError?,
                     trace: PDFDiagnosticSnapshot?) -> String? {
        var full = diagnostic
        full.materialKind = kind.rawValue
        full.parserVersion = SpecialScheduleAnalysis.parserVersion
        full.sourceName = sourceName
        full.analysisSucceeded = succeeded
        full.attemptFailure = failure
        full.trace = trace
        return (try? PDFFullDiagnosticEncoding.report(full)) ??
            (try? full.jsonData()).flatMap { String(data: $0, encoding: .utf8) }
                .map { "TAKUPOKE-PDF-FULL-JSON-1\n" + $0 }
    }
}
