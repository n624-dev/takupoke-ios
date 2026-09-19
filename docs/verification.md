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

## CI・実機での確認待ち

CI はメンテナーが監視します。開発エージェントはこの実装の push 後の Actions を監視しません。

- [ ] Actions の checks / release（ビルド・公開）が成功する。
- [ ] Release の IPA・Source・アイコン・メタデータをダウンロードできる。
- [ ] 固定 URL の Source を AltStore Classic に追加できる。
- [ ] Source から初回導入し、アプリが起動する。
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
