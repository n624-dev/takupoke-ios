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
        with tempfile.TemporaryDirectory(prefix="notification-settings-lifecycle-") as scratch:
            directory = Path(scratch)
            swift = directory / "Probe.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(directory / "modules"), str(swift),
                            "-o", str(directory / "probe")], check=True, timeout=60)
            subprocess.run([str(directory / "probe")], check=True, timeout=15)
