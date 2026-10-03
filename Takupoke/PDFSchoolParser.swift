import Foundation

enum PDFSchoolParser {
    static let maximumRecords = 10000
    struct YearMarker { let year: Int; let range: Range<String.Index>; let isReiwa: Bool }
    static func yearMarkers(_ header: String,check: () throws -> Void = {}) throws -> [YearMarker] {
        var markers = [YearMarker](), remainder = header.startIndex..<header.endIndex
        while let range = header.range(of:"(?<![\\p{N}])(?:令和[\\p{N}]+|[\\p{N}]+)年度",options:.regularExpression,range:remainder) {
            try check()
            let token = header[range], era = token.hasPrefix("令和")
            let digits = String(era ? token.dropFirst(2).dropLast(2) : token.dropLast(2)).precomposedStringWithCompatibilityMapping
            guard (era ? (1...2).contains(digits.count) : digits.count == 4),
                  digits.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(digits),
                  !era || (1...99).contains(value) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
            let year = era ? 2018+value:value
            guard (1900...9998).contains(year) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
            markers.append(YearMarker(year:year,range:range,isReiwa:era))
            remainder = range.upperBound..<header.endIndex
        }
        return markers
    }
    static func uniqueTitleYear(_ header: String,check: () throws -> Void = {}) throws -> Int {
        let markers = try yearMarkers(header,check:check)
        guard let first = markers.first, markers.contains(where:\.isReiwa) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
        guard markers.allSatisfy({ $0.year == first.year }) else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) }
        return first.year
    }
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
            if kind == .timetable {
                do { try page.requireVisibleBounds(check:check) }
                catch var error as PDFParseError { error.page = index+1; throw error }
            }
        }
        let top = PDFGrid.rows(pages[0].glyphs.filter { $0.cy < pages[0].height / 8 }).map { $0.map(\.text).joined() }.joined()
        let normalized = key(top)
        let year: Int
        if kind == .timetable {
            do { year = try uniqueTitleYear(normalized,check:check) }
            catch var error as PDFParseError { error.page = 1; throw error }
        } else {
            // Legacy event PDFs retain their original header contract.
            guard let range = normalized.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
                  let era = Int(normalized[range].dropFirst(2).dropLast(2)), (1...99).contains(era) else {
                throw PDFParseError(code: .unsupported, page: 1, stage: .yearHeading)
            }
            year = 2018+era
        }
        for (index, page) in pages.enumerated() {
            let heading = key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 8 }).map { $0.map(\.text).joined() }.joined())
            if kind == .timetable {
                do { guard try uniqueTitleYear(heading,check:check) == year else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) } }
                catch var error as PDFParseError { error.page = index+1; throw error }
            } else {
                guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
                      Int(heading[range].dropFirst(2).dropLast(2)) == year-2018 else {
                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .yearHeading)
                }
            }
        }
        var result = PDFAnalysis(version: PDFAnalysis.currentVersion(for: kind), kind: kind, sourceDigest: digest, sourceName: name, parsedAt: Date(),
                                 schoolYear: year, term: nil, lessons: [], events: [], notices: [])
        if kind == .timetable {
            guard pages.count == 1, normalized.contains("時間割"),
                  normalized.contains("前期") != normalized.contains("後期") else {
                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading)
            }
            result.term = normalized.contains("前期") ? "前期" : "後期"
            do { result.lessons = try timetable(pages[0], check: check) }
            catch var error as PDFParseError { error.page = 1; throw error }
            result.notices = ["PDFの記載名を解析結果として保存しています。正式名称の対応は表示時に適用します。",
                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更は日付ごとの表示時に反映します。"]
        } else {
            guard normalized.contains("行事予定表"), pages.count == 2 else {
                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading)
            }
            var months: Set<Int> = []
            var arrows: [CalendarArrow] = []
            for (i, page) in pages.enumerated() {
                do {
                    let parsed = try events(page, year: year, pageNumber: i + 1, check: check)
                    guard months.isDisjoint(with: parsed.months) else { throw PDFParseError(code: .ambiguous) }
                    months.formUnion(parsed.months)
                    result.events += parsed.records
                    arrows += parsed.arrows
                } catch var error as PDFParseError { error.page = i + 1; throw error }
            }
            guard months == Set(1...12), !result.events.isEmpty else { throw PDFParseError(code: .unsupported) }
            result.events.sort { ($0.date, $0.scope) < ($1.date, $1.scope) }
            attachPeriods(to: &result.events, arrows: arrows)
            for i in result.events.indices { result.events[i].classification = .fromExplicitText(result.events[i].title) }
            result.notices = ["共通・詫間欄の記載を日付ごとに表示しています。休業・祝日・曜日振替・補講日・確認済みの校内行事にタグを付け、それ以外の授業の有無は未判定です。授業なしは登校不要という意味ではありません。",
                              "休業の終了日は期間表記・矢印から確認し、その日を含む期間として表示します。終了日未確認の項目は元PDFで確認してください。日別の休講反映はまだ行いません。"]
        }
        guard result.lessons.count + result.events.count <= maximumRecords else { throw PDFParseError(code: .limit) }
        try check()
        return result
    }

}
