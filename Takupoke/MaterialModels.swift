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

    #if os(iOS) || os(macOS)
    /// A renewed picker grant can retain the decision only for the bookmarked
    /// original. A matching filename or digest alone is insufficient.
    func references(_ selectedURL: URL) -> Bool {
        guard !isFolder, selectedURL.isFileURL else { return false }
        guard let original = try? MaterialBookmarkResolution.resolve(bookmark) else { return false }
        return original.url.standardizedFileURL == selectedURL.standardizedFileURL
    }
    #endif
}

struct MaterialBookmarkResolution {
    let url: URL
    let isStale: Bool

    static func verifiesOriginal(receivedDigest: String, savedDigest: String, readSavedDigest: () throws -> String) throws {
        guard receivedDigest == savedDigest, try readSavedDigest() == savedDigest else { throw MaterialError.bookmarkStale }
    }

    #if os(iOS) || os(macOS)
    func renewedGrant(_ previous: SourceGrant, receivedDigest: String, savedDigest: String,
                      readSavedDigest: () throws -> String) throws -> SourceGrant {
        try Self.verifiesOriginal(receivedDigest: receivedDigest, savedDigest: savedDigest, readSavedDigest: readSavedDigest)
        do {
            return SourceGrant(bookmark: try url.bookmarkData(options: .minimalBookmark,
                includingResourceValuesForKeys: nil, relativeTo: nil), name: previous.name, isFolder: previous.isFolder)
        } catch { throw MaterialError.bookmarkFailed }
    }
    #endif

    func requireCurrent() throws {
        if isStale { throw MaterialError.bookmarkStale }
    }

    #if os(iOS) || os(macOS)
    static func resolve(_ bookmark: Data) throws -> Self {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &stale), url.isFileURL else {
            throw MaterialError.bookmarkUnresolved
        }
        return Self(url: url, isStale: stale)
    }
    #endif
}

/// Only configuration confirmed for this header is reused after a provider update.
struct ChangeColumnLayout: Codable, Equatable {
    var sheet: String
    var headerRow: Int
    var original: [String]
    var headers: [String]
    var physicalWidth: Int? = nil
    var headerSources: [Int: String]? = nil
}

struct PersonalChangeSettings: Codable, Equatable {
    var year: Int
    var layout: ChangeColumnLayout
    var rows: ChangeEdits?
    var history: [ChangeEdits.Entry]
    var reviewedDigest: String? = nil
    var ambiguousRows: [Int]? = nil
    var ambiguousOriginals: [ChangeEdits.Original]? = nil
    var ambiguousLayout: ChangeColumnLayout? = nil
}

struct MaterialSource: Codable {
    var personalChanges: PersonalChangeSettings? = nil
    var grant: SourceGrant?
    var childName: String?
    var selectionID: String? = nil
    var weekdayConsent: ChangeWeekdayConsent? = nil
    var rowSkipConsent: ChangeRowSkipConsent? = nil
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
    var lastAcquiredAt: Date? = nil
    var lastCheckedAt: Date? = nil
}

struct AcquisitionAttempt: Codable {
    var date: Date
    var failure: String?
    var cancelled: Bool? = nil
    var problem: AcquisitionProblem? = nil

    var failedToAcquire: Bool {
        guard let failure else { return false }
        // Older records stored Japanese error text without a cancellation bit.
        return !(cancelled ?? (failure == MaterialError.cancelled.errorDescription))
    }
}

enum AcquisitionProblem: String, Codable, Sendable {
    case sizeLimit, invalidFormat, permission, staleBookmark, unresolvedBookmark, temporary, storage, unavailable

    init(_ error: Error) {
        switch error {
        case MaterialError.tooLarge: self = .sizeLimit
        case MaterialError.invalidFile: self = .invalidFormat
        case MaterialError.accessExpired, MaterialError.bookmarkFailed: self = .permission
        case MaterialError.bookmarkStale: self = .staleBookmark
        case MaterialError.bookmarkUnresolved: self = .unresolvedBookmark
        case MaterialError.providerReadFailed: self = .temporary
        case MaterialError.invalidState: self = .storage
        default:
            self = FilePipeline.isTransient(error, stage: .acquiring) ? .temporary : .unavailable
        }
    }

    var message: String {
        switch self {
        case .sizeLimit: return MaterialError.tooLarge.localizedDescription
        case .invalidFormat: return MaterialError.invalidFile.localizedDescription
        case .permission: return MaterialError.accessExpired.localizedDescription
        case .staleBookmark: return MaterialError.bookmarkStale.localizedDescription
        case .unresolvedBookmark: return MaterialError.bookmarkUnresolved.localizedDescription
        case .temporary: return MaterialError.providerReadFailed.localizedDescription
        case .storage: return MaterialError.invalidState.localizedDescription
        case .unavailable: return MaterialError.unavailable.localizedDescription
        }
    }
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
    case bookmarkStale, bookmarkUnresolved

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
        case .bookmarkStale:
            return "保存したファイルへの参照が古くなりました。ファイルを選び直してください。前回のファイルは保持しています。"
        case .bookmarkUnresolved:
            return "保存したファイルの場所を確認できません。ファイルを選び直してください。前回のファイルは保持しています。"
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
    func saveAcquisition(_ record: MaterialRecord, replacing previous: MaterialRecord, attempt: AcquisitionAttempt, moveToEnd: Bool) throws
    func retainedStoredNames() throws -> Set<String>
}
