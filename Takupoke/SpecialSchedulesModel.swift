import CryptoKit
import Foundation
import SwiftUI

/// Written only by the serial import worker, then read once on the main queue.
private final class SpecialDiagnosticCapture {
    var report: String?
    var failure: PDFParseError?
    var store: SpecialScheduleStore?
}

@MainActor
final class SpecialSchedulesModel: ObservableObject {
    @Published private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    @Published private(set) var sources: [SpecialScheduleKind: SpecialScheduleSource] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var fullReadReports: [SpecialScheduleKind: String] = [:]

    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.special-schedules", qos: .userInitiated)
    private var store: SpecialScheduleStore?
    private var control: AcquisitionControl?
    private var checkedAtStartup = false

    func loadIfNeeded() {
        guard !ready, !busy else { return }
        perform(success: nil) { store, _, _ in _ = store }
    }

    func importPDF(_ selection: ScopedMaterialSelection, kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: selection)
    }

    func analyzePDF(_ kind: SpecialScheduleKind) {
        analyze(kind: kind, selection: nil)
    }

    func checkSelectedFilesAtStartup() {
        guard ready, !busy, !checkedAtStartup else { return }
        checkedAtStartup = true
        perform(success: nil) { store, control, _ in
            var failure: Error?
            for kind in SpecialScheduleKind.allCases {
                guard let source = store.sources[kind], let grant = source.grant else { continue }
                let staged = store.newStagingURL()
                defer { store.discardStaging(staged) }
                do {
                    var stale = false
                    let url = try URL(resolvingBookmarkData: grant.bookmark, options: [],
                                      relativeTo: nil, bookmarkDataIsStale: &stale)
                    guard !stale else { throw MaterialError.accessExpired }
                    let selection = ScopedMaterialSelection(url)
                    let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
                    guard digest != source.digest else {
                        try store.recordSuccessfulCheck(kind, digest: digest)
                        continue
                    }
                    try store.saveSelection(staged: staged, kind: kind, originalName: name,
                                            byteCount: count, digest: digest, grant: grant)
                    guard let selectedURL = store.selectedURL(for: kind) else { throw MaterialError.unavailable }
                    let pages = try PDFKitReader.readSpecial(selectedURL, check: { try control.check() })
                    let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: digest,
                                                                   name: name, check: { try control.check() })
                    try store.saveAnalysis(analysis)
                } catch {
                    failure = error
                    let parseFailure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
                    try? store.recordFailure(parseFailure, kind: kind)
                }
            }
            if let failure { throw failure }
        }
    }

    private func analyze(kind: SpecialScheduleKind, selection: ScopedMaterialSelection?) {
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

    func cancel() {
        control?.cancel()
        message = "中止を要求しました。処理の終了を待っています。"
    }

    private func perform(success: String?, reporting kind: SpecialScheduleKind? = nil,
                         operation: @escaping (SpecialScheduleStore, AcquisitionControl,
                                               SpecialDiagnosticCapture) throws -> Void) {
        guard !busy else { return }
        busy = true
        failed = false
        message = nil
        let control = AcquisitionControl()
        self.control = control
        let existingStore = store
        queue.async {
            let capture = SpecialDiagnosticCapture()
            let result = Result { () throws -> Void in
                let store: SpecialScheduleStore
                if let existing = existingStore { store = existing }
                else {
                    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
                    store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite", isDirectory: true))
                }
                capture.store = store
                try operation(store, control, capture)
            }
            DispatchQueue.main.async {
                self.busy = false
                self.control = nil
                if let kind { self.fullReadReports[kind] = capture.report }
                if let store = capture.store {
                    self.store = store
                    self.records = store.records
                    self.sources = store.sources
                    self.urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                        store.selectedURL(for: kind).map { (kind, $0) }
                    })
                    self.ready = true
                }
                switch result {
                case .success:
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "\(kind?.title ?? "試験時間割・試験返却時間割")を保存できませんでした。前回の解析結果は保持しています。"
                }
            }
        }
    }

    private nonisolated static func copy(_ selection: ScopedMaterialSelection, to staged: URL,
                                         control: AcquisitionControl) throws -> (String, Int, String) {
        try selection.access { url in
            try control.check()
            let coordinator = NSFileCoordinator(filePresenter: nil)
            control.attach(coordinator)
            defer { control.attach(nil) }
            var error: NSError?
            var result: Result<(String, Int, String), Error>?
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { safeURL in
                result = Result {
                    try control.check()
                    let values = try safeURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true,
                          url.pathExtension.lowercased() == "pdf" else { throw MaterialError.invalidFile }
                    let input = try FileHandle(forReadingFrom: safeURL)
                    defer { try? input.close() }
                    guard FileManager.default.createFile(atPath: staged.path, contents: nil) else { throw MaterialError.unavailable }
                    let output = try FileHandle(forWritingTo: staged)
                    defer { try? output.close() }
                    var hasher = SHA256()
                    var count = 0
                    var header = Data()
                    while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
                        try control.check()
                        count += chunk.count
                        guard count <= MaterialLibrary.maximumBytes else { throw MaterialError.tooLarge }
                        if header.count < 5 { header.append(chunk.prefix(5 - header.count)) }
                        hasher.update(data: chunk)
                        try output.write(contentsOf: chunk)
                    }
                    guard header.starts(with: Array("%PDF-".utf8)) else { throw MaterialError.invalidFile }
                    try output.synchronize()
                    return (url.lastPathComponent, count,
                            hasher.finalize().map { String(format: "%02x", $0) }.joined())
                }
            }
            try control.check()
            if let error { throw error }
            guard let result else { throw MaterialError.unavailable }
            return try result.get()
        }
    }
}
