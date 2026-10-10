# OCR改善の検証記録

## 2026-10-10 直接取得の不要な拒否と表示条件

0.1.239から347への更新後、利用者から通常P01・試験P12・返却P12の失敗が報告された。
原本の再取得・直接テストは行わない。3資料の実際の原因と改善後の結果は未評価である。

色の設定と実描画、先行する白いページ背景、閉じた表示に影響しないタグ、
ページ全体を含む矩形クリップを直接取得で検証する。字形の範囲は幅・上下寸法だけでは
証明できないため、取得矩形が収まる場合でもページより狭いクリップは拒否する。
未知の色変換は実描画する色方式だけを確認し、未使用DefaultRGBでGrayを拒否しない。
任意表示・置換文字・上塗り・不可視文字・切断と不正構造の拒否は維持する。

最初のApple両SDK521件は予定skip1・失敗8だった。
診断段階の旧期待値6件、異なる色方式の黒を比較した画素不一致2件を別に扱う。
同じCMYK描画の独立した標準命令を対照に変更し、全画素一致の条件を維持した。
修正ソース982e297の[両SDK再検証](https://github.com/n624-dev/takupoke-ios/actions/runs/38020607674)は、
521件・予定skip1・失敗0。26は111.330秒、27は69.376秒だった。
対象は架空入力の取得・拒否条件であり、時間割全体の復旧率へ加算しない。
CI成功・直接取得の検査・実資料の文書全体成功・OCR／モデル品質を区別する。

配布前全体348のNative521件は予定skip1・失敗0だったが、27の手動訂正・原本変更UIは
clearボタン取得時のAX snapshot timeoutで失敗した（本体201.614秒、Selected suite201.659秒）。
ボタン全体の実表示を確認してから取得する候補修正はUI検証経路だけで、解析規則を変えない。
直前のInvalid frame dimension警告の原因・解消と、候補修正のAppleでの効果は未確認である。
失敗した実行を配布成功やOCRの改善に数えず、新しいソースの全体検証を必要とする。

取得順序を変更した全体349の原本変更27も失敗した（本体242.280秒）。
今回は実clear・確認解除・本文入力まで成功し、keyboard toolbarの完了が操作不可だった。
入力終了を製品のnavigation barへ移す候補を実装し、同じ確認・保存規則で再検証する。
画面寸法警告の原因は未確定で、このUI修正をPDF／OCR品質の改善へ加算しない。


## 配布前の実行件数確認：Mac Bashの空配列で未実行成功を拒否

全体実行 [37724583586](https://github.com/n624-dev/takupoke-ios/actions/runs/37724583586)、`9e1bec0` のiOS26 UI Aは約10秒でsuccess表示でしたが、rootが完了ログを読むとMac標準Bashの `probe_args[@]: unbound variable` でテスト前に終了していました。追加した診断切り替え用の空配列が原因で、清掃trap後の終了が成功として扱われています。XCTest完了は0で、UI合格・配布合格には数えません。残る実行は中止します。

引数配列は通常モードでも必ず `--shard` と値を持たせ、清掃で直前の終了値を保持します。さらに呼出側でもstdoutから各OS・shardのXCTest完了件数と結果を独立確認し、Bの追加OS文字サイズ3実行も必須にします。空ログ、未完了、余計な反復、skip条件違いをsuccess表示だけで通しません。集中診断も同じ呼出側確認を使います。

集中診断 [37723327217](https://github.com/n624-dev/takupoke-ios/actions/runs/37723327217)、`6188769` はiOS26/27でそれぞれ実際の2 XCTest完了・成功を確認済みです。両方ともリンクの解除・再起動・再追加、AI/OCRの初期OFF、ON/OFF/ON保存、再起動後OFFと保存の再確認を完了しました。これは新しい呼出側保護の検証や全13条件の合格とは別です。

## 項目別native信頼度：独立ASCII見出しで誤受理があり一律調整を不採用

研究ソース `0da6e3bd6addd667205633bf10f3cd79c0043de0`、Actions [37723930725](https://github.com/n624-dev/takupoke-ios/actions/runs/37723930725) は511テスト（6 skip）、128の一意な項目ID、4種類の境界、専用測定の固定2認識と所有ログ・JSONLの削除を完了しました。架空の開発／独立評価1920px原画像をメモリ内で描き、各4種類×16項目を配置しました。内容・フォントをHiraginoSans-W3／HiraMinProN-W3に分け、9/12/16/20px、黒／青を事前固定しました。日本語・英語、言語自動検出OFF、8原画素の認識最小高さは研究条件です。正解・評価領域は認識後の位置／literal監査だけに使い、認識・候補選択には渡していません。

|種類（各16項目）|開発完全一致|独立完全一致|開発だけで固定した候補score下限|独立正答受理|独立誤答受理|
|---|---:|---:|---:|---:|---:|
|ASCII見出し|8|2|0.36487713456153875|0|2|
|日本語見出し|13|12|0.038918737322092063|12|0|
|日本語本文|14|10|0.068930856883525862|5|0|
|コード|8|5|候補なし|0|0|

開発側で固有score付き誤答2件以上・正答4件以上を要求し、誤答最大scoreより上に正答がある場合だけ候補を一つ固定しました。独立側の結果を見て再調整していません。ASCIIは誤答を2件通し、正答を受理できないため不採用です。コードは開発側で分離できません。日本語の小標本で誤受理0でも、本文受理は5/16にとどまり、全文書を最大3訂正で完了できる根拠やモデル資格とは扱いません。独立側には日本語見出し2件・本文3件の欠落があり、空欄へ変換していません。全128件の原座標・各reader自身のliteral/scoreを保持し、score転用、アプリ閾値変更、採用は0です。次は同じ画素に対するText readerの固定paired診断で、修復・退行・共通誤読を分ける候補です。

先行実行 [37720750964](https://github.com/n624-dev/takupoke-ios/actions/runs/37720750964)、`a4138f7` のnative測定・511テスト自体は完了しましたが、XCTest stderrがJSON1行を分断し集計が失敗しました。元の先頭・末尾だけを再接続して全128件を監査しました。上記再実行は、変更しない記録を専用の所有JSONLへ一度だけ保存する経路のnative検証であり、新しい独立正答件数には加算しません。さらに前の未登録テスト実行とimport不足のコンパイル失敗は0測定として扱い、認識精度の失敗／成功には混ぜません。

## 再起動後の実操作を分離して診断

全体実行 [37720614152](https://github.com/n624-dev/takupoke-ios/actions/runs/37720614152)、ソース `d4a54f2580d79ed0f2e24e67e9e1d48568f70802` のiOS27 UI Bは13件中2件が失敗しました。リンクのお気に入り解除後の再起動では一覧の行可視判定中にnavigation/tab要素を解決できず、AI・OCRスイッチは初期OFF、ON→OFF→ONと保存、再起動後のON保持まで通り、続く物理OFFタップがUI/保存値に反映されませんでした。両方とも再起動後の操作ですが、共通原因やアプリ不具合とはまだ断定しません。配布合格には数えません。

QAはその2操作を独立したnative実行で診断できるようにし、操作前と失敗時に架空画面の画像・実際のAX状態を記録します。リンクの可視判定は実際の「一覧」navigationを特定し、存在を確認してから枠を参照します。実ボタン操作、各項目の保存・再起動保持、OFF反映の条件は維持し、直接の状態代入や成功までの再試行は追加しません。集中実行は全体検証の代わりにはなりません。

同実行のiOS26 UI B、iOS26の3項目訂正／4項目拒否、iOS27の1項目訂正は成功しました。ファイル選択UI3件、ホスト505テスト（1 skip）、iPhone向けReleaseコンパイルも完了しています。残るジョブは中止し、全13条件の合格とは数えません。作成された非公開配布下書き406383091は、その実行ID・コミット・タグ・所有bodyとprivate状態を照合して削除しました。正式版・既存公開版は変更していません。

## 配布前のファイル一覧検証：全要素検索のタイムアウト

全体実行 [37718945066](https://github.com/n624-dev/takupoke-ios/actions/runs/37718945066)、ソース `ae7ecd1604802841e1c1314810f7345c575ce869` はPython125件（3 skip）、native PDF/復旧505件（1 skip）が成功しました。ビルド用ジョブ内のファイル選択UIは、実ボタンの選択・キャンセルを繰り返し、ホームから設定へ戻ったあと、全子要素を対象とした `picker-file-list` の検索でAXスナップショットがタイムアウトしました。iPhone向けアプリのコンパイルエラーや学校資料の解析エラーとは扱いません。IPA作成・private draft stagingには進んでいません。残るジョブは中止し、全13条件の成功や配布の合格とは数えません。

QAはSwiftUI Listの識別子付きCollectionViewを直接検索する形に変更しました。既存の実ボタン操作、4種類の行、可視範囲、実スクロール、キャンセルと復帰の確認は維持しています。この変更の効果と配布前全条件は新しい同一コミットのnative実行で確認します。

## 分割見出しの原墨監査：文字枠の共有を保持して自動結合を見送る

研究ソース `40447dd9e4287554a8a57cccc74a969c4a322d14`、Actions [37717228516](https://github.com/n624-dev/takupoke-ios/actions/runs/37717228516) は510テスト（5 skip）、36の固定局所認識と所有ファイル削除を完了しました。前のログには行枠しかなかったため、同じ原墨+4px条件でtop1の各文字範囲枠・観測順・原読順を取得しました。新しい独立した正答件数としては数えません。既知クラス・正解・語彙は認識や枠の選択に使用していません。

分割された `3_IT` と `5_IT` は、両readerとも別観測の文字枠が原画像の非白4画素を重複して囲んでいました。原非白画素は219/218、単独の文字枠に囲まれた画素は215/214、どの文字枠にも囲まれない画素は0です。枠で囲まれることは文字の正しい所有の証明ではなく、実際の印字を重複認識したとも断定しません。位置・同一セル・文字の連結だけで安全な再構成と認める根拠が不足するため、結合は許可しません。文字枠を人工分割、修正、丸めたり、文字を追加・削除して整合させたりしていません。

`1_1` は137原非白画素がありながら両reader無出力でした。空欄へ変換せず未読のまま残します。また、文字枠が墨をすべて囲んでも、accurate readerではunderscoreを省いた誤読があり、墨の網羅性だけでは正確な読字を証明できません。固有score、採用条件、アプリ経路は変更せず、追加モデルと全文書の資格は未合格です。

1行のJSONがXCTestの別出力で分断されたため、元の先頭と末尾を再接続し、全18行の画素数の分割和を確認しました。欠けた診断を再認識で埋めることはしていません。

## 消去タップの可視範囲：44px全体をキーボードから離す

集中実行 [37714976724](https://github.com/n624-dev/takupoke-ios/actions/runs/37714976724)、ソース `5b815ae1a51f589b81a864cec17ecaec0b1c75c5` のiOS26は最初の2項目の物理消去・全文入力・個別ACKを通り、3項目目の消去で失敗しました。失敗位置では23pxの入力欄がy475から、44pxの消去ボタンが同じy475から表示され、キーボードを避けるQAの安全範囲にボタン全高が収まっていません。Buttonはenabled/hittableですが、記録に消去actionの配送がなく、実際の値も元のままでした。フォーカスへの依存を除く変更だけで解決したとは扱いません。

同じ集中実行のiOS27は3項目の訂正・独立確認・採用後保存と4項目拒否を完了しました。iOS26の失敗をiOS27の成功で合格扱いにはしません。

QAの可視化helperは入力欄だけに全高の安全範囲を要求していました。消去ボタンにも同じ要求を適用し、元のList上で実際にスクロールしてボタン全体を表示してから1回タップします。値の直接代入、ACKの合成、再試行での成功扱いは行いません。集中実行 [37716679414](https://github.com/n624-dev/takupoke-ios/actions/runs/37716679414)、ソース `d6d5b48cebb1752ad6daab5d93d193ef2ca04b72` でiOS26/27の両方が全3項目の物理消去・全文入力・個別ACK・採用後保存・再起動保持と4項目拒否を完了しました。iOS26は25分05秒、27は19分47秒のジョブです。配布前の全13条件は別に確認します。

## 固定全墨クロップ：AI印字は改善するが、欠落・断片と信頼度が残る

研究ソース `c5772cfb774b782e23c3aa5acfcd4f888c76aff4`、Actions [37715939572](https://github.com/n624-dev/takupoke-ios/actions/runs/37715939572) は510テスト（5 skip）、36局所呼び出し、所有画像・依存の削除を完了しました。同じ独立架空2ページの全18クラスセルについて、原画像の全非白画素と固定4px余白を拡大せず渡しました。語彙・認識結果・正解をクロップ選択に使っていません。

| 固定reader | 開発top1単行一致 /9 | 未使用top1単行一致 /9 | 全18件で正答かつ自身のscore0.85以上 |
|---|---:|---:|---:|
| Documents、元の補正設定 |7|8|0|
| accurate文字認識、補正OFF |4|6|7|

Documentsは4つのAI見出しをすべて原文どおり返しましたが、`1_1` は両APIで出力なし、`3_IT` と `5_IT` は各 `3_` / `5_` と `IT` の別観測でした。単行一致がないことと、全断片の文字自体が誤読されたことは区別します。断片を一つに結合して成功扱いにはしていません。accurate文字認識にはunderscoreを省く退行も残りました。元の全体認識、各局所readerの値・候補・信頼度を保持し、転用やしきい値変更、採用は行いません。

前の同条件実行 [37715457158](https://github.com/n624-dev/takupoke-ios/actions/runs/37715457158) は、nativeの観測四角形が入力クロップを約0.14px/0.33pxはみ出すことを診断assertionが拒否しました。四角形を丸めず原座標のまま記録し、入力内包含と元の物理セル内包含を分けました。再実行では全観測が元の物理セル内にあり、各reader10/18セルで入力クロップ境界からのはみ出しを記録しています。これは研究診断の訂正で、アプリの位置・採用条件の緩和ではありません。全文書復旧と追加モデル資格は未合格です。

## 不採用：クラス欄の局所2経路認識

研究ソース `6ea3a5483339a99b67fd2a0996b72c6414bbc016`、Actions [37714706335](https://github.com/n624-dev/takupoke-ios/actions/runs/37714706335) は510テスト（5 skip）、36の固定局所認識呼び出し、所有画像・依存の削除を完了しました。2文書の先頭ページだけを対象に、原画素の閉罫線から選んだ全18クラスセルを同じ原画素で比較しました。全ページの再認識・拡大・語彙補正・採用は行っていません。

| 固定reader | 開発9件のtop1一致 | 未使用9件のtop1一致 | 全18件のtop5内に正答 | 正答で自身のscore0.85以上 | 誤答で自身のscore0.85以上 |
|---|---:|---:|---:|---:|---:|
| 局所Documents、元の補正設定 | 6 | 7 | 14 | 0 | 0 |
| 局所accurate文字認識、補正OFF | 6 | 7 | 13 | 7 | 0 |

両readerのtop1は同じ5誤読を返し、4つのAI見出しに加えて、全ページ認識では正しかった `4_CN` も `A_CN` へ退行しました。見出し18件は独立18文書の成功件数ではありません。候補内に1件増えた正答を既知クラス一覧で選ばず、正答率改善・しきい値の妥当性・全文書復旧として数えません。クロップとreader設定が変わるため、補正OFF単独の効果とも断定しません。この方式は本番へ採用しません。

## 訂正の消去操作：入力フォーカスへの依存を除く

ソース `5e437e041798507285c8819dea5975d25a81d47b` の集中実行 [37713451766](https://github.com/n624-dev/takupoke-ios/actions/runs/37713451766) は両OSで失敗しました。iOS26は1項目目の物理的消去・入力・独立確認を終えましたが、2項目目の消去後もAX値と実際の入力状態がともに元の `架空科` のままでした。行幅を固定する前回の変更だけでは直っていません。iOS27は設定画面からの移動時にAXスナップショット取得がタイムアウトし、消去操作まで到達していません。両者を合格として扱いません。

入力フォーカスはボタンのタップ開始からaction配送までに変化し得るため、消去の有効条件からフォーカスを外しました。入力値・機能ON・処理状態・現在draftのガードは維持し、確認済みチェックも通常の入力変更と同じ経路で解除します。QAは物理タップ時のボタン位置と有効状態、実際の消去action配送を記録します。この原因仮説と修正の効果は次のnative実行で確認し、未検証のまま配布しません。

## クラス列の欠落原因：原認識文字の不一致

研究コミット `381b386920f241a1ab35e8fd58100ede0592b6da`、Actions [37711266896](https://github.com/n624-dev/takupoke-ios/actions/runs/37711266896) は509テスト（3 skip）と所有一時ファイルの削除を完了しました。同じ独立架空2文書を20回の固定ページ認識で測り、全文書の正式復旧は0/2、誤採用0、実行エラー0です。

先頭ページのクラス列は各9行のうち7行について、原文を保持し、閉罫線・印字の包含・時限列との位置・行の重複排除をすべて満たしました。残る2行は、開発資料で `AL_1` と `AIL_2`、未使用側で `AlL2` と `AILI` が認識時から返っています。これらを既知クラス名で修正せず、クラス網羅性の検査で拒否しました。正しい文字が後処理で分断・消失する仮説は、この失敗箇所には当てはまりません。本文の2040/2040原文出現は維持していますが、セル・項目所属の成功とは扱いません。

次の比較は、物理罫線と原画素だけでクラス列の非空欄をすべて選び、局所文書認識とaccurate文字認識の固定条件を測る診断です。各readerの上位候補・位置・信頼度を別々に保持し、候補の既知クラス照合、信頼度の転用、採用は行いません。比較結果はまだ未測定です。

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

## 2026-10-08: Original physical header pixels, without another OCR pass

Research source`2f0a4a1b10f1c86aa500f588396eeae7a6075129`, native Actions37708490025, completed507 tests (4 skips) and owned cleanup. It rendered only the first page of each same independent readable image PDF, with0 OCR/LLM calls. Original weekday text had already been recognized correctly. Day-band closure failed specifically at top/right support; containment, day uniqueness and left/right semantic alignment were true.

Native development dayBox=[236,71.5,1899.5,123], periodBox=[236,124,443.5,179.5]. Actual dark rows71/72 span[236,1899]/[235,1900]; rows123/124 span[48,1900]/[47,1900], with white rows on either side. Extracted rules retained separate adjacent lanes at123 and124, and a shorter top/right representative. Held-out shows the same effect at width2048, with right edge1995.5. Original RGBA SHA-256development957b9b3b0fa3570f124d81c4dc3d620311150475043046698e2df6856df2d306 and held-out153c80d912c0410b363605a0c97c1cebddef53e25c9e22af80ea678951f10da9.

This establishes a pixel-lane ordering/representative defect in physical rule extraction, not missing weekday recognition. No Builder tolerance, accepted class, confidence threshold or formal adoption rule was relaxed.

## 2026-10-08: Continuous physical border bands preserved

Research source`5e2e3a83745c009c3196a6743ee953ddf1ff555a`, native Actions[37710319607](https://github.com/n624-dev/takupoke-ios/actions/runs/37710319607), completed509 tests (3 skips),20 whole-page Documents calls and owned cleanup. Adjacent lanes with observed endpoint differences are grouped by pixel axis, using the longest actual lane rather than stitching inferred spans. Masking is limited to contiguous observed support; a white pixel gap keeps two boundaries separate. Both new physical regressions and existing faint-ink/open-tail/cancellation guards passed; Linux454 tests also passed.

Both original weekday bands now have all four physically closed edges. Development day bottom and first-period top both equal123.5 rather than123/124; held-out behaves likewise. Same source pixels and all2040 exact root/table body occurrences are preserved. Full documents now fail at classLabel ambiguous instead of calendarDates ambiguous:0/2 exact formal documents,0 incorrect formal adoption,0 execution errors. Confidence is unchanged. Builder output atoms remain0 because it does not return a completed document, not because native source text is absent. Next diagnosis follows raw class headings, their original line IDs and each class-row predicate. The geometry/mask fix and its two regressions are promoted to the application; full application checks remain separately required before publication.

## 2026-10-08: Physical correction input checks

Focused native run37708947860 tested source957706f. iOS27 completed the independent edit/acknowledgement/background/adoption checks, while iOS26 failed because its native text-selection menu did not expose Select All. No pass is inferred from the other OS. The correction input now provides an explicit native clear operation using the same guarded text-update path; clearing revokes acknowledgement and never supplies replacement text. UI checks physically tap clear, require empty input and unchecked acknowledgement, type the complete correction, dismiss the keyboard and compare the entire value. Local Python125 tests pass (3 skips).

Full run37711193104, source23e73b7, failed its iOS26 three-field case at the second field's empty-after-clear assertion. Its first field passed full replacement and independent acknowledgement. Because the failing log lacked the actual post-clear field/state, no binding-versus-AX diagnosis is claimed. The editor now retains the same row height/field width when the clear control becomes hidden, and failure diagnostics preserve the targeted field and draft value. Remaining checks of the rejected source were cancelled; its build job had not started and no owned staging draft existed. A focused three-field check on both OS versions precedes another full run. No verification or release pass is inferred from incomplete/cancelled jobs.

### 配布前の確認画面上部へのQAスクロール（2026-10-08）

- af3f380の全配布チェック37725047676で、iOS27の1項目訂正は全文入力・ACK取消/再確認・同一プロセスの背景復帰・未採用のreview=trueまで進んだ後、見出しのAX検索がタイムアウトした（job113141447527）。原本や採用データの不具合を証明したものではない。実機でも同じになるとは未確認。
- ログでは、編集画面の位置を保持した確認画面から、上部の見出しが仮想化されているのに、QAが下の内容へ向かう上ドラッグを開始していた。上部のreview/preview見出しを探す場合だけ、実際のList内の型付きStaticTextを対象にし、最初は上部へ向かう下ドラッグとする。実際の領域情報が出た場合の方向修正・16回上限・一度だけの無進行反転・完全表示/操作可能性の検査を維持する。本文/ACK/採用状態を注入しない。製品のView・Coordinator・判定規則は変更していない。
- 実QAと同じ純粋ナビゲーション状態17ケースをコンパイル/実行し、Python127件がLinuxで成功した。Native iOS26/27の画面チェックはこれからで、この変更だけでタイムアウトが解決したとは扱わない。
- 同じaf3実行のiOS27・3項目訂正（job113141447541）は実XCTest853.872秒で成功した。これは他の失敗項目の代替合格にはしない。

## 2026-10-08: 配布前の通知操作とライセンス一覧

- ソース41f8112の実行37727315956で、iOS27 UI A（job113148563561）は13件中11件成功、2件失敗。通知スイッチのON待ちが失敗し、ライセンス一覧は戻った後に上にあるdenpa-schedule-csvの行を上方向へスクロールし続けた。画面階層には同じ行がナビゲーションバーより上に残っていた。読み取り精度の不合格とは別に記録する。
- 通知のQA操作は画面・有効状態を確認し、アクセシビリティ範囲の右端から26px内側の実コントロール中央を1回タップする。タップ前の架空画面と値を記録し、実際のON、再起動後の通知生成の期待値は保つ。許可画面は既存の標準UI interruption monitorで扱う。
- ライセンスのQA操作は行の実座標を使い、前の行が仮想化されている場合も明示した上側へ探す。ライセンス本文のCopyright確認は省略しない。アプリ本体・通知保存規則・採用条件は変更しない。
- LinuxのSwift構文確認とPython127件は成功（skipなし）。iOS26/27の修正版の実操作は未確認で、同一ソースの全13必須チェック成功前には公開しない。

## 2026-10-08: 再起動後のリンク行の実長押し

- ソース55fe35fの実行37730636019では、26 UI Aの通知生成・ライセンス表示と27の1項目訂正が成功した。27 UI B（job113158930495）は13件中12件成功し、再起動後のリンク行の長押し前判定だけが失敗した。全13チェックの成功・配布可能とは扱わない。
- 元スクリーンショットのSHA256は56a0b4a0ff655853e4f844e3af60ac02034174bfa66f2929f043df19b84d4bcc。ログと実画像では行[16,205.3,361,64]がナビゲーション下端165からタブ上端769の間に全表示され、待ち時間前後の画像も同一だった。長押しは始まっていないため、実操作が可能かはこの失敗だけでは判定しない。
- QAは存在・有効・全表示の条件を維持し、その行の実座標で長押しする。AXのisHittableは診断へ残し、事前の合否条件には使わない。ネイティブメニューの出現、実ボタンの操作、再起動後の解除状態と再追加を引き続き必須にする。製品のリンク処理・保存・UI・採用条件は変更しない。修正版の実操作は未確認。

### 通知スイッチの標準操作による切り分け

- 同じ55fe35fの27 UI A（job113158930594）は13件中12件成功し、通知変更のON待ちだけが失敗した。許可ダイアログを操作したログはなく、座標タップから保存までのどこで止まったかは確定できない。通知以外の12件と26の成功を、この失敗の代わりにはしない。
- QAはネイティブSwitchの標準tapを1回だけ行い、許可処理、ON状態、実プロセス再起動後の通知生成を維持する。失敗時には値・有効状態・AX階層・原画面を記録する。通知状態や許可を注入しない。通知・リンク・AI設定の3件を両OSの独立した絞り込み実行で先に確認し、その成功後も同一ソースの全13必須チェックを要求する。
- 55fe35fと0abdf31の未合格実行はキャンセル済み。前者の所有証明付き非公開draft406449099を削除し404を確認した。公開済みの配布物と正式版は変更していない。

### 通知行と子Switchの区別

- feac6b8の絞り込み実行37734895217では、両OSともリンク長押し・保存/再起動とAI設定が実操作で成功した。通知のONだけが両OSで失敗した。未合格であり配布条件を満たしていない。
- 失敗時のAX階層で、ラベル付き行Switch[16,165,361,52.3]の内部に実コントロールSwitch[300,177.3,63,28]があることを両OSで確認した。行の標準tap後も画面のSHA256が前後同じで、ONも許可操作も記録されていなかった。
- QAは対象ラベル行の内側にあるネイティブSwitchを型付きで取得し、その存在・有効・操作可能性を確認して1回タップする。ON・許可・再起動後の通知生成と設定保持は省略しない。通知の2ケースに絞って両OSで検証し、成功後に全13必須チェックを実行する。製品コードや保存済み許可は変更しない。

### 通知画面への遷移と実コントロールの実測

- ソース20cc616の絞り込み実行37736674883では26の2件が成功。27も子Switchの1回タップ、実際の許可ダイアログのAllow操作、ON表示、実プロセス再起動後の通知生成が成功した。27のもう1件は通知画面に入る前の行isHittable確認で失敗した。スイッチ操作の失敗とは別に扱い、全13チェックの成功とは数えない。
- 27のAX階層では通知行[16,577.3,361,52.3]がナビゲーション下端165とタブ上端769の間に全表示されている。通知画面を開くQAは存在・有効・全表示を確認し、実際の行の座標へ1回タップして遷移完了を必須とする。保存値・通知許可・製品コードの注入や合格条件の省略は行わない。修正版の実操作は未確認。

### 同一原画像でのVision2経路の比較

- 研究ソース9e0e434、ネイティブ実行37736842542は511件・6skip・失敗0。1920角の架空画像2枚・128項目にRecognizeDocumentsRequestとaccurateのRecognizeTextRequestを適用し、言語ja/en・自動言語判定OFF・言語補正を揃えた。2画像のSHAと256件の各経路固有の候補・スコア、8集計、4呼出しを検証した。
- 各経路の完全一致数は開発側でASCII見出し8/16、日本語見出し13/16、日本語本文14/16、コード8/16。別フォント側では2/16、12/16、10/16、5/16。全8分類で片方だけの完全一致は0件であり、この条件では誤読を相互補完できなかった。候補の一致を採用根拠にはしない。
- 同じ原画像の再認識なので新規独立項目は0、採用0、品質合格ではない。次の色比較でも各経路自身のスコアと原画像を保持し、本来の文書全体評価を代用しない。

### 固定8色・2フォント・2経路の原画像比較

- 研究ソースa29a72d、ネイティブ実行37738592715（macOS 26 / Xcode 26.6）は512件・6skip・失敗0。Hiragino SansとHiragino Minchoの架空文字を1920角の白背景へ描画した。各フォントで文字・大きさ・配置・評価領域を固定し、8色の元画像を両経路へ渡した。色とフォントの変化は独立した新規資料の成功件数に数えない。
- 16画像の個別RGBAハッシュ、1024件の各経路自身の候補・位置・スコア、128集計、32呼出しを保存時の原レコードから再計算して検証した。候補・スコアの置換を認めず、比較は全呼出し完了後に行った。所有する一時レコード・ログは最後に削除し、artifactは保存していない。
- 下表は各色・2フォント合計の文字列完全一致。各欄はDocuments・accurate Textの順で、セル所属・文書全体成功を示さない。

|色|ASCII見出し|日本語見出し|日本語本文|コード|
|---|---|---|---|---|
|black|5/16・5/16|14/16・14/16|14/16・14/16|10/16・10/16|
|navy|7/16・7/16|12/16・12/16|13/16・14/16|7/16・7/16|
|red|8/16・8/16|13/16・13/16|14/16・15/16|7/16・7/16|
|green|7/16・7/16|12/16・12/16|15/16・15/16|9/16・9/16|
|dark-gray|6/16・6/16|13/16・13/16|14/16・14/16|8/16・8/16|
|medium-gray|8/16・8/16|13/16・13/16|14/16・15/16|6/16・6/16|
|light-gray|8/16・8/16|12/16・12/16|14/16・14/16|8/16・8/16|
|very-light-gray|7/16・7/16|9/16・9/16|9/16・9/16|6/16・6/16|

- 色によって改善・悪化が混在し、2経路の集計は64分類中39分類で異なった。Documentsのvery-light-grayはASCII4/16、日本語見出し7/16、日本語本文4/16、コード3/16を取りこぼした。色相と明るさを同時に変えているため、色相だけの優劣とは断定しない。
- Documentsの512項目では正読・誤読とも単一領域の自身confidence≥.85の件数は0だった。accurate Textの512項目では正読75件・誤読30件が自身confidence≥.85となった。経路ごとのスコアは同等ではなく、Textの高いスコアをDocumentsへ移して受理しない。モデル・項目別の校正や独立した評価を行わずにしきい値を下げない。原画像を明るい灰色へ塗り替える処理や配信モデルへの昇格は行っていない。採用0・品質合格ではなく、従来の文書全体評価を代用しない。

## 配布前のリンク操作：座標取得の待機期限

全体実行 [37739675534](https://github.com/n624-dev/takupoke-ios/actions/runs/37739675534)、`fcdbcd6` のiOS27 UI Bは13件中リンク保存テスト1件が失敗しました。原画像ではリンク行が画面内にあり、AXツリーも行205.3〜269.3、ナビゲーション下端165、タブ上端769を示しています。実行ログでは10秒の可視判定中にAX属性取得が遅延し、長押し前に待機期限に達しました。通知設定・画像PDF復旧・明示採用など残る12件は通過しましたが、全体の配布合格には数えません。

可視判定で各frameを一度だけ取得し、待機期限を45秒に変更します。幅・高さの非ゼロ、画面上下境界、enabledの確認を維持し、失敗時は各境界値も記録します。実際の長押しとメニュー操作、再起動後の保存確認は省略しません。修正後の実行は別に確認します。

同じ前回実行の中止後ログも確認すると、iOS27 UI Aの通知更新テストは許可要求後もスイッチがDisabled/value=0のままでした。単一の直後操作では、非同期のOS許可画面がまだ現れずInterruptionMonitorが呼ばれない可能性があります。実際のスイッチは一度だけ押し、未完了時は15秒待機後に無操作のナビゲーションタイトルでmonitorを最大3回dispatchします。OSの許可ボタン以外から許可を設定せず、スイッチの押し直しやfixtureでの有効化は行いません。原因の確定と修正の有効性は集中したnative実行で確認します。後続クラス設定のAX snapshot timeoutも配布合格に含めません。

### 本文訂正の消去操作とAX観測の期限

実行37744475809、ソース0ba3661のiOS27単一訂正ケースは、消去後の5秒のAX待機で失敗しました。実操作の消去ボタンを1回押した後、入力は9バイトから0バイトへ変更され、確認チェックもfalseでした。AXのvalueも空でしたが、その取得だけで待機期限を超えていました。読み取りや消去の失敗とは分け、配布全体の成功とは数えません。

消去・確認スイッチ・採用ボタンの有効状態・キーボード終了の観測期限を45秒へ揃えます。物理操作、全文消去、入力変更による確認解除、全文一致、個別確認、原本変更時の拒否、前回正常結果の保持は引き続き必須です。設定値の注入や判定の省略は行わず、修正後のネイティブ実行で検証します。

実行37747040448のiOS27単一訂正ケースは、再確認画面からの3回目の編集で、先に本文へfocusした後の消去ボタンがキーボード付近に残り、QAの安全なスクロールでは操作領域を確保できず失敗しました。消去・全文入力・確認解除・個別確認・同一プロセスでの背景復帰と訂正レビューまでは通過しています。入力欄を先にタップせず、全文表示した実際の44px消去ボタンを押し、その製品処理がfocusしたネイティブ入力へ全文をタイプする順に変更します。確認の自動付与や値の注入は行いません。

同実行のiOS26の3項目ケースは、アプリを起動できないXcodeのタイムアウトで操作前に失敗しました。アプリ内の訂正判定の失敗とは分け、成功件数には含めません。

### リンク行のAX観測を1回にまとめる

実行37749888072、ソース5bf763bのiOS27 UI Bは12件が成功し、リンク保存1件が長押し前の45秒の観測期限で失敗しました。失敗後の境界値は行205.3〜269.3、ナビゲーション下端165、タブ上端769、有効trueです。predicate内で複数のAX問い合わせを繰り返す処理を、各部品の存在待機と境界の1回取得に分けます。有限・非ゼロの境界、画面内の行、実際の2秒長押し、メニュー選択、再起動後の保存確認を維持します。修正前の失敗を成功には数えません。ローカルPython127件とSwift構文確認は成功し、製品コードは変更していません。

### 設定の行とネイティブSwitchを区別する

同実行のiOS26 UI Bでは、AI・OCR設定の最初の3回の切替とONでの再起動保持は成功しましたが、再起動後のOFF操作は画面・保存値ともONのままで失敗しました。待機期限だけの問題とは扱いません。AXツリーと架空画面の実測では、行の範囲が(16,472.7,361,52.3)、子のネイティブSwitchは(300,485,63,28)でした。行の右端から26pt内側は実コントロールの中心ではありません。

QAでは行の内側にあるSwitchがちょうど1個であること、有限・非空の範囲、行内の包含、有効・操作可能性を確認して、その実コントロールを1回タップします。表示と保存値の両方の確認、ON/OFFでのプロセス再起動、OFF時の復旧禁止は維持します。操作の再試行や設定値の注入は行わず、状態観測の期限を既存の手動訂正QAと同じ45秒にします。製品の設定保存処理は変更せず、修正後の新ソースで全13必須チェックを再実行します。旧実行の成功ケースは新ソースの合格へ流用しません。

### 3項目訂正の探索で復旧sheetを引き下げた失敗

実行37760047573、ソースcef0a5dのiOS27・3項目ケースは、1項目目の全文入力・個別確認と未完成時の送信禁止を通過しましたが、2項目目へ戻るQAスクロールで失敗しました。上部の説明行が181〜249ptで表示されているのに、下向きの全viewportドラッグを146→769ptへ行い、復旧Listが消失しました。crashCauseは未評価で、アプリのクラッシュとは断定しません。native型付き参照の再利用が対象を取りこぼしたかも未確定です。

QAは編集対象の既知IDを各探索で解決し直します。復旧画面を一度確認したら、List消失時に背後の通常画面へ探索を戻さず失敗させます。実際の先頭行が表示された時は、それ以上の下向きドラッグを防ぎ、下向き移動は最大240ptとします。進捗のanchorをList相対位置にし、16回上限と無進捗時の反転1回、全文入力・個別確認・送信禁止・正式採用の検査を維持します。頂点を観測した直後に無進捗判定が下向きへ反転する順序も、実際の純粋状態テストに追加します。製品のView・Coordinator・採用規則は変更しません。

### 通知許可ダイアログを操作しなかったiOS27 QA

実行37760047573のiOS27 UI Bでは通知Switchを1回タップした後、未解決画面のスクリーンショットに実際の通知許可ダイアログが表示されていました。許可の非同期処理中にONになるという期待は成立せず、未解決時点でSwitchはOFF・無効でした。ダイアログの外側にあるNavigationBarへの座標タップ3回は、ログ上で割込み監視を起動していません。一方、次のテストの通常のアプリ要素タップでは、XCTestがダイアログを検出してAllowを操作しています。

この時点ではQAをアプリ全体へのタップに変更しましたが、`app.tap()`の実際の操作位置は画面中央とは保証されません。後続の再調査でこの前提を撤回し、下記の専用操作対象へ置き換えます。実際のAllowボタンを操作し、権限の注入は行いません。操作上限3回、各回15秒の状態観測、通知の有効化と設定保持の確認は維持します。通知の製品実装は変更せず、新ソースのネイティブUI結果で再確認します。


### 画面テスト全体の再読による操作対象・可視判定の修正

実行37763960693、ソース1e252f4のiOS26 UI Aでは実際のSwitch操作後もOFFのままで、未解決画面に許可ダイアログはありませんでした。操作が届かなかったか、後続の汎用`app.tap()`が再操作したかは未確定です。同UI Bのリンク保存は、画面内でhittable=trueの行への座標長押し後もメニューが現れず失敗しました。通常のリンク設定変更や製品の通知許可処理が壊れているとは、このログだけで断定しません。

画面テストを再読し、存在だけで完了する可視判定、復旧sheet内から背後の画面を使う探索、固定比率で押すSwitch、ファイル選択のスクロール前に保持したナビゲーション境界も修正します。実Switchが1個であること・有限で画面内の実境界を確認して中心へ1回タップし、通知割込み監視は設定値を変更しないQA専用Buttonで起動します。実許可とON・保存値を確認後にButtonを閉じます。診断Textは操作を妨げません。hittableなリンクは実要素の長押しを使い、既知のiOS27 AX不一致に限り境界確認済みの座標操作を維持します。

復旧ListにQA専用識別子を付け、存在・画面内の全文表示を確認します。panの開始位置は同じListの受動的なCell内へ限定し、先頭からsheetを引き下げません。手動訂正と選択UIも操作直前の境界を使い、背景からの復帰でアプリ終了を成功に数えません。全文一致、個別確認、採用前の保持、再起動後の保存、許可ダイアログの実操作は省略しません。製品のView・保存・解析規則の変更はありません。修正後ソースの全13必須チェックは別実行で確認します。


実行37769934718、ソース9dcc93bのiOS27単一訂正ケースでは、全文入力・個別確認・送信有効化まで通過後、QAの「架空検証」toolbar Menuを本文の探索に渡して失敗しました。Menuの実境界はy79〜115、本文の探索領域はy141以降で、Listを動かしても到達できません。可視条件の強化時にMenuの専用操作経路を付け忘れたテスト側の不具合です。Menuは実際の復旧navigationBar内の有限・可視・有効な部品から1回開き、3つの既知actionが現れたことを確認後、唯一の可視actionを1回押します。popupは本文Listでscrollしません。値の維持、ACKの維持・編集時解除、原本変更時の拒否は後段の実状態で引き続き確認します。


同実行のiOS26 UI Bでは、リンクの長押し・再起動保存、通知の実許可・ON・保存値・試験返却Switch、並記／通常復旧の採用が通過しました。一方、ホームから時間割へ切り替える最初の操作では、イベントループのidle待機が60秒で戻らず、その後のselected観測が10秒で失敗しました。操作不達・要素参照の再生成・アプリ処理の遅延のどれかは確定していません。QAは実tabBar内の有限・可視・有効なボタン中心へ1回タップし、切替後の要素を再取得して既存の45秒上限内でselectedを確認します。未完了時の実画面とAX情報を記録し、押し直しや期待状態の注入は行いません。


### 全文再調査：存在しない画像、初期設定のfooter、子プロセスの回収

実行37773544786、ソース8b9e6d5は全体の配布条件を満たしていません。Native PDF・復旧505件（専用評価経路1件skip）とiPhoneビルド、iOS26の手動訂正3ケースは成功しました。ホームの時間割切替・リンクの長押しと再起動保存・実通知許可のON保存も両OSで通過しましたが、個別成功を新ソースの配布合格へ流用しません。

iOS27の3項目訂正は、実際の受動的なText行が取得できた後に、存在しないImageのfirstMatch.existsを問い合わせて約5分半停滞しました。anchorは同じ行の取得済みText配列を優先し、Textがない場合だけImage配列を取得する方式に変更します。16回の探索上限、進捗・先頭判定、全文入力・個別確認・採用検証は維持します。

両OSの初期設定ケースは、本文用のtap探索でsafeAreaInsetの「次へ」を本文境界へ収めようとして失敗しました。iOS26の失敗時AXには実ボタンがy767.7〜802.0に残っています。初期設定の現ページと唯一の実footerボタンを確認し、画面内の有限・有効・操作可能な範囲へ1回タップする専用操作に変更します。本文のスクロールや背後の設定tab境界をfooter操作へ使いません。

Linuxの実プロセスによる再現では、timed_commandのleaderが7で終了した後、TERMを無視する子プロセスが旧実装のcleanupを通過して残りました。leaderとは別に所有するprocess group全体を観測し、猶予後に残存groupを終了します。回帰テストは実子プロセスの停止と元の終了コード7の保持を確認し、テスト自身もPID読取前の失敗を含めgroup全体を回収します。

通知QAは今回の起動前にdeliveredだった通知を成功に数えず、起動後の実配信1件・delivered全体1件・非空revisionを要求します。revisionの対象fingerprintとの一致や送信呼出回数の証明とは区別します。製品の通知送信処理や採用規則は変更していません。

iOS27の外観設定ケースは再起動のapp.launch内でaccessibility未読込となりました。原因は未確定です。終了確認後の1回起動と、AXに依存しない固定の起動stage診断を追加し、起動失敗を成功へ救済しません。診断は完全架空アプリの使い捨てcontainer内だけに記録し、文字列・資料・画像を含めず、所有simulatorの削除時に回収します。ローカルテストやSwift構文確認だけでSimulatorの修正成功とは扱いません。


### 背景復帰テストで背景への遷移を確認していなかった条件

同じ実行37773544786の手動訂正ログでは、Home操作直後のstateが4（前景）のままで、その後のactivateを呼んでいました。既存プロセスID・入力・ACKの保持は確認していますが、この条件だけでは背景遷移の証明にはなりません。iOS26の単一訂正ケース通過を、背景移行が確認済みである根拠としては扱いません。

Homeを物理操作した後、45秒以内にrunningBackgroundまたはrunningBackgroundSuspendedを観測してからactivateする条件へ変更します。背景を観測できない、または終了した場合は失敗とし、再起動やdraft再生成で救済しません。編集画面と訂正レビューの両方に同じ条件を適用し、復帰後の同一プロセス・全文・個別ACK・レビュー保持も引き続き要求します。

### iOS26のAI・OCRスイッチで物理操作後もOFFだったケース

実行37781627582、ソースe3d20abのUI Bでは、実Switch枠(300,485,63,28)への1回タップ後もUIと保存値が45秒間0でした。前後の架空画面もOFFで、途中のアプリ再初期化・fixture再seedは記録されていません。製品setterの未配送と二重配送はまだ区別できず、製品の保存処理を原因として断定しません。

QAの物理操作は観測済み実widget中心(331.5,499)をアプリ座標へ固定し、nested AX参照の再解決を避けます。生成した使い捨てアプリコピーに限り、既存setterの直前・直後でrequested/storedのBoolとPID・時刻を記録します。製品setter・待機上限・UIと保存値の両方の検証は維持し、押し直しや保存値の注入をしません。効果は次のnative実行で確認します。

同実行のiOS27単一訂正ケースはXCTest runnerの起動準備中に停止し、テスト本体へ到達していません。背景保持の不合格として集計せず、実行エラーとして扱います。Native PDF・復旧505件（専用評価経路1件skip）、両OSの3項目訂正、iOS26の初期設定footerは通過しましたが、全体の公開条件は未達です。

### スイッチ通過後の資料詳細見出し探索

実行37789317942、ソースa314784のiOS26ではAI・OCRの4回切替、UIと保存値、ON/OFFそれぞれの再起動保持が成功しました。生成コピーの既存setter記録も、各requestedの直後に対応するstoredへ変わることを示しています。次の通常時間割詳細で、状態見出しの探索が6回swipeDown後に失敗しました。

失敗時AXの現在navは通常時間割、下端113です。状態sectionはy113・高さ40.3、同名の行ラベルはy169.3・高さ20.3でした。丸め前の座標と失敗判定時のviewportは未記録なので、原因を丸め差と断定しません。全文レビューで、全画面firstMatchがsectionと行を区別せず、nav/対象frameを別時点で取得してbounce直後に次のgestureへ進む条件を確認しました。

4種の資料詳細に、既存と同じText見出しの固有accessibility identifierを付け、テストは実sectionを一意に選びます。現在のページ名でnavを特定し、最大2秒、厳密包含を待ちます。成立なら探索を終了し、未成立なら次のgestureへ進みます。6回上限、全包含、状態→操作の順序条件を維持し、epsilonや期待値注入で救済しません。失敗した場合の対象frame/viewportも記録します。次のnative確認まで効果は未確認です。

同じa314784のiOS27画面Aは13項目が成功し、実通知許可と起動後の新規配信1件の確認へ到達しました。e3d20abのiOS26単一訂正も、編集・レビュー両方で実背景state3と同一プロセスの状態保持を確認して通過しています。各個別成功を別ソースの公開判定へ流用しません。

### キーボードが開いていない段階のAX探索停止

同じ実行37789317942のiOS27・3項目訂正は、room入力と消去ボタンの取得後、キーボードを開く消去操作より前に失敗しました。ManualAssistanceChecks.swiftのviewport計算で、keyboard.firstMatch.existsの問い合わせが約5分停滞し、AX query timeoutを返しています。入力変更や確認チェックの誤反映が判明した結果ではありません。

手動訂正と通常画面のテストでは、実在するkeyboard配列を1回取得し、0件なら不在、1件なら有限・正寸法のframeを使い、複数なら検証失敗とします。同じ観測frameをviewportと診断に共有し、キーボードの消失も実在配列が空であることを待ちます。入力時の実キーボード出現、全文消去・入力、個別ACK、16回上限、厳密な可視範囲の条件は維持します。Simulatorでの効果は修正版のnative確認まで未確認です。

直前のスクロールにはInvalid frame dimension警告もありました。警告だけから製品の原因を断定せず、キーボード探索停止と同一原因とも扱いません。製品の画像・入力処理は今回変更していません。

### 修正版の結果と短時間の処理中状態を取り逃したQA

cab44eceのfocused実行37798972776では、3項目の訂正・個別確認・採用前レビュー・4項目の拒否が両OSで成功しました。iOS27のInvalid frame dimension警告は残っており、修正済みとは扱いません。全体実行37798976861の単一訂正では、両OSで編集・レビューの実背景state3と同一プロセス保持、採用後の再起動保存が成功しました。

同じ全体実行のiOS27はUI A/Bが失敗しています。UI Aの処理中テストは架空処理のみButtonの操作後、実model.busyの観測までに3秒のworker待機が終了し得る条件でした。QAのworkerを最大60秒のsemaphore待機へ変え、実処理中と授業詳細の保持を確認してから専用Buttonで終了させます。終了後の待機状態、正式更新・原本更新による詳細の閉鎖は引き続き実データで検証します。製品の処理・保存規則は変えません。

iOS27 UI BのAI・OCR Switchは実枠中心への1回操作後もUIと保存値が0で、既存setterへの到達記録はありませんでした。初回起動の別ケースはfixture-readyを記録した後にもapp.launch内でtimeoutしました。前者の原因や後者のAX応答・起動handshake完了は、初期化記録だけから確定しません。

Switchは実control.valueの0/1と行の値の一致を確認し、その観測状態から実trackの反対側1点を選ぶ比較へ変更します。未知値は失敗とし、実枠の一意性・包含・enabled/hittable、UIと保存値、再起動保持を維持します。押し直し・期待値や権限の注入はしません。通知の別失敗はrequesting=trueが残り、失敗画面に許可ダイアログはありませんでした。原因未確定として扱います。初回起動・通知・処理中・設定再起動の4既存ケースをfocusedで再確認し、全13必須チェックの代わりにはしません。

22c8ee2のfocused実行37808331012では両OSの4ケースが成功し、全体実行37811661856も同じソース・試行1の全13チェックが成功しました。反対側の実点操作では、AI・OCRの4回切替、UI/保存値、ON/OFF両方の再起動保持と資料詳細の見出し確認まで通過しています。busy-onlyはホーム・時間割の両方で解除前false/pending、実Button後true/success、既存データ識別値の不変を確認しました。旧cab44eceのiOS26 UI Bも中心操作後にOFFのまま失敗しており、旧全体実行は取消済みです。特定のthumbや起動handshakeを原因として確定した結果ではありません。

iOS27の手動訂正・原本変更にInvalid frame dimension警告が残っています。全件通過を警告解消やOCR品質合格とは扱いません。公開実行37824028785で今回の開発版を公開し、認証なしのIPA/導入手順取得とハッシュ一致を確認しました。追加配布は改善完了まで行いません。

### 公開後のiPhone字体検証：描画の一致と文字の正しさの分離

別の研究ブランチのソース16c6d9b、[37824681486](https://github.com/n624-dev/takupoke-ios/actions/runs/37824681486)はApple環境で519件（1skip・失敗0）とiPhone SDKビルドが成功しました。独立した架空TrueType／ToUnicodeなしPDFで、実際の埋め込みGIDと位置による再描画は800角の全画素で一致し、GID交換・位置変更・GID0・別字体・不可視文字は一致しないことを確認しました。PDFKitの抽出は0件のままで、Strict拒否・capture未完了を維持しています。

研究ソース659c419、[37825645690](https://github.com/n624-dev/takupoke-ios/actions/runs/37825645690)は521件（1skip・失敗0）とiPhone SDKビルドが成功しました。cmapだけをA/B間で交換しても最終画像が変わらない例、異なるGIDが同じ形になる例、通常の可視文字が後続の不透明描画で隠れる例を、追加2テストで実測しています。字体のSHA・対応の一意性・同じ字体の再描画だけを文字の意味の証明にする案は採用しません。

独立した対照と適用範囲・範囲外の拒否条件は引き続き検証が必要です。研究コードは今回の公開版・取得・正式採用・OCRしきい値へ接続しておらず、時間割全体の読み取り率やモデル品質合格に加算しません。学校原本やその文字・画像を使用せず、両実行の所有ビルド領域は最後に削除し、artifact・追加配布物は作成していません。
