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
    def test_actual_methods_preserve_idle_draft_and_only_reset_ack_on_raw_change(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift compiler unavailable; native CI compiles the same methods")
        coordinator = (ROOT / "Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        assistance = (ROOT / "Takupoke/RecoveryManualAssistance.swift").read_text(encoding="utf-8")
        source = '''import Foundation
final class Work { var cancelled=false; func cancel() { cancelled=true } }
final class Monitor { var enabled=false; func setFileMonitoring(_ value:Bool) { enabled=value } }
final class LocalRecoveryModelManager { static let shared=LocalRecoveryModelManager(); var cancelled=false; func cancel() { cancelled=true } }
final class Coordinator {
 var task:Work?=Work(), preparationControl:Work?=Work()
 var operation=UUID(), running=true, status="", failure:String?="failure"
 var manualDraft:String?="original-snapshot", manualImages=["field":"original-crop"]
 var preview:String?="preview", pendingDocument:String?="document", pendingPages:String?="pages", source:String?="source", awaitingModel=true
''' + block(coordinator, "    func suspendForInactivity()") + "\n" + block(coordinator, "    func cancel()") + '''
}
final class Application {
 let recovery=Coordinator(), materials=Monitor(), specialSchedules=Monitor(); var ready=true
''' + block(application, "    func setFileMonitoring(_ foreground: Bool)") + '''
}
''' + block(assistance, "enum RecoveryManualInput") + '''
let app=Application(), operation=UUID()
app.recovery.operation=operation
let task=app.recovery.task!, preparation=app.recovery.preparationControl!
app.setFileMonitoring(false)
precondition(app.recovery.manualDraft == "original-snapshot" && app.recovery.manualImages["field"] == "original-crop" && app.recovery.source == "source")
precondition(task.cancelled && preparation.cancelled && LocalRecoveryModelManager.shared.cancelled && !app.recovery.running && app.recovery.operation != operation)
app.setFileMonitoring(false) // Both scene-phase and background notification can arrive.
app.setFileMonitoring(true)
precondition(app.recovery.manualDraft != nil && app.materials.enabled && app.specialSchedules.enabled)
app.recovery.manualDraft=nil
app.setFileMonitoring(false)
precondition(app.recovery.source == nil && app.recovery.preview == nil)
let other=Application(); other.recovery.cancel() // Retention/user cancellation still destroys private draft.
precondition(other.recovery.manualDraft == nil && other.recovery.manualImages.isEmpty)
var values=["room":"架空室一","subject":"架空科目二","teacher":"架空教員三"]
var ack=["room":true,"subject":true,"teacher":true]
for key in ["room","subject","teacher","room","subject"] {
 RecoveryManualInput.update(values[key]!,id:key,original:"旧架空本文",values:&values,acknowledged:&ack)
}
precondition(ack.values.allSatisfy { $0 })
RecoveryManualInput.update("架空科目改",id:"subject",original:"",values:&values,acknowledged:&ack)
precondition(ack == ["room":true,"subject":false,"teacher":true])
values["subject"]="Ae\\u{301}";ack["subject"]=true
RecoveryManualInput.update("Aé",id:"subject",original:"",values:&values,acknowledged:&ack)
precondition(ack["subject"] == false && values["subject"]!.utf8.elementsEqual("Aé".utf8))
ack["subject"]=true
RecoveryManualInput.update("Aé",id:"subject",original:"",values:&values,acknowledged:&ack)
precondition(ack["subject"] == true)
RecoveryManualInput.update("",id:"subject",original:"",values:&values,acknowledged:&ack)
precondition(ack["subject"] == false)
print("Verified idle/heavy-work/cancel and exact-byte input lifecycle transitions.")
'''
        # All scratch belongs to this invocation, including its generated executable.
        with tempfile.TemporaryDirectory(prefix="manual-input-lifecycle-") as scratch:
            path = Path(scratch)
            (path / "main.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", str(path / "main.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_view_rejects_detached_field_callbacks_and_retention_still_cancels(self):
        view = (ROOT / "Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        self.assertEqual(view.count("guard coordinator.manualDraft?.id == draft.id else { return }"), 2)
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        retention = application.split("if try retention.installedPeriod() != period {")[1].split("loadedPeriod = period")[0]
        self.assertIn("recovery.cancel()", retention)


if __name__ == "__main__":
    unittest.main()
