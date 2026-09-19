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
    case unavailable, invalidFile, tooLarge, invalidState, cancelled, folderTooLarge
    case accessExpired, bookmarkFailed, providerReadFailed, invalidWebURL, webUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "取得できませんでした。「ファイル」で資料を開けるか確認し、必要なら再選択してください。前回の資料は保持しています。"
        case .invalidFile:
            return "指定した種類のPDFまたはXLSXを選んでください。空のファイルや形式が異なるファイルは取得できません。"
        case .tooLarge:
            return "1ファイル50 MiBまで取得できます。前回の資料は保持しています。"
        case .invalidState:
            return "端末内の保存情報を読み取れません。既存データを保護するため更新を停止しました。"
        case .cancelled:
            return "取得を中止しました。前回の資料は保持しています。"
        case .folderTooLarge:
            return "項目数が多いため一覧を取得できません。資料をまとめた小さなフォルダを選んでください。"
        case .accessExpired:
            return "資料へのアクセス許可を確認できません。ファイルを選び直してください。前回の資料は保持しています。"
        case .bookmarkFailed:
            return "資料は読み取れましたが、次回のアクセス情報を保存できませんでした。前回の資料は保持しています。ファイルを選び直してください。"
        case .providerReadFailed:
            return "ファイルの内容を取得できませんでした。OneDriveの通信状態を確認してください。続く場合は「ファイル」で一度開いてから再選択してください。前回の資料は保持しています。"
        case .invalidWebURL:
            return "学校行事PDFの取得先を利用できません。前回の資料は保持しています。"
        case .webUnavailable:
            return "学校行事PDFをWebから取得できませんでした。通信状態を確認して再試行してください。前回の資料は保持しています。"
        }
    }
}

/// Used only on the acquisition worker's serial queue. No provider URLs are
/// touched here; this owns the private on-device copies and their manifest.
final class MaterialLibrary {
    static let maximumBytes = 50 * 1024 * 1024
    private let root: URL
    private let files: URL
    private let staging: URL
    private let manifest: URL
    private let writeManifest: (Data, URL) throws -> Void
    private(set) var state: MaterialLibraryState

    init(root: URL, writeManifest: @escaping (Data, URL) throws -> Void = {
        try $0.write(to: $1, options: .atomic)
    }) throws {
        self.root = root
        files = root.appendingPathComponent("files", isDirectory: true)
        staging = root.appendingPathComponent("staging", isDirectory: true)
        manifest = root.appendingPathComponent("library.json")
        self.writeManifest = writeManifest
        let manager = FileManager.default
        let hasManifest = manager.fileExists(atPath: manifest.path)
        if hasManifest {
            do {
                guard let size = try manifest.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size <= 64 * 1024 * 1024 else { throw MaterialError.invalidState }
                state = try JSONDecoder().decode(MaterialLibraryState.self, from: Data(contentsOf: manifest))
                guard state.schemaVersion == 1,
                      Set(state.records.map(\.kind)).count == state.records.count,
                      state.records.allSatisfy({ Self.validStoredName($0.storedName, kind: $0.kind) }) else {
                    throw MaterialError.invalidState
                }
                if let analysis = state.changeAnalysis {
                    guard (1...ChangeAnalysis.parserVersion).contains(analysis.version),
                          !analysis.records.isEmpty, analysis.records.count <= ChangeNormalizer.maximumRecords else {
                        throw MaterialError.invalidState
                    }
                }
                for (key, analysis) in state.pdfAnalyses ?? [:] {
                    guard key == analysis.kind.rawValue, Self.validPDFAnalysis(analysis) else { throw MaterialError.invalidState }
                }
            } catch {
                // Never replace an unreadable manifest with an empty one.
                throw MaterialError.invalidState
            }
        } else {
            // Existing copies without a manifest are not assumed disposable.
            if manager.fileExists(atPath: files.path),
               !(try manager.contentsOfDirectory(atPath: files.path)).isEmpty {
                throw MaterialError.invalidState
            }
            state = MaterialLibraryState()
        }
        // An incomplete library must not look like a successful acquisition.
        for record in state.records {
            let copy = files.appendingPathComponent(record.storedName)
            guard manager.fileExists(atPath: copy.path) else { throw MaterialError.invalidState }
        }
        try manager.createDirectory(at: files, withIntermediateDirectories: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        #if os(iOS) || os(macOS)
        var protectedRoot = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedRoot.setResourceValues(values)
        #endif
        #if os(iOS)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: files.path)
        try manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: staging.path)
        #endif
        // Establish the empty commit point before the first copy. A crash
        // after moving that copy can then be recovered as an orphan.
        if !hasManifest { try persist(state) }
        // A valid manifest is the commit point. Reclaim only our unreferenced
        // files, including work interrupted by termination during a copy.
        try removeUnreferencedFiles()
    }

    private static func validStoredName(_ name: String, kind: MaterialKind) -> Bool {
        let suffix = "." + kind.fileExtension
        return name.hasSuffix(suffix) && UUID(uuidString: String(name.dropLast(suffix.count))) != nil
    }

    func newStagingURL() -> URL {
        staging.appendingPathComponent(UUID().uuidString)
    }

