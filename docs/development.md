# 開発環境と検証手順

[README に戻る](../README.md)

## 必要な環境

| 作業 | 環境・ツール |
| --- | --- |
| ソース編集、Git 操作 | Linux または Windows、Git、任意のエディター |
| 配布処理のローカルテスト | Python 3.11 以降、標準ライブラリのみ |
| ワークフローの追加チェック | 任意で actionlint |
| iOS ビルド | Actions の `macos-15` と Xcode 26.3 |
| 実機導入・更新 | iOS 16.0 以降の iPhone、AltStore Classic。Windows の AltServer を使う経路を基準とする |

このデバイスの開発環境は Linux です。Linux / Windows では SwiftUI のビルドを行わず、配布スクリプトのテストとソース編集を行います。XcodeGen、CocoaPodsは使用していません。XLSX展開にはZIPFoundation 0.9.20（コミット固定）をSwift Packageとして使用します。

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

この Linux デバイスには Swift 6.1.2 を公式署名を確認して `/home/ubuntu/.local/share/swift-6.1.2` に導入しました。Swift を PATH に追加した環境では以下を実行できます。このデバイスで一時的に PATH を指定する場合は次のとおりです。

```sh
PATH="/home/ubuntu/.local/share/swift-6.1.2/usr/bin:$PATH" bash tools/test-materials.sh
```

コンパイラーのモジュールキャッシュ・実行ファイル・入力と保存データは専用の一時ディレクトリに置き、終了時に削除します。Swift の配布アーカイブもインストール後に削除済みです。Windows への Swift 導入は必須ではありません。

学校サイトの本番URLをテスト・疎通確認に使いません。HEADや条件付きGETも禁止です。通信テストのURLProtocolはすべてのリクエストを捕捉し、`example.invalid`以外を拒否します。学校サーバーへの定期確認・負荷試験はCIへ追加しないでください。実装上必要な調査としての取得は利用者から許可されていますが、必要な回数に限定し、実資料をリポジトリ・CIへ持ち込みません。

## SwiftのXLSX解析テスト

`bash tools/test-parsing.sh` はSwift Package経由で、本体のXLSX読み取り・正規化・PDFの位置情報解析・保存処理を検証します。GitHubから固定したZIPFoundationを取得しますが、学校サイトや学校資料にはアクセスしません。教師名・科目名を含め、テスト入力・期待結果は架空です。

LinuxではSwiftに加えてzlibの開発ファイルが必要です。一般的なUbuntu環境では `zlib1g-dev` と `pkg-config` を導入してください。このデバイスでは管理者権限を使えなかったため、Ubuntu配布のzlib開発パッケージをユーザー領域に展開し、既存のzlibランタイムへリンクしました。pkg-configは未導入です。次の指定で実行できます。

```sh
TKPK_ZLIB_PREFIX=/home/ubuntu/.local/share/takupoke-build-deps \
PATH="/home/ubuntu/.local/share/swift-6.1.2/usr/bin:$PATH" bash tools/test-parsing.sh
```

macOS CIでは標準のCompressionを使うため、この追加導入は不要です。解析テストもIPA作成前に実行し、失敗時は配布を止めます。パッケージcheckout、ビルド、モジュールキャッシュ、架空XLSXは専用一時ディレクトリにまとめ、終了時に削除します。SwiftPMの共有依存キャッシュは無効にします。通常の `swift test` を直接実行すると既定のキャッシュ・`.build`が残るため、このスクリプトを使ってください。

Xcode側も依存のcheckout・キャッシュをビルド用一時ディレクトリへ指定し、repository cacheを無効にしています。Actions cache・artifactの保存は追加していません。`Package.swift`、Xcodeプロジェクト、2か所の `Package.resolved` は同じコミットに揃えます。

## ファイルを変更するとき

- SwiftUI 画面は `Takupoke/` に追加する。新しい Swift ファイルは Xcode プロジェクトの Sources にも登録する。
- Bundle ID と最低 iOS は `distribution/config.json` と Xcode の設定を一致させる。導入済みアプリの更新を維持するため、Bundle ID は安易に変更しない。
- バージョンの major / minor は `distribution/config.json` の `versionPrefix` で管理する。patch と build は CI が付与する。
- 権限、拡張機能、署名設定を追加するときは、Source の `appPermissions` と IPA 検証処理も更新する。初期版は追加権限なしを前提としている。
- 配布や機能の挙動を変えたら README と関連手順も更新する。

アイコンはプロジェクト独自の幾何学図形です。再生成は `python3 -B tools/make-icon.py`（Windows は `py -3 -B tools/make-icon.py`）で行います。追加パッケージや一時画像は不要です。

## push と CI

`main` への push でテスト・iOS ビルド・配布を実行します。Pull Request はテスト・ビルドのみで公開しません。Actions の手動実行も可能ですが、公開するのはこのリポジトリの `main` だけです。

CI の監視はメンテナーが行います。開発エージェントは push 後の待機・継続監視・ポーリングを行いません。失敗報告や修正依頼を受けた場合は、その失敗済み実行のログを調査して修正します。取得ログをローカルに溜めず、共有する情報から個人情報を除きます。修正後の CI もメンテナーが確認します。

## Mac が利用できる場合の任意のビルド

Mac の所有は必須ではありません。Xcode 26.3 を利用できる場合のみ、次のようにローカルビルドできます。

```sh
export TKPK_VERSION=0.1.1
export TKPK_BUILD=1.1
export TKPK_COMMIT="$(git rev-parse HEAD)"
bash tools/build-ios.sh ./dist
```

これは動作検証用です。配布は Actions から行います。ビルド途中のファイルは専用一時ディレクトリを終了時に削除します。指定した出力先の IPA などは成果物として残るため、確認後に不要な `dist/` を削除してください。

## 参照

- [GitHub の macOS runner 構成](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md)
- [GitHub のコミットメール設定](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)
- [actionlint](https://github.com/rhysd/actionlint)

PDFの公開テストは文字・罫線を架空の位置に配置して生成します。macOSではPDFKitによる架空PDFの読み取りと回転もテストし、実資料・学校サイトへはアクセスしません。Liquid Glass対応のためActionsではXcode 26.3を指定しています。
