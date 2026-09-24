import CryptoKit
import Foundation

/// Cancellation can be requested from the UI while the serial worker is
/// waiting for the File Provider. No UI work is performed under file coordination.
final class AcquisitionControl {
    private let lock = NSLock()
    private var cancelled = false
    private var coordinator: NSFileCoordinator?

    func cancel() {
        lock.lock()
        cancelled = true
        let active = coordinator
        lock.unlock()
        active?.cancel()
    }

    func check() throws {
        lock.lock()
        let value = cancelled
        lock.unlock()
        if value { throw MaterialError.cancelled }
    }

    func attach(_ value: NSFileCoordinator?) {
        lock.lock()
        coordinator = value
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel { value?.cancel() }
    }
}

/// Acquire the picker URL before its callback returns; retain the lease until
/// the worker finishes copying and saving the bookmark. URL and lease are immutable.
final class ScopedMaterialSelection: @unchecked Sendable {
    private let url: URL
    private let granted: Bool

    init(_ url: URL) {
        self.url = url
        granted = url.startAccessingSecurityScopedResource()
    }

    deinit { if granted { url.stopAccessingSecurityScopedResource() } }

    func access<T>(_ body: (URL) throws -> T) throws -> T {
        guard granted else { throw MaterialError.accessExpired }
        return try withExtendedLifetime(self) { try body(url) }
    }
}

final class MaterialWorker {
    private(set) var library: MaterialLibrary?
    private(set) var changePreview: ChangePreview?
    private(set) var timetableReadReport: String?
    private(set) var timetableFailure: PDFParseError?

    func clearPreview() { changePreview = nil }

    func open() throws {
        if library != nil { return }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite", isDirectory: true))
    }

    func analyzeChanges(defaultYear: Int?, control: AcquisitionControl) throws {
        guard let library = library, let record = library.state.record(for: .changes),
              let url = library.localURL(for: .changes) else { throw ChangeParseError(code: .invalidArchive) }
        do {
            let check = {
                do { try control.check() }
                catch { throw ChangeParseError(code: .cancelled) }
            }
            let rows = try XLSXReader.read(url, defaultYear: defaultYear, check: check)
            let changes = try ChangeNormalizer.parse(rows, defaultYear: defaultYear, check: check)
            try check()
            let analysis = ChangeAnalysis(sourceDigest: record.digest, sourceName: record.originalName,
                defaultYear: defaultYear, parsedAt: Date(), records: changes)
            do { try library.saveChangeAnalysis(analysis) }
            catch { throw ChangeParseError(code: .storage) }
        } catch {
            let failure = (error as? ChangeParseError) ?? ChangeParseError(code: .storage)
            do { try library.recordParseFailure(failure, defaultYear: defaultYear) }
            catch { throw ChangeParseError(code: .storage) }
            throw failure
        }
    }

    func analyzePDF(kind: MaterialKind, control: AcquisitionControl) throws {
        let diagnostics = kind == .timetable ? PDFDiagnosticRecorder() : nil
        diagnostics?.record(.start)
        if kind == .timetable { timetableReadReport = nil; timetableFailure = nil }
        let check = {
            do { try control.check() } catch { throw PDFParseError(code: .cancelled) }
        }
        var diagnosticURL: URL?
        var succeeded = false
        defer {
            if kind == .timetable {
                var full = diagnosticURL.map { PDFKitReader.diagnose($0, check: check) } ?? PDFFullReadDiagnostic()
                if diagnosticURL == nil { full.incomplete.append(.unavailable) }
                diagnostics?.record(.complete)
                full.sourceName = library?.state.record(for: kind)?.originalName
                full.analysisSucceeded = succeeded
                full.attemptFailure = timetableFailure
                full.trace = diagnostics?.snapshot
                // Full source data stays in memory; the ordinary manifest stores
                // only the previous result and the bounded numeric failure trace.
                timetableReadReport = (try? PDFFullDiagnosticEncoding.report(full)) ??
                    (try? full.jsonData()).flatMap { String(data: $0, encoding: .utf8) }.map { "TAKUPOKE-PDF-FULL-JSON-1\n" + $0 }
            }
        }
        do {
            diagnostics?.record(.material)
            guard kind != .changes, let library = library, let record = library.state.record(for: kind),
                  let url = library.localURL(for: kind) else { throw PDFParseError(code: .unreadable) }
            diagnosticURL = url
            let pages = try PDFKitReader.read(url, kind: kind, diagnostics: diagnostics, check: check)
            diagnostics?.record(.parse, values: [Double(pages.count)])
            let analysis = try PDFSchoolParser.parse(pages, kind: kind, digest: record.digest, name: record.originalName, check: check)
            diagnostics?.record(.parseComplete, values: [Double(analysis.lessons.count), Double(analysis.events.count)])
            try check()
            diagnostics?.record(.save)
            do { try library.savePDFAnalysis(analysis) } catch { throw PDFParseError(code: .storage) }
            diagnostics?.record(.saveComplete)
            succeeded = true
        } catch {
            var failure = diagnostics?.attaching(to: error) ?? ((error as? PDFParseError) ?? PDFParseError(code: .unreadable))
            if kind == .timetable { timetableFailure = failure }
            diagnostics?.record(.failureSave)
            do {
                if let library = library {
                    try library.recordPDFFailure(failure, kind: kind)
                    diagnostics?.record(.failureSaved)
                } else { diagnostics?.record(.failureSaveFailed) }
            } catch {
                diagnostics?.record(.failureSaveFailed)
                let storage = diagnostics?.attaching(to: PDFParseError(code: .storage)) ?? PDFParseError(code: .storage)
                if kind == .timetable { timetableFailure = storage }
                throw storage
            }
            if let diagnostics = diagnostics { failure.trace = diagnostics.snapshot }
            if kind == .timetable { timetableFailure = failure }
            throw failure
        }
    }

