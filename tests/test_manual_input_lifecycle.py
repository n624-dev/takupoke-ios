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
    def test_actual_activation_does_not_resume_source_checks_after_backgrounding_during_awaits(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift compiler unavailable; native CI compiles the same methods")
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        content = (ROOT / "Takupoke/ContentView.swift").read_text(encoding="utf-8")
        source = '''import Foundation
@MainActor final class UIApplication {
 enum State { case active, background }
 static let shared=UIApplication(); var applicationState=State.active
 var isProtectedDataAvailable=true
}
@MainActor final class Unit {
 var busy=true, active=false, refreshes=0
 func loadIfNeeded() {} ; func checkAtStartup() {}
 func refreshAtStartup() { precondition(active); refreshes += 1 }
 func setSourceChecksActive(_ value:Bool) { active=value }
 func refresh() async {} ; func check() async {}
}
@MainActor struct SchoolDataPeriod: Equatable {
 let index: Int
 static var clock = 2
 static func current() -> Self { .init(index:clock) }
}
struct Clock { let currentDate=Date(timeIntervalSince1970: 42) }
@MainActor final class Countdown {
 var updatedAt: [Date]=[]
 func update(using app:Application, at date:Date) {
  precondition(app.countdown === self && UIApplication.shared.applicationState == .active)
  updatedAt.append(date)
 }
}
@MainActor final class Application {
 var backgroundRefresh:Task<Void,Never>?, backgroundDuringPrepare=false
 var ready=true
 var loadedPeriod: SchoolDataPeriod? = .current()
 var preparing = false
 var heldWork: CheckedContinuation<Void, Never>?
 let materials=Unit(),specialSchedules=Unit(),schoolEvents=Unit(),mappings=Unit(),times=Unit(),links=Unit(),account=Unit()
 let countdown=Countdown()
 let homeClock=Clock()
 func prepare() async -> Bool {
  preparing = true
  loadedPeriod = .current(); ready = true
  if backgroundDuringPrepare { UIApplication.shared.applicationState = .background; schoolEvents.setSourceChecksActive(false) }
  return true
 }
 func setFileMonitoring(_ active:Bool) { schoolEvents.setSourceChecksActive(active) }
 func checkNotificationsWhenActive() {}
''' + block(application, "    func activate() async") + "\n" + block(application, "    func updateCountdown()") + "\n" + block(
            application, "    var readyForCurrentPeriod:") + '''
}
@MainActor struct Content {
 let application: Application
''' + block(content, "    private var dataReady:") + '''
 var showsData: Bool { dataReady }
}
@main struct Probe {
 @MainActor static func main() async {
  for stage in 0...3 {
   UIApplication.shared.applicationState = .active
   let app=Application()
   if stage==1 { app.backgroundDuringPrepare=true }
   if stage==2 {
    app.backgroundRefresh=Task { @MainActor in
     UIApplication.shared.applicationState = .background
     app.schoolEvents.setSourceChecksActive(false)
    }
   }
   if stage==3 { UIApplication.shared.applicationState = .background }
   await app.activate()
   precondition(app.schoolEvents.refreshes == (stage==0 ? 1:0))
   precondition(app.schoolEvents.active == (stage==0))
   precondition(app.countdown.updatedAt == (stage==0 ? [app.homeClock.currentDate] : []))
  }
  print("Verified actual activation foreground guards across both suspension points.")
  for nextPeriod in [2,3] {
   for crossedBoundary in [false,true] {
    UIApplication.shared.applicationState = .active
    SchoolDataPeriod.clock = crossedBoundary ? nextPeriod - 1 : nextPeriod
    let app = Application(), screen = Content(application:app)
    precondition(app.ready && screen.showsData)
    app.backgroundRefresh = Task { await withCheckedContinuation { app.heldWork = $0 } }
    while app.heldWork == nil { await Task.yield() }
    SchoolDataPeriod.clock = nextPeriod
    precondition(screen.showsData == !crossedBoundary) // check the view even before the async activation
    let foreground = Task { await app.activate() }
    while app.backgroundRefresh?.isCancelled != true { await Task.yield() }
    precondition(!app.preparing && app.ready == !crossedBoundary && screen.showsData == !crossedBoundary)
    precondition(app.updateCountdown() == !crossedBoundary)
    precondition(app.countdown.updatedAt.count == (crossedBoundary ? 0 : 1))
    app.heldWork?.resume(); app.heldWork = nil
    await foreground.value
    precondition(app.preparing && app.loadedPeriod == .current() && screen.showsData)
   }
  }
  print("Verified prior-period data is hidden before a suspended background refresh completes.")
 }
}
'''
        with tempfile.TemporaryDirectory(prefix="events-activation-lifecycle-") as scratch:
            path = Path(scratch)
            (path / "probe.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", "-module-cache-path", str(path / "modules"),
                            str(path / "probe.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_actual_background_methods_preserve_idle_draft_and_cancel_heavy_work(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift compiler unavailable; native CI compiles the same methods")
        coordinator = (ROOT / "Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        source = '''import Foundation
final class Work { var cancelled=false; func cancel() { cancelled=true } }
final class Monitor { var enabled=false; func setFileMonitoring(_ value:Bool) { enabled=value }; func setSourceChecksActive(_ value:Bool) { enabled=value } }
final class Clock { var running=true; func start() { running=true }; func pause() { running=false } }
final class LocalRecoveryModelManager { static let shared=LocalRecoveryModelManager(); var cancelled=false; func cancel() { cancelled=true } }
final class Coordinator {
 var task:Work?=Work(), preparationControl:Work?=Work()
 var operation=UUID(), running=true, status="", failure:String?="failure"
 var manualDraft:String?="original-snapshot", manualImages=["field":"original-crop"]
 var manualReview:String?="review",manualContextImages=["field":"actual-cell"]
 var previewRasters=[1:"original-raster"],manualInitialValues=["field":"prior-transcription"]
 var preview:String?="preview", pendingDocument:String?="document", pendingPages:String?="pages", source:String?="source", awaitingModel=true
''' + block(coordinator, "    func suspendForInactivity()") + "\n" + block(coordinator, "    func cancel()") + '''
}
final class Application {
 let recovery=Coordinator(), materials=Monitor(), specialSchedules=Monitor(), schoolEvents=Monitor(); var ready=true
 let homeClock=Clock()
''' + block(application, "    func setFileMonitoring(_ foreground: Bool)") + '''
}
let app=Application(), operation=UUID()
app.recovery.operation=operation
let task=app.recovery.task!, preparation=app.recovery.preparationControl!
app.setFileMonitoring(false)
precondition(!app.schoolEvents.enabled)
precondition(!app.homeClock.running)
precondition(app.recovery.manualDraft == "original-snapshot" && app.recovery.manualImages["field"] == "original-crop" && app.recovery.source == "source")
precondition(app.recovery.manualReview == "review" && app.recovery.manualContextImages["field"] == "actual-cell")
precondition(app.recovery.previewRasters[1] == "original-raster" && app.recovery.manualInitialValues["field"] == "prior-transcription")
precondition(task.cancelled && preparation.cancelled && LocalRecoveryModelManager.shared.cancelled && !app.recovery.running && app.recovery.operation != operation)
app.setFileMonitoring(false) // Both scene-phase and background notification can arrive.
app.setFileMonitoring(true)
precondition(app.recovery.manualDraft != nil && app.materials.enabled && app.specialSchedules.enabled && app.schoolEvents.enabled)
precondition(app.homeClock.running)
app.recovery.manualDraft=nil
app.setFileMonitoring(false)
precondition(app.recovery.source == nil && app.recovery.preview == nil)
precondition(app.recovery.previewRasters.isEmpty && app.recovery.manualInitialValues.isEmpty)
let other=Application(); other.recovery.cancel() // Retention/user cancellation still destroys private draft.
precondition(other.recovery.manualDraft == nil && other.recovery.manualImages.isEmpty && other.recovery.manualReview == nil && other.recovery.manualContextImages.isEmpty)
precondition(other.recovery.previewRasters.isEmpty && other.recovery.manualInitialValues.isEmpty)
print("Verified actual background preservation and heavy-work/cancel transitions.")
'''
        # All scratch belongs to this invocation, including its generated executable.
        with tempfile.TemporaryDirectory(prefix="manual-input-lifecycle-") as scratch:
            path = Path(scratch)
            (path / "main.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-module-cache-path", str(path / "modules"),
                            str(path / "main.swift"), "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_actual_field_callbacks_reject_replaced_missing_and_reviewed_drafts(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for actual binding callback execution")
        view = (ROOT / "Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        text = block(view.split('TextField("PDFに記載された全文",', 1)[1], "set:")[4:]
        acknowledgement = block(view.split('let acknowledged = manualAcknowledged[field.id] ?? false', 1)[1], "Button ")
        acknowledgement = acknowledgement.removeprefix("Button ")
        assistance = (ROOT / "Takupoke/RecoveryManualAssistance.swift").read_text(encoding="utf-8")
        source = '''import Foundation
struct Draft { let id:String }
struct Field { let id:String;let originalText:String }
final class Coordinator { var manualDraft:Draft?=Draft(id:"first");var manualReview:String? }
''' + block(assistance, "enum RecoveryManualInput") + '''
let coordinator=Coordinator(),draft=Draft(id:"first"),field=Field(id:"subject",originalText:"架空初期入力")
var manualValues=[field.id:field.originalText],manualAcknowledged=[field.id:false]
let changeText:(String)->Void=TEXT_CALLBACK
let changeAcknowledgement:()->Void=ACK_CALLBACK
changeText("架空現画面入力");changeAcknowledgement()
precondition(manualValues[field.id]=="架空現画面入力" && manualAcknowledged[field.id]==true)
changeAcknowledgement()
precondition(manualAcknowledged[field.id]==false)
for current in [Draft(id:"replacement"),nil] {
 coordinator.manualDraft=current
 manualValues[field.id]="架空新しい画面入力";manualAcknowledged[field.id]=false
 changeText("架空古い画面入力");changeAcknowledgement()
 precondition(manualValues[field.id]=="架空新しい画面入力" && manualAcknowledged[field.id]==false)
}
coordinator.manualDraft=draft;coordinator.manualReview="review"
changeText("架空レビュー中入力");changeAcknowledgement()
precondition(manualValues[field.id]=="架空新しい画面入力" && manualAcknowledged[field.id]==false)
coordinator.manualReview=nil
changeAcknowledgement();changeText("架空再開入力")
precondition(manualValues[field.id]=="架空再開入力" && manualAcknowledged[field.id]==false)
print("Verified actual stale/missing/review callback rejection and current callback operation.")
'''.replace("TEXT_CALLBACK", text).replace("ACK_CALLBACK", acknowledgement)
        with tempfile.TemporaryDirectory(prefix="manual-binding-callbacks-") as directory:
            path = Path(directory)
            (path / "main.swift").write_text(source, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-module-cache-path", str(path / "modules"),
                            str(path / "main.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_retention_route_keeps_explicit_draft_cancellation(self):
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        retention = application.split("if installed != period {")[1].split("loadedPeriod = period")[0]
        self.assertIn("await stopPrivateWork(resetNotifications: true)", retention)
        stopping = application.split("private func stopPrivateWork(")[1].split("func recoverRetention()")[0]
        self.assertIn("recovery.cancel()", stopping)

    def test_retention_waits_for_confirmed_notifications_before_advancing_or_resetting_marker(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production retention lifecycle")
        application = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        prepare = block(application, "    func prepare(")
        original_root = ('try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,\n'
                         '                                                  appropriateFor: nil, create: true)')
        self.assertEqual(prepare.count(original_root), 1)
        program = r'''import Foundation
@MainActor final class UIApplication {
    static let shared = UIApplication()
    var isProtectedDataAvailable = true
}
struct SchoolDataPeriod: Equatable {
    let half: Int
    static func current() -> Self { .init(half:2) }
}
@MainActor struct SchoolDataRetention {
    let root: URL
    enum Failure: Error, Equatable { case invalidMarker; case notificationCleanup(recoveringInvalidMarker:Bool) }
    static let privatePaths = ["fictional-private"]
    static var installed: SchoolDataPeriod? = .init(half:1)
    static var corrupt = false, replaced = 0, quarantined = 0
    func installedPeriod() throws -> SchoolDataPeriod? {
        if Self.corrupt { throw Failure.invalidMarker }
        return Self.installed
    }
    func replace(with period: SchoolDataPeriod) throws { Self.replaced += 1; Self.installed = period }
    func quarantineInvalidMarker() throws { Self.corrupt = false; Self.quarantined += 1 }
    func finishRecovery() throws {}
}
@MainActor final class FileRefreshDiagnostics {
    static let shared = FileRefreshDiagnostics()
    func clear() {}
}
@MainActor final class Unit {
    var closed = 0, resumed = 0, resets = 0
    func suspend() {}
    func resume() {}
    func allow() {}
    func cancel() {}
    func resumeAfterRetention() { resumed += 1 }
    func closeForRetention() async { closed += 1 }
    func stopForRetention() async { closed += 1 }
    func resetForRetention() { resets += 1 }
}
@MainActor final class UpdateNotifications {
    var response = true
    func suspendForUnavailableData() async -> Bool { response }
    func resetForRetention() async -> Bool { response }
}
@MainActor final class Countdown {
    var response = false
    var includesDelivered = [Bool]()
    func expirePrivateNotices(removeDelivered: Bool) async -> Bool {
        includesDelivered.append(removeDelivered)
        return response
    }
}
@MainActor final class Application {
    let testRoot: URL
    init(root: URL) { testRoot = root }
    let projections = Unit(), textMeasurements = Unit(), homeClock = Unit(), recovery = Unit()
    let notifications = UpdateNotifications(), account = Unit(), materials = Unit(), specialSchedules = Unit()
    let mappings = Unit(), links = Unit(), times = Unit(), countdown = Countdown()
    var ready = true, preparing = false, retentionNotice = false, retentionFailure = false
    var retentionFailureReason: SchoolDataRetention.Failure?
    var loadedPeriod: SchoolDataPeriod? = .init(half:1)
    func setFileMonitoring(_ enabled: Bool) { precondition(!enabled) }
RECOVERY_ACTION
PREPARE
STOP
}
@main struct Probe {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        try Data("fictional".utf8).write(to:root.appendingPathComponent("fictional-private"))
        for (corrupt, countdownResponds, updatesRespond) in [(false,false,true), (true,false,true), (false,true,false), (true,true,false)] {
            SchoolDataRetention.installed = .init(half:1)
            SchoolDataRetention.corrupt = corrupt
            SchoolDataRetention.replaced = 0
            SchoolDataRetention.quarantined = 0
            let app = Application(root:root)
            app.countdown.response = countdownResponds
            app.notifications.response = updatesRespond
            let blocked = await app.prepare(recoverInvalidMarker:corrupt)
            precondition(!blocked && !app.ready && app.loadedPeriod == nil && !app.preparing)
            precondition(app.retentionFailure && app.retentionFailureReason == .notificationCleanup(recoveringInvalidMarker:corrupt))
            precondition(app.canRecoverRetention == corrupt)
            precondition(SchoolDataRetention.corrupt == corrupt)
            precondition(SchoolDataRetention.installed?.half == 1 && SchoolDataRetention.replaced == 0)
            precondition(SchoolDataRetention.quarantined == 0 && app.materials.resumed == 0)
            precondition(app.account.closed == 1 && app.materials.closed == 1 && app.specialSchedules.closed == 1)
            precondition(app.links.resets == 1 && app.times.resets == 1 && app.countdown.includesDelivered == [true])
            app.countdown.response = true
            app.notifications.response = true
            let recovered = await app.prepare(recoverInvalidMarker:app.canRecoverRetention)
            precondition(recovered && app.ready && !app.retentionFailure && app.retentionFailureReason == nil)
            precondition(app.loadedPeriod?.half == 2 && app.retentionNotice && !app.preparing)
            precondition(SchoolDataRetention.replaced == 1 && SchoolDataRetention.quarantined == (corrupt ? 1 : 0))
            precondition(app.countdown.includesDelivered == [true,true])
        }
    }
}
'''.replace("RECOVERY_ACTION", block(application, "    var canRecoverRetention:")).replace(
    "PREPARE", prepare.replace(original_root, "testRoot")).replace(
    "STOP", block(application, "    private func stopPrivateWork("))
        with tempfile.TemporaryDirectory(prefix="retention-notice-retry-") as scratch:
            directory = Path(scratch)
            swift = directory / "Probe.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(directory / "modules"), str(swift),
                            "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)


if __name__ == "__main__":
    unittest.main()
