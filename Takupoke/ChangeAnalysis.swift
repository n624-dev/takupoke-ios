import Foundation

// Ported from denpa-schedule-csv (MIT). See LicenseDocuments/denpa-schedule-csv.txt.
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
    var change_kind: String? = nil

    var readableOriginal: String? = nil
    var reason: String? = nil
    var remainingNote: String? = nil
    var updated: ChangeTimestamp? = nil
    var personallyEdited: Bool? = nil
    var personalReason: Bool? = nil
    var personalUpdate: Bool? = nil

    var originalForDisplay: String {
        if let readableOriginal { return readableOriginal }
        // Older rows only retained a labeled string. Limit conversion to the date field.
        return raw_text.components(separatedBy: " | ").map { field in
            guard field.hasPrefix("月日:") else { return field }
            let value = String(field.dropFirst(3))
            let year = SchoolDate(iso8601: change_date)?.schoolYear
            let displayed = ChangeNormalizer.readableDate(value, defaultYear: year)
            if ChangeNormalizer.readableDate(value, defaultYear: year, uses1904: true) ==
                ChangeNormalizer.readableDate(change_date, defaultYear: year) {
                return "月日:" + (ChangeNormalizer.readableDate(change_date, defaultYear: year) ?? "月日を確認")
            }
            return "月日:" + (displayed ?? "月日を確認")
        }.joined(separator: " | ")
    }

    // Old successful results remain on disk until an explicit reparse, but their
    // class picker, filtering and labels use the same identity as new results.
    var displayClassName: String { ChangeNormalizer.canonicalClassName(class_name) }

    var isCancellation: Bool {
        (change_kind ?? note).precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines) == "休講"
    }

    var isMakeup: Bool {
        (change_kind ?? note).precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines) == "補講"
    }

    var cardKindLabel: String {
        isCancellation ? "休講" : (isMakeup ? "補講" : "変更")
    }

    var displayPeriod: String {
        let value = period.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "記載なし" }
        return value.range(of: "^[0-9]+$", options: .regularExpression) == nil ? period : "\(value)限"
    }

    /// A change remains one saved row even when it covers consecutive periods.
    /// Unsupported or nonconsecutive notation stays visible in the change list.
    var gridPeriods: [Int]? {
        guard let periods = detailPeriods,
              zip(periods, periods.dropFirst()).allSatisfy({ $0.1 == $0.0 + 1 }) else { return nil }
        return periods
    }

    /// Detailed clock ranges may be disjoint; grid merging still requires adjacency.
    var detailPeriods: [Int]? {
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
              Set(periods).count == periods.count else { return nil }
        return periods
    }
}

struct ChangeWeekdayConsent: Codable, Equatable {
    var digest: String
    var defaultYear: Int?
    var parserVersion: Int
    func matches(digest: String, defaultYear: Int?) -> Bool {
        self.digest == digest && self.defaultYear == defaultYear && parserVersion == ChangeAnalysis.parserVersion
    }
}

struct ChangeAnalysis: Codable {
    static let parserVersion = 13
    var sourceModifiedAt: Date? = nil
    var personalEdit: Bool? = nil
    var personalSourceIdentity: String? = nil
    var version = parserVersion
    var sourceDigest: String
    var sourceName: String
    var defaultYear: Int?
    var parsedAt: Date
    var records: [ScheduleChange]
    var weekdayConsent: ChangeWeekdayConsent? = nil
    var rowSkipConsent: ChangeRowSkipConsent? = nil

    func matches(record: MaterialRecord, defaultYear: Int?) -> Bool {
        guard let defaultYear else { return false }
        return personalSourceIdentity == record.personalChangeIdentity(for: defaultYear) &&
        sourceDigest == record.digest && version == Self.parserVersion &&
        self.defaultYear == defaultYear && weekdayConsent == record.source.weekdayConsent &&
        rowSkipConsent == record.source.rowSkipConsent
    }
}

extension MaterialRecord {
    func personalChangeIdentity(for year: Int?) -> String? {
        guard let year, source.personalChanges?.year == year else { return nil }
        return source.selectionID ?? storedName
    }
}

