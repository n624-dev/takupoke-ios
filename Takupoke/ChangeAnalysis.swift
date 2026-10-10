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
    static let parserVersion = 6
    var version = parserVersion
    var sourceDigest: String
    var sourceName: String
    var defaultYear: Int?
    var parsedAt: Date
    var records: [ScheduleChange]
    var weekdayConsent: ChangeWeekdayConsent? = nil
    var rowSkipConsent: ChangeRowSkipConsent? = nil
}

struct ChangeRowSkipConsent: Codable, Equatable {
    var sourceIdentity: String
    var digest: String
    var defaultYear: Int?
    var parserVersion: Int
    var rows: [Int]

    func matches(sourceIdentity: String, digest: String, defaultYear: Int?) -> Bool {
        self.sourceIdentity == sourceIdentity && self.digest == digest && self.defaultYear == defaultYear &&
        parserVersion == ChangeAnalysis.parserVersion && !rows.isEmpty && rows == Array(Set(rows)).sorted() &&
        rows.allSatisfy { (1...ChangeNormalizer.maximumRows).contains($0) }
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

    static func needsAnalysis(digest: String, defaultYear: Int, analysis: ChangeAnalysis?, attempt: ChangeParseAttempt?, weekdayConsent: ChangeWeekdayConsent? = nil, rowSkipConsent: ChangeRowSkipConsent? = nil) -> Bool {
        if analysis?.sourceDigest == digest, analysis?.version == ChangeAnalysis.parserVersion,
           analysis?.defaultYear == defaultYear, analysis?.weekdayConsent == weekdayConsent,
           analysis?.rowSkipConsent == rowSkipConsent { return false }
        if attempt?.sourceDigest == digest, attempt?.defaultYear == defaultYear,
           attempt?.parserVersion == ChangeAnalysis.parserVersion, let failure = attempt?.failure,
           failure.code != .cancelled && failure.code != .storage { return false }
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
    var reviewGroups: [ChangeReviewGroup] { ChangeReviewGroup.group(reviewRows) }
    var canCorrectWeekdays: Bool { sourceIdentity != nil && sourceDigest != nil && !warnings.isEmpty && warnings.allSatisfy(\.canCorrectWeekday) }
    var canSkipRows: Bool { sourceIdentity != nil && sourceDigest != nil && reviewRows.contains(where: \.canSkip) }
}

struct ChangeParseError: Error, Codable, LocalizedError, Equatable {
    enum Code: String, Codable {
        case invalidArchive, limit, invalidXML, missingSheet, unsupported, headers
        case date, year, classes, unknownAll, empty, cancelled, storage
        case formula, formulaCache, weekdayMismatch, weekdayOnly, mergedCells, dateSystem, cellType
    }
    var code: Code
    var row: Int? = nil
    var printedWeekday: String? = nil
    var calculatedWeekday: String? = nil
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
        case .formulaCache: detail = "曜日の計算結果が保存されていません。警告を確認して内容だけを見ることができます。"
        case .weekdayMismatch: detail = "曜日と月日が一致しないか、曜日の表記を確認できません。警告を確認して内容だけを見ることができます。"
        case .weekdayOnly: detail = "曜日以外の値がない行があります。内容を確認して、その行を除外できます。"
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
