import Foundation

final class MaterialWorker {
    let ownerQueue = DispatchQueue(label: "io.github.n624dev.takupoke.materials", qos: .userInitiated)
    private(set) var library: MaterialLibrary?

    init(library: MaterialLibrary? = nil) { self.library = library }
    var changePreview: ChangePreview?
    var timetableReadReport: String?
    var timetableFailure: PDFParseError?
    var recoveryCapture: RecoveryReadCapture?
    var recoveryCapturedStoredName: String?

    func close() { library = nil; changePreview = nil; timetableReadReport = nil; timetableFailure = nil; recoveryCapture = nil; recoveryCapturedStoredName = nil }

    func clearPreview() { changePreview = nil }

    func open() throws {
        if library != nil { return }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite", isDirectory: true))
    }

    func selectFile(_ selection: ScopedMaterialSelection, kind: MaterialKind, control: AcquisitionControl) throws {
        let sameOriginal = kind == .changes &&
            library?.state.record(for: kind)?.source.grant?.references(selection.url) == true
        try acquire(kind, control: control, reuseUnchanged: sameOriginal) { staged in
            try selection.access { url in
                guard url.pathExtension.lowercased() == kind.fileExtension else { throw MaterialError.invalidFile }
                let result = try copyProviderFile(url, to: staged, kind: kind, control: control)
                control.pipelineTicket?.enter(.access)
                let source = MaterialSource(grant: try grant(for: url), childName: nil)
                return .downloaded((source, url.lastPathComponent, result.count, result.digest, result.modified, result.receipt))
            }
        }
    }

    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws {
        guard let source = library?.state.record(for: kind)?.source else { throw MaterialError.unavailable }
        try acquireSource(source, kind: kind, control: control)
    }

    /// Reads the selected provider file again, then reparses only if its content
    /// digest changed, analysis was interrupted, or the parser changed. An unavailable provider preserves the previous result.
    func refreshIfChanged(_ kind: MaterialKind, defaultYear: Int?, control: AcquisitionControl) throws {
        if kind == .changes, defaultYear.map({ (1900...9998).contains($0) }) != true { throw ChangeParseError(code: .defaultYear) }
        guard kind == .timetable || kind == .changes,
              let previous = library?.state.record(for: kind), previous.source.grant != nil else { return }
        try refresh(kind, control: control)
        guard let current = library?.state.record(for: kind) else { return }
        let sameDigest = current.digest == previous.digest
        FileRefreshDiagnostics.shared.record(sameDigest ? .hashSame : .hashChanged,
                                             source: FileRefreshDiagnostics.Source(rawValue: kind.rawValue))
        if sameDigest {
            control.pipelineTicket?.unchanged()
            if kind == .timetable, try library?.recertifyAcceptedTimetable(hash:current.digest) == true { return }
            guard let state = library?.state else { return }
            if kind == .changes {
                guard ChangeParseAttempt.needsAnalysis(digest: current.digest, defaultYear: defaultYear,
                    analysis: state.changeAnalysis, attempt: state.changeParseAttempt, weekdayConsent: current.source.weekdayConsent,
                    rowSkipConsent: current.source.rowSkipConsent, personalSourceIdentity: current.personalChangeIdentity(for: defaultYear)) else { return }
            } else {
            let saved = state.pdfAnalyses?[kind.rawValue]
            let analysis = saved.flatMap { RecoveryConversion.trustsAcquisitionCache($0,hash:current.digest) ? $0:nil }
            let attempt = state.pdfParseAttempts?[kind.rawValue]
            guard PDFParseAttempt.needsAnalysis(digest: current.digest, parserVersion: PDFAnalysis.parserVersion,
                analysisDigest: analysis?.sourceDigest, analysisVersion: analysis?.version, attemptDigest: attempt?.sourceDigest,
                failure: attempt?.failure, attemptVersion: attempt?.parserVersion) else { return }
            }
        }
        if kind == .changes { try analyzeChanges(defaultYear: defaultYear, control: control) }
        else { try analyzePDF(kind: kind, control: control) }
    }

