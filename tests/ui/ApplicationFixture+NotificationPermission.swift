import SwiftUI
import UIKit
import UserNotifications

// Observe only the real checkPermission response in the disposable app copy.
// Each read has its own identity; leaving the screen invalidates late responses.
@MainActor
final class FixtureNotificationAuthorization: ObservableObject {
    static let shared = FixtureNotificationAuthorization()
    @Published private(set) var authorization = "pending"
    private var request: UUID?

    func begin() -> UUID {
        let identifier = UUID()
        request = identifier
        authorization = "pending"
        FixtureLaunchDiagnostics.record("notification-settings-enter")
        return identifier
    }

    func complete(_ identifier: UUID, authorization: Int, cancelled: Bool) {
        guard request == identifier, !cancelled else {
            FixtureLaunchDiagnostics.record("notification-settings-cancelled")
            return
        }
        self.authorization = String(authorization)
        FixtureLaunchDiagnostics.record("notification-settings-complete")
        print("NOTIFICATION_READINESS authorization=\(authorization)"
            + ";application=\(UIApplication.shared.applicationState.rawValue)")
    }

    func invalidate() {
        request = nil
        authorization = "pending"
    }
}

// Isolated interaction target. This control cannot grant permission or save settings.
struct FixtureNotificationPermissionTouch: View {
    @Environment(\.scenePhase) private var phase
    @ObservedObject private var notifications = ApplicationData.shared.notifications
    @ObservedObject private var permission = FixtureNotificationAuthorization.shared
    @State private var dismissed = false
    private var permissionState: String {
        "requesting=\(notifications.requestingPermission)"
            + ";changes=\(notifications.changesEnabled)"
            + ";saved=\(UserDefaults.standard.bool(forKey: "notifyScheduleChanges"))"
            + ";message=\(notifications.message ?? "none")"
            + ";authorization=\(permission.authorization);scene=\(String(describing: phase))"
            + ";application=\(UIApplication.shared.applicationState.rawValue)"
    }

    var body: some View {
        VStack {
            if !dismissed {
                Button("許可画面を確認") {
                    if notifications.changesEnabled { dismissed = true }
                }.accessibilityIdentifier("fixture-notification-permission-touch")
            }
            Text(permissionState)
                .font(.system(size: 1)).allowsHitTesting(false)
                .accessibilityIdentifier("fixture-notification-permission-state")
        }
        .onDisappear { permission.invalidate() }
    }
}

// Diagnostic alternative to the imported async API. Returns the OS object;
// it never synthesizes authorization, retries, or changes notification choices.
enum FixtureNotificationSettings {
    nonisolated static func read(_ center: UNUserNotificationCenter,
                                permission: Bool) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            FixtureLaunchDiagnostics.record(permission
                ? "notification-settings-request" : "notification-reconcile-request")
            center.getNotificationSettings { settings in
                FixtureLaunchDiagnostics.record(permission
                    ? "notification-settings-callback" : "notification-reconcile-callback")
                continuation.resume(returning: settings)
            }
        }
    }
}
