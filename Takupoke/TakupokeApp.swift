import SwiftUI

@main
struct TakupokeApp: App {
    @MainActor init() {
        // Install the notification delegate before SwiftUI builds the root view,
        // including a cold launch started by tapping a pending notice.
        _ = ApplicationData.shared.notifications
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.timeZone, JapaneseDateDisplay.timeZone)
                .modifier(MainColorScope())
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.schedule()
            await ApplicationData.shared.refreshInBackground()
        }
    }
}
