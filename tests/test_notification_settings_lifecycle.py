"""Execute the actual OS callback bridge with controlled native boundary responses.

The stubs verify concurrency and value transport, not Apple availability or UI.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]


class NotificationSettingsLifecycleTests(unittest.TestCase):
    def test_disabling_update_notices_removes_owned_ids_now_and_after_a_late_write(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the actual update notice settings and worker")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        methods = "\n".join(block(source, name) for name in (
            "func setEnabled(", "func disableNotifications(", "func finishDeferredNotificationRemovals(",
            "func clearDisabledNotifications(", "func removeUpdateNotifications(", "func drainPending()"))
        declarations = "\n".join(line for line in source.splitlines()
            if "static let updateIdentifiers" in line or "static let notificationStopPending" in line)
        program = r'''import Foundation
@MainActor final class UserDefaults {
    static let standard = UserDefaults()
    var values = [String:Bool]()
    func set(_ value: Bool, forKey key: String) { values[key] = value }
}
struct Snapshot { var pending = ["changes":1,"exam":2,"examReturn":3] }
@MainActor final class Center {
    let initial = ["takupoke.changes","takupoke.exam","takupoke.examReturn","fictional.unrelated"]
    lazy var pending = initial
    lazy var delivered = initial
    var waiting: CheckedContinuation<Void,Never>?
    var removals = [[String]]()
    func add(_ id: String) async {
        await withCheckedContinuation { waiting = $0 }
        pending.append(id); delivered.append(id)
    }
    func complete() { let callback = waiting; waiting = nil; callback?.resume() }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        pending.removeAll { ids.contains($0) }
        removals.append(ids)
    }
    func removeDeliveredNotifications(withIdentifiers ids: [String]) { delivered.removeAll { ids.contains($0) } }
}
@MainActor final class Schedule {
DECLARATIONS
    let center = Center()
    var changesEnabled = true, specialsEnabled = true, requestingPermission = false
    var message: String?, permissionMessage: String?
    var lastAppliedPermissionSequence = 0, permissionReadSequence = 0
    var baseline: Snapshot? = Snapshot(), pending: String?
    var reconcileTask: NotificationWork?
    var disabledNotificationsAwaitingWrite = Set<String>()
    static func requestAuthorization(from center: Center) async throws -> Bool { true }
    func storageFile() throws -> URL { URL(fileURLWithPath:"/fictional-discarded") }
    func save(_ snapshot: Snapshot, to url: URL) throws { baseline = snapshot }
    func apply(_ id: String) async { await center.add(id) }
    func start(_ id: String) -> Task<Void,Never> {
        Task { pending = id; await drainPending() }
    }
METHODS
}
@main struct Probe {
    @MainActor static func observe(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        while !condition() { precondition(ContinuousClock.now < deadline); await Task.yield() }
    }
    @MainActor static func main() async {
        let slow = Schedule(), reenabled = Schedule()
        let writeChanges = slow.start("takupoke.changes"), writeExam = reenabled.start("takupoke.exam")
        await observe { slow.center.waiting != nil && reenabled.center.waiting != nil }
        let offChanges = Task { await slow.setEnabled(changes:true,value:false) }
        let offExams = Task { await reenabled.setEnabled(changes:false,value:false) }
        await observe {
            UserDefaults.standard.values["notifyScheduleChanges"] == false &&
            UserDefaults.standard.values["notifySpecialSchedules"] == false &&
            !slow.center.pending.contains("takupoke.changes") && !reenabled.center.pending.contains("takupoke.exam")
        }
        let otherNotifications = ["takupoke.exam","takupoke.examReturn","fictional.unrelated"]
        precondition(slow.center.pending == otherNotifications && slow.center.delivered == otherNotifications)
        precondition(slow.reconcileTask?.task.isCancelled == true && slow.center.waiting != nil)
        precondition(reenabled.center.pending == ["takupoke.changes","fictional.unrelated"])

        await reenabled.setEnabled(changes:false,value:true)
        reenabled.center.complete()
        await writeExam.value; await offExams.value
        precondition(reenabled.specialsEnabled && reenabled.center.pending.contains("takupoke.exam"))
        precondition(reenabled.center.delivered.contains("takupoke.exam") && reenabled.center.removals.count == 1)
        precondition(reenabled.baseline?.pending == Snapshot().pending)

        await offChanges.value
        precondition(!slow.changesEnabled && slow.specialsEnabled && slow.center.waiting != nil && slow.message != nil)
        precondition(slow.baseline?.pending == Snapshot().pending)
        slow.center.complete()
        await writeChanges.value
        precondition(slow.center.pending == otherNotifications && slow.center.delivered == otherNotifications)
        precondition(slow.center.removals == [["takupoke.changes"],["takupoke.changes"]])
        precondition(slow.baseline?.pending == ["exam":2,"examReturn":3] && slow.message == nil)
        precondition(slow.reconcileTask == nil && slow.disabledNotificationsAwaitingWrite.isEmpty)

        let idle = Schedule()
        await idle.setEnabled(changes:false,value:false)
        precondition(idle.center.pending == ["takupoke.changes","fictional.unrelated"] && idle.center.pending == idle.center.delivered)
        precondition(idle.baseline?.pending == ["changes":1] && idle.message == nil)
        print("Verified immediate owned removals, bounded stop, late write cleanup, and a newer explicit opt-in.")
    }
}
'''.replace("DECLARATIONS", declarations).replace("METHODS", methods)
        program += "\n@MainActor\n" + block(source, "final class NotificationWork {")
        self.run_probe(compiler, program, swift_version="6")

    def test_countdown_retries_only_rejected_missing_reservations_while_plan_is_current(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production reservation loop")
        source = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        program = r'''import Foundation
enum SchoolDate {
    static var japanCalendar: Calendar {
        var calendar = Calendar(identifier:.gregorian)
        calendar.timeZone = TimeZone(identifier:"Asia/Tokyo")!
        return calendar
    }
}
struct CountdownNotice {
    let identifier: String
    let title = "架空通知"
    let fireAt: Date
    let targetID = UUID()
    let targetKey = "fictional"
    let classScope: String? = nil
    init(_ id: String, fromNow interval: TimeInterval = 3600) {
        identifier = id
        fireAt = Date().addingTimeInterval(interval)
    }
}
struct UNCalendarNotificationTrigger {
    let dateMatching: DateComponents
    let repeats: Bool
}
struct Sound { static let `default` = Sound() }
final class UNMutableNotificationContent {
    var title = "", body = ""
    var sound: Sound?
    var userInfo = [String:Any]()
}
struct UNNotificationRequest {
    let identifier: String
    let content: UNMutableNotificationContent
    let trigger: UNCalendarNotificationTrigger
}
@MainActor final class Center {
    var requests = [String:UNNotificationRequest]()
    var called = [String](), removals = [String]()
    var failOnce = Set<String>(), failPermanently = Set<String>()
    var rejectedButAppearsLater: UNNotificationRequest?
    var withheldRead: Int?
    var pausesAdd = false
    var unfinishedAdd: CheckedContinuation<Void, Never>?
    var reads = 0
    func pendingNotificationRequests() async -> [UNNotificationRequest]? {
        reads += 1
        if reads == withheldRead { return nil }
        if reads == 2, let rejectedButAppearsLater { requests[rejectedButAppearsLater.identifier] = rejectedButAppearsLater }
        return Array(requests.values)
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { requests.removeValue(forKey:id); removals.append(id) }
    }
    func add(_ request: UNNotificationRequest) async throws {
        let id = request.identifier
        called.append(id)
        precondition(!request.trigger.repeats && request.trigger.dateMatching.timeZone?.identifier == "Asia/Tokyo")
        if id == "late" { rejectedButAppearsLater = request; throw CocoaError(.fileReadUnknown) }
        if failOnce.remove(id) != nil || failPermanently.contains(id) { throw CocoaError(.fileReadUnknown) }
        if pausesAdd { await withCheckedContinuation { unfinishedAdd = $0 } }
        requests[id] = request
    }
}
@MainActor enum ScheduleNotifications {
    static func readPending(from center: Center) async -> [UNNotificationRequest]? {
        await center.pendingNotificationRequests()
    }
}
@MainActor final class Harness {
    struct NoticePlan { let revision: UUID; let desired: [CountdownNotice] }
    var revision = UUID()
    let center = Center()
    func apply(_ desired: [CountdownNotice], allowed: Bool = true) async -> [String]? {
        let known = Array(center.requests.values)
        return await reserveNotifications(.init(revision:revision,desired:desired),allowed:allowed,startingWith:known)?.map(\.identifier).sorted()
    }
RESERVE
MATCH
}
@main struct Probe {
    @MainActor static func waitForRead(_ center: Center) async {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        while center.reads == 0 { precondition(ContinuousClock.now < deadline); await Task.yield() }
    }
    @MainActor static func main() async {
        let h = Harness()
        let confirmed = CountdownNotice("already-confirmed")
        let first = await h.apply([confirmed])
        precondition(first == ["already-confirmed"])
        h.center.called.removeAll(); h.center.reads = 0
        h.center.failOnce = ["transient"]
        h.center.failPermanently = ["persistent"]
        let result = await h.apply([confirmed,.init("ordinary"),.init("transient"),.init("persistent"),.init("expired",fromNow:-1)])
        precondition(result == ["already-confirmed","ordinary","transient"] && h.center.reads == 5)
        precondition(h.center.called == ["ordinary","transient","persistent","transient","persistent","persistent"])
        precondition(h.center.removals.isEmpty)
        let disabled = await h.apply([.init("disabled")],allowed:false)
        precondition(disabled == result && !h.center.called.contains("disabled"))

        let late = Harness()
        let revealed = await late.apply([.init("late")])
        precondition(revealed == ["late"] && late.center.called == ["late"] && late.center.reads == 2)

        for stoppedRead in [1,2] {
            let unknown = Harness()
            unknown.center.failOnce = ["unknown"]
            unknown.center.withheldRead = stoppedRead
            let result = await unknown.apply([.init("unknown")])
            precondition(result == nil && unknown.center.called == ["unknown"] && unknown.center.reads == stoppedRead)
        }

        for supersede in [false,true] {
            let stale = Harness()
            stale.center.failOnce = ["rejected"]
            let task = Task { await stale.apply([.init("rejected")]) }
            await waitForRead(stale.center)
            if supersede { stale.revision = UUID() } else { task.cancel() }
            let stopped = await task.value
            precondition(stopped == nil && stale.center.called == ["rejected"] && stale.center.reads == 1)
        }

        for cancel in [false,true] {
            let stale = Harness()
            stale.center.pausesAdd = true
            let personal = CountdownNotice("fictional.personal")
            let privateNotice = CountdownNotice("fictional.private")
            let task = Task { await stale.apply([personal,privateNotice]) }
            let deadline = ContinuousClock.now.advanced(by:.seconds(3))
            while stale.center.unfinishedAdd == nil {
                precondition(ContinuousClock.now < deadline); await Task.yield()
            }
            stale.revision = UUID()
            if cancel { task.cancel() }
            stale.center.unfinishedAdd?.resume(); stale.center.unfinishedAdd = nil
            let stopped = await task.value
            precondition(stopped == nil && stale.center.called == [personal.identifier])
            precondition((stale.center.requests[personal.identifier] == nil) == cancel)
            precondition(stale.center.removals == (cancel ? [personal.identifier] : []))
        }
    }
}
'''.replace("RESERVE", block(source, "private func reserveNotifications(")).replace(
    "MATCH", block(source, "private func matches("))
        self.run_probe(compiler, program)

    def test_explicit_countdown_authorization_starts_without_a_settings_read(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production countdown permission action")
        source = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        action = block(source, "func notificationPermission()")
        program = r'''import Foundation
final class Center {
    enum Authorization { case notDetermined }
    let authorizationStatus = Authorization.notDetermined
    var requests = 0, settingsReads = 0
    var response: Result<Bool,CocoaError> = .success(true)
}
@MainActor enum ScheduleNotifications {
    static func notificationSettings(from center:Center) async -> Center {
        center.settingsReads += 1
        return center
    }
    static func requestAuthorization(from center:Center) async throws -> Bool {
        center.requests += 1
        return try center.response.get()
    }
}
@MainActor final class CountdownProbe {
    let center = Center()
    var message: String?
ACTION
}
@main struct Probe {
    @MainActor static func main() async {
        for granted in [false,true] {
            let model = CountdownProbe()
            model.center.response = .success(granted)
            await model.notificationPermission()
            precondition(model.center.requests == 1 && model.center.settingsReads == 0 && model.message == nil)
        }
        let failure = CountdownProbe()
        failure.center.response = .failure(CocoaError(.fileReadUnknown))
        await failure.notificationPermission()
        precondition(failure.center.requests == 1 && failure.center.settingsReads == 0 && failure.message != nil)
    }
}
'''.replace("ACTION", action)
        self.run_probe(compiler, program)

    def test_countdown_storage_actions_remove_only_owned_pending_notifications(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production storage recovery actions")
        source = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        notifications = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        prefix = next(line for line in (ROOT / "Takupoke/Countdown.swift").read_text(encoding="utf-8").splitlines()
                      if line.startswith('    static let prefix = "takupoke.countdown.'))
        program = r'''import Foundation
enum CountdownNotice {
PREFIX
}
struct CountdownLibrary {}
final class CountdownStore {
    enum ReadError: Error { case noLongerCorrupt, corrupt, unsafeFile }
    var fails = false, writes = 0
    var readError: ReadError? = .corrupt
    func load() throws -> CountdownLibrary {
        if let readError { throw readError }
        return CountdownLibrary()
    }
    func preserveCorruptFileAndReset() throws {
        if fails { throw CocoaError(.fileWriteOutOfSpace) }
        writes += 1
    }
}
@MainActor final class FakeCenter {
    struct Request: Sendable { var identifier: String }
    var state = ["takupoke.countdown.personal.example", "takupoke.countdown.private.example", "takupoke.materials", "takupoke.countdown-other"]
    var reads = 0, responds = true
    var removals: [[String]] = []
    var held: (@Sendable ([Request]) -> Void)?
    nonisolated func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([Request]) -> Void) {
        Task { @MainActor in
            reads += 1
            if responds { completionHandler(state.map { Request(identifier: $0) }) }
            else { held = completionHandler }
        }
    }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removals.append(ids)
        state.removeAll(where: ids.contains)
    }
}
typealias UNUserNotificationCenter = FakeCenter
typealias UNNotificationRequest = FakeCenter.Request
@MainActor enum ScheduleNotifications {
    BRIDGE
}
@MainActor final class Harness {
    STATE
    let center = FakeCenter(), availableStore = CountdownStore()
    var store: CountdownStore?, library = CountdownLibrary(), message: String?
    var storageState = StorageState.unavailable, storageActionInProgress = false
    var onChange: (() -> Void)?, revision = UUID(), request: Int? = 1, worker: Task<Void, Never>?
    func openStore() throws -> CountdownStore { availableStore }
    LOAD
    RETRY
    RECOVER
    STOP
    REMOVE
}
@main struct Probe {
    @MainActor static func main() async {
        let unchanged = ["takupoke.materials", "takupoke.countdown-other"]
        let stop = Harness()
        await stop.stopNoticesWhileStorageIsUnavailable()
        precondition(stop.center.state == unchanged && stop.center.reads == 1)
        precondition(stop.request == nil && !stop.storageActionInProgress && stop.storageState == .unavailable)
        precondition(stop.availableStore.writes == 0)
        stop.availableStore.readError = .unsafeFile
        stop.retryStorageLoad()
        precondition(stop.message?.contains("読み込めません") == true)

        let reset = Harness()
        await reset.recoverCorruptStorage()
        precondition(reset.center.reads == 0 && reset.availableStore.writes == 0)
        reset.storageState = .corrupt
        reset.availableStore.fails = true
        await reset.recoverCorruptStorage()
        precondition(reset.storageState == .corrupt && !reset.storageActionInProgress && reset.center.reads == 0)
        reset.availableStore.readError = .unsafeFile
        await reset.recoverCorruptStorage()
        precondition(reset.storageState == .unavailable && reset.center.reads == 0)
        reset.availableStore.readError = .corrupt
        reset.retryStorageLoad()
        precondition(reset.storageState == .corrupt)
        reset.availableStore.fails = false
        var callbacks = 0
        reset.onChange = {
            precondition(reset.storageState == .ready && !reset.storageActionInProgress)
            precondition(reset.center.state == unchanged)
            callbacks += 1
        }
        await reset.recoverCorruptStorage()
        precondition(callbacks == 1 && reset.availableStore.writes == 1 && reset.center.reads == 1)
        await reset.stopNoticesWhileStorageIsUnavailable()
        precondition(reset.center.reads == 1)

        let delayed = FakeCenter()
        delayed.responds = false
        let query = Task { await ScheduleNotifications.pendingStorageRecoveryIdentifiers(from:delayed) }
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        while delayed.held == nil {
            precondition(ContinuousClock.now < deadline)
            await Task.yield()
        }
        delayed.held?([.init(identifier:"actual-response")])
        let result = await query.value
        precondition(result == ["actual-response"] && delayed.reads == 1)

        let stalledStop = Harness(), stalledReset = Harness()
        for model in [stalledStop, stalledReset] { model.center.responds = false }
        stalledReset.storageState = .corrupt
        async let stopping: Void = stalledStop.stopNoticesWhileStorageIsUnavailable()
        async let resetting: Void = stalledReset.recoverCorruptStorage()
        _ = await (stopping, resetting)
        precondition(stalledStop.storageState == .unavailable && stalledStop.message?.contains("確認できません") == true)
        precondition(stalledReset.availableStore.writes == 1 && stalledReset.storageState == .ready)
        precondition(stalledReset.message?.contains("確認できていません") == true)
        for model in [stalledStop, stalledReset] {
            precondition(model.center.reads == 1 && model.center.held != nil)
            let message = model.message
            model.center.held?(model.center.state.map { .init(identifier:$0) })
            await Task.yield()
            precondition(model.center.removals.isEmpty && model.center.state.count == 4)
            precondition(!model.storageActionInProgress && model.message == message)
        }
    }
}
'''.replace("PREFIX", prefix) \
           .replace("BRIDGE", "\n".join(block(notifications, marker) for marker in (
               "nonisolated static func notificationQuery", "nonisolated static func readPending",
               "nonisolated static func pendingStorageRecoveryIdentifiers"))) \
           .replace("STATE", block(source, "enum StorageState")) \
           .replace("LOAD", block(source, "func load(reportFailure:")) \
           .replace("RETRY", block(source, "func retryStorageLoad()")) \
           .replace("RECOVER", block(source, "func recoverCorruptStorage()")) \
           .replace("STOP", block(source, "func stopNoticesWhileStorageIsUnavailable()")) \
           .replace("REMOVE", block(source, "private func removeUnavailableStorageNotices()"))
        self.run_probe(compiler, program)

    def test_authorization_bridge_requires_one_real_callback_and_preserves_denial_and_errors(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production authorization bridge")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        start = source.index("    static func requestAuthorization(")
        end = source.index("    func enableFromSetup()", start)
        program = r'''import Foundation
struct UNAuthorizationOptions: OptionSet, Sendable {
    let rawValue: Int
    static let alert = Self(rawValue: 4), sound = Self(rawValue: 2)
}
final class UNUserNotificationCenter: @unchecked Sendable {
    typealias Callback = @Sendable (Bool, Error?) -> Void
    private let lock = NSLock()
    private var calls = 0
    private var callback: Callback?
    private var requested: UNAuthorizationOptions = []
    let immediate: (Bool, Error?)?
    init(_ immediate: (Bool, Error?)? = nil) { self.immediate = immediate }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    var options: UNAuthorizationOptions { lock.lock(); defer { lock.unlock() }; return requested }
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping Callback) {
        MainActor.assertIsolated()
        lock.lock(); calls += 1; callback = completionHandler; requested = options; lock.unlock()
        if let immediate { completionHandler(immediate.0, immediate.1) }
    }
    func complete(_ granted: Bool, _ error: Error? = nil) {
        lock.lock(); let handler = callback; lock.unlock()
        precondition(handler != nil); handler?(granted, error)
    }
}
final class Completion: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    func finish() { lock.lock(); finished = true; lock.unlock() }
    var value: Bool { lock.lock(); defer { lock.unlock() }; return finished }
}
@MainActor final class Harness {
BRIDGE
    nonisolated static func request(_ center: UNUserNotificationCenter) async throws -> Bool {
        try await requestAuthorization(from: center)
    }
}
@main struct Probe {
    static func main() async throws {
        let failure = NSError(domain: "fictional-authorization", code: 7)
        for granted in [false, true] {
            let center = UNUserNotificationCenter((granted, nil))
            let result = try await Harness.request(center)
            precondition(result == granted && center.count == 1 && center.options == [.alert, .sound])
            // The actual OS error wins even if its Boolean is contradictory.
            let failing = UNUserNotificationCenter((granted, failure))
            do {
                _ = try await Harness.request(failing)
                preconditionFailure("An OS error must not grant permission")
            } catch { precondition((error as NSError) === failure && failing.count == 1) }
        }
        for granted in [false, true] {
            let center = UNUserNotificationCenter(), observed = Completion()
            let task = Task {
                let result = try await Harness.request(center)
                observed.finish(); return result
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while center.count == 0 {
                precondition(ContinuousClock.now < deadline); await Task.yield()
            }
            precondition(center.count == 1 && !observed.value)
            task.cancel()
            // Cancellation cannot fabricate a result or a second OS request.
            precondition(!observed.value && center.count == 1)
            center.complete(granted)
            let result = try await task.value
            precondition(result == granted && task.isCancelled && center.count == 1 && observed.value)
        }
        print("Verified production authorization bridge: one request, actual callback, denial and exact errors.")
    }
}
'''.replace("BRIDGE", source[start:end])
        self.run_probe(compiler, program)

    def test_actual_bridge_preserves_os_objects_and_finishes_cancelled_or_missing_reads(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production callback bridge")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        bridge = "\n".join(block(source, "nonisolated static func " + name) for name in (
            "notificationSettings(", "notificationQuery"))
        program = r'''import Foundation
final class UNNotificationSettings: @unchecked Sendable {
    let authorizationStatus: Int
    init(_ value: Int) { authorizationStatus = value }
}
final class UNUserNotificationCenter: @unchecked Sendable {
    let immediate: UNNotificationSettings?
    private let lock = NSLock()
    private var callbacks = [@Sendable (UNNotificationSettings) -> Void]()
    init(_ value: UNNotificationSettings? = nil) { immediate = value }
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return callbacks.count
    }
    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {
        lock.lock(); callbacks.append(completionHandler); lock.unlock()
        if let immediate { completionHandler(immediate) }
    }
    func complete(_ index: Int, _ value: UNNotificationSettings) {
        lock.lock(); let callback = callbacks[index]; lock.unlock()
        callback(value)
    }
}
final class Harness {
BRIDGE
    nonisolated static func read(_ center: UNUserNotificationCenter,
                                 timeout: Duration = .seconds(6)) async -> UNNotificationSettings? {
        await notificationSettings(from:center,timeout:timeout)
    }
}
@main struct Probe {
    static func waitForReads(_ count: Int, _ center: UNUserNotificationCenter) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while center.count != count {
            precondition(ContinuousClock.now < deadline, "OS read was not issued")
            await Task.yield()
        }
    }
    static func main() async {
        // Return the exact OS object, including a future unknown raw status.
        for status in [0, 1, 2, 3, 4, 99] {
            let original = UNNotificationSettings(status)
            let center = UNUserNotificationCenter(original)
            let result = await Harness.read(center)
            precondition(result === original && result?.authorizationStatus == status)
            precondition(center.count == 1)
        }
        let center = UNUserNotificationCenter()
        let first = Task { await Harness.read(center) }
        await waitForReads(1, center)
        let second = Task { await Harness.read(center) }
        await waitForReads(2, center)
        let later = UNNotificationSettings(2), earlier = UNNotificationSettings(1)
        // Two overlapping reads keep their own continuations. Completing the
        // second first must not complete the first or manufacture permission.
        center.complete(1, later)
        let secondResult = await second.value
        precondition(secondResult === later && center.count == 2)
        first.cancel()
        let firstResult = await first.value
        precondition(firstResult == nil && first.isCancelled && center.count == 2)
        let expired = await Harness.read(center,timeout:.milliseconds(40))
        precondition(expired == nil && center.count == 3)
        let next = Task { await Harness.read(center) }
        await waitForReads(4,center)
        center.complete(0,earlier)
        center.complete(2,earlier)
        center.complete(3,later)
        let nextResult = await next.value
        precondition(nextResult === later && center.count == 4)
        print("Verified actual bridge: exact OS objects, one read per call, cancellation, deadlines, and late callback isolation.")
    }
}
'''.replace("BRIDGE", bridge)
        self.run_probe(compiler, program)

    def test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production delivery gate")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        bridge = "\n".join(block(source, "nonisolated static func " + name) for name in (
            "notificationSettings(", "notificationQuery"))
        observed = block(source, "    private func readCurrentNotificationSettings(")
        permission = block(source, "    func checkPermission() async")
        gate_start = source.index("    private func deliveryAllowed() async -> Bool? {")
        gate_end = source.index("    private func apply(", gate_start)
        program = r'''import Foundation
enum Authorization: Int {
    case notDetermined = 0, denied = 1, authorized = 2, provisional = 3, ephemeral = 4, unknown = 99
}
final class UNNotificationSettings: @unchecked Sendable {
    let authorizationStatus: Authorization
    init(_ value: Authorization) { authorizationStatus = value }
}
final class UNUserNotificationCenter: @unchecked Sendable {
    let response: UNNotificationSettings?
    private let lock = NSLock()
    private var reads = [@Sendable (UNNotificationSettings) -> Void]()
    init(_ response: UNNotificationSettings?) { self.response = response }
    var count: Int { lock.lock(); defer { lock.unlock() }; return reads.count }
    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {
        lock.lock(); reads.append(completionHandler); lock.unlock()
        // nil models an OS service that never responds. The disabled branch
        // must complete without touching it, not wait for a synthesized reply.
        if let response { completionHandler(response) }
    }
    func complete(_ index: Int, authorization: Authorization) {
        lock.lock(); let callback = reads[index]; lock.unlock()
        callback(UNNotificationSettings(authorization))
    }
}
@MainActor final class Harness {
    let changesEnabled: Bool
    let specialsEnabled: Bool
    let center: UNUserNotificationCenter
    var message: String?
    var permissionMessage: String?
    private var permissionReadSequence = 0, lastAppliedPermissionSequence = 0
    init(_ changes: Bool, _ specials: Bool, _ center: UNUserNotificationCenter) {
        changesEnabled = changes; specialsEnabled = specials; self.center = center
    }
BRIDGE
OBSERVED
GATE
PERMISSION
    func evaluate() async -> Bool? { await deliveryAllowed() }
}
@main struct Probe {
    static func waitForReads(_ count: Int, _ center: UNUserNotificationCenter) async {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        while center.count != count { precondition(ContinuousClock.now < deadline); await Task.yield() }
    }

    @MainActor static func verifyReadOrder(newerDelivery: Bool, earlierStatus: Authorization,
                                           currentStatus: Authorization) async {
        let center = UNUserNotificationCenter(nil)
        let harness = Harness(true,false,center)
        harness.message = "independent storage failure"
        let earlier = Task { () -> Bool? in
            if !newerDelivery { return await harness.evaluate() }
            await harness.checkPermission()
            return nil
        }
        await waitForReads(1,center)
        let current = Task { () -> Bool? in
            if newerDelivery { return await harness.evaluate() }
            await harness.checkPermission()
            return nil
        }
        await waitForReads(2,center)
        center.complete(1,authorization:currentStatus)
        let confirmed = await current.value
        if newerDelivery { precondition(confirmed == (currentStatus == .authorized)) }
        let expected = currentStatus == .denied ? "iPhoneの設定で通知を許可してください。" : nil
        precondition(harness.permissionMessage == expected)
        center.complete(0,authorization:earlierStatus)
        let stale = await earlier.value
        precondition(stale == nil && harness.permissionMessage == expected)
        precondition(harness.message == "independent storage failure" && center.count == 2)
    }

    @MainActor static func main() async {
        let unavailable = UNUserNotificationCenter(nil)
        let disabled = Harness(false, false, unavailable)
        let disabledResult = await disabled.evaluate()
        precondition(disabledResult == false && unavailable.count == 0)
        disabled.permissionMessage = "iPhoneの設定で通知を許可してください。"
        await disabled.checkPermission()
        precondition(disabled.permissionMessage == nil && disabled.message == nil && unavailable.count == 0)
        disabled.message = "unrelated failure"
        await disabled.checkPermission()
        precondition(disabled.message == "unrelated failure" && unavailable.count == 0)
        for status in [Authorization.notDetermined, .denied, .authorized, .provisional, .ephemeral, .unknown] {
            for (changes, specials) in [(false, false), (true, false), (false, true), (true, true)] {
                let center = UNUserNotificationCenter(UNNotificationSettings(status))
                let result = await Harness(changes, specials, center).evaluate()
                let enabled = changes || specials
                let allowed = [.authorized, .provisional, .ephemeral].contains(status)
                precondition(result == (enabled && allowed))
                precondition(center.count == (enabled ? 1 : 0))
                let harness = Harness(changes, specials, center)
                for previous in [nil, "iPhoneの設定で通知を許可してください。", "unrelated failure"] {
                    harness.permissionMessage = previous
                    harness.message = "independent storage failure"
                    await harness.checkPermission()
                    let expected = enabled && status == .denied
                        ? "iPhoneの設定で通知を許可してください。"
                        : nil
                    precondition(harness.permissionMessage == expected)
                    precondition(harness.message == "independent storage failure")
                }
                precondition(center.count == (enabled ? 4 : 0))
            }
        }
        for newerDelivery in [false,true] {
            await verifyReadOrder(newerDelivery:newerDelivery,earlierStatus:.denied,currentStatus:.authorized)
            await verifyReadOrder(newerDelivery:newerDelivery,earlierStatus:.authorized,currentStatus:.denied)
        }
        print("Verified production gate: disabled uses no OS request; older callbacks cannot overwrite confirmed permission.")
    }
}
'''.replace("BRIDGE", bridge).replace("OBSERVED", observed).replace("GATE", source[gate_start:gate_end]).replace(
    "PERMISSION", permission)
        self.run_probe(compiler, program)

    def test_actual_apply_keeps_denial_separate_from_storage_success_and_failure(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for the production permission/apply methods")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        permission = block(source, "    func checkPermission() async")
        bridge = "\n".join(block(source, "nonisolated static func " + name) for name in (
            "notificationSettings(", "notificationQuery", "readPending", "readDelivered"))
        observed = block(source, "    private func readCurrentNotificationSettings(")
        gate_start = source.index("    private func deliveryAllowed() async -> Bool? {")
        methods = source[gate_start:source.index("    private func changeNotice(", gate_start)]
        program = r'''import Foundation
enum Authorization { case denied, authorized, provisional, ephemeral }
final class UNNotificationSettings: @unchecked Sendable { let authorizationStatus:Authorization; init(_ status:Authorization){authorizationStatus=status} }
final class UNUserNotificationCenter: @unchecked Sendable {
 var response:UNNotificationSettings?=UNNotificationSettings(.denied)
 private let lock=NSLock()
 private var count=0
 var reads:Int{lock.lock();defer{lock.unlock()};return count}
 func getNotificationSettings(completionHandler:@escaping @Sendable (UNNotificationSettings)->Void){
  lock.lock();count+=1;lock.unlock()
  if let response{completionHandler(response)}
 }
 func getPendingNotificationRequests(completionHandler:@escaping @Sendable ([UNNotificationRequest])->Void){completionHandler([])}
 func getDeliveredNotifications(completionHandler:@escaping @Sendable ([UNNotification])->Void){completionHandler([])}
}
struct UNNotificationRequest { let identifier:String; let content:Content }
struct Content { let userInfo:[AnyHashable:Any] }
struct UNNotification { let request:UNNotificationRequest }
struct SchoolDate { static func today()->Self{Self()} }
struct SchoolDataPeriod:Equatable { static func current()->Self{Self()} }
struct ChangeNormalizer { static func canonicalClassName(_ value:String)->String{value} }
final class UIApplication { static let shared=UIApplication();var isProtectedDataAvailable=true }
struct ScheduleNotificationSnapshot:Codable,Equatable {
 struct Change:Codable,Hashable{};struct ChangeTarget:Codable,Equatable{}
 struct Pending:Codable,Equatable { var fingerprint="fictional";var changeTargets:[ChangeTarget]? }
 enum State {case available,unavailable}
 struct Availability {func state(for kind:String)->State{.unavailable}}
 var revision=0;var pending=[String:Pending]()
 static func load(from file:URL)throws->Self{preconditionFailure("This permission probe starts with an already loaded baseline")}
 func reconciling(changes:Set<Change>?,specials:[String:String],availability:Availability,today:SchoolDate,classes:Set<String>,changesEnabled:Bool,specialsEnabled:Bool,changeDocument:String?,personalEdit:Bool)throws->Self{var next=self;next.revision+=1;return next}
 func validTargets(_ targets:[ChangeTarget],in changes:Set<Change>,today:SchoolDate,classes:Set<String>)->[ChangeTarget]{targets}
}
@MainActor final class Harness {
 var changesEnabled=true,specialsEnabled=true,message:String?,permissionMessage:String?
 private var permissionReadSequence=0,lastAppliedPermissionSequence=0
 let center=UNUserNotificationCenter();var generation=UUID(),latestRevision=UUID(),loaded=true
 var baseline:ScheduleNotificationSnapshot?=ScheduleNotificationSnapshot();var failSave=false,saves=0
 let root:URL
 init(_ root:URL){self.root=root}
 struct Input {var changeDocument:String? = nil;var personalEdit=false;var revision:UUID;var period=SchoolDataPeriod.current();var changes:Set<ScheduleNotificationSnapshot.Change>?;var specials=[String:String]();var availability=ScheduleNotificationSnapshot.Availability()}
 func storageFile()throws->URL{root.appendingPathComponent("fictional-baseline.json")}
 func save(_ value:ScheduleNotificationSnapshot,to file:URL)throws{saves+=1;if failSave{throw CocoaError(.fileWriteNoPermission)};baseline=value}
 func send(kind:String,notice:ScheduleNotificationSnapshot.Pending)async throws{preconditionFailure("No notice is eligible in this baseline-only fixture")}
 func changeNotice(_ targets:[ScheduleNotificationSnapshot.ChangeTarget])throws->ScheduleNotificationSnapshot.Pending{.init()}
PERMISSION
BRIDGE
OBSERVED
METHODS
 func update()async{await apply(Input(revision:latestRevision))}
}
@main struct Probe {
 @MainActor static func main()async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("notification-permission-"+UUID().uuidString)
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:root)}
  let h=Harness(root), denied="iPhoneの設定で通知を許可してください。"
  await h.checkPermission();precondition(h.permissionMessage==denied || h.message==denied)
  await h.update()
  precondition(h.permissionMessage==denied,"Successful baseline reconciliation must retain the OS denial warning")
  precondition(h.message==nil && h.changesEnabled && h.specialsEnabled && h.saves==1)
  h.failSave=true;await h.update()
  precondition(h.permissionMessage==denied && h.message=="通知の更新確認を保存できませんでした。","Storage failure and denial must remain independently visible")
  h.center.response=UNNotificationSettings(.authorized);await h.checkPermission()
  precondition(h.permissionMessage==nil && h.message != nil,"Authorization recovery must not clear the storage failure")
  h.failSave=false;await h.update();precondition(h.message==nil && h.permissionMessage==nil)
  h.center.response=UNNotificationSettings(.denied);await h.checkPermission();precondition(h.permissionMessage==denied)
  h.center.response=nil
  let original=h.baseline, saves=h.saves, reads=h.center.reads
  let unavailable=Task{await h.update()}
  let deadline=ContinuousClock.now.advanced(by:.seconds(3))
  while h.center.reads==reads{precondition(ContinuousClock.now<deadline);await Task.yield()}
  unavailable.cancel();await unavailable.value
  precondition(h.baseline==original && h.saves==saves && h.permissionMessage==denied)
  h.center.response=UNNotificationSettings(.authorized);await h.update()
  precondition(h.saves==saves+1 && h.baseline?.revision==(original?.revision ?? 0)+1 && h.permissionMessage==nil)
  h.center.response=UNNotificationSettings(.denied);await h.checkPermission();precondition(h.permissionMessage==denied)
  h.changesEnabled=false;h.specialsEnabled=false;let count=h.center.reads
  await h.checkPermission();await h.update()
  precondition(h.permissionMessage==nil && h.center.reads==count,"Both-off must clear permission state without asking the OS")
  print("Actual permission/apply: denial survives reconcile, storage failure coexists, authorization recovers independently, and disabled settings do not read the OS.")
 }
}
'''.replace("PERMISSION", permission).replace("BRIDGE", bridge).replace("OBSERVED", observed).replace("METHODS", methods)
        self.run_probe(compiler, program)

    def test_retention_can_retry_private_notification_cleanup_after_unknown_os_reads(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute production expiry and passive callbacks")
        notifications = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        model = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        bridges = "\n".join(block(notifications, "nonisolated static func " + name) for name in (
            "notificationSettings(", "notificationQuery", "readPending", "readDelivered"))
        program = r'''import Foundation
struct UNNotificationSettings: Sendable {}
struct UNNotificationRequest: Sendable { let identifier: String }
struct UNNotification: Sendable { let request: UNNotificationRequest }
enum CountdownNotice { static let privatePrefix = "fictional.private." }
@MainActor final class UNUserNotificationCenter {
    let all = ["fictional.private.1", "fictional.personal.1", "fictional.school.1", "unrelated"]
    var reads = [0, 0, 0]
    var respondToPending = false, respondToDelivered = false
    var settingsCallback: (@Sendable (UNNotificationSettings) -> Void)?
    var pending: (@Sendable ([UNNotificationRequest]) -> Void)?
    var delivered: (@Sendable ([UNNotification]) -> Void)?
    var removed = [String](), removedDelivered = [String]()
    nonisolated func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {
        Task { @MainActor in reads[0] += 1; settingsCallback = completionHandler }
    }
    nonisolated func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void) {
        Task { @MainActor in
            reads[1] += 1
            if respondToPending { completionHandler(all.map(UNNotificationRequest.init)) }
            else { pending = completionHandler }
        }
    }
    nonisolated func getDeliveredNotifications(completionHandler: @escaping @Sendable ([UNNotification]) -> Void) {
        Task { @MainActor in
            reads[2] += 1
            if respondToDelivered { completionHandler(all.map { UNNotification(request:.init(identifier:$0)) }) }
            else { delivered = completionHandler }
        }
    }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) { removed += ids }
    func removeDeliveredNotifications(withIdentifiers ids: [String]) { removedDelivered += ids }
}
enum ScheduleNotifications {
BRIDGES
}
struct Card { let isPrivate: Bool }
@MainActor final class Harness {
    let center = UNUserNotificationCenter()
    var cards = [Card(isPrivate:true),Card(isPrivate:false)]
    var notificationCards = [0:Card(isPrivate:true),1:Card(isPrivate:false)]
    var revision = UUID()
    var request: Int? = 0
    var worker: NotificationWork?
    func begin() {
        worker = NotificationWork { [self] in
            let settings = await ScheduleNotifications.notificationSettings(from:center)
            precondition(!Task.isCancelled && settings != nil)
            worker = nil
        }
    }
EXPIRY
}
@main struct Probe {
    @MainActor static func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        while !condition() { precondition(ContinuousClock.now < deadline); await Task.yield() }
    }
    @MainActor static func main() async {
        let h = Harness(), center = h.center
        h.begin()
        await waitUntil { center.reads[0] == 1 }
        let cancelled = Task { await h.expirePrivateNotices(removeDelivered:true) }
        await waitUntil { h.request == nil }
        precondition(h.worker?.task.isCancelled == false && center.pending == nil)
        center.settingsCallback?(UNNotificationSettings())
        await waitUntil { center.pending != nil }
        cancelled.cancel()
        let first = await cancelled.value
        precondition(!first && h.worker == nil && h.request == nil)
        precondition(h.cards.map(\.isPrivate) == [false] && h.notificationCards.keys.sorted() == [1])
        precondition(center.removed.isEmpty && center.removedDelivered.isEmpty)
        center.pending?(center.all.map(UNNotificationRequest.init))

        center.respondToPending = true
        let pendingMissing = Harness()
        pendingMissing.center.respondToDelivered = true
        async let inverse = pendingMissing.expirePrivateNotices(removeDelivered:true)
        let second = await h.expirePrivateNotices(removeDelivered:true)
        precondition(!second && center.reads == [1,2,1] && center.delivered != nil)
        precondition(center.removed == ["fictional.private.1"] && center.removedDelivered.isEmpty)
        center.delivered?(center.all.map { UNNotification(request:.init(identifier:$0)) })
        let pendingWasKnown = await inverse
        precondition(!pendingWasKnown && pendingMissing.center.reads == [0,1,1])
        precondition(pendingMissing.center.removed.isEmpty && pendingMissing.center.removedDelivered == ["fictional.private.1"])

        center.respondToDelivered = true
        let complete = await h.expirePrivateNotices(removeDelivered:true)
        precondition(complete && center.reads == [1,3,2])
        precondition(center.removed == ["fictional.private.1", "fictional.private.1"])
        precondition(center.removedDelivered == ["fictional.private.1"])
        let suspended = await h.expirePrivateNotices(removeDelivered:false)
        precondition(suspended && center.reads == [1,4,2])
        precondition(center.removedDelivered == ["fictional.private.1"])
    }
}
'''.replace("BRIDGES", bridges).replace("EXPIRY", block(model, "func expirePrivateNotices(")) + "\n@MainActor\n" + block(
            notifications, "final class NotificationWork {")
        self.run_probe(compiler, program)

    def test_retention_does_not_wait_indefinitely_or_clean_up_before_a_notification_write_finishes(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the notification worker's cancellation and expiry")
        notifications = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        countdown = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        program = r'''import Foundation
struct Request { let identifier: String; var request: Self { self } }
struct Card { let isPrivate: Bool }
enum CountdownNotice { static let privatePrefix = "fictional.private." }
@MainActor final class Center {
    var commit: CheckedContinuation<Void, Never>?
    var saved = ["fictional.personal", "fictional.school", "unrelated"]
    var pendingReads = 0
    var removedPending = [String](), removedDelivered = [String]()
    func write(_ identifier: String) async {
        await withCheckedContinuation { commit = $0 }
        saved.append(identifier)
    }
    func finishWrite() { let continuation = commit; commit = nil; continuation?.resume() }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removedPending += ids
        saved.removeAll { ids.contains($0) }
    }
    func removeDeliveredNotifications(withIdentifiers ids: [String]) { removedDelivered += ids }
}
@MainActor final class ScheduleNotifications {
    static let updateIdentifiers = ["fictional.changes", "fictional.exam", "fictional.examReturn"]
    let center = Center()
    var generation = UUID()
    var pending: Int? = 1, baseline: Int? = 1
    var loaded = true
    var reconcileTask: NotificationWork?
    func start() {
        reconcileTask = NotificationWork {
            await self.center.write("fictional.exam")
            self.reconcileTask = nil
        }
    }
    static func readPending(from center: Center) async -> [Request]? {
        center.pendingReads += 1
        return center.saved.map(Request.init)
    }
    static func readDelivered(from center: Center) async -> [Request]? { center.saved.map(Request.init) }
STOP_UPDATES
RESET_UPDATES
}
@MainActor final class Countdown {
    let center = Center()
    var cards = [Card(isPrivate:true),Card(isPrivate:false)]
    var notificationCards = [0:Card(isPrivate:true),1:Card(isPrivate:false)]
    var revision = UUID(), request: Int? = 1
    var worker: NotificationWork?
    func start(_ identifier: String) {
        worker = NotificationWork {
            await self.center.write(identifier)
            self.worker = nil
        }
    }
EXPIRE
}
@main struct Probe {
    @MainActor static func main() async {
        let countdown = Countdown(), publicCountdown = Countdown(), updates = ScheduleNotifications()
        countdown.start("fictional.private.countdown")
        publicCountdown.start("fictional.new.public.countdown")
        updates.start()
        while countdown.center.commit == nil || publicCountdown.center.commit == nil || updates.center.commit == nil {
            await Task.yield()
        }
        async let privateExpiry = countdown.expirePrivateNotices(removeDelivered:true)
        async let publicExpiry = publicCountdown.expirePrivateNotices(removeDelivered:true)
        async let updateExpiry = updates.resetForRetention()
        let (removedPrivate, removedPublic, removedUpdates) = await (privateExpiry, publicExpiry, updateExpiry)
        precondition(!removedPrivate && !removedPublic && !removedUpdates, "an unknown write must leave the period blocked")
        precondition(countdown.worker?.task.isCancelled == false && publicCountdown.worker?.task.isCancelled == false)
        precondition(updates.reconcileTask?.task.isCancelled == true)
        precondition(countdown.center.pendingReads == 0 && updates.loaded && updates.baseline == 1)
        precondition(countdown.request == nil && updates.pending == nil && countdown.cards.map(\.isPrivate) == [false])
        precondition(countdown.center.removedPending.isEmpty && updates.center.removedPending.isEmpty)

        let retry = Task { await countdown.expirePrivateNotices(removeDelivered:true) }
        retry.cancel()
        let cancelled = await retry.value
        precondition(!cancelled && countdown.worker != nil)

        let oldCountdown = countdown.worker, oldPublicCountdown = publicCountdown.worker, oldUpdates = updates.reconcileTask
        countdown.center.finishWrite(); publicCountdown.center.finishWrite(); updates.center.finishWrite()
        await oldCountdown?.value; await oldPublicCountdown?.value; await oldUpdates?.value
        precondition(countdown.center.saved.contains("fictional.private.countdown"))
        precondition(updates.center.saved.contains("fictional.exam"))
        let retriedPrivate = await countdown.expirePrivateNotices(removeDelivered:true)
        let retriedPublic = await publicCountdown.expirePrivateNotices(removeDelivered:true)
        let retriedUpdates = await updates.resetForRetention()
        precondition(retriedPrivate && retriedPublic && retriedUpdates)
        precondition(countdown.center.removedPending == ["fictional.private.countdown"])
        precondition(updates.center.removedPending == ScheduleNotifications.updateIdentifiers)
        precondition(!updates.loaded && updates.baseline == nil)
        precondition(countdown.center.saved == ["fictional.personal", "fictional.school", "unrelated"])
        precondition(publicCountdown.center.saved == countdown.center.saved + ["fictional.new.public.countdown"])
        precondition(publicCountdown.center.removedPending.isEmpty && publicCountdown.center.removedDelivered.isEmpty)
        precondition(updates.center.saved == countdown.center.saved)
        print("Verified notification-write timeout, ownership retention, cancellation, and late completion cleanup.")
    }
}
'''.replace("STOP_UPDATES", block(notifications, "func suspendForUnavailableData("))
        program = program.replace("RESET_UPDATES", block(notifications, "func resetForRetention("))
        program = program.replace("EXPIRE", block(countdown, "func expirePrivateNotices("))
        program += "\n@MainActor\n" + block(notifications, "final class NotificationWork {")
        self.run_probe(compiler, program)

    def test_background_refresh_waits_for_countdown_and_cancels_its_owned_plan(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the background and countdown worker")
        app = (ROOT / "Takupoke/ApplicationData.swift").read_text(encoding="utf-8")
        model = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        schedule = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        background = app[app.index("    func refreshInBackground() async {"):
                         app.index("    private func checkRevisionsInBackground()")]
        workers = model[model.index("    func waitForNotificationReconciliation()"):
                        model.index("    private func reconcile(_ plan:")]
        marker = "    private func cancelNotificationReconciliation(_ token: UUID) {\n"
        self.assertEqual(workers.count(marker), 1)
        workers = workers.replace(marker, marker + "        cancellations.append(token)\n")
        wait_operation = "            let finished = await withTaskCancellationHandler {\n"
        self.assertEqual(workers.count(wait_operation), 1)
        workers = workers.replace(wait_operation, "            waitEntries += 1\n" + wait_operation)
        program = r'''import Foundation
@MainActor final class UIApplication {
    enum State { case active, background }
    static let shared = UIApplication()
    var applicationState = State.background
    let isProtectedDataAvailable = true
}
@MainActor final class Material {
    let state = 0, records = 0, sources = 0, ready = true
    let busy = false
    func setSourceChecksActive(_ active: Bool) {}
    func loadIfNeeded() {}
    func refreshAtStartup() {}
    func checkAtStartup() {}
    func refresh() async {}
    func check() async {}
    func refreshInBackground() async -> Bool { true }
}
@MainActor final class ScheduleNotices {
    private(set) var finished = false
    var pausesWrite = false
    var pending: Int? = nil
    var reconcileTask: NotificationWork?
    var waiting: CheckedContinuation<Void, Never>?
    func reconcile(state: Int, records: Int, sources: Int, period: Int,
                   materialsReady: Bool, specialsReady: Bool) async {
        pending = 1
        await drainPending()
        finished = true
    }
    private func apply(_ input: Int) async {
        if pausesWrite { await withCheckedContinuation { waiting = $0 } }
    }
    func release() {
        let callback = waiting; waiting = nil
        callback?.resume()
    }
    private func finishDeferredNotificationRemovals() {}
UPDATE_DRAIN
}
@MainActor final class Countdown {
    struct NoticePlan { let revision: UUID }
    var request: NoticePlan?, worker: NotificationWork?
    var revision = UUID()
    var waiting: CheckedContinuation<Void, Never>?
    var applied: [UUID] = []
    var cancellations: [UUID] = []
    var waitEntries = 0

    func enqueue() {
        revision = UUID()
        request = NoticePlan(revision: revision)
        startNotificationWorker()
    }
    private func reconcile(_ plan: NoticePlan) async {
        await withCheckedContinuation { waiting = $0 }
        guard !Task.isCancelled, revision == plan.revision else { return }
        applied.append(plan.revision)
    }
    func release() {
        let callback = waiting!
        waiting = nil
        callback.resume()
    }
WORKERS
}
@MainActor final class App {
    let materials = Material(), specialSchedules = Material(), schoolEvents = Material()
    let mappings = Material(), times = Material(), links = Material(), account = Material()
    let notifications = ScheduleNotices(), countdown = Countdown()
    var loadedPeriod: Int? = 1
    var backgroundRefresh: Task<Void, Never>?
    var finished = false
    var ready = true, readyForCurrentPeriod = true
    var prepareCalls = 0

    func prepare() async -> Bool { prepareCalls += 1; return true }
    func setFileMonitoring(_ enabled: Bool) { precondition(enabled == (UIApplication.shared.applicationState == .active)) }
    func checkRevisionsInBackground() async {}
    func checkNotificationsWhenActive() {}
    func updateCountdown() { if UIApplication.shared.applicationState == .background { countdown.enqueue() } }
BACKGROUND
ACTIVATION
    func start() -> Task<Void, Never> {
        Task { await refreshInBackground(); finished = true }
    }
}
@main struct Probe {
    @MainActor static func observe(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition() { precondition(ContinuousClock.now < deadline); await Task.yield() }
    }
    @MainActor static func main() async {
        for cancel in [false, true] {
            let app = App()
            let task = app.start()
            await observe { app.countdown.waiting != nil && app.notifications.finished }
            precondition(!app.finished && app.backgroundRefresh != nil)
            let token = app.countdown.revision
            if cancel {
                task.cancel()
                await observe { app.countdown.worker?.task.isCancelled == true }
            }
            app.countdown.release()
            await task.value
            precondition(app.finished && app.backgroundRefresh == nil)
            precondition(app.countdown.applied == (cancel ? [] : [token]))
        }
        let app = App()
        let task = app.start()
        await observe { app.countdown.waiting != nil && app.notifications.finished }
        app.countdown.enqueue()
        let newest = app.countdown.revision
        task.cancel()
        app.countdown.release()
        await observe { app.countdown.waiting != nil }
        app.countdown.release()
        await task.value
        await observe { app.countdown.applied == [newest] }
        precondition(app.countdown.applied == [newest])

        // Join after the previous operation was cancelled but before its OS
        // callback returns. Its epilogue starts the newer task.
        for newerPlanAfterJoining in [false, true] {
            let countdown = Countdown()
            countdown.enqueue()
            await observe { countdown.waiting != nil }
            countdown.worker!.cancel()
            countdown.enqueue()
            let original = countdown.revision
            var beganWaiting = false
            var endedWaiting = false
            let join = Task {
                beganWaiting = true
                await countdown.waitForNotificationReconciliation()
                endedWaiting = true
            }
            await observe { beganWaiting }
            if newerPlanAfterJoining { countdown.enqueue() }
            let restarted = countdown.revision
            countdown.release()
            await observe { countdown.waiting != nil && countdown.waitEntries == 2 }
            precondition(!endedWaiting)
            if newerPlanAfterJoining {
                join.cancel()
                await observe { !countdown.cancellations.isEmpty }
                precondition(countdown.cancellations == [original] && countdown.worker?.task.isCancelled == false)
            }
            countdown.release()
            await join.value
            await observe { countdown.applied == [restarted] }
            precondition(endedWaiting && countdown.applied == [restarted])
        }
        let overlap = App()
        overlap.notifications.pausesWrite = true
        let background = overlap.start()
        await observe { overlap.countdown.waiting != nil && overlap.notifications.waiting != nil }
        precondition(!overlap.finished && overlap.prepareCalls == 1)
        let countdownWorker = overlap.countdown.worker, updateWorker = overlap.notifications.reconcileTask
        UIApplication.shared.applicationState = .active
        let foreground = Task { await overlap.activate() }
        await observe {
            overlap.prepareCalls == 2 && countdownWorker?.task.isCancelled == true && updateWorker?.task.isCancelled == true
        }
        precondition(overlap.countdown.waiting != nil && overlap.notifications.waiting != nil)
        precondition(overlap.countdown.worker === countdownWorker && overlap.notifications.reconcileTask === updateWorker)
        await foreground.value
        await background.value
        precondition(overlap.finished && overlap.backgroundRefresh == nil && overlap.countdown.applied.isEmpty)
        overlap.countdown.release(); overlap.notifications.release()
        await countdownWorker?.value; await updateWorker?.value
        precondition(overlap.countdown.worker == nil && overlap.notifications.reconcileTask == nil)
        print("Verified exact background and foreground methods, both native worker owners and cancellation handlers.")
    }
}
'''.replace("WORKERS", workers).replace("BACKGROUND", background)
        program = program.replace("ACTIVATION", block(app, "func activate() async"))
        program = program.replace("UPDATE_DRAIN", block(schedule, "private func drainPending()"))
        program += "\n@MainActor\n" + block(schedule, "final class NotificationWork {")
        self.run_probe(compiler, program)
        self.run_probe(compiler, program, swift_version="6")

    def run_probe(self, compiler, program, swift_version="5"):
        with tempfile.TemporaryDirectory(prefix="notification-settings-lifecycle-") as scratch:
            directory = Path(scratch)
            swift = directory / "Probe.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", swift_version, "-parse-as-library",
                            "-module-cache-path", str(directory / "modules"), str(swift),
                            "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)
