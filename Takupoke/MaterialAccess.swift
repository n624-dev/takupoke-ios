import Foundation

final class MaterialWorker {
    private(set) var library: MaterialLibrary?
    var changePreview: ChangePreview?
    var timetableReadReport: String?
    var timetableFailure: PDFParseError?

    func close() { library = nil; changePreview = nil; timetableReadReport = nil; timetableFailure = nil }

    func clearPreview() { changePreview = nil }

    func open() throws {
        if library != nil { return }
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        library = try LocalMaterialDatabase.openLibrary(root: base.appendingPathComponent("SchoolMaterialsSQLite", isDirectory: true))
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