    func fetchEvents(control: AcquisitionControl) throws {
        try acquire(.events, control: control) { staged in
            return try readWebPDF(WebPDFDownloader.eventsURL, to: staged, control: control)
        }
    }

    private func acquireSource(_ source: MaterialSource, kind: MaterialKind, control: AcquisitionControl) throws {
        try acquire(kind, control: control, reuseUnchanged: true) { staged in
            if let url = source.remoteURL {
                guard kind == .events, source.grant == nil else { throw MaterialError.invalidState }
                return try readWebPDF(url, to: staged, control: control)
            }
            guard let grant = source.grant else { throw MaterialError.invalidState }
            return try withAccess(grant) { reference in
                let root = reference.url
                let target: URL
                if grant.isFolder {
                    guard let name = source.childName, !name.isEmpty, name != ".", name != "..",
                          !name.contains("/"), !name.contains("\\") else { throw MaterialError.invalidFile }
                    target = root.appendingPathComponent(name)
                } else { target = root }
                guard target.pathExtension.lowercased() == kind.fileExtension else { throw MaterialError.invalidFile }
                let result = try copyProviderFile(target, to: staged, kind: kind, control: control)
                guard reference.isStale else {
                    return .downloaded((source, target.lastPathComponent, result.count, result.digest, result.modified, result.receipt))
                }
                guard let record = library?.state.record(for: kind), let saved = library?.localURL(for: kind) else {
                    throw MaterialError.bookmarkStale
                }
                var renewed = source
                renewed.grant = try reference.renewedGrant(grant, receivedDigest: result.digest, savedDigest: record.digest) {
                    try readMaterial(saved, copyingTo: nil, kind: kind, control: control).1
                }
                return .downloaded((renewed, record.originalName, result.count, result.digest, result.modified, result.receipt))
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
        return .downloaded((source, "学校行事.pdf", result.0, result.1, response.modifiedAt, nil))
    }

    private typealias Acquisition = (source: MaterialSource, name: String, count: Int, digest: String,
                                     modified: Date?, receipt: SelectedFilePresenter.ReadReceipt?)

    private enum AcquisitionOutcome {
        case downloaded(Acquisition)
        case unchanged(MaterialSource)
    }

    private func acquire(_ kind: MaterialKind, control: AcquisitionControl, reuseUnchanged: Bool = false,
                         read: (URL) throws -> AcquisitionOutcome) throws {
        guard let library = library else { throw MaterialError.invalidState }
        let staged = library.newStagingURL()
        defer { library.discardStaging(staged) }
        do {
            let result = try read(staged)
            control.pipelineTicket?.enter(.validating)
            try control.check()
            switch result {
            case .downloaded(let file):
                let legacySettings = kind == .changes && reuseUnchanged && library.state.record(for:kind)?.digest != file.digest
                    ? try library.legacyChangeSettings(check:control.check) : nil
                try control.check()
                try library.commit(staged: staged, kind: kind, source: file.source,
                                   originalName: file.name, byteCount: file.count,
                                   digest: file.digest, modifiedAt: file.modified, reuseUnchanged: reuseUnchanged,
                                   legacyChangeSettings:legacySettings)
                if let receipt = file.receipt {
                    if let ticket = control.pipelineTicket { ticket.afterCommit { receipt.acknowledge() } }
                    else { receipt.acknowledge() }
                    control.recordProviderAcquisition(kind.rawValue)
                }
            case .unchanged(let source):
                try library.recordUnchanged(kind, source: source)
            }
        } catch {
            let safeError = (error as? MaterialError) ?? .unavailable
            let cancelled: Bool
            if case .cancelled = safeError { cancelled = true } else { cancelled = false }
            let problem = cancelled ? nil : AcquisitionProblem(error)
            try? library.recordFailure(kind, message: safeError.localizedDescription, cancelled: cancelled, problem: problem)
            throw safeError
        }
    }
}
