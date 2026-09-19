# AltStore Classic による導入・更新と配布の仕組み

[README に戻る](../README.md)

この文書は実装した配布経路の手順です。公開処理の修正後に、利用者から Actions 成功と初回導入・実機起動の報告を受けました。その後、案内した Source 更新の手順に対し、更新後も確認メモが残るとの報告を受けました。詳細は [検証記録](verification.md) を参照してください。

## 配布先

| 項目 | 値 |
| --- | --- |
| リポジトリ | [n624-dev/takupoke-ios](https://github.com/n624-dev/takupoke-ios) |
| 公開成果物 | [GitHub Releases](https://github.com/n624-dev/takupoke-ios/releases) |
| Source | `https://github.com/n624-dev/takupoke-ios/releases/latest/download/altstore-source.json` |
| 元の Bundle ID | `io.github.n624dev.takupoke` |
| 対象端末 | iOS 16.0 以降の iPhone |
| 配布方式 | AltStore Classic が導入時に署名する IPA |

GitHub Pages や独自サーバーの設定は不要です。

## Windows と iPhone の準備

1. [AltStore 公式の Windows 導入手順](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) に従い、Windows に AltServer を準備し、iPhone に AltStore Classic を導入します。関連する Apple ソフトウェアや接続設定は公式手順に合わせます。
2. AltStore / AltServer 側で必要なサインインと端末側の設定を済ませます。Apple ID・パスワード・証明書を GitHub や CI に登録しないでください。
3. AltStore Classic 自体がアプリをインストールできる状態にします。接続や署名の問題は [公式トラブルシューティング](https://faq.altstore.io/altstore-classic/troubleshooting-guide) を参照します。

Windows の AltServer を使う経路を手順の基準とします。AltStore 自体の署名更新と、たくポケの新しいバージョンへのアップデートは別の操作です。

## 初回導入

1. メンテナーが Actions の成功と、Release に `takupoke.ipa`・`altstore-source.json`・`icon.png`・`release.json` が揃っていることを確認します。
2. iPhone の AltStore Classic の Sources 画面で Source を追加し、上記の固定 URL を入力します。
3. Source 内の「たくポケ」をインストールします。
4. アプリを開き、バージョン・ビルド・コミットが Release と一致することを確認します。
5. 「更新を確かめる」の欄に、個人情報を含まない短いメモを入力します。

初回導入の確認には個別 IPA の手動インポートだけでなく、Source からの導入が必要です。

## アップデート確認

1. `main` に次の変更を push します。コードを変更せず配布経路だけ再確認する場合は、`main` を対象に Actions の `workflow_dispatch` を新規実行できます。
2. メンテナーが新しい Release と Source の生成を確認します。
3. AltStore Classic で Source / 更新一覧を更新し、新しいバージョンをインストールします。
4. アプリ内のバージョン・ビルドが新しくなり、メモが保持されることを確認します。確認中にアプリを削除しないでください。
5. iOS / AltStore / AltServer のバージョンと結果を [検証記録](verification.md) に残します。

この経路での更新と確認メモ保持について利用者から成功報告を受け、ロードマップ①の必須の完了条件を満たしました。正確な version / build の照合など、追加の確認項目は検証記録に残しています。

## 自動化の構成

ワークフローは [ios-release.yml](../.github/workflows/ios-release.yml) です。

1. **checks**：架空データで配布スクリプトをテスト。
2. **release ジョブ内のビルド**：macOS / Xcode で iPhone 向け Release ビルドを行い、`Payload/Takupoke.app` を IPA 化。署名用 Secrets は不要。
3. **Source 生成**：IPA の Info.plist、対象 OS、実行ファイル、サイズを検査して Source を生成。不一致があれば停止。
4. **同じ release ジョブ内の公開**：Release を draft として作成して4個の成果物をアップロード。再ダウンロードした内容の SHA-256 が一致した後に公開し、Latest を切り替え。

PR と配布対象外のブランチは、読み取り権限だけの `build-check` ジョブでビルドします。ジョブ間の IPA 受け渡し用 artifact は作成しません。

Source は IPA と同じ Release を参照します。IPA・アイコンの URL には固有のタグが入り、後の配布で中身を上書きしません。固定 Source URL だけが Latest に追従します。

初期実装の Source は最新の1版を掲載します。過去の IPA と各時点の Source は各 Release に残ります。major / minor や最低 OS の変更時には、旧端末向けの履歴掲載方針を改めて検討します。

## バージョン・build 番号

`distribution/config.json` の `versionPrefix` が `0.1`、Actions の run number が `12`、run attempt が `1` の例です。

| 項目 | 例 |
| --- | --- |
| CFBundleShortVersionString | `0.1.12` |
| CFBundleVersion | `12.1` |
| Release タグ | `v0.1.12-build.12.1` |
| 新しいワークフロー実行 | `0.1.13` / `13.1` |
| 同じ実行の全ジョブ再実行 | `0.1.12` / `12.2` |

番号は CI で生成し、IPA と Source の両方に反映します。番号更新の Git コミットは作りません。PR や失敗により欠番が発生することがあります。現在は run number 1〜9999、attempt 1〜99 に限定しています。ワークフロー名の変更や番号上限への到達時は採番方針を見直してください。

## 失敗・再実行・復旧

新しい draft は作成APIの応答から Release ID を受け取り、そのIDで取得・添付・照合・公開します。作成直後の draft を一覧やタグで再検索しません。添付ファイルも asset ID で読み戻して SHA-256 を照合します。一覧は処理開始時の既存 Release 確認に使用します。APIや照合の失敗時は公開せず停止します。

| 状況 | 動作・対応 |
| --- | --- |
| テスト・ビルド・検証が失敗 | 新しい Release は公開されず、前の Source を維持 |
| アップロード・照合に失敗 | draft のまま停止し、前の Latest は変更しない |
| release ジョブを再実行 | 同じジョブ内で再ビルドし、新しい build 番号を付与。同じ版の既存 draft に再送する場合も、公開済みの成果物は置き換えない |
| 新しい `main` が先に存在 | 古いコミットの実行は公開を見送る |
| 最新より古い番号の再実行 | 最新の配布を巻き戻さず公開を見送る |
| Source URL が 404 | 初回公開未完了、Latest 未設定、または該当添付がない状態を確認 |
| Xcode が見つからない | runner の提供バージョンと `DEVELOPER_DIR` を照合 |
| Source は見えるが導入できない | AltStore のエラー、署名・接続、iOS、IPA と Source の整合を確認 |
| 更新が表示されない | Source を再取得し、インストール済みと公開版の version / build を比較 |

最終 API 呼び出しで通信が切れた場合は公開できている可能性もあるため、メンテナーが Release の状態を確認します。再実行時は同じ版が公開済みならスキップします。

公開後の不具合は、修正を push して新しい番号で配布するのが基本です。緊急時は GitHub で前の正常な Release を Latest に戻せますが、端末のアプリが自動でダウングレードされるわけではありません。公開済み IPA の差し替えは行いません。

## キャッシュと一時保存

Actions のビルド・依存関係キャッシュと保存用 artifact は使用しません。`actions/cache`、`upload-artifact`、`download-artifact` は導入せず、Python セットアップの依存キャッシュも有効にしません。IPA は同じ macOS ジョブ内でビルドから公開まで完結し、終了時に runner 内の成果物を削除します。

GitHub Releases の添付は Actions のキャッシュ・artifact と別の配布用保存です。正式な Release を件数制限で自動削除することはしません。不要な失敗 draft は公開されず、正常な Source からも参照されません。保存の区分は [Actions のストレージ](https://docs.github.com/en/billing/concepts/product-billing/github-actions) と [Releases の説明](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) を参照してください。

公開内容の照合では、その実行でアップロードした成果物を取得します。IPA は版ごとに固有の URL を使い、同一 URL の中身を差し替えません。

GitHub 側の配信キャッシュをこのリポジトリから完全に無効化することは保証しません。固定 Source URL の反映が遅れる場合は、Release の Source と AltStore の表示を照合し、時間をおいて再取得します。

ビルド用一時ファイル・照合用ダウンロードも処理終了時に削除します。Actions の実行ログは GitHub の保持期限に従います。キャッシュや artifact の使用量を手動で整理する運用は設けません。

## 公式資料

- [AltStore Source の仕様](https://faq.altstore.io/developers/make-a-source)
- [AltStore のアプリ更新判定](https://faq.altstore.io/developers/updating-apps)
- [GitHub CLI の Release 公開・Latest 設定](https://cli.github.com/manual/gh_release_edit)
