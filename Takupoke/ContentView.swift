import SwiftUI

struct ContentView: View {
    @StateObject private var materials = MaterialsModel()
    @StateObject private var specialSchedules = SpecialSchedulesModel()
    @StateObject private var schoolEvents = SchoolEventsModel()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            TimetableView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents)
                .tabItem { Label("時間割", systemImage: "calendar") }
            SettingsView(materials: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents)
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .onChange(of: materials.ready) { ready in
            if ready { materials.checkSelectedFilesAtStartup() }
        }
        .onChange(of: specialSchedules.ready) { ready in
            if ready { specialSchedules.checkSelectedFilesAtStartup() }
        }
        .task {
            materials.loadIfNeeded()
            specialSchedules.loadIfNeeded()
            schoolEvents.refreshAtStartup()
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var materials: MaterialsModel
    @ObservedObject var specialSchedules: SpecialSchedulesModel
    @ObservedObject var schoolEvents: SchoolEventsModel

    var body: some View {
        NavigationStack {
            List {
                Section("データ取得") {
                    NavigationLink {
                        MaterialsView(model: materials, specialSchedules: specialSchedules, schoolEvents: schoolEvents)
                    } label: {
                        Label("ファイル選択", systemImage: "folder")
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

private struct HomeView: View {
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
