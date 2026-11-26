import SwiftUI

/// Keep the indicator and its label centered independently of the cancel button.
struct LoadingRow: View {
    let title: String
    var cancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                Text(title)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            if let cancel { Button("中止", action: cancel) }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}
