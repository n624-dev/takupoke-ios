# PDF厳格解析の全差分：239.1 → 380.1

比較元は239.1の`bfc599fd5a552ced0c140497c703199547c30fd4`、
比較先は380.1の配布ソース`bfdf7c51b31d5331a9308ac8cb4ae28388aaa897`。
現在の作業HEADではなく、この2コミットを固定して比較した。
対象は通常時間割・試験時間割・試験返却時間割のStrict Reader、Parser、解析データとエラー契約。
P01／P12以外も含む。本文の照合は原本を使わず、公開ソースの差分で行った。

**輪郭付き文字の拒否だけが差分ではない。**
Readerに増えた表示検査に加え、読み取り後の年度・空欄の位置・行数・並記・日付・時刻・クラス集合も変わった。
入口だけを直しても、これらの後続条件で止まる可能性がある。
利用者の申告は380.1・今回実行した解析・AI／OCR OFFで通常P01、試験P12、返却P12。
古い版・古いエラー表示を原因候補にしない。

## 全行の差分と確認方法

- [省略なしのStrict差分（Markdown）](strict-pdf-diff-239-380.md)：Strict本体18ファイル、124差分区間、1,624行、99,133 bytes。共通判定2箇所は下記へ収録。
- diff本文のSHA-256：`f27ee9776695d2fa05eccdaaf1d661f35ac821e226d997ee5ac8b05a8de91930`。
- `git diff --no-ext-diff --no-renames --unified=0 <比較元> <比較先> -- <下記18ファイル>`で生成した。
- 所有する一時Git領域に比較元の18ファイルを置き、`git apply --unidiff-zero`を実行した。
  適用後の18ファイルが比較先のGit blobと全bytes一致することを確認した。一時領域は削除済み。
- この確認は差分資料の完全性の検証。PDF復旧の実測や、実資料の原因特定・成功の証明ではない。

以下の識別子はこの文書内の整理番号で、アプリが出力する新しい診断コードではない。
「以前は検査なし」は、その部品にその拒否条件がなかったという意味。
任意のPDFが239.1の文書全体解析を通ったという意味ではない。

## 1. Reader入口と文字抽出

根拠：[PDFKitReader](../Takupoke/PDFKitReader.swift)、
[PDFDrawnTextReader](../Takupoke/PDFDrawnTextReader.swift)、
[Fonts](../Takupoke/PDFDrawnTextReader+Fonts.swift)、
[PDFTextGeometry](../Takupoke/PDFTextGeometry.swift)、[PDFUnicodeMap](../Takupoke/PDFUnicodeMap.swift)。

