import SwiftUI
import UniformTypeIdentifiers

/// Synthetic file rows, with the same local State and destination closures as
/// MaterialsView. No school files or app databases are loaded.
struct PickerTapHarness: View {
    var body: some View {
        TabView {
            Text("架空ホーム").tabItem { Text("ホーム") }
            NavigationStack {
                List {
                    Section("データ取得") {
                        NavigationLink("ファイル選択") { PickerTapFileList() }
                    }
                }
                .navigationTitle("設定")
            }
            .tabItem { Text("設定") }
        }
    }
}

private struct PickerTapFileList: View {
    private struct Request: Identifiable {
        let id = UUID()
        let kind: Int
    }
    @State private var request: Request?

    var body: some View {
        List {
            ForEach(0..<4) { kind in
                Section("架空ファイル\(kind)") {
                    Text("解析済み")
                    NavigationLink("詳細を見る") { Text("架空の詳細") }
                        .accessibilityIdentifier("detail-\(kind)")
                    Button("ファイルを選び直す") {
                        MaterialPickerTestTrace.record?("BUTTON \(kind)")
                        request = Request(kind: kind)
                    }
                    .accessibilityIdentifier("choose-\(kind)")
                }
            }
        }
        .navigationTitle("ファイル選択")
        .background {
            MaterialDocumentPicker(item: $request, type: { _ in .pdf },
                instruction: { "架空ファイル\($0.kind)を選んでください" }, selected: { _, _ in })
        }
    }
}
