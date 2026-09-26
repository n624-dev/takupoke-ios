import SwiftUI

extension SpecialSchedulesModel {
    func analyze(kind: SpecialScheduleKind, selection: ScopedMaterialSelection?) {
        guard !busy else { return }
        fullReadReports[kind] = nil
        perform(success: "\(kind.title)を解析して保存しました。", reporting: kind) { store, control, capture in
            let diagnostics = PDFDiagnosticRecorder(parserVersion: SpecialScheduleAnalysis.parserVersion)
            diagnostics.record(.start)
            let staged = selection.map { _ in store.newStagingURL() }
            defer { if let staged { store.discardStaging(staged) } }
            var diagnosticURL: URL?
            var sourceName: String?
            var succeeded = false
            var inspected: PDFFullReadDiagnostic?
            defer {
                let full = inspected ?? diagnosticURL.map { PDFKitReader.diagnose($0, check: { try control.check() }) }
                    ?? PDFFullReadDiagnostic()
                diagnostics.record(.complete)
                capture.report = SpecialScheduleDiagnosticReport.make(full, kind: kind,
                    sourceName: sourceName, succeeded: succeeded,
                    failure: capture.failure, trace: diagnostics.snapshot)
            }
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
                let pages = try PDFKitReader.readSpecial(selectedURL, diagnostics: diagnostics,
                                                         check: { try control.check() })
                diagnostics.record(.parse, values: [Double(pages.count)])
                let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: source.digest,
                                                               name: source.originalName, check: { try control.check() })
                diagnostics.record(.parseComplete, values: [Double(analysis.lessons.count)])
                inspected = PDFKitReader.diagnose(selectedURL, check: { try control.check() })
                try control.check()
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