struct ChangeRowSkipConsent: Codable, Equatable {
    var sourceIdentity: String
    var digest: String
    var defaultYear: Int?
    var parserVersion: Int
    var rows: [Int]

    /// The user's decision belongs to the original rows, not an app release.
    /// Reuse still requires a fresh read and validation by the current parser.
    func identifies(sourceIdentity: String, digest: String, defaultYear: Int?) -> Bool {
        self.sourceIdentity == sourceIdentity && self.digest == digest && self.defaultYear == defaultYear &&
        (1...ChangeAnalysis.parserVersion).contains(parserVersion) &&
        !rows.isEmpty && rows == Array(Set(rows)).sorted() &&
        rows.allSatisfy { (1...ChangeNormalizer.maximumRows).contains($0) }
    }

    func matches(sourceIdentity: String, digest: String, defaultYear: Int?) -> Bool {
        parserVersion == ChangeAnalysis.parserVersion &&
        identifies(sourceIdentity: sourceIdentity, digest: digest, defaultYear: defaultYear)
    }
}

struct ChangeReviewField: Equatable {
    var title: String
    var value: String
}

struct ChangeReviewRow: Equatable, Identifiable {
    var id: Int
    var warning: ChangeParseError
    var fields: [ChangeReviewField]
    var canSkip: Bool { warning.code == .weekdayMismatch || warning.code == .weekdayOnly }
}

struct ChangeReviewGroup: Identifiable {
    var rows: [ChangeReviewRow]
    var id: Int { rows[0].id }
    var rowIDs: Set<Int> { Set(rows.map(\.id)) }
    var rangeLabel: String { Self.rangeLabel(rows.map(\.id)) }
    var accessibilityID: String {
        rows.count == 1 ? "change-skip-row-\(id)" : "change-skip-group-\(id)-\(rows.last!.id)"
    }

    static func group(_ rows: [ChangeReviewRow]) -> [Self] {
        var groups: [Self] = []
        for row in rows {
            if let previous = groups.last?.rows.last,
               previous.id < Int.max, row.id == previous.id+1,
               placeholder(previous), placeholder(row), previous.fields == row.fields,
               previous.warning.printedWeekday == row.warning.printedWeekday {
                groups[groups.count-1].rows.append(row)
            } else { groups.append(Self(rows:[row])) }
        }
        return groups
    }

    private static func placeholder(_ row: ChangeReviewRow) -> Bool {
        row.warning.code == .weekdayOnly && row.fields.count <= 1 &&
        row.fields.allSatisfy { ["曜日", "曜"].contains(ChangeNormalizer.token($0.title)) }
    }

    static func rangeLabel(_ rowIDs: [Int]) -> String {
        let sorted = Set(rowIDs).sorted()
        guard let first = sorted.first else { return "" }
        var ranges: [String] = [], start = first, end = first
        func appendRange() { ranges.append(start == end ? "\(start)行目" : "\(start)〜\(end)行目") }
        for row in sorted.dropFirst() {
            if end < Int.max, row == end+1 { end = row }
            else { appendRange(); start = row; end = row }
        }
        appendRange()
        return ranges.joined(separator:"、")
    }
}

struct ChangeParseAttempt: Codable {
    var date: Date
    var sourceDigest: String?
    var defaultYear: Int?
    var failure: ChangeParseError?
    var parserVersion: Int? = nil

    func matches(digest: String, defaultYear: Int?) -> Bool {
        guard let defaultYear, (1900...9998).contains(defaultYear) else { return false }
        return sourceDigest == digest && self.defaultYear == defaultYear && parserVersion == ChangeAnalysis.parserVersion
    }

    static func needsAnalysis(digest: String, defaultYear: Int?, analysis: ChangeAnalysis?, attempt: ChangeParseAttempt?, weekdayConsent: ChangeWeekdayConsent? = nil, rowSkipConsent: ChangeRowSkipConsent? = nil, personalSourceIdentity: String? = nil) -> Bool {
        // An invalid configured year must be corrected before acquisition/parse.
        guard let defaultYear, (1900...9998).contains(defaultYear) else { return false }
        if analysis?.sourceDigest == digest, analysis?.version == ChangeAnalysis.parserVersion,
           analysis?.defaultYear == defaultYear, analysis?.personalSourceIdentity == personalSourceIdentity, analysis?.weekdayConsent == weekdayConsent,
           analysis?.rowSkipConsent == rowSkipConsent { return false }
        if attempt?.sourceDigest == digest, attempt?.defaultYear == defaultYear,
           attempt?.parserVersion == ChangeAnalysis.parserVersion, let failure = attempt?.failure,
           failure.code != .cancelled && failure.code != .storage && failure.code != .staleConfirmation { return false }
        return true
    }
}

