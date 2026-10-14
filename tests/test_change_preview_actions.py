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
enum ChangeAnalysis { static let parserVersion = 6 }
struct Source { var selectionID: String? = "original" }
struct Record { var digest = "same"; var storedName = "stored"; var source = Source() }
struct State {
    var current: Record? = Record()
    func record(for kind: MaterialKind) -> Record? { current }
}
struct ChangePreview {
    var sourceDigest: String? = "same", sourceIdentity: String? = "original"
    var defaultYear: Int? = 2032, parserVersion = ChangeAnalysis.parserVersion
    var canSkipRows = true, canCorrectWeekdays = true
}
struct Worker {
    func correctWeekdays(_ p: ChangePreview, defaultYear: Int, control: Int) throws {}
    func skipChangeRows(_ p: ChangePreview, rows: Set<Int>, defaultYear: Int, control: Int) throws {}
}
final class MaterialsModel {
    var busy = false, retired = false, automaticChangeSchoolYear = 2032
    var state = State(), changePreview: ChangePreview? = ChangePreview(), dispatches = 0
    func dismissPreview() { changePreview = nil }
    // The probe tests admission, not acquisition or persistence.
    func perform(success: String?, operation: (Worker, Int) throws -> Void) { dispatches += 1 }
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
        model.automaticChangeSchoolYear = 2033; rejected(); model.automaticChangeSchoolYear = 2032
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
    func applyRowSkips(_ p: ChangePreview, rows: Set<Int>, defaultYear: Int,
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
