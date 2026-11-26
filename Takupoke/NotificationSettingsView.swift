import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @EnvironmentObject private var notifications: ScheduleNotifications
    @Environment(\.openURL) private var openURL

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
            if let message = notifications.message {
                Section {
                    Text(message).foregroundStyle(.orange)
                    Button("iPhoneの設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
        }
        .navigationTitle("通知")
        .task { await notifications.checkPermission() }
    }
}
