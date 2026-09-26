import Foundation

/// Used only on the acquisition worker's serial queue. No provider URLs are
/// touched here; this owns the private on-device copies and their saved metadata.
final class MaterialLibrary {
    static let maximumBytes = 50 * 1024 * 1024
    private let root: URL
    private let files: URL
    private let staging: URL
    private let manifest: URL
    private let persistence: MaterialLibraryPersistence?
    private let writeManifest: (Data, URL) throws -> Void
    var state: MaterialLibraryState

    init(root: URL, persistence: MaterialLibraryPersistence? = nil, writeManifest: @escaping (Data, URL) throws -> Void = {
        try $0.write(to: $1, options: .atomic)
    }) throws {
        self.root = root
        self.persistence = persistence
        files = root.appendingPathComponent("files", isDirectory: true)
        staging = root.appendingPathComponent("staging", isDirectory: true)
        manifest = root.appendingPathComponent("library.json")
        self.writeManifest = writeManifest
        let manager = FileManager.default
        let hasManifest = manager.fileExists(atPath: manifest.path)
        if let persistence {
            do { state = try persistence.load() }
            catch { throw MaterialError.invalidState }
        } else if hasManifest {
            do {
                guard let size = try manifest.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size <= 64 * 1024 * 1024 else { throw MaterialError.invalidState }
                state = try Self.decodeLegacyManifest(Data(contentsOf: manifest))
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
        if persistence == nil && !hasManifest { try persist(state) }
        // A valid saved state is the commit point. Reclaim only our unreferenced
        // files, including work interrupted by termination during a copy.
        try removeUnreferencedFiles()
    }

    /// Pure validation shared by the legacy reader and migration preparation.
    /// Does not create directories or run the legacy file collector.
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
        if let persistence { try persistence.save(next) }
        else { try writeManifest(data, manifest) }
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
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
            #endif
            try persist(next)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        // Old data is removed only after persistence succeeds.
        // Interrupted cleanup is retried the next time the library opens.
        // SQLite may still have an older file open in a PDF view. Defer orphan
        // collection to the next launch, before any views or jobs can use files.
        if persistence == nil { try? removeUnreferencedFiles() }
    }

    func localURL(for kind: MaterialKind) -> URL? {
        state.record(for: kind).map { files.appendingPathComponent($0.storedName) }
    }

    private func removeUnreferencedFiles() throws {
        let manager = FileManager.default
        let keep = try persistence?.retainedStoredNames() ?? Set(state.records.map(\.storedName))
        for url in try manager.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: url)
        }
        for url in try manager.contentsOfDirectory(at: files, includingPropertiesForKeys: nil)
            where !keep.contains(url.lastPathComponent) {
            try manager.removeItem(at: url)
        }
    }
}