| ID | 239.1から380.1への変更 | 解析への影響 |
|---|---|---|
| I01 | 試験／返却の`readSpecial`が`verifyVisibility: true`で共通Readerを呼ぶ | 以前のPDFKit選択検証に加えて、下記の描画検査が必須になった。設定OFFでも実行される |
| I02 | 通常もPathReaderの`verifyVisibility`が常時true | 以前は文字の直接読取後に罫線を取得していた。現在は罫線取得の前後にも表示条件で停止する |
| I03 | 通常・試験・返却でMediaBoxとCropBoxの完全一致を要求 | 文字が読めてもページ領域が違えばP22。239.1の入口にはこの条件がない |
| I04 | `page.string`が空白だけの場合を明示拒否 | 以前のnil／文字・罫線なしの失敗とは、失敗する位置とエラーが変わる。現在はP22 |
| I05 | 文字取得直後と罫線取得後に`requireVisibleBounds`を呼ぶ | 全文字矩形と全罫線端点がページ内でなければP22。構造Parser側でも再検査する |
| I06 | 通常の後続fill検証をDrawnTextReaderから必須PathReaderへ延期 | `deferFillValidation: true`は塗り罫線修正で導入。単独DrawnTextReaderの既定値はfalse。PathReader成功前に正式な読取成功にはならない |
| I07 | 読取中の文字・罫線をcaptureへ段階別に記録 | ページ数を初期化し、文字だけならpartial、最後にcomplete／partialを記録する。Strictの戻り値とcapture用の文字列は別に保持する |
| I08 | 字形・罫線なしのエラーを分離 | 以前のunreadableから、字形なしP22／罫線なしP08へ変更。診断時点と分類が異なる |
| T01 | 文字描画`Tr`の0／1／2許可を0だけへ変更 | 輪郭のみ・塗り＋輪郭をP01で拒否。導入はa06c82b。380の罫線修正では変わっていない |
| T02 | 空の`Tj`も`engine.show([])`を通す | 以前は空文字なら即return。現在はBT内・正のsize／scale等を確認し、取消しも検出する。空文字だけでfontのUnicode対応は要求しない |
| T03 | fillの可視色検査を実文字使用時に追加 | 文字を表示する時点で白色・未対応の色状態等をP23で拒否する |
| T04 | 制御文字の拒否をToUnicode全体から実使用へ移す | 未使用のNUL等の対応は読み込めるようになった。実際に描く制御文字はP01。単なる厳格化ではなく未使用項目への拒否は緩和された |
| T05 | ToUnicodeがない未使用字体をnil字体として設定可能にする | 239.1は選択時に即拒否。現在は空文字・後で字体を変更する設定を許可し、実文字に使った場合だけP01。明示的に不正なToUnicodeは引き続き拒否 |
| T06 | 選択した字体キーにも128の上限を追加 | 読込済み字体だけでなく、未使用・対応表なしの字体の大量選択も上限で停止する |
| T07 | ToUnicodeの範囲所属検査を有限配列へ変更 | 65,536位置を一度だけ印付けし、重複範囲は引き続き拒否。コード幅・重複対応・縦書き等の既存拒否は維持。字形の意味を新しく推定していない |
| T08 | ToUnicodeのtoken・範囲・対応登録に取消し確認を追加 | 解析が長いときの終了検出が変わる。新しいUnicode推論経路ではない |
| T09 | 描いた空白をRecovery用配列にも保持する | Strictの非空白glyph配列は維持。空白のgeometryが不完全ならcaptureだけpartialとする。この状態だけでStrictを失敗させる追加guardはない |
| T10 | 蓄積したclipに全glyphが収まるか最後にも確認する | P24。後述のclip支持範囲と合わせて働く |

フォントのSubtype、Identity-H、幅、ascent／descent等を読む既存部分と、
PDFKit文字列と描画文字の非空白scalarを照合する`finish`の基本条件は変更されていない。
試験／返却のUTF-16長・選択文字列一致・sourceLine所属・選択矩形の基本検証も差分なし。
研究ブランチの埋め込み字体／GID復旧は、この比較先のStrictへ接続されていない。

## 2. 描画命令・罫線・図形

根拠：[PDFPathReader](../Takupoke/PDFPathReader.swift)、
[PDFDrawnTextReader](../Takupoke/PDFDrawnTextReader.swift)、
[PDFTextGeometry](../Takupoke/PDFTextGeometry.swift)。

