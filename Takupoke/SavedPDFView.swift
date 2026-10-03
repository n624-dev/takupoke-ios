import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct SavedPDFView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            LocalPDFCanvas(url: url)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
private struct LocalPDFCanvas: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        guard context.coordinator.loadedURL != url.standardizedFileURL else { return }
        // Originals use a new local URL on replacement. Clear the old document even
        // when opening the replacement fails, so it cannot look like the new PDF.
        view.document = PDFDocument(url: url)
        context.coordinator.loadedURL = url.standardizedFileURL
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var loadedURL: URL? }
}
