import SwiftUI

struct HomeView: View {
    @AppStorage("updateVerificationNote") private var verificationNote = ""

    private let accent = Color(red: 0.08, green: 0.43, blue: 0.40)
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
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(accent)
                            .accessibilityHidden(true)
                        Text("学校の予定を、\nひとつの場所に。")
                            .font(.title.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("学校資料を、いつもの「ファイル」から。\n時間割づくりの準備を始めましょう。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                }

                Section("このアプリについて") {
                    Text("たくポケは個人が開発・運営する非公式アプリです。香川高等専門学校および国立高等専門学校機構が運営・承認・推奨・保証するものではありません。表示内容には遅延や誤りが生じる場合があります。重要な予定・変更は学校の公式案内も確認してください。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("利用規約", destination: URL(string: "https://takupoke.n624.jp/terms")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://takupoke.n624.jp/privacy")!)
                    Link("ソースコード", destination: URL(string: "https://github.com/n624-dev/takupoke-ios")!)
                    Link("問い合わせ", destination: URL(string: "mailto:takupoke@n624.jp")!)
                    LabeledContent("バージョン", value: bundleValue("CFBundleShortVersionString"))
                    LabeledContent("ビルド", value: bundleValue("CFBundleVersion"))
                    LabeledContent("コミット", value: String(bundleValue("TakupokeCommit").prefix(7)))
                }

                Section {
                    TextField("更新後に残す確認メモ", text: $verificationNote, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("更新確認用のメモ")
                } header: {
                    Text("更新を確かめる")
                } footer: {
                    Text("短いメモを入力し、AltStoreから更新した後も残っているか確認できます。メモは端末内にのみ保存されます。")
                }

                Section {
                    NavigationLink("オープンソースライセンス") {
                        ScrollView {
                            Text(licenseText).font(.footnote).textSelection(.enabled).padding()
                        }.navigationTitle("ライセンス")
                    }
                    ShareLink(item: sourceURL) {
                        Label("AltStore SourceのURLを共有", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("アプリの更新はAltStore Classicから行います。")
                }
            }
            .navigationTitle("たくポケ")
            .tint(accent)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
