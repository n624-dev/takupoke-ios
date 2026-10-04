# 汎用罫線 Recovery の原本対照検証

日ごとにページが分かれた架空時間割にも、元の物理罫線・印字・画素を使って Recovery を構成する経路を追加しました。既存経路が `unsupported/periodHeading` で終わった通常時間割だけを対象にします。Strict、Validator、授業数の意味条件、32M の作業上限、曖昧さ・限界・キャンセル時の終端は保持しています。フォールバックでも同じ作業予算を引き継ぎます。

対照資料は公開済みの独立した架空 PDF 2 件・計 10 ページです。元 PNG の RGBA は lossless に一致し、印字・独立の全 40 slot の期待値も変更していません。フォントから得た元の文字 box を使う取得後の source 対照で、両資料の全 40 slot・原文値を既存 Builder → Rules → Validator → formal conversion で検証しました。期待値を Builder の入力や探索条件に渡していません。実際の Vision 出力から得られた成功率ではありません。

欠落した曜日、重複ページ・slot、年学期の不一致、欠けた時限・閉じた罫線、隣セルに跨る文字、未知の物理行、OCR ページの未読 ink・空欄内 ink、作業上限・キャンセルを拒否する回帰を追加しました。OCR の担当・教室の空欄は元画素の独立した blank 証明を必要とします。モデルは呼びません。

実装ソースは [codex/pdf-local-recovery の 71d28af](https://github.com/n624-dev/takupoke-ios/commit/71d28af373535762e406ec370e8dfddfd25a0744)、実行は [CI 37207798028](https://github.com/n624-dev/takupoke-ios/actions/runs/37207798028) です。必要な 7 job はすべて成功しました。Linux Swift の最終対照は 317 tests / 0 failures、Apple の actual PDF・Recovery は 365 tests / 0 failures、iPhone SDK build は成功しました。画面テストは 51 件成功・予定の VoiceOver 1 件 skip・失敗 0、Picker UI は別途 3 件成功です。配布処理 58 テスト・共有プロンプト 7 テスト・厳密 fixture 30 件も通過しました。実ログの byte 数・SHA256・初回と再実行の区別は [checks.json](checks.json) に記録しています。

初回 iOS 27 UI A はビルド等約 16 分 40 秒と正常テストの累積がジョブ全体の 35 分上限に達し、11 件成功・12 件目実行中に中断しました。assertion failure は記録されていません。同じコミットのその 1 job のみを再実行し、13 件すべて成功しました。初回ログと結果も保持しています。他の 6 成功 job は再実行していません。テスト条件、対象、assertion、各テストの timeout は変更していません。

この検証は決定的な Recovery の入力・意味・安全性の証拠です。OCR の完全取得、追加 AI モデルの実用性や品質合格、実機 iPhone のメモリ・性能を証明しません。モデル catalog は有効化していません。