// Deliberately separate from the persisted, successful ChangeAnalysis.
struct ChangePreview {
    var sourceName: String
    var defaultYear: Int?
    var records: [ScheduleChange]
    var warnings: [ChangeParseError]
    var sourceIdentity: String? = nil
    var sourceDigest: String? = nil
    var parserVersion: Int = ChangeAnalysis.parserVersion
    var reviewRows: [ChangeReviewRow] = []
    var excludedRows: Set<Int> = []
    var editor: ChangeWorkbookReview? = nil
    var usesDateDerivedWeekdays = false
    var reviewGroups: [ChangeReviewGroup] { ChangeReviewGroup.group(reviewRows) }
    var canCorrectWeekdays: Bool { sourceIdentity != nil && sourceDigest != nil && !warnings.isEmpty && warnings.allSatisfy(\.canCorrectWeekday) }
    var canSkipRows: Bool { sourceIdentity != nil && sourceDigest != nil && reviewRows.contains(where: \.canSkip) }
}

struct ChangeParseError: Error, Codable, LocalizedError, Equatable {
    enum Code: String, Codable {
        case invalidArchive, limit, invalidXML, missingSheet, unsupported, headers
        case date, defaultYear, year, classes, unknownAll, empty, cancelled, storage, staleConfirmation
        case formula, formulaCache, weekdayMismatch, weekdayOnly, mergedCells, dateSystem, cellType
    }
    var code: Code
    var row: Int? = nil
    var printedWeekday: String? = nil
    var calculatedWeekday: String? = nil
    var column: Int? = nil
    var canCorrectWeekday: Bool { code == .weekdayMismatch && printedWeekday.map(ChangeNormalizer.knownWeekday) == true && calculatedWeekday != nil }
    var permitsPreview: Bool { code == .formulaCache || code == .weekdayMismatch || code == .weekdayOnly }
    var errorDescription: String? {
        let detail: String
        switch code {
        case .invalidArchive: detail = "XLSXの構造を読み取れません。破損・暗号化されたファイルは解析できません。"
        case .limit: detail = "ファイルが解析可能なサイズ・行数・件数の上限を超えています。"
        case .invalidXML: detail = "XLSX内の表の構造が不正です。"
        case .missingSheet: detail = "「時間割変更」シートが見つからないか、重複しています。"
        case .unsupported: detail = "このXLSXには未対応の構造や外部参照が含まれています。"
        case .formula: detail = "見出し、または曜日以外の列に数式があります。この箇所の数式は解析できません。"
        case .formulaCache: detail = "曜日の計算結果が保存されていません。内容を確認して修正できます。"
        case .weekdayMismatch: detail = "曜日と月日が一致しないか、曜日の表記を確認できません。内容を確認して修正できます。"
        case .weekdayOnly: detail = "曜日以外の値がない行があります。内容を確認して、その行を除外できます。"
        case .mergedCells: detail = "見出しや表の行に結合セルがあります。結合された値は推測して補えません。"
        case .dateSystem: detail = "ブックの日付システムを確認できません。"
        case .cellType: detail = "表に未対応のセル形式やExcelのエラー値があります。"
        case .headers: detail = "必要な見出し（学 年・学科・クラス・月日）がないか、見出しが重複しています。"
        case .date: detail = "日付を確定できません。年なし日付の場合は補完する年を指定してください。"
        case .defaultYear: detail = "西暦1900〜9998の学校年度を入力してください。"
        case .year: detail = "学年の指定を読み取れません。"
        case .classes: detail = "クラスの指定を読み取れません。"
        case .unknownAll: detail = "「全」の対象クラスをファイル内の記載から確定できません。"
        case .empty: detail = "時間割変更の行がありません。空の結果では前回の解析結果を置き換えません。"
        case .cancelled: detail = "解析を中止しました。"
        case .staleConfirmation: detail = "資料・補完年度・確認内容が変わりました。現在の資料を解析して、内容を確認し直してください。"
        case .storage: detail = "解析結果を保存できません。"
        }
        return (row.map { "\($0)行目：" } ?? "") + detail
    }
}

