import Foundation

extension MaterialLibrary {
    /// Hide a rejected recovery projection without deleting its stored audit.
    /// Strict results have no recovery payload and retain their existing path.
    static func displayableTimetables(_ state: MaterialLibraryState) -> (state:MaterialLibraryState,rejected:Set<String>) {
        var visible = state, rejected = Set<String>()
        for (key,analysis) in state.pdfAnalyses ?? [:] where analysis.recovery != nil {
            if let proved = try? RecoveryValidator.recertifiedTimetable(analysis,hash:analysis.sourceDigest) { visible.pdfAnalyses?[key] = proved }
            else { visible.pdfAnalyses?.removeValue(forKey:key); rejected.insert(key) }
        }
        return (visible,rejected)
    }

    func saveChangeAnalysis(_ analysis: ChangeAnalysis, authorizeWeekdayCorrection: Bool = false, authorizeRowSkip: Bool = false) throws {
        guard state.record(for: .changes)?.digest == analysis.sourceDigest,
              analysis.version == ChangeAnalysis.parserVersion,
              !analysis.records.isEmpty, analysis.records.count <= ChangeNormalizer.maximumRecords else {
            throw ChangeParseError(code: .storage)
        }
        var next = state
        if let consent = analysis.weekdayConsent {
            guard consent.matches(digest: analysis.sourceDigest, defaultYear: analysis.defaultYear),
                  authorizeWeekdayCorrection || state.record(for: .changes)?.source.weekdayConsent == consent,
                  let index = next.records.firstIndex(where: { $0.kind == .changes }) else { throw ChangeParseError(code: .storage) }
            next.records[index].source.weekdayConsent = consent
        }
        if let consent = analysis.rowSkipConsent {
            guard let index = next.records.firstIndex(where: { $0.kind == .changes }),
                  consent.matches(sourceIdentity: next.records[index].source.selectionID ?? next.records[index].storedName,
                                  digest: analysis.sourceDigest, defaultYear: analysis.defaultYear),
                  authorizeRowSkip || state.records[index].source.rowSkipConsent == consent else { throw ChangeParseError(code: .storage) }
            next.records[index].source.rowSkipConsent = consent
        } else if let index = next.records.firstIndex(where: { $0.kind == .changes }),
                  next.records[index].source.rowSkipConsent != nil {
            // A success must never silently omit the exclusions used to obtain it.
            throw ChangeParseError(code: .storage)
        }
        next.changeAnalysis = analysis
        next.changeParseAttempt = ChangeParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest,
                                                     defaultYear: analysis.defaultYear, failure: nil, parserVersion: ChangeAnalysis.parserVersion)
        try persist(next)
    }

    func savePDFAnalysis(_ analysis: PDFAnalysis) throws {
        guard Self.validPDFAnalysis(analysis), state.record(for: analysis.kind)?.digest == analysis.sourceDigest else {
            throw PDFParseError(code: .storage)
        }
        if analysis.recovery?.previousAcceptance != nil {
            guard let old = state.pdfAnalyses?[analysis.kind.rawValue],
                  let proved = try RecoveryValidator.recertifiedTimetable(old,hash:analysis.sourceDigest),
                  try JSONEncoder.sortedRecoveryEncoding(proved) == JSONEncoder.sortedRecoveryEncoding(analysis) else { throw PDFParseError(code:.storage) }
        }
        var next = state
        var analyses = next.pdfAnalyses ?? [:]
        var attempts = next.pdfParseAttempts ?? [:]
        analyses[analysis.kind.rawValue] = analysis
        attempts[analysis.kind.rawValue] = PDFParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest, failure: nil, parserVersion: PDFAnalysis.currentVersion(for: analysis.kind))
        next.pdfAnalyses = analyses
        next.pdfParseAttempts = attempts
        try persist(next)
    }

    /// Runs on the existing serial acquisition worker. The database's
    /// generation-checked transaction re-reads the previous stored snapshot.
    @discardableResult
    func recertifyAcceptedTimetable(hash: String) throws -> Bool {
        guard state.record(for:.timetable)?.digest == hash,
              let original = state.pdfAnalyses?[MaterialKind.timetable.rawValue],
              let current = try RecoveryValidator.recertifiedTimetable(original,hash:hash) else { return false }
        guard current.version != original.version || current.recovery != original.recovery else { return true }
        var next = state
        next.pdfAnalyses?[MaterialKind.timetable.rawValue] = current
        next.pdfParseAttempts?[MaterialKind.timetable.rawValue] = PDFParseAttempt(date:original.parsedAt,sourceDigest:hash,failure:nil,parserVersion:PDFAnalysis.parserVersion)
        try persist(next)
        return true
    }

    func recordPDFFailure(_ error: PDFParseError, kind: MaterialKind) throws {
        var next = state
        var attempts = next.pdfParseAttempts ?? [:]
        attempts[kind.rawValue] = PDFParseAttempt(date: Date(), sourceDigest: state.record(for: kind)?.digest, failure: error,
            recoveryJob: kind == .timetable && RecoveryPolicy.eligible(error) && !(state.pdfAnalyses?[kind.rawValue]?.version == PDFAnalysis.currentVersion(for:kind) && RecoveryValidator.previouslyAccepted(state.pdfAnalyses?[kind.rawValue]?.recovery, hash:state.record(for:kind)?.digest ?? "")) ? state.record(for: kind).map {
                RecoveryJob(pdfHash: $0.digest, kind: .timetable, state: .pending, createdAt: Date())
            } : nil, parserVersion: PDFAnalysis.currentVersion(for: kind))
        next.pdfParseAttempts = attempts
        try persist(next)
    }

    func clearWeekdayConsent() throws {
        guard let index = state.records.firstIndex(where: { $0.kind == .changes }), state.records[index].source.weekdayConsent != nil else { return }
        var next = state; next.records[index].source.weekdayConsent = nil
        try persist(next)
    }

    func clearRowSkipConsent() throws {
        guard let index = state.records.firstIndex(where: { $0.kind == .changes }), state.records[index].source.rowSkipConsent != nil else { return }
        var next = state; next.records[index].source.rowSkipConsent = nil
        try persist(next)
    }

    func recordParseFailure(_ error: ChangeParseError, defaultYear: Int?) throws {
        var next = state
        next.changeParseAttempt = ChangeParseAttempt(date: Date(), sourceDigest: state.record(for: .changes)?.digest,
                                                     defaultYear: defaultYear, failure: error, parserVersion: ChangeAnalysis.parserVersion)
        try persist(next)
    }
}
