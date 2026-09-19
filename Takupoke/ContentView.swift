import SwiftUI

struct ContentView: View {
    @AppStorage("updateVerificationNote") private var verificationNote = ""

    private let accent = Color(red: 0.08, green: 0.43, blue: 0.40)
    private let sourceURL = URL(string: "https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json")!

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
                        Text("たくぽけの開発版へようこそ。\nまずは、インストールと更新の準備から。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                }

                Section("このアプリについて") {
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
                    ShareLink(item: sourceURL) {
                        Label("AltStore SourceのURLを共有", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("アプリの更新はAltStore Classicから行います。学校資料の取り込みと時間割の表示は、今後の開発で追加します。")
                }
            }
            .navigationTitle("たくぽけ")
            .tint(accent)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
