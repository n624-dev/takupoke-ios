import Foundation

enum PDFDisplayText {
    /// Remove document line breaks for display, keeping the stored text intact.
    static func continuous(_ value: String) -> String {
        value.components(separatedBy: .newlines).joined()
    }
}

struct PDFGlyph: Codable {
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var sourceLine: Int? = nil
    var sourceOrder: Int? = nil
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
/// A bounded, text-free snapshot of just the failing cell. Never include glyph
/// text, document names, digests, paths or the rest of the page in this type.
struct PDFCellGeometryDiagnostic: Codable, Equatable {
    struct Glyph: Codable, Equatable {
        var line: Int?
        var order: Int?
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }
    static let maximumGlyphs = 256
    var parserVersion: Int
    var width: Double
    var height: Double
    var totalGlyphs: Int
    var glyphs: [Glyph]

    init(_ input: [PDFGlyph], box: PDFBox) {
        parserVersion = PDFAnalysis.currentVersion(for: .timetable)
        width = box.right - box.left
        height = box.bottom - box.top
        totalGlyphs = input.count
        // Cell-local ranks preserve comparisons without disclosing page offsets.
        let lines = Dictionary(uniqueKeysWithValues: Set(input.compactMap(\.sourceLine)).sorted().enumerated().map { ($1, $0) })
        let orders = Dictionary(uniqueKeysWithValues: Set(input.compactMap(\.sourceOrder)).sorted().enumerated().map { ($1, $0) })
        glyphs = input.prefix(Self.maximumGlyphs).map {
            Glyph(line: $0.sourceLine.flatMap { lines[$0] }, order: $0.sourceOrder.flatMap { orders[$0] },
                  x: $0.x - box.left, y: $0.y - box.top, width: $0.width, height: $0.height)
        }
    }
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
    var classification: PDFEventClassification? = nil
}
struct PDFEventClassification: Codable, Equatable {
    enum EventType: String, Codable {
        case noClass = "NO_CLASS", weekdayOverride = "WEEKDAY_OVERRIDE", special = "SPECIAL"
        case supplementary = "SUPPLEMENTARY", schoolEventNoClass = "SCHOOL_EVENT_NO_CLASS"
    }
    var type: EventType
    var scheduleDay: Int? = nil
    var needsReview: Bool = false

    var label: String {
        switch type {
        case .noClass: return "授業なし"
        case .supplementary: return "補講日"
        case .schoolEventNoClass: return "校内行事（授業なし）"
        case .weekdayOverride:
            let days = [1: "月", 2: "火", 3: "水", 4: "木", 5: "金"]
            return days[scheduleDay ?? 0].map { "曜日振替（\($0)曜日授業）" } ?? "曜日振替（要確認）"
        case .special: return needsReview ? "分類を要確認" : "行事（授業の有無は未判定）"
        }
    }

    static func fromExplicitText(_ title: String) -> Self {
        let lines = title.components(separatedBy: .newlines).map(PDFSchoolParser.key)
        // Exact declarations only. Do not turn exams, ceremonies or
        // comments merely mentioning a break into an inferred cancellation.
        func declares(_ names: [String]) -> Bool {
            let words = names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            return lines.contains { $0.range(of: "^(?:" + words + ")(?=$|[（(/／])", options: .regularExpression) != nil }
        }
        let holidays = ["元日", "成人の日", "建国記念の日", "天皇誕生日", "春分の日", "昭和の日", "憲法記念日",
                        "みどりの日", "こどもの日", "子どもの日", "海の日", "山の日", "敬老の日", "秋分の日",
                        "スポーツの日", "文化の日", "勤労感謝の日", "振替休日", "国民の休日"]
        // These labels classify text already present in the PDF. No holiday dates
        // are calculated, fetched, or inserted into a calendar by this code.
        let noClass = declares(["臨時休業", "夏季休業", "冬季休業", "学年末休業", "休業日"] + holidays)
        let supplementary = declares(["補講日"])
        let schoolEvents = ["体育祭", "体育大会", "春季体育大会", "夏季体育大会", "秋季体育大会", "冬季体育大会",
                            "文化祭", "総合文化祭", "電波祭"]
        let schoolEvent = declares(schoolEvents.flatMap { [$0, $0 + "準備", $0 + "準備日"] })
        let pattern = try! NSRegularExpression(pattern: "(?:^([月火水木金])曜日授業$|【([月火水木金])曜日授業】)")
        let days = ["月": 1, "火": 2, "水": 3, "木": 4, "金": 5]
        var overrides: [Int] = []
        for line in lines {
            let ns = line as NSString
            for match in pattern.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                let range = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
                if let day = days[ns.substring(with: range)] { overrides.append(day) }
            }
        }
        // A break and an approved school event agree that regular lessons are
        // absent. Keep the more specific school-event tag in that combination.
        let categories = [noClass || schoolEvent, supplementary, !overrides.isEmpty].filter { $0 }.count
        if overrides.count > 1 || categories > 1 { return Self(type: .special, needsReview: true) }
        if schoolEvent { return Self(type: .schoolEventNoClass) }
        if noClass { return Self(type: .noClass) }
        if supplementary { return Self(type: .supplementary) }
        if let day = overrides.first { return Self(type: .weekdayOverride, scheduleDay: day) }
        return Self(type: .special)
    }
}
struct PDFAnalysis: Codable {
    static let parserVersion = 6
    // Timetable fixes must not ask users to reparse an unchanged calendar.
    static func currentVersion(for kind: MaterialKind) -> Int { kind == .events ? 4 : parserVersion }
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
    // Fixed labels only: never include source text, filenames, URLs or personal data.
    enum Stage: String, Codable, CaseIterable {
        case characterMapping, pageRotation, yearHeading, documentHeading, periodHeading
        case gridColumn, gridRow, gridCell, eventColumns, calendarDates, monthHeading, vectorObjects, textOrder
        case classLabel, gradeLabel, duplicateClass, lessonLines, parallelLessons, emptySubject
        case fragmentOverlap, fragmentAlignment