struct ChangeEditBaseline: Equatable {
    let personal: PersonalChangeSettings?
    let weekday: ChangeWeekdayConsent?
    let skipped: ChangeRowSkipConsent?

    init(source: MaterialSource) {
        personal = source.personalChanges
        weekday = source.weekdayConsent
        skipped = source.rowSkipConsent
    }
}

struct ChangeWorkbookReview {
    let id = UUID()
    var baseline: ChangeEditBaseline? = nil
    var sheets: [String]
    var table: ChangeEditTable
    var layout: ChangeColumnLayout
    var requiresLayoutConfirmation: Bool
    var edits: [Int: ChangeRowEdit] = [:]
    var conflicts: Set<Int> = []
    var previous: [ChangeEdits.Entry] = []
}

/// Column indexes are zero-based. Row numbers are the physical one-based XLSX numbers.
struct ChangeRowEdit: Codable, Equatable {
    var values: [Int: String] = [:]
    var excluded = false
    var deriveWeekday = false
    // nil also decodes decisions saved before the weekday control could be turned off explicitly.
    var keepPrintedWeekday: Bool? = nil
    var isEmpty: Bool { values.isEmpty && !excluded && !deriveWeekday && keepPrintedWeekday != true }

    mutating func chooseDateDerivedWeekday(_ derive: Bool) {
        deriveWeekday = derive
        keepPrintedWeekday = derive ? nil : true
    }
}

struct ChangeEdits: Codable, Equatable {
    struct Original: Codable, Hashable {
        var values: [String]
        var issues: [Int: ChangeParseError.Code]
        var sources: [Int: String]
        var date1904: Bool? = nil
    }
    struct Entry: Codable, Equatable {
        var row: Int
        var original: Original
        var occurrences: Int
        var edit: ChangeRowEdit
        var valueLabels: [Int: String]? = nil
        var editedSerialUses1904: Bool? = nil
        var dateColumn: Int? = nil
    }
    var sourceIdentity: String
    var digest: String
    var defaultYear: Int
    var sheet: String
    var headers: [String]
    var entries: [Entry]
    var originalHeaders: [String]? = nil
    var headerSources: [Int: String]? = nil
    var reviewedHeaderRow: Int? = nil
    var physicalWidth: Int? = nil
}

/// One action can operate on the listed rows. Row identity is still saved independently.
struct ChangeIssueGroup: Identifiable, Hashable {
    var code: ChangeParseError.Code
    var column: Int
    var rows: [Int]
    var printed = ""
    var formula = false
    var blankField = false
    var optional = false
    enum Saved: Hashable { case excluded, derived, printed, field(String) }
    var saved: Saved? = nil
    var id: String {
        switch saved {
        case .excluded: return "excluded"
        case .derived: return "derived"
        case .printed: return "printed"
        case .field: return "field-\(column)-\(rows[0])"
        case nil: return "\(code.rawValue)-\(column)-\(rows[0])"
        }
    }

    static func savedGroups(_ edits: [Int: ChangeRowEdit]) -> [Self] {
        struct Key: Hashable { var action: Saved; var column: Int }
        var members: [Key: [Int]] = [:], order: [Key] = []
        func append(_ action: Saved, _ column: Int, row: Int) {
            let key = Key(action: action, column: column)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(row)
        }
        for row in edits.keys.sorted() {
            guard let edit = edits[row] else { continue }
            if edit.excluded { append(.excluded, -1, row: row) }
            if edit.deriveWeekday { append(.derived, -2, row: row) }
            if edit.keepPrintedWeekday == true { append(.printed, -3, row: row) }
            for column in edit.values.keys.sorted() {
                if let value = edit.values[column] { append(.field(value), column, row: row) }
            }
        }
        return order.map { Self(code: .staleConfirmation, column: $0.column, rows: members[$0]!, saved: $0.action) }
    }

    enum Action { case exclude, weekday, value(String), undo }

