import SwiftUI

struct ContentView: View {
    @AppStorage("updateVerificationNote") private var verificationNote = ""
    @StateObject private var materials = MaterialsModel()

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
                        Text("学校資料を、いつもの「ファイル」から。\n時間割づくりの準備を始めましょう。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                }

                Section {
                    NavigationLink {
                        MaterialsView(model: materials)
                    } label: {
                        Label("学校資料を選ぶ", systemImage: "folder")
                    }
                } footer: {
                    Text("通常時間割PDFと時間割変更XLSXは「ファイル」から、学校行事PDFは学校サイトから取得して端末内に保存します。内容の解析は今後追加します。")
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
                    Text("アプリの更新はAltStore Classicから行います。")
                }
            }
            .navigationTitle("たくポケ")
            .tint(accent)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
