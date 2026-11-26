import SwiftUI

enum UsageHelpTopic: String, CaseIterable, Identifiable {
    case gettingStarted, timetable, links, updates, troubleshooting
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gettingStarted: return "はじめに"
        case .timetable: return "時間割を見る"
        case .links: return "リンクを使う"
        case .updates: return "更新と通知"
        case .troubleshooting: return "困ったとき"
        }
    }
    var icon: String {
        switch self {
        case .gettingStarted: return "list.number"
        case .timetable: return "calendar"
        case .links: return "link"
        case .updates: return "bell"
        case .troubleshooting: return "questionmark.circle"
        }
    }
}

struct UsageHelpView: View {
    var body: some View {
        List(UsageHelpTopic.allCases) { topic in
            NavigationLink { UsageHelpTopicView(topic: topic) } label: {
                Label(topic.title, systemImage: topic.icon)
            }
        }
        .navigationTitle("使い方")
    }
}

struct UsageHelpTopicView: View {
    let topic: UsageHelpTopic

    var body: some View {
        List {
            switch topic {
            case .gettingStarted: gettingStarted
            case .timetable: timetable
            case .links: links
            case .updates: updates
            case .troubleshooting: troubleshooting
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var gettingStarted: some View {
        Group {
            Section("1. OneDriveを準備する") {
                Text("対象ファイルの「⋯」から「オフラインで使用可能にする」を選びます。ダウンロードが完了するまで待ってください。")
                Text("iPhoneの「設定」→「一般」→「Appのバックグラウンド更新」でOneDriveを有効にします。低電力モードではバックグラウンド更新が停止します。")
            }
            Section("2. データを取得する") {
                Text("たくポケの「設定」→「リンク・名称・授業時刻」を開き、「学校アカウントで取得」を押します。")
                Text("名称データは、科目・教員・教室の略称を正式名称で表示するために使います。")
            }
            Section("3. 時間割ファイルを選ぶ") {
                Text("「設定」→「時間割ファイル」で通常時間割のPDFと時間割変更のExcelファイルを選びます。選択後、自動で解析します。")
                Text("試験時間割・試験返却時間割のPDFは、手元にある場合に選んでください。")
            }
            Section("4. 学校行事を取得する") {
                Text("「設定」→「学校行事」で年度を確認し、「学校行事を取得」を押します。年度が空欄なら現在の学校年度を使います。")
            }
            Section("5. クラスを選ぶ") {
                Text("「設定」→「クラス」で表示するクラスを選びます。時間割タブの「クラス」からも変更できます。")
                Text("1年生は追加クラスも選べます。留学生向けの授業を見る場合は「留学生向けの授業も表示」をオンにします。")
            }
        }
    }

    private var timetable: some View {
        Group {
            Section("今日の予定") {
                Text("ホームに今日の授業と行事を表示します。授業を押すと詳細を確認できます。")
                Text("「時間割を見る」を押すと、今日を含む週を開きます。終了した授業も表示されます。")
            }
            Section("週の時間割") {
                Text("「前週」「翌週」で週を移動します。週の日付を押すと、カレンダーから移動先を選べます。")
                Text("授業カードを押すと、科目・教員・教室・時刻を確認できます。連続する授業は1つのカードにまとめます。")
            }
            Section("時間割変更") {
                Text("「通常」「変更込み」で表示を切り替えます。ホームの今日の予定は変更込みです。")
                Text("週の時間割の下に変更一覧があります。「今日以降」「この週」「全件」で絞り込めます。")
            }
        }
    }

    private var links: some View {
        Group {
            Section("リンクを開く") {
                Text("一覧タブでリンクを押します。検索欄から名前を探せます。")
                Text("「設定」→「リンクの開き方」で、アプリ内かデフォルトのブラウザかを選びます。")
                Text("リンクを長押しすると、設定と逆の開き方も選べます。アプリ内で開けるのはHTTPSのリンクです。")
            }
            Section("お気に入り・色・非表示") {
                Text("リンクを長押しして「お気に入りに追加」「色を変更」「非表示」を選びます。お気に入りはホームにも表示されます。")
                Text("非表示にしたリンクは、一覧タブ右上の非表示アイコンから「再表示」で戻せます。")
            }
        }
    }

    private var updates: some View {
        Group {
            Section("ファイルと学校行事") {
                Text("選択済みファイルは、起動時・アプリへ戻ったとき・表示中に変更が届いたときに確認します。内容が変わると自動で解析します。")
                Text("取得済み年度の学校行事も自動で更新を確認します。")
            }
            Section("リンク・名称・授業時刻") {
                Text("更新があるとホームに案内が出ます。案内を押し、「更新を確認」から新しいデータを取得します。必要なときに学校アカウント認証が始まります。")
            }
            Section("通知") {
                Text("「設定」→「通知」で、種類ごとにオン・オフを切り替えます。")
                Text("時間割変更：今日以降の、選択中クラスに関係する変更を通知します。")
                Text("試験・返却：選択済みPDFが更新され、解析に成功すると通知します。")
                Text("初回の取り込みは通知せず、その後の変更を通知します。")
            }
            Section("バックグラウンドの確認") {
                Text("アプリを開いていない間も更新を確認します。実行時期はiOSが決めます。ロック中で保存データを読めない場合は、次の確認へ持ち越します。")
            }
            Section("4月・10月の切り替え") {
                Text("4月1日・10月1日の切替後、端末に保存した学校ファイル・解析結果・リンク一覧・名称データ・授業時刻を削除します。")
                Text("ファイルを選び直し、学校アカウントでデータを再取得してください。クラスやお気に入りなどの個人設定は引き継ぎます。")
            }
        }
    }

    private var troubleshooting: some View {
        Group {
            Section("ファイルが更新されない") {
                Text("1. OneDriveを開いて、対象ファイルの同期状況を確認します。")
                Text("2. iPhoneの「ファイル」で対象ファイルを開き、たくポケへ戻ります。")
                Text("3. 読み取れない場合は「設定」→「時間割ファイル」で選び直します。")
                Text("最新版が届く時期はOneDriveの同期状況によって異なります。")
            }
            Section("解析に失敗する") {
                Text("「時間割ファイル」の「詳細を見る」でエラーを確認します。ファイルを確認した後、「解析する」を押してください。")
                Text("失敗した場合も選択したファイルを保持し、前回の正常な結果があれば使い続けます。")
            }
            Section("時間割変更の日付がおかしい") {
                Text("「時間割ファイル」→「時間割変更」の「詳細を見る」で補完年度を確認します。年のない日付に使う学校年度です。")
                Text("空欄なら現在の学校年度を使います。2026年度の場合、1〜3月の日付は2027年として扱います。")
                Text("年度を変更したら「解析する」を押します。")
            }
            Section("ファイル選択が消えた") {
                Text("4月1日・10月1日の半期切替後は、ファイルの再選択が必要です。")
                Text("「設定」→「初期設定」から、データ取得・ファイル選択・クラス選択を順番に行えます。途中で「あとで設定」を押して終了できます。")
            }
        }
    }
}
