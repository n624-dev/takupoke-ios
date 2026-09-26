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
