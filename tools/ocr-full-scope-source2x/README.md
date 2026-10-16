# 全17クラス・原PDF2倍描画の固定比較

`ocr-document-qualification`の固定済み独立架空6資料を使用する。
通常17クラス×5曜日×8時限、試験17クラス×5日×6時限、返却17クラス×5日×8時限、
各3本文値で11220値・102クラス名。2字体は既使用で、未見評価とは呼ばない。
学校原本・名前差替え・追加学習は使用しない。

初回の両V6描画条件を要求する研究は、通常2成功・試験／返却4失敗だった。
その失敗とクラスの一意な実セル所属条件は変更しない。
この別研究は、以前の小規模比較で改善した原PDF2倍・4096px上限だけを候補入力とし、
全クラス・日・時限・役割を保持する。結果が出る前から合格とは扱わない。

既存の所有Packageコピーで同じ原PDFを取得する。元Visionは2048px上限で実際に1回、
ラスタ取得は2条件のまま。NNと候補比較だけをsource2x4096へ限定する。
元Visionの文字・信頼度・元座標は保持し、4096pxでVisionを動かしたとは主張しない。
原罫線／全墨／一意所属、原RGB SHA、V6原CTC、class EnglishV1の同長・piece0.85・
reject0.05・padding条件を変更しない。本文のASCII末尾候補は再実行しない。
認識側にはPDF・ID・kind・SHAだけを渡し、全NN完了後の別比較器だけがoracleを読む。

比較失敗前にも実取得geometryを出力し、原因調査に必要な観測を保持する。
終了時のallowlist付き数値noticeは公開GitHub annotationsから確認できる。
生ログ全原行をローカルで再構成した証明とは区別する。学校資料をこの研究へ投入しない。

```sh
TKPK_OCR_QUALIFICATION_CASE=f1-timetable bash tools/ocr-full-scope-source2x/run.sh
```

Apple環境・SDK26専用。6jobは失敗後も取消せず完了を確認する。
cache／artifactは作らず、所有一時領域は成功／失敗時に回収する。
本体208ファイル・Strictの実装と全入口／経路・Package・Vendor・配布を変更しない。
この比較の成功は、正式Builder／Validator、iOSでのPDF全取得、実資料、実機の合格ではない。
