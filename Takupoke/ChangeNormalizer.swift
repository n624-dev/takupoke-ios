import Foundation

enum ChangeNormalizer {
    static let maximumRows = 10_000
    static let maximumColumns = 128
    static let maximumRecords = 20_000
    static let maximumTextBytes = 16 * 1024 * 1024
    static let schoolYearSettingKey = "changeDefaultSchoolYear"

    static func effectiveSchoolYear(configured: String?, today: SchoolDate) -> Int? {
        let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return today.schoolYear }
        guard value.allSatisfy({ $0.isASCII && $0.isNumber }), let year = Int(value), (1900...9998).contains(year) else { return nil }
        return year
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
        if v.contains(",") || v.contains("、") {
            let fields = v.replacingOccurrences(of: "、", with: ",").components(separatedBy: ",").map(text)
            guard fields.allSatisfy({ matches($0, "^[1-9]$") }), Set(fields).count == fields.count else {
                throw ChangeParseError(code: .year)
            }
            return fields
        }
        guard let year = Int(token(v)), (1...9).contains(year), matches(token(v), "^[0-9]+$") else {
            throw ChangeParseError(code: .year)
        }
        return [String(year)]
    }
    static func classes(_ value: String) throws -> [String] {
        if token(value) == "全" { return [] }
        let parts = text(value).components(separatedBy: CharacterSet(charactersIn: ",，、・･•·")).map(token)
        guard !parts.isEmpty, parts.allSatisfy({ matches($0, "^[A-Z0-9]{1,12}$") }) else {
            throw ChangeParseError(code: .classes)
        }
        var seen = Set<String>()
        return parts.filter { seen.insert($0).inserted }
    }

    static func canonicalClassName(_ identifier: String) -> String {
        let parts = identifier.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1] == "AI", matches(String(parts[0]), "^[0-9]+$"),
              let year = Int(parts[0]), (1...9).contains(year) else { return identifier }
        // User-confirmed aliases: 1_AI and AI_1 name the same class.
        return "AI_\(parts[0])"
    }
    enum OptionalColumn: String, CaseIterable {
        case period = "時限", kind = "変更種別", before = "変更前", after = "変更後"
        case teacher = "教員", room = "教室", note = "備考", subject = "科目"
        case reason = "変更理由", updated = "更新日時"

        var aliases: [String] {
            switch self {
            case .period: return [rawValue, "校時", "時間", "限"]
            case .kind: return [rawValue, "変更内容", "種別"]
            case .before: return [rawValue, "変更前科目", "旧科目", "変更元"]
            case .after: return [rawValue, "変更後科目", "新科目", "変更先"]
            case .teacher: return [rawValue, "担当", "担当教員", "担任", "教官"]
            case .room: return [rawValue, "場所"]
            case .reason: return [rawValue, "理由"]
            case .updated: return [rawValue, "最終更新日時"]
            case .note: return [rawValue, "連絡", "メモ", "その他"]
            case .subject: return [rawValue, "科目(担当教員)", "科目・担当教員"]
            }
        }

        func index(in headerTokens: [String]) -> Int? {
            headerTokens.firstIndex(where: aliases.contains)
        }
    }

    static func headerIndex(_ rows: [[String]]) throws -> Int {
        guard let index = rows.firstIndex(where: { row in
            let cells = row.map(text)
            return ["学 年", "学科・クラス", "月日"].allSatisfy(cells.contains)
        }) else { throw ChangeParseError(code: .headers) }
        return index
    }

    static func parse(_ rows: [[String]], defaultYear: Int?, check: () throws -> Void = {}, allowEmptyPreview: Bool = false, sourceRows: [[String]]? = nil, sourceHeaders: [String]? = nil, workbook: ChangeEditTable? = nil, edits: [Int: ChangeRowEdit] = [:]) throws -> [ScheduleChange] {
        guard rows.count <= maximumRows, rows.allSatisfy({ $0.count <= maximumColumns }),
              rows.flatMap({ $0 }).allSatisfy({ $0.utf8.count <= 4096 }) else { throw ChangeParseError(code: .limit) }
        guard rows.reduce(0, { total, row in total + row.reduce(0, { $0 + $1.utf8.count }) }) <= maximumTextBytes else {
            throw ChangeParseError(code: .limit)
        }
        if let year = defaultYear, !(1900...9998).contains(year) { throw ChangeParseError(code: .defaultYear) }
        let index = try headerIndex(rows)
        let headers = rows[index].map { text($0) == "時限" ? $0 : text($0) }
        let nonempty = headers.filter { !$0.isEmpty }
        guard Set(nonempty).count == nonempty.count else { throw ChangeParseError(code: .headers, row: index + 1) }
        let dateIndex = headers.firstIndex(of: "月日")!
        let yearIndex = headers.firstIndex(of: "学 年")!
        let classIndex = headers.firstIndex(of: "学科・クラス")!
        let headerTokens = headers.map(token)
        let columns = Dictionary(uniqueKeysWithValues: OptionalColumn.allCases.compactMap { field in
            field.index(in: headerTokens).map { (field, $0) }
        })
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
            func value(_ field: OptionalColumn) -> String {
                columns[field].map { item.cells[$0] } ?? ""
            }
            let normalizedDate: String
            do { normalizedDate = try date(item.cells[dateIndex], defaultYear: defaultYear) }
            catch var error as ChangeParseError { error.row = item.row; throw error }
            let period = number(replace(value(.period), "(時限|限目|限)$", ""))
            var before = value(.before)
            var after = value(.after)
            let teacher = value(.teacher)
            let room = value(.room)
            var note = value(.note)
            let content = value(.kind)
            let subject = value(.subject)
            if note.isEmpty { note = content }
            if before.isEmpty && after.isEmpty && !subject.isEmpty {
                if token(content) == "休講" { before = subject } else { after = subject }
            }
            let rawCells = sourceRows.flatMap { $0.indices.contains(item.row - 1) ? $0[item.row - 1] : nil } ?? item.cells
            let labels = sourceHeaders ?? headers
            let raw = rawCells.enumerated().compactMap { column, value -> String? in
                guard !value.isEmpty else { return nil }
                let title = labels.indices.contains(column) && !labels[column].isEmpty ? labels[column] : "列\(column + 1)"
                return "\(title):\(value)"
            }.joined(separator: " | ")
            let edit = edits[item.row] ?? ChangeRowEdit()
            let originalDate: String?
            if let workbook, let year = defaultYear {
                originalDate = workbook.displayCell(row: item.row, column: dateIndex, year: year)
            } else {
                originalDate = readableDate(item.cells[dateIndex], defaultYear: defaultYear)
            }
            let readable = rawCells.enumerated().compactMap { column, value -> String? in
                guard !value.isEmpty else { return nil }
                let label = labels.indices.contains(column) && !labels[column].isEmpty ? labels[column] : "列\(column + 1)"
                return label + ":" + (column == dateIndex ? originalDate ?? "月日を確認" : value)
            }.joined(separator: " | ")
            let dedicated = value(.reason)
            let reasonInfo = ChangeNormalizer.reason(dedicated: dedicated, note: value(.note))
            let updated = columns[.updated].flatMap { column -> ChangeTimestamp? in
                if let workbook {
                    return workbook.timestamp(row: item.row, column: column, edit: edit)
                }
                return ChangeTimestamp.parse(value(.updated))
            }
            let reasonColumn = dedicated.isEmpty ? columns[.note] : columns[.reason]
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
                        note: note, raw_text: raw, canonical_text: canonical, change_kind: content,
                        readableOriginal: workbook != nil || readable != raw ? readable : nil,
                        sourceRow: workbook == nil ? nil : item.row,
                        reasonSource: reasonInfo.reason == nil ? nil : reasonColumn.map { headers[$0] },
                        reason: reasonInfo.reason, remainingNote: reasonInfo.remaining,
                        updated: updated, personallyEdited: edit.isEmpty ? nil : true,
                        personalReason: reasonColumn.flatMap { edit.values[$0] } == nil ? nil : true,
                        personalUpdate: columns[.updated].flatMap { edit.values[$0] } == nil ? nil : true))
                }
            }
        }
        guard !output.isEmpty || allowEmptyPreview else { throw ChangeParseError(code: .empty) }
        return output
    }
}

