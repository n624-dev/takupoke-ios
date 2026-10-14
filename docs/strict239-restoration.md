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
実際の3PDFでの復元成功と実機導入は未確認。詳細は検証記録へ分ける。
