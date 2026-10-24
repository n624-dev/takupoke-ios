# 239.1のStrict PDF解析を復元する変更

## 基準と対象

通常時間割・試験時間割・試験返却時間割のStrictを、動作していた239.1の
`bfc599fd5a552ced0c140497c703199547c30fd4`へ戻す。
[239→393の全差分](strict-pdf-diff-239-393.md)は歴史資料として保持する。
今回の変更はR265／R267／R270だけを修理する旧方針を置き換える。
アプリ全体、時間割変更XLSX、学校行事API、Windows、Androidは戻さない。

## 実装の経路

- 通常：`PDFKitReader.read` → `PDF239KitReader` → `PDF239DrawnTextReader`／
  `PDF239PathReader` → `PDFSchoolParser.parse` → `PDF239SchoolParser`／`PDF239Grid`。
- 試験・返却：`PDFKitReader.readSpecial` → `PDF239KitReader`のPDFKit選択経路 →
  `SpecialScheduleParser.parse` → `PDF239SpecialScheduleParser`／`PDF239Grid`。
- 復旧専用：`readCertified`／`readCertifiedSpecial`で追加の表示・所属の証明を取得する。
  `parseCertified`は追加条件を保持する検査用の入口。Strictの入口から呼ばない。
- 旧学校行事PDFは既存経路を維持する。現在の行事表示はAPIである。

通常は描画命令の文字・位置・元の行を直接使い、試験・返却は239.1のPDFKit選択を使う。
現在のStrictを実行してから旧版へ逃がす方式ではない。
新しい役割校正、全年度marker一致、viewport／clip／色差／重なりの追加条件、
ラベルprefix、任意2役割の並記矛盾、固定クラス集合、日付昇順、時刻重複判定は
Strictの成功条件へ入れない。元の8行上限、件数・重複・年度・構造・取消・処理上限は残す。

## 旧版のソースとの一致

復元時の一致記録は以下のとおり。後続の返却時限ラベル修正では
`PDF239SpecialScheduleParser+Pages.swift`と`PDF239SpecialScheduleParser.swift`に、
返却のみクラス表の上端より上の見出しを内容の取得範囲から分離する処理を追加した。
現在の全13ファイルが旧blobと一致するという意味ではない。
通常・試験は239.1の条件を維持し、返却の授業セルも元の構築処理を維持する。
396.1時点では特殊Parser30で同じ内容の旧結果も再解析した。現行の版は下の所属投影節に記載し、実測は検証記録へ分ける。

13ファイルを固定コミットから復元した。型名をPDF239へ分離し、失敗生成箇所へ
新しい固定番号R272〜R422を追加した。既存番号は再割当しない。
型名と失敗メタデータの変更を逆変換した本文は、13ファイルすべて元のblobと全bytes一致した。
下のSHAは元のソースの同一性の記録であり、PDFの正読率を証明するものではない。

| 現在のファイル | 239.1の元ファイル | 元ソースSHA-256 |
|---|---|---|
| PDF239DrawnTextReader.swift | PDFDrawnTextReader.swift | `55c236afc0cd4a60d6f13223405f6f8d4e8d7270cceef5641dfaa82b014bb707` |
| PDF239DrawnTextReader+Fonts.swift | PDFDrawnTextReader+Fonts.swift | `44f65b1327c3279190e2d830281137570cfefc37b56c280fac25037a53c258ec` |
| PDF239TextGeometry.swift | PDFTextGeometry.swift | `883392fd51e2d008c3b75e4c49314931c69f7d2b4942a851971ea2ac314f9a6c` |
| PDF239UnicodeMap.swift | PDFUnicodeMap.swift | `da2338a71789d9ea8c763653a7c2ef97c8b7abc12de41e788f5297b47dfa7c04` |
| PDF239PathReader.swift | PDFPathReader.swift | `45b016e615ddf28fe0b05e67f9f4ff7985729ff1ee2127327a2c0815108a8f04` |
| PDF239Grid.swift | PDFGrid.swift | `fdc6d1501d4700f12aa397b9798d1cec7e12f7de4a26b65fa070429677737cfd` |
| PDF239SchoolParser.swift | PDFSchoolParser.swift | `b877e5fd561153d5f50598cce6d74aac864e5388d0874d7eee469d63a2e80902` |
| PDF239SchoolParser+Timetable.swift | PDFSchoolParser+Timetable.swift | `7c439039085f9d7f2939fb2b96fd4d6d543f69a0c66e16fe6396d6bc7cd8a2ca` |
| PDF239SchoolParser+Events.swift | PDFSchoolParser+Events.swift | `62765f0004a3154f8b873affea4d4e08314a9bb6e9b22f048291d45e4545deae` |
| PDF239SpecialScheduleParser.swift | SpecialScheduleParser.swift | `53d4ea27e9d68b5dcbfd67f03026e239a8bb81e1849b62b1eafc2a698f05c5ca` |
| PDF239SpecialScheduleParser+Pages.swift | SpecialScheduleParser+Pages.swift | `b632d819ae3525385d6dbffd9a6cb1c85c676b448999da5c86dbc8b4ba925153` |
| PDF239SpecialScheduleParser+Times.swift | SpecialScheduleParser+Times.swift | `4b4d25d4202f3819c4031f19806a19b0000bc0356a8f8051bd91748b505d4a9e` |
| PDF239KitReader.swift | PDFKitReader.swift | `8f759e1895a343db163a94346c08844243c72c9e2fd6ade65c1f582c21188323` |

共有モデルの保存形式・任意のRecoveryメタデータは維持し、Strict成功にはRecoveryを付けない。
旧版の未実装機能を説明するnoticesだけは、現在の名称表示・変更反映の説明へ差し替える。
これは採否・値・セル所属を変えない。
通常Parser32、試験／返却29へ進め、同一内容の旧失敗も再解析対象にする。
行事4、XLSX6は維持する。

