# 独立架空資料の密度・文字色比較：実iOS Reader（Parser24）

密度の高い黒文字のラベルなし本体は、実Reader→Strict Parserで **680/680枠** の架空科目・教員・教室が一致した。年度2032・後期・17クラスも一致し、余分な枠は0。2件の濃い色variantはReaderが未対応として停止し、680枠の精度は未評価。読める黒文字controlは復旧に失敗した。

このgeneratorと実測では、学校原本を入力・参照資料・CI・公開物として使用していない。提供原本の閲覧は担当者の非公開ローカルでの構造理解に限り、workspace上の作業用コピーは削除済み。科目・教員・教室・対応配列は継承していない。

実行は [37227358109](https://github.com/n624-dev/takupoke-ios/actions/runs/37227358109)、native helper `1f222ad3b6b1e8cc5dd24fabceab03fc5211ee6d`、30本体sourceは前cohortと同じimmutable `2569b7a`。Apple iOS27 SDKでコンパイルし、iPhone14型iOS27シミュレーターで別の固定4件を各1回だけ測定した。旧wide6・baseline・OCR・モデル呼出しは0。補助テスト22件と所有一時ファイルの後片付けは成功した。

| 独立variant | 実Reader・後続経路 | 680枠照合 |
|---|---|---|
| 密度・黒文字・ラベルなし | 完了→Strict成功 | 680/680、年度・学期・クラス一致、余分0 |
| 密度・濃い色・ラベルなし | `unsupported.characterMapping`、Reader未完了 | 未評価、Analysisなし |
| 密度・黒文字・ラベル付きcontrol | 完了→Strict `unsupported.lessonLines`→Builder `ambiguous.fragmentAlignment` | 未評価、Analysisなし、読めるcontrolの復旧失敗 |
| 密度・濃い色・control | `unsupported.characterMapping`、Reader未完了 | 未評価、Analysisなし |

全4件は1450×990の1ページで、17クラス×5曜日×8時限。coordinateと幅32pt・行高47ptは元のwide資料と独立に指定した。680枠の内容は同じ完全架空seedから生成し、黒/濃い色の文字分割・配置は同じ。濃い色は別seed704893が選んだ12文字だけのRGB `(0.02,0.04,0.12)`。既存の色・可視性guardを緩めていない。

返ったcodeは2件とも `unsupported.characterMapping` であり、色variantの未対応結果として記録する。これだけでAPIや処理内部の詳細な失敗原因を確定せず、色variantをliteral精度0とも正常成功とも数えない。部分captureからcomplete/EMPTY/formalへ昇格していない。黒controlは読める比較用資料での復旧失敗であり、不正入力の正しい拒否として合格に数えない。

黒本体は8750 glyph・1094 rule、実operator21882/paint-work352949。黒controlは12647/1094、operator29676/work525709。いずれも元の1,000,000 work上限の範囲内で、診断省略は全件0。黒2件のcaptureは `readerCompleted=true`/`complete=true`、全page state complete、実layout数・sourcePDFページ数と一致する。濃い色2件はReader未完了のまま保持した。実行limit/IO/cancellation0。

native phaseは76.822秒、個別4件のacquire合計は約2.654秒。残りにはspawn・初期化等が含まれ、bootはphase前で個別時間を測定していない。

`fixed/stdout` 3428419 bytes、`fixed/stderr` 95 bytes、`metadata/execution` 50770 bytesの**正確3ストリーム**をGitHub完全ログから4096-byte番号付きchunk・元byte数・SHAで復元した。raw gzip-base64 envelopeは元bytesを保存し、full SHAを検証する。短summaryやnative実行成功だけをliteral成功と数えていない。

`expected.json` は元wideとbyte同一の `efdcb749420be6b000bf172f41102fd6c98b4e6b600dd22d07b41168788ce191`。Reader/Parser/Builder/Rules/Validatorへ期待値・role・evidence・blank指定を渡さず、実Analysisが返った後だけ680枠・年度・学期・クラス・追加枠を照合した。`analyze.py` で保存rawから独立に再計算できる。

```bash
python3 -B analyze.py . /tmp/unique-owned-density-derived.json
```

この証拠は生成vector資料・シミュレーター・in-memory Analysisまで。実iPhone、利用者原本、画像PDF、保存・手動採用UI、画像OCRのEMPTY、追加AIモデルの品質合格は確認していない。PDF・font・PNGバイナリはGitに含めていない。generatorと公開font/SHAは `tools/independent-wide-timetable`、この4PDFの固定SHAは `density-artifact-pins.json` にある。元wide6結果は別folderに保持し、このcohortへ混ぜていない。今回の追加実測はこの4件で終了し、反復測定やguard変更は行っていない。
