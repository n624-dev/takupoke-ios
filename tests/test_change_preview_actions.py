"""Execute production preview callbacks and admission methods with fake dispatch."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]


class ChangePreviewActionTests(unittest.TestCase):
    def test_special_provider_refresh_keeps_cancellation_separate_from_failure(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production special schedule refresh")
        refresh = (ROOT / "Takupoke/SpecialSchedulesModel+Startup.swift").read_text(encoding="utf-8")
        access = (ROOT / "Takupoke/ScopedMaterialSelection.swift").read_text(encoding="utf-8")
        program = r'''import Foundation
enum MaterialError: Error { case cancelled, unavailable, accessExpired, providerReadFailed }
enum SpecialScheduleKind: String, CaseIterable { case exam, examReturn }
struct PDFParseError: Error { enum Code { case cancelled }; let code: Code }
final class NSFileCoordinator { func cancel() {} }
struct URL {
    init() {}
    init(resolvingBookmarkData: Data, options: [Int], relativeTo: URL?, bookmarkDataIsStale: inout Bool) throws {}
}
struct ScopedMaterialSelection { init(_ url: URL) {} }
struct Grant { let bookmark = Data() }
struct Source {
    let digest = "saved", originalName = "fictional.pdf"
    let grant: Grant? = Grant()
    let failure: PDFParseError? = nil
    let attemptParserVersion: Int? = SpecialScheduleAnalysis.parserVersion
}
struct SpecialScheduleAnalysis { static let parserVersion = 1; let version = SpecialScheduleAnalysis.parserVersion }
struct Saved { let digest = "saved", analysis = SpecialScheduleAnalysis() }
enum RecoveryConversion { static func trustsAcquisitionCache(_ value: SpecialScheduleAnalysis, hash: String) -> Bool { true } }
enum PDFParseAttempt {
    static func needsAnalysis(digest: String, parserVersion: Int, analysisDigest: String?, analysisVersion: Int?,
                              attemptDigest: String?, failure: PDFParseError?, attemptVersion: Int?) -> Bool { false }
}
enum PDFKitReader {
    static func readSpecial(_ url: URL, check: () throws -> Void) throws -> [Int] { preconditionFailure("Expected no parsing") }
}
enum SpecialScheduleParser {
    static func parse(_ pages: [Int], kind: SpecialScheduleKind, digest: String, name: String,
                      check: () throws -> Void) throws -> SpecialScheduleAnalysis { preconditionFailure("Expected no parsing") }
}
final class FileRefreshDiagnostics {
    enum Event { case refreshStarted, refreshFailed, hashSame, hashChanged, cancelled }
    struct Source { init(rawValue: String) {} }
    static let shared = FileRefreshDiagnostics()
    var events = [Event]()
    func record(_ event: Event, source: Source) { events.append(event) }
}
final class SpecialScheduleStore {
    let sources = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.map { ($0, Source()) })
    let records = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.map { ($0, Saved()) })
    var failed = [SpecialScheduleKind](), confirmed = [SpecialScheduleKind](), discarded = 0
    func newStagingURL() -> URL { URL() }
    func discardStaging(_ url: URL) { discarded += 1 }
    func selectedURL(for kind: SpecialScheduleKind) -> URL? { URL() }
    func recordSuccessfulCheck(_ kind: SpecialScheduleKind, digest: String, originalName: String) throws { confirmed.append(kind) }
    func recordAcquisitionFailure(kind: SpecialScheduleKind) throws { failed.append(kind) }
    func recordFailure(_ error: PDFParseError, kind: SpecialScheduleKind) throws { preconditionFailure("Expected no parsing") }
    func saveSelection(staged: URL, kind: SpecialScheduleKind, originalName: String, byteCount: Int,
                       digest: String, grant: Grant) throws { preconditionFailure("Expected same bytes") }
    func saveAnalysis(_ analysis: SpecialScheduleAnalysis) throws { preconditionFailure("Expected no parsing") }
}
CONTROL
enum SpecialSchedulesModel {
    struct Receipt { let acknowledge: () -> Void }
    static var cancelled = false, copied = [SpecialScheduleKind](), acknowledged = [SpecialScheduleKind]()
    static func copy(_ selection: ScopedMaterialSelection, to staged: URL, kind: SpecialScheduleKind,
                     control: AcquisitionControl) throws -> (String, Int, String, Receipt) {
        copied.append(kind)
        if kind == .exam {
            if cancelled { control.cancel(); try control.check() }
            throw MaterialError.providerReadFailed
        }
        return ("fictional.pdf", 10, "saved", Receipt { acknowledged.append(kind) })
    }
METHOD
}
var failures = [String]()
func check(_ condition: Bool, _ description: String) { if !condition { failures.append(description) } }
for cancelling in [true, false] {
    let control = AcquisitionControl(), store = SpecialScheduleStore()
    SpecialSchedulesModel.cancelled = cancelling
    SpecialSchedulesModel.copied = []; SpecialSchedulesModel.acknowledged = []
    FileRefreshDiagnostics.shared.events = []
    do {
        try SpecialSchedulesModel.refreshSelectedFiles(store, requested: Set(SpecialScheduleKind.allCases.map(\.rawValue)), control: control)
        check(false, "refresh incorrectly reported success")
    } catch MaterialError.cancelled { check(cancelling, "provider failure became cancellation") }
    catch MaterialError.providerReadFailed { check(!cancelling, "cancellation became provider failure") }
    catch { check(false, "unexpected refresh error") }
    check(store.failed == (cancelling ? [] : [.exam]), "only a real provider read failure is recorded")
    check(SpecialSchedulesModel.copied == (cancelling ? [.exam] : [.exam, .examReturn]), "unexpected provider work")
    check(store.confirmed == (cancelling ? [] : [.examReturn]), "unexpected saved source check")
    check(SpecialSchedulesModel.acknowledged == store.confirmed, "unexpected acknowledgment")
    check(control.acquiredProviderSources == Set(store.confirmed.map(\.rawValue)), "unexpected acquired source")
    check(store.discarded == SpecialSchedulesModel.copied.count, "staging must be discarded for each checked source")
    let terminal = FileRefreshDiagnostics.shared.events.filter { $0 == .cancelled || $0 == .refreshFailed }
    check(terminal == (cancelling ? [.cancelled] : [.refreshFailed]), "cancel and provider failure need distinct logs")
}
if !failures.isEmpty { print(failures.joined(separator: "\n")); exit(1) }
'''.replace("METHOD", block(refresh, "nonisolated static func refreshSelectedFiles(")) \
   .replace("CONTROL", block(access, "final class AcquisitionControl"))
        with tempfile.TemporaryDirectory(prefix="special-provider-refresh-") as scratch:
            root = Path(scratch)
            source = root / "main.swift"
            source.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-module-cache-path", str(root / "modules"),
                            str(source), "-o", str(root / "probe")], check=True, timeout=60)
            subprocess.run([str(root / "probe")], check=True, timeout=15)

    def test_recovered_timetable_clears_previous_error_only_after_commit(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the recovered timetable commit")
        source = (ROOT / "Takupoke/MaterialWorker+Analysis.swift").read_text(encoding="utf-8")
        program = '''import Foundation
struct PDFAnalysis { let digest: String }
final class MaterialLibrary {
    enum Failure: Error { case disk }
    var saved = "previous", fails = true
    func savePDFAnalysis(_ analysis: PDFAnalysis) throws {
        if fails { throw Failure.disk }
        saved = analysis.digest
    }
}
final class MaterialWorker {
    var timetableFailure: String? = "fictional-strict-error"
METHOD
}
let library = MaterialLibrary(), worker = MaterialWorker()
let recovered = PDFAnalysis(digest: "fictional-recovery")
do {
    try worker.saveRecoveredTimetable(recovered, in: library)
    preconditionFailure("Failed commit returned success")
} catch MaterialLibrary.Failure.disk {
    precondition(library.saved == "previous" && worker.timetableFailure == "fictional-strict-error")
}
library.fails = false
try worker.saveRecoveredTimetable(recovered, in: library)
precondition(library.saved == recovered.digest && worker.timetableFailure == nil)
'''.replace("METHOD", block(source, "    func saveRecoveredTimetable("))
        with tempfile.TemporaryDirectory(prefix="recovered-timetable-commit-") as scratch:
            directory = Path(scratch)
            swift = directory / "main.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-module-cache-path", str(directory / "modules"),
                            str(swift), "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)

    def test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production acquisition")
        access_source = (ROOT / "Takupoke/MaterialAccess.swift").read_text()
        control_source = (ROOT / "Takupoke/ScopedMaterialSelection.swift").read_text()
        program = '''import Foundation
enum MaterialKind: String { case changes }
enum MaterialError: Error { case cancelled, unavailable, invalidState }
enum SimulatedError: Error { case disk }
final class NSFileCoordinator { func cancel() {} }
struct MaterialSource {}
struct PersonalChangeSettings {}
enum SelectedFilePresenter {
    struct ReadReceipt { let acknowledge: () -> Void }
}
CONTROL
final class MaterialLibrary {
    enum Failure { case none, duringMigration, afterMigration, commit }
    var failure = Failure.none
    var currentDigest = "v1", migrated = false, checks = 0, commits = 0, acknowledgements = 0, cleanup = 0
    var recordedCancellation: Bool?
    let control = AcquisitionControl()
    var state: MaterialLibrary { self }
    var digest: String { currentDigest }
    func record(for kind: MaterialKind) -> MaterialLibrary? { self }
    func newStagingURL() -> URL { URL(fileURLWithPath: "/fictional-staging") }
    func discardStaging(_ url: URL) { cleanup += 1 }
    func legacyChangeSettings(check: @escaping () throws -> Void) throws -> PersonalChangeSettings? {
        checks += 1
        if failure == .duringMigration { control.cancel() }
        try check()
        if failure == .afterMigration { control.cancel() }
        return PersonalChangeSettings()
    }
    func commit(staged: URL, kind: MaterialKind, source: MaterialSource, originalName: String, byteCount: Int,
                digest: String, modifiedAt: Date?, reuseUnchanged: Bool, legacyChangeSettings: PersonalChangeSettings?) throws {
        commits += 1
        if failure == .commit { throw SimulatedError.disk }
        currentDigest = digest
        migrated = legacyChangeSettings != nil
    }
    func recordUnchanged(_ kind: MaterialKind, source: MaterialSource) throws {}
    func recordFailure(_ kind: MaterialKind, message: String, cancelled: Bool? = nil) throws {
        recordedCancellation = cancelled
    }
}
final class MaterialWorker {
    let library: MaterialLibrary? = MaterialLibrary()
    private typealias Acquisition = (source: MaterialSource, name: String, count: Int, digest: String,
                                     modified: Date?, receipt: SelectedFilePresenter.ReadReceipt?)
OUTCOME
ACQUIRE
    func run(to digest: String) throws {
        let library = self.library!
        try acquire(.changes, control: library.control, reuseUnchanged: true) { _ in
            let receipt = SelectedFilePresenter.ReadReceipt {
                precondition(library.currentDigest == digest)
                library.acknowledgements += 1
            }
            return .downloaded((MaterialSource(), "fictional.xlsx", 5, digest, nil, receipt))
        }
    }
}
@main struct Probe {
    static func main() throws {
        for failure: MaterialLibrary.Failure in [.duringMigration, .afterMigration, .commit] {
            let worker = MaterialWorker(), library = worker.library!
            library.failure = failure
            do { try worker.run(to: "v2"); preconditionFailure("Expected failure") }
            catch let error as MaterialError {
                precondition(error == (failure == .commit ? .unavailable : .cancelled))
            }
            precondition(library.currentDigest == "v1" && !library.migrated && library.acknowledgements == 0)
            precondition(library.control.acquiredProviderSources.isEmpty)
            precondition(library.checks == 1 && library.cleanup == 1)
            precondition(library.commits == (failure == .commit ? 1 : 0))
            precondition(library.recordedCancellation == (failure != .commit))
        }
        for digest in ["v1", "v2"] {
            let worker = MaterialWorker(), library = worker.library!
            try worker.run(to: digest)
            precondition(library.currentDigest == digest && library.acknowledgements == 1)
            precondition(library.migrated == (digest == "v2"))
            precondition(library.control.acquiredProviderSources == ["changes"])
            precondition(library.checks == (digest == "v1" ? 0 : 1) && library.commits == 1 && library.cleanup == 1)
            precondition(library.recordedCancellation == nil)
        }
    }
}
'''.replace("CONTROL", block(control_source, "final class AcquisitionControl")) \
           .replace("OUTCOME", block(access_source, "private enum AcquisitionOutcome")) \
           .replace("ACQUIRE", block(access_source, "private func acquire(_"))
        with tempfile.TemporaryDirectory(prefix="provider-commit-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True, timeout=30)

    def test_actual_dispatch_retains_review_after_failure_and_closes_only_after_success(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production review completion")
        source = (ROOT / "Takupoke/MaterialsModel.swift").read_text()
        method = block(source, "func perform(")
        program = '''import Foundation
enum MaterialKind: String { case timetable, events, changes }
struct ReviewSource { var selectionID: String? = "fictional-id" }
struct ReviewRecord { var digest = "fictional-digest", storedName = "fictional-copy"; var source = ReviewSource() }
struct MaterialLibraryState {
    var marker = "last-good"
    func record(for kind: MaterialKind) -> ReviewRecord? { ReviewRecord() }
}
struct ChangePreview { var marker = "reviewed" }
struct ChangeParseError: Error, LocalizedError { var errorDescription: String? { "review-failed" } }
struct PDFParseError: Error, LocalizedError { var errorDescription: String? { "pdf-failed" } }
enum MaterialError: Error, LocalizedError {
    case unavailable
    var errorDescription: String? { "unavailable" }
}
final class AcquisitionControl { var acquiredProviderSources = Set<String>() }
final class MaterialLibrary {
    var state = MaterialLibraryState()
    static func displayableTimetables(_ state: MaterialLibraryState) -> (state: MaterialLibraryState, rejected: Set<String>) { (state, []) }
}
final class MaterialWorker {
    var library: MaterialLibrary? = MaterialLibrary(), changePreview: ChangePreview?
    var timetableReadReport: String?, timetableFailure: PDFParseError?
    func clearPreview() { changePreview = nil }
    func pdfURL(for kind: MaterialKind) -> URL? { nil }
}
@MainActor final class MaterialsModel {
    var busy = false, retired = false, failed = false, ready = true
    var message: String?, changePreview: ChangePreview? = ChangePreview()
    var changeFailureContext: (identity: String, digest: String, year: Int)?
    var generation = UUID(), state = MaterialLibraryState(), rejectedRecoveryKinds = Set<String>()
    var control: AcquisitionControl?, pdfURLs: [String: URL] = [:]
    var timetableReadReport: String?, timetableFailure: PDFParseError?
    let worker = MaterialWorker(), queue = DispatchQueue(label: "fictional-review-worker")
    var observedAcquisitions = Set<String>()
    func updateFileMonitoring(retryFailedFor acquired: Set<String>) { observedAcquisitions = acquired }
    func runPendingSelection() {}
    func runPendingFileRefresh() {}
METHOD
}
@main struct Probe {
    @MainActor static func main() async {
        let model = MaterialsModel()
        func run(fails: Bool, close: Bool) async -> Bool {
            await withCheckedContinuation { continuation in
                model.perform(success: "saved", completion: { continuation.resume(returning: $0) },
                    preserveChangePreview: true, dismissChangePreviewOnSuccess: close) { _, control in
                    if fails {
                        control.acquiredProviderSources.insert("changes")
                        throw ChangeParseError()
                    }
                }
                precondition(model.changePreview?.marker == "reviewed")
            }
        }
        let failed = await run(fails: true, close: true)
        precondition(!failed && model.failed && !model.busy)
        precondition(model.message == "review-failed" && model.state.marker == "last-good")
        precondition(model.observedAcquisitions == ["changes"])
        precondition(model.changePreview?.marker == "reviewed")
        let preserved = await run(fails: false, close: false)
        precondition(preserved && model.changePreview?.marker == "reviewed")
        precondition(model.observedAcquisitions.isEmpty)
        let succeeded = await run(fails: false, close: true)
        precondition(succeeded && !model.failed && model.changePreview == nil && !model.busy)
    }
}
'''.replace("METHOD", method)
        with tempfile.TemporaryDirectory(prefix="change-review-completion-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True, timeout=30)

    def test_actual_callbacks_preserve_rejected_preview_and_dispatch_accepted_action_once(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production preview admission")
        model = (ROOT / "Takupoke/MaterialsModel.swift").read_text()
        methods = "\n".join(block(model, marker) for marker in [
            "func changePreviewActionFailure(", "func correctWeekdays(", "func skipChangeRows(", "func savePersonalChanges("])
        program = '''import Foundation
enum MaterialKind { case changes }
enum ChangeAnalysis { static let parserVersion = 7 }
struct Source { var selectionID: String? = "original" }
struct Record { var digest = "same"; var storedName = "stored"; var source = Source() }
struct State {
    var current: Record? = Record()
    func record(for kind: MaterialKind) -> Record? { current }
}
struct ChangePreview {
    var sourceDigest: String? = "same", sourceIdentity: String? = "original"
    var defaultYear: Int? = 2032, parserVersion = ChangeAnalysis.parserVersion
    var canSkipRows = true, canCorrectWeekdays = true, usesDateDerivedWeekdays = false
}
struct ChangeParseError: Error, LocalizedError {
    enum Code { case defaultYear, staleConfirmation, storage }
    var code: Code
    var errorDescription: String? { "invalid-year" }
}
struct ChangeWorkbookReview {}
struct ChangeRowEdit {}
struct Control { func check() throws {} }
struct Library {
    func saveChangeEditor(_ view: ChangeWorkbookReview, year: Int, expectedIdentity: String, expectedDigest: String,
                          edits: [Int: ChangeRowEdit], manual: Bool, check: () throws -> Void) throws {}
}
struct Worker {
    var library: Library? = Library()
    func refresh(_ kind: MaterialKind, control: Control) throws {}
    func correctWeekdays(_ p: ChangePreview, defaultYear: Int, control: Control) throws {}
    func skipChangeRows(_ p: ChangePreview, rows: Set<Int>, defaultYear: Int, control: Control, correctWeekdays: Bool = false) throws {}
}
final class MaterialsModel {
    var busy = false, retired = false
    var automaticChangeSchoolYear: Int? = 2032
    var state = State(), changePreview: ChangePreview? = ChangePreview(), dispatches = 0
    func dismissPreview() { changePreview = nil }
    // The probe tests admission, not acquisition or persistence.
    func perform(success: String?, preserveChangePreview: Bool = false, dismissChangePreviewOnSuccess: Bool = false, changeYear: Int? = nil, operation: (Worker, Control) throws -> Void) { dispatches += 1 }
METHODS
}
@main struct Probe {
    static func main() {
        let preview = ChangePreview(), model = MaterialsModel()
        let skip: (Set<Int>) -> String? = { model.skipChangeRows(preview, rows: $0) }
        let correct = { model.correctWeekdays(preview) }
        let save = { model.savePersonalChanges(preview, view: ChangeWorkbookReview(), edits: [:]) }
        func rejected() {
            precondition(skip([3, 4]) != nil && correct() != nil && save() != nil)
            precondition(model.dispatches == 0 && model.changePreview != nil)
        }
        model.busy = true; rejected(); model.busy = false
        model.retired = true; rejected(); model.retired = false
        model.automaticChangeSchoolYear = 2033; rejected()
        model.automaticChangeSchoolYear = nil; rejected()
        model.automaticChangeSchoolYear = 2032
        model.state.current?.digest = "changed"; rejected(); model.state = State()
        model.state.current?.source.selectionID = "different"; rejected(); model.state = State()
        model.state.current = nil; rejected(); model.state = State()
        var stale = preview; stale.parserVersion -= 1
        precondition(model.skipChangeRows(stale, rows: [3]) != nil)
        precondition(model.skipChangeRows(preview, rows: []) != nil)
        precondition(model.dispatches == 0 && model.changePreview != nil)
        precondition(skip([3, 4]) == nil && model.dispatches == 1)
        precondition(correct() == nil && model.dispatches == 2)
        precondition(save() == nil && model.dispatches == 3)
        print("Verified production callbacks: rejected actions retain preview; accepted actions dispatch once.")
    }
}
'''.replace("METHODS", methods)
        with tempfile.TemporaryDirectory(prefix="change-preview-admission-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_actual_worker_records_failure_only_for_the_reviewed_original(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production exclusion worker")
        source = (ROOT / "Takupoke/MaterialWorker+Analysis.swift").read_text()
        method = block(source, "func skipChangeRows(")
        program = '''import Foundation
enum MaterialKind { case changes }
struct ChangeParseError: Error {
    enum Code { case unsupported, cancelled, storage, weekdayOnly }
    var code: Code
}
struct AcquisitionControl { func check() throws {} }
struct ChangePreview {
    var canSkipRows = true, defaultYear: Int? = 2032
    var sourceDigest: String? = "reviewed", sourceIdentity: String? = "original"
}
struct Source { var selectionID: String? = "original" }
struct Record { var digest = "reviewed", storedName = "stored", source = Source() }
struct State { var current = Record(); func record(for kind: MaterialKind) -> Record? { current } }
final class Library {
    var state = State(), failures = [ChangeParseError.Code](), years = [Int?]()
    func stabilizeLegacyChangeSelection() throws {}
    func applyRowSkips(_ p: ChangePreview, rows: Set<Int>, defaultYear: Int, correctWeekdays: Bool = false,
                      check: () throws -> Void) throws { throw ChangeParseError(code: .weekdayOnly) }
    func recordParseFailure(_ error: ChangeParseError, defaultYear: Int?) throws {
        failures.append(error.code); years.append(defaultYear)
    }
}
final class MaterialWorker {
    var library: Library? = Library(), replaceDigest = false, replaceSelection = false
    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws {
        if replaceDigest { library?.state.current.digest = "new-content" }
        if replaceSelection { library?.state.current.source.selectionID = "other-original" }
    }
METHOD
}
@main struct Probe {
    static func main() {
        for replacement in 0...2 {
            let worker = MaterialWorker()
            worker.replaceDigest = replacement == 1; worker.replaceSelection = replacement == 2
            do {
                try worker.skipChangeRows(ChangePreview(), rows: [3], defaultYear: 2032,
                    control: AcquisitionControl())
                preconditionFailure("Failure must not become success")
            } catch let error as ChangeParseError { precondition(error.code == .weekdayOnly) }
            catch { preconditionFailure("Unexpected failure") }
            precondition(worker.library!.failures == (replacement == 0 ? [.weekdayOnly] : []))
            precondition(worker.library!.years == (replacement == 0 ? [2032] : []))
        }
    }
}
'''.replace("METHOD", method)
        with tempfile.TemporaryDirectory(prefix="change-preview-worker-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_invalid_year_blocks_change_acquisition_without_stalling_other_queued_materials(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production year admission")
        source = (ROOT / "Takupoke/MaterialsModel.swift").read_text()
        methods = "\n".join(block(source, marker) for marker in [
            "func selectFile(", "private func runPendingSelection(", "func refresh(",
            "private func acceptsChangeYear(", "private nonisolated static func analyzeAfterAcquisition(",
            "func analyzeChanges("])
        pending = (ROOT / "Takupoke/SelectedFileSource.swift").read_text()
        queue = block(pending, "struct PendingFileSelections<")
        program = r'''import Foundation
enum MaterialKind: String { case timetable, changes; var title: String { rawValue } }
struct ScopedMaterialSelection {}
struct AcquisitionControl {}
struct ChangeParseError: Error, LocalizedError {
    enum Code { case defaultYear }
    var code: Code
    var errorDescription: String? { "invalid-year" }
}
final class MaterialWorker {
    var reads: [MaterialKind] = [], pdfs: [MaterialKind] = [], years: [Int?] = []
    func selectFile(_ url: ScopedMaterialSelection, kind: MaterialKind, control: AcquisitionControl) throws { reads.append(kind) }
    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws { reads.append(kind) }
    func analyzeChanges(defaultYear: Int?, control: AcquisitionControl) throws { years.append(defaultYear) }
    func analyzePDF(kind: MaterialKind, control: AcquisitionControl) throws { pdfs.append(kind) }
}
QUEUE
@MainActor final class MaterialsModel {
    var retired = false, busy = false, failed = false, message: String?
    var automaticChangeSchoolYear: Int? = nil
    var pendingSelections = PendingFileSelections<MaterialKind, ScopedMaterialSelection>()
    let worker = MaterialWorker()
    var dispatches = 0
    func perform(success: String?, changeYear: Int? = nil, operation: (MaterialWorker, AcquisitionControl) throws -> Void) {
        dispatches += 1; try! operation(worker, AcquisitionControl())
    }
METHODS
}
@main struct Probe {
    @MainActor static func main() {
        let model = MaterialsModel()
        model.refresh(.changes); model.analyzeChanges(defaultYear: nil); model.analyzeChanges(defaultYear: 203)
        model.selectFile(ScopedMaterialSelection(), kind: .changes)
        precondition(model.dispatches == 0 && model.failed && model.message == "invalid-year")
        model.busy = true
        model.selectFile(ScopedMaterialSelection(), kind: .changes)
        model.selectFile(ScopedMaterialSelection(), kind: .timetable)
        model.busy = false
        // Append a final item to drain the same production queue after a busy operation.
        model.selectFile(ScopedMaterialSelection(), kind: .changes)
        precondition(model.worker.reads == [.timetable] && model.worker.pdfs == [.timetable])
        model.refresh(.timetable)
        precondition(model.worker.reads == [.timetable, .timetable])
        model.automaticChangeSchoolYear = 2032
        model.refresh(.changes); model.analyzeChanges(defaultYear: nil)
        precondition(model.worker.years == [2032, 2032])
        precondition(model.dispatches == 4)
    }
}
'''.replace("METHODS", methods).replace("QUEUE", queue)
        with tempfile.TemporaryDirectory(prefix="change-year-admission-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)