| ID | 239.1から380.1への変更 | 解析への影響 |
|---|---|---|
| V01 | `gs`にRI、LW、BMの追加検査 | 通常のDrawnTextReaderでは不正なLW、Normal以外のBM、BMの配列形式を新たに拒否。通常P01になり得る。RIは色検査のエラーになる |
| V02 | PathReaderにも`gs`の検査を追加 | Font／SMask／TR／TR2、dash、LW、BM、alpha等を拒否。試験／返却でP12になり得る。通常でFont／mask／transfer／alphaを拒否する条件自体は239.1のDrawnTextReaderにも既にあった |
| V03 | `/BM /Normal`だけを許可し、配列形式を拒否 | `/BM [/Normal]`もこの実装では拒否される。通常と試験／返却の双方に影響する追加差分で、Trとは別の候補 |
| V04 | PathReaderの非0の`Tr`を拒否 | 試験／返却ではPDFKitで文字を取得できてもP12になる |
| V05 | inline画像`BI/ID/EI`とshading`sh`を拒否 | 通常P01／試験・返却P12になり得る。239.1ではこの命令のcallbackがなかった |
| V06 | 曲線`c/v/y`をStrictでは即拒否 | 239.1は罫線として使えないsubpathを捨てていた。現在は描画前・後続`n`で捨てる場合でも命令を見た段階でP12になり得る |
| V07 | `d`とExtGStateの`D`を検査 | 空pattern・phase0だけを許可。以前はこの検査なし。破線の設定だけでもP12になり得る |
| V08 | 全fillを閉じた軸平行の細い矩形へ限定 | 5点で閉じ、2種類のx／y、各corner一回、各edge軸平行、幅または高さ2.1以下・他方3超を要求。広い背景・highlight・非矩形はP12 |
| V09 | fillと全元glyph矩形の接触・重なりを検査 | 描画順に関係なく、触れる場合も拒否。380では文字後のfillを一律拒否せず、この検査に委ねる |
| V10 | 塗り矢印の三角形もV08の前段で拒否される | 旧来のstem＋triangle検出器は残っているが、Strictではtriangleがそこへ到達できない。単独の矢印検出テスト成功は、この入口の成功を示さない |
| V11 | strokeの変換を厳密な角度保持へ限定 | 非一様拡大・shear等を拒否。ノルムの完全一致と直交を要求する。239.1はこのguardなし |
| V12 | stroke幅の変換後extentに上限を追加 | Frobenius normで見積もり、hairlineも少なくとも1のextent、extent2以下を要求。それを超えるstrokeはP12 |
| V13 | strokeの各edgeを完全な水平／垂直へ限定 | 罫線抽出器の既存0.2許容とは別に、その前段でxまたはyの完全一致を要求する |
| V14 | strokeのpad込みで全元glyphと衝突検査 | glyphへ触れる線をP12で拒否。239.1は衝突検査なし |
| V15 | 描いたpathのboundsをpad込みで蓄積 | clip検証へ使う。100,000の上限も追加 |
| V16 | 衝突検査にx／y索引を追加 | 最終の包含境界込みの判定を維持し、候補を削減する。生成・sort・探索・比較を同じpaintWorkへ計上。不正bounds・オーバーフロー・取消しを検出する |
| V17 | q／QでlineWidthと色状態も保存・復元 | 239.1のPathReaderはCTMだけを保存。状態とstroke検査が対応するようになった |
| V18 | PathReaderの読取終了時にstack空を要求 | 特別の新しいP12候補。通常の文字engineのstack／BT終了検証は以前からある |
| V19 | 操作・衝突の計測／取消し区間を拡張 | 既存paintWork上限1,000,000は同じだが、追加検証も予算を消費する。以前と同じ図形数でも上限に達する可能性を別に評価する |

`Do`（Form XObject等）の拒否、罫線として採用する基本の座標条件、
stemとtriangleから矢印を作る基本ロジックは239.1からある。
`Do`を「新しく増えた拒否」と扱って原因を決めない。

## 3. 色・clip・content tag

根拠：[PDFContentVisibility](../Takupoke/PDFContentVisibility.swift)、
[PDFPaintSpace](../Takupoke/PDFPaintSpace.swift)、[PDFPaintSample](../Takupoke/PDFPaintSample.swift)。
この3ファイルは比較元になく、全体が追加されている。

