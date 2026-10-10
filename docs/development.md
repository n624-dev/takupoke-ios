# 開発環境と検証手順

[README に戻る](../README.md)

## 必要な環境

| 作業 | 環境・ツール |
| --- | --- |
| ソース編集、Git 操作 | Linux または Windows、Git、任意のエディター |
| 配布処理のローカルテスト | Python 3.11 以降、標準ライブラリのみ |
| ワークフローの追加チェック | 任意で actionlint |
| iOS ビルド | Actions の `xcode-27` と Xcode 27.0 |
| アプリ画面の検証 | iOS 26：`macos-26`・Xcode 26.6、iOS 27：`xcode-27`・Xcode 27.0 |
| 実機導入・更新 | iOS 26・27のiPhone、AltStore Classic。[導入手順](altstore-pal-install.md)を参照 |

Linux / Windows では SwiftUI のビルドを行わず、配布スクリプトのテストとソース編集を行います。XLSX展開にはZIPFoundation 0.9.20、SQLite保存基盤にはGRDB 7.11.1をコミット固定のSwift Packageとして使用します。共通ソースのテストにはSwift 6.1以降が必要です。

Actionsでは `/Applications/Xcode_27.0.app/Contents/Developer` を指定し、正式版のXcode 27.0を使用します。`xcode-27` runnerは公開プレビューです。最低対応OSはiOS 26、アプリのSwift言語モードは5を維持します。

## clone とメールアドレスの非公開設定

```sh
git clone https://github.com/n624-dev/takupoke-ios.git
cd takupoke-ios
```

最初のコミット前に、自分の公開用ユーザー名と GitHub の `noreply` アドレスを設定します。下記のプレースホルダーは自分の値に置き換えてください。他人の作者情報を使用しないでください。

```sh
git config --local user.name "YOUR_PUBLIC_NAME"
git config --local user.email "YOUR_GITHUB_NOREPLY_ADDRESS"
git config --local user.useConfigOnly true
```

