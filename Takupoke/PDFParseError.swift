import Foundation

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
    var trace: PDFDiagnosticSnapshot? = nil
    var diagnosticReport: String? {
        guard trace != nil || geometry != nil else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else { return nil }
        return (trace == nil ? "TAKUPOKE-PDF-GEOMETRY-1\n" : "TAKUPOKE-PDF-TRACE-1\n") + json
    }
    var errorDescription: String? {
        let reason: String
        switch code {
        case .unreadable: reason = "PDFを読み取れません。暗号化・破損・画像だけのPDFには対応していません。"
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