    func apply(_ action: Action, selecting selected: Set<Int>, headers: [String], edits: inout [Int: ChangeRowEdit]) {
        for row in rows where selected.contains(row) {
            switch action {
            case .undo:
                switch saved {
                case .excluded: edits[row]?.excluded = false
                case .derived: edits[row]?.deriveWeekday = false
                case .printed: edits[row]?.keepPrintedWeekday = nil
                case .field: edits[row]?.values.removeValue(forKey: column)
                case nil: break
                }
            case .exclude: edits[row, default: ChangeRowEdit()].excluded = true
            case .weekday: edits[row, default: ChangeRowEdit()].chooseDateDerivedWeekday(true)
            case .value(let value):
                guard headers.indices.contains(column) else { continue }
                edits[row, default: ChangeRowEdit()].values[column] = value
                let header = ChangeNormalizer.token(headers[column])
                if ["曜", "曜日"].contains(header) {
                    edits[row, default: ChangeRowEdit()].chooseDateDerivedWeekday(false)
                } else if header == "月日", edits[row]?.keepPrintedWeekday != true {
                    edits[row, default: ChangeRowEdit()].deriveWeekday = true
                }
            }
        }
    }

    static func groups(_ problems: [Int: [ChangeParseError]], table: ChangeEditTable, edits: [Int: ChangeRowEdit] = [:]) -> [Self] {
        struct Field: Hashable { let code: ChangeParseError.Code; let column: Int; let blank: Bool }
        var groups: [Self] = []
        var fields: [Field: Int] = [:]
        for row in problems.keys.sorted() {
            for issue in problems[row] ?? [] {
                guard let column = issue.column else { continue }
                let code: ChangeParseError.Code = issue.code == .formulaCache && issue.calculatedWeekday != nil ? .weekdayMismatch : issue.code
                if code == .weekdayOnly {
                    let printed = ChangeNormalizer.text(issue.printedWeekday ?? "")
                    let formula = table.cellIssues[row]?[column] == .formula || table.cellIssues[row]?[column] == .formulaCache
                    if let last = groups.last, last.code == code, last.column == column,
                       last.rows.last == row - 1, last.printed == printed, last.formula == formula {
                        groups[groups.count - 1].rows.append(row)
                    } else {
                        groups.append(Self(code: code, column: column, rows: [row], printed: printed, formula: formula))
                    }
                } else {
                    let original = table.rows[row - 1]
                    let value = edits[row]?.values[column] ?? (original.indices.contains(column) ? original[column] : "")
                    let blank = (code == .year || code == .classes) && ChangeNormalizer.text(value).isEmpty
                    let key = Field(code: code, column: column, blank: blank)
                    if let index = fields[key] { groups[index].rows.append(row) }
                    else {
                        fields[key] = groups.count
                        groups.append(Self(code: code, column: column, rows: [row], blankField: blank))
                    }
                }
            }
        }
        return groups
    }
}

struct ChangeEditTable: Equatable {
    var sheet: String
    var headers: [String]
    var rows: [[String]]
    var headerRow: Int
    var cellIssues: [Int: [Int: ChangeParseError.Code]] = [:]
    /// Includes e.g. an unexecuted formula's source, Excel error value or relative merge offsets.
    var cellSources: [Int: [Int: String]] = [:]
    var originalHeaders: [String]? = nil

    var headerSources: [Int: String]? = nil
    var physicalWidth: Int? = nil
    var uses1904 = false
    var numericCells: [Int: Set<Int>] = [:]
    var dateCells: [Int: Set<Int>] = [:]
    var formattedDates: [Int: [Int: Bool]] = [:] // true when the format includes a clock

    var rowIDs: [Int] {
        guard headerRow > 0, headerRow < rows.count else { return [] }
        return ((headerRow + 1)...rows.count).filter { number in
            rows[number - 1].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                || cellIssues[number]?.isEmpty == false || cellSources[number]?.isEmpty == false
        }
    }

