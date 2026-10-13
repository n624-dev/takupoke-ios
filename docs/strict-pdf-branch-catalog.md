# Strict PDF解析の詳細番号

通常・試験・試験返却のStrict解析と共通判定の拒否箇所を示す一覧。
原PDFは239.1で読めた時から不変。番号付き版の実機では3種類すべてP12／R126で拒否された。

画面のP01〜P25は大分類、R番号は実装内の失敗生成箇所を示す。
例えばP12とR127なら、罫線の変換・線幅を確認する条件で拒否された。
資料の種類・P番号・R番号・ページ番号だけを伝えればよく、本文や画像は不要。
複合guardは1箇所として扱う。その中のどの条件かまでは番号だけで断定しない。
R126の条件は四隅／R263の辺／R264の根拠／R265の重なりに分離した。旧保存番号は変更しない。
呼出元が分類を付け直した場合、画面のP番号と表の生成時分類が異なる場合がある。

番号は固定enum。既存番号を別の条件へ転用せず、新しい箇所は未使用番号を追加する。
本文・座標・フォント名・色・原本情報を番号に含めず、自動送信や診断コピーを追加しない。
旧保存エラーは番号なしで復元する。手動の解析は新たにReaderを実行する。
番号は拒否理由の識別用。幅広矩形の扱いを修正しても、実資料の復旧は別に確認する。

外部エラーが診断helperで変換された場合、番号は変換箇所を示す。元エラーの原因までは示さない。
共通ヘルパーを復旧処理が使う場合も同じ番号になるため、番号だけで経路は判断しない。

更新: `python3 -B tools/pdf_branch_catalog.py write`。
整合性: `python3 -B tools/pdf_branch_catalog.py check`。学校資料は読み込まない。

## 対応一覧（271箇所）

