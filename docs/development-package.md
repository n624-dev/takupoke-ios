# 検証済み iOS 開発版の手動配布

既存 `ios-release.yml` を `codex/pdf-local-recovery` で手動実行したときだけ、iPhone 向け未署名 IPA と `release.json` を `takupoke-ios-development-<full SHA>` という短期 artifact に保存します。保持期間は3日です。正式な main の配布と AltStore Source は変更しません。

同じコミット・実行ID・最新の再実行回について、Distribution・Native PDF/recovery・iPhone build と iOS26/27 UI A/B の全7ジョブが成功してから、以下の CLI で取得できます。UI A に追加された手動補助のテストも成功条件に含まれます。artifact の ID・コミット・期限・サイズを確認し、IPA 内の版番号・build・コミット・iPhoneOS・未署名状態・公開診断除外等を既存 `inspect_ipa` で検証します。CI 成功は実機動作や学校の実資料の復旧精度を保証しません。

```sh
python3 -B tools/development_release.py \
  --run-id <成功した実行ID> --commit <その40文字SHA> \
  --output <存在しない出力ディレクトリ>
```

GitHub の既存認証を使用します。上記は読み取りとローカル出力だけです。公開時は同じコマンドに `--publish` を追加します。出力は `takupoke.ipa`、`SHA256SUMS`、`INSTALL.txt` の3点だけで、署名・導入方法は `INSTALL.txt` に記載します。出力ディレクトリは呼出側が管理し、確認後に不要になった自分の出力だけを削除してください。

公開 CLI は一意な `dev-ios-<run ID>-<attempt>-<short SHA>` の新しい draft を作り、3添付のバイトを再取得して照合し、prerelease・`make_latest=false` で公開します。公開後にも添付を再取得して照合します。同じタグや既存 release があれば停止し、既存配布物を置換しません。失敗時に撤収できるのは作成応答の ID で所有を確認できる未公開 draft だけです。公開後の障害で公開済み release を自動削除しません。AltStore Source・正式な latest・main のファイルは更新しません。
