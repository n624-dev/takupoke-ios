# たくポケ iOS / takupoke-ios

学校の時間割・時間割変更・試験・試験返却・学校行事を、iPhoneで確認するSwift / SwiftUI製アプリです。個人開発・運営の非公式アプリです。重要な予定は学校の公式案内と元ファイルを確認してください。

[インストール手順](docs/altstore-pal-install.md) · [Releases](https://github.com/n624-dev/takupoke-ios/releases) · [開発環境](docs/development.md) · [検証状況](docs/roadmap.md)

開発時は[テスト一覧と変更時の必須手順](docs/test-catalog.md)から対応テストを検索してください。
[テスト保守方針](docs/test-maintenance-policy.md)に従い、未登録コードと一覧の整合性をCIで検査します。既存テストで十分なら、ケースと実行結果を記録し、不要なテスト編集は行いません。

PDF端末内AI復旧は開発中です。前処理・Validator・開始・元PDF確認・プレビュー・明示採用・モデル管理と各iOS Runtime adapterを接続しました。OCR復旧後のプレビューでは、科目を長押しすると、その授業の科目・教員・教室を原本と照合して訂正できます。高信頼の誤読も対象ですが、安全な所属を確認できた本文だけ、必須の確認項目と合わせて資料全体で最大3項目です。追加時は入力を保持し、全項目の原本一致を確認し直します。追加モデルはまだ配信していません。[方針・実装状況・残る確認](docs/pdf-recovery.md)を参照してください。

[Strict PDFの詳細番号一覧](docs/strict-pdf-branch-catalog.md)で、P／R番号から拒否箇所を確認できます。
393.1の通常R265・試験R267・返却R270という報告を受け、[239.1のStrictを復元](docs/strict239-restoration.md)しました。
通常・試験・返却の解析を旧仕様へ戻し、追加の表示・Evidence検査は復旧専用に分離しています。
394.1公開後、利用者から3種類の解析が戻った実機報告を受けました。[原因調査](docs/strict-pdf-regression-cause.md)を記録しています。

[OCRの実測と不採用にした比較](docs/ocr-improvement-log.md)を記録しています。小さな取得テストと文書全体の品質は分けて評価します。

設定の「AI・OCRを使用する」は初期OFFです。OFF時は従来の厳格な解析のみを使用し、ON時も厳格な解析に失敗したPDFだけ復旧します。時間割変更XLSXの曜日不一致は、日付からの補正を明示承認できます。曜日に問題がある行は、元の記載を確認して除外できます。同じ曜日だけが残った連続行は、200〜300行目などの範囲をまとめて選べます。補正・除外はファイル内容が更新されるまで同じ原本に適用します。詳しくは[XLSX仕様](docs/xlsx-specification.md)を参照してください。

最新版は[Latest Release](https://github.com/n624-dev/takupoke-ios/releases/latest)と固定AltStore Sourceから確認できます。今回の修正は、連続しない変更時限、試験・返却の時刻、備考のある休講・補講、不正年度と鮮度警告、名称データの復旧、通知・ファイル監視を対象とします。返却PDFは元の先頭列と専用時刻の対応を保存し、日付順の並べ替えで時刻を変えません。[修正と検証](docs/issue-59-verification.md)、[追加Issueの検証](docs/issue-47-58-verification.md)を記録しています。物理iPhoneでの確認は別途必要です。

以前の[0.1.419（419.1）](https://github.com/n624-dev/takupoke-ios/releases/tag/v0.1.419-build.419.1)を通常Releaseとして公開した際には、固定AltStore Sourceを更新しました。
留学生向けの休講・変更を非表示にした際、通常授業や試験／返却授業まで空欄になる問題を修正しました。ホーム・時間割・共通時刻・振替土曜へ同じ表示条件を適用し、元資料の詳細と表示対象の休講・補講の優先を保持します。再解析は不要です。
一覧リンクはタップで開き、長押しでメニューを出す標準Menuに揃えました。実メニューでのお気に入り解除・再起動保持・再追加、タップでブラウザを開いて戻る操作を両OSで検証しています。
時間割変更の除外後の全体再解析・失敗時保持、ホーム正式名称、シラバス学科設定、一覧専用学内認証は414.1の機能を継承しています。
[同一ソースのCI](https://github.com/n624-dev/takupoke-ios/actions/runs/39397264222)全15必須チェックと、公開4添付の匿名取得・全ハッシュ・IPA内部の版とソース・固定Sourceの一致を確認済みです。[検証の詳細](docs/verification.md)。
AltStore ClassicのSource／更新一覧を更新するとアップデートできます。Sourceの再登録やアプリの削除は不要です。
厳格な解析とその全入口／経路、追加モデルは変更していません。修正版の物理iPhone確認、新認証の実機完了と実資料OCR精度は今回未確認です。

以前の[401.1](https://github.com/n624-dev/takupoke-ios/releases/tag/v0.1.401-build.401.1)では、次の修正と実機報告がありました。
1年のPDF授業は、原文授業名のCN／ES／ITの1種類に応じた学科へ移し、保存成功後は移行先だけに残します。
返却はクラス欄が下段のコマ見出しまで結合する構造に対処し、本文を含まない位置情報の手動取得も追加しました。
通常・試験のStrictは239.1の復元を維持し、復旧の原本所属・Evidence検証も保持しています。
同じソース・試行1の全13必須チェック、SDK26.6／27.0の各Native576件（予定skip1、失敗0）、両OSの通常UI・手動訂正が成功しました。
認証なしで4添付を取得し、全ハッシュ・IPAの版とソース・固定Sourceとの一致を確認済みです。
401.1公開後、利用者から返却の時限見出しが授業名へ混入せず、1年授業の学科移行もできたとの実機報告を受けました。
診断コピー、AltStore Source経由の更新方法と全授業項目の網羅的な照合は引き続き未確認です。
実装範囲は[PDF仕様](docs/pdf-specification.md)、実測・旧実行の失敗・未確認事項は[検証記録](docs/verification.md)に記載しています。

先行確認用の[開発406.1](https://github.com/n624-dev/takupoke-ios/releases/tag/dev-ios-38978574667-1-d40ba83544a5)も保持しています。現在は同じOCR訂正機能を、固定Sourceの正式419.1から更新できます。

以前の[個別開発確認版IPA](https://github.com/n624-dev/takupoke-ios/releases/tag/dev-ios-37811661856-1-22c8ee2b5fa5)も引き続き公開しています。ソース`22c8ee2`の既存公開版で、現在のLatest・固定AltStore Sourceとは別です。

## 主な機能

- 通常時間割PDF・時間割変更XLSX・試験時間割PDF・試験返却時間割PDFの選択、自動解析、端末内保存。
- 学校行事を組み合わせた週の時間割。クラス選択、前週・翌週、カレンダー、通常／変更込み、連続授業の結合、授業詳細、変更一覧。OSの文字サイズに合わせて文字とカードを拡大できます。
- ホームの今日の予定は科目の正式名称を優先し、未対応は原名を表示。お気に入り、おすすめ、取得済みデータの更新案内。
- 一覧・名称・授業時刻の取得対象を選択。初回一括はMicrosoft認証一回、一覧だけなら学内ネットワーク認証を使用し、学外・判定不能時はMicrosoftへ進みます。名称・時刻はMicrosoft認証を維持。科目・教員・教室の正式名称と日付別の時刻を表示。
- リンクの検索・お気に入り・色変更・非表示、アプリ内／デフォルトのブラウザの選択。
- 設定の「シラバスの学科」で入学年度区分付きの11候補を選択。既知のシラバスを選択学科と当年で開きます。
- 起動・復帰・ファイル変更時の確認と、内容変更時の再解析。保存期間内は取得・解析失敗時も前回の正常結果を保持。
- バックグラウンドの更新確認、選択中クラスの時間割変更と選択済み試験・返却PDFの更新通知。
- 初期設定、目的別の使い方、OS標準と7色から選ぶメインカラー、VoiceOver、規約・個別ライセンスの閲覧。

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
| アプリ設定 | クラス、通知、メインカラー、リンクの開き方、シラバスの学科 |
| サポート | 初期設定、使い方、このアプリについて |

「時間割ファイル」で4種類のPDF・XLSXを選ぶと、自動で解析します。「詳細を見る」で日時・件数・解析結果を確認し、右上の「解析する」で再解析できます。学校行事は「学校行事」で年度を確認し、「学校行事を取得」を押します。リンク一覧・名称データ・授業時刻は「リンク・名称・授業時刻」からまとめて取得します。

取得・確認・解析・元ファイル更新の日時は、端末のタイムゾーンにかかわらず日本時間で表示します。保存している日時自体は変更しません。

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
| 解析・通知 | [PDF](docs/pdf-specification.md)、[239.1→380.1のStrict差分](docs/strict-pdf-diff-audit-239-380.md)、[Strict互換性の修正点](docs/strict-pdf-compatibility-repair.md)、[XLSX](docs/xlsx-specification.md)、[通知・バックグラウンド確認](docs/notifications-background.md) |
| 開発 | [開発方針](docs/development-policy.md)、[開発環境](docs/development.md)、[コードの構成](docs/source-structure.md)、[CIの実行時間](docs/ci-performance.md)、[アイコン](docs/app-icon.md)、[貢献ガイド](CONTRIBUTING.md) |
| 検証・情報管理 | [実装と残る確認](docs/roadmap.md)、[シミュレーター検証](docs/simulator-verification.md)、[検証履歴](docs/verification.md)、[公開時の情報管理](docs/public-repository.md) |

## データとライセンス

学校ファイル・アクセス用ブックマーク・解析結果は端末内へ保存します。非公開データの保存先はiOSのファイル保護を使用し、バックアップから除外します。公開するソース・テスト・ログに学校の実資料、抽出結果、個人情報、認証情報を含めません。

プロジェクトのライセンスは未選定です。ZIPFoundation・denpa-schedule-csv・GRDB.swiftのMITライセンスは[LicenseDocuments](Takupoke/LicenseDocuments)に同梱し、設定の「このアプリについて」から個別に全文を閲覧できます。

試験返却PDFの見出し混入を調べる場合は、解析結果の授業詳細で「位置情報を取得」→「位置情報をコピー」を操作します。
本文・教員名・教室名・画像を含めず、端末内だけで位置情報を作ります。コピー内容は非公開の開発相談へ共有してください。
1年のPDF授業で授業名にCN・ES・ITの1種類が明記されたものは学科所属へ移し、元クラスへ二重保存しません。
