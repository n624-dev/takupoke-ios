# OCR改善の検証記録

## 不採用：物理セルでの言語補正OFF

研究コミット `02c7ebd688a595dc41422f9d0b6df1b984992610`、Actions実行 `37647779556` は、下記の物理セル比較と同じ48領域をaccurate文字認識へ1回ずつ渡し、言語補正だけをOFFにしました。日本語・英語、自動言語検出ON、切り出し範囲・画素・認識レベルを維持し、前の条件は再実行していません。48組すべてで元画像と切り出しのSHA-256が一致し、位置は有限で領域内でした。48呼び出しは10.718秒で完了し、実行エラーはありませんでした。

| 元の文字サイズ | 原文一致（ON／OFF） | 正しい文字列で0.85以上（ON／OFF） | 誤読で0.85以上（ON／OFF） |
|---|---:|---:|---:|
| 24 px | 20/24 → 20/24 | 8 → 19 | 2 → 3 |
| 16 px | 21/24 → 21/24 | 9 → 18 | 0 → 1 |

全48領域で読み取った文字列は変わらず、誤読の修正も正しかった文字列の破壊も0件でした。正しい20件が信頼度を新たに満たした一方、誤った教室表記2件も信頼度を新たに満たしました。誤読は上位3候補にも正解がなく、信頼度の上昇を精度改善として数えません。この設定は本番へ採用せず、しきい値や採用基準も変更しません。

macOS 26.6.2のVisionによる本文の固定比較です。同じ内容の2サイズを独立した文書成功件数へ合算せず、iPhone実機・見出し・結合・並記・全文書復旧・追加モデル品質は未評価です。画像はメモリ内だけで扱い、ジョブ所有の実行ファイルと一時ログを終了時に削除しました。Actions artifactと学校原本は使っていません。


## 同じ表の物理セルを固定範囲で切り出す比較

研究コミット `40854f2f8d0da062d921087feaea57b2cdd9b719`、Actions実行 `37635555403` では、前の24種類の架空本文を描いた表から、罫線の内側2 pxを含めない物理セルを切り出しました。376 × 106 pxの48領域は拡大せず、文書認識とaccurate文字認識へ各1回渡しました。日本語・英語指定、自動言語検出ON、文字認識の言語補正ONを固定しました。96呼び出しは26.006秒で完了し、実行エラーは0件でした。

| 元の文字サイズ | 文書認識の原文一致 | 文字認識の原文一致 | 文書認識の誤読かつ信頼度0.85以上 | 文字認識の誤読かつ信頼度0.85以上 |
|---|---:|---:|---:|---:|
| 24 px | 20/24 | 20/24 | 3 | 2 |
| 16 px | 21/24 | 21/24 | 0 | 0 |

返された全行の位置は有限で切り出し内にあり、元のセルへ一意に対応しました。48個の切り出しの画素ハッシュは相互に異なり、両APIには同じ画素を渡しました。認識結果を誤ったセルへ割り当てたことや、同一画像の使い回しは、この比較の残る誤読の原因ではありません。

同じ表を全体で認識した固定出力と比べると、24 pxで1項目改善し、16 pxでは改善0項目、元々正しかった項目の破壊は両条件で0件でした。両APIには教室表記のO/0・I/1や教員名の文字の誤読が共通して残り、取得した上位3候補にも正解がありませんでした。API間の一致と高い信頼度だけでは正解を証明できません。

信頼度0.85以上の正しい項目は、24 pxの文書認識9件／文字認識8件、16 pxは各9件でした。正しいが信頼度を満たさない項目は各11件／12件、各12件でした。これはMac CIでのVision本文比較であり、iPhone実機の精度、見出し・結合・並記、文書全体の復旧成功や採用品質は未評価です。追加モデルの品質合格も出していません。画像はメモリ内に限定し、Actions artifactは作成していません。

## 未使用の架空表での言語設定・構造の比較

研究コミット `84e055bb4192b39ce81919ea5368c84aafecc02f`、Actions実行 `37633860319` では、調整に使っていない24種類の架空本文を罫線付き8行3列の表へ描きました。科目・教員・教室という項目名は画像に付けず、Hiragino Sansの24 px・16 pxを、文書認識の既定設定と日本語・英語指定／自動言語検出ONへ各1回渡しました。2画像・4呼び出しが7.917秒で完了しました。

