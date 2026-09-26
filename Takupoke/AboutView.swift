import SwiftUI

struct AboutView: View {
    @State private var safariPage: SafariPage?
    private let sourceURL = URL(string: "https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json")!

    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "ライセンス情報を読み取れません。" }
        return text
    }

    private func bundleValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                Text("香川高専詫間キャンパスの学生向けに個人が開発・運営する非公式アプリです。")
                LabeledContent("バージョン", value: bundleValue("CFBundleShortVersionString"))
                LabeledContent("ビルド", value: bundleValue("CFBundleVersion"))
            }
            Section {
                NavigationLink("利用規約") { LegalDocumentView(document: .terms) }
                NavigationLink("プライバシーポリシー") { LegalDocumentView(document: .privacy) }
                Button("たくにんの利用規約") {
                    safariPage = SafariPage(url: URL(string: "https://takuma-gakunin.n624.jp/terms")!)
                }
                Button("たくにんのプライバシーポリシー") {
                    safariPage = SafariPage(url: URL(string: "https://takuma-gakunin.n624.jp/privacy")!)
                }
                NavigationLink("オープンソースライセンス") {
                    ScrollView {
                        Text(licenseText).font(.footnote).textSelection(.enabled).padding()
                    }.navigationTitle("オープンソースライセンス")
                }
            }
            Section {
                Link("ソースコード", destination: URL(string: "https://github.com/n624-dev/takupoke-ios")!)
                Link("問い合わせ", destination: URL(string: "mailto:takupoke@n624.jp")!)
                ShareLink(item: sourceURL) {
                    Label("AltStore SourceのURLを共有", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("このアプリについて")
        .sheet(item: $safariPage) { page in
            SafariLinkView(url: page.url) { safariPage = nil }.ignoresSafeArea()
        }
    }
}
