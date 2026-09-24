import Foundation

// Ported from denpa-schedule-csv (MIT). See ThirdPartyNotices.txt.
struct ScheduleChange: Codable, Equatable {
    var change_date: String
    var class_name: String
    var period: String
    var before_subject: String
    var after_subject: String
    var teacher: String
    var room: String
    var note: String
    var raw_text: String
    var canonical_text: String

    // Old successful results remain on disk until an explicit reparse, but their
    // class picker, filtering and labels use the same identity as new results.
    var displayClassName: String { ChangeNormalizer.canonicalClassName(class_name) }

    var isCancellation: Bool {
        note.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines) == "休講"
    }

    var isMakeup: Bool {
        note.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines) == "補講"
    }

    var displayPeriod: String {
        let value = period.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "記載なし" }
        return value.range(of: "^[0-9]+$", options: .regularExpression) == nil ? period : "\(value)限"
    }

    /// A change remains one saved row even when it covers consecutive periods.
    /// Unsupported or nonconsecutive notation stays visible in the change list.
    var gridPeriods: [Int]? {
        let value = period.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "〜", with: "~")
            .filter { !$0.isWhitespace }
        let parts: [String]
        if value.contains(",") {
            parts = value.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        } else if value.contains("~") {
            let bounds = value.split(separator: "~", omittingEmptySubsequences: false)
            guard bounds.count == 2, let first = Int(bounds[0]), let last = Int(bounds[1]),
                  (1...8).contains(first), (1...8).contains(last), first < last else { return nil }
            return Array(first...last)
        } else {
            parts = [value]
        }
        let periods = parts.compactMap(Int.init)
        guard periods.count == parts.count, !periods.isEmpty,
              periods.allSatisfy({ (1...8).contains($0) }),
              zip(periods, periods.dropFirst()).allSatisfy({ $0.1 == $0.0 + 1 }) else { return nil }
        return periods
    }
}

struct ChangeAnalysis: Codable {
    static let parserVersion = 4
    var version = parserVersion
    var sourceDigest: String
    var sourceName: String
    var defaultYear: Int?
    var parsedAt: Date
    var records: [ScheduleChange]
}

struct ChangeParseAttempt: Codable {
    var date: Date
    var sourceDigest: String?
    var defaultYear: Int?
    var failure: ChangeParseError?
}

// Deliberately separate from the persisted, successful ChangeAnalysis.
struct ChangePreview {
    var sourceName: String
    var defaultYear: Int?
    var records: [ScheduleChange]
    var warnings: [ChangeParseError]
}

struct ChangeParseError: Error, Codable, LocalizedError, Equatable {
    enum Code: String, Codable {
        case invalidArchive, limit, invalidXML, missingSheet, unsupported, headers
        case date, year, classes, unknownAll, empty, cancelled, storage
        case formula, formulaCache, weekdayMismatch, mergedCells, dateSystem, cellType
    }
    var code: Code
    var row: Int? = nil
    var permitsPreview: Bool { code == .formulaCache || code == .weekdayMismatch }
    var errorDescription: String? {
        let detail: String
        switch code {
        case .invalidArchive: detail = "XLSXの構造を読み取れません。破損・暗号化されたファイルは解析できません。"
        case .limit: detail = "ファイルが解析可能なサイズ・行数・件数の上限を超えています。"
        case .invalidXML: detail = "XLSX内の表の構造が不正です。"
        case .missingSheet: detail = "「時間割変更」シートが見つからないか、重複しています。"
        case .unsupported: detail = "このXLSXには未対応の構造や外部参照が含まれています。"
        case .formula: detail = "見出し、または曜日以外の列に数式があります。この箇所の数式は解析できません。"
        case .formulaCache: detail = "曜日の計算結果が保存されていません。警告を確認して内容だけを見ることができます。"
        case .weekdayMismatch: detail = "曜日と月日が一致しないか、曜日の表記を確認できません。警告を確認して内容だけを見ることができます。"
        case .mergedCells: detail = "見出しや表の行に結合セルがあります。結合された値は推測して補えません。"
        case .dateSystem: detail = "1904年起点の日付を使用するXLSXは未対応です。"
        case .cellType: detail = "表に未対応のセル形式やExcelのエラー値があります。"
        case .headers: detail = "必要な見出し（学 年・学科・クラス・月日）がないか、見出しが重複しています。"
        case .date: detail = "日付を確定できません。年なし日付の場合は補完する年を指定してください。"
        case .year: detail = "学年の指定を読み取れません。"
        case .classes: detail = "クラスの指定を読み取れません。"
        case .unknownAll: detail = "「全」の対象クラスをファイル内の記載から確定できません。"
        case .empty: detail = "時間割変更の行がありません。空の結果では前回の解析結果を置き換えません。"
        case .cancelled: detail = "解析を中止しました。"
        case .storage: detail = "解析結果を保存できません。"
        }
        return (row.map { "\($0)行目：" } ?? "") + detail + " 前回の正常な解析結果は保持しています。"
    }
}