extension ChangeEditTable {
    private var weekdayColumn: Int? { headers.firstIndex { ["曜日", "曜"].contains(ChangeNormalizer.token($0)) } }

    func values(at row: Int, edit: ChangeRowEdit = ChangeRowEdit(), defaultYear: Int) -> [String] {
        guard row > 0, rows.indices.contains(row - 1) else { return [] }
        var values = rows[row - 1]
        if values.count < headers.count { values += Array(repeating: "", count: headers.count - values.count) }
        for (column, value) in edit.values where headers.indices.contains(column) { values[column] = value }
        if edit.deriveWeekday, let column = weekdayColumn, let day = derivedWeekday(values, row: row, edit: edit, defaultYear: defaultYear) {
            values[column] = day
        }
        return values
    }

    /// Interpret the original date system after column mapping. The editor and the saved
    /// row identity retain the literal spreadsheet values, including serials and ISO times.
    private func dateValue(_ value: String, row: Int, column: Int, edit: ChangeRowEdit) -> String {
        if dateCells[row]?.contains(column) == true,
           edit.values[column] == nil || edit.values[column] == rows[row - 1][column] {
            return String(value.prefix(10))
        }
        let number = ChangeNormalizer.text(value)
        if uses1904,
           ChangeNormalizer.matches(number, "^[0-9]+(?:\\.[0-9]+)?$"), let serial = Double(number) {
            return String(serial + 1462)
        }
        return value
    }

