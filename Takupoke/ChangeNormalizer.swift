import Foundation

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

    static func parse(_ rows: [[String]], defaultYear: Int?, check: () throws -> Void = {}, allowEmptyPreview: Bool = false) throws -> [ScheduleChange] {
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
        guard !output.isEmpty || allowEmptyPreview else { throw ChangeParseError(code: .empty) }
        return output
    }
}
