import Foundation
import SwiftUI

extension SpecialSchedulesModel {
    func runPendingFileRefresh() {
        let requested = fileRefreshQueue.take(ready: ready, busy: busy, blocked: Set(FilePipeline.shared.activeSources.map(\.rawValue)).union(fileMonitor.blockedSources))
        guard !requested.isEmpty else { return }
        perform(success: nil) { store, control, _ in
            try Self.refreshSelectedFiles(store, requested: requested, control: control)
        }
    }

    nonisolated static func refreshSelectedFiles(_ store: SpecialScheduleStore, requested: Set<String>,
                                                 control: AcquisitionControl, force: Bool = false, reason: FilePipeline.Reason = .automatic) throws {
            var failure: Error?
            for kind in SpecialScheduleKind.allCases where requested.contains(kind.rawValue) {
                try control.check()
                guard let source = store.sources[kind] else { continue }
                let diagnosticSource = FileRefreshDiagnostics.Source(rawValue: kind.rawValue)
                FileRefreshDiagnostics.shared.record(.refreshStarted, source: diagnosticSource)
                let record = store.records[kind]
                let saved = record.flatMap { RecoveryConversion.trustsAcquisitionCache($0.analysis,hash:source.digest) ? $0:nil }
                let needsAnalysis = PDFParseAttempt.needsAnalysis(digest: source.digest, parserVersion: SpecialScheduleAnalysis.parserVersion,
                    analysisDigest: saved?.digest, analysisVersion: saved?.analysis.version, attemptDigest: source.digest,
                    failure: source.failure, attemptVersion: source.attemptParserVersion)
                do {
                    try Self.pipeline(store, kind: kind, reason: force ? .manual : reason, control: control) { store, control in
                    if reason == .manual, source.grant == nil { throw MaterialError.accessExpired }
                    var changed = false
                    if let grant = source.grant {
                        let staged = store.newStagingURL()
                        defer { store.discardStaging(staged) }
                        var stale = false
                        let url = try URL(resolvingBookmarkData: grant.bookmark, options: [],
                                          relativeTo: nil, bookmarkDataIsStale: &stale)
                        guard !stale else { throw MaterialError.accessExpired }
                        let selection = ScopedMaterialSelection(url)
                        let (name, count, digest, receipt) = try Self.copy(selection, to: staged, kind: kind, control: control)
                        FileRefreshDiagnostics.shared.record(digest == source.digest ? .hashSame : .hashChanged,
                                                             source: diagnosticSource)
                        control.pipelineTicket?.enter(.validating)
                        try control.check()
                        if digest == source.digest, !force, store.hasSelectedFile(kind) {
                            control.pipelineTicket?.unchanged()
                            try store.recordSuccessfulCheck(kind, digest: digest, originalName:name)
                        } else {
                            try store.saveSelection(staged: staged, kind: kind, originalName: name,
                                                    byteCount: count, digest: digest, grant: grant)
                            changed = true
                        }
                        if let ticket = control.pipelineTicket { ticket.afterCommit { receipt.acknowledge() } }
                    else { receipt.acknowledge() }
                        control.recordProviderAcquisition(kind.rawValue)
                    }
                    // Check the provider before retrying an older local parser failure.
                    // A malformed old copy must not prevent acquiring its replacement.
                    if changed || needsAnalysis || force {
                        guard let selectedURL = store.selectedURL(for: kind),
                              let selectedSource = store.sources[kind] else { throw MaterialError.unavailable }
                        control.pipelineTicket?.enter(.parsing)
                        let parseCheck: () throws -> Void = {
                            do { try control.check() } catch { throw PDFParseError(code: .cancelled) }
                        }
                        let pages = try PDFKitReader.readSpecial(selectedURL, check: parseCheck)
                        let analysis = try SpecialScheduleParser.parse(pages, kind: kind,
                                                                       digest: selectedSource.digest,
                                                                       name: selectedSource.originalName,
                                                                       check: parseCheck)
                        control.pipelineTicket?.enter(.validating)
                        try parseCheck()
                        try store.saveAnalysis(analysis); control.pipelineTicket?.parsed()
                    }
                    }
                } catch {
                    if (error as? FilePipeline.Failure) == .cancelled || (error as? FilePipeline.Failure) == .stale {
                        try control.check()
                        FileRefreshDiagnostics.shared.record(.cancelled, source: diagnosticSource)
                        failure = error
                        continue
                    }
                    if FileOperationOutcome.isCancellation(error) {
                        FileRefreshDiagnostics.shared.record(.cancelled, source: diagnosticSource)
                        throw error
                    }
                    FileRefreshDiagnostics.shared.record(.refreshFailed, source: diagnosticSource)
                    failure = error
                }
            }
            if let failure { throw failure }
    }
}