### ページの文字・罫線が表示範囲に入るか

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R001 | P22 | `guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw` | [確認条件](../Takupoke/PDFAnalysis.swift#L44) |
| R002 | P22 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFAnalysis.swift#L49) |
| R003 | P22 | `guard inside(line.x1,line.y1), inside(line.x2,line.y2) else { throw` | [確認条件](../Takupoke/PDFAnalysis.swift#L54) |

### 文字と選択範囲の対応

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R004 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFCharacterGeometry.swift#L9) |
| R005 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFCharacterGeometry.swift#L16) |

### 色・破線・clip・表示タグ

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R006 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFContentVisibility.swift#L64) |
| R007 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFContentVisibility.swift#L73) |
| R008 | 分類なし／呼出元 | `guard clips.count <= 128 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L102) |
| R009 | 分類なし／呼出元 | `guard comparisons <= 1_000_000 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L107) |
| R010 | P24 | `guard contains(clip, box) else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L109) |
| R011 | P01 | `guard phase.isFinite, phase >= 0, count <= 256 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L121) |
| R012 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFContentVisibility.swift#L126) |
| R013 | P01 | `guard hasPositive else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L130) |
| R014 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFContentVisibility.swift#L155) |
| R015 | P23 | `guard CGPDFScannerPopName(scanner,&name), let name else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L161) |
| R016 | P23 | `guard CGPDFDictionaryGetName(dictionary,"RI",&name), let name else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L167) |
| R017 | P23 | `guard CGPDFScannerPopName(scanner,&pointer), let pointer else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L178) |
| R018 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFContentVisibility.swift#L197) |
| R019 | P23 | `guard CGPDFScannerPopNumber(scanner,&value) else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L202) |
| R020 | P24 | `guard let candidate else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L230) |
| R021 | 分類なし／呼出元 | `guard depth < 64 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L238) |
| R022 | P25 | `guard CGPDFScannerPopObject(scanner, &object), let object else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L241) |
| R023 | P25 | `CGPDFObjectGetValue(resource, .dictionary, &dictionary) else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L247) |
| R024 | P25 | `} else if !CGPDFObjectGetValue(object, .dictionary, &dictionary) { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L248) |
| R025 | P25 | `guard let dictionary else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L249) |
| R026 | P25 | `guard CGPDFDictionaryGetInteger(dictionary, "MCID", &value), value >= 0 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L255) |
| R027 | P25 | `CGPDFStringGetLength(language) <= 256 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L261) |
| R028 | P25 | `guard CGPDFDictionaryGetCount(dictionary) == known else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L264) |
| R029 | P25 | `guard CGPDFScannerPopName(scanner, &tag), let tag, String(cString: tag) != "OC" else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L267) |
| R030 | P25 | `guard depth > 0 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L271) |
| R031 | P25 | `guard depth == 0 else { throw` | [確認条件](../Takupoke/PDFContentVisibility.swift#L275) |

### PDF以外のエラーを失敗表示へ変換

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R032 | 分類なし／呼出元 | `var failure = (error as? PDFParseError) ??` | [確認条件](../Takupoke/PDFDiagnostics.swift#L100) |

### 字体・文字対応表・幅の読み取り

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R033 | P01 | `guard let object = CGPDFContentStreamGetResource(stream, category, name) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L8) |
| R034 | P01 | `guard CGPDFObjectGetValue(object, .dictionary, &dict), let dict = dict else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L10) |
| R035 | P01 | `guard !CGPDFDictionaryGetObject(dict, key, &object), let fallback = fallback else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L21) |
| R036 | 分類なし／呼出元 | `guard selectedFontKeys.count < 128 else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L27) |
| R037 | 分類なし／呼出元 | `guard fonts.count < 128 else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L31) |
| R038 | P01 | `guard !CGPDFDictionaryGetObject(dict, "ToUnicode", &object) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L38) |
| R039 | P01 | `guard let mapStream = mapStream else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L42) |
| R040 | P01 | `guard let data = CGPDFStreamCopyData(mapStream, &format), format == .raw else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L44) |
| R041 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L55) |
| R042 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L60) |
| R043 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L65) |
| R044 | 分類なし／呼出元 | `guard count <= 200_000 else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L72) |
| R045 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L77) |
| R046 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L83) |
| R047 | P01 | `guard i < count else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L91) |
| R048 | P01 | `guard length > 0, length <= 65536 - start else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L94) |
| R049 | P01 | `guard CGPDFArrayGetNumber(list, offset, &value) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L97) |
| R050 | P01 | `guard end >= start, i < count, CGPDFArrayGetNumber(array, i, &value) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L104) |
| R051 | P01 | `guard !CGPDFDictionaryGetObject(metrics, "W", &object) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L111) |
| R052 | P01 | `CGPDFArrayGetCount(array) == Int(last - first + 1) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L117) |
| R053 | P01 | `guard CGPDFArrayGetNumber(array, index, &value) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L120) |
| R054 | P01 | `guard mapping.values.keys.allSatisfy({ widths[$0] != nil }) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader+Fonts.swift#L123) |

### PDF文字描画命令・描画状態

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R055 | P01 | `guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L32) |
| R056 | P01 | `guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L39) |
| R057 | P01 | `guard CGPDFScannerPopString(scanner, &value), let value = value else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L44) |
| R058 | 分類なし／呼出元 | `guard length <= 200_000 else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L49) |
| R059 | P01 | `guard let bytes = CGPDFStringGetBytePtr(value) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L51) |
| R060 | P01 | `CGPDFArrayGetCount(array) <= 100_000 else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L57) |
| R061 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L63) |
| R062 | P01 | `guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L72) |
| R063 | P01 | `} else if CGPDFDictionaryGetObject(dict,"LW",&widthObject) { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L77) |
| R064 | P01 | `else if CGPDFDictionaryGetObject(dict, key, &object) { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L81) |
| R065 | P01 | `CGPDFArrayGetNumber(dash,1,&phase) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L88) |
| R066 | P01 | `guard PDFPaintColors.hasNormalBlendMode(dict) else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L91) |
| R067 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L93) |
| R068 | P01 | `guard let table = CGPDFOperatorTableCreate() else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L110) |
| R069 | P01 | `guard CGPDFScannerPopString(scanner, &text), let text = text else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L166) |
| R070 | P01 | `guard CGPDFScannerPopArray(scanner,&pattern), let pattern else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L186) |
| R071 | P01 | `guard s.engine.glyphs.isEmpty &#124;&#124; s.deferFillValidation else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L200) |
| R072 | P24 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L229) |
| R073 | P01 | `CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L240) |
| R074 | P01 | `guard succeeded else { throw` | [確認条件](../Takupoke/PDFDrawnTextReader.swift#L250) |

### セルの境界・原文の行・授業欄の対応

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R075 | P08 | `guard visits <= 64_000_000 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L15) |
| R076 | P08 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFGrid.swift#L34) |
| R077 | P08 | `glyph.y + glyph.height <= box.bottom else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L70) |
| R078 | P06 | `let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min() else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L83) |
| R079 | P07 | `guard let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L88) |
| R080 | P08 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFGrid.swift#L99) |
| R081 | P13 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFGrid.swift#L124) |
| R082 | 分類なし／呼出元 | `guard input.reduce(0, { $0 + $1.text.utf8.count }) <= 4096 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L153) |
| R083 | P21 | `guard aligned.count <= 1 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L181) |
| R084 | P20 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFGrid.swift#L186) |
| R085 | P08 | `guard cell.top >= row.top-0.8, cell.bottom <= row.bottom+0.8 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L207) |
| R086 | 分類なし／呼出元 | `guard boxes.count <= 10_000 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L209) |
| R087 | P17 | `guard !lines.isEmpty, lines.count < 3 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L220) |
| R088 | P08 | `guard seen.count <= 10000 else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L227) |
| R089 | P17 | `guard rows.count == lines.count else { throw` | [確認条件](../Takupoke/PDFGrid.swift#L244) |
| R090 | P17 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFGrid.swift#L262) |

### ファイル・ページ・PDFKit選択・表示領域

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R091 | 分類なし／呼出元 | `guard let size = size, size > 0, size <= MaterialLibrary.maximumBytes else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L39) |
| R092 | 分類なし／呼出元 | `document.pageCount > 0, document.pageCount <= 12 else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L43) |
| R093 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L51) |
| R094 | P22 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L58) |
| R095 | P22 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L62) |
| R096 | P02 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L67) |
| R097 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L97) |
| R098 | P13 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L101) |
| R099 | 分類なし／呼出元 | `guard textLines.count <= 100000 else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L106) |
| R100 | 分類なし／呼出元 | `guard count <= 100000 else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L112) |
| R101 | P13 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L118) |
| R102 | 分類なし／呼出元 | `guard coveredUnits <= ns.length * 2 else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L121) |
| R103 | P13 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L128) |
| R104 | P13 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L146) |
| R105 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L154) |
| R106 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFKitReader.swift#L161) |
| R107 | P22 | `guard !glyphs.isEmpty else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L204) |
| R108 | P08 | `guard !lines.isEmpty else { throw` | [確認条件](../Takupoke/PDFKitReader.swift#L205) |

### 色空間・ICCプロファイルの支持範囲と上限

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R109 | 分類なし／呼出元 | `guard cache.count < 128 else { throw` | [確認条件](../Takupoke/PDFPaintSpace.swift#L56) |
| R110 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPaintSpace.swift#L58) |
| R111 | 分類なし／呼出元 | `guard length <= 1_048_576 else { throw` | [確認条件](../Takupoke/PDFPaintSpace.swift#L110) |
| R112 | 分類なし／呼出元 | `guard bytes <= 1_048_576, profileBytes <= 4_194_304 - bytes else { throw` | [確認条件](../Takupoke/PDFPaintSpace.swift#L114) |

### 罫線・塗り図形・文字との重なり

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R113 | 分類なし／呼出元 | `guard boxes.count <= 100000 else { throw` | [確認条件](../Takupoke/PDFPathReader.swift#L13) |
| R114 | 分類なし／呼出元 | `(box.right-box.left).isFinite, (box.bottom-box.top).isFinite else { throw` | [確認条件](../Takupoke/PDFPathReader.swift#L19) |
| R115 | 分類なし／呼出元 | `(query.right+pad).isFinite, (query.bottom+pad).isFinite else { throw` | [確認条件](../Takupoke/PDFPathReader.swift#L44) |
| R116 | 分類なし／呼出元 | `if s.operations > 1000000 { s.failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L138) |
| R117 | 分類なし／呼出元 | `guard CGPDFScannerPopNumber(scanner, &n), n.isFinite else { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L146) |
| R118 | 分類なし／呼出元 | `if lines.count > 100000 { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L161) |
| R119 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L169) |
| R120 | 分類なし／呼出元 | `guard consumePaintWork() else { throw failure ??` | [確認条件](../Takupoke/PDFPathReader.swift#L192) |
| R121 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L206) |
| R122 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L214) |
| R123 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L219) |
| R124 | P12 | `塗り矢印が元文字に重なる、または範囲を取得できない` | [確認条件](../Takupoke/PDFPathReader.swift#L229) |
| R125 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L237) |
| R126 | P12 | `矩形の四隅が各1回の対応でない。旧版では辺・原文字範囲・重なりも同じ番号` | [確認条件](../Takupoke/PDFPathReader.swift#L247) |
| R263 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L250) |
| R264 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L253) |
| R265 | P12 | `文字と重なる塗りが文字描画後、線付き、または細い罫線` | [確認条件](../Takupoke/PDFPathReader.swift#L262) |
| R270 | P12 | `背景の塗りに複数subpathがあり、偶奇／windingの穴や消去を除外できない` | [確認条件](../Takupoke/PDFPathReader.swift#L267) |
| R271 | P23 | `背景の単色描画だけでは有効／未知のoverprint合成を確認できない` | [確認条件](../Takupoke/PDFPathReader.swift#L270) |
| R268 | P12 | `背景より前の罫線・矢印・他の描画が背景で消える可能性がある` | [確認条件](../Takupoke/PDFPathReader.swift#L275) |
| R266 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L279) |
| R127 | P12 | `罫線の変換が角度保持でない、または変換後の線幅が支持範囲外` | [確認条件](../Takupoke/PDFPathReader.swift#L299) |
| R128 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L307) |
| R129 | 分類なし／呼出元 | `if collisionBoxes.count > 100_000 { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L314) |
| R130 | 分類なし／呼出元 | `if failure == nil { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L322) |
| R269 | P23 | `背景と後続の罫線・矢印・装飾の色のコントラストを保証できない` | [確認条件](../Takupoke/PDFPathReader.swift#L419) |
| R131 | P24 | `guard let box = rectangularPathBox() else { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L440) |
| R132 | P24 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L443) |
| R133 | 分類なし／呼出元 | `guard clips.count < 128 else { failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L445) |
| R134 | 分類なし／呼出元 | `guard let table = CGPDFOperatorTableCreate() else { throw` | [確認条件](../Takupoke/PDFPathReader.swift#L512) |
| R135 | 分類なし／呼出元 | `if s.stack.count >= 64 { s.failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L516) |
| R136 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L530) |
| R137 | 分類なし／呼出元 | `if s.paths.count > 10000 { s.failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L539) |
| R138 | 分類なし／呼出元 | `if s.paths[s.paths.count - 1].count > 10000 { s.failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L544) |
| R139 | 分類なし／呼出元 | `if s.paths.count > 10000 { s.failure =` | [確認条件](../Takupoke/PDFPathReader.swift#L550) |
| R140 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L576) |
| R141 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L583) |
| R142 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L586) |
| R143 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L590) |
| R144 | P12 | `ExtGStateの透明度・mask・blend・字体・線幅等が支持範囲外` | [確認条件](../Takupoke/PDFPathReader.swift#L595) |
| R145 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L600) |
| R146 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L609) |
| R267 | P23 | `背景と後続文字の実描画色のコントラストを保証できない` | [確認条件](../Takupoke/PDFPathReader.swift#L612) |
| R147 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L617) |
| R148 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L658) |
| R149 | 分類なし／呼出元 | `guard succeeded else { throw` | [確認条件](../Takupoke/PDFPathReader.swift#L673) |
| R150 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L675) |
| R151 | 分類なし／呼出元 | `guard self.consumePaintWork() else { throw self.failure ??` | [確認条件](../Takupoke/PDFPathReader.swift#L679) |
| R152 | 分類なし／呼出元 | `guard consumePaintWork() else { throw failure ??` | [確認条件](../Takupoke/PDFPathReader.swift#L691) |
| R153 | P12 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFPathReader.swift#L698) |

### 旧行事PDFの列・日付・行

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R154 | P09 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Events.swift#L19) |
| R155 | P10 | `guard dateRows.map(\.0) == Array(1...31) else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Events.swift#L27) |
| R156 | P11 | `guard monthTexts.count == 1 else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Events.swift#L38) |
| R157 | P11 | `let month = Int(monthText.dropLast()), months.insert(month).inserted else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Events.swift#L41) |

### 通常時間割のクラス・曜日・時限・授業

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R158 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L10) |
| R159 | P06 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L16) |
| R160 | P14 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L33) |
| R161 | P15 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L39) |
| R162 | P16 | `guard classes.insert(name).inserted else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L42) |
| R163 | 分類なし／呼出元 | `guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L67) |
| R164 | P17 | `guard lines.count <= 3, !lines[0].isEmpty else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L68) |
| R165 | P17 | `guard !lines.contains(where:RecoveryRole.hasLabelPrefix) else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L69) |
| R166 | P18 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L74) |
| R167 | P19 | `if parallel && parts[0].contains(where: { $0.isEmpty }) { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L76) |
| R168 | 分類なし／呼出元 | `if output.count > maximumRecords { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L84) |
| R169 | 分類なし／呼出元 | `guard !classes.isEmpty, !output.isEmpty else { throw` | [確認条件](../Takupoke/PDFSchoolParser+Timetable.swift#L88) |

### 文書全体・年度・資料名・ページ数

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R170 | P03 | `guard normalized.count == originalRanges.count else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L26) |
| R171 | P03 | `!era &#124;&#124; (1...99).contains(value) else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L35) |
| R172 | P03 | `guard (1900...9998).contains(year) else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L37) |
| R173 | P03 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L39) |
| R174 | P03 | `guard let first = markers.first, markers.contains(where:\.isReiwa) else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L48) |
| R175 | P03 | `guard markers.allSatisfy({ $0.year == first.year }) else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L49) |
| R176 | 分類なし／呼出元 | `guard kind != .changes, !pages.isEmpty, pages.count <= 12 else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L57) |
| R177 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L68) |
| R178 | P03 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L85) |
| R179 | P03 | `do { guard try uniqueTitleYear(rawHeading,check:check) == year else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L93) |
| R180 | P03 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L98) |
| R181 | P04 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L107) |
| R182 | P04 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFSchoolParser.swift#L116) |
| R183 | 分類なし／呼出元 | `guard months.isDisjoint(with: parsed.months) else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L123) |
| R184 | 分類なし／呼出元 | `guard months == Set(1...12), !result.events.isEmpty else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L129) |
| R185 | 分類なし／呼出元 | `guard result.lessons.count + result.events.count <= maximumRecords else { throw` | [確認条件](../Takupoke/PDFSchoolParser.swift#L136) |

### 文字の描画状態・文字位置・Unicode照合

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R186 | P01 | `guard n.count == 6, n.allSatisfy(\.isFinite) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L40) |
| R187 | 分類なし／呼出元 | `guard operations <= 1_000_000 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L83) |
| R188 | P01 | `guard let count = counts[op], n.count == count, n.allSatisfy(\.isFinite) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L89) |
| R189 | 分類なし／呼出元 | `guard stack.count < 64 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L94) |
| R190 | P01 | `guard let saved = stack.popLast() else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L97) |
| R191 | P01 | `guard !inText else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L101) |
| R192 | P01 | `guard inText else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L104) |
| R193 | P01 | `guard inText else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L106) |
| R194 | P01 | `guard inText else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L109) |
| R195 | P01 | `guard n[0] >= 0 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L119) |
| R196 | P01 | `guard [0.0, 1, 2].contains(n[0]) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L122) |
| R197 | P01 | `guard n[0] >= 1 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L125) |
| R198 | P01 | `guard [0.0, 1, 2].contains(n[0]) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L130) |
| R199 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L132) |
| R200 | P01 | `guard size.isFinite, size > 0 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L136) |
| R201 | P01 | `guard inText, amount.isFinite else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L140) |
| R202 | P01 | `guard inText, state.size > 0, state.scale > 0 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L145) |
| R203 | P23 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L148) |
| R204 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L152) |
| R205 | P01 | `textUnits + text.utf16.count <= 100_000 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L159) |
| R206 | P01 | `guard (xs + ys).allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L167) |
| R207 | P01 | `guard validGeometry else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L174) |
| R208 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L181) |
| R209 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L190) |
| R210 | P01 | `guard boxes.count == occlusionBounds.count else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L222) |
| R211 | 分類なし／呼出元 | `guard workCount <= 1_000_000 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L226) |
| R212 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFTextGeometry.swift#L233) |
| R213 | P01 | `guard !inText, stack.isEmpty, !glyphs.isEmpty, expectedText.utf16.count <= 100_000 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L239) |
| R214 | P01 | `guard content(drawnText) == content(expectedText) else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L247) |
| R215 | 分類なし／呼出元 | `guard clips.count < 128 else { throw` | [確認条件](../Takupoke/PDFTextGeometry.swift#L254) |

### ToUnicodeの書式・重複・範囲・文字幅

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R216 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L18) |
| R217 | P01 | `box.left < box.right, box.top < box.bottom else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L24) |
| R218 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L31) |
| R219 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L43) |
| R220 | P01 | `!tokens.contains("beginnotdefchar") else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L55) |
| R221 | P01 | `guard value.first == "<", value.last == ">" else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L66) |
| R222 | P01 | `guard !body.isEmpty, body.count % 2 == 0, body.count <= 128 else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L68) |
| R223 | P01 | `guard let b = UInt8(body[cursor..<end], radix: 16) else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L72) |
| R224 | P01 | `guard let count = byteCount, b.count == count else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L79) |
| R225 | P01 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L87) |
| R226 | P01 | `guard i < tokens.count else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L95) |
| R227 | P01 | `guard try next() == "0" else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L101) |
| R228 | P01 | `guard i >= 2, let count = Int(tokens[i - 2]), (1...65536).contains(count) else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L104) |
| R229 | P01 | `byteCount == nil &#124;&#124; byteCount == low.count else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L109) |
| R230 | P01 | `guard l <= h else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L112) |
| R231 | P01 | `guard !covered[code] else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L115) |
| R232 | P01 | `guard high >= low, high - low < 65536 else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L123) |
| R233 | P01 | `guard try next() == "]" else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L127) |
| R234 | P01 | `guard !carry else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L137) |
| R235 | P01 | `guard try next() == ending else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L144) |
| R236 | P01 | `guard let bytes = byteCount, !values.isEmpty else { throw` | [確認条件](../Takupoke/PDFUnicodeMap.swift#L146) |

### 試験・返却のページ構成・日付・クラス

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R237 | P14 | `guard labels.count == columns else { throw` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L14) |
| R238 | P10 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L22) |
| R239 | P05 | `guard step > 5 else { throw` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L56) |
| R240 | P10 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L64) |
| R241 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L74) |
| R242 | P14 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L88) |
| R243 | P15 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L98) |
| R244 | P16 | `guard seenClasses.insert(name).inserted else { throw` | [確認条件](../Takupoke/SpecialScheduleParser+Pages.swift#L101) |

### 試験・返却の時刻・時限

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R245 | P05 | `guard (1...8).contains(count) else { throw` | [確認条件](../Takupoke/SpecialScheduleParser+Times.swift#L6) |
| R246 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Times.swift#L21) |
| R247 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Times.swift#L35) |
| R248 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Times.swift#L42) |
| R249 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser+Times.swift#L49) |

### 試験・返却の文書全体と授業欄

| 詳細番号 | 生成時分類 | 拒否条件／コード抜粋 | 実装 |
|---|---|---|---|
| R250 | P04 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L25) |
| R251 | 分類なし／呼出元 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L38) |
| R252 | P04 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L47) |
| R253 | P03 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L53) |
| R254 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L59) |
| R255 | P10 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L68) |
| R256 | P16 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L72) |
| R257 | 分類なし／呼出元 | `guard lessons.count <= PDFSchoolParser.maximumRecords else { throw` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L76) |
| R258 | 分類なし／呼出元 | `coveredClasses == Set(RecoveryValidator.specialClasses), !lessons.isEmpty else { throw` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L79) |
| R259 | P05 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L111) |
| R260 | P17 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L133) |
| R261 | P17 | `guard !rawLines.contains(where:RecoveryRole.hasLabelPrefix) else { throw` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L136) |
| R262 | P08 | `複合条件の拒否。実装リンクの条件全文を参照` | [確認条件](../Takupoke/SpecialScheduleParser.swift#L141) |