    func original(at row: Int) -> ChangeEdits.Original {
        // An omitted trailing XLSX cell and an explicit blank are the same input.
        var values = rows[row - 1]
        while values.last == "" { values.removeLast() }
        let date = headers.firstIndex(where: { ChangeNormalizer.text($0) == "月日" })
        let date1904 = uses1904 && date.map { column in
            values.indices.contains(column) && ChangeNormalizer.matches(ChangeNormalizer.text(values[column]), #"^[0-9]+(?:\.[0-9]+)?$"#)
        } == true
        return ChangeEdits.Original(values: values, issues: cellIssues[row] ?? [:], sources: cellSources[row] ?? [:],
                                    date1904: date1904 ? true : nil)
    }

    func savedEdits(sourceIdentity: String, digest: String, defaultYear: Int,
                    edits: [Int: ChangeRowEdit]) throws -> ChangeEdits? {
        let active = edits.filter { !$0.value.isEmpty }
        guard !active.isEmpty else { return nil }
        let ids = rowIDs
        guard !sourceIdentity.isEmpty, !digest.isEmpty, Set(active.keys).isSubset(of: Set(ids)),
              active.values.allSatisfy({ $0.values.allSatisfy { headers.indices.contains($0.key) && $0.value.utf8.count <= 4096 } })
        else { throw ChangeParseError(code: .staleConfirmation) }
        let groups = Dictionary(grouping: ids, by: original(at:))
        let dateColumn = headers.firstIndex { ChangeNormalizer.text($0) == "月日" }
        let entries = active.keys.sorted().compactMap { number -> ChangeEdits.Entry? in
            let key = original(at: number)
            guard let occurrences = groups[key]?.count, let edit = active[number] else { return nil }
            let editedDate = dateColumn.flatMap { edit.values[$0] }
            let editedSerial = editedDate.map { ChangeNormalizer.matches(ChangeNormalizer.text($0), "^[0-9]+(?:\\.[0-9]+)?$") } == true
            return ChangeEdits.Entry(row: number, original: key, occurrences: occurrences, edit: edit,
                valueLabels: Dictionary(uniqueKeysWithValues: edit.values.keys.map { ($0, headers[$0]) }), editedSerialUses1904: editedSerial ? uses1904 : nil, dateColumn: dateColumn)
        }
        return ChangeEdits(sourceIdentity: sourceIdentity, digest: digest, defaultYear: defaultYear,
                           sheet: sheet, headers: headers, entries: entries, originalHeaders: originalHeaders, headerSources: headerSources, reviewedHeaderRow: headerRow, physicalWidth: physicalWidth)
    }

    /// An appended source column may shift fields supplied by the editor. The old
    /// physical prefix must keep its meaning. A virtual field follows its unique
    /// label, and only an identical original row is eligible for those values.
    private func restoredColumns(from saved: ChangeEdits) -> [Int: Int]? {
        let previous = saved.originalHeaders ?? saved.headers
        let current = originalHeaders ?? headers
        let oldSources = saved.headerSources ?? [:]
        let newSources = headerSources ?? [:]
        if previous == current && saved.headers == headers && oldSources == newSources {
            return Dictionary(uniqueKeysWithValues: headers.indices.map { ($0, $0) })
        }
        guard let oldWidth = saved.physicalWidth, let newWidth = physicalWidth,
              oldWidth < newWidth, saved.headers.count >= oldWidth, headers.count >= newWidth,
              current.starts(with: previous), oldSources == newSources.filter({ $0.key < oldWidth }),
              Array(saved.headers.prefix(oldWidth)) == Array(headers.prefix(oldWidth)) else { return nil }
        var mapping = Dictionary(uniqueKeysWithValues: (0..<oldWidth).map { ($0, $0) })
        for column in oldWidth..<saved.headers.count {
            let candidates = headers.indices.filter { $0 >= oldWidth && headers[$0] == saved.headers[column] }
            if candidates.count == 1 { mapping[column] = candidates[0] }
        }
        return mapping
    }

    func restoreDetailed(_ saved: ChangeEdits?, sourceIdentity: String, digest: String, defaultYear: Int)
        -> (edits: [Int: ChangeRowEdit], conflicts: Set<Int>, unmatched: [ChangeEdits.Entry]) {
        guard let saved, saved.sourceIdentity == sourceIdentity, saved.defaultYear == defaultYear,
              saved.sheet == sheet, let columns = restoredColumns(from: saved),
              saved.digest != digest || saved.reviewedHeaderRow == nil || saved.reviewedHeaderRow == headerRow else {
            return ([:], [], saved?.entries.map { $0.withDateColumn(in: saved?.headers ?? []) } ?? [])
        }
        let groups = Dictionary(grouping: rowIDs, by: original(at:))
        let dateColumn = headers.firstIndex { ChangeNormalizer.text($0) == "月日" }
        func epochMatches(_ entry: ChangeEdits.Entry) -> Bool {
            if let originalEpoch = entry.editedSerialUses1904 { return originalEpoch == uses1904 }
            // v10 saved no epoch for a numeric correction of an empty source cell.
            guard saved.digest != digest, let column = dateColumn, let value = entry.edit.values[column],
                  ChangeNormalizer.matches(ChangeNormalizer.text(value), "^[0-9]+(?:\\.[0-9]+)?$") else { return true }
            if entry.original.sources[column]?.hasPrefix("/type/n/") == true {
                return (entry.original.date1904 == true) == uses1904
            }
            return false
        }
        var edits: [Int: ChangeRowEdit] = [:], conflicts = Set<Int>(), unmatched: [ChangeEdits.Entry] = []
        var mappedEntries: [ChangeEdits.Entry] = []
        for previous in saved.entries {
            var entry = previous.withDateColumn(in: saved.headers)
            let fields = entry.edit.values
            guard fields.keys.allSatisfy({ columns[$0] != nil }) else {
                unmatched.append(entry)
                continue
            }
            entry.edit.values = Dictionary(uniqueKeysWithValues: fields.map { (columns[$0.key]!, $0.value) })
            entry.valueLabels = Dictionary(uniqueKeysWithValues: entry.edit.values.keys.map { ($0, headers[$0]) })
            mappedEntries.append(entry)
        }
        for (key, previous) in Dictionary(grouping: mappedEntries, by: \.original) {
            guard let numbers = groups[key], let first = previous.first,
                  previous.allSatisfy(epochMatches) else {
                unmatched += previous
                continue
            }
            if saved.digest == digest {
                let candidates = Set(numbers)
                for entry in previous where candidates.contains(entry.row) { edits[entry.row] = entry.edit }
            } else if !key.sources.values.contains(where: { $0.hasPrefix("unresolved-shared/") }),
                      first.occurrences == numbers.count, previous.count == numbers.count,
                      previous.allSatisfy({ $0.occurrences == first.occurrences && $0.edit == first.edit }) {
                // Also covers one-to-one matching after insertion/reordering. A duplicate
                // group is safe only if every old/new copy gets exactly the same decision.
                for number in numbers { edits[number] = first.edit }
            } else {
                conflicts.formUnion(numbers)
                unmatched += previous
            }
        }
        return (edits, conflicts, unmatched.sorted { $0.row < $1.row })
    }

    func restore(_ saved: ChangeEdits?, sourceIdentity: String, digest: String, defaultYear: Int)
        -> (edits: [Int: ChangeRowEdit], conflicts: Set<Int>) {
        let restored = restoreDetailed(saved, sourceIdentity: sourceIdentity, digest: digest, defaultYear: defaultYear)
        return (restored.edits, restored.conflicts)
    }
}

extension ChangeEdits.Entry {
    func withDateColumn(in headers: [String]) -> Self {
        var entry = self
        if entry.dateColumn == nil {
            entry.dateColumn = headers.firstIndex { ChangeNormalizer.text($0) == "月日" }
        }
        return entry
    }

    func displayValue(column: Int, edited: Bool, year: Int) -> String {
        let value = edited ? edit.values[column] ?? "" :
            (original.values.indices.contains(column) ? original.values[column] : "")
        guard column == dateColumn || valueLabels?[column] == "月日" else { return value }
        guard edited || original.issues[column] == nil else { return "月日を確認" }
        let typed = !edited && original.sources[column]?.hasPrefix("/type/d/") == true
        let epoch = edited ? editedSerialUses1904 ?? (original.date1904 == true) : original.date1904 == true
        return ChangeNormalizer.readableDate(typed ? String(value.prefix(10)) : value,
                                             defaultYear: year, uses1904: epoch) ?? "月日を確認"
    }
}
