import Foundation
import SwiftUI

extension SpecialSchedulesModel {
    func runPendingFileRefresh() {
        let requested = fileRefreshQueue.take(ready: ready, busy: busy)
        guard !requested.isEmpty else { return }
        perform(success: nil) { store, control, _ in
            try Self.refreshSelectedFiles(store, requested: requested, control: control)
        }
    }

    nonisolated static func refreshSelectedFiles(_ store: SpecialScheduleStore, requested: Set<String>,
                                                 control: AcquisitionControl) throws {
            var failure: Error?
            for kind in SpecialScheduleKind.allCases where requested.contains(kind.rawValue) {
                try control.check()
                guard let source = store.sources[kind] else { continue }
                let diagnosticSource = FileRefreshDiagnostics.Source(rawValue: kind.rawValue)
                FileRefreshDiagnostics.shared.record(.refreshStarted, source: diagnosticSource)
                let saved = store.records[kind]
                let needsAnalysis = PDFParseAttempt.needsAnalysis(digest: source.digest, parserVersion: SpecialScheduleAnalysis.parserVersion,
                    analysisDigest: saved?.digest, analysisVersion: saved?.analysis.version, attemptDigest: source.digest,
                    failure: source.failure, attemptVersion: source.attemptParserVersion)
                do {
                    var changed = false
                    if let grant = source.grant {
                        let staged = store.newStagingURL()
                        defer { store.discardStaging(staged) }
                        var stale = false
                        let url = try URL(resolvingBookmarkData: grant.bookmark, options: [],
                                          relativeTo: nil, bookmarkDataIsStale: &stale)
                        guard !stale else { throw MaterialError.accessExpired }
                        let selection = ScopedMaterialSelection(url)
                        let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
                        FileRefreshDiagnostics.shared.record(digest == source.digest ? .hashSame : .hashChanged,
                                                             source: diagnosticSource)
                        if digest == source.digest {
                            try store.recordSuccessfulCheck(kind, digest: digest, originalName:name)
                        } else {
                            try store.saveSelection(staged: staged, kind: kind, originalName: name,
                                                    byteCount: count, digest: digest, grant: grant)
                            changed = true
                        }
                    }
                    // Check the provider before retrying an older local parser failure.
                    // A malformed old copy must not prevent acquiring its replacement.
                    if changed || needsAnalysis {
                        guard let selectedURL = store.selectedURL(for: kind),
                              let selectedSource = store.sources[kind] else { throw MaterialError.unavailable }
                        let parseCheck: () throws -> Void = {
                            do { try control.check() } catch { throw PDFParseError(code: .cancelled) }
                        }
                        let pages = try PDFKitReader.readSpecial(selectedURL, check: parseCheck)
                        let analysis = try SpecialScheduleParser.parse(pages, kind: kind,
                                                                       digest: selectedSource.digest,
                                                                       name: selectedSource.originalName,
                                                                       check: parseCheck)
                        try parseCheck()
                        try store.saveAnalysis(analysis)
                    }
                } catch {
                    FileRefreshDiagnostics.shared.record(.refreshFailed, source: diagnosticSource)
                    failure = error
                    if let parseFailure = error as? PDFParseError { try? store.recordFailure(parseFailure, kind: kind) }
                    else { try? store.recordAcquisitionFailure(kind: kind) }
                }
            }
            if let failure { throw failure }
    }
}