| 文字サイズ | 既定の原文一致 | 日本語・英語指定の原文一致 | 指定条件で正しいが0.85未満 | 指定条件で原文不一致かつ0.85以上 |
| --- | ---: | ---: | ---: | ---: |
| 24 px | 11/24 | 19/24 | 9 | 3 |
| 16 px | 11/24 | 21/24 | 11 | 1 |

同じサイズの両条件で画素SHA-256は一致しました。原認識行を物理セルの位置へ割り当てて評価し、各条件で24行すべてが一意に対応しました。表はすべて1件・8行3列・24セルで、SDKの行列番号とセル領域の位置が整合していました。セル本文と原認識行の完全一致件数も等しく、文字が後処理で消えたという結果ではありません。指定条件は24 pxで8件、16 pxで10件の原文不一致を修正し、元々正しかった本文の破壊は0件でした。

ただし教室のO/0・I/1と架空教員名の誤読が残り、原文不一致のまま高信頼度になった項目もあります。正しい科目などの低信頼度も未解決です。両サイズを独立した文書成功件数として合算せず、この小さな表から正式な時間割全体の完全成功を主張しません。見出し・全17クラス・結合・並記・日付・授業時刻は未評価です。しきい値、正式採用、追加モデル配信は変更しません。

生成画像はメモリ内に限定し、実行ファイルと一時ログはジョブ終了時に削除しました。学校原本・Actions artifactは使っていません。

この記録の入力は独立して作成した架空資料だけです。利用者から預かった学校PDF、その画像、科目・教員・教室のコピーは使っていません。部分的な認識結果を文書全体の復旧成功や追加モデルの品質合格として数えません。未実装の方針は別の方針専用文書で管理します。

## 文書認識結果の取り出し

コミット `0349aa9307814f7c191414f37fe648047e3a7de9`、Actions実行 `37615424510` のiOS 26・27 UI Bで、画像だけの架空PDFを実際の `PDFRecoveryRecognition.acquire` に通しました。項目名を付けない2行3列の表です。

- 原認識結果の6文字列は6/6完全一致でした。
- 元の表1件と、アプリが保持した表1件が一致しました。各行・セルの本文、認識行数、行・列の結合範囲もSDKの元結果と照合しました。
- 取得した原認識行は6行で、取得情報の整合性検証を通りました。
- これはクラス・曜日・時限・本文の取り出しを調べる小さな取得テストです。正式な時間割全体の完全性、全17クラス、日付や授業時刻、モデル品質は未評価です。

## 不採用：日本語の強制と認識中の言語補正停止

コミット `10de1c9379fb7bb03bc2a7b70e0fadd55f3e0fb2`、Actions実行 `37620502590` で、macOS 26.6.2・Xcode 26.6のVisionを使い、別の架空表に固定した3条件を1回ずつ実行しました。iOSの上記入力とは別で、結果を合算していません。

| 設定 | 原文の完全一致 | 結果 |
| --- | ---: | --- |
| 既定の文書認識 | 5/6 | 英語が設定されていましたが、言語の自動検出が有効でした |
| 日本語・英語を指定、自動検出OFF | 4/6 | 架空教員名の末尾を誤読しました |
| 上記に加え、認識中の言語補正OFF | 4/6 | 末尾の誤読を維持したまま、その文字列の信頼度が約0.927になりました |

3条件とも表を1件認識しました。共通する原文の不一致にはクラス名のアンダースコアが空白になった例があり、原文一致とクラス名の意味解析は別に扱います。最後の条件は、信頼度の数値が上がっても文字が正しくなったとは限らない例です。この設定変更は本番へ採用せず、既定の認識と既存の検証基準を維持しました。

各条件は同じ小さな入力の比較で、独立した3文書の成功件数ではありません。追加モデル、しきい値、採用条件は変更していません。生成画像はメモリ内に限定し、実行ファイルとジョブ所有の一時ファイルは終了時に削除しました。Actions artifactは使用していません。

## 別APIによる文字の再確認

