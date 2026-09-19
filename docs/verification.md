# 検証記録

[README に戻る](../README.md)

## 配布基盤の初期実装

ローカルの Linux / Python 3.12 で以下を確認しました。

- 架空 IPA と Source の version / build・Bundle ID・サイズ・ダウンロード URL の整合。
- 不一致のメタデータ、シミュレーター向け IPA、未申告権限、署名プロファイル、余計な公開ファイルの拒否。
- ファイル改変の検出、アップロード・照合失敗時の公開防止。
- 古い版や最新の `main` ではないコミットによる配布の巻き戻り防止。
- PR からの公開処理の拒否。
- actionlint によるワークフロー静的検証、Bash 構文確認、Xcode プロジェクトの OpenStep 形式の読み取り。

iOS SDK によるコンパイルはローカルでは実施していません。テストの IPA は実行できない架空の ZIP であり、実機検証の代わりにはなりません。

## 初回 CI の失敗調査

ユーザーからの失敗報告を受け、[実行 35430150981](https://github.com/n624-dev/takupoke-ios/actions/runs/35430150981) のログを確認しました。対象コミットは `ac411d2` です。

- 配布テスト、iOS ビルド、IPA と Source の生成は成功しました。
- `Verify uploads and publish together` で、draft Release を `/releases/tags/{tag}` から取得しようとして HTTP 404 になりました。
- 認証済みの Release 一覧から対象の ID を取得し、`/releases/{release_id}` で draft と添付ファイルを確認するよう修正しました。
- タグ API が draft に対して 404 を返す条件と、対象 draft が見つからない場合の回帰テストを追加しました。
- 修正後のローカルテスト19件が通過しました。実際の失敗時の draft も ID で取得でき、CI が生成した IPA・Source・アイコン・チェックサムの検証が通りました。取得物は一時ディレクトリから削除済みで、Release 自体は変更していません。

API の取得対象は [GitHub Releases API の仕様](https://docs.github.com/en/rest/releases/releases#get-a-release-by-tag-name) に基づきます。修正後の結果は次節に記載します。

## 初回導入・実機起動の確認（2026-09-19）

利用者から、修正後の Actions 成功と、AltStore Classic で初回導入したアプリが実機で動作したとの報告を受けました。開発エージェントによる CI の継続監視は行っていません。

導入途中に `AltServer could not find this device` が表示されましたが、利用者が接続し直すことで解消しました。アプリ側の変更は行っていません。

端末モデル、iOS / AltStore / AltServer のバージョン、インストール済みの version / build は未記録です。この記録更新を push して次の版を配布し、Source 経由の更新と確認メモの保持を検証します。文書のみの変更でも CI が新しい version / build を付与するため、更新経路を確認できます。

## CI・実機での確認待ち

CI はメンテナーが監視します。開発エージェントはこの実装の push 後の Actions を監視しません。

- [x] Actions の checks / release（ビルド・公開）が成功する（利用者報告）。
- [ ] Release の IPA・Source・アイコン・メタデータをダウンロードできる。
- [x] 固定 URL の Source を AltStore Classic に追加できる（案内した導入手順に対する利用者の成功報告）。
- [x] Source から初回導入し、アプリが起動する（利用者報告）。
- [ ] アプリ内と Release の version / build・コミットが一致する。
- [ ] 確認メモを入力後、次の版へ Source から更新できる。
- [ ] 更新後に確認メモが保持される。
- [ ] Windows からも編集・push して同じ更新経路を使える。
- [ ] 実際の CI で公開準備が失敗した場合、前の配布が維持される。

## 実機確認テンプレート

個人名、メールアドレス、Apple ID、シリアル番号や UDID は記録しません。

```text
確認日:
iPhone モデル / iOS バージョン:
Windows / AltStore Classic / AltServer バージョン:
対象 Release:
初回導入: 成功 / 失敗
起動・バージョン表示: 成功 / 失敗
更新前の version / build:
更新後の version / build:
Source 経由の更新: 成功 / 失敗
確認メモの保持: 成功 / 失敗
エラー・制約（個人情報を除く）:
```
