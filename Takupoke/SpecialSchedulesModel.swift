import CryptoKit
import Foundation
import SwiftUI

/// Written only by the serial import worker, then read once on the main queue.
private final class SpecialDiagnosticCapture {
    var report: String?
    var failure: PDFParseError?
}

@MainActor
final class SpecialSchedulesModel: ObservableObject {
    @Published private(set) var records: [SpecialScheduleKind: SpecialScheduleRecord] = [:]
    @Published private(set) var urls: [SpecialScheduleKind: URL] = [:]
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failed = false
    @Published private(set) var fullReadReports: [SpecialScheduleKind: String] = [:]

    private let queue = DispatchQueue(label: "io.github.n624dev.takupoke.special-schedules", qos: .userInitiated)
    private var store: SpecialScheduleStore?
    private var control: AcquisitionControl?

    func loadIfNeeded() {
        guard !ready, !busy else { return }
        perform(success: nil) { store, _, _ in _ = store }
    }

    func importPDF(_ selection: ScopedMaterialSelection, kind: SpecialScheduleKind) {
        guard !busy else { return }
        fullReadReports[kind] = nil
        perform(success: "\(kind.title)を解析して保存しました。", reporting: kind) { store, control, capture in
            let diagnostics = PDFDiagnosticRecorder()
            diagnostics.record(.start)
            let staged = store.newStagingURL()
            defer { store.discardStaging(staged) }
            var sourceName: String?
            var succeeded = false
            var inspected: PDFFullReadDiagnostic?
            defer {
                let diagnosticURL = succeeded ? (store.savedURL(for: kind) ?? staged) : staged
                let full = inspected ?? PDFKitReader.diagnose(diagnosticURL, check: { try control.check() })
                diagnostics.record(.complete)
                capture.report = SpecialScheduleDiagnosticReport.make(full, kind: kind,
                    sourceName: sourceName, succeeded: succeeded,
                    failure: capture.failure, trace: diagnostics.snapshot)
            }
            do {
                diagnostics.record(.material)
                let (name, count, digest) = try Self.copy(selection, to: staged, control: control)
                sourceName = name
                let pages = try PDFKitReader.read(staged, kind: .timetable,
                                                  diagnostics: diagnostics, check: { try control.check() })
                diagnostics.record(.parse, values: [Double(pages.count)])
                let analysis = try SpecialScheduleParser.parse(pages, kind: kind, digest: digest,
                                                               name: name, check: { try control.check() })
                diagnostics.record(.parseComplete, values: [Double(analysis.lessons.count)])
                inspected = PDFKitReader.diagnose(staged, check: { try control.check() })
                try control.check()
                diagnostics.record(.save)
                try store.save(staged: staged, analysis: analysis, originalName: name,
                               byteCount: count, digest: digest)
                diagnostics.record(.saveComplete)
                succeeded = true
            } catch {
                capture.failure = diagnostics.attaching(to: error)
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
            let result = Result { () throws -> (SpecialScheduleStore, [SpecialScheduleKind: SpecialScheduleRecord], [SpecialScheduleKind: URL]) in
                let store: SpecialScheduleStore
                if let existing = existingStore { store = existing }
                else {
                    let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
                    store = try SpecialScheduleStore(root: base.appendingPathComponent("SpecialSchedulesSQLite", isDirectory: true))
                }
                try operation(store, control, capture)
                let urls = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.compactMap { kind in
                    store.savedURL(for: kind).map { (kind, $0) }
                })
                return (store, store.records, urls)
            }
            DispatchQueue.main.async {
                self.busy = false
                self.control = nil
                if let kind { self.fullReadReports[kind] = capture.report }
                switch result {
                case .success(let snapshot):
                    self.store = snapshot.0
                    self.records = snapshot.1
                    self.urls = snapshot.2
                    self.ready = true
                    self.message = success
                case .failure(let error):
                    self.failed = true
                    self.message = (error as? PDFParseError)?.localizedDescription
                        ?? (error as? MaterialError)?.localizedDescription
                        ?? "試験資料を保存できませんでした。前回の解析結果は保持しています。"
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
