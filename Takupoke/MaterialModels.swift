import Foundation

enum MaterialKind: String, Codable, CaseIterable, Identifiable {
    case timetable, events, changes

    var id: String { rawValue }
    var title: String {
        switch self {
        case .timetable: return "通常時間割"
        case .events: return "学校行事"
        case .changes: return "時間割変更"
        }
    }
    var fileExtension: String { self == .changes ? "xlsx" : "pdf" }
}

struct SourceGrant: Codable {
    var bookmark: Data
    var name: String
    var isFolder: Bool
}

struct MaterialSource: Codable {
    var grant: SourceGrant?
    var childName: String?
    var remoteURL: URL? = nil
    var remoteETag: String? = nil
    var remoteLastModified: String? = nil
}

struct MaterialRecord: Codable {
    var kind: MaterialKind
    var source: MaterialSource
    var originalName: String
    var storedName: String
    var byteCount: Int
    var digest: String
    var sourceModifiedAt: Date?
    var acquiredAt: Date
    var lastCheckedAt: Date? = nil
}

struct AcquisitionAttempt: Codable {
    var date: Date
    var failure: String?
}

struct MaterialLibraryState: Codable {
    var schemaVersion = 1
    var folder: SourceGrant?
    var records: [MaterialRecord] = []
    var attempts: [String: AcquisitionAttempt] = [:]
    var changeAnalysis: ChangeAnalysis?
    var changeParseAttempt: ChangeParseAttempt?
    var pdfAnalyses: [String: PDFAnalysis]?
    var pdfParseAttempts: [String: PDFParseAttempt]?

    func record(for kind: MaterialKind) -> MaterialRecord? {
        records.first { $0.kind == kind }
    }
}

enum MaterialError: LocalizedError {
    case unavailable, invalidFile, tooLarge, invalidState, cancelled
    case accessExpired, bookmarkFailed, providerReadFailed, invalidWebURL, webUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "取得できませんでした。「ファイル」で対象のファイルを開けるか確認し、必要なら選び直してください。前回のファイルは保持しています。"
        case .invalidFile:
            return "指定した種類のPDFまたはXLSXを選んでください。空のファイルや形式が異なるファイルは取得できません。"
        case .tooLarge:
            return "1ファイル50 MiBまで取得できます。前回のファイルは保持しています。"
        case .invalidState:
            return "端末内の保存情報を読み取れません。既存データを保護するため更新を停止しました。"
        case .cancelled:
            return "取得を中止しました。前回のファイルは保持しています。"
        case .accessExpired:
            return "ファイルへのアクセス許可を確認できません。ファイルを選び直してください。前回のファイルは保持しています。"
        case .bookmarkFailed:
            return "ファイルは読み取れましたが、次回のアクセス情報を保存できませんでした。前回のファイルは保持しています。ファイルを選び直してください。"
        case .providerReadFailed:
            return "ファイルの内容を取得できませんでした。OneDriveの通信状態を確認してください。続く場合は「ファイル」で一度開いてから選び直してください。前回のファイルは保持しています。"
        case .invalidWebURL:
            return "学校行事PDFの取得先を利用できません。前回のファイルは保持しています。"
        case .webUnavailable:
            return "学校行事PDFをWebから取得できませんでした。通信状態を確認して再試行してください。前回のファイルは保持しています。"
        }
    }
}

/// An adapter owns the commit point; file collection runs only after a valid load.
protocol MaterialLibraryPersistence: AnyObject {
    func load() throws -> MaterialLibraryState
    func save(_ state: MaterialLibraryState) throws
    func retainedStoredNames() throws -> Set<String>
}
