"""Compile production input/background methods with Foundation-only UI dependency stubs.

These checks exercise state transitions, not UIKit event delivery or OCR quality.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


class ManualInputLifecycleTests(unittest.TestCase):
    def test_actual_background_methods_preserve_idle_draft_and_cancel_heavy_work(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift compiler unavailable; native CI compiles the same methods")
        coordinator = (ROOT / "Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        source = '''import Foundation
final class Work { var cancelled=false; func cancel() { cancelled=true } }
final class Monitor { var enabled=false; func setFileMonitoring(_ value:Bool) { enabled=value } }
final class LocalRecoveryModelManager { static let shared=LocalRecoveryModelManager(); var cancelled=false; func cancel() { cancelled=true } }
final class Coordinator {
 var task:Work?=Work(), preparationControl:Work?=Work()
 var operation=UUID(), running=true, status="", failure:String?="failure"
 var manualDraft:String?="original-snapshot", manualImages=["field":"original-crop"]
 var manualReview:String?="review",manualContextImages=["field":"actual-cell"]
 var preview:String?="preview", pendingDocument:String?="document", pendingPages:String?="pages", source:String?="source", awaitingModel=true
''' + block(coordinator, "    func suspendForInactivity()") + "\n" + block(coordinator, "    func cancel()") + '''
}
final class Application {
 let recovery=Coordinator(), materials=Monitor(), specialSchedules=Monitor(); var ready=true
''' + block(application, "    func setFileMonitoring(_ foreground: Bool)") + '''
}
let app=Application(), operation=UUID()
app.recovery.operation=operation
let task=app.recovery.task!, preparation=app.recovery.preparationControl!
app.setFileMonitoring(false)
precondition(app.recovery.manualDraft == "original-snapshot" && app.recovery.manualImages["field"] == "original-crop" && app.recovery.source == "source")
precondition(app.recovery.manualReview == "review" && app.recovery.manualContextImages["field"] == "actual-cell")
precondition(task.cancelled && preparation.cancelled && LocalRecoveryModelManager.shared.cancelled && !app.recovery.running && app.recovery.operation != operation)
app.setFileMonitoring(false) // Both scene-phase and background notification can arrive.
app.setFileMonitoring(true)
precondition(app.recovery.manualDraft != nil && app.materials.enabled && app.specialSchedules.enabled)
app.recovery.manualDraft=nil
app.setFileMonitoring(false)
precondition(app.recovery.source == nil && app.recovery.preview == nil)
let other=Application(); other.recovery.cancel() // Retention/user cancellation still destroys private draft.
precondition(other.recovery.manualDraft == nil && other.recovery.manualImages.isEmpty && other.recovery.manualReview == nil && other.recovery.manualContextImages.isEmpty)
print("Verified actual background preservation and heavy-work/cancel transitions.")
'''
        # All scratch belongs to this invocation, including its generated executable.
        with tempfile.TemporaryDirectory(prefix="manual-input-lifecycle-") as scratch:
            path = Path(scratch)
            (path / "main.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", str(path / "main.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_actual_field_callbacks_reject_replaced_missing_and_reviewed_drafts(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for actual binding callback execution")
        view = (ROOT / "Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        text = block(view.split('TextField("PDFに記載された全文",', 1)[1], "set:")[4:]
        acknowledgement = block(view.split('Toggle("原本と一致することを確認",', 1)[1], "set:")[4:]
        assistance = (ROOT / "Takupoke/RecoveryManualAssistance.swift").read_text(encoding="utf-8")
        source = '''import Foundation
struct Draft { let id:String }
struct Field { let id:String;let originalText:String }
final class Coordinator { var manualDraft:Draft?=Draft(id:"first");var manualReview:String? }
''' + block(assistance, "enum RecoveryManualInput") + '''
let coordinator=Coordinator(),draft=Draft(id:"first"),field=Field(id:"subject",originalText:"架空初期入力")
var manualValues=[field.id:field.originalText],manualAcknowledged=[field.id:false]
let changeText:(String)->Void=TEXT_CALLBACK
let changeAcknowledgement:(Bool)->Void=ACK_CALLBACK
changeText("架空現画面入力");changeAcknowledgement(true)
precondition(manualValues[field.id]=="架空現画面入力" && manualAcknowledged[field.id]==true)
for current in [Draft(id:"replacement"),nil] {
 coordinator.manualDraft=current
 manualValues[field.id]="架空新しい画面入力";manualAcknowledged[field.id]=false
 changeText("架空古い画面入力");changeAcknowledgement(true)
 precondition(manualValues[field.id]=="架空新しい画面入力" && manualAcknowledged[field.id]==false)
}
coordinator.manualDraft=draft;coordinator.manualReview="review"
changeText("架空レビュー中入力");changeAcknowledgement(true)
precondition(manualValues[field.id]=="架空新しい画面入力" && manualAcknowledged[field.id]==false)
coordinator.manualReview=nil
changeAcknowledgement(true);changeText("架空再開入力")
precondition(manualValues[field.id]=="架空再開入力" && manualAcknowledged[field.id]==false)
print("Verified actual stale/missing/review callback rejection and current callback operation.")
'''.replace("TEXT_CALLBACK", text).replace("ACK_CALLBACK", acknowledgement)
        with tempfile.TemporaryDirectory(prefix="manual-binding-callbacks-") as directory:
            path = Path(directory)
            (path / "main.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", str(path / "main.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_retention_route_keeps_explicit_draft_cancellation(self):
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        retention = application.split("if try retention.installedPeriod() != period {")[1].split("loadedPeriod = period")[0]
        self.assertIn("recovery.cancel()", retention)


if __name__ == "__main__":
    unittest.main()
