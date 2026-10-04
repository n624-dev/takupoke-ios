# 独立架空wide資料の実iOS Reader検証（Parser24）

原版のラベルなし本体と、未使用フォント選択だけを変えた診断版は、実iOS Reader→Strict Parserでそれぞれ **680/680枠** の架空科目・教員・教室が一致した。年度2032・後期・17クラスも一致し、余分な枠は0。このgeneratorと実測では、学校原本を入力・参照資料・CI・公開物として使用していない。提供原本の閲覧は担当者の非公開ローカルでの構造理解に限り、workspace上の作業用コピーは削除済み。科目・教員・教室・対応配列は継承していない。

実行は [37225883970](https://github.com/n624-dev/takupoke-ios/actions/runs/37225883970)、native helper `3526db360a8de06900fd4daf4d6e25288e3dd0e8`、本体ソース `2569b7a`。Apple iOS27 SDKで30ファイルをコンパイルし、iPhone14型のiOS27シミュレーターで固定6件を各1回だけ測定した。旧baseline・密度variant・OCR・モデルの呼出しは0。補助テスト20件と所有一時ファイルの後片付けは成功した。

| 架空PDF | 実Reader | 実際の経路・結果 | 680枠照合 |
|---|---|---|---|
| 原版ラベルなし本体 | 完了、8749 glyph・1094 rule | Strict成功 | 680/680、年度・学期・クラス一致、余分0 |
| 未使用fontを外した本体 | 完了、8749・1094 | Strict成功 | 同上 |
| 原版ラベル付きcontrol | 完了、12646・1094 | Strict `unsupported.lessonLines`→Builder `ambiguous.parallelLessons` | 未評価、Analysisなし |
| control診断版 | 完了、12646・1094 | 同上 | 未評価、Analysisなし |
| 不一致の並記負例 | 完了、8741・1094 | StrictとBuilderの双方が `ambiguous.parallelLessons` | 未評価、Analysisなし |
| 未対応文字の負例 | 未完了 | Reader `unsupported.characterMapping` | 未評価、部分captureを昇格しない |

全6件は1ページの独立生成PDF。`independent-page-counts.json` は元の固定SHAを再確認した公開PyMuPDFによる事後ページ数照合で、native入力ではない。実Readerが返った5件のcaptureは `readerCompleted=true`、`complete=true`、全page state completeであり、返ったlayoutの数と一致した。

同じ1,000,000 paint-work上限を維持した本体の実測は281679、controlは465477、不一致負例は280383。`.paths` の実operator数は順に5637、5747、5637。診断の省略は全件0。index導入でこの独立入力のReaderが完了した証拠であり、上限を拡大した結果ではない。以前のParser22 cohortの部分capture・未評価結果は別folderに保持している。

native phase全体は130.565秒、6件のacquire時間合計は約27.894秒。残りにはspawn・初期化等が含まれ、bootはphaseの前に実行された。個別boot所要時間はこのreceiptでは計測していない。

`fixed/stdout`（6702446 bytes）、`fixed/stderr`（95 bytes）、`metadata/execution`（47556 bytes）の**正確3ストリーム**をGitHubの完全ログから番号付き4096-byte chunks・元byte数・SHAで復元した。raw envelopeは元byte列をgzip-base64で保存し、decoderで全byteとSHAを確認する。短summaryだけでは照合成功と数えていない。

`expected.json` のSHAは `efdcb749420be6b000bf172f41102fd6c98b4e6b600dd22d07b41168788ce191`。値は完全に架空のgeneratorで独立に作り、Reader・Parser・Builder・Rules・Validatorへ渡していない。実Analysisが返った後だけassertionに使い、portable `analyze.py` が全680 literalと年度・学期・クラス・追加枠を事後に再計算する。

```bash
python3 -B analyze.py . /tmp/unique-owned-derived-evidence.json
```

本体成功とcontrolの未対応拒否は別の結果である。control2件は読める比較用資料の復旧失敗であり、負例2件の正しい拒否と区別する。空欄の期待枠は完全Reader/Strict成功後の授業不在を比較しており、画像OCRでのEMPTY証明や追加AIモデルの品質合格ではない。この実測はシミュレーター・生成vector資料・in-memory Analysisまでで、実iPhone、ユーザー原本、画像PDF、利用者の保存・手動採用UIの確認は含まない。不一致のAnalysis返却0、実行limit/IO/cancellation0だが、全形式の品質合格は主張しない。

PDF・font・PNGのバイナリはGitに含めていない。generator、public font pin、PDF SHAはsource receiptと既存 `tools/independent-wide-timetable` にある。生のfixture本文とlayoutの公開は完全架空資料に限定する。
