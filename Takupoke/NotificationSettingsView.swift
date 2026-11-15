import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @EnvironmentObject private var notifications: ScheduleNotifications
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase

    var body: some View {
        List {
            Section {
                Toggle("時間割変更", isOn: Binding(get: { notifications.changesEnabled }, set: { value in
                    Task { await notifications.setEnabled(changes: true, value: value) }
                }))
                Toggle("試験・返却", isOn: Binding(get: { notifications.specialsEnabled }, set: { value in
                    Task { await notifications.setEnabled(changes: false, value: value) }
                }))
            }
            .disabled(notifications.requestingPermission)
            if let message = notifications.permissionMessage {
                Section {
                    InlineWarning(message)
                    Button("iPhoneの設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            if let message = notifications.message {
                Section { InlineWarning(message) }
            }
        }
        .navigationTitle("通知")
        .task { await notifications.checkPermission() }
        .onChange(of: phase) { _, phase in
            if phase == .active { Task { await notifications.checkPermission() } }
        }
    }
}
