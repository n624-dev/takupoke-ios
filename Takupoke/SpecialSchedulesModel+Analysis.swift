import SwiftUI

extension SpecialSchedulesModel {
    /// Manual telemetry is deliberately separate from analysis saving and from
    /// the internal full-text export. Re-reads only the saved original locally.
    func diagnoseReturnLesson(_ lesson: SpecialScheduleLesson) {
        perform(success: "位置情報を取得しました。コピーして開発相談へ貼り付けてください。") { store, control, capture in
            guard let url = store.savedURL(for:.examReturn),
                  let record = store.records[.examReturn], record.analysis.lessons.contains(lesson) else {
                throw PDFParseError(code:.storage)
            }
            let check: () throws -> Void = { try control.check() }
            let pages = try PDFKitReader.readSpecial(url,check:check)
            let recorder = PDFReturnGeometryRecorder(lesson:lesson)
            _ = try PDF239SpecialScheduleParser.parse(pages,kind:.examReturn,digest:record.digest,
                name:record.originalName,geometry:recorder,check:check)
            try check()
            guard let report = recorder.report() else { throw PDFParseError(code:.unsupported) }
            capture.positionsReport = report
        }
    }

    func analyze(kind: SpecialScheduleKind, selection: ScopedMaterialSelection?) {
        guard !busy else { return }
        fullReadReports[kind] = nil
        perform(success: "\(kind.title)を解析して保存しました。", reporting: kind) { store, control, capture in
            let parseCheck: () throws -> Void = {
                do { try control.check() } catch { throw PDFParseError(code: .cancelled) }
            }
            let diagnostics = PDFDiagnosticRecorder(parserVersion: SpecialScheduleAnalysis.parserVersion)
            diagnostics.record(.start)
            let staged = selection.map { _ in store.newStagingURL() }
            defer { if let staged { store.discardStaging(staged) } }
            var diagnosticURL: URL?
            var sourceName: String?
            var succeeded = false
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
            var inspected: PDFFullReadDiagnostic?
            defer {
                let full = inspected ?? diagnosticURL.map { PDFKitReader.diagnose($0, check: parseCheck) }
                    ?? PDFFullReadDiagnostic()
                diagnostics.record(.complete)
                capture.report = SpecialScheduleDiagnosticReport.make(full, kind: kind,
                    sourceName: sourceName, succeeded: succeeded,
                    failure: capture.failure, trace: diagnostics.snapshot)
            }
#endif
            do {
                if let selection, let staged {
                    diagnostics.record(.material)
                    diagnosticURL = staged
                    let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
                    sourceName = name
                    let grant = try selection.access { url in
                        SourceGrant(bookmark: try url.bookmarkData(options: .minimalBookmark,
                            includingResourceValuesForKeys: nil, relativeTo: nil),
                            name: url.lastPathComponent, isFolder: false)
                    }
                    try store.saveSelection(staged: staged, kind: kind, originalName: name,
                                            byteCount: count, digest: digest, grant: grant)
                }
                guard let source = store.sources[kind], let selectedURL = store.selectedURL(for: kind) else {
                    throw PDFParseError(code: .unreadable)
                }
                diagnosticURL = selectedURL
                sourceName = source.originalName
                let readerCapture = RecoveryReadCapture()
                defer { capture.recoveryPages = readerCapture.pages }
                let pages = try PDFKitReader.readSpecial(selectedURL, diagnostics: diagnostics,
                                                         capture: readerCapture, check: parseCheck)
                diagnostics.record(.parse, values: [Double(pages.count)])
                let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: source.digest,
                                                               name: source.originalName, check: parseCheck)
                diagnostics.record(.parseComplete, values: [Double(analysis.lessons.count)])
#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
                inspected = PDFKitReader.diagnose(selectedURL, check: parseCheck)
#endif
                try parseCheck()
                diagnostics.record(.save)
                do { try store.saveAnalysis(analysis) }
                catch { throw PDFParseError(code: .storage) }
                diagnostics.record(.saveComplete)
                succeeded = true
            } catch {
                capture.failure = diagnostics.attaching(to: error)
                if let selectedURL = store.selectedURL(for: kind), diagnosticURL == selectedURL,
                   let failure = capture.failure {
                    try? store.recordFailure(failure, kind: kind)
                }
                throw capture.failure!
            }
        }
    }
}
