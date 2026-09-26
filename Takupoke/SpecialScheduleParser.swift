import Foundation

enum SpecialScheduleParser {
    struct Run {
        let text: String
        let box: PDFBox
        var cx: Double { (box.left + box.right) / 2 }
        var cy: Double { (box.top + box.bottom) / 2 }
    }

    struct ParsedPage {
        let dates: [String]
        let classes: [String]
        let lessons: [SpecialScheduleLesson]
    }

    struct Times: Equatable {
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

    static func runs(_ glyphs: [PDFGlyph]) -> [Run] {
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

    static func periodHeader(_ page: PDFPageLayout, sequence: String, repeats: Int) throws -> [PDFGlyph] {
        let rows = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 4 })
        let matching = rows.filter { PDFSchoolParser.key($0.map(\.text).joined()) == String(repeating: sequence, count: repeats) }
        guard matching.count == 1, matching[0].count == sequence.count * repeats else {
            throw PDFParseError(code: .unsupported, stage: .periodHeading)
        }
        return matching[0]
    }

    static func date(_ text: String, schoolYear: Int, slash: Bool) -> SchoolDate? {
        let pattern = slash ? "^([0-9]{1,2})/([0-9]{1,2})$" : "^([0-9]{1,2})月([0-9]{1,2})日"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let monthRange = Range(match.range(at: 1), in: text),
              let dayRange = Range(match.range(at: 2), in: text),
              let month = Int(text[monthRange]), let day = Int(text[dayRange]) else { return nil }
        return SchoolDate(year: month >= 4 ? schoolYear : schoolYear + 1, month: month, day: day)
    }

    static func lessons(in page: PDFPageLayout, box: PDFBox, date: SchoolDate,
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

}
