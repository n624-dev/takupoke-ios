# たくポケ iOS / takupoke-ios

個人開発・運営の非公式アプリです。香川高等専門学校・国立高等専門学校機構が運営・承認・推奨・保証するものではありません。重要な予定は学校の公式案内を確認してください。

学生向けデータの認証・保存期間は [非公開データの管理](docs/private-data-lifecycle.md) を参照してください。

学校の通常時間割・学校行事・時間割変更を、iPhone 内でひとつにまとめる Swift / SwiftUI 製アプリです。

通常時間割・時間割変更は iOS 標準の「ファイル」から OneDrive File Provider 経由で取得し、学校行事は `takupoke-api` から初回に手動で取得します。保存後は起動時に更新を確認します。Microsoft Graph は使いません。

[インストール手順](docs/altstore-pal-install.md) · [開発環境](docs/development.md) · [ロードマップ](docs/roadmap.md) · [Releases](https://github.com/n624-dev/takupoke-ios/releases)

## 主な機能

- 通常時間割PDF・時間割変更XLSX・試験PDF・試験返却PDFを選択し、端末内で解析・保存。
- 学校行事APIと解析結果を組み合わせた週の時間割表示。クラス選択、週移動、授業詳細、変更一覧に対応。
- 学校アカウント認証によるリンク一覧と名称対応表の取得・更新。
- リンクの検索・お気に入り・色変更・非表示。ホームにはお気に入りとおすすめを表示。
- 起動時・復帰時のファイル確認と、変更がある場合の再解析。取得・解析に失敗した場合は保存期間内の正常結果を保持。
- 初回セットアップと、設定からの再開。
- 7色のメインカラー、アプリ内／外部ブラウザの選択、ライセンスの個別表示。

画面は縦向き専用です。iOS 26以降では標準部品のLiquid Glassに対応しています。通知と時間割画像の共有は未実装です。実装範囲と検証状況は[ロードマップ](docs/roadmap.md)と[検証記録](docs/verification.md)を参照してください。

## iPhone に導入する

まず [AltStore PAL 経由のインストール手順](docs/altstore-pal-install.md) を参照してください。**AltStore PAL → AltStore Classic → たくポケ** の順に導入します。この案内は、iOS 27以降とAltStore Classic 2.3以降でRemote AltServer・端末内ペアリングを使う方を対象にしています。

たくポケ本体は **iOS 16.0以降のiPhone** に対応します。追加ガイドの条件に合わない場合は、[WindowsのAltServerを使う導入手順](docs/distribution.md#windows-と-iphone-の準備) を利用できます。画面は縦向き専用です。アプリアイコンはWeb版のクラシックを単色化したLiquid Glass対応素材を使用します（[素材とビルド](docs/app-icon.md)）。

以下の固定 URL を AltStore Classic の Source として追加できます。

```text
https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
```

CI は [Actions](https://github.com/n624-dev/takupoke-ios/actions/workflows/ios-release.yml)、公開済みの成果物は [Releases](https://github.com/n624-dev/takupoke-ios/releases) で確認できます。

導入後は初回セットアップに沿って学校アカウント認証・ファイル選択・クラス選択を行います。IPA は署名なしで生成し、導入時に AltStore Classic が署名します。配布の生成・公開方法は [配布の仕組み](docs/distribution.md) に記載しています。

## ファイル選択

アプリの「設定」→「ファイル選択」で、通常時間割PDF・時間割変更XLSX・試験PDF・試験返却PDFを個別に選びます。各ファイルの「詳細を見る」から取得日時・解析結果を確認し、右上の「解析する」で再解析できます。学校行事は同じ画面で年度を指定し、「学校行事を取得」を押します。件数と取得日時は詳細画面で確認できます。試験・返却PDFは解析に失敗しても選択状態と前回の正常結果を保持します。公開版では診断コピーを表示しません。起動時には保存済みファイルのハッシュを確認し、保存済み年度の学校行事APIをETagで条件付き取得します。行事元PDFには別途HEADでETagを確認し、PDF本文は自動ダウンロードしません。再取得・アクセス失効時の対応・現在の制約は [学校資料の選択・取得](docs/materials.md) を参照してください。

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
| [AltStore PAL経由のインストール](docs/altstore-pal-install.md) | 主な新規導入手順、Remote AltServer、署名更新 |
| [PC経由の導入・配布の仕組み](docs/distribution.md) | Windowsの導入経路、Source URL、番号規則、障害対応 |
| [学校資料の選択・取得](docs/materials.md) | OneDrive / Files の選択・再取得・制約・実機確認項目 |
| [XLSX解析の移植仕様](docs/xlsx-specification.md) | 既存実装の規則、架空の比較データ、未実装の範囲 |
| [名称対応表の配信・接続](docs/mapping-distribution.md) | 起動時の公開revision確認、OIDC認証、ZIP検証、専用SQLite保存 |
| [PDF解析の仕様確認](docs/pdf-specification.md) | 同時刻の並記授業、空欄保持、記載名・正式名称の保持とWeb版に合わせた表示方針 |
| [検証記録](docs/verification.md) | ローカルの確認範囲と CI・実機の確認待ち項目 |
| [公開時の情報管理](docs/public-repository.md) | 学校資料、個人情報、認証情報、コミット作者情報 |
| [貢献ガイド](CONTRIBUTING.md) | 変更提案、Pull Request、公開できるテストデータ |

## データと公開範囲

公開するのはソースコード・設定・ドキュメント・架空のテストデータです。学校の実資料、その抽出結果、氏名、個人のメールアドレス、OneDrive 共有リンク、認証情報は含めません。実資料は原則リポジトリ外に置き、一時ファイルは作業後に片付けます。

クラス・メインカラーなどの個人設定、資料とアクセス用ブックマークを端末内に保存します。資料の保存領域はバックアップから除外します。学校資料やアクセス情報を開発者のサーバーへ送信する処理はありません。OneDriveとの通信はFile Providerが担当します。学校行事はたくポケAPIから取得し、元PDFの更新確認は学校サイトへHEADを送信します。元資料は変更しません。

## ライセンス

プロジェクトのライセンスは未選定です。正式なライセンスは決定後に `LICENSE` と本節へ記載します。ZIPFoundation・移植元denpa-schedule-csv・GRDB.swiftのMITライセンス表記は [LicenseDocuments](Takupoke/LicenseDocuments) に含め、設定の「このアプリについて」→「オープンソースライセンス」から個別に全文を閲覧できます。

初めて起動したときはセットアップで学校アカウント認証、ファイル選択、クラス選択へ進めます。「あとで設定」で終了した場合も、設定からセットアップを開けます。一覧・名称対応表の更新と、使い方・規約・ライセンスは設定にまとめています。
