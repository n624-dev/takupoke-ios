import Foundation

extension MaterialLibrary {
    struct PipelineSnapshot {
        let state: MaterialLibraryState
        let inputs: [(URL, String)]
        func open(at root: URL) throws -> MaterialLibrary {
            let copy = try MaterialLibrary(root: root)
            for (url, name) in inputs { try PipelineWorkspace.copyIfPresent(url, to: copy.files.appendingPathComponent(name)) }
            try copy.seedPipelineSnapshot(state)
            return copy
        }
    }
    func pipelineSnapshot(_ kind: MaterialKind? = nil) -> PipelineSnapshot {
        var frozen = state
        if let kind {
            frozen.records = state.records.filter { $0.kind == kind }
            frozen.pdfAnalyses = state.pdfAnalyses?.filter { $0.key == kind.rawValue }
            frozen.pdfParseAttempts = state.pdfParseAttempts?.filter { $0.key == kind.rawValue }
            if kind != .changes { frozen.changeAnalysis = nil; frozen.changeParseAttempt = nil }
        }
        return PipelineSnapshot(state: frozen, inputs: frozen.records.compactMap { record in
            localURL(for: record.kind).map { ($0, record.storedName) }
        })
    }
    func isolatedCopy(at root: URL) throws -> MaterialLibrary { try pipelineSnapshot().open(at: root) }
    func pipelineIdentity(_ kind: MaterialKind) throws -> Data {
        struct Identity: Encodable {
            let record: MaterialRecord?
            let changes: ChangeAnalysis?
            let pdf: PDFAnalysis?
            let changeAttempt: ChangeParseAttempt?
            let pdfAttempt: PDFParseAttempt?
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(Identity(record: state.record(for: kind), changes: kind == .changes ? state.changeAnalysis : nil,
            pdf: state.pdfAnalyses?[kind.rawValue], changeAttempt: kind == .changes ? state.changeParseAttempt : nil,
            pdfAttempt: state.pdfParseAttempts?[kind.rawValue]))
    }
    /// Import only this file's state; another file may have committed meanwhile.
    func acceptPipeline(_ copy: MaterialLibrary, kind: MaterialKind, expected: Data, ticket: FilePipeline.Ticket) throws {
        guard try pipelineIdentity(kind) == expected else { throw FilePipeline.Failure.stale }
        try ticket.beginCommit(period: .current())
        if copy.metadataOnlyAcquisition == kind, let record = copy.state.record(for: kind) {
            var next = state
            next.records.removeAll { $0.kind == kind }
            next.records.append(record)
            next.attempts[kind.rawValue] = copy.state.attempts[kind.rawValue]
            try persistUnchangedAcquisition(next, kind: kind, moveToEnd: true)
            ticket.didCommit()
            return
        }
        let oldNames = Set(state.records.filter { $0.kind == kind }.map(\.storedName))
        var next = state
        var imported: URL?
        if let record = copy.state.record(for: kind) {
            if record.storedName != state.record(for: kind)?.storedName {
                guard let input = copy.localURL(for: kind) else { throw MaterialError.invalidState }
                let destination = files.appendingPathComponent(record.storedName)
                // Both are application-support files on the same volume. The
                // byte copy happened in the isolated job; only rename is live.
                try FileManager.default.moveItem(at: input, to: destination)
                imported = destination
            }
            next.records.removeAll { $0.kind == kind }; next.records.append(record)
        }
        next.attempts[kind.rawValue] = copy.state.attempts[kind.rawValue]
        if kind == .changes {
            next.changeAnalysis = copy.state.changeAnalysis; next.changeParseAttempt = copy.state.changeParseAttempt
        } else {
            if next.pdfAnalyses == nil { next.pdfAnalyses = [:] }
            if next.pdfParseAttempts == nil { next.pdfParseAttempts = [:] }
            next.pdfAnalyses?[kind.rawValue] = copy.state.pdfAnalyses?[kind.rawValue]
            next.pdfParseAttempts?[kind.rawValue] = copy.state.pdfParseAttempts?[kind.rawValue]
        }
        do { try persist(next); ticket.didCommit(); retirePipelineFiles(oldNames) }
        catch { if let imported { try? FileManager.default.removeItem(at: imported) }; throw error }
    }
}