| ID | 追加・変更された条件 | 解析への影響 |
|---|---|---|
| C01 | DeviceGray／RGB／CMYKのcomponent数・有限値・0〜1範囲を検査 | 以前は色命令の検査なし。文字やpathの可視性へ接続する |
| C02 | 白色と可視inkの判定を追加 | 標準黒は速い経路、対応色はPDF rendererによる単色描画でbrightnessを測る。白境界は254.5／255。白い実文字・罫線等をP23で拒否 |
| C03 | 白い全ページ背景だけに例外を設ける | text・line・arrow・paintedBoxがない時点で、単一の全ページ矩形・fillのみなら許可。部分的な白矩形や後続白塗りは例外にならない |
| C04 | `cs/CS/sc/scn/SC/SCN`、Default色空間、aliasを解釈 | 未対応の実paintを拒否する。未使用の未対応色状態は後で上書き可能。operand読取にも上限がある |
| C05 | CalGray／CalRGBを限定対応 | WhitePoint、BlackPoint、Gamma、Matrix等を検査し、CoreGraphicsの色空間生成と単色PDF描画へ接続する |
| C06 | ICCBasedを限定対応 | Nは1／3／4、Rangeは既定0〜1、Alternateは対応Device名等を要求。profile単体1MiB、合計4MiB等の上限。非既定Range等は拒否 |
| C07 | rendering intentを限定対応 | Perceptual／RelativeColorimetric／Saturation／AbsoluteColorimetricの固定4名称。未知値を拒否 |
| C08 | alias・profile・sampleの処理上限／cacheを追加 | alias深さ8未満、新規解決時の色空間cache件数128未満（最大128）、sample cache最大256等。未知色を推測して許可しない |
| C09 | 単色検証用PDFの生成と小数表記を追加 | 1pixelの色のみを描画。元の文字・画像・授業値は使わない。PDFにない指数表記は通常の小数表記へ展開する |
| C10 | clipを単一の軸平行矩形へ限定 | 通常の239.1は`W/W*`を一律P01拒否。現在は全ページを含む矩形を許可する緩和がある。特別では以前未検査だったclipを新たに検査する |
| C11 | clipが全Mediaページと保持したgeometryを含むことを要求 | 文字のadvance／ascentだけでoutlineの包含を証明しないため、ページ全体を含むことを要求。狭いclip、複数path、非矩形等はP24。clipは最大128 |
| C12 | BMC／BDC／EMCを解釈・depth／終端を検査 | 通常の239.1はBMC／BDCを一律拒否。現在は不活性なタグを許可する緩和もある。特別では新しい検査になる |
| C13 | tagのpropertyをMCID／Langへ限定 | MCID非負整数、Lang文字列256bytes以下、未知property・ActualText等・OCを拒否。depth64未満、閉じ忘れ等はP25 |

新しい色検査を「黒しか許さない」とは説明しない。380は対応する可視色を許可する。
ただし、元から読める文字でも背景・profile・状態の支持範囲によって停止する条件がある。

## 4. 罫線内への文字割当と授業欄

根拠：[PDFGrid](../Takupoke/PDFGrid.swift)。

| ID | 239.1から380.1への変更 | 解析への影響 |
|---|---|---|
| G01 | check付きbox／glyphs／textと共通Calibrationを追加 | 罫線・glyph検索、sort、照合で取消しを確認し、64,000,000 visitsで停止。旧APIも残るがStrictは新しいAPIを使う |
| G02 | glyph中心yの索引で領域検索し、元index順へ戻す | 元の中心座標の0.3余白条件を維持。空間検索でPDFの原順序を変えない |
| G03 | `ocrLineAtom`のセル全体包含条件を追加 | atomは中心だけでセルへ割り当てない。Strictの直接取得glyphはこのflagを設定しないため、通常の直接PDFでは追加拒否の原因にならない |
| G04 | 授業行と時限列から`lessonBoxes`を前計算 | 対象行の内側に収まる罫線セルを要求し、box数10,000等を制限。既存のセル処理より前に追加の罫線不足・不一致・上限エラーが出得る |
| G05 | 1〜2行の欄に`lessonFields`による役割照合を追加 | 239.1の通常は不足分を末尾の空欄にしていた。現在は同じ高さの3行欄の行位置と一意に一致する必要がある |
| G06 | 参照欄にも条件を追加 | 高さ差0.5未満、3行、ラベルprefixなし等を要求。行中心間隔2超、許容差は最大0.75。参照なし・位置不一致・複数参照の矛盾ならP17 |
| G07 | 参照欄／検索のcacheと共通予算を追加 | 有効・無効参照を再利用。参照セル上限10,000。性能だけでなく停止の条件と区間が変わる |
| G08 | fragment照合ループにもcheckを追加 | 既存の原文内順序、上下0.35での行fragment結合、overlap／alignment拒否の基本式は差分なし |

