# たくポケ iOS / takupoke-ios

学校の通常時間割・学校行事・時間割変更を、iPhone 内でひとつにまとめる Swift / SwiftUI 製アプリです。

通常時間割・時間割変更は iOS 標準の「ファイル」から OneDrive File Provider 経由で取得し、学校行事は `takupoke-api` から手動で取得します。Microsoft Graph は使いません。

**資料取得・XLSX/PDF解析に加え、SwiftUI の時間割タブを実装した開発版です。保存済みの通常時間割・APIの学校行事・時間割変更を週表示に反映し、試験・返却PDFも端末内で解析します。変更詳細には置き換え前の授業も残します。採用版の保存、通知、週画像の共有は未実装です。既存版の時間割タブは利用者から表示成功の報告を受けました。今回の行事APIと画面調整は実機確認待ちです。**

通常時間割・変更資料の情報と解析結果は端末内SQLiteに保存します。学校行事APIの結果は年度ごとに端末内へ保存します。旧行事PDFの解析結果は時間割表示に使用しません。新DBに保存した資料と解析結果は次回起動でも読み込みます。採用版を保存する統合処理は未実装です。実装範囲と確認待ちの条件は[SQLite設計](docs/local-database-design.md)に記載しています。

新規のPDF結果確認画面は標準ナビゲーションとLiquid Glassの解析ボタンを使います。ActionsをXcode 26.3へ更新し、iOS 26以降でLiquid Glass、それより古いOSで従来の標準部品を使う構成です。既存画面の全面的な置き換えは後の作業です。