enum ChangeNormalizer {
    static let maximumRows = 10_000
    static let maximumColumns = 128
    static let maximumRecords = 20_000
    static let maximumTextBytes = 16 * 1024 * 1024
    static let schoolYearSettingKey = "changeDefaultSchoolYear"

    static func effectiveSchoolYear(configured: String?, today: SchoolDate) -> Int {
        let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let year = Int(value), (1900...9998).contains(year) { return year }
        return today.schoolYear
    }

    static func replace(_ text: String, _ pattern: String, _ replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
    static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
    static func text(_ value: String) -> String {
        let normalized = value.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return replace(replace(normalized, "[ \\t\\f\\x0B]+", " "), "\\n+", "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func token(_ value: String) -> String {
        text(value).replacingOccurrences(of: " ", with: "").uppercased()
    }
    static func number(_ value: String) -> String {
        let v = text(value)
        return matches(v, "^-?[0-9]+\\.0+$") ? String(v.split(separator: ".")[0]) : v
    }
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    static func serialDate(_ value: String) throws -> String {
        guard matches(value, "^[0-9]+(\\.[0-9]+)?$") else { return value }
        guard let days = Double(value), days > 0, days < 2_958_466 else {
            throw ChangeParseError(code: .date)
        }
        let base = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        let date = base.addingTimeInterval(days * 86_400)
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)/\(c.month!)/\(c.day!)"
    }
    static func date(_ value: String, defaultYear: Int?) throws -> String {
        var v = try serialDate(text(value))
        for separator in ["年", "月", ".", "-"] { v = v.replacingOccurrences(of: separator, with: "/") }
        v = replace(v.replacingOccurrences(of: "日", with: ""), "\\s+", "")
        let parts: [Int]
        if matches(v, "^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$") {
            parts = v.split(separator: "/").compactMap { Int($0) }
        } else if matches(v, "^[0-9]{1,2}/[0-9]{1,2}$"), let year = defaultYear {
            let monthDay = v.split(separator: "/").compactMap { Int($0) }
            guard monthDay.count == 2 else { throw ChangeParseError(code: .date) }
            parts = [monthDay[0] <= 3 ? year + 1 : year] + monthDay
        } else { throw ChangeParseError(code: .date) }
        guard parts.count == 3, (1900...9999).contains(parts[0]),
              (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              let d = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            throw ChangeParseError(code: .date)
        }
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        guard c.year == parts[0], c.month == parts[1], c.day == parts[2] else { throw ChangeParseError(code: .date) }
        return String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
    }
    static func weekdayMatches(_ value: String, normalizedDate: String) -> Bool {
        let parts = normalizedDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return false }
        let weekday = ["日", "月", "火", "水", "木", "金", "土"][calendar.component(.weekday, from: date) - 1]
        return [weekday, weekday + "曜", weekday + "曜日", "(" + weekday + ")"].contains(text(value))
    }

    static func years(_ value: String) throws -> [String] {
        let v = text(value)
        // The source format also uses AI in the grade column. Keep that
        // literal identifier, as the reference does; do not swap the columns.
        if token(v) == "AI" { return ["AI"] }
        if matches(v, "^[0-9]+\\s*[～〜~-]\\s*[0-9]+$") {
            let ends = replace(v, "\\s*[～〜~-]\\s*", ",").split(separator: ",").compactMap { Int($0) }
            guard ends.count == 2, ends.allSatisfy({ (1...9).contains($0) }) else { throw ChangeParseError(code: .year) }
            return stride(from: ends[0], through: ends[1], by: ends[0] <= ends[1] ? 1 : -1).map(String.init)
        }
        guard let year = Int(token(v)), (1...9).contains(year), matches(token(v), "^[0-9]+$") else {
            throw ChangeParseError(code: .year)
        }
        return [token(v)]
    }
    static func classes(_ value: String) throws -> [String] {
        if token(value) == "全" { return [] }
        let parts = replace(text(value), "[,，、]", ",").split(separator: ",").map { token(String($0)) }.filter { !$0.isEmpty }
        guard !parts.isEmpty, parts.allSatisfy({ matches($0, "^[A-Z0-9]{1,12}$") }) else {
            throw ChangeParseError(code: .classes)
        }
        return parts
    }