コミット `54fd9e6fd6f82cb3317ae194307aeb4d25161b98`、Actions実行 `37623012394` では、別の固定比較として同じ生成画像を3方式へ渡しました。画素SHA-256はすべて `7a72c163c9996987e185d5c20efa99bdbdb1051a12212de44502d7e4db7e56da` でした。文書認識の既定設定、`RecognizeTextRequest` のaccurate・言語自動検出ON、日本語・英語・言語補正ON、同じ文字認識で言語補正OFFを比較しました。

原文一致はすべて5/6でした。文字認識APIでは信頼度が0.5または1、言語補正OFFでは全項目1になりましたが、共通するクラス名の原文不一致は解決しませんでした。文書認識と文字認識では行の返却順も異なりました。信頼度の上昇やAPI間の一致を読み取りの改善・正解の証明として扱わず、全体の文書認識をこのAPIへ単純に置き換える変更は採用しません。別APIだから独立したモデルであるとも断定していません。

この固定比較も3呼び出し・1画像の取得診断で、正式な時間割や追加モデルの品質は未評価です。生成画像はメモリ内だけで扱い、ジョブ所有の実行ファイル・一時ログは削除しました。

## 小さい文字画像での項目別・信頼度別の比較

研究コミット `bc1eec4b8f9b2a439e1db0784f5015222870655e`、Actions実行 `37626889496` では、40種類の架空文字列をHiragino Sansの24 px・16 pxで描き、各画像を文書認識の既定設定とaccurate文字認識へ1回ずつ渡しました。80画像・160呼び出しが完了し、実行エラーは0件、所要時間は52.381秒でした。文字認識側は日本語・英語、言語自動検出ON、言語補正ONです。

| 項目 | 文書認識の原文一致 | 文字認識の原文一致 |
| --- | ---: | ---: |
| 科目 | 0/16 | 16/16 |
| 教員 | 16/16 | 16/16 |
| 教室 | 8/16 | 8/16 |
| 見出し | 26/32 | 26/32 |

これは孤立した小さな文字画像の比較で、ページ全体の文書認識や表の取得を測った結果ではありません。同じ文字列の2サイズを独立した文書成功件数として数えません。Windowsの別比較とは架空文字列を共有しましたが、フォント・画素・Runtimeが異なり、両OSの同一入力比較や合算値ではありません。

保存した原出力で本番と同じ0.85を評価すると、文書認識は正しい文字列46件を通し、正しい4件を拒否し、原文不一致20件を通しました。文字認識は正しい42件を通し、正しい24件を拒否し、原文不一致6件を通しました。研究コードの診断用0.8と集計は同じで、再推論やしきい値変更はしていません。文字認識で正しく読めた科目16件はすべて信頼度0.5であり、そのまま直接採用はできません。

両APIが同じ教室番号を誤読した例が8件残りました。文字認識で通った原文不一致6件の内訳は教室のO/0誤読2件と時間範囲の区切り4件です。後者は独立した時刻解析では意味が等しい可能性があり、文字列不一致と誤った時間割時刻を同一視しません。見出しのクラス表記も2件誤読されましたが、両APIの信頼度検査で拒否されました。

同じ誤読への一致は正解の根拠になりません。別APIで正しく読めたことだけでも採用条件を緩めません。原文、位置、構造、文書全体の完全性の照合が必要です。候補3件を取得しましたが、教室の誤読8件で正解を含んだのは1件だけでした。「候補のどれかに必ず正解がある」と仮定しません。正式採用・全文書復旧・追加モデル品質は未評価です。生成画像はメモリ内に限定し、一時実行ファイル・ログを終了時に削除し、Actions artifactを作成していません。

## 日本語を候補に含め、自動言語検出を維持する比較

研究コミット `0adc42b7f4e9c711fc50e6945662189f640d3815`、Actions実行 `37630666266` では、上記の既定文書認識の出力を固定し、新しい設定だけを80回実行しました。日本語・英語を指定し、自動言語検出はON、言語補正は既定のままです。全80画像の画素SHA-256が前の入力と一致しました。実行エラー0件、21.912秒で、以前の2条件は再実行していません。

