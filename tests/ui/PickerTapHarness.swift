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
                        if ProcessInfo.processInfo.arguments.contains("--unpaired-appearance") {
                            let root = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                                .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
                            func anchors(_ controller: UIViewController) -> [MaterialPickerAnchor] {
                                (controller as? MaterialPickerAnchor).map { [$0] } ?? controller.children.flatMap(anchors)
                            }
                            if let root, let anchor = anchors(root).first {
                                MaterialPickerTestTrace.record?("FAULT unpaired appearance return")
                                anchor.viewDidDisappear(false)
                            }
                        }
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
                .allowsHitTesting(false)
        }
    }
}
