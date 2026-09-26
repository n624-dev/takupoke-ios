import Foundation

extension MaterialWorker {
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
}
