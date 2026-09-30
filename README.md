# たくポケ iOS / takupoke-ios

学校の時間割・時間割変更・試験・試験返却・学校行事を、iPhoneで確認するSwift / SwiftUI製アプリです。個人開発・運営の非公式アプリです。重要な予定は学校の公式案内と元ファイルを確認してください。

[インストール手順](docs/altstore-pal-install.md) · [Releases](https://github.com/n624-dev/takupoke-ios/releases) · [開発環境](docs/development.md) · [検証状況](docs/roadmap.md)

## 主な機能

- 通常時間割PDF・時間割変更XLSX・試験時間割PDF・試験返却時間割PDFの選択、自動解析、端末内保存。
- 学校行事を組み合わせた週の時間割。クラス選択、前週・翌週、カレンダー、通常／変更込み、連続授業の結合、授業詳細、変更一覧。
- ホームの今日の予定、お気に入り、おすすめ、取得済みデータの更新案内。
- 一回の学校アカウント認証でリンク一覧・名称データ・授業時刻を取得。科目・教員・教室の正式名称と日付別の時刻を表示。
- リンクの検索・お気に入り・色変更・非表示、アプリ内／デフォルトのブラウザの選択。
- 起動・復帰・ファイル変更時の確認と、内容変更時の再解析。保存期間内は取得・解析失敗時も前回の正常結果を保持。
- バックグラウンドの更新確認、選択中クラスの時間割変更と選択済み試験・返却PDFの更新通知。
- 初期設定、目的別の使い方、7色のメインカラー、VoiceOver、規約・個別ライセンスの閲覧。

対応端末は**iOS 26・27のiPhone**です。画面は縦向き専用で、標準部品のLiquid Glassに対応しています。

## インストール

[AltStore PAL経由の手順](docs/altstore-pal-install.md)を参照してください。**AltStore PAL → AltStore Classic → たくポケ**の順に導入します。この手順はiOS 27以降・AltStore Classic 2.3以降のRemote AltServerと端末内ペアリングを対象とします。デベロッパモードの有効化と、再起動後の確認も必要です。

iOS 26など、この手順の条件に合わない場合は[WindowsのAltServerを使う手順](docs/distribution.md#windows-と-iphone-の準備)を利用できます。

AltStore Classicに追加するSourceの固定URL:

```text
https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
```

IPAは署名なしで公開し、導入時にAltStore Classicが署名します。無料Apple Accountの署名更新と、アプリの新しい版へのアップデートは別の操作です。配布方法は[配布の仕組み](docs/distribution.md)を参照してください。

## 初めて使う

初期設定に沿って、学校アカウント認証、ファイル選択、クラス選択を行います。試験・返却PDFの選択画面も用意しています。手元にないファイルは後から設定できます。「あとで設定」で終了した場合は、設定から初期設定を開けます。

設定は次の3つに分かれています。

| 見出し | 項目 |
| --- | --- |
| データ | 時間割ファイル、学校行事、リンク・名称・授業時刻 |
| アプリ設定 | クラス、通知、メインカラー、リンクの開き方 |
| サポート | 初期設定、使い方、このアプリについて |

「時間割ファイル」で4種類のPDF・XLSXを選ぶと、自動で解析します。「詳細を見る」で日時・件数・解析結果を確認し、右上の「解析する」で再解析できます。学校行事は「学校行事」で年度を確認し、「学校行事を取得」を押します。リンク一覧・名称データ・授業時刻は「リンク・名称・授業時刻」からまとめて取得します。

クラスは設定と時間割のどちらからも選べます。留学生向け授業の切り替えはクラス選択内にあります。使い方は「はじめに」「時間割を見る」「リンクを使う」「更新と通知」「困ったとき」の5ページです。

## 更新と保存期間

選択したファイルは起動・復帰・表示中の変更通知で内容のハッシュを確認し、変化がある場合に解析します。OneDriveの同期状況によって読み取れる版が異なります。準備と復旧の手順は[ファイル選択と取得](docs/materials.md)に記載しています。

学校行事は保存済み年度を条件付きGETで確認します。リンク一覧・名称データ・授業時刻は公開更新識別子で確認し、新版の取得時に学校アカウント認証を行います。確認のタイミングは[名称データの配信・接続](docs/mapping-distribution.md)を参照してください。

日本時間の4月1日・10月1日の切替後、学校ファイルのコピー・解析結果・アクセス用ブックマーク・リンク一覧・名称データ・授業時刻を削除します。ファイルの再選択とデータの再取得が必要です。クラス・お気に入りなどの個人設定、公開の学校行事、OneDrive上の原本は保持します。詳しくは[非公開データの管理](docs/private-data-lifecycle.md)を参照してください。

## 開発する

Linux / Windowsで編集し、GitHub ActionsでiPhone向けビルドと配布を行います。配布ビルドはXcode 27.0、画面テストはiOS 26・27の専用Runnerを使用します。

```sh
git clone https://github.com/n624-dev/takupoke-ios.git
cd takupoke-ios
python3 -B -m unittest discover -s tests -v
```

Windowsでは最後のコマンドを `py -3 -B -m unittest discover -s tests -v` に置き換えます。コミット前にGitHubの `noreply` メールを設定してください。Swift・UIテスト、依存関係、一時ファイルの管理は[開発環境・検証手順](docs/development.md)を参照してください。

## ドキュメント

| 分類 | 文書 |
| --- | --- |
| 導入・配布 | [PAL経由の導入](docs/altstore-pal-install.md)、[PC経由の導入・配布](docs/distribution.md) |
| 画面・操作 | [ホーム](docs/home.md)、[時間割](docs/timetable-tab.md)、[一覧](docs/links-tab.md) |
| 取得・保存 | [ファイル選択と取得](docs/materials.md)、[名称データの配信](docs/mapping-distribution.md)、[端末内保存](docs/local-database-design.md)、[保存期限](docs/private-data-lifecycle.md) |
| 解析・通知 | [PDF](docs/pdf-specification.md)、[XLSX](docs/xlsx-specification.md)、[通知・バックグラウンド確認](docs/notifications-background.md) |
| 開発 | [開発方針](docs/development-policy.md)、[開発環境](docs/development.md)、[コードの構成](docs/source-structure.md)、[アイコン](docs/app-icon.md)、[貢献ガイド](CONTRIBUTING.md) |
| 検証・情報管理 | [実装と残る確認](docs/roadmap.md)、[シミュレーター検証](docs/simulator-verification.md)、[検証履歴](docs/verification.md)、[公開時の情報管理](docs/public-repository.md) |

## データとライセンス

学校ファイル・アクセス用ブックマーク・解析結果は端末内へ保存します。非公開データの保存先はiOSのファイル保護を使用し、バックアップから除外します。公開するソース・テスト・ログに学校の実資料、抽出結果、個人情報、認証情報を含めません。

プロジェクトのライセンスは未選定です。ZIPFoundation・denpa-schedule-csv・GRDB.swiftのMITライセンスは[LicenseDocuments](Takupoke/LicenseDocuments)に同梱し、設定の「このアプリについて」から個別に全文を閲覧できます。