    func pdfURL(for kind: MaterialKind) -> URL? { library?.localURL(for: kind) }

    func previewChanges(control: AcquisitionControl) throws {
        guard let library = library else { throw ChangeParseError(code: .storage) }
        let check = {
            do { try control.check() }
            catch { throw ChangeParseError(code: .cancelled) }
        }
        changePreview = try library.previewChanges(check: check)
        // No manifest write: neither the last success nor the failed attempt changes.
    }

    private func grant(for url: URL) throws -> SourceGrant {
        // Called while the original selection is still scoped, after reading.
        do {
            return SourceGrant(bookmark: try url.bookmarkData(options: .minimalBookmark,
                               includingResourceValuesForKeys: nil, relativeTo: nil),
                               name: url.lastPathComponent, isFolder: false)
        } catch { throw MaterialError.bookmarkFailed }
    }

    private func withAccess<T>(_ grant: SourceGrant, body: (URL) throws -> T) throws -> T {
        var stale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: grant.bookmark, options: [], relativeTo: nil,
                          bookmarkDataIsStale: &stale)
        } catch { throw MaterialError.accessExpired }
        let selection = ScopedMaterialSelection(url)
        guard !stale else { throw MaterialError.accessExpired }
        return try selection.access(body)
    }

    private func coordinated<T>(_ url: URL, control: AcquisitionControl,
                                read: (URL) throws -> T) throws -> T {
        try control.check()
        let coordinator = NSFileCoordinator(filePresenter: nil)
        control.attach(coordinator)
        defer { control.attach(nil) }
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { safeURL in
            result = Result { try control.check(); return try read(safeURL) }
        }
        try control.check()
        if let error = coordinationError { throw error }
        guard let result = result else { throw MaterialError.unavailable }
        return try result.get()
    }

    func selectFile(_ selection: ScopedMaterialSelection, kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control) { staged in
            try selection.access { url in
                guard url.pathExtension.lowercased() == kind.fileExtension else { throw MaterialError.invalidFile }
                let result = try copyProviderFile(url, to: staged, kind: kind, control: control)
                let source = MaterialSource(grant: try grant(for: url), childName: nil)
                return .downloaded((source, url.lastPathComponent, result.0, result.1, result.2))
            }
        }
    }

    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws {
        guard let source = library?.state.record(for: kind)?.source else { throw MaterialError.unavailable }
        try acquireSource(source, kind: kind, control: control)
    }

    /// Reads the selected provider file again, then reparses only if its content
    /// digest changed. An unavailable provider preserves the previous result.
    func refreshIfChanged(_ kind: MaterialKind, defaultYear: Int, control: AcquisitionControl) throws -> Bool {
        guard kind == .timetable || kind == .changes,
              let previous = library?.state.record(for: kind), previous.source.grant != nil else { return false }
        try refresh(kind, control: control)
        guard let current = library?.state.record(for: kind), current.digest != previous.digest else { return false }
        if kind == .changes { try analyzeChanges(defaultYear: defaultYear, control: control) }
        else { try analyzePDF(kind: kind, control: control) }
        return true
    }

    func fetchEvents(control: AcquisitionControl) throws {
        try acquire(.events, control: control) { staged in
            return try readWebPDF(WebPDFDownloader.eventsURL, to: staged, control: control)
        }
    }

    private func acquireSource(_ source: MaterialSource, kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control) { staged in
            if let url = source.remoteURL {
                guard kind == .events, source.grant == nil else { throw MaterialError.invalidState }
                return try readWebPDF(url, to: staged, control: control)
            }
            guard let grant = source.grant else { throw MaterialError.invalidState }
            return try withAccess(grant) { root in
                let target: URL
                if grant.isFolder {
                    guard let name = source.childName, !name.isEmpty, name != ".", name != "..",
                          !name.contains("/"), !name.contains("\\") else { throw MaterialError.invalidFile }
                    target = root.appendingPathComponent(name)
                } else { target = root }
                guard target.pathExtension.lowercased() == kind.fileExtension else { throw MaterialError.invalidFile }
                let result = try copyProviderFile(target, to: staged, kind: kind, control: control)
                return .downloaded((source, target.lastPathComponent, result.0, result.1, result.2))
            }
        }
    }

    private func readWebPDF(_ url: URL, to staged: URL, control: AcquisitionControl) throws -> AcquisitionOutcome {
        let previous = library?.state.record(for: .events)
        let hasCopy = library?.localURL(for: .events).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let cached: WebPDFCacheMetadata?
        if hasCopy, previous?.source.remoteURL == url {
            cached = WebPDFCacheMetadata(etag: previous?.source.remoteETag, lastModified: previous?.source.remoteLastModified)
        } else { cached = nil }
        let response = try WebPDFDownloader.fetch(url, to: staged, cached: cached) { try control.check() }
        let source = MaterialSource(grant: nil, childName: nil, remoteURL: url,
                                    remoteETag: response.metadata.etag, remoteLastModified: response.metadata.lastModified)
        if response.notModified { return .unchanged(source) }
        let result = try readMaterial(staged, copyingTo: nil, kind: .events, control: control)
        return .downloaded((source, "学校行事.pdf", result.0, result.1, response.modifiedAt))
    }

    private func copyProviderFile(_ url: URL, to staged: URL, kind: MaterialKind,
                                  control: AcquisitionControl) throws -> (Int, String, Date?) {
        do {
            return try coordinated(url, control: control) { file in
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw MaterialError.invalidFile }
                let result = try readMaterial(file, copyingTo: staged, kind: kind, control: control)
                return (result.0, result.1, values.contentModificationDate)
            }
        } catch {
            throw (error as? MaterialError) ?? MaterialError.providerReadFailed
        }
    }

    private func readMaterial(_ file: URL, copyingTo staged: URL?, kind: MaterialKind,
                              control: AcquisitionControl) throws -> (Int, String) {
        let input = try FileHandle(forReadingFrom: file)
        defer { try? input.close() }
        var output: FileHandle?
        if let staged = staged {
            guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
            output = try FileHandle(forWritingTo: staged)
        }
        defer { try? output?.close() }
        var hasher = SHA256()
        var count = 0
        var header = Data()
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
            try control.check()
            count += chunk.count
            guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
            if header.count < 8 { header.append(chunk.prefix(8 - header.count)) }
            hasher.update(data: chunk)
            try output?.write(contentsOf: chunk)
        }
        guard count > 0 else { throw MaterialError.invalidFile }
        if kind == .changes {
            guard header.starts(with: [0x50, 0x4b, 0x03, 0x04]) else { throw MaterialError.invalidFile }
        } else {
            guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
        }
        try output?.synchronize()
        return (count, hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    private typealias Acquisition = (source: MaterialSource, name: String, count: Int, digest: String, modified: Date?)

    private enum AcquisitionOutcome {
        case downloaded(Acquisition)
        case unchanged(MaterialSource)
    }

    private func acquire(_ kind: MaterialKind, control: AcquisitionControl,
                         read: (URL) throws -> AcquisitionOutcome) throws {
        guard let library = library else { throw MaterialError.invalidState }
        let staged = library.newStagingURL()
        defer { library.discardStaging(staged) }
        do {
            let result = try read(staged)
            try control.check()
            switch result {
            case .downloaded(let file):
                try library.commit(staged: staged, kind: kind, source: file.source,
                                   originalName: file.name, byteCount: file.count,
                                   digest: file.digest, modifiedAt: file.modified)
            case .unchanged(let source):
                try library.recordUnchanged(kind, source: source)
            }
        } catch {
            let safeError = (error as? MaterialError) ?? .unavailable
            try library.recordFailure(kind, message: safeError.localizedDescription)
            throw safeError
        }
    }
}