## 復旧と保存

Strictの成功を復旧captureのcompleteへ昇格しない。captureは空でreaderCompleted=falseを維持する。
ON時の復旧は、失敗した同じ原本を内容SHA・選択・Parser版で確認してから独立して取得する。
旧Readerの文字／罫線取得不足R420・R408だけはunreadableでも復旧候補を提示する。
ファイルサイズ・施錠・文書不正・ページ上限の旧失敗は候補にしない。
復旧Readerでunreadable／limit／cancelledになった場合はOCRへ落とさず終了する。
候補の提示は完全取得や正式採用の証明ではない。
OFFではStrictだけを使い、OCR・モデルをロードしない。
Validator、5状態、原文ID・sources順・セル所属、最大3項目の確認、構造不明の拒否、
明示採用、更新時の確認無効化、前回正常結果の保持は維持する。

## 検証の責務

既存の追加条件の対照は復旧用の入口へ移す。入力・期待値・拒否条件を削らない。
Strictは独立した同じPDFを239.1と現在の本番入口へ通し、全文結果を比較する。
第一年度、旧空欄処理、viewport外相対配置、8行・17件の非固定集合、日付列と時刻の旧扱い、
塗りの旧Reader通過とcapture未完了、復旧候補の限定、同じ内容の旧失敗再解析も検査する。
公開前の全13必須チェック、同一ソース、IPA内版／SHA、AltStore参照先を照合する。
実測・失敗は[検証記録](verification.md)と[改善記録](ocr-improvement-log.md)へ記載する。
実際の3PDFとAltStore更新は実機確認が必要で、CIから確認済みと扱わない。

## 公開と確認範囲

復元ソースb2721dcを0.1.394（394.1）として公開した。
全13必須チェック、両SDKの各Native561件（予定skip1、失敗0）、
36文書・96ページの全文oracle比較、公開IPA・固定AltStore Sourceの匿名照合が成功。
公開後、利用者から3種類の解析が戻った実機報告を受けた。
AltStore更新経路と全授業項目の照合は未確認。詳細は検証記録と[原因調査](strict-pdf-regression-cause.md)へ分ける。

## 位置情報診断と1年の所属投影

返却の本文境界は396.1のクラスセル上端を基本とする。クラス欄が下段見出し帯まで結合されている場合は、
複数日列の明記されたコマ見出しと、その直下の全時限列を横断する実罫線を確認して本文を分離する。
確認できない場合は境界を動かさず、授業本文の同じ語を一律に削除しない。
診断は指定授業の実際の採用行を観測するだけで、
PDF239Gridの既存の行配列を文字列化前に返すhelperへ分離した。受理・行順・結合・空欄の条件は追加しない。
1年の学科移行はStrictの結果を返した後の共通投影で行い、Reader・復旧の証明条件をStrictへ追加しない。
401.1時点のParserは通常33・特殊32。添付原本の位置関係で下段見出しの混入経路を診断した。
独立架空PDFを含む401.1の全13必須検査と公開物照合が成功し、通常Release・固定Sourceへ配布した。
401.1公開後、利用者から返却の時限見出しが授業名へ混入せず、1年授業の学科移行もできたとのiPhone実機報告を受けた。
全授業項目・全PDF経路の網羅的な照合や診断コピーの確認とは区別する。原本はローカル確認後に削除した。

## 原文行順と数値トークンの共通修正（追加issue84/91）

84/91は、StrictとCertifiedの意図した受理差ではなく、両経路が誤った科目/教員や
時刻を正常採用する共通不具合として利用者から修正対象に指定された。
この明示された2条件だけを239.1基準に対する例外とする。

- GridはcontentRowsで確定した縦の行順を保持する。高さの異なる字体の矩形上端で
  再sortしない。横断片の結合、元の読み順、重なり・曖昧な整列の拒否は維持する。
- 時限と時計の数字は途中から/途中まで採用しない。空白正規化で隣接する完全な
  単独/連続見出しを一群として区切り、その外端がUnicode十進数字の途中なら解析を拒否する。
  元の時刻値・順序・重複・件数の検査と、連続時計が未記載の場合の単独時限からの算出は維持する。
  不正な明示時計を未記載と同じ扱いで推測採用しない。新しい境界違反はR424/425で識別し、
  撤回実験の予約R423と既存の番号を再利用しない。

候補のParserは通常34・特殊34。古い解析の再評価でも成功前に正常データを破棄しない。
Reader・可視性・役割校正・復旧証明の追加条件はStrictへ入れず、返却本文境界と
結果後の所属投影も維持する。固定239.1の3全文比較と全既存入力/期待値は変更しない。
実行結果・未確認事項・公開版は[追加issue検証記録](issues-65-103-verification.md)へ分離する。

## 文字対応表の索引と取消（追加issue77）

ToUnicodeの受理条件は239.1を維持し、繰り返すcodespaceの配列走査だけを
65,536位置のparse内索引へ置き換える。重複range・文字の範囲所属と順序、
Strict固有の未使用control mapping拒否、不正UTF16、2MB/65,536対応の上限は変えない。
範囲が有効か確認してからmarkし、既存の固定番号を別の条件へ割り当てない。

token抽出・範囲確認/mark・next・insertで128作業ごとに取消を確認する。
既定のcheckは現在のTask取消を確認し、実font readerは元から持つengine.checkを渡す。
取込中止は正常な既存解析の置換へ進めない。これは受理規則の拡大ではなく、
同じ有限入力を処理する仕事量と取消への応答を改善する変更である。
