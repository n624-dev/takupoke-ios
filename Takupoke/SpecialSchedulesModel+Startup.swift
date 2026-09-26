import Foundation
import SwiftUI

extension SpecialSchedulesModel {
    func checkSelectedFilesAtStartup() {
        guard ready, !busy, !checkedAtStartup else { return }
        checkedAtStartup = true
        perform(success: nil) { store, control, _ in
            var failure: Error?
            for kind in SpecialScheduleKind.allCases {
                guard let source = store.sources[kind] else { continue }
                let needsAnalysis = store.records[kind].map {
                    $0.analysis.version < SpecialScheduleAnalysis.parserVersion
                } ?? false
                do {
                    if needsAnalysis {
                        guard let selectedURL = store.selectedURL(for: kind) else { throw MaterialError.unavailable }
                        let pages = try PDFKitReader.readSpecial(selectedURL, check: { try control.check() })
                        let analysis = try SpecialScheduleParser.parse(pages, kind: kind,
                                                                       digest: source.digest,
                                                                       name: source.originalName,
                                                                       check: { try control.check() })
                        try store.saveAnalysis(analysis)
                    }
                    if let grant = source.grant {
                        let staged = store.newStagingURL()
                        defer { store.discardStaging(staged) }
                        var stale = false
                        let url = try URL(resolvingBookmarkData: grant.bookmark, options: [],
                                          relativeTo: nil, bookmarkDataIsStale: &stale)
                        guard !stale else { throw MaterialError.accessExpired }
                        let selection = ScopedMaterialSelection(url)
                        let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
                        if digest == source.digest {
                            try store.recordSuccessfulCheck(kind, digest: digest)
                        } else {
                            try store.saveSelection(staged: staged, kind: kind, originalName: name,
                                                    byteCount: count, digest: digest, grant: grant)
                            guard let selectedURL = store.selectedURL(for: kind),
                                  let selectedSource = store.sources[kind] else { throw MaterialError.unavailable }
                            let pages = try PDFKitReader.readSpecial(selectedURL, check: { try control.check() })
                            let analysis = try SpecialScheduleParser.parse(pages, kind: kind,
                                                                           digest: selectedSource.digest,
                                                                           name: selectedSource.originalName,
                                                                           check: { try control.check() })
                            try store.saveAnalysis(analysis)
                        }
                    }
                } catch {
                    failure = error
                    let parseFailure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
                    try? store.recordFailure(parseFailure, kind: kind)
                }
            }
            if let failure { throw failure }
        }
    }
}