    func discardStaging(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func persist(_ next: MaterialLibraryState) throws {
        let data = try JSONEncoder().encode(next)
        guard data.count <= 64 * 1024 * 1024 else { throw MaterialError.invalidState }
        try writeManifest(data, manifest)
        state = next
    }

    func saveChangeAnalysis(_ analysis: ChangeAnalysis) throws {
        guard state.record(for: .changes)?.digest == analysis.sourceDigest,
              analysis.version == ChangeAnalysis.parserVersion,
              !analysis.records.isEmpty, analysis.records.count <= ChangeNormalizer.maximumRecords else {
            throw ChangeParseError(code: .storage)
        }
        var next = state
        next.changeAnalysis = analysis
        next.changeParseAttempt = ChangeParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest,
                                                     defaultYear: analysis.defaultYear, failure: nil)
        try persist(next)
    }

    private static func validPDFAnalysis(_ analysis: PDFAnalysis) -> Bool {
        guard (1...PDFAnalysis.parserVersion).contains(analysis.version), analysis.kind != .changes,
              analysis.lessons.count + analysis.events.count <= PDFSchoolParser.maximumRecords else { return false }
        switch analysis.kind {
        case .timetable: return !analysis.lessons.isEmpty && analysis.events.isEmpty &&
            analysis.lessons.allSatisfy { (1...5).contains($0.weekday) && (1...8).contains($0.period) && !$0.names.subject.isEmpty }
        case .events: return !analysis.events.isEmpty && analysis.lessons.isEmpty &&
            analysis.events.allSatisfy { ["共通", "詫間"].contains($0.scope) && !$0.title.isEmpty }
        case .changes: return false
        }
    }

    func savePDFAnalysis(_ analysis: PDFAnalysis) throws {
        guard Self.validPDFAnalysis(analysis), state.record(for: analysis.kind)?.digest == analysis.sourceDigest else {
            throw PDFParseError(code: .storage)
        }
        var next = state
        var analyses = next.pdfAnalyses ?? [:]
        var attempts = next.pdfParseAttempts ?? [:]
        analyses[analysis.kind.rawValue] = analysis
        attempts[analysis.kind.rawValue] = PDFParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest, failure: nil)
        next.pdfAnalyses = analyses
        next.pdfParseAttempts = attempts
        try persist(next)
    }

    func recordPDFFailure(_ error: PDFParseError, kind: MaterialKind) throws {
        var next = state
        var attempts = next.pdfParseAttempts ?? [:]
        attempts[kind.rawValue] = PDFParseAttempt(date: Date(), sourceDigest: state.record(for: kind)?.digest, failure: error)
        next.pdfParseAttempts = attempts
        try persist(next)
    }

    func recordParseFailure(_ error: ChangeParseError, defaultYear: Int?) throws {
        var next = state
        next.changeParseAttempt = ChangeParseAttempt(date: Date(), sourceDigest: state.record(for: .changes)?.digest,
                                                     defaultYear: defaultYear, failure: error)
        try persist(next)
    }

    func saveFolder(_ grant: SourceGrant) throws {
        var next = state
        next.folder = grant
        try persist(next)
    }

    func recordFailure(_ kind: MaterialKind, message: String) throws {
        var next = state
        next.attempts[kind.rawValue] = AcquisitionAttempt(date: Date(), failure: message)
        try persist(next)
    }

    func recordUnchanged(_ kind: MaterialKind, source: MaterialSource) throws {
        var next = state
        guard let index = next.records.firstIndex(where: { $0.kind == kind }),
              source.remoteURL != nil, next.records[index].source.remoteURL == source.remoteURL else {
            throw MaterialError.invalidState
        }
        let now = Date()
        next.records[index].source = source
        next.records[index].lastCheckedAt = now
        next.attempts[kind.rawValue] = AcquisitionAttempt(date: now, failure: nil)
        try persist(next)
    }

    func commit(staged: URL, kind: MaterialKind, source: MaterialSource,
                originalName: String, byteCount: Int, digest: String, modifiedAt: Date?) throws {
        guard staged.deletingLastPathComponent().standardizedFileURL == staging.standardizedFileURL,
              byteCount > 0, byteCount <= Self.maximumBytes else { throw MaterialError.invalidFile }
        let name = UUID().uuidString + "." + kind.fileExtension
        let destination = files.appendingPathComponent(name)
        try FileManager.default.moveItem(at: staged, to: destination)
        var next = state
        let now = Date()
        next.records.removeAll { $0.kind == kind }
        next.records.append(MaterialRecord(kind: kind, source: source, originalName: originalName,
                                           storedName: name, byteCount: byteCount, digest: digest,
                                           sourceModifiedAt: modifiedAt, acquiredAt: now, lastCheckedAt: now))
        next.attempts[kind.rawValue] = AcquisitionAttempt(date: now, failure: nil)
        do {
            try persist(next)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        // Old data is removed only after the atomic manifest write succeeds.
        // Interrupted cleanup is retried the next time the library opens.
        try? removeUnreferencedFiles()
    }

    func localURL(for kind: MaterialKind) -> URL? {
        state.record(for: kind).map { files.appendingPathComponent($0.storedName) }
    }

    private func removeUnreferencedFiles() throws {
        let manager = FileManager.default
        let keep = Set(state.records.map(\.storedName))
        for url in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: url)
        }
        for url in try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil)
            where !keep.contains(url.lastPathComponent) {
            try manager.removeItem(at: url)
        }
    }
}
