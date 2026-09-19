# 開発環境と検証手順

[README に戻る](../README.md)

## 必要な環境

| 作業 | 環境・ツール |
| --- | --- |
| ソース編集、Git 操作 | Linux または Windows、Git、任意のエディター |
| 配布処理のローカルテスト | Python 3.11 以降、標準ライブラリのみ |
| ワークフローの追加チェック | 任意で actionlint |
| iOS ビルド | Actions の `macos-15` と Xcode 16.4 |
| 実機導入・更新 | iOS 16.0 以降の iPhone、AltStore Classic。Windows の AltServer を使う経路を基準とする |

このデバイスの開発環境は Linux です。Linux / Windows では SwiftUI のビルドを行わず、配布スクリプトのテストとソース編集を行います。XcodeGen、CocoaPods、サードパーティー Swift パッケージは使用していません。

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
git diff --check
```

Windows PowerShell:

```powershell
py -3 -B -m unittest discover -s tests -v
git diff --check
```

Windows でシェルスクリプトを変更した場合は Git Bash で `bash -n tools/build-ios.sh` も実行します。`actionlint` がある環境ではリポジトリのルートで `actionlint` を実行します。

テストは架空の IPA を OS の一時ディレクトリに作成し、正常終了・テスト失敗のどちらでも後片付けします。`-B` は Python のバイトコードキャッシュ作成を抑止します。これらのテストは実際の SwiftUI ビルドや AltStore インストールの代わりにはなりません。

## ファイルを変更するとき

- SwiftUI 画面は `Takupoke/` に追加する。新しい Swift ファイルは Xcode プロジェクトの Sources にも登録する。
- Bundle ID と最低 iOS は `distribution/config.json` と Xcode の設定を一致させる。導入済みアプリの更新を維持するため、Bundle ID は安易に変更しない。
- バージョンの major / minor は `distribution/config.json` の `versionPrefix` で管理する。patch と build は CI が付与する。
- 権限、拡張機能、署名設定を追加するときは、Source の `appPermissions` と IPA 検証処理も更新する。初期版は追加権限なしを前提としている。
- 配布や機能の挙動を変えたら README と関連手順も更新する。

アイコンはプロジェクト独自の幾何学図形です。再生成は `python3 -B tools/make-icon.py`（Windows は `py -3 -B tools/make-icon.py`）で行います。追加パッケージや一時画像は不要です。

## push と CI

`main` への push でテスト・iOS ビルド・配布を実行します。Pull Request はテスト・ビルドのみで公開しません。Actions の手動実行も可能ですが、公開するのはこのリポジトリの `main` だけです。

CI の監視はメンテナーが行います。開発エージェントは、別の指示がない限り push 後の実行状況・ログ取得やポーリングを行いません。失敗時は個人情報を除いた該当箇所のログをもとに修正します。

## Mac が利用できる場合の任意のビルド

Mac の所有は必須ではありません。Xcode 16.4 を利用できる場合のみ、次のようにローカルビルドできます。

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
