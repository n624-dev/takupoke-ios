"""Execute production preview callbacks and admission methods with fake dispatch."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]


# These admission/legacy-boundary harnesses do not execute asynchronous jobs.
# Real isolation, deadlines and late work are tested by FileRefreshTests.
PIPELINE_STUBS = r"""
struct SchoolDataPeriod { static func current() -> Self { Self() } }
protocol SelectedFileProviding {}
struct SystemSelectedFileProvider: SelectedFileProviding {}
final class FileRefreshDiagnostics {
    enum Event { case refreshStarted, refreshFailed, hashSame, hashChanged, cancelled }
    enum Source: String { case timetable, changes, exam, examReturn }
    static let shared = FileRefreshDiagnostics()
    var events = [Event]()
    func record(_ event: Event, source: Source? = nil) { events.append(event) }
}
final class FilePipeline {
    enum Failure: Error { case cancelled, timedOut, stale }
    enum Reason { case selection, manual, automatic, background, review }
    enum Stage { case access, acquiring, parsing, validating }
    typealias Source = FileRefreshDiagnostics.Source
    struct Request { let id: UUID; let sources: Set<Source>; let successMessage: String? }
    enum RequestResult { case succeeded, cancelled, failed(String) }
    struct Status { let id: UUID; let requestID: UUID }
    struct Observation {
        let statuses: [Source: Status] = [:]
        let activeSources: Set<Source> = []
        let completed: [Source: Status] = [:]
        func restricting(to sources: Set<Source>) -> Self { self }
        func result(for id: UUID, sources: Set<Source>) -> RequestResult? { nil }
    }
    final class Ticket {
        let source = Source.changes
        var failure: FilePipeline.Failure?
        func check() throws { if let failure { throw failure } }
        func cancel() { failure = .cancelled }
        func enter(_ stage: Stage) {}
        func acquired() {}
        func parsed() {}
        func unchanged() {}
        func onAbort(_ callback: (() -> Void)?) {}
        func afterCommit(_ callback: @escaping () -> Void) { callback() }
    }
    var intentSnapshot: [String: UInt64] { [:] }
    let observation = Observation()
    static let shared = FilePipeline()
    static func claimMonitorRegistrations(in outcomes: [Source: Status], handled: inout [Source: UUID]) -> Set<String> { [] }
    func cancel(_ sources: [Source]) {}
    func cancel(_ source: String) {}
    func isRecovering(_ source: String) -> Bool { false }
}
"""


class ChangePreviewActionTests(unittest.TestCase):
    def test_batch_cancellation_is_separate_from_child_deadline(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for actual cancellation control")
        control = block((ROOT / "Takupoke/SelectedFileProvider.swift").read_text(), "final class AcquisitionControl")
        program = r'''import Foundation
enum MaterialError: Error { case cancelled }
final class NSFileCoordinator { func cancel() {} }
CONTROL
let outer = AcquisitionControl(), inner = AcquisitionControl()
let timedOut = FilePipeline.Ticket()
timedOut.failure = .timedOut
outer.registerCancellationTarget(timedOut)
try outer.check() // A child's timeout must not discard the other file in a batch.
inner.pipelineTicket = timedOut
do { try inner.check(); preconditionFailure("Inner must honor its deadline") }
catch FilePipeline.Failure.timedOut {}
outer.cancel()
do { try outer.check(); preconditionFailure("Explicit batch cancel must stop all") }
catch MaterialError.cancelled {}
precondition(timedOut.failure == .cancelled)
'''.replace("CONTROL", control)
        with tempfile.TemporaryDirectory(prefix="batch-ticket-control-") as scratch:
            root = Path(scratch)
            (root / "main.swift").write_text(PIPELINE_STUBS + program)
            subprocess.run([compiler, "-swift-version", "5", str(root / "main.swift"), "-o", str(root / "probe")], check=True, timeout=60)
            subprocess.run([str(root / "probe")], check=True, timeout=10)

    def test_paused_files_do_not_start_background_work_before_foreground_return(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute background refresh admission")
        materials = block((ROOT / "Takupoke/MaterialsModel.swift").read_text(), "func refreshInBackground(")
        specials = block((ROOT / "Takupoke/SpecialSchedulesModel.swift").read_text(), "func refreshInBackground(")
        queue = block((ROOT / "Takupoke/SelectedFileSource.swift").read_text(), "struct FileRefreshQueue")
        program = '''import Foundation
QUEUE
enum MaterialKind: String { case timetable, changes }
enum SpecialScheduleKind: String, CaseIterable { case exam, examReturn }
struct Source { let grant: Bool? = true }
struct Record { let source = Source() }
struct State { func record(for kind: MaterialKind) -> Record? { Record() } }
struct Library { let state = State() }
final class Worker { let library: Library? = Library(); func open() throws {} }
struct Store { let sources: [SpecialScheduleKind: Source] = [:] }
final class Control { func check() throws {}; func cancel() {} }
struct Monitor { var blockedSources = Set<String>() }
@MainActor final class MaterialsModel {
    var busy = false, retired = false, backgroundRefreshID: UUID?
    var fileRefreshQueue = FileRefreshQueue(), dispatches = 0
    var control: Control?, automaticChangeSchoolYear: Int? = 2032
    var fileMonitor = Monitor()
    // This harness checks admission only. Production operations are not run by this fake dispatcher.
    func perform(success: String?, completion: @escaping (Bool) -> Void, operation: (Worker, Control) throws -> Void) {
        dispatches += 1; completion(true)
    }
    nonisolated static func refreshSelectedFiles(_ worker: Worker, requested: Set<String>, year: Int?, control: Control, reason: FilePipeline.Reason = .automatic) throws {}
MATERIALS
}
@MainActor final class SpecialSchedulesModel {
    var busy = false, retired = false, backgroundRefreshID: UUID?
    var fileRefreshQueue = FileRefreshQueue(), dispatches = 0
    var control: Control?
    var fileMonitor = Monitor()
    func perform(success: String?, completion: @escaping (Bool) -> Void, operation: (Store, Control, Bool) throws -> Void) {
        dispatches += 1; completion(true)
    }
    nonisolated static func refreshSelectedFiles(_ store: Store, requested: Set<String>, control: Control, reason: FilePipeline.Reason = .automatic) throws {}
SPECIALS
}
@main struct Probe {
    @MainActor static func main() async {
        let materials = MaterialsModel(), specials = SpecialSchedulesModel()
        materials.fileRefreshQueue.setForeground(true); specials.fileRefreshQueue.setForeground(true)
        materials.fileRefreshQueue.suspend(); specials.fileRefreshQueue.suspend()
        materials.fileRefreshQueue.setForeground(false); specials.fileRefreshQueue.setForeground(false)
        let stoppedMaterial = await materials.refreshInBackground()
        let stoppedSpecial = await specials.refreshInBackground()
        precondition(!stoppedMaterial && !stoppedSpecial)
        precondition(materials.dispatches == 0 && specials.dispatches == 0)
        materials.fileRefreshQueue.setForeground(true); specials.fileRefreshQueue.setForeground(true)
        materials.fileRefreshQueue.setForeground(false); specials.fileRefreshQueue.setForeground(false)
        let resumedMaterial = await materials.refreshInBackground()
        let resumedSpecial = await specials.refreshInBackground()
        precondition(resumedMaterial && resumedSpecial)
        precondition(materials.dispatches == 1 && specials.dispatches == 1)
    }
}
'''.replace("QUEUE", queue).replace("MATERIALS", materials).replace("SPECIALS", specials)
        with tempfile.TemporaryDirectory(prefix="paused-file-refresh-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True, timeout=30)

    def test_special_provider_refresh_keeps_cancellation_separate_from_failure(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production special schedule refresh")
        refresh = (ROOT / "Takupoke/SpecialSchedulesModel+Startup.swift").read_text(encoding="utf-8")
        access = (ROOT / "Takupoke/SelectedFileProvider.swift").read_text(encoding="utf-8")
        program = r'''import Foundation
enum MaterialError: Error { case cancelled, unavailable, accessExpired, providerReadFailed, bookmarkStale }
enum SpecialScheduleKind: String, CaseIterable { case exam, examReturn }
struct PDFParseError: Error { enum Code { case cancelled }; let code: Code }
struct ChangeParseError: Error { enum Code { case cancelled }; let code: Code }
CANCELLATION
final class NSFileCoordinator { func cancel() {} }
struct URL {
    init() {}
    init(resolvingBookmarkData: Data, options: [Int], relativeTo: URL?, bookmarkDataIsStale: inout Bool) throws {}
}
struct ScopedMaterialSelection {
    let url: URL
    init(_ url: URL) { self.url = url }
    func access<T>(_ block: (URL) throws -> T) throws -> T { try block(url) }
}
struct SourceGrant { let bookmark: Data; init(bookmark: Data = Data()) { self.bookmark = bookmark } }
typealias Grant = SourceGrant
struct MaterialBookmarkResolution {
    let url = URL()
    let isStale: Bool
    static func resolve(_ bookmark: Data) throws -> Self { Self(isStale: !bookmark.isEmpty) }
    func renewedGrant(_ previous: SourceGrant, receivedDigest: String, savedDigest: String,
                      readSavedDigest: () throws -> String) throws -> SourceGrant {
        try Self.verifiesOriginal(receivedDigest: receivedDigest, savedDigest: savedDigest, readSavedDigest: readSavedDigest)
        return SourceGrant(bookmark: Data([9]))
    }
VERIFIES_ORIGINAL
}
enum MaterialFileReader {
    static var saved = "saved"
    static func copy(_ url: URL, to: URL?, isWorkbook: Bool, check: () throws -> Void) throws -> (count: Int, digest: String) {
        try check(); return (10, saved)
    }
}
struct Source {
    let digest = "saved", originalName = "fictional.pdf"
    let grant: Grant?
    let failure: PDFParseError? = nil
    let attemptParserVersion: Int? = SpecialScheduleAnalysis.parserVersion
}
struct SpecialScheduleAnalysis {
    static let parserVersion = 1
    let version = SpecialScheduleAnalysis.parserVersion
    let consecutiveTimes: [String: String]? = [:]
    let recoveredExamClockEvidence: Bool? = nil
}
struct Saved { let digest = "saved", analysis = SpecialScheduleAnalysis() }
enum RecoveryConversion { static func trustsAcquisitionCache(_ value: SpecialScheduleAnalysis, hash: String) -> Bool { true } }
enum PDFParseAttempt {
    static func needsAnalysis(digest: String, parserVersion: Int, analysisDigest: String?, analysisVersion: Int?,
                              attemptDigest: String?, failure: PDFParseError?, attemptVersion: Int?) -> Bool { false }
}
enum PDFKitReader {
    static var reads = 0
    static var beforeCheck = {}
    static func readSpecial(_ url: URL, check: () throws -> Void) throws -> [Int] {
        beforeCheck(); try check(); reads += 1; return [1]
    }
}
enum SpecialScheduleParser {
    static var parses = 0
    static func parse(_ pages: [Int], kind: SpecialScheduleKind, digest: String, name: String,
                      check: () throws -> Void) throws -> SpecialScheduleAnalysis { try check(); parses += 1; return SpecialScheduleAnalysis() }
}
final class SpecialScheduleStore {
    let sources: [SpecialScheduleKind: Source]
    let records = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.map { ($0, Saved()) })
    var failed = [SpecialScheduleKind](), confirmed = [SpecialScheduleKind](), selected = [SpecialScheduleKind](), discarded = 0, analyses = 0
    var parseCancellations: [SpecialScheduleKind] = [], renewed = [SpecialScheduleKind]()
    init(missingGrant: SpecialScheduleKind? = nil, staleGrant: SpecialScheduleKind? = nil) {
        sources = Dictionary(uniqueKeysWithValues: SpecialScheduleKind.allCases.map {
            ($0, Source(grant: $0 == missingGrant ? nil : Grant(bookmark: $0 == staleGrant ? Data([1]) : Data())))
        })
    }
    func newStagingURL() -> URL { URL() }
    func discardStaging(_ url: URL) { discarded += 1 }
    func selectedURL(for kind: SpecialScheduleKind) -> URL? { URL() }
    func hasSelectedFile(_ kind: SpecialScheduleKind) -> Bool { true }
    func recordSuccessfulCheck(_ kind: SpecialScheduleKind, digest: String, originalName: String, renewedGrant: SourceGrant?) throws {
        confirmed.append(kind)
        if renewedGrant != nil { renewed.append(kind) }
    }
    func recordAcquisitionFailure(kind: SpecialScheduleKind) throws { failed.append(kind) }
    func recordFailure(_ error: PDFParseError, kind: SpecialScheduleKind) throws {
        precondition(error.code == .cancelled)
        parseCancellations.append(kind)
    }
    func saveSelection(staged: URL, kind: SpecialScheduleKind, originalName: String, byteCount: Int,
                       digest: String, grant: Grant) throws { selected.append(kind) }
    func acceptParsedAnalysis(_ parsed: SpecialScheduleAnalysis, selectedURL: URL, check: () throws -> Void) throws {
        try check(); analyses += 1
    }
}
CONTROL
enum SpecialSchedulesModel {
    static func pipeline(_ store: SpecialScheduleStore, kind: SpecialScheduleKind, reason: FilePipeline.Reason,
        control: AcquisitionControl, operation: (SpecialScheduleStore, AcquisitionControl) throws -> Void) throws {
        // This harness models only the final authorized attempt; retry and
        // live-store isolation are exercised by the native pipeline tests.
        do { try operation(store, control) }
        catch {
            if !FileOperationOutcome.isCancellation(error) { try store.recordAcquisitionFailure(kind: kind) }
            throw error
        }
    }
    struct Receipt { let acknowledge: () -> Void }
    static var cancelled = false, succeed = false, copied = [SpecialScheduleKind](), acknowledged = [SpecialScheduleKind]()
    static func copy(_ selection: ScopedMaterialSelection, to staged: URL, kind: SpecialScheduleKind,
                     control: AcquisitionControl) throws -> (name: String, count: Int, digest: String, receipt: Receipt) {
        copied.append(kind)
        if kind == .exam && !succeed {
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
    check(PDFKitReader.reads == 0 && SpecialScheduleParser.parses == 0 && store.analyses == 0,
          "automatic unchanged checks must not parse")
    check(store.selected.isEmpty, "automatic unchanged checks must not replace the source")
    let terminal = FileRefreshDiagnostics.shared.events.filter { $0 == .cancelled || $0 == .refreshFailed }
    check(terminal == (cancelling ? [.cancelled] : [.refreshFailed]), "cancel and provider failure need distinct logs")
}
SpecialSchedulesModel.succeed = true
for force in [false, true] {
    let control = AcquisitionControl(), store = SpecialScheduleStore()
    SpecialSchedulesModel.copied = []; SpecialSchedulesModel.acknowledged = []
    PDFKitReader.reads = 0; SpecialScheduleParser.parses = 0
    do {
        try SpecialSchedulesModel.refreshSelectedFiles(store,
            requested: Set(SpecialScheduleKind.allCases.map(\.rawValue)), control: control, force: force)
    } catch { check(false, "successful same-byte acquisition must complete") }
    check(SpecialSchedulesModel.copied == [.exam, .examReturn], "both kinds must reacquire their source")
    check(SpecialSchedulesModel.acknowledged == [.exam, .examReturn], "both copies must be acknowledged")
    check(store.selected == (force ? [.exam, .examReturn] : []), "force must replace the acquired source even when unchanged")
    check(store.confirmed == (force ? [] : [.exam, .examReturn]), "ordinary checks must keep the unchanged source")
    check(PDFKitReader.reads == (force ? 2 : 0) && SpecialScheduleParser.parses == (force ? 2 : 0),
          "force must run reading and parsing even when unchanged")
    check(store.analyses == (force ? 2 : 0), "only completed forced analyses are saved")
    check(store.discarded == 2 && store.failed.isEmpty, "staging is released without recording false failures")
}
let cancelledRead = AcquisitionControl(), interruptedStore = SpecialScheduleStore()
PDFKitReader.beforeCheck = { cancelledRead.cancel() }
SpecialSchedulesModel.copied = []
FileRefreshDiagnostics.shared.events = []
do {
    try SpecialSchedulesModel.refreshSelectedFiles(interruptedStore,
        requested: Set(SpecialScheduleKind.allCases.map(\.rawValue)), control: cancelledRead, force: true)
    check(false, "interrupted PDF read incorrectly reported success")
} catch let error as PDFParseError {
    check(error.code == .cancelled, "the parser cancellation should reach the caller")
} catch { check(false, "unexpected PDF read error") }
check(SpecialSchedulesModel.copied == [.exam], "parser cancellation must stop the batch")
check(interruptedStore.parseCancellations.isEmpty && interruptedStore.failed.isEmpty && interruptedStore.analyses == 0,
      "cancelled candidates must not publish live parse failures, acquisition failures or analyses")
let terminal = FileRefreshDiagnostics.shared.events.filter { $0 == .cancelled || $0 == .refreshFailed }
check(terminal == [.cancelled], "cancelled PDF reading must use the cancellation trace")
let legacyStore = SpecialScheduleStore(missingGrant: .exam)
SpecialSchedulesModel.copied = []
do {
    try SpecialSchedulesModel.refreshSelectedFiles(legacyStore, requested: ["exam", "examReturn"],
        control: AcquisitionControl(), reason: .manual)
    check(false, "a manual source check without a bookmark must fail")
} catch MaterialError.accessExpired {} catch { check(false, "expected a reselection error") }
check(legacyStore.failed == [.exam] && legacyStore.confirmed == [.examReturn],
      "a missing bookmark must not block another authorized file or record an unperformed check")
check(legacyStore.selected.isEmpty && legacyStore.analyses == 0 && SpecialSchedulesModel.copied == [.examReturn],
      "keep the cached selection and analysis for the legacy file")
for saved in ["saved", "different-actual-saved"] {
    MaterialFileReader.saved = saved
    let store = SpecialScheduleStore(staleGrant: .exam)
    do {
        try SpecialSchedulesModel.refreshSelectedFiles(store, requested: ["exam", "examReturn"], control: AcquisitionControl())
        check(saved == "saved", "a mismatched copy cannot renew the reference")
    } catch MaterialError.bookmarkStale { check(saved != "saved", "matching input must renew automatically") }
    catch { check(false, "unexpected stale reference error") }
    check(store.renewed == (saved == "saved" ? [.exam] : []), "only the matching source may renew its grant")
    check(store.confirmed.contains(.examReturn) && store.selected.isEmpty, "unrelated source must still be confirmed")
}
if !failures.isEmpty { print(failures.joined(separator: "\n")); exit(1) }
'''.replace("METHOD", block(refresh, "nonisolated static func refreshSelectedFiles(")) \
   .replace("CANCELLATION", block((ROOT / "Takupoke/StatusPresentation.swift").read_text(), "enum FileOperationOutcome")) \
   .replace("CONTROL", block(access, "final class AcquisitionControl")) \
   .replace("VERIFIES_ORIGINAL", block((ROOT / "Takupoke/MaterialModels.swift").read_text(), "static func verifiesOriginal("))
        with tempfile.TemporaryDirectory(prefix="special-provider-refresh-") as scratch:
            root = Path(scratch)
            source = root / "main.swift"
            source.write_text(PIPELINE_STUBS + program, encoding="utf-8")
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
            swift.write_text(PIPELINE_STUBS + program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-module-cache-path", str(directory / "modules"),
                            str(swift), "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)

    def test_acquisition_acknowledges_only_committed_copy_and_honors_cancellation_during_migration(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production acquisition")
        access_source = (ROOT / "Takupoke/MaterialAccess.swift").read_text()
        control_source = (ROOT / "Takupoke/SelectedFileProvider.swift").read_text()
        program = '''import Foundation
enum MaterialKind: String { case changes }
enum MaterialError: Error { case cancelled, unavailable, invalidState, tooLarge, invalidFile, accessExpired, bookmarkFailed, bookmarkStale, bookmarkUnresolved, providerReadFailed }
ACQUISITION_PROBLEM
extension FilePipeline {
TRANSIENT
}
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
    func recordFailure(_ kind: MaterialKind, message: String, cancelled: Bool? = nil,
                       problem: AcquisitionProblem? = nil) throws {
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
           .replace("ACQUISITION_PROBLEM", block((ROOT / "Takupoke/MaterialModels.swift").read_text(), "enum AcquisitionProblem:")) \
           .replace("TRANSIENT", block((ROOT / "Takupoke/FilePipeline.swift").read_text(), "static func isTransient(")) \
           .replace("OUTCOME", block(access_source, "private enum AcquisitionOutcome")) \
           .replace("ACQUIRE", block(access_source, "private func acquire(_"))
        with tempfile.TemporaryDirectory(prefix="provider-commit-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
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
struct ChangeParseError: Error, LocalizedError {
    enum Code { case failed, cancelled }
    var code: Code = .failed
    var errorDescription: String? { "review-failed" }
}
struct PDFParseError: Error, LocalizedError {
    enum Code { case failed, cancelled }
    var code: Code = .failed
    var errorDescription: String? { "pdf-failed" }
}
enum MaterialError: Error, LocalizedError {
    case unavailable, cancelled
    var errorDescription: String? { self == .cancelled ? "cancelled" : "unavailable" }
}
CANCELLATION
REFRESH_QUEUE
final class Monitor { var discarded = 0; func discardPendingRefreshes() { discarded += 1 } }
final class AcquisitionControl {
    let operationID = UUID()
    let usedPipeline = false
    let pipelineSources = Set<FileRefreshDiagnostics.Source>()
    init(intents: [String: UInt64] = [:]) {}
    var acquiredProviderSources = Set<String>()
    var cancelled = false
    func cancel() { cancelled = true }
}
PENDING_SELECTIONS
final class MaterialLibrary {
    var state = MaterialLibraryState()
    let wasPartiallyRecovered = false
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
    var pendingPipelineRequest: FilePipeline.Request?, lastOperationUsedPipeline = false
    var pipelineMonitorIDs: [FileRefreshDiagnostics.Source: UUID] = [:]
    var cancellationRequested = false, lastOperationWasCancelled = false
    var fileRefreshQueue = FileRefreshQueue()
    var pendingManualRefresh = Set<MaterialKind>()
    var pendingManualChecks = Set<MaterialKind>()
    var pendingSelections = PendingFileSelections<MaterialKind, Int>()
    let fileMonitor = Monitor()
    var message: String?, changePreview: ChangePreview? = ChangePreview()
    var changeFailureContext: (identity: String, digest: String, year: Int)?
    var generation = UUID(), state = MaterialLibraryState(), rejectedRecoveryKinds = Set<String>()
    var control: AcquisitionControl?, pdfURLs: [String: URL] = [:]
    var analysisPDFURLs: [String: URL] = [:]
    var wasPartiallyRecovered = false
    var timetableReadReport: String?, timetableFailure: PDFParseError?
    let worker = MaterialWorker(), queue = DispatchQueue(label: "fictional-review-worker")
    var observedAcquisitions = Set<String>()
    nonisolated static func analysisPDFURLs(in library: MaterialLibrary, visible state: MaterialLibraryState) -> [String: URL] { [:] }
    func updateFileMonitoring(retryFailedFor acquired: Set<String>) { observedAcquisitions = acquired }
    func runPendingSelection() {}
    func runPendingFileRefresh() {}
METHOD
APPLY_PIPELINE_RESULT
CANCEL_OPERATION
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
        for error: Error in [MaterialError.cancelled, ChangeParseError(code: .cancelled), PDFParseError(code: .cancelled), CancellationError()] {
            model.changePreview = ChangePreview()
            model.fileRefreshQueue.setForeground(true)
            model.fileRefreshQueue.request("changes")
            model.pendingSelections.append(1, kind: .changes)
            let cancelled: Bool = await withCheckedContinuation { continuation in
                model.perform(success: "saved", completion: { continuation.resume(returning: $0) },
                    preserveChangePreview: true, dismissChangePreviewOnSuccess: true) { _, _ in throw error }
                model.cancelCurrentOperation()
                precondition(model.busy && model.cancellationRequested && model.control?.cancelled == true)
                precondition(model.pendingSelections.take(busy: false) == nil && !model.fileRefreshQueue.suspended)
            }
            precondition(!cancelled && !model.failed && !model.busy && !model.cancellationRequested)
            precondition(model.lastOperationWasCancelled && model.message == "cancelled")
            precondition(model.changePreview?.marker == "reviewed" && model.state.marker == "last-good")
            precondition(model.fileRefreshQueue.pending.isEmpty && !model.fileRefreshQueue.suspended)
        }
        precondition(model.fileMonitor.discarded == 8)
    }
}
'''.replace("METHOD", method) \
           .replace("APPLY_PIPELINE_RESULT", block(source, "private func applyPipelineResult(")) \
           .replace("CANCEL_OPERATION", block(source, "func cancelCurrentOperation()")) \
           .replace("PENDING_SELECTIONS", block((ROOT / "Takupoke/SelectedFileSource.swift").read_text(), "struct PendingFileSelections")) \
           .replace("CANCELLATION", block((ROOT / "Takupoke/StatusPresentation.swift").read_text(), "enum FileOperationOutcome")) \
           .replace("REFRESH_QUEUE", block((ROOT / "Takupoke/SelectedFileSource.swift").read_text(), "struct FileRefreshQueue"))
        with tempfile.TemporaryDirectory(prefix="change-review-completion-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
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
struct Control { var pipelineTicket: FilePipeline.Ticket? = nil; func check() throws {} }
struct Library {
    func saveChangeEditor(_ view: ChangeWorkbookReview, year: Int, expectedIdentity: String, expectedDigest: String,
                          edits: [Int: ChangeRowEdit], manual: Bool, check: () throws -> Void) throws {}
}
struct Worker {
    func pipeline(_ kind: MaterialKind, reason: FilePipeline.Reason, control: Control,
        operation: (Worker, Control) throws -> Void) throws { try operation(self, control) }
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
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
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
struct AcquisitionControl { var pipelineTicket: FilePipeline.Ticket? = nil; func check() throws {} }
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
    func pipeline(_ kind: MaterialKind, reason: FilePipeline.Reason, control: AcquisitionControl,
        operation: (MaterialWorker, AcquisitionControl) throws -> Void) throws {
        var inner = control; inner.pipelineTicket = FilePipeline.Ticket(); try operation(self, inner)
    }
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
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
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
struct Monitor {
    var blockedSources = Set<String>()
    func isRegistering(_ id: String) -> Bool { blockedSources.contains(id) }
}
struct AcquisitionControl {}
struct ChangeParseError: Error, LocalizedError {
    enum Code { case defaultYear }
    var code: Code
    var errorDescription: String? { "invalid-year" }
}
final class MaterialWorker {
    var reads: [MaterialKind] = [], pdfs: [MaterialKind] = [], years: [Int?] = []
    func pipeline(_ kind: MaterialKind, reason: FilePipeline.Reason, control: AcquisitionControl,
        operation: (MaterialWorker, AcquisitionControl) throws -> Void) throws { try operation(self, control) }
    func selectFile(_ url: ScopedMaterialSelection, kind: MaterialKind, control: AcquisitionControl) throws { reads.append(kind) }
    func refresh(_ kind: MaterialKind, control: AcquisitionControl) throws { reads.append(kind) }
    func analyzeChanges(defaultYear: Int?, control: AcquisitionControl) throws { years.append(defaultYear) }
    func analyzePDF(kind: MaterialKind, control: AcquisitionControl) throws { pdfs.append(kind) }
}
QUEUE
@MainActor final class MaterialsModel {
    var retired = false, busy = false, failed = false, message: String?
    var automaticChangeSchoolYear: Int? = nil
    var pendingManualRefresh = Set<MaterialKind>()
    var pendingManualChecks = Set<MaterialKind>()
    var pendingSelections = PendingFileSelections<MaterialKind, ScopedMaterialSelection>()
    var fileMonitor = Monitor()
    let worker = MaterialWorker()
    var dispatches = 0
    func checkForUpdates(_ kind: MaterialKind) {}
    func drainAfterCompletion() { runPendingSelection() }
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
        model.drainAfterCompletion()
        model.refresh(.timetable)
        precondition(model.worker.reads == [.timetable, .timetable])
        model.automaticChangeSchoolYear = 2032
        model.refresh(.changes); model.analyzeChanges(defaultYear: nil)
        precondition(model.worker.years == [2032, 2032])
        precondition(model.dispatches == 4)
        model.fileMonitor.blockedSources = ["changes"]
        model.selectFile(ScopedMaterialSelection(), kind: .changes)
        model.selectFile(ScopedMaterialSelection(), kind: .timetable)
        precondition(model.dispatches == 5 && model.worker.reads.last == .timetable)
        model.fileMonitor.blockedSources = []
        model.selectFile(ScopedMaterialSelection(), kind: .timetable)
        precondition(model.dispatches == 6 && model.worker.reads.last == .changes)
        model.drainAfterCompletion()
        precondition(model.dispatches == 7 && model.worker.reads.suffix(2) == [.changes, .timetable])
    }
}
'''.replace("METHODS", methods).replace("QUEUE", queue)
        with tempfile.TemporaryDirectory(prefix="change-year-admission-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(PIPELINE_STUBS + program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)