これらは生成AIによる判断ではないが、Strictが復旧用の役割ラベル判定を共通利用している。
`RecoveryRole.hasLabelPrefix`は科目・教員・教室等の固定見出し＋colonを検出する純粋関数。
この呼出しを理由に「設定OFFでAIが実行された」とは説明しない。

## 5. 通常時間割Parser

根拠：[PDFSchoolParser](../Takupoke/PDFSchoolParser.swift)、
[PDFSchoolParser+Timetable](../Takupoke/PDFSchoolParser+Timetable.swift)。

| ID | 239.1から380.1への変更 | 解析への影響 |
|---|---|---|
| N01 | Parserでも全glyph／ruleのページ内包含を要求 | Readerを経ずlayoutを渡してもP22で拒否する |
| N02 | 最初の令和年度matchから`uniqueTitleYear`へ変更 | 令和／西暦の全年度markerを検出し、少なくとも令和markerを必要とし、全markerの年一致を要求。衝突はP03 |
| N03 | 年度の正規化・表記検査を追加 | 空白除去と非数値の互換正規化、元のnumeric scalar／位置保持、令和1〜2桁・西暦4桁・ASCII数字等の条件。不正な追加markerも拒否対象 |
| N04 | 各ページでも一意年度と先頭年の一致を検査 | 最初のmarkerだけの一致では通らない。旧行事Parserの年度処理は元の契約を維持する |
| N05 | 全class行／period列の参照boxを前計算し、check付きAPIへ移行 | G04〜G07が通常時間割にも適用される。先に罫線条件で失敗する場合がある |
| N06 | 科目／教員／教室のラベルprefixを含む授業行を拒否 | 以前はこの条件なし。行数が3でもP17になり得る |
| N07 | 1〜2行を末尾補充から位置での空欄割当へ変更 | 同じ文字でも、役割位置を証明できない場合はP17。room側へ割り当てる等、成功結果の空欄位置が旧版と違う場合もある |
| N08 | 並記の矛盾を「科目＋教員」から「任意の2役割」へ拡張 | 教員＋教室だけが複数記載でも、3行すべて2値の並記でなければP18。1役割だけのcompound literalは維持 |
| N09 | noticesの説明文を更新 | 正式名称は表示時に適用し、変更は日付ごとの表示時に反映すると記載。授業値やその採否を変更する条件ではない |

40時限見出し（1〜8を5回）、通常1ページ、class／gradeの基本表記、
重複class拒否、空科目、room濁点処理、fragmentの基本規則などは既存条件。
この差分で新しく増えた規則として扱わない。

## 6. 試験・試験返却Parser

根拠：[SpecialScheduleParser](../Takupoke/SpecialScheduleParser.swift)、
[Pages](../Takupoke/SpecialScheduleParser+Pages.swift)、[Times](../Takupoke/SpecialScheduleParser+Times.swift)。

| ID | 239.1から380.1への変更 | 解析への影響 |
|---|---|---|
| S01 | Parserでも全glyph／ruleのページ内包含を要求 | P22。相対的に正しい表だけでは成功にならない |
| S02 | 全ページの年度を通常と同じ一意marker検証へ変更 | N02〜N03が適用される。資料名と返却の判定は年度抽出より先になったため、複数不正時の最初のエラーも変わる |
| S03 | 17classという件数から固定集合との完全一致へ変更 | 1年3組、2〜5年のCN／ES／IT、AI2組の固定17classに一致する必要がある。件数だけが同じ別集合はunsupported（stage指定なし） |
| S04 | 試験・返却で参照boxを前計算し、gridを共有する | G04〜G07が適用。追加の罫線条件とCalibration上限が働く |
| S05 | 授業欄の最大8行を最大3行へ変更 | 4〜8行は旧版の授業行保持まで進めたが、現在はP17で停止する |
| S06 | 1〜2行の欄も役割位置で3fieldへ再構築 | 旧版は読み取った行配列を保持。現在は位置を証明して空欄を入れるため、結果の`lines`の内容・長さも変わり得る |
| S07 | 科目／教員／教室等のラベルprefixを拒否 | 3行以内でもP17になり得る |
| S08 | 返却の5日付を左から厳密な昇順に限定 | 件数5・重複なしに加わった新条件。最初の列へ特別時刻を適用する前にP10で拒否する |
| S09 | 単一時限の時刻を隣接順に検査 | 件数1〜8を限定し、前時限終了が次時限開始以下でなければP05。明示された連続時限chartは別に維持する |
| S10 | lessonsへcheckと共有gridを渡す | 毎回grid生成していた経路から共通の検索／cache／予算へ変わる |