原文一致は50/80から66/80になり、科目16件を修正し、元々正しかった文字列の破壊は0件でした。ただし科目16件はすべて信頼度0.5です。原出力を本番と同じ0.85で集計すると、正しい35件を通し、正しい31件を拒否し、教室のO/0誤読2件を通しました。前の診断用0.8でも同じ集計でした。これは認識候補の改善であり、正式な復旧成功や誤採用件数ではありません。しきい値を下げず、採用基準を緩めず、孤立画像の比較だけで本番のページ認識を変更しません。表の構造・位置と文書全体を含む独立した比較が必要です。

## 文字PDFの直接抽出と、同じ架空資料の画像PDFを分けた評価

実PDFKit取得から自然なStrict失敗、保持した原文・位置・罫線、Builder、Rules、Validator、正式変換まで通した独立架空資料は、[37669800332](https://github.com/n624-dev/takupoke-ios/actions/runs/37669800332)で正例2/2が年度・学期・680授業キー・2,040本文値すべて一致し、欠落・並記の負例4/4を拒否しました。Windowsと入力SHA-256も一致しました。文字PDFの結果であり、OCRや追加モデルの合格ではありません。

同じ正例から作った、文字レイヤーのない5ページ画像PDFを別に測定しました。SHA-256は `c3646735a721789b25a84dc1ff95afb969857fde71af9c30549fa07b40ae8635` と `3a62d279148c10e055e5179c45a1a48bae82a668ab44aaf223a00c4c73eec7b7` です。学校原本は使っていません。

| 固定比較 | 実行 | 全文書復旧 | 停止段階 |
| --- | --- | ---: | --- |
| 既定の文書認識 | [37672267679](https://github.com/n624-dev/takupoke-ios/actions/runs/37672267679) | 0/2 | 文字位置対応／時限見出し |
| 日本語・英語を指定、自動言語判定・補正は維持 | [37678207381](https://github.com/n624-dev/takupoke-ios/actions/runs/37678207381) | 0/2 | 同じ段階 |

それぞれ実Visionを10回呼び、LLMは0回です。正式出力0、誤った正式出力0、実行エラー0でした。正例の拒否は復旧失敗として数えます。root行とtable行を別に残しましたが、本文全文字列の一致・包含は両方とも0/2,040でした。この指標を文字正解率0%とは解釈しません。行分割・空白や、セル所属も別に検証する必要があります。

続く[37680504894](https://github.com/n624-dev/takupoke-ios/actions/runs/37680504894)、研究ソース `5a4cf6d9fa5817ad78da0610bf155a051a1bf5c2` では、各資料の第1ページだけを同じ言語設定で長辺2,048と原画像相当の2倍描画へ渡しました。実寸は1,573×2,048対2,176×2,832、1,616×2,048対2,396×3,036です。全4呼び出しが完了しましたが、原文の包含は空白を無視する診断でも0件のままで、解像度だけの変更を改善として採用しません。第1ページの観察を全5ページの成功率へ換算せず、文書全体とiPhone実機品質は未評価のままです。認識後の架空断片には別の文字体系も含まれ、次は自動言語判定を単独比較します。

これらはmacOS上のPDFKit・Visionと共通取得コードの観察です。iPhone上の取得・人の採用・追加モデル品質の合格を意味しません。採用条件、信頼度、最大3本文項目の条件は変更していません。Actions所有のPDF・フォント・実行環境は最終cleanupで削除し、artifactを作成していません。

自動言語判定だけをOFFにした研究ソース `adbdb3a79b727c61f1ca95c77ce6ca04d416afd2`、[37681733088](https://github.com/n624-dev/takupoke-ios/actions/runs/37681733088)も、全文書復旧0/2、正式出力0、実行エラー0でした。ON/OFFで全10ページのRGBAハッシュは一致し、macOS26.6.2、言語ja/en、補正ON、候補3を実際のrequestから記録しました。開発側はroot本文1/2,040の文字列が一致しましたが、セル所属の証明や正式採用には進めず、文字位置対応の失敗も増えました。未見側は時限見出しの失敗が残りました。原密度の第1ページでも原文包含0件です。自動判定OFFを本番へ採用せず、次は同一CGImageをaccurate文字認識へ渡す独立比較を行います。

同一CGImageでRecognizeDocumentsRequestとaccurateのRecognizeTextRequestを比較した研究ソース `d00cbca`、[37682901775](https://github.com/n624-dev/takupoke-ios/actions/runs/37682901775)でも、文書全体の既存経路は0/2でした。第1ページの別認識では、長辺2,048の開発側が原文包含1件、未見側0件、原密度2倍では両方0件です。低信頼度行は減りましたが、原文一致の改善には結び付かなかったため、accurateへの切替を本番へ採用しません。第1ページの包含数は全5ページ2,040値の正解率として扱わず、セル所属・正式採用は未評価です。両requestには同じ画像・ja/en・言語自動判定OFF・補正ONを使い、しきい値を変えていません。次は同寸法の埋込元PNGとPDFKit描画を比較し、取得経路と認識能力を分けて評価します。

## Same-size embedded PNG comparison: SDK compile error before OCR

Research run [37687961129](https://github.com/n624-dev/takupoke-ios/actions/runs/37687961129), source `b767a92`, failed before native recognition because `RecognizeTextRequest` uses `minimumTextHeightFraction`, not `minimumTextHeight`. No acquisition comparison or quality conclusion was produced. Research source `e505f13` corrects that diagnostic property to match the official SDK declaration and retains every recognition setting, source image and adoption restriction. Its replacement native run must complete before interpreting PNG-versus-PDFKit results.

## Same-size original PNG versus PDFKit: acquisition change rejected

Corrected research run [37693394523](https://github.com/n624-dev/takupoke-ios/actions/runs/37693394523), source `e505f13`, passed505 native tests (one skipped). On both invented first pages, PDFKit2x and the embedded original PNG had exactly matching normalized RGBA hashes,0 RGB-changed pixels,0 nonwhite-classification changes and0 dark160 changes. Accurate Japanese/English text recognition produced the same line counts and occurrence diagnostics on either image:187/206 lines,137/168 below0.85, and0 body literal occurrences. These first-page occurrences use the2,040 whole-document denominator and are not first-page or complete-document accuracy. The larger original-image acquisition alone did not improve recognition; it is not promoted. Formal recovery remains0/2, with no model qualified.

The recorded `RecognizeTextRequest.minimumTextHeightFraction` default was0.03125. The next separate research condition `68b4775` compares a fixed8-source-pixel detection minimum on the identical2x CGImage, changing no ROI, language, correction, confidence or adoption rule. This is a detection experiment, not a lowered acceptance threshold. The paired sources remain diagnostic documents, not independent qualification material. Final CI cleanup removed all owned image/PDF/font and Python intermediates.

## Fixed eight-pixel text detection minimum: more text, not qualified recovery

Research source `68b4775`, [37695296545](https://github.com/n624-dev/takupoke-ios/actions/runs/37695296545), completed505 native tests with one skipped and no failures. Both first-page comparisons used exactly the same CGImage as their accurate-text baseline, changing only `minimumTextHeightFraction` from0.03125 to8/imageHeight. Languages ja/en, accurate level, automatic language detectionOFF, correctionON and acceptance rules stayed fixed.

| Invented source | Baseline lines | Eight-pixel lines | Baseline body literal occurrences | Eight-pixel body literal occurrences | Eight-pixel lines below0.85 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Development | 187 | 434 | 0 | 48 | 411 |
| Unseen content | 206 | 434 | 0 | 54 | 395 |

The year/term transcript also improved, but low confidence remains common. Counts are textual occurrences observed on only the first page against2,040 whole-document obligations. They are not verified field assignments, character accuracy or complete-document success. The full existing recovery result remains0/2. No additional model is qualified and production settings remain unchanged. Owned generated source images, PDFs, font and Python environment were removed by final CI cleanup.

The next research source `964d9e9` compares the same height-only change inside RecognizeDocumentsRequest, recording root lines and row-axis table lines separately. This checks whether the native document hierarchy benefits rather than assuming the independent text reader's improvement transfers to table acquisition. The larger diagnostic raster remains outside the app's2,048px capture bound and cannot enter adoption.

## Documents minimum-height comparison: more text does not preserve the table

Research run [37698462486](https://github.com/n624-dev/takupoke-ios/actions/runs/37698462486), source `964d9e9`, passed505 native tests (one skipped), with no execution error and successful owned-data cleanup. On the same two original-density first-page CGImages, only `RecognizeDocumentsRequest.textRecognitionOptions.minimumTextHeightFraction` changed from0.03125 to8/imageHeight. Japanese/English, language autodetectionOFF and the native correction/candidate settings remained fixed. Root text and row-axis table text were counted separately, without column-axis duplicates. These oversized research images still cannot enter production capture.

| First-page diagnostic | Development default /8px | Unseen default /8px |
| --- | --- | --- |
| Root lines |182/434|207/434|
| Tables |1/0|1/1|
| Table rows |18/0|18/19|
| Row-axis cell references |162/0|144/164|
| Native merged cells |0/0|0/3|
| Root body-literal occurrences |0/48|0/53|
| Table body-literal occurrences |0/0|0/53|

All root/table top candidates were below the unchanged0.85 floor. This aggregate does not reveal whether the native scores are0,0.5, missing or otherwise distributed; missing candidates must be measured separately rather than treated as zero. First-page occurrence counts against the whole-document2,040-value inventory are not field accuracy or complete-document success. The development table disappeared, and unseen table topology changed, so this setting is not promoted as a production improvement. Formal recovery remains0/2 and no additional model is qualified. Next diagnosis inspects actual native candidate confidence without transplanting a Text reader's score onto Documents text or lowering adoption thresholds.

## Native confidence distribution: low candidate scores are real, not missing-as-zero

Research run [37700542780](https://github.com/n624-dev/takupoke-ios/actions/runs/37700542780), source `8ceef06`, passed506 native tests (three skipped), completed exactly4 recognition calls and removed its owned generated cohort/dependencies. The closed density/whole-document conditions were skipped rather than repeated. Two first-page CGImages were each passed to Documents and accurate Text with the8px minimum, ja/en, autodetectionOFF and correctionON. No oracle entered recognition, and neither reader's text/score was substituted into the other's output.

Documents root candidates were all present, finite and nonzero: development434scores ranged0.07689995–0.68293792; unseen434ranged0.11558640–0.58729869. The unseen433row-axis table candidates ranged0.11558640–0.50915205; development again had no table. These native values are genuinely below the unchanged0.85 floor. The enclosing `DocumentObservation.confidence` was0 on each page, a distinct API value which is not used to replace line-candidate confidence.

Text candidates were also all present/finite/nonzero. Development returned410scores at0.5,23at1 and1at0.3; unseen393at0.5,39at1 and2at0.3. The native API distributions therefore differ. Neither0.5 nor1 is treated as a calibrated correctness probability, and these measurements do not authorize a threshold reduction or cross-reader score transfer. Full-document recovery and additional-model qualification remain unproved.

The unseen numeric JSON was split by XCTest stdout/stderr interleaving. Both existing fragments were reassembled after the run, and histogram totals were checked against all observations; recognition was not rerun to repair logging. Future diagnostics limit displayed distinct-value entries while retaining observation/missing/nonfinite counts and exact min/max.

## Independent readable-Japanese whole-document observation

Native Actions37702350296, research source87726dc0d6ff6262d150531218184e37bb2fb389, completed506 tests (2 skips), the dedicated observation and final owned PDF/dependency cleanup. The same independent10-page image PDFs as Windows were used: SHA-256dc161893dd91f26004ccc9ca7f99b9b762ee918b40c621b561c2d5366c533704 and378abd58c74a23c397dc71b3091179d3196c4501a8eb64dad9c610130dcf6a5f. Prior harder positive inputs remain unchanged failures.

Both documents had2040/2040 exact body-literal occurrences in native root and table text after20 whole-page Documents calls. All20 pages were captured within2048-pixel axes with0 character-mapping errors. This is occurrence evidence, not correct field/cell ownership or100% timetable accuracy. Both full documents failed in Builder at calendarDates ambiguous;0/2 exact formal documents,0 incorrect formal adoption,0 execution errors.

The4 additional first-page confidence calls returned236 root candidate scores on each case, all present/finite/nonzero but all below.85. Root ranges: development.11911424–.71568602, held-out.08924722–.70995468. Accurate Text yielded development219×.5,16×1,1×.3; held-out148×.5,87×1,1×.3. Native confidence is not lowered, replaced or treated as calibrated correctness. The8-source-pixel recognition minimum and language recipe remain research conditions; no production/catalog qualification follows. Next diagnostic traces the original weekday labels and the exact physical-band predicate before changing parsing.