    func normalizedDate(_ values: [String], row: Int, edit: ChangeRowEdit, defaultYear: Int) -> String? {
        guard let column = headers.firstIndex(where: { ChangeNormalizer.text($0) == "月日" }),
              values.indices.contains(column), cellIssues[row]?[column] == nil || edit.values[column] != nil else { return nil }
        return try? ChangeNormalizer.date(dateValue(values[column], row: row, column: column, edit: edit), defaultYear: defaultYear)
    }

    private func derivedWeekday(_ values: [String], row: Int, edit: ChangeRowEdit, defaultYear: Int) -> String? {
        normalizedDate(values, row: row, edit: edit, defaultYear: defaultYear).flatMap(ChangeNormalizer.weekday)
    }

    func suggestedEdits(defaultYear: Int, check: () throws -> Void = {}) throws -> [Int: ChangeRowEdit] {
        guard let column = weekdayColumn else { return [:] }
        var edits: [Int: ChangeRowEdit] = [:]
        for number in rowIDs {
            try check()
            let values = values(at: number, defaultYear: defaultYear)
            guard let date = normalizedDate(values, row: number, edit: ChangeRowEdit(), defaultYear: defaultYear),
                  canDeriveWeekday(row: number, column: column),
                  !ChangeNormalizer.weekdayMatches(values[column], normalizedDate: date) else { continue }
            edits[number] = ChangeRowEdit(deriveWeekday: true)
        }
        return edits
    }

    private func canDeriveWeekday(row: Int, column: Int) -> Bool {
        guard let code = cellIssues[row]?[column] else { return true }
        return [.formula, .formulaCache, .weekdayMismatch].contains(code)
    }

    private func weekdayOnly(_ values: [String], row: Int, column: Int) -> Bool {
        let issue = cellIssues[row]?[column]
        return (issue.map { [.formula, .formulaCache, .weekdayOnly].contains($0) } ?? true)
            && (!ChangeNormalizer.text(values[column]).isEmpty || issue != nil)
            && rows[row - 1].enumerated().allSatisfy { $0.offset == column || ChangeNormalizer.text($0.element).isEmpty }
            && values.enumerated().allSatisfy { $0.offset == column || ChangeNormalizer.text($0.element).isEmpty }
            && cellIssues[row, default: [:]].keys.allSatisfy { $0 == column }
            && cellSources[row, default: [:]].keys.allSatisfy { $0 == column }
    }

    func isOriginalWeekdayOnly(_ row: Int, defaultYear: Int) -> Bool {
        guard let column = weekdayColumn else { return false }
        let original = values(at: row, defaultYear: defaultYear)
        return original.indices.contains(column) && weekdayOnly(original, row: row, column: column)
    }