試験6ページ・返却1ページ、5日、基本の日付読取、各ページの時刻chart一致、
class重複、最大授業数10,000、セルが覆う時限、連続時限の原文時刻の使用、
複数lessonを作るセル分割の基本規則は維持されている。

## 7. 解析データ・エラー契約

根拠：[PDFAnalysis](../Takupoke/PDFAnalysis.swift)、
[PDFParseError](../Takupoke/PDFParseError.swift)、[SpecialSchedule](../Takupoke/SpecialSchedule.swift)。

| ID | 変更 | Strictとの関係 |
|---|---|---|
| M01 | glyph／rule／layout／arrowへSendableを追加 | 並行処理の型契約。これだけで読める内容は変わらない |
| M02 | glyphへ任意の`ocrLineAtom`を追加 | G03用。直接読取でflagは立てない |
| M03 | 通常Parser版8→28、特別6→25 | 解析結果の版と再解析判断に使う。旧行事版4は維持 |
| M04 | 解析結果へ任意のRecovery payloadを追加 | Strictが返す通常／特別結果ではnil。これだけで生成AI結果へ置換しない |
| M05 | `periodTime`にRecoveryの時刻優先を追加 | payloadがある結果だけの分岐。Strictのnil結果の既存時刻経路は維持 |
| M06 | PDFParseAttemptへParser版・Recovery job・needsAnalysisを追加 | 解析前の実行判断の契約。今回の申告は新しい解析なので古い失敗表示の説明に使わない |
| M07 | P22／P23／P24／P25をStageへ追加 | raster／可視性／clip／tagで新しい分類。P01／P12の基本名称は同じで、下位分岐すべてを区別しない |
| M08 | unreadableの文言から画像PDF非対応の断定を除去 | エラー文の変更。Strictで画像だけのページが成功する変更ではない |

## 8. 差分のない部品・検証できていないこと

Git blobの一致を確認したStrict関連部品は`PDFCharacterGeometry.swift`、
`PDFDiagnostics.swift`、`PDFSchoolParser+Events.swift`、`SchoolDate.swift`、
`MaterialLibrary+Validation.swift`。
`ChangeNormalizer.canonicalClassName`の関数と`TimetableLessonNames`のStrict用field／initializerも差分なし。
共通ファイルに他用途の変更があっても、それをStrictの新規則と混同しない。

新しいStrict依存は、上記の`RecoveryRole.hasLabelPrefix`と
`RecoveryValidator.specialClasses`の純粋な判定／固定集合。
それぞれの追加元は[RecoveryModels](../Takupoke/RecoveryModels.swift)と
[RecoveryValidator](../Takupoke/RecoveryValidator.swift)。この監査ではStrictが使う部分だけを確認した。
Strictから新たに呼ぶ2箇所の定義も、固定した比較先から以下へそのまま抜き出した。
比較元には両ファイルが存在せず、この共通判定への接続は新規追加。

```swift
enum RecoveryRole: String, Codable, CaseIterable, Sendable { case subject, teacher, room
    var labels: [String] { switch self { case .subject: return ["科目", "科目名", "授業", "授業名", "授業科目"]; case .teacher: return ["教員", "教員名", "教師", "教師名", "担当", "担当者", "担当教員"]; case .room: return ["教室", "教室名", "授業教室", "場所", "会場"] } }
}
extension RecoveryRole {
    static func hasLabelPrefix(_ value: String) -> Bool {
        let compact = value.filter { !$0.isWhitespace }.replacingOccurrences(of:"･",with:"・")
        return compact.components(separatedBy:"・").contains { part in
            allCases.flatMap(\.labels).contains { part.hasPrefix($0+":") || part.hasPrefix($0+"：") }
        }
    }
}

static let specialClasses = ["1_1", "1_2", "1_3"] + (2...5).flatMap { year in ["CN", "ES", "IT"].map { "\(year)_\($0)" } } + ["AI_1", "AI_2"]
```

