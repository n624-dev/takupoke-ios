# たくポケ iOS / takupoke-ios

学校の通常時間割・学校行事・時間割変更を、iPhone 内でひとつにまとめる Swift / SwiftUI 製アプリです。

通常時間割・時間割変更は iOS 標準の「ファイル」から OneDrive File Provider 経由で取得し、学校行事PDFは学校の公開サイトから取得します。Web 版とは独立して実装し、Microsoft Graph や通知用サーバーを必要としない構成を目指します。

**現在は資料取得と時間割変更XLSXの解析に対応する開発版です。PDF解析・通常時間割との統合はまだありません。XLSX解析の実機成功報告があります。追加したAIクラス表記統一は実機確認待ちです。**

[導入・更新手順](docs/distribution.md) · [開発環境](docs/development.md) · [ロードマップ](docs/roadmap.md) · [Releases](https://github.com/n624-dev/takupoke-ios/releases)

## 現在できること

- iOS「ファイル」から通常時間割PDF・時間割変更XLSXを個別に選択して端末内に保存。対応サービスではフォルダ選択も利用可能。
- 学校行事PDFを固定の学校公式URLから取得して保持。手動更新はETag / Last-Modifiedを使い、変更なしの応答では本体の再取得を省略。
- 資料の参照先を保存して手動再取得。失敗時は前回のコピーを維持し、エラーを表示。
- 保存した時間割変更XLSXを手動解析し、日付・クラス・変更前後科目・教員・教室・備考を確認。年なし日付の補完年を明示的に指定でき、解析失敗時は前回正常な結果を保持。
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
| 学校行事PDFのWeb取得・保持 | 取得・再起動後の保持・変更なし時の日時表示を利用者報告で確認。条件付き応答と失敗時の保持は架空データでテスト |
| XLSX解析・結果確認 | 数式対応後の実機解析成功報告あり。AIクラス表記統一と警告付きプレビューの実機操作は確認待ち |
| PDF解析・時間割統合 | 未実装 |
| 通知・バックグラウンド更新 | 未実装 |

## iPhone に導入する

対象は **iOS 16.0 以降の iPhone と AltStore Classic** です。現在の配布設定では iPad 専用 UI・AltStore PAL・App Store 配布は対象にしていません。

以下の固定 URL を AltStore Classic の Source として追加できます。

```text
https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json
```

CI は [Actions](https://github.com/n624-dev/takupoke-ios/actions/workflows/ios-release.yml)、公開済みの成果物は [Releases](https://github.com/n624-dev/takupoke-ios/releases) で確認できます。

Windows での AltServer 準備、初回導入、アップデート、実機確認項目は [導入・更新手順](docs/distribution.md) を参照してください。IPA は署名なしで生成し、導入時に AltStore 側で署名する構成です。Apple ID や署名証明書をこのリポジトリや CI に登録する必要はありません。

## 学校資料を選ぶ

アプリの「学校資料を選ぶ」で通常時間割PDFと時間割変更XLSXを個別に選びます。学校行事は「学校サイトから取得」で保存し、以降は「更新を確認」を使います。起動時にPDFを毎回ダウンロードする処理はありません。再取得・アクセス失効時の対応・現在の制約は [学校資料の選択・取得](docs/materials.md) を参照してください。

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
| [開発環境・検証手順](docs/development.md) | Linux / Windows の準備、Git 設定、テスト、ビルド |
| [導入・更新・配布の仕組み](docs/distribution.md) | Source URL、実機導入、番号規則、障害対応 |
| [学校資料の選択・取得](docs/materials.md) | OneDrive / Files の選択・再取得・制約・実機確認項目 |
| [XLSX解析の移植仕様](docs/xlsx-specification.md) | 既存実装の規則、架空の比較データ、未実装の範囲 |
| [検証記録](docs/verification.md) | ローカルの確認範囲と CI・実機の確認待ち項目 |
| [公開時の情報管理](docs/public-repository.md) | 学校資料、個人情報、認証情報、コミット作者情報 |
| [貢献ガイド](CONTRIBUTING.md) | 変更提案、Pull Request、公開できるテストデータ |

## データと公開範囲

公開するのはソースコード・設定・ドキュメント・架空のテストデータです。学校の実資料、その抽出結果、氏名、個人のメールアドレス、OneDrive 共有リンク、認証情報は含めません。実資料は原則リポジトリ外に置き、一時ファイルは作業後に片付けます。

確認メモは端末内の UserDefaults、資料とアクセス用ブックマークはアプリ専用の保存領域に置きます。資料の保存領域はバックアップから除外します。学校資料やアクセス情報を開発者のサーバーへ送信する処理はありません。OneDrive との通信は File Provider が担当し、学校行事の取得・更新確認時は学校の公開サイトへ接続します。元資料は変更しません。

## ライセンス

プロジェクトのライセンスは未選定です。正式なライセンスは決定後に `LICENSE` と本節へ記載します。ZIPFoundationと移植元denpa-schedule-csvのMITライセンス表記は [ThirdPartyNotices.txt](Takupoke/ThirdPartyNotices.txt) に含め、アプリ内からも閲覧できます。
