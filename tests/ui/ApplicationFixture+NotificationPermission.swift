import SwiftUI
import UIKit

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

    func completeWithoutRead(_ identifier: UUID, cancelled: Bool) {
        guard request == identifier, !cancelled else {
            FixtureLaunchDiagnostics.record("notification-settings-cancelled")
            return
        }
        authorization = "notRequested"
        FixtureLaunchDiagnostics.record("notification-settings-not-requested")
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
            + ";specials=\(notifications.specialsEnabled)"
            + ";savedSpecials=\(UserDefaults.standard.bool(forKey: "notifySpecialSchedules"))"
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