    func legacyEdits(weekday: Bool, excluded: Set<Int>, defaultYear: Int,
                     check: () throws -> Void = {}) throws -> [Int: ChangeRowEdit] {
        var edits: [Int: ChangeRowEdit] = [:]
        let suggestions = weekday ? try suggestedEdits(defaultYear: defaultYear, check: check) : [:]
        if let column = weekdayColumn {
            for (number, suggestion) in suggestions {
                try check()
                let values = values(at: number, defaultYear: defaultYear)
                let issue = cellIssues[number]?[column]
                if ChangeNormalizer.knownWeekday(values[column]), issue == nil || issue == .weekdayMismatch || issue == .formula {
                    edits[number] = suggestion
                }
            }
        }
        for number in rowIDs where excluded.contains(number) {
            try check()
            edits[number, default: ChangeRowEdit()].excluded = true
        }
        return edits
    }

    /// Return all correctable issues together, including several missing values on one row.
    /// Header/limit failures prevent a reliable row interpretation and are reported separately.
    func review(edits: [Int: ChangeRowEdit], defaultYear: Int, check: () throws -> Void = {}) throws -> [Int: [ChangeParseError]] {
        guard (1900...9998).contains(defaultYear) else { throw ChangeParseError(code: .defaultYear) }
        guard rows.count <= ChangeNormalizer.maximumRows, headers.count <= ChangeNormalizer.maximumColumns,
              rows.allSatisfy({ $0.count <= ChangeNormalizer.maximumColumns }) else { throw ChangeParseError(code: .limit) }
        let names = headers.map(ChangeNormalizer.text)
        let named = names.filter { !$0.isEmpty }
        guard headerRow > 0, headerRow <= rows.count, Set(named).count == named.count,
              named.filter({ ["曜日", "曜"].contains(ChangeNormalizer.token($0)) }).count <= 1,
              let date = names.firstIndex(of: "月日"), let grade = names.firstIndex(of: "学 年"),
              let classroom = names.firstIndex(of: "学科・クラス") else { throw ChangeParseError(code: .headers) }
        let ids = rowIDs
        guard Set(edits.keys).isSubset(of: Set(ids)) else { throw ChangeParseError(code: .staleConfirmation) }
        let weekday = weekdayColumn
        var issues: [Int: [ChangeParseError]] = [:], explicit: [String: Set<String>] = [:]
        var allRows: [(row: Int, years: [String])] = []
        for number in ids {
            try check()
            let edit = edits[number] ?? ChangeRowEdit()
            guard edit.values.keys.allSatisfy({ headers.indices.contains($0) }) else { throw ChangeParseError(code: .staleConfirmation) }
            guard edit.values.values.allSatisfy({ $0.utf8.count <= 4096 }) else { throw ChangeParseError(code: .limit) }
            if edit.excluded { continue }
            let v = values(at: number, edit: edit, defaultYear: defaultYear)
            func report(_ code: ChangeParseError.Code, _ column: Int, printed: String? = nil, calculated: String? = nil) {
                guard issues[number]?.contains(where: { $0.column == column }) != true else { return }
                issues[number, default: []].append(ChangeParseError(code: code, row: number, printedWeekday: printed,
                                                                    calculatedWeekday: calculated, column: column))
            }
            if let weekday, weekdayOnly(v, row: number, column: weekday) {
                issues[number] = [ChangeParseError(code: .weekdayOnly, row: number, printedWeekday: v[weekday], column: weekday)]
                continue
            }
            let normalizedDate = self.normalizedDate(v, row: number, edit: edit, defaultYear: defaultYear)
            for (column, code) in (cellIssues[number] ?? [:]).sorted(by: { $0.key < $1.key }) {
                // The printed weekday/date relationship is recomputed below after any date edit.
                if code == .weekdayMismatch || code == .weekdayOnly { continue }
                if headers.indices.contains(column), ChangeNormalizer.OptionalColumn.updated.aliases.contains(ChangeNormalizer.token(headers[column])),
                   [.date, .cellType, .formula, .formulaCache].contains(code) { continue }
                let matchingCachedWeekday = code == .formula && normalizedDate.map {
                    v.indices.contains(column) && ChangeNormalizer.weekdayMatches(v[column], normalizedDate: $0)
                } == true
                let resolvedWeekday = column == weekday && (matchingCachedWeekday || (edit.deriveWeekday && normalizedDate != nil && canDeriveWeekday(row: number, column: column)))
                if edit.values[column] == nil && !resolvedWeekday {
                    if column == weekday && (code == .formula || code == .formulaCache) {
                        if ChangeNormalizer.text(v[column]).isEmpty {
                            report(.formulaCache, column, calculated: normalizedDate.flatMap(ChangeNormalizer.weekday))
                        } else if let normalizedDate {
                            report(.weekdayMismatch, column, printed: v[column], calculated: ChangeNormalizer.weekday(normalizedDate))
                        }
                    } else { report(code, column) }
                }
            }
            if normalizedDate == nil && (issues[number]?.contains { $0.column == date } != true) { report(.date, date) }
            if let weekday, let normalizedDate,
               !ChangeNormalizer.text(v[weekday]).isEmpty,
               issues[number]?.contains(where: { $0.column == weekday }) != true,
               !ChangeNormalizer.weekdayMatches(v[weekday], normalizedDate: normalizedDate) {
                report(.weekdayMismatch, weekday, printed: v[weekday], calculated: ChangeNormalizer.weekday(normalizedDate))
            }
            let years = try? ChangeNormalizer.years(ChangeNormalizer.number(v[grade]))
            let classes = try? ChangeNormalizer.classes(ChangeNormalizer.number(v[classroom]))
            if years == nil { report(.year, grade) }
            if classes == nil { report(.classes, classroom) }
            if let years, let classes {
                if ChangeNormalizer.token(v[classroom]) == "全" { allRows.append((number, years)) }
                else { for year in years { explicit[year, default: []].formUnion(classes.filter { $0 != "AI" }) } }
            }
            if let outside = v.indices.first(where: { $0 >= headers.count && !ChangeNormalizer.text(v[$0]).isEmpty }) {
                report(.headers, outside)
            }
        }
        for item in allRows where item.years.contains(where: { explicit[$0]?.isEmpty != false }) {
            issues[item.row, default: []].append(ChangeParseError(code: .unknownAll, row: item.row, column: classroom))
        }
        return issues
    }