[導入・更新手順](docs/distribution.md) · [開発環境](docs/development.md) · [ロードマップ](docs/roadmap.md) · [Releases](https://github.com/n624-dev/takupoke-ios/releases)

## 現在できること

- iOS「ファイル」から通常時間割PDF・時間割変更XLSXを個別に選択して端末内に保存。対応サービスではフォルダ選択も利用可能。
- 学校行事は年度を指定して公開APIから手動取得し、タグと期間を確認。取得失敗時は保存済みのAPI結果を保持。
- 資料の参照先とハッシュを保存し、起動時に選択済みのPDF・XLSXを読み直して変更時のみ自動解析。読み取れない場合は前回の正常結果を保持し、エラーを表示。
- 時間割変更XLSXは選択後に自動解析し、日付・クラス・変更前後科目・教員・教室・備考を確認。年なし日付には設定した学校年度、未設定なら操作日の学校年度を使い、1〜3月は翌年へ変換。解析失敗時は選択資料と前回正常な結果を保持。
- 通常時間割PDFは取得後に自動解析し、クラス・曜日での絞り込みと授業詳細を確認。APIの行事・休業期間を週表示に反映。
- 時間割タブでクラス設定（1年生はホームルームと学科の組み合わせ）、前週／翌週、日付からの週選択、通常／変更込み、週の授業グリッド、授業詳細、変更一覧の「今日以降／この週／全件」を利用。試験・返却PDFの個別選択と解析にも対応。取得操作は設定タブの「ファイル選択」に集約。適用期間と未対応部分は[時間割タブの表示仕様](docs/timetable-tab.md)を参照。
- 試験・返却の授業詳細は科目・教員・教室をラベル付きで表示。クラスや表示設定は更新後も保持し、資料に候補がない間も保存した選択を削除しない。
- PDFの記載名を保持し、元PDFもアプリ内で確認。正式名称の対応表は、別途構築するOIDC認証付き配信との接続後に利用予定。
- `1_AI` / `AI_1`、`2_AI` / `AI_2` のクラス表記をそれぞれ `AI_1`、`AI_2` に統一し、まとめて絞り込み。
- 曜日数式の結果が日付と合わない場合などは警告を表示。確認操作後に閲覧用プレビューを開き、前回の正常データを保持。
- SwiftUI のホーム画面でバージョン・ビルド・コミットを表示。
- 端末内に確認メモを保存し、アプリ更新後のデータ保持を検証。
- `main` への push から、Actions で iPhone 向け IPA と AltStore Source JSON を生成・公開するワークフロー。
- 配布前に IPA と Source の情報・アップロード内容を照合し、失敗した公開準備が前回の配布を置き換えない構成。

| 対象 | 状態 |
| --- | --- |
| 最小アプリ・Xcode プロジェクト | CI ビルド成功。利用者から実機起動の成功報告あり |
| Actions・IPA・Source 自動生成／公開処理 | 公開処理を修正し、利用者から Actions 成功の報告あり |
| 配布メタデータ・公開失敗時の処理 | 架空データによるローカルテストを実施 |
| Source からの初回導入・更新 | 初回導入・起動・更新後のメモ保持を利用者報告で確認 |
| File Provider からの資料取得 | 修正版のPDF・XLSX取得、再起動後の保持・同じ資料の再取得に成功した利用者報告あり。OneDriveのフォルダ選択は不可 |
| 学校行事APIの取得・保持 | 新しいAPI接続は架空データのテストを実施。iOSビルド・実機確認待ち。旧PDF取得経路の実機成功報告は過去版の記録 |
| XLSX解析・結果確認 | 数式対応後の実機解析成功報告あり。AIクラス表記統一の実機成功報告あり。警告付きプレビューの実機操作は確認待ち |
| PDF解析・結果確認 | 通常時間割のバージョン7は実機解析成功の報告あり。バージョン8で教室名の重複濁点・半濁点を限定補正し、実機確認待ち。学校行事はバージョン4を維持 |
| SwiftUI 時間割タブ | 既存版は iOS SDK ビルド・Release 公開と利用者の実機表示報告あり。試験・返却PDFの実機解析失敗を受けて修正し、再確認待ち |
| 対応表の認証付き配信・時間割統合 | 未接続・未実装 |
| 通知・バックグラウンド更新 | 未実装 |

## iPhone に導入する

対象は **iOS 16.0 以降の iPhone と AltStore Classic** です。現在の配布設定では iPad 専用 UI・AltStore PAL・App Store 配布は対象にしていません。

以下の固定 URL を AltStore Classic の Source として追加できます。

```text
https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
```

CI は [Actions](https://github.com/n624-dev/takupoke-ios/actions/workflows/ios-release.yml)、公開済みの成果物は [Releases](https://github.com/n624-dev/takupoke-ios/releases) で確認できます。

Windows での AltServer 準備、初回導入、アップデート、実機確認項目は [導入・更新手順](docs/distribution.md) を参照してください。IPA は署名なしで生成し、導入時に AltStore 側で署名する構成です。Apple ID や署名証明書をこのリポジトリや CI に登録する必要はありません。

## ファイル選択

アプリの「設定」→「ファイル選択」で、通常時間割PDF・時間割変更XLSX・試験PDF・試験返却PDFを個別に選びます。学校行事は同じ画面で年度を指定し、「行事予定APIから取得」を押します。試験・返却PDFは解析に失敗しても選択状態を保持し、それぞれの「PDFを解析・結果を確認」から再解析と全文診断のコピーができます。起動時には保存済みファイルのハッシュを確認し、行事元PDFにはHEADでETagを確認します。PDF本文の自動ダウンロードと行事データの自動取得は行いません。再取得・アクセス失効時の対応・現在の制約は [学校資料の選択・取得](docs/materials.md) を参照してください。

## 開発する

現在の Linux 開発環境と Windows で編集し、iOS のビルドには GitHub Actions の macOS runner を使用します。Mac の所有は前提にしません。

```text
Linux / Windows で編集・ローカル検証
  → GitHub の main へ push
  → macOS runner で IPA をビルド
  → IPA と AltStore Source を同じ Release で公開
  → iPhone の AltStore Classic から更新
```

ローカルの配布テストに必要なのは Git と Python 3.11 以降です。Python の追加パッケージは不要です。

```sh
git clone https://github.com/n624-dev/takupoke-ios.git
cd takupoke-ios
python3 -B -m unittest discover -s tests -v
```

Windows では最後のコマンドを `py -3 -B -m unittest discover -s tests -v` に置き換えます。コミット前に、自分の GitHub `noreply` メールをこの clone に設定してください。詳しくは [開発環境・検証手順](docs/development.md) を参照してください。

## 構成

```text
Takupoke/                  SwiftUI アプリ、Info.plist、アイコン、プライバシー宣言
Takupoke.xcodeproj/         共有 scheme を含む Xcode プロジェクト
distribution/config.json   公開アプリ情報・バージョン系列
tools/                     IPA ビルド・Source 生成・公開用スクリプト
tests/                     架空データによる配布・保存・復旧・XLSX解析のテスト
Package.swift              Linux / macOSで共通の解析ソースを検証するSwift Package
.github/workflows/         iOS ビルドと AltStore 配布の CI
docs/                      方針・手順・検証・情報管理
```

## ドキュメント

| 文書 | 内容 |
| --- | --- |
| [確定した開発方針](docs/development-policy.md) | 採用技術、資料取得、解析、保存、配布の判断基準 |
| [開発ロードマップ](docs/roadmap.md) | ①〜⑧の順序と完了条件 |
| [端末内DB・統合の設計案](docs/local-database-design.md) | 修正案に基づく保存・採用・復旧の設計と、確認待ちの資料契約 |
| [時間割タブの表示仕様](docs/timetable-tab.md) | 週表示、変更反映、Astro版との機能照合 |
| [開発環境・検証手順](docs/development.md) | Linux / Windows の準備、Git 設定、テスト、ビルド |
| [導入・更新・配布の仕組み](docs/distribution.md) | Source URL、実機導入、番号規則、障害対応 |
| [学校資料の選択・取得](docs/materials.md) | OneDrive / Files の選択・再取得・制約・実機確認項目 |
| [XLSX解析の移植仕様](docs/xlsx-specification.md) | 既存実装の規則、架空の比較データ、未実装の範囲 |
| [対応表配信の接続方針](docs/mapping-distribution.md) | OIDC・配信用Worker・非公開R2の役割と、未確定の接続情報 |
| [PDF解析の仕様確認](docs/pdf-specification.md) | 同時刻の並記授業、空欄保持、記載名・正式名称の保持とWeb版に合わせた表示方針 |
| [検証記録](docs/verification.md) | ローカルの確認範囲と CI・実機の確認待ち項目 |
| [公開時の情報管理](docs/public-repository.md) | 学校資料、個人情報、認証情報、コミット作者情報 |
| [貢献ガイド](CONTRIBUTING.md) | 変更提案、Pull Request、公開できるテストデータ |

## データと公開範囲

公開するのはソースコード・設定・ドキュメント・架空のテストデータです。学校の実資料、その抽出結果、氏名、個人のメールアドレス、OneDrive 共有リンク、認証情報は含めません。実資料は原則リポジトリ外に置き、一時ファイルは作業後に片付けます。

確認メモは端末内の UserDefaults、資料とアクセス用ブックマークはアプリ専用の保存領域に置きます。資料の保存領域はバックアップから除外します。学校資料やアクセス情報を開発者のサーバーへ送信する処理はありません。OneDrive との通信は File Provider が担当し、学校行事の取得・更新確認時は学校の公開サイトへ接続します。元資料は変更しません。

## ライセンス

プロジェクトのライセンスは未選定です。正式なライセンスは決定後に `LICENSE` と本節へ記載します。ZIPFoundationと移植元denpa-schedule-csvのMITライセンス表記は [ThirdPartyNotices.txt](Takupoke/ThirdPartyNotices.txt) に含め、アプリ内からも閲覧できます。
