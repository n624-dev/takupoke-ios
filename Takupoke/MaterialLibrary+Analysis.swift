import Foundation

extension MaterialLibrary {
    func saveChangeAnalysis(_ analysis: ChangeAnalysis) throws {
        guard state.record(for: .changes)?.digest == analysis.sourceDigest,
              analysis.version == ChangeAnalysis.parserVersion,
              !analysis.records.isEmpty, analysis.records.count <= ChangeNormalizer.maximumRecords else {
            throw ChangeParseError(code: .storage)
        }
        var next = state
        next.changeAnalysis = analysis
        next.changeParseAttempt = ChangeParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest,
                                                     defaultYear: analysis.defaultYear, failure: nil, parserVersion: ChangeAnalysis.parserVersion)
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
        attempts[analysis.kind.rawValue] = PDFParseAttempt(date: analysis.parsedAt, sourceDigest: analysis.sourceDigest, failure: nil, parserVersion: PDFAnalysis.currentVersion(for: analysis.kind))
        next.pdfAnalyses = analyses
        next.pdfParseAttempts = attempts
        try persist(next)
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

    func recordParseFailure(_ error: ChangeParseError, defaultYear: Int?) throws {
        var next = state
        next.changeParseAttempt = ChangeParseAttempt(date: Date(), sourceDigest: state.record(for: .changes)?.digest,
                                                     defaultYear: defaultYear, failure: error, parserVersion: ChangeAnalysis.parserVersion)
        try persist(next)
    }
}