        var label: String {
            switch self {
            case .characterMapping: return "文字と位置の対応（P01）"
            case .pageRotation: return "ページの向き（P02）"
            case .yearHeading: return "年度の見出し（P03）"
            case .documentHeading: return "資料名・学期・ページ数（P04）"
            case .periodHeading: return "時限の見出し（P05）"
            case .gridColumn: return "表の列の罫線（P06）"
            case .gridRow: return "日付の行の罫線（P07）"
            case .gridCell: return "表のセルの罫線（P08）"
            case .eventColumns: return "共通・高松・詫間の見出し（P09）"
            case .calendarDates: return "日付の列（P10）"
            case .monthHeading: return "月の見出し（P11）"
            case .vectorObjects: return "未対応の埋め込み描画（P12）"
            case .textOrder: return "文字の行と読み順（P13）"
            case .classLabel: return "クラス欄（P14）"
            case .gradeLabel: return "学年欄（P15）"
            case .duplicateClass: return "クラス行の重複（P16）"
            case .lessonLines: return "授業欄の行分け（P17）"
            case .parallelLessons: return "並記された授業の対応（P18）"
            case .emptySubject: return "並記された科目の空欄（P19）"
            case .fragmentOverlap: return "文字列断片の位置と読み順（P20）"
            case .fragmentAlignment: return "文字列断片が属する行（P21）"
            }
        }
    }
    var code: Code
    var page: Int? = nil
    var stage: Stage? = nil
    struct Cell: Codable, Equatable {
        var classRow: Int
        var weekday: Int
        var period: Int
        var detectedLines: Int? = nil
        var label: String {
            let days = [1: "月", 2: "火", 3: "水", 4: "木", 5: "金"]
            return "表の上から\(classRow)番目のクラス・\(days[weekday] ?? "?")曜\(period)限" +
                (detectedLines.map { "・検出\($0)行" } ?? "")
        }
    }
    var cell: Cell? = nil
    var geometry: PDFCellGeometryDiagnostic? = nil
    var diagnosticReport: String? {
        guard geometry != nil else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else { return nil }
        return "TAKUPOKE-PDF-GEOMETRY-1\n" + json
    }
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
        return (page.map { "\($0)ページ目：" } ?? "") + reason +
            (stage.map { "確認箇所：\($0.label)。" } ?? "") +
            (cell.map { "対象：\($0.label)。" } ?? "") + "前回の正常な解析結果は保持しています。"
    }
}

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
            throw PDFParseError(code: .unsupported, page: 1, stage: .yearHeading)
        }
        let year = 2018 + era
        for (index, page) in pages.enumerated() {
            let heading = key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 8 }).map { $0.map(\.text).joined() }.joined())
            guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
                  Int(heading[range].dropFirst(2).dropLast(2)) == era else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .yearHeading)
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
            result.notices = ["PDFの記載名を表示しています。正式名称の対応表はまだ取り込んでいません。",
                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更との統合はまだ行いません。"]
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

    private static func timetable(_ page: PDFPageLayout, check: () throws -> Void) throws -> [PDFLesson] {
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
