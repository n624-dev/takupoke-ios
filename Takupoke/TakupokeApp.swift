import SwiftUI

@main
struct TakupokeApp: App {
    @AppStorage(MainColor.storageKey) private var mainColor = MainColor.systemDefault.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.timeZone, JapaneseDateDisplay.timeZone)
                .tint((MainColor(rawValue: mainColor) ?? .systemDefault).color)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await ApplicationData.shared.refreshInBackground()
        }
    }
}
