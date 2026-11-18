import SwiftUI

@main
struct TakupokeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.timeZone, JapaneseDateDisplay.timeZone)
                .modifier(MainColorScope())
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await ApplicationData.shared.refreshInBackground()
        }
    }
}