特に追加拒否との互換性を別途評価すべきものは、
文字描画mode、BM配列等のgraphics state、inline画像／shading、curve／dash、
塗り矢印、背景／stroke条件、年度の追加marker、短い授業欄、4〜8行の試験欄、
class集合、日付順・時刻順。
必要な拒否と過剰拒否を一括で解除せず、元の採否とgeometryの両方を確認する。

現在の`testOnlyFilledTextModeHasAnIndependentGlyphExtentProof`は非0の一律拒否を期待する。
`testPDFPathPaintPreservesFilledRulesAndUniqueArrow`は既定のvisibility検証なしのReader、
`testPDFKitBridgeRecognizesFilledArrowGeometry`は`.events`を通す。
これらの成功だけでは、通常／試験／返却のStrict入口の旧対応範囲を証明できない。
日付順・時刻順等の新規則にも、現在の拒否を期待するテストがある。
旧版が通した独立資料を旧／現行の全経路へ同じ条件で渡す比較は、まだ完了していない。

今回実施したのは全Strict差分の静的照合と差分資料のbytes検証。
実資料のどの条件が発火したかは未特定で、原因確定・改善成功・互換性合格とは記載しない。
原本の再取得・直接テスト、製品コード／テスト期待値の変更、Actions開始は行っていない。

## 9. ファイル単位の漏れ確認

以下は固定コミット間の全Strict差分。行数はGit numstatで、動作ケース数ではない。
124区間すべての生差分は冒頭のMarkdownのdiff本文へ保持している。

| ファイル | 追加行 | 削除行 | 区間数 |
|---|---:|---:|---:|
| [PDFAnalysis.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFAnalysis.swift) | 28 | 5 | 8 |
| [PDFContentVisibility.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFContentVisibility.swift) | 231 | 0 | 1 |
| [PDFDrawnTextReader+Fonts.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFDrawnTextReader+Fonts.swift) | 13 | 3 | 4 |
| [PDFDrawnTextReader.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFDrawnTextReader.swift) | 89 | 3 | 10 |
| [PDFGrid.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFGrid.swift) | 155 | 3 | 6 |
| [PDFKitReader.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFKitReader.swift) | 54 | 15 | 16 |
| [PDFPaintSample.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFPaintSample.swift) | 68 | 0 | 1 |
| [PDFPaintSpace.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFPaintSpace.swift) | 146 | 0 | 1 |
| [PDFParseError.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFParseError.swift) | 15 | 2 | 5 |
| [PDFPathReader.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFPathReader.swift) | 313 | 6 | 14 |
| [PDFSchoolParser+Timetable.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFSchoolParser+Timetable.swift) | 18 | 10 | 9 |
| [PDFSchoolParser.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFSchoolParser.swift) | 74 | 10 | 6 |
| [PDFTextGeometry.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFTextGeometry.swift) | 59 | 6 | 14 |
| [PDFUnicodeMap.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/PDFUnicodeMap.swift) | 30 | 10 | 9 |
| [SpecialSchedule.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/SpecialSchedule.swift) | 3 | 1 | 3 |
| [SpecialScheduleParser+Pages.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/SpecialScheduleParser+Pages.swift) | 10 | 7 | 9 |
| [SpecialScheduleParser+Times.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/SpecialScheduleParser+Times.swift) | 9 | 0 | 2 |
| [SpecialScheduleParser.swift](https://github.com/n624-dev/takupoke-ios/blob/bfdf7c51b31d5331a9308ac8cb4ae28388aaa897/Takupoke/SpecialScheduleParser.swift) | 17 | 12 | 6 |
| 合計 | 1332 | 93 | 124 |
