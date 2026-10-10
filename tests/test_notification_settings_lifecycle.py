"""Execute the actual OS callback bridge with controlled native boundary responses.

The stubs verify concurrency and value transport, not Apple availability or UI.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NotificationSettingsLifecycleTests(unittest.TestCase):
    def test_authorization_bridge_requires_one_real_callback_and_preserves_denial_and_errors(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production authorization bridge")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        start = source.index("    private static func requestAuthorization(")
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

    def test_actual_bridge_preserves_os_objects_for_immediate_delayed_and_cancelled_reads(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production callback bridge")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        start = source.index("    nonisolated private static func notificationSettings(")
        end = source.index("    func resetForRetention()", start)
        bridge = source[start:end]
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
    nonisolated static func read(_ center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await notificationSettings(from: center)
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
            precondition(result === original && result.authorizationStatus == status)
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
        center.complete(0, earlier)
        let firstResult = await first.value
        precondition(firstResult === earlier && first.isCancelled && center.count == 2)
        print("Verified actual bridge: exact OS objects, one read per call, concurrent and cancelled completion.")
    }
}
'''.replace("BRIDGE", bridge)
        self.run_probe(compiler, program)

    def test_disabled_delivery_never_reads_os_settings_and_enabled_delivery_requires_real_status(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the production delivery gate")
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        bridge_start = source.index("    nonisolated private static func notificationSettings(")
        bridge_end = source.index("    func resetForRetention()", bridge_start)
        permission_start = source.index("    func checkPermission() async {")
        permission_end = source.index("    // Keep the actual OS response", permission_start)
        gate_start = source.index("    private func deliveryAllowed() async -> Bool {")
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
    private var reads = 0
    init(_ response: UNNotificationSettings?) { self.response = response }
    var count: Int { lock.lock(); defer { lock.unlock() }; return reads }
    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {
        lock.lock(); reads += 1; lock.unlock()
        // nil models an OS service that never responds. The disabled branch
        // must complete without touching it, not wait for a synthesized reply.
        if let response { completionHandler(response) }
    }
}
@MainActor final class Harness {
    let changesEnabled: Bool
    let specialsEnabled: Bool
    let center: UNUserNotificationCenter
    var message: String?
    init(_ changes: Bool, _ specials: Bool, _ center: UNUserNotificationCenter) {
        changesEnabled = changes; specialsEnabled = specials; self.center = center
    }
BRIDGE
GATE
PERMISSION
    func evaluate() async -> Bool { await deliveryAllowed() }
}
@main struct Probe {
    @MainActor static func main() async {
        let unavailable = UNUserNotificationCenter(nil)
        let disabled = Harness(false, false, unavailable)
        let disabledResult = await disabled.evaluate()
        precondition(!disabledResult && unavailable.count == 0)
        disabled.message = "iPhoneの設定で通知を許可してください。"
        await disabled.checkPermission()
        precondition(disabled.message == nil && unavailable.count == 0)
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
                    harness.message = previous
                    await harness.checkPermission()
                    let expected = enabled && status == .denied
                        ? "iPhoneの設定で通知を許可してください。"
                        : (previous == "iPhoneの設定で通知を許可してください。" ? nil : previous)
                    precondition(harness.message == expected)
                }
                precondition(center.count == (enabled ? 4 : 0))
            }
        }
        print("Verified production gate: disabled uses no OS request; enabled requires actual allowed status.")
    }
}
'''.replace("BRIDGE", source[bridge_start:bridge_end]).replace("GATE", source[gate_start:gate_end]).replace(
    "PERMISSION", source[permission_start:permission_end])
        self.run_probe(compiler, program)

    def run_probe(self, compiler, program):
        with tempfile.TemporaryDirectory(prefix="notification-settings-lifecycle-") as scratch:
            directory = Path(scratch)
            swift = directory / "Probe.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(directory / "modules"), str(swift),
                            "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)
