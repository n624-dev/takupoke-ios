# 従来型Visionと画素反復の認識器比較

新APIのaccurate／言語補正変更だけの再試行は、過去のiOS研究で改善していない。
この別比較では、従来型VNRecognizeTextRequest revision3のaccurate・ja/en・補正OFFへ、
元画像と各画素を正確に4×4回反復した画像を渡す。文字・罫線・元画素を生成し直さず、
拡大後CGImageの全RGBA画素を読み戻して原画素との対応を検査する。
新しい詳細を復元したという主張や、変更していないV6との同一入力性能比較ではない。

元の独立架空認識器screenの144項目、既使用2字体、generatorの物理枠からの観測墨+2pxを用いる。
これは認識器の条件探索で、実際の文書取得・全文書・未見評価ではない。
全288回の呼出し後だけ、別Python比較器がoracleを読む。
原native候補・信頼度・文字枠とobservation枠、原／入力RGBA SHA、拡大倍率を保持する。
拡大画像のnative正規化枠と元画素への変換枠は別々に記録する。
他エンジンのCTCやconfidenceへ変換しない。

原画像の小ささによるAPIエラーも想定される。エラーを空認識へ置換せず、両条件の全呼出しを
記録した後に失敗終了する。missing／split／元枠外は未一致に残す。
設定・言語の未対応は全認識前の1回のpreflightで停止する。
候補の文字枠APIの失敗も別に保持し、成功済み原文字・confidence・observationを消さず失敗終了する。
文字一致・自身のnative0.85を通る誤読・改善／悪化を別に数え、しきい値を下げない。
code lookup／名称対応表・正解による候補選択は使わない。

```sh
bash tools/ocr-legacy-line-screen/run.sh
```

Mac SDK26の探索で、物理iPhone・iOS Simulator・正式Builder／Validator・本体採用は未確認。
アプリ208ファイル・Strictと全入口／経路・Package・Vendor・公開版401.1を変更しない。
新規GPT-6.1 Sol／Highのコード差分レビュー後にだけActionsを開始する。
所有一時資料と実行物は成功／失敗時に回収し、cache／artifact／Releaseを作らない。