    static func canonicalClassName(_ identifier: String) -> String {
        let parts = identifier.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1] == "AI", matches(String(parts[0]), "^[0-9]+$"),
              let year = Int(parts[0]), (1...9).contains(year) else { return identifier }
        // User-confirmed aliases: 1_AI and AI_1 name the same class.
        return "AI_\(parts[0])"
    }
    static func headerIndex(_ rows: [[String]]) throws -> Int {
        guard let index = rows.firstIndex(where: { row in
            let cells = row.map(text)
            return ["学 年", "学科・クラス", "月日"].allSatisfy(cells.contains)
        }) else { throw ChangeParseError(code: .headers) }
        return index
    }

    static func parse(_ rows: [[String]], defaultYear: Int?, check: () throws -> Void = {}) throws -> [ScheduleChange] {
        guard rows.count <= maximumRows, rows.allSatisfy({ $0.count <= maximumColumns }),
              rows.flatMap({ $0 }).allSatisfy({ $0.utf8.count <= 4096 }) else { throw ChangeParseError(code: .limit) }
        guard rows.reduce(0, { total, row in total + row.reduce(0, { $0 + $1.utf8.count }) }) <= maximumTextBytes else {
            throw ChangeParseError(code: .limit)
        }
        if let year = defaultYear, !(1900...9999).contains(year) { throw ChangeParseError(code: .date) }
        let index = try headerIndex(rows)
        let headers = rows[index].map { text($0) == "時限" ? $0 : text($0) }
        let nonempty = headers.filter { !$0.isEmpty }
        guard Set(nonempty).count == nonempty.count else { throw ChangeParseError(code: .headers, row: index + 1) }
        let dateIndex = headers.firstIndex(of: "月日")!
        let yearIndex = headers.firstIndex(of: "学 年")!
        let classIndex = headers.firstIndex(of: "学科・クラス")!
        var table: [(row: Int, cells: [String], years: [String], classes: [String])] = []
        var known: [String: Set<String>] = [:]
        for i in (index + 1)..<rows.count {
            try check()
            // Do not silently truncate nonempty cells beyond the header.
            guard rows[i].dropFirst(headers.count).allSatisfy({ text($0).isEmpty }) else {
                throw ChangeParseError(code: .headers, row: i + 1)
            }
            var cells = Array(rows[i].prefix(headers.count)).map(number)
            cells += Array(repeating: "", count: headers.count - cells.count)
            if cells.allSatisfy(\.isEmpty) { continue }
            do {
                cells[dateIndex] = try serialDate(cells[dateIndex])
                let ys = try years(cells[yearIndex]), cs = try classes(cells[classIndex])
                for y in ys { known[y, default: []].formUnion(cs) }
                table.append((i + 1, cells, ys, cs))
            } catch var error as ChangeParseError { error.row = i + 1; throw error }
        }
        var output: [ScheduleChange] = []
        var textBytes = 0
        for item in table {
            try check()
            func value(_ aliases: [String]) -> String {
                let keys = Set(aliases.map(token))
                return headers.firstIndex(where: { keys.contains(token($0)) }).map { item.cells[$0] } ?? ""
            }
            let normalizedDate: String
            do { normalizedDate = try date(item.cells[dateIndex], defaultYear: defaultYear) }
            catch var error as ChangeParseError { error.row = item.row; throw error }
            let period = number(replace(value(["時限", "校時", "時間", "限"]), "(時限|限目|限)$", ""))
            var before = value(["変更前", "変更前科目", "変更前 科目", "旧科目", "変更元"])
            var after = value(["変更後", "変更後科目", "変更後 科目", "新科目", "変更先"])
            let teacher = value(["教員", "担当", "担当教員", "担任", "教官"])
            let room = value(["教室", "場所"])
            var note = value(["備考", "連絡", "メモ", "その他"])
            let content = value(["変更内容", "変更種別", "種別"])
            let subject = value(["科目(担当教員)", "科目（担当教員）", "科目・担当教員", "科目"])
            if note.isEmpty { note = content }
            if before.isEmpty && after.isEmpty && !subject.isEmpty {
                if token(content) == "休講" { before = subject } else { after = subject }
            }
            let raw = zip(headers, item.cells).filter { !$0.1.isEmpty }.map { "\($0.0):\($0.1)" }.joined(separator: " | ")
            for year in item.years {
                let cs = token(item.cells[classIndex]) == "全" ? (known[year] ?? []).filter { $0 != "AI" }.sorted() : item.classes
                guard !cs.isEmpty else { throw ChangeParseError(code: .unknownAll, row: item.row) }
                for cls in cs {
                    let name = canonicalClassName("\(year)_\(cls)")
                    let fields = [normalizedDate, name, period, before, after, teacher, room, note, raw]
                    let canonical = fields.map(text).filter { !$0.isEmpty }.joined(separator: " | ")
                    textBytes += fields.reduce(0) { $0 + $1.utf8.count } + canonical.utf8.count
                    guard output.count < maximumRecords, textBytes <= maximumTextBytes else { throw ChangeParseError(code: .limit) }
                    output.append(ScheduleChange(change_date: normalizedDate, class_name: name, period: period,
                        before_subject: before, after_subject: after, teacher: teacher, room: room,
                        note: note, raw_text: raw, canonical_text: canonical))
                }
            }
        }
        guard !output.isEmpty else { throw ChangeParseError(code: .empty) }
        return output
    }
}