    func records(edits: [Int: ChangeRowEdit], defaultYear: Int, check: () throws -> Void = {}) throws -> [ScheduleChange] {
        let issues = try review(edits: edits, defaultYear: defaultYear, check: check)
        if let number = issues.keys.min(), let issue = issues[number]?.first { throw issue }
        return try recordsAfterReview(edits: edits, defaultYear: defaultYear, check: check)
    }

    fileprivate func recordsAfterReview(edits: [Int: ChangeRowEdit], defaultYear: Int,
                                        check: () throws -> Void) throws -> [ScheduleChange] {
        var table = Array(repeating: [String](), count: rows.count)
        table[headerRow - 1] = headers
        guard let date = headers.firstIndex(where: { ChangeNormalizer.text($0) == "月日" }) else { throw ChangeParseError(code: .headers) }
        for row in rowIDs {
            try check()
            let edit = edits[row] ?? ChangeRowEdit()
            if !edit.excluded {
                var effective = values(at: row, edit: edit, defaultYear: defaultYear)
                effective[date] = dateValue(effective[date], row: row, column: date, edit: edit)
                table[row - 1] = effective
            }
        }
        return try ChangeNormalizer.parse(table, defaultYear: defaultYear, check: check,
                                          sourceRows: rows, sourceHeaders: originalHeaders ?? headers, workbook: self, edits: edits)
    }
}

struct ChangeWorkbookVerification {
    var issues: [Int: [ChangeParseError]] = [:]
    var groups: [ChangeIssueGroup] = []
    var suggestions: ChangeIssueGroup?
    var savedGroups: [ChangeIssueGroup] = []
    var viable = false
    var error: String?