設定は clone ごとに必要です。メンテナーの同一アカウント用設定と確認方法は [情報管理ルール](public-repository.md#コミットのメールアドレス) に記載しています。認証には各開発環境の GitHub 認証を使用し、トークンを remote URL やファイルへ埋め込みません。

## ローカル検証

Linux:

```sh
python3 -B -m unittest discover -s tests -v
bash -n tools/build-ios.sh
bash -n tools/build-ios-app.sh
bash -n tools/test-picker-ui.sh
bash -n tools/test-app-ui.sh
bash -n tools/test-materials.sh
bash -n tools/test-parsing.sh
git diff --check
```

Windows PowerShell:

```powershell
py -3 -B -m unittest discover -s tests -v
git diff --check
```

Windows でシェルスクリプトを変更した場合は Git Bash で `bash -n tools/build-ios.sh`、`bash -n tools/test-materials.sh`、`bash -n tools/test-parsing.sh` も実行します。`actionlint` がある環境ではリポジトリのルートで `actionlint` を実行します。

テストは架空の IPA を OS の一時ディレクトリに作成し、正常終了・テスト失敗のどちらでも後片付けします。`-B` は Python のバイトコードキャッシュ作成を抑止します。これらのテストは実際の SwiftUI ビルドや AltStore インストールの代わりにはなりません。

## Swift の保存処理テスト

`bash tools/test-materials.sh` はアプリ本体の `MaterialLibrary.swift` を直接コンパイルし、保存・再読み込み・書き込み失敗時の保持・途中終了の回収・破損時の停止を架空データで検証します。macOS のビルド処理でも IPA 作成前に必ず実行します。失敗すれば配布には進みません。加えて `WebPDFDownloader.swift` を架空のHTTP応答で動かし、PDF取得・条件付きGET・304時の保持・HTTPエラー・サイズ上限・中止を検証します。学校サイトへの通信や実資料の取得は行いません。SwiftUI や File Provider はこのテストの対象外です。

Swift 6.1以降をPATHに追加して実行します。

```sh
bash tools/test-materials.sh
```

コンパイラーのモジュールキャッシュ・実行ファイル・テストデータは専用の一時ディレクトリに置き、終了時に削除します。

学校サイトの本番URLをテスト・疎通確認に使いません。HEADや条件付きGETも禁止です。通信テストのURLProtocolはすべてのリクエストを捕捉し、`example.invalid`以外を拒否します。学校サーバーへの定期確認・負荷試験はCIへ追加しないでください。実装の調査で本番資料を取得する場合は必要な回数に限定し、実資料をリポジトリ・CIへ持ち込みません。

## Swiftの解析・保存テスト

`bash tools/test-parsing.sh` はSwift Package経由で、本体のXLSX読み取り・正規化・PDFの位置情報解析・保存処理を検証します。GitHubから固定したZIPFoundationとGRDBを取得しますが、学校サイトや学校資料にはアクセスしません。教師名・科目名を含め、テスト入力・期待結果は架空です。

LinuxではSwift 6.1以降に加えてzlib・SQLiteの開発ファイルが必要です。Ubuntuでは `zlib1g-dev`、`libsqlite3-dev`、`pkg-config` を導入してください。

```sh
bash tools/test-parsing.sh
```

依存ライブラリを独自のディレクトリへ配置する場合は、`TKPK_ZLIB_PREFIX` にzlib・SQLiteのヘッダーとライブラリの配置先を指定します。

PDFの公開テストは架空の文字と罫線から生成します。macOSではPDFKitによる読み取りと回転も検証します。

macOS CIでは標準のCompressionを使うため、この追加導入は不要です。解析テストもIPA作成前に実行し、失敗時は配布を止めます。パッケージcheckout、ビルド、モジュールキャッシュ、架空XLSXは専用一時ディレクトリにまとめ、終了時に削除します。SwiftPMの共有依存キャッシュは無効にします。通常の `swift test` を直接実行すると既定のキャッシュ・`.build`が残るため、このスクリプトを使ってください。

Xcode側も依存のcheckout・キャッシュをビルド用一時ディレクトリへ指定し、repository cacheを無効にしています。Actions cache・artifactの保存は追加していません。`Package.swift`、Xcodeプロジェクト、2か所の `Package.resolved` は同じコミットに揃えます。

### 復旧の負荷と中止を確認する入力

`RecoveryBuilderTests` は680セル・各3項目24群の完全架空の返却PDFレイアウトから、前処理・Rules・Validatorを通す。iOSでは固定項目の行をSourceへまとめるため、実Builderの出力は2,388件。49,308の独立Source入力は同じ架空文字と群の位置を使う別の契約回帰であり、Builderの実到達件数やモデルの精度として報告しない。背の高い跨セルSource、原順、共有の比較・文字列上限、内側取消、上限時に次のモデルを読み込まないことも検証する。最新検証ではLinux295件、Native Mac343件が成功した。Apple SDKのiPhoneビルドでworkerと各Providerの接続を確認し、OS26/27の実アプリUIで安定した詳細表示、採用・再起動後の保持を確認した。物理端末のモデル推論・メモリ・取消は別に確認する。

## このLinux環境のSwift

この開発環境ではSwift 6.1.2を `/home/ubuntu/.local/share/swift-6.1.2` に配置しています。既定のPATHには含まれていません。zlib・SQLiteの開発ファイルは `/home/ubuntu/.local/share/takupoke-build-deps` にあります。

現在のOSにはSwift Package Managerが必要とする `libxml2.so.2` がないため、Ubuntuの公式パッケージ `libxml2`・`libicu74` を `/home/ubuntu/.local/share/swift-6.1.2-compat` に展開しています。システムのライブラリは変更せず、実行時だけ参照します。

```sh
export PATH="/home/ubuntu/.local/share/swift-6.1.2/usr/bin:$PATH"
export LD_LIBRARY_PATH="/home/ubuntu/.local/share/swift-6.1.2-compat/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export TKPK_ZLIB_PREFIX="/home/ubuntu/.local/share/takupoke-build-deps"
swift --version
bash tools/test-materials.sh
bash tools/test-parsing.sh
```

これらはこの端末の設置先です。別のLinux環境では実際の設置先に合わせます。LinuxのSwiftではPDFKit・SwiftUI・iOSの実行検証はできないため、該当部分はmacOS・Xcodeで確認します。

## UI検証とビルドの並列実行

通常画面はiOS 26・27で各2組、手動訂正は各OSで3ケースに分けて実行します。
配布検査・Native・全画面の12事前検査が成功してから配布用Runnerを割り当てます。
公開前にも同じ実行・試行・コミットの成功を照合します。
対象は[シミュレーター検証](simulator-verification.md)、
測定結果は[CIの実行時間](ci-performance.md)を参照してください。

`tools/build-ios.sh` は同じRunner内で次の順に実行します。標準ファイル画面の表示とアクセシビリティ取得が、保存・解析テストのSwiftコンパイルとCPU・メモリを競合しないようにします。別Runnerの実アプリUI4組との並行実行は維持します。

- `tools/test-picker-ui.sh`：使い捨てのiPhoneシミュレーターで標準ファイル選択画面を検証。XCUITestでボタンをタップし、別の検証で表示領域・遅れたキャンセル・表示拒否後の再選択・選択結果の引き継ぎを確認。
- `tools/build-ios-app.sh`：保存・解析テストの後にiPhone向けReleaseビルドを実行。

UI検証用のXcodeプロジェクトは `tools/picker_test_project.py` が一時ディレクトリへ生成します。検証後はプロジェクト・テスト結果・シミュレーターを削除します。

`tools/parallel_build.py` が各処理の終了結果を確認し、すべて成功した場合だけIPA作成へ進みます。先の処理が失敗したら次の処理を開始せず、中止時には子プロセスも停止します。処理ごとのログは実行中に出力し、一時ディレクトリとシミュレーターは後片付けします。プロセス制御とBash実行のテストはmacOS・Linuxで実行し、Windowsでは省略します。

## ファイルを変更するとき

- SwiftUI 画面は `Takupoke/` に追加する。新しい Swift ファイルは Xcode プロジェクトの Sources にも登録する。
- Bundle ID と最低 iOS は `distribution/config.json` と Xcode の設定を一致させる。導入済みアプリの更新を維持するため、Bundle ID は安易に変更しない。
- バージョンの major / minor は `distribution/config.json` の `versionPrefix` で管理する。patch と build は CI が付与する。
- 権限、拡張機能、署名設定を追加するときは、Source の `appPermissions` と IPA 検証処理も更新する。現在は通知許可・バックグラウンド更新の登録と、Required Reason APIのプライバシー宣言を含む。
- 配布や機能の挙動を変えたらREADMEと関連手順、`distribution/release-notes.txt` を更新する。

アイコンはWeb版のクラシックを元にした `Takupoke/AppIcon.icon` です。Xcode 27.0でLiquid Glass用にコンパイルします。素材の出典・更新方法・各外観の指定は[アプリアイコン](app-icon.md)を参照してください。

## push と CI

`main` への push でテスト・iOS ビルド・配布を実行します。Pull Request はテスト・ビルドのみで公開しません。Actions の手動実行も可能ですが、公開するのはこのリポジトリの `main` だけです。

コード変更後は対象コミットのActionsが完了するまで確認し、失敗時はログを調べて修正します。文書のみのpushではActionsを監視しません。取得したログは確認後に削除し、共有する情報に個人情報を含めないでください。

## Mac が利用できる場合の任意のビルド

Mac の所有は必須ではありません。Xcode 27.0 を利用できる場合のみ、次のようにローカルビルドできます。

```sh
export TKPK_VERSION=0.1.1
export TKPK_BUILD=1.1
export TKPK_COMMIT="$(git rev-parse HEAD)"
bash tools/build-ios.sh ./dist
```

これは動作検証用です。配布は Actions から行います。ビルド途中のファイルは専用一時ディレクトリを終了時に削除します。指定した出力先の IPA などは成果物として残るため、確認後に不要な `dist/` を削除してください。

## 参照

- [PDF復旧・OCR・ローカルAIの未実装方針](https://github.com/n624-dev/takupoke-win/blob/codex/pdf-local-recovery/documentation/pdf-recovery-pending-policy.md)
- [OCR・PDF精度改善の未実装参考候補と色比較の条件](https://github.com/n624-dev/takupoke-win/blob/codex/pdf-local-recovery/documentation/ocr-improvement-reference.md)。参考案は今すぐ全項目を実装する指示ではない。実装できた項目は参考一覧から削除する。OCR・AIの推論は端末内のみとし、学校資料・画像・OCR文字・Prompt・結果を外部へ送信しない。モデル取得通信を資料解析から分離し、Private Cloud Computeを含むリモート推論へ切り替えない。

- [GitHub の macOS runner 構成](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [GitHub のコミットメール設定](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)
- [actionlint](https://github.com/rhysd/actionlint)

### OCRの全ページ取得証明

OCR復旧では、認識できたセル内だけでなく、全ページの非罫線インクが取得文字の箱で覆われることを確認します。クラス行全体やセル外注記の未取得を、残りの文字だけで成功扱いしません。非OCR経路の条件、既存の32M上限・中止処理、認識信頼度のしきい値は維持します。

取得成功後にアプリ内部の `ocrCoverageProof` version 1へページ番号・元グレースケール寸法・SHA256を記録します。モデル応答のSchema2は変更せず、受理時のscope fingerprintが文字・箱・順序・セル証明と取得証明全体を結び付けます。この証明は文字の正読率を保証しません。証明のない旧OCR監査はメタデータだけで移行・再利用せず、保存原文を削除せずに再取得が必要な状態として扱います。非OCRの合法な旧採用結果は従来どおりacceptedAtと確認履歴を保持して再検証できます。通常時間割Parser25で同一hashの旧解析も再検査し、イベントParser4・特殊時間割Parser22は維持します。
