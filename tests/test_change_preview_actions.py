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
final class AcquisitionControl {}
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
    func updateFileMonitoring(retryFailed: Bool = false) {}
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
                    preserveChangePreview: true, dismissChangePreviewOnSuccess: close) { _, _ in
                    if fails { throw ChangeParseError() }
                }
                precondition(model.changePreview?.marker == "reviewed")
            }
        }
        let failed = await run(fails: true, close: true)
        precondition(!failed && model.failed && !model.busy)
        precondition(model.message == "review-failed" && model.state.marker == "last-good")
        precondition(model.changePreview?.marker == "reviewed")
        let preserved = await run(fails: false, close: false)
        precondition(preserved && model.changePreview?.marker == "reviewed")
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
        view = (ROOT / "Takupoke/ChangeAnalysisView.swift").read_text()
        methods = "\n".join(block(model, marker) for marker in [
            "func changePreviewActionFailure(", "func correctWeekdays(", "func skipChangeRows("])
        skip = block(view, "skipRows: preview.canSkipRows ?")
        skip = skip[skip.index("{"):]
        correct = block(view, "correctWeekdays: preview.canCorrectWeekdays ?")
        correct = correct[correct.index("{"):]
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
    enum Code { case defaultYear }
    var code: Code
    var errorDescription: String? { "invalid-year" }
}
struct Worker {
    func correctWeekdays(_ p: ChangePreview, defaultYear: Int, control: Int) throws {}
    func skipChangeRows(_ p: ChangePreview, rows: Set<Int>, defaultYear: Int, control: Int, correctWeekdays: Bool = false) throws {}
}
final class MaterialsModel {
    var busy = false, retired = false
    var automaticChangeSchoolYear: Int? = 2032
    var state = State(), changePreview: ChangePreview? = ChangePreview(), dispatches = 0
    func dismissPreview() { changePreview = nil }
    // The probe tests admission, not acquisition or persistence.
    func perform(success: String?, preserveChangePreview: Bool = false, dismissChangePreviewOnSuccess: Bool = false, changeYear: Int? = nil, operation: (Worker, Int) throws -> Void) { dispatches += 1 }
METHODS
}
@main struct Probe {
    static func main() {
        let preview = ChangePreview(), model = MaterialsModel()
        let skip: (Set<Int>) -> String? = SKIP
        let correct: () -> String? = CORRECT
        func rejected() {
            precondition(skip([3, 4]) != nil && correct() != nil)
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
        print("Verified production callbacks: rejected actions retain preview; accepted actions dispatch once.")
    }
}
'''.replace("METHODS", methods).replace("SKIP", skip).replace("CORRECT", correct)
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