    static func evaluate(_ view: ChangeWorkbookReview, edits: [Int: ChangeRowEdit], year: Int,
                         check: () throws -> Void) throws -> Self {
        try check()
        var result = Self(savedGroups: ChangeIssueGroup.savedGroups(edits))
        let table = view.table
        do {
            result.issues = try table.review(edits: edits, defaultYear: year, check: check)
            result.groups = ChangeIssueGroup.groups(result.issues, table: table, edits: edits,
                                                    conflicts: view.conflicts, previous: view.previous)
            if let weekday = table.headers.firstIndex(where: { ["曜日", "曜"].contains(ChangeNormalizer.token($0)) }) {
                let rows = try table.rowIDs.filter { row in
                    try check()
                    let edit = edits[row] ?? ChangeRowEdit()
                    guard !edit.excluded, !edit.deriveWeekday, edit.keepPrintedWeekday != true,
                          table.cellIssues[row]?[weekday] == nil, !view.conflicts.contains(row) else { return false }
                    let values = table.values(at: row, edit: edit, defaultYear: year)
                    return ChangeNormalizer.text(values[weekday]).isEmpty &&
                        table.normalizedDate(values, row: row, edit: edit, defaultYear: year) != nil
                }
                if !rows.isEmpty {
                    result.suggestions = ChangeIssueGroup(code: .weekdayMismatch, column: weekday, rows: rows, optional: true)
                }
            }
            result.viable = result.issues.isEmpty && view.conflicts.isEmpty
            if result.viable && !view.requiresLayoutConfirmation {
                // The same frozen input already passed review. Check only the final model here.
                _ = try table.recordsAfterReview(edits: edits, defaultYear: year, check: check)
            }
        } catch {
            try check()
            return .init(savedGroups: result.savedGroups, error: error.localizedDescription)
        }
        try check()
        return result
    }
}

extension ChangeEditTable {
    func displayCell(row: Int, column: Int, edit: ChangeRowEdit = ChangeRowEdit(), year: Int) -> String {
        let rowValues = values(at: row, edit: edit, defaultYear: year)
        guard rowValues.indices.contains(column) else { return "" }
        guard ChangeNormalizer.text(headers[column]) == "月日" else { return rowValues[column] }
        guard let date = normalizedDate(rowValues, row: row, edit: edit, defaultYear: year) else { return "月日を確認" }
        return ChangeNormalizer.readableDate(date, defaultYear: year) ?? "月日を確認"
    }

    func timestamp(row: Int, column: Int, edit: ChangeRowEdit) -> ChangeTimestamp? {
        if let value = edit.values[column] { return ChangeTimestamp.parse(value) }
        guard cellIssues[row]?[column] == nil, rows[row - 1].indices.contains(column) else { return nil }
        let value = rows[row - 1][column]
        if numericCells[row]?.contains(column) == true {
            guard let clock = formattedDates[row]?[column] else { return nil }
            return ChangeTimestamp.serial(value, uses1904: uses1904, clock: clock)
        }
        return ChangeTimestamp.parse(value)
    }

    func weekdayComparison(row: Int, edit: ChangeRowEdit, year: Int) -> String? {
        let values = values(at: row, edit: edit, defaultYear: year)
        guard let column = weekdayColumn, let day = derivedWeekday(values, row: row, edit: edit, defaultYear: year) else { return nil }
        let original = rows[row - 1]
        let printed = original.indices.contains(column) ? original[column] : ""
        return "原本の曜日 " + (printed.isEmpty ? "空欄" : printed) + " → 補完後 " + day
    }

    func summary(row: Int, edit: ChangeRowEdit, year: Int) -> String {
        let values = values(at: row, edit: edit, defaultYear: year)
        return headers.indices.compactMap { column -> String? in
            let value = values[column]
            let label = ChangeNormalizer.token(headers[column]) == "学年" ? "学年" : headers[column]
            if ChangeNormalizer.text(label) == "月日" { return label + " " + displayCell(row: row, column: column, edit: edit, year: year) }
            if value.isEmpty {
                return ["学年", "学科・クラス", "月日"].contains(label) ? label + " 空欄" : nil
            }
            return label + " " + value
        }.joined(separator: "　")
    }
}
