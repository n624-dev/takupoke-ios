import SwiftUI

@main
struct TakupokeApp: App {
    @AppStorage("mainColor") private var mainColor = MainColor.blue.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint((MainColor(rawValue: mainColor) ?? .blue).color)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await ApplicationData.shared.refreshInBackground()
        }
    }
}
