import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("たくポケ")
        }
    }
}
