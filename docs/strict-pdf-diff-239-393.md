# 厳格なPDF解析の差分：239.1 → 393.1

比較元：239.1 `bfc599fd5a552ced0c140497c703199547c30fd4`。
比較先：393.1 `8fdaac45467086c29115f95c04977fbc829d0fc5`。
対象は通常・試験・試験返却のStrict本体21ファイルと、そこから呼ばれる追加の共通判定2箇所。
変更行数には枝番号・Parser版・記録用項目も含む。行数を追加の拒否条件数とは扱わない。

## 現在も残る主な動作差分

| 分野 | 239.1からの現在の変更 |
|---|---|
| 表示範囲 | MediaBox／CropBox一致、文字・罫線・輪郭のページ内／clip包含の追加検査 |
| 描画 | 塗り・線・輪郭と文字の衝突、線幅・変換・曲線・破線等の使用時検査 |
| 色と表示属性 | 実際に使う色、alpha／blend／mask、content tagの検査。393.1では背景の色差・描画順・複合path・overprintの検査も追加 |
| 年度 | 最初の令和markerだけでなく、検出した年度marker全体の一致を要求 |
| 空欄の役割 | 末尾への空欄補充／原行保持から、位置参照による科目・教員・教室の割当へ変更 |
| 授業欄 | ラベルprefix拒否。通常の並記矛盾判定を任意の2役割へ拡張。試験／返却の上限を8行から3行へ変更 |
| クラス集合 | 試験／返却を17クラスという件数から固定集合との一致へ変更 |
| 日付・時刻 | 返却の日付列を左から昇順に要求。隣接する単独時限の時間重複を拒否 |
| 処理・記録 | 取消・処理予算・索引・cache、partial／complete記録、Parser版、固定の枝番号を追加／変更 |

上記は現在のコードに残る差分であり、今回の各原PDFで発火したと断定するものではない。
R265／R267／R270で止まっているため、読み取り後の年度・授業欄等まで通過するかは実機未確認。
独立3設計・36表現・96ページの比較成功は、上記全条件や全学校書式の互換性合格ではない。
必要な拒否と互換性を評価する対象を区別し、授業投影まで239.1と候補版を同じ入力で比較する。

Tr1／2の一律拒否、Normal単要素配列、破棄する曲線、未使用の破線、塗り矢印は
380.1の時点から後に限定修正されている。239→380の旧監査を393.1の現状とは扱わない。
詳細は[互換性修正](strict-pdf-compatibility-repair.md)と[未実装方針](strict-pdf-regression-plan.md)へ分ける。

## 差分資料の完全性

`git diff --no-ext-diff --no-renames --unified=0`で、固定した2コミットの下記21ファイルを取得した。
所有する一時Git領域へ比較元を置き、このdiffをapplyした後、21ファイルすべてが比較先blobと
全bytes一致することを確認した。一時領域は削除した。原本PDF・実際の名前・本文は使っていない。
これは差分資料の完全性の確認であり、PDFの復旧実測ではない。

diff本文：172,379 bytes、SHA-256 `e2bf1483208608db3267c66b49389a0f87f44934e4928b889e8bcda1e6201c1b`。

| ファイル | 追加行 | 削除行 |
|---|---:|---:|
| [Takupoke/PDFAnalysis.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFAnalysis.swift) | 28 | 5 |
| [Takupoke/PDFCharacterGeometry.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFCharacterGeometry.swift) | 2 | 2 |
| [Takupoke/PDFContentVisibility.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFContentVisibility.swift) | 278 | 0 |
| [Takupoke/PDFDrawnTextReader+Fonts.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFDrawnTextReader+Fonts.swift) | 50 | 24 |
| [Takupoke/PDFDrawnTextReader+GlyphBounds.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFDrawnTextReader+GlyphBounds.swift) | 55 | 0 |
| [Takupoke/PDFDrawnTextReader.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFDrawnTextReader.swift) | 125 | 17 |
| [Takupoke/PDFEncodedGlyphMap.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFEncodedGlyphMap.swift) | 76 | 0 |
| [Takupoke/PDFGrid.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFGrid.swift) | 162 | 10 |
| [Takupoke/PDFKitReader.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFKitReader.swift) | 82 | 29 |
| [Takupoke/PDFPaintSample.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFPaintSample.swift) | 68 | 0 |
| [Takupoke/PDFPaintSpace.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFPaintSpace.swift) | 146 | 0 |
| [Takupoke/PDFParseError.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFParseError.swift) | 161 | 12 |
| [Takupoke/PDFPathReader.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFPathReader.swift) | 497 | 18 |
| [Takupoke/PDFSchoolParser+Timetable.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFSchoolParser+Timetable.swift) | 29 | 21 |
| [Takupoke/PDFSchoolParser.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFSchoolParser.swift) | 81 | 17 |
| [Takupoke/PDFTextGeometry.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFTextGeometry.swift) | 149 | 24 |
| [Takupoke/PDFUnicodeMap.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/PDFUnicodeMap.swift) | 62 | 28 |
| [Takupoke/SpecialSchedule.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/SpecialSchedule.swift) | 3 | 1 |
| [Takupoke/SpecialScheduleParser+Pages.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/SpecialScheduleParser+Pages.swift) | 18 | 15 |
| [Takupoke/SpecialScheduleParser+Times.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/SpecialScheduleParser+Times.swift) | 12 | 3 |
| [Takupoke/SpecialScheduleParser.swift](https://github.com/n624-dev/takupoke-ios/blob/8fdaac45467086c29115f95c04977fbc829d0fc5/Takupoke/SpecialScheduleParser.swift) | 28 | 23 |

## 省略なしのStrict本体diff

```diff
diff --git a/Takupoke/PDFAnalysis.swift b/Takupoke/PDFAnalysis.swift
index 937c68c..e4b4fc8 100644
--- a/Takupoke/PDFAnalysis.swift
+++ b/Takupoke/PDFAnalysis.swift
@@ -10 +10 @@ enum PDFDisplayText {
-struct PDFGlyph: Codable {
+struct PDFGlyph: Codable, Sendable {
@@ -17,0 +18,2 @@ struct PDFGlyph: Codable {
+    /// Whole native OCR literal; it cannot be split or assigned by its centre.
+    var ocrLineAtom: Bool? = nil
@@ -21 +23 @@ struct PDFGlyph: Codable {
-struct PDFRule: Codable {
+struct PDFRule: Codable, Sendable {
@@ -29 +31 @@ struct PDFRule: Codable {
-struct PDFPageLayout: Codable {
+struct PDFPageLayout: Codable, Sendable {
@@ -34,0 +37,20 @@ struct PDFPageLayout: Codable {
+
+    /// Relative table geometry alone does not prove that any text is displayed.
+    /// School schedules may reuse a native layout only within its viewport.
+    func requireVisibleBounds(check: () throws -> Void = {}) throws {
+        func inside(_ x: Double, _ y: Double) -> Bool {
+            x.isFinite && y.isFinite && x >= 0 && y >= 0 && x <= width && y <= height
+        }
+        guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw PDFParseError(code:.unsupported,stage:.rasterInput, branch:.b001) }
+        for (index,glyph) in glyphs.enumerated() {
+            if index % 128 == 0 { try check() }
+            guard glyph.width.isFinite, glyph.height.isFinite, glyph.width >= 0, glyph.height >= 0,
+                  inside(glyph.x,glyph.y), inside(glyph.x+glyph.width,glyph.y+glyph.height) else {
+                throw PDFParseError(code:.unsupported,stage:.rasterInput, branch:.b002)
+            }
+        }
+        for (index,line) in lines.enumerated() {
+            if index % 128 == 0 { try check() }
+            guard inside(line.x1,line.y1), inside(line.x2,line.y2) else { throw PDFParseError(code:.unsupported,stage:.rasterInput, branch:.b003) }
+        }
+    }
@@ -36 +58 @@ struct PDFPageLayout: Codable {
-struct PDFArrow: Codable { var x: Double; var top: Double; var bottom: Double }
+struct PDFArrow: Codable, Sendable { var x: Double; var top: Double; var bottom: Double }
@@ -157 +179 @@ struct PDFAnalysis: Codable {
-    static let parserVersion = 8
+    static let parserVersion = 31
@@ -169,0 +192 @@ struct PDFAnalysis: Codable {
+    var recovery: RecoveryAdopted? = nil
diff --git a/Takupoke/PDFCharacterGeometry.swift b/Takupoke/PDFCharacterGeometry.swift
index e378fd2..11d0e00 100644
--- a/Takupoke/PDFCharacterGeometry.swift
+++ b/Takupoke/PDFCharacterGeometry.swift
@@ -9 +9 @@ enum PDFCharacterGeometry {
-            throw PDFParseError(code: .unsupported, stage: .characterMapping)
+            throw PDFParseError(code: .unsupported, stage: .characterMapping, branch:.b004)
@@ -16 +16 @@ enum PDFCharacterGeometry {
-                throw PDFParseError(code: .unsupported, stage: .characterMapping)
+                throw PDFParseError(code: .unsupported, stage: .characterMapping, branch:.b005)
diff --git a/Takupoke/PDFContentVisibility.swift b/Takupoke/PDFContentVisibility.swift
new file mode 100644
index 0000000..66d3475
--- /dev/null
+++ b/Takupoke/PDFContentVisibility.swift
@@ -0,0 +1,278 @@
+import Foundation
+#if canImport(CoreGraphics)
+import CoreGraphics
+#endif
+
+// Device color assignments are state, not paint. Reject unsupported visible
+// paint when used; an unused white stroke must not reject black filled text.
+struct PDFDevicePaint {
+    var components = [0.0]
+    var count = 1
+    #if canImport(CoreGraphics)
+    var resolvedSpace: PDFPaintSpace?
+    var renderingIntent = CGColorRenderingIntent.defaultIntent
+    private let deviceSpaces = [PDFPaintSpace.device(1),PDFPaintSpace.device(3),PDFPaintSpace.device(4)]
+    private var interpretedSpace: PDFPaintSpace? {
+        if let resolvedSpace { return resolvedSpace }
+        switch count {
+        case 1: return deviceSpaces[0]
+        case 3: return deviceSpaces[1]
+        case 4: return deviceSpaces[2]
+        default: return nil
+        }
+    }
+    #endif
+    var isBlack: Bool { PDFTextVisibility.blackColor(components, count: count) }
+    #if canImport(CoreGraphics)
+    // Use Quartz's interpretation, including calibrated/ICC/default spaces.
+    // Raw component equality cannot certify contrast against a colored fill.
+    var renderedBrightness: Double? {
+        interpretedSpace?.brightness(components, intent: renderingIntent)
+    }
+    #endif
+    var isWhite: Bool {
+        #if canImport(CoreGraphics)
+        if resolvedSpace == nil && isBlack { return false }
+        if resolvedSpace == nil && (count == 4 ? components == [0,0,0,0] : components.allSatisfy({ $0 == 1 })) { return true }
+        if let interpretedSpace {
+            guard let sample = interpretedSpace.brightness(components,intent:renderingIntent) else { return false }
+            return sample >= 254.5 / 255
+        }
+        #endif
+        return count == 4 ? components == [0, 0, 0, 0] : components.allSatisfy { $0 == 1 }
+    }
+    var isVisibleInk: Bool {
+        guard !isWhite else { return false }
+        #if canImport(CoreGraphics)
+        if resolvedSpace == nil && isBlack { return true }
+        if let interpretedSpace {
+            guard let sample = interpretedSpace.brightness(components,intent:renderingIntent) else { return false }
+            return sample < 254.5 / 255
+        }
+        #endif
+        return count == 4 || components.contains { $0 < 254.5 / 255 }
+    }
+    mutating func device(_ values: [Double], count: Int) throws {
+        #if canImport(CoreGraphics)
+        resolvedSpace = nil
+        #endif
+        try set(values, count: count)
+    }
+    mutating func set(_ values: [Double], count: Int) throws {
+        guard [1, 3, 4].contains(count), values.count == count,
+              values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
+            throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b006)
+        }
+        self.count = count; components = values
+    }
+    mutating func space(_ name: String) throws {
+        switch name {
+        case "DeviceGray": try device([0], count: 1)
+        case "DeviceRGB": try device([0, 0, 0], count: 3)
+        case "DeviceCMYK": try device([0, 0, 0, 1], count: 4)
+        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b007)
+        }
+    }
+}
+
+struct PDFPaintColors {
+    var fill = PDFDevicePaint(), stroke = PDFDevicePaint()
+
+    func canPaintText(mode: Double) -> Bool {
+        switch mode {
+        case 0: return fill.isVisibleInk
+        case 1: return stroke.isVisibleInk
+        // Fill is drawn first. A white fill still leaves the subsequent visible
+        // outline; an unknown fill or a white erasing outline is not certified.
+        case 2: return stroke.isVisibleInk && (fill.isVisibleInk || fill.isWhite)
+        default: return false
+        }
+    }
+}
+
+enum PDFClipValidation {
+    static func contains(_ outer: PDFBox, _ inner: PDFBox) -> Bool {
+        guard [outer.left,outer.top,outer.right,outer.bottom,inner.left,inner.top,inner.right,inner.bottom].allSatisfy(\.isFinite),
+              outer.left < outer.right, outer.top < outer.bottom,
+              inner.left <= inner.right, inner.top <= inner.bottom else { return false }
+        return outer.left <= inner.left && outer.top <= inner.top &&
+        inner.right <= outer.right && inner.bottom <= outer.bottom
+    }
+    static func requireContains(_ boxes: [PDFBox], clips: [PDFBox], work: () throws -> Void = {}, check: () throws -> Void) throws {
+        guard clips.count <= 128 else { throw PDFParseError(code: .limit, branch:.b008) }
+        var comparisons = 0
+        for clip in clips { for box in boxes {
+            try work()
+            comparisons += 1
+            guard comparisons <= 1_000_000 else { throw PDFParseError(code: .limit, branch:.b009) }
+            if comparisons % 128 == 0 { try check() }
+            guard contains(clip, box) else { throw PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b010) }
+        } }
+        try check()
+    }
+}
+
+#if canImport(CoreGraphics)
+import CoreGraphics
+
+extension PDFPaintColors {
+    static func isSolidDash(_ pattern: CGPDFArrayRef, phase: Double) throws -> Bool {
+        let count = CGPDFArrayGetCount(pattern)
+        guard phase.isFinite, phase >= 0, count <= 256 else { throw PDFTextFailure.unsupported(.b011) }
+        var hasPositive = count == 0
+        for index in 0..<count {
+            var value: CGPDFReal = 0
+            guard CGPDFArrayGetNumber(pattern,index,&value), value.isFinite, value >= 0 else {
+                throw PDFTextFailure.unsupported(.b012)
+            }
+            hasPositive = hasPositive || value > 0
+        }
+        guard hasPositive else { throw PDFTextFailure.unsupported(.b013) }
+        return count == 0
+    }
+    // A singleton /Normal array has the same effective blend mode as /Normal.
+    // Mixed alternatives remain outside the supported subset.
+    static func hasNormalBlendMode(_ dictionary: CGPDFDictionaryRef) -> Bool {
+        var object: CGPDFObjectRef?
+        guard CGPDFDictionaryGetObject(dictionary, "BM", &object) else { return true }
+        var name: UnsafePointer<CChar>?
+        if CGPDFDictionaryGetName(dictionary, "BM", &name), let name {
+            return String(cString: name) == "Normal"
+        }
+        var array: CGPDFArrayRef?
+        guard CGPDFDictionaryGetArray(dictionary, "BM", &array), let array,
+              CGPDFArrayGetCount(array) == 1,
+              CGPDFArrayGetName(array, 0, &name), let name else { return false }
+        return String(cString: name) == "Normal"
+    }
+    mutating func intent(_ name: String) throws {
+        let value: CGColorRenderingIntent
+        switch name {
+        case "Perceptual": value = .perceptual
+        case "RelativeColorimetric": value = .relativeColorimetric
+        case "Saturation": value = .saturation
+        case "AbsoluteColorimetric": value = .absoluteColorimetric
+        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b014)
+        }
+        fill.renderingIntent = value; stroke.renderingIntent = value
+    }
+    mutating func intent(_ scanner: CGPDFScannerRef) throws {
+        var name: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner,&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b015) }
+        try intent(String(cString:name))
+    }
+    mutating func applyIntent(_ dictionary: CGPDFDictionaryRef) throws {
+        var object: CGPDFObjectRef?, name: UnsafePointer<CChar>?
+        guard CGPDFDictionaryGetObject(dictionary,"RI",&object) else { return }
+        guard CGPDFDictionaryGetName(dictionary,"RI",&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b016) }
+        try intent(String(cString:name))
+    }
+}
+
+extension PDFDevicePaint {
+    mutating func applyDefault(_ scanner: CGPDFScannerRef, resolver: PDFPaintSpaceResolver) throws {
+        resolvedSpace = try resolver.deviceDefault(scanner, count: count)
+    }
+    mutating func space(_ scanner: CGPDFScannerRef, resolver: PDFPaintSpaceResolver) throws {
+        var pointer: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner,&pointer), let pointer else { throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b017) }
+        let name = String(cString:pointer)
+        if ["DeviceGray", "DeviceRGB", "DeviceCMYK"].contains(name) {
+            try space(name); try applyDefault(scanner, resolver: resolver)
+        } else {
+            let space = try resolver.named(scanner, name: name)
+            count = space.count
+            components = count == 4 ? [0,0,0,1] : Array(repeating:0,count:count)
+            resolvedSpace = space.device ? try resolver.deviceDefault(scanner,count:count) : space
+        }
+    }
+    mutating func color(_ scanner: CGPDFScannerRef) throws {
+        if count == 0 {
+            // Unsupported unused state may be superseded before any paint.
+            // Consume its bounded operands without certifying that color.
+            for _ in 0..<32 {
+                var object: CGPDFObjectRef?
+                if !CGPDFScannerPopObject(scanner,&object) { return }
+            }
+            throw PDFParseError(code:.limit, branch:.b018)
+        }
+        var values = [Double]()
+        for _ in 0..<count {
+            var value: CGPDFReal = 0
+            guard CGPDFScannerPopNumber(scanner,&value) else { throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b019) }
+            values.insert(Double(value),at:0)
+        }
+        try set(values,count:count)
+    }
+}
+
+// Conservatively support only a single axis-aligned rectangular clipping path.
+// Readers additionally require the whole media page to fit each clip. Advance
+// and ascent/descent bounds alone cannot prove that glyph outlines fit a clip.
+// Retained geometry must also fit, including clips in saved states.
+struct PDFRectangularClipPath {
+    private var candidate: PDFBox?
+    private var occupied = false
+    mutating func invalidate() { occupied = true; candidate = nil }
+    mutating func reset() { occupied = false; candidate = nil }
+    mutating func rectangle(_ n: [Double], matrix: PDFTextMatrix) throws {
+        guard !occupied else { candidate = nil; return }
+        occupied = true
+        let p = [matrix.point(n[0], n[1]), matrix.point(n[0]+n[2], n[1]),
+                 matrix.point(n[0]+n[2], n[1]+n[3]), matrix.point(n[0], n[1]+n[3])]
+        guard p.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
+              Set(p.map(\.x)).count == 2, Set(p.map(\.y)).count == 2,
+              zip(p, Array(p.dropFirst())+[p[0]]).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }) else { return }
+        candidate = PDFBox(left: Double(p.map(\.x).min()!), top: Double(p.map(\.y).min()!),
+                           right: Double(p.map(\.x).max()!), bottom: Double(p.map(\.y).max()!))
+    }
+    func clippingBox() throws -> PDFBox {
+        guard let candidate else { throw PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b020) }
+        return candidate
+    }
+}
+
+struct PDFMarkedContent {
+    private var depth = 0
+    mutating func begin(_ scanner: CGPDFScannerRef, properties: Bool) throws {
+        guard depth < 64 else { throw PDFParseError(code: .limit, branch:.b021) }
+        if properties {
+            var object: CGPDFObjectRef?
+            guard CGPDFScannerPopObject(scanner, &object), let object else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b022) }
+            var dictionary: CGPDFDictionaryRef?
+            if CGPDFObjectGetType(object) == .name {
+                var name: UnsafePointer<CChar>?
+                guard CGPDFObjectGetValue(object, .name, &name), let name,
+                      let resource = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "Properties", String(cString: name)),
+                      CGPDFObjectGetValue(resource, .dictionary, &dictionary) else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b023) }
+            } else if !CGPDFObjectGetValue(object, .dictionary, &dictionary) { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b024) }
+            guard let dictionary else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b025) }
+            // Only structure ID and language metadata are inert. Replacement,
+            // optional-content membership, and unknown entries remain rejected.
+            var known = 0, metadataObject: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary, "MCID", &metadataObject) {
+                var value: CGPDFInteger = 0
+                guard CGPDFDictionaryGetInteger(dictionary, "MCID", &value), value >= 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b026) }
+                known += 1
+            }
+            if CGPDFDictionaryGetObject(dictionary, "Lang", &metadataObject) {
+                var language: CGPDFStringRef?
+                guard CGPDFDictionaryGetString(dictionary, "Lang", &language), let language,
+                      CGPDFStringGetLength(language) <= 256 else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b027) }
+                known += 1
+            }
+            guard CGPDFDictionaryGetCount(dictionary) == known else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b028) }
+        }
+        var tag: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner, &tag), let tag, String(cString: tag) != "OC" else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b029) }
+        depth += 1
+    }
+    mutating func end() throws {
+        guard depth > 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b030) }
+        depth -= 1
+    }
+    func finish() throws {
+        guard depth == 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags, branch:.b031) }
+    }
+}
+#endif
diff --git a/Takupoke/PDFDrawnTextReader+Fonts.swift b/Takupoke/PDFDrawnTextReader+Fonts.swift
index e08a3ce..1e3f9d6 100644
--- a/Takupoke/PDFDrawnTextReader+Fonts.swift
+++ b/Takupoke/PDFDrawnTextReader+Fonts.swift
@@ -8 +8 @@ extension PDFDrawnTextReader {
-        guard let object = CGPDFContentStreamGetResource(stream, category, name) else { throw PDFTextFailure.unsupported }
+        guard let object = CGPDFContentStreamGetResource(stream, category, name) else { throw PDFTextFailure.unsupported(.b033) }
@@ -10 +10 @@ extension PDFDrawnTextReader {
-        guard CGPDFObjectGetValue(object, .dictionary, &dict), let dict = dict else { throw PDFTextFailure.unsupported }
+        guard CGPDFObjectGetValue(object, .dictionary, &dict), let dict = dict else { throw PDFTextFailure.unsupported(.b034) }
@@ -21 +21 @@ extension PDFDrawnTextReader {
-        guard !CGPDFDictionaryGetObject(dict, key, &object), let fallback = fallback else { throw PDFTextFailure.unsupported }
+        guard !CGPDFDictionaryGetObject(dict, key, &object), let fallback = fallback else { throw PDFTextFailure.unsupported(.b035) }
@@ -26,2 +26,6 @@ extension PDFDrawnTextReader {
-        if let cached = fonts[key] { try engine.font(cached, size: size); return }
-        guard fonts.count < 128 else { throw PDFParseError(code: .limit) }
+        if !selectedFontKeys.contains(key) {
+            guard selectedFontKeys.count < 128 else { throw PDFParseError(code: .limit, branch:.b036) }
+            selectedFontKeys.insert(key)
+        }
+        if let cached = fonts[key] { try engine.font(cached, size:size); return }
+        guard fonts.count < 128 else { throw PDFParseError(code: .limit, branch:.b037) }
@@ -30,2 +34,7 @@ extension PDFDrawnTextReader {
-        guard CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream), let mapStream = mapStream else {
-            throw PDFTextFailure.unsupported
+        if !CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream) {
+            // Only an absent map can be an unused setup font. An explicitly
+            // malformed map, broken resource, cancellation, or limit still fails.
+            var object: CGPDFObjectRef?
+            guard !CGPDFDictionaryGetObject(dict, "ToUnicode", &object) else { throw PDFTextFailure.unsupported(.b038) }
+            try engine.font(nil, size: size)
+            return
@@ -32,0 +42 @@ extension PDFDrawnTextReader {
+        guard let mapStream = mapStream else { throw PDFTextFailure.unsupported(.b039) }
@@ -34,2 +44,2 @@ extension PDFDrawnTextReader {
-        guard let data = CGPDFStreamCopyData(mapStream, &format), format == .raw else { throw PDFTextFailure.unsupported }
-        let mapping = try PDFUnicodeMap.read(data as Data)
+        guard let data = CGPDFStreamCopyData(mapStream, &format), format == .raw else { throw PDFTextFailure.unsupported(.b040) }
+        let mapping = try PDFUnicodeMap.read(data as Data,check:engine.check)
@@ -45 +55 @@ extension PDFDrawnTextReader {
-                throw PDFTextFailure.unsupported
+                throw PDFTextFailure.unsupported(.b041)
@@ -50 +60 @@ extension PDFDrawnTextReader {
-                throw PDFTextFailure.unsupported
+                throw PDFTextFailure.unsupported(.b042)
@@ -55 +65 @@ extension PDFDrawnTextReader {
-            throw PDFTextFailure.unsupported
+            throw PDFTextFailure.unsupported(.b043)
@@ -62 +72 @@ extension PDFDrawnTextReader {
-                guard count <= 200_000 else { throw PDFParseError(code: .limit) }
+                guard count <= 200_000 else { throw PDFParseError(code: .limit, branch:.b044) }
@@ -67 +77 @@ extension PDFDrawnTextReader {
-                        throw PDFTextFailure.unsupported
+                        throw PDFTextFailure.unsupported(.b045)
@@ -73 +83 @@ extension PDFDrawnTextReader {
-                        throw PDFTextFailure.unsupported
+                        throw PDFTextFailure.unsupported(.b046)
@@ -81 +91 @@ extension PDFDrawnTextReader {
-                    guard i < count else { throw PDFTextFailure.unsupported }
+                    guard i < count else { throw PDFTextFailure.unsupported(.b047) }
@@ -84 +94 @@ extension PDFDrawnTextReader {
-                        guard length > 0, length <= 65536 - start else { throw PDFTextFailure.unsupported }
+                        guard length > 0, length <= 65536 - start else { throw PDFTextFailure.unsupported(.b048) }
@@ -87 +97 @@ extension PDFDrawnTextReader {
-                            guard CGPDFArrayGetNumber(list, offset, &value) else { throw PDFTextFailure.unsupported }
+                            guard CGPDFArrayGetNumber(list, offset, &value) else { throw PDFTextFailure.unsupported(.b049) }
@@ -94 +104 @@ extension PDFDrawnTextReader {
-                        guard end >= start, i < count, CGPDFArrayGetNumber(array, i, &value) else { throw PDFTextFailure.unsupported }
+                        guard end >= start, i < count, CGPDFArrayGetNumber(array, i, &value) else { throw PDFTextFailure.unsupported(.b050) }
@@ -101 +111 @@ extension PDFDrawnTextReader {
-                guard !CGPDFDictionaryGetObject(metrics, "W", &object) else { throw PDFTextFailure.unsupported }
+                guard !CGPDFDictionaryGetObject(metrics, "W", &object) else { throw PDFTextFailure.unsupported(.b051) }
@@ -107 +117 @@ extension PDFDrawnTextReader {
-                  CGPDFArrayGetCount(array) == Int(last - first + 1) else { throw PDFTextFailure.unsupported }
+                  CGPDFArrayGetCount(array) == Int(last - first + 1) else { throw PDFTextFailure.unsupported(.b052) }
@@ -110 +120 @@ extension PDFDrawnTextReader {
-                guard CGPDFArrayGetNumber(array, index, &value) else { throw PDFTextFailure.unsupported }
+                guard CGPDFArrayGetNumber(array, index, &value) else { throw PDFTextFailure.unsupported(.b053) }
@@ -113 +123,15 @@ extension PDFDrawnTextReader {
-            guard mapping.values.keys.allSatisfy({ widths[$0] != nil }) else { throw PDFTextFailure.unsupported }
+            guard mapping.values.keys.allSatisfy({ widths[$0] != nil }) else { throw PDFTextFailure.unsupported(.b054) }
+        }
+        var outlineBounds: PDFBox?
+        var fontBox: CGPDFArrayRef?
+        if CGPDFDictionaryGetArray(descriptor, "FontBBox", &fontBox), let fontBox,
+           CGPDFArrayGetCount(fontBox) == 4 {
+            var values = [Double]()
+            for index in 0..<4 {
+                var value: CGPDFReal = 0
+                guard CGPDFArrayGetNumber(fontBox, index, &value) else { values.removeAll(); break }
+                values.append(Double(value))
+            }
+            if values.count == 4, values.allSatisfy(\.isFinite), values[0] < values[2], values[1] < values[3] {
+                outlineBounds = PDFBox(left:values[0], top:values[1], right:values[2], bottom:values[3])
+            }
@@ -114,0 +139,2 @@ extension PDFDrawnTextReader {
+        let glyphBounds = try embeddedGlyphBounds(font:dict, metrics:metrics, descriptor:descriptor,
+            composite:composite, codes:Array(mapping.values.keys))
@@ -117 +143 @@ extension PDFDrawnTextReader {
-            ascent: number(descriptor, "Ascent"), descent: number(descriptor, "Descent"))
+            ascent: number(descriptor, "Ascent"), descent: number(descriptor, "Descent"), outlineBounds:outlineBounds, encodedGlyphBounds:glyphBounds)
diff --git a/Takupoke/PDFDrawnTextReader+GlyphBounds.swift b/Takupoke/PDFDrawnTextReader+GlyphBounds.swift
new file mode 100644
index 0000000..0524c69
--- /dev/null
+++ b/Takupoke/PDFDrawnTextReader+GlyphBounds.swift
@@ -0,0 +1,55 @@
+import Foundation
+#if canImport(CoreGraphics) && canImport(CoreText)
+import CoreGraphics
+import CoreText
+
+extension PDFDrawnTextReader {
+    /// Uses the embedded font actually addressed by the PDF's encoded codes.
+    /// No system font substitution and no Unicode -> glyph guess is permitted.
+    func embeddedGlyphBounds(font: CGPDFDictionaryRef, metrics: CGPDFDictionaryRef,
+                             descriptor: CGPDFDictionaryRef, composite: Bool,
+                             codes: [Int]) throws -> [Int: PDFBox]? {
+        try engine.check()
+        var stream: CGPDFStreamRef?
+        guard CGPDFDictionaryGetStream(descriptor, "FontFile2", &stream), let stream else { return nil }
+        var format = CGPDFDataFormat.raw
+        guard let raw = CGPDFStreamCopyData(stream, &format), format == .raw,
+              CFDataGetLength(raw) <= 8_000_000 else { return nil }
+        let data = raw as Data
+        var mapping: [Int: UInt16]?
+        if composite {
+            var subtype: UnsafePointer<CChar>?
+            guard CGPDFDictionaryGetName(metrics, "Subtype", &subtype), let subtype,
+                  String(cString:subtype) == "CIDFontType2" else { return nil }
+            var object: CGPDFObjectRef?, mapStream: CGPDFStreamRef?, mapName: UnsafePointer<CChar>?
+            if !CGPDFDictionaryGetObject(metrics, "CIDToGIDMap", &object) ||
+                (CGPDFDictionaryGetName(metrics, "CIDToGIDMap", &mapName) && mapName.map { String(cString:$0) } == "Identity") {
+                mapping = Dictionary(uniqueKeysWithValues: codes.map { ($0, UInt16($0)) })
+            } else if CGPDFDictionaryGetStream(metrics, "CIDToGIDMap", &mapStream), let mapStream {
+                guard let rawMap = CGPDFStreamCopyData(mapStream, &format), format == .raw else { return nil }
+                mapping = try PDFEncodedGlyphMap.cidToGID(rawMap as Data, check:engine.check)
+            } else { return nil }
+        } else {
+            var encoding: CGPDFObjectRef?, flags: CGPDFInteger = 0
+            guard !CGPDFDictionaryGetObject(font, "Encoding", &encoding),
+                  CGPDFDictionaryGetInteger(descriptor, "Flags", &flags), flags & 4 != 0, flags & 32 == 0 else { return nil }
+            mapping = try PDFEncodedGlyphMap.symbolicTrueType(data, check:engine.check)
+        }
+        guard let mapping, let provider = CGDataProvider(data:data as CFData), let cgFont = CGFont(provider) else { return nil }
+        let ctFont = CTFontCreateWithGraphicsFont(cgFont, 1000, nil, nil)
+        var result: [Int: PDFBox] = [:]
+        for code in codes.sorted() {
+            try engine.check()
+            guard let gid = mapping[code], gid != 0, Int(gid) < cgFont.numberOfGlyphs,
+                  let path = CTFontCreatePathForGlyph(ctFont, gid, nil) else { continue }
+            let box = path.boundingBoxOfPath
+            guard !box.isNull, !box.isEmpty,
+                  [box.minX,box.minY,box.maxX,box.maxY].allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { continue }
+            result[code] = PDFBox(left:Double(box.minX),top:Double(box.minY),right:Double(box.maxX),bottom:Double(box.maxY))
+        }
+        // A supported physical map with missing/empty glyphs is not rescued by
+        // the whole-font box. Geometry rejects it when outlined text uses it.
+        return result
+    }
+}
+#endif
diff --git a/Takupoke/PDFDrawnTextReader.swift b/Takupoke/PDFDrawnTextReader.swift
index 9e5a05a..08cfbeb 100644
--- a/Takupoke/PDFDrawnTextReader.swift
+++ b/Takupoke/PDFDrawnTextReader.swift
@@ -11 +11,10 @@ final class PDFDrawnTextReader {
-    init(check: @escaping () throws -> Void) { engine = PDFTextGeometry(check: check) }
+    var selectedFontKeys: Set<String> = []
+    private var clipPath = PDFRectangularClipPath()
+    private var markedContent = PDFMarkedContent()
+    private var pageBounds: PDFBox?
+    private let paintResolver = PDFPaintSpaceResolver()
+    private let deferFillValidation: Bool
+    init(deferFillValidation: Bool = false, check: @escaping () throws -> Void) {
+        self.deferFillValidation = deferFillValidation
+        engine = PDFTextGeometry(check: check)
+    }
@@ -23 +32 @@ final class PDFDrawnTextReader {
-            guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw PDFTextFailure.unsupported }
+            guard CGPDFScannerPopNumber(scanner, &value), value.isFinite else { throw PDFTextFailure.unsupported(.b055) }
@@ -30 +39 @@ final class PDFDrawnTextReader {
-        guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw PDFTextFailure.unsupported }
+        guard CGPDFScannerPopName(scanner, &pointer), let pointer = pointer else { throw PDFTextFailure.unsupported(.b056) }
@@ -35 +44 @@ final class PDFDrawnTextReader {
-        guard CGPDFScannerPopString(scanner, &value), let value = value else { throw PDFTextFailure.unsupported }
+        guard CGPDFScannerPopString(scanner, &value), let value = value else { throw PDFTextFailure.unsupported(.b057) }
@@ -40,3 +49,3 @@ final class PDFDrawnTextReader {
-        guard length <= 200_000 else { throw PDFParseError(code: .limit) }
-        if length == 0 { return }
-        guard let bytes = CGPDFStringGetBytePtr(value) else { throw PDFTextFailure.unsupported }
+        guard length <= 200_000 else { throw PDFParseError(code: .limit, branch:.b058) }
+        if length == 0 { try engine.show([]); return }
+        guard let bytes = CGPDFStringGetBytePtr(value) else { throw PDFTextFailure.unsupported(.b059) }
@@ -48 +57 @@ final class PDFDrawnTextReader {
-              CGPDFArrayGetCount(array) <= 100_000 else { throw PDFTextFailure.unsupported }
+              CGPDFArrayGetCount(array) <= 100_000 else { throw PDFTextFailure.unsupported(.b060) }
@@ -54 +63 @@ final class PDFDrawnTextReader {
-            else { throw PDFTextFailure.unsupported }
+            else { throw PDFTextFailure.unsupported(.b061) }
@@ -58,0 +68 @@ final class PDFDrawnTextReader {
+        try engine.state.colors.applyIntent(dict)
@@ -62,2 +72,20 @@ final class PDFDrawnTextReader {
-            guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw PDFTextFailure.unsupported }
-        }
+            guard !CGPDFDictionaryGetObject(dict, key, &object) else { throw PDFTextFailure.unsupported(.b062) }
+        }
+        var lineWidth: CGPDFReal = 0, widthObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetNumber(dict,"LW",&lineWidth) {
+            try engine.operation("w", [Double(lineWidth)])
+        } else if CGPDFDictionaryGetObject(dict,"LW",&widthObject) { throw PDFTextFailure.unsupported(.b063) }
+        for (key, op) in [("LJ", "j"), ("ML", "M")] {
+            var value: CGPDFReal = 0, object: CGPDFObjectRef?
+            if CGPDFDictionaryGetNumber(dict, key, &value) { try engine.operation(op, [Double(value)]) }
+            else if CGPDFDictionaryGetObject(dict, key, &object) { throw PDFTextFailure.unsupported(.b064) }
+        }
+        var dashObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetObject(dict,"D",&dashObject) {
+            var dash: CGPDFArrayRef?, pattern: CGPDFArrayRef?, phase: CGPDFReal = 0
+            guard CGPDFDictionaryGetArray(dict,"D",&dash), let dash, CGPDFArrayGetCount(dash) == 2,
+                  CGPDFArrayGetArray(dash,0,&pattern), let pattern,
+                  CGPDFArrayGetNumber(dash,1,&phase) else { throw PDFTextFailure.unsupported(.b065) }
+            engine.state.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase))
+        }
+        guard PDFPaintColors.hasNormalBlendMode(dict) else { throw PDFTextFailure.unsupported(.b066) }
@@ -65 +93,11 @@ final class PDFDrawnTextReader {
-            throw PDFTextFailure.unsupported
+            throw PDFTextFailure.unsupported(.b067)
+        }
+    }
+    private func deviceColor(_ scanner: CGPDFScannerRef, stroke: Bool, count: Int) throws {
+        let values = try numbers(scanner,count)
+        let operation = count == 1 ? (stroke ? "G" : "g") : count == 3 ? (stroke ? "RG" : "rg") : (stroke ? "K" : "k")
+        try engine.operation(operation,values)
+        if stroke {
+            try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
+        } else {
+            try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
@@ -69 +107,4 @@ final class PDFDrawnTextReader {
-        guard let table = CGPDFOperatorTableCreate() else { throw PDFTextFailure.unsupported }
+        let media = page.getBoxRect(.mediaBox)
+        pageBounds = PDFBox(left: Double(media.minX), top: Double(media.minY),
+                            right: Double(media.maxX), bottom: Double(media.maxY))
+        guard let table = CGPDFOperatorTableCreate() else { throw PDFTextFailure.unsupported(.b068) }
@@ -125 +166 @@ final class PDFDrawnTextReader {
-                guard CGPDFScannerPopString(scanner, &text), let text = text else { throw PDFTextFailure.unsupported }
+                guard CGPDFScannerPopString(scanner, &text), let text = text else { throw PDFTextFailure.unsupported(.b069) }
@@ -131,0 +173,64 @@ final class PDFDrawnTextReader {
+        CGPDFOperatorTableSetCallback(table,"ri") { scanner,p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.intent(scanner) } }
+        CGPDFOperatorTableSetCallback(table, "w") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            try s.engine.operation("w", s.numbers(scanner,1))
+        } }
+        CGPDFOperatorTableSetCallback(table, "j") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            try s.engine.operation("j", s.numbers(scanner,1))
+        } }
+        CGPDFOperatorTableSetCallback(table, "M") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            try s.engine.operation("M", s.numbers(scanner,1))
+        } }
+        CGPDFOperatorTableSetCallback(table, "d") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            let phase = try s.numbers(scanner,1)[0]
+            var pattern: CGPDFArrayRef?
+            guard CGPDFScannerPopArray(scanner,&pattern), let pattern else { throw PDFTextFailure.unsupported(.b070) }
+            s.engine.state.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:phase)
+        } }
+        CGPDFOperatorTableSetCallback(table,"g") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:1) } }
+        CGPDFOperatorTableSetCallback(table,"G") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:1) } }
+        CGPDFOperatorTableSetCallback(table,"rg") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:3) } }
+        CGPDFOperatorTableSetCallback(table,"RG") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:3) } }
+        CGPDFOperatorTableSetCallback(table,"k") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:false,count:4) } }
+        CGPDFOperatorTableSetCallback(table,"K") { scanner,p in PDFDrawnTextReader.run(p) { try $0.deviceColor(scanner,stroke:true,count:4) } }
+        // Standalone extraction cannot certify a later fill. PDFKitReader may
+        // defer this check to its mandatory path scan with all original glyph
+        // boxes; that scan must succeed before returning or completing capture.
+        for op in ["f", "F", "f*", "B", "B*", "b", "b*"] {
+            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { s in
+                guard s.engine.glyphs.isEmpty || s.deferFillValidation else { throw PDFTextFailure.unsupported(.b071) }
+                s.clipPath.reset()
+            } }
+        }
+        CGPDFOperatorTableSetCallback(table, "cs") { scanner, p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.fill.space(scanner,resolver:$0.paintResolver) } }
+        CGPDFOperatorTableSetCallback(table, "CS") { scanner, p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.stroke.space(scanner,resolver:$0.paintResolver) } }
+        for op in ["sc", "scn"] {
+            CGPDFOperatorTableSetCallback(table, op) { scanner, p in PDFDrawnTextReader.run(p) { s in
+                try s.engine.state.colors.fill.color(scanner)
+            } }
+        }
+        for op in ["SC", "SCN"] {
+            CGPDFOperatorTableSetCallback(table, op) { scanner, p in PDFDrawnTextReader.run(p) { s in
+                try s.engine.state.colors.stroke.color(scanner)
+            } }
+        }
+        CGPDFOperatorTableSetCallback(table, "re") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            try s.clipPath.rectangle(s.numbers(scanner,4),matrix:s.engine.state.ctm)
+        } }
+        for op in ["m", "l", "c", "v", "y"] {
+            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { $0.clipPath.invalidate() } }
+        }
+        for op in ["n", "S", "s"] {
+            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { $0.clipPath.reset() } }
+        }
+        for op in ["W", "W*"] {
+            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { s in
+                let clip = try s.clipPath.clippingBox()
+                guard let page = s.pageBounds, PDFClipValidation.contains(clip, page) else {
+                    throw PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b072)
+                }
+                try s.engine.clip(clip)
+            } }
+        }
+        CGPDFOperatorTableSetCallback(table, "BMC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:false) } }
+        CGPDFOperatorTableSetCallback(table, "BDC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:true) } }
+        CGPDFOperatorTableSetCallback(table, "EMC") { _, p in PDFDrawnTextReader.run(p) { try $0.markedContent.end() } }
@@ -134,2 +239,2 @@ final class PDFDrawnTextReader {
-        for op in ["Do", "BDC", "BMC", "W", "W*"] {
-            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw PDFTextFailure.unsupported } }
+        for op in ["Do", "BI", "ID", "EI", "sh"] {
+            CGPDFOperatorTableSetCallback(table, op) { _, p in PDFDrawnTextReader.run(p) { _ in throw PDFTextFailure.unsupported(.b073) } }
@@ -140,0 +246,2 @@ final class PDFDrawnTextReader {
+        try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
+        try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
@@ -143 +250,2 @@ final class PDFDrawnTextReader {
-        guard succeeded else { throw PDFTextFailure.unsupported }
+        guard succeeded else { throw PDFTextFailure.unsupported(.b074) }
+        try markedContent.finish()
diff --git a/Takupoke/PDFEncodedGlyphMap.swift b/Takupoke/PDFEncodedGlyphMap.swift
new file mode 100644
index 0000000..5d2d4ba
--- /dev/null
+++ b/Takupoke/PDFEncodedGlyphMap.swift
@@ -0,0 +1,76 @@
+import Foundation
+
+/// Physical PDF code -> glyph ID only. This never recovers or certifies Unicode.
+/// Unsupported/ambiguous encodings retain the reader's conservative font bounds.
+enum PDFEncodedGlyphMap {
+    static func symbolicTrueType(_ data: Data, check: () throws -> Void = {}) throws -> [Int: UInt16]? {
+        try check()
+        guard data.count >= 12, data.count <= 8_000_000 else { return nil }
+        let bytes = [UInt8](data)
+        func word(_ offset: Int) -> Int? {
+            guard offset >= 0, offset <= bytes.count - 2 else { return nil }
+            return Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
+        }
+        func long(_ offset: Int) -> Int? {
+            guard let high = word(offset), let low = word(offset + 2) else { return nil }
+            return high * 65536 + low
+        }
+        guard let signature = long(0), [0x00010000, 0x74727565].contains(signature),
+              let count = word(4), (1...128).contains(count), 12 + count * 16 <= bytes.count else { return nil }
+        var tables: [Int: Range<Int>] = [:]
+        for index in 0..<count {
+            try check()
+            let record = 12 + index * 16
+            guard let tag = long(record), let start = long(record + 8), let length = long(record + 12),
+                  start >= 12 + count * 16, start <= bytes.count, length <= bytes.count - start,
+                  tables[tag] == nil else { return nil }
+            let range = start..<(start + length)
+            guard !tables.values.contains(where: { $0.overlaps(range) }) else { return nil }
+            tables[tag] = range
+        }
+        guard let cmap = tables[0x636d6170], cmap.count >= 4, word(cmap.lowerBound) == 0,
+              let entries = word(cmap.lowerBound + 2), (1...128).contains(entries),
+              4 + entries * 8 <= cmap.count else { return nil }
+        var selected: Int?
+        for index in 0..<entries {
+            try check()
+            let record = cmap.lowerBound + 4 + index * 8
+            guard let platform = word(record), let encoding = word(record + 2), let offset = long(record + 4),
+                  offset >= 4 + entries * 8, offset < cmap.count else { return nil }
+            // A competing symbolic table makes the PDF rendering choice uncertain.
+            if platform == 3 && encoding == 0 { return nil }
+            if platform == 1 && encoding == 0 {
+                guard selected == nil else { return nil }
+                selected = cmap.lowerBound + offset
+            }
+        }
+        guard let start = selected, let format = word(start), let length = word(start + 2),
+              length <= cmap.upperBound - start else { return nil }
+        var result: [Int: UInt16] = [:]
+        if format == 0 {
+            guard length == 262 else { return nil }
+            for code in 0..<256 { result[code] = UInt16(bytes[start + 6 + code]) }
+        } else if format == 6 {
+            guard length >= 10, let first = word(start + 6), let count = word(start + 8),
+                  first <= 255, count <= 256 - first, length == 10 + count * 2 else { return nil }
+            for offset in 0..<count {
+                try check()
+                guard let gid = word(start + 10 + offset * 2) else { return nil }
+                result[first + offset] = UInt16(gid)
+            }
+        } else { return nil }
+        return result
+    }
+
+    static func cidToGID(_ data: Data, check: () throws -> Void = {}) throws -> [Int: UInt16]? {
+        try check()
+        guard !data.isEmpty, data.count <= 131072, data.count % 2 == 0 else { return nil }
+        let bytes = [UInt8](data)
+        var result: [Int: UInt16] = [:]
+        for offset in stride(from: 0, to: bytes.count, by: 2) {
+            if offset % 256 == 0 { try check() }
+            result[offset / 2] = UInt16(bytes[offset]) * 256 + UInt16(bytes[offset + 1])
+        }
+        return result
+    }
+}
diff --git a/Takupoke/PDFGrid.swift b/Takupoke/PDFGrid.swift
index 25227e5..3d9c6e2 100644
--- a/Takupoke/PDFGrid.swift
+++ b/Takupoke/PDFGrid.swift
@@ -7,0 +8,72 @@ struct PDFGrid {
+    private final class Calibration {
+        var visits = 0
+        var orderedGlyphIndices: [Int]?
+        var valid: [PDFBox:[Double]] = [:]
+        var invalid = Set<PDFBox>()
+        func consume(_ check: () throws -> Void) throws {
+            visits += 1
+            guard visits <= 64_000_000 else { throw PDFParseError(code:.limit,stage:.gridCell, branch:.b075) }
+            if visits % 128 == 0 { try check() }
+        }
+    }
+    private let calibration = Calibration()
+    init(page: PDFPageLayout) { self.page = page }
+    private func checkedRules(_ predicate: (PDFRule) -> Bool, check: () throws -> Void) throws -> [PDFRule] {
+        var result = [PDFRule]()
+        for rule in page.lines { try calibration.consume(check); if predicate(rule) { result.append(rule) } }
+        return result
+    }
+    func box(_ x: Double, _ y: Double, check: () throws -> Void) throws -> PDFBox {
+        try check()
+        let vs = try checkedRules({ $0.vertical && $0.y1-0.8 <= y && y <= $0.y2+0.8 },check:check)
+        let hs = try checkedRules({ $0.horizontal && $0.x1-0.8 <= x && x <= $0.x2+0.8 },check:check)
+        guard let l = vs.filter({ $0.x1 < x-0.5 }).map(\.x1).max(),
+              let r = vs.filter({ $0.x1 > x+0.5 }).map(\.x1).min(),
+              let t = hs.filter({ $0.y1 < y-0.5 }).map(\.y1).max(),
+              let b = hs.filter({ $0.y1 > y+0.5 }).map(\.y1).min() else {
+            throw PDFParseError(code:.unsupported,stage:.gridCell, branch:.b076)
+        }
+        return PDFBox(left:l,top:t,right:r,bottom:b)
+    }
+    func glyphs(in box: PDFBox, check: () throws -> Void) throws -> [PDFGlyph] {
+        try check()
+        if calibration.orderedGlyphIndices == nil {
+            var indices = [Int](); indices.reserveCapacity(page.glyphs.count)
+            for index in page.glyphs.indices { try calibration.consume(check); indices.append(index) }
+            try indices.sort { a,b in
+                try calibration.consume(check)
+                let ay = page.glyphs[a].cy, by = page.glyphs[b].cy
+                return ay == by ? a < b : ay < by
+            }
+            calibration.orderedGlyphIndices = indices
+        }
+        let indices = calibration.orderedGlyphIndices!
+        func boundary(_ y: Double, inclusive: Bool) throws -> Int {
+            var left = 0, right = indices.count
+            while left < right {
+                try calibration.consume(check)
+                let middle = left+(right-left)/2, value = page.glyphs[indices[middle]].cy
+                if value < y || (inclusive && value == y) { left = middle+1 } else { right = middle }
+            }
+            return left
+        }
+        let first = try boundary(box.top+0.3,inclusive:true)
+        let end = try boundary(box.bottom-0.3,inclusive:false)
+        var selected = [Int]()
+        if first < end {
+            for offset in first..<end {
+                try calibration.consume(check)
+                let index = indices[offset], glyph = page.glyphs[index]
+                if box.left+0.3 < glyph.cx && glyph.cx < box.right-0.3 {
+                    if glyph.ocrLineAtom == true {
+                        guard glyph.x >= box.left, glyph.y >= box.top, glyph.x + glyph.width <= box.right,
+                              glyph.y + glyph.height <= box.bottom else { throw PDFParseError(code:.ambiguous,stage:.gridCell, branch:.b077) }
+                    }
+                    selected.append(index)
+                }
+            }
+        }
+        // Spatial lookup cannot change the original PDF reading/drawing order.
+        try selected.sort { a,b in try calibration.consume(check); return a < b }
+        return selected.map { page.glyphs[$0] }
+    }
@@ -11 +83 @@ struct PDFGrid {
-              let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min() else { throw PDFParseError(code: .unsupported, stage: .gridColumn) }
+              let r = vs.filter({ $0.x1 > x + 0.5 }).map(\.x1).min() else { throw PDFParseError(code: .unsupported, stage: .gridColumn, branch:.b078) }
@@ -16 +88 @@ struct PDFGrid {
-        guard let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else { throw PDFParseError(code: .unsupported, stage: .gridRow) }
+        guard let b = hs.filter({ $0.y1 > y + 0.5 }).map(\.y1).min() else { throw PDFParseError(code: .unsupported, stage: .gridRow, branch:.b079) }
@@ -27 +99 @@ struct PDFGrid {
-            throw PDFParseError(code: .unsupported, stage: .gridCell)
+            throw PDFParseError(code: .unsupported, stage: .gridCell, branch:.b080)
@@ -33 +105,3 @@ struct PDFGrid {
-            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 }
+            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 &&
+            ($0.ocrLineAtom != true || $0.x >= box.left && $0.y >= box.top &&
+                $0.x + $0.width <= box.right && $0.y + $0.height <= box.bottom) }
@@ -50 +124 @@ struct PDFGrid {
-            throw PDFParseError(code: .ambiguous, stage: .textOrder)
+            throw PDFParseError(code: .ambiguous, stage: .textOrder, branch:.b081)
@@ -65,0 +140,3 @@ struct PDFGrid {
+    func text(_ box: PDFBox, check: () throws -> Void) throws -> [String] {
+        try Self.contentRows(try glyphs(in:box,check:check)).map { $0.map(\.text).joined() }
+    }
@@ -72,3 +149,5 @@ struct PDFGrid {
-    func timetableText(_ box: PDFBox) throws -> [String] {
-        let input = glyphs(in: box)
-        guard input.reduce(0, { $0 + $1.text.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit) }
+    func timetableText(_ box: PDFBox, check: () throws -> Void = {}) throws -> [String] {
+        try timetableText(try glyphs(in:box,check:check),check:check)
+    }
+    private func timetableText(_ input: [PDFGlyph], check: () throws -> Void) throws -> [String] {
+        guard input.reduce(0, { $0 + $1.text.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, branch:.b082) }
@@ -97,0 +177 @@ struct PDFGrid {
+            try check()
@@ -101 +181 @@ struct PDFGrid {
-            guard aligned.count <= 1 else { throw PDFParseError(code: .ambiguous, stage: .fragmentAlignment) }
+            guard aligned.count <= 1 else { throw PDFParseError(code: .ambiguous, stage: .fragmentAlignment, branch:.b083) }
@@ -106 +186 @@ struct PDFGrid {
-                    throw PDFParseError(code: .ambiguous, stage: .fragmentOverlap)
+                    throw PDFParseError(code: .ambiguous, stage: .fragmentOverlap, branch:.b084)
@@ -114,0 +195,72 @@ struct PDFGrid {
+    /// Build calibration cells only inside the independently identified lesson
+    /// rows and period columns. Page annotations cannot establish field roles.
+    func lessonBoxes(rows: [PDFBox], columns: [Double], check: () throws -> Void = {}) throws -> [PDFBox] {
+        var boxes = Set<PDFBox>()
+        for row in rows {
+            for x in columns {
+                try calibration.consume(check)
+                let rules = try checkedRules({ $0.horizontal && $0.x1-0.5 <= x && x <= $0.x2+0.5 && row.top+1 < $0.y1 && $0.y1 < row.bottom-1 },check:check)
+                let cuts = Set(rules.map(\.y1)).sorted()
+                let edges = [row.top]+cuts+[row.bottom]
+                for index in 0..<(edges.count-1) where edges[index+1]-edges[index] >= 2 {
+                    let cell = try box(x,(edges[index]+edges[index+1])/2,check:check)
+                    guard cell.top >= row.top-0.8, cell.bottom <= row.bottom+0.8 else { throw PDFParseError(code:.ambiguous,stage:.gridCell, branch:.b085) }
+                    boxes.insert(cell)
+                    guard boxes.count <= 10_000 else { throw PDFParseError(code:.limit, branch:.b086) }
+                }
+            }
+        }
+        return Array(boxes)
+    }
+    /// A missing line cannot shift the following field into its place. Only
+    /// complete lesson cells of the same height establish the role baselines.
+    func lessonFields(_ box: PDFBox, lines: [String], referenceBoxes: [PDFBox], check: () throws -> Void = {}) throws -> [String] {
+        try check()
+        if lines.count == 3 { return lines }
+        guard !lines.isEmpty, lines.count < 3 else { throw PDFParseError(code: .ambiguous, stage: .lessonLines, branch:.b087) }
+        let height = box.bottom - box.top
+        var references: [[Double]] = []
+        var seen = Set<PDFBox>()
+        for other in referenceBoxes {
+            try calibration.consume(check)
+            guard seen.insert(other).inserted else { continue }
+            guard seen.count <= 10000 else { throw PDFParseError(code:.limit,stage:.gridCell, branch:.b088) }
+            guard abs(other.bottom-other.top-height) < 0.5, !calibration.invalid.contains(other) else { continue }
+            if let cached = calibration.valid[other] { references.append(cached); continue }
+            let input = try glyphs(in:other,check:check)
+            let text: [String]
+            do { text = try timetableText(input,check:check) }
+            catch let error as PDFParseError where error.code == .ambiguous || error.code == .unsupported {
+                calibration.invalid.insert(other); continue
+            }
+            let rows = Self.rows(input)
+            guard text.count == 3, !text.contains(where:RecoveryRole.hasLabelPrefix), rows.count == 3 else {
+                calibration.invalid.insert(other); continue
+            }
+            let centers = rows.map { row in row.map(\.cy).reduce(0,+)/Double(row.count)-other.top }
+            calibration.valid[other] = centers; references.append(centers)
+        }
+        let rows = Self.rows(try glyphs(in:box,check:check))
+        guard rows.count == lines.count else { throw PDFParseError(code:.ambiguous,stage:.lessonLines, branch:.b089) }
+        var candidates = [[String]]()
+        for reference in references {
+            try calibration.consume(check)
+            guard zip(reference,reference.dropFirst()).allSatisfy({ $0.1-$0.0 > 2 }) else { continue }
+            let tolerance = min(0.75, zip(reference, reference.dropFirst()).map { ($0.1 - $0.0) / 3 }.min()!)
+            var fields = ["", "", ""], assigned: Set<Int> = [], valid = true
+            for (row, text) in zip(rows, lines) {
+                let center = row.map(\.cy).reduce(0,+) / Double(row.count) - box.top
+                let matches = reference.indices.filter { abs(reference[$0] - center) <= tolerance }
+                guard matches.count == 1, assigned.insert(matches[0]).inserted else { valid = false; break }
+                fields[matches[0]] = text
+            }
+            // A matching reference that places this line in teacher/room is
+            // conflicting evidence, even when it would leave subject absent.
+            if valid { candidates.append(fields) }
+        }
+        guard let fields = candidates.first, !fields[0].isEmpty, candidates.allSatisfy({ $0 == fields }) else {
+            throw PDFParseError(code: .ambiguous, stage: .lessonLines, branch:.b090)
+        }
+        return fields
+    }
+
diff --git a/Takupoke/PDFKitReader.swift b/Takupoke/PDFKitReader.swift
index 3724b6f..8137326 100644
--- a/Takupoke/PDFKitReader.swift
+++ b/Takupoke/PDFKitReader.swift
@@ -11 +11 @@ enum PDFKitReader {
-    static func read(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder? = nil,
+    static func read(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder? = nil, capture: RecoveryReadCapture? = nil,
@@ -14 +14 @@ enum PDFKitReader {
-        do { return try readPages(url, kind: kind, diagnostics: recorder, check: check) }
+        do { return try readPages(url, kind: kind, diagnostics: recorder, capture: capture, check: check) }
@@ -21,4 +21,4 @@ enum PDFKitReader {
-    /// The exam PDFs contain marked content or clipping commands rejected by
-    /// the ordinary timetable's drawing interpreter. Their PDFKit character
-    /// selections are validated individually by the calendar text path.
-    static func readSpecial(_ url: URL, diagnostics: PDFDiagnosticRecorder? = nil,
+    /// Special schedules use individually validated PDFKit selections plus an
+    /// independent content-stream visibility check. Unsupported visibility is
+    /// recovered from raster pages, rather than from selectable hidden text.
+    static func readSpecial(_ url: URL, diagnostics: PDFDiagnosticRecorder? = nil, capture: RecoveryReadCapture? = nil,
@@ -26 +26 @@ enum PDFKitReader {
-        do { return try readPages(url, kind: .events, diagnostics: diagnostics, check: check) }
+        do { return try readPages(url, kind: .events, diagnostics: diagnostics, capture: capture, verifyVisibility: true, check: check) }
@@ -33 +33 @@ enum PDFKitReader {
-    private static func readPages(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder?,
+    private static func readPages(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder?, capture: RecoveryReadCapture?, verifyVisibility: Bool = false,
@@ -34,0 +35 @@ enum PDFKitReader {
+        capture?.reset()
@@ -38 +39 @@ enum PDFKitReader {
-        guard let size = size, size > 0, size <= MaterialLibrary.maximumBytes else { throw PDFParseError(code: .unreadable) }
+        guard let size = size, size > 0, size <= MaterialLibrary.maximumBytes else { throw PDFParseError(code: .unreadable, branch:.b091) }
@@ -42 +43,2 @@ enum PDFKitReader {
-              document.pageCount > 0, document.pageCount <= 12 else { throw PDFParseError(code: .unreadable) }
+              document.pageCount > 0, document.pageCount <= 12 else { throw PDFParseError(code: .unreadable, branch:.b092) }
+        capture?.begin(pageCount: document.pageCount)
@@ -48,2 +50,13 @@ enum PDFKitReader {
-                  let string = page.string, page.numberOfCharacters <= 100000 else {
-                throw PDFParseError(code: .unreadable, page: index + 1)
+                  page.numberOfCharacters <= 100000 else {
+                throw PDFParseError(code: .unreadable, page: index + 1, branch:.b093)
+            }
+            if verifyVisibility || kind == .timetable {
+                let media = ref.getBoxRect(.mediaBox), crop = ref.getBoxRect(.cropBox)
+                guard media == crop else {
+                    // The viewer displays CropBox. Selectable content outside it
+                    // must never become a complete timetable through MediaBox.
+                    throw PDFParseError(code:.unsupported,page:index+1,stage:.rasterInput, branch:.b094)
+                }
+            }
+            guard let string = page.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
+                throw PDFParseError(code: .unsupported, page: index + 1, stage: .rasterInput, branch:.b095)
@@ -54 +67 @@ enum PDFKitReader {
-                throw PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation)
+                throw PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation, branch:.b096)
@@ -59,0 +73,7 @@ enum PDFKitReader {
+            var recoveryGlyphs: [PDFGlyph]? = nil
+            var recoveryComplete = true
+            var textPaintBounds: [PDFBox] = []
+            func displayedBox(_ box: PDFBox) -> PDFBox {
+                let b = transform.rect(CGRect(x:box.left,y:box.top,width:box.right-box.left,height:box.bottom-box.top))
+                return PDFBox(left:Double(b.minX),top:Double(b.minY),right:Double(b.maxX),bottom:Double(b.maxY))
+            }
@@ -62 +82,2 @@ enum PDFKitReader {
-                    glyphs = try PDFDrawnTextReader(check: check).read(ref, expectedText: string).map { glyph in
+                    let drawnReader = PDFDrawnTextReader(deferFillValidation: true, check: check)
+                    func transformed(_ glyph:PDFGlyph) -> PDFGlyph {
@@ -67,0 +89,4 @@ enum PDFKitReader {
+                    glyphs = try drawnReader.read(ref,expectedText:string).map(transformed)
+                    textPaintBounds = drawnReader.engine.paintedGlyphBounds.map(displayedBox)
+                    recoveryGlyphs = drawnReader.engine.recoveryGlyphs.map(transformed)
+                    recoveryComplete = drawnReader.engine.recoveryComplete
@@ -72 +97 @@ enum PDFKitReader {
-                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
+                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping, branch:.b097)
@@ -76 +101 @@ enum PDFKitReader {
-                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
+                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder, branch:.b098)
@@ -81 +106 @@ enum PDFKitReader {
-                guard textLines.count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
+                guard textLines.count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1, branch:.b099) }
@@ -87 +112 @@ enum PDFKitReader {
-                    guard count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
+                    guard count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1, branch:.b100) }
@@ -93 +118 @@ enum PDFKitReader {
-                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
+                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder, branch:.b101)
@@ -96 +121 @@ enum PDFKitReader {
-                        guard coveredUnits <= ns.length * 2 else { throw PDFParseError(code: .limit, page: index + 1) }
+                        guard coveredUnits <= ns.length * 2 else { throw PDFParseError(code: .limit, page: index + 1, branch:.b102) }
@@ -103 +128 @@ enum PDFKitReader {
-                                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .textOrder)
+                                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .textOrder, branch:.b103)
@@ -121 +146 @@ enum PDFKitReader {
-                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
+                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder, branch:.b104)
@@ -129 +154 @@ enum PDFKitReader {
-                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
+                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping, branch:.b105)
@@ -136 +161 @@ enum PDFKitReader {
-                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
+                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping, branch:.b106)
@@ -148 +173,9 @@ enum PDFKitReader {
-            let reader = PDFPathReader(transform: transform, check: check)
+            let textLayout = PDFPageLayout(width:Double(transform.width),height:Double(transform.height),glyphs:glyphs,lines:[])
+            if verifyVisibility || kind == .timetable {
+                do { try textLayout.requireVisibleBounds(check:check) }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            }
+            var capturedText = textLayout
+            capturedText.glyphs = recoveryGlyphs ?? glyphs
+            capture?.record(page: index + 1, state: .partial, layout: capturedText)
+            let reader = PDFPathReader(transform: transform, verifyVisibility: verifyVisibility || kind == .timetable, textBoxes:glyphs.map { PDFBox(left:$0.x,top:$0.y,right:$0.x+$0.width,bottom:$0.y+$0.height) }, check: check)
@@ -151,3 +184,22 @@ enum PDFKitReader {
-            do { lines = try reader.read(ref) }
-            catch var error as PDFParseError { error.page = index + 1; throw error }
-            guard !glyphs.isEmpty, !lines.isEmpty else { throw PDFParseError(code: .unreadable, page: index + 1) }
+            do {
+                defer { diagnostics?.record(.paths,page:index+1,values:[Double(reader.operations),Double(reader.paintWork)]) }
+                lines = try reader.read(ref)
+                if reader.hasOutlinedText && kind != .timetable {
+                    // Preserve the validated PDFKit selections and their source
+                    // order. Reuse direct drawing only to bound outlined ink.
+                    let outlineReader = PDFDrawnTextReader(deferFillValidation:true,check:check)
+                    _ = try outlineReader.read(ref,expectedText:string)
+                    textPaintBounds = outlineReader.engine.paintedGlyphBounds.map(displayedBox)
+                }
+                if reader.hasOutlinedText { try reader.validateTextPaintBounds(textPaintBounds) }
+            } catch var error as PDFParseError { error.page = index + 1; throw error }
+            let layout = PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows)
+            if verifyVisibility || kind == .timetable {
+                do { try layout.requireVisibleBounds(check:check) }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            }
+            var capturedLayout = layout
+            capturedLayout.glyphs = recoveryGlyphs ?? glyphs
+            capture?.record(page: index + 1, state: glyphs.isEmpty ? .rasterOnly : recoveryComplete ? .complete : .partial, layout: capturedLayout)
+            guard !glyphs.isEmpty else { throw PDFParseError(code: .unsupported, page: index + 1, stage: .rasterInput, branch:.b107) }
+            guard !lines.isEmpty else { throw PDFParseError(code: .unsupported, page: index + 1, stage: .gridCell, branch:.b108) }
@@ -156 +208 @@ enum PDFKitReader {
-            output.append(PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows))
+            output.append(layout)
@@ -158,0 +211 @@ enum PDFKitReader {
+        capture?.finish()
diff --git a/Takupoke/PDFPaintSample.swift b/Takupoke/PDFPaintSample.swift
new file mode 100644
index 0000000..1eb89d1
--- /dev/null
+++ b/Takupoke/PDFPaintSample.swift
@@ -0,0 +1,68 @@
+import Foundation
+
+enum PDFPaintNumber {
+    // PDF numeric syntax has no exponent form. Expand Swift's exact decimal
+    // representation instead of rounding very small color or gamma values.
+    static func literal(_ value: Double) -> String {
+        let text = String(value)
+        guard let marker = text.firstIndex(where:{ $0 == "e" || $0 == "E" }),
+              let exponent = Int(text[text.index(after:marker)...]) else { return text }
+        let mantissa = String(text[..<marker]), sign = mantissa.hasPrefix("-") ? "-" : ""
+        let unsigned = mantissa.replacingOccurrences(of:"-",with:"")
+        let parts = unsigned.split(separator:".")
+        let digits = parts.joined(), position = parts[0].count + exponent
+        if position <= 0 { return sign + "0." + String(repeating:"0",count:-position) + digits }
+        if position >= digits.count { return sign + digits + String(repeating:"0",count:position-digits.count) }
+        let index = digits.index(digits.startIndex,offsetBy:position)
+        return sign + digits[..<index] + "." + digits[index...]
+    }
+}
+#if canImport(CoreGraphics)
+import CoreGraphics
+
+/// Probe only a solid color, using the PDF renderer's own interpretation. No
+/// source glyph, image, Unicode mapping or inferred timetable value is involved.
+enum PDFPaintSample {
+    static func brightness(definition: String, profile: Data?, count: Int,
+                           values: [Double], intent: CGColorRenderingIntent) -> Double? {
+        var rendering = ""
+        switch intent {
+        case .perceptual: rendering = "/Perceptual ri "
+        case .relativeColorimetric: rendering = "/RelativeColorimetric ri "
+        case .saturation: rendering = "/Saturation ri "
+        case .absoluteColorimetric: rendering = "/AbsoluteColorimetric ri "
+        default: break
+        }
+        let command = rendering + "/Paint cs " + values.map(PDFPaintNumber.literal).joined(separator:" ") + " scn 0 0 1 1 re f"
+        var objects = [
+            "<< /Type /Catalog /Pages 2 0 R >>",
+            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
+            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 1 1] /Resources << /ColorSpace << /Paint \(definition) >> >> /Contents 4 0 R >>",
+            "<< /Length \(command.utf8.count) >>\nstream\n\(command)\nendstream"
+        ].map { Data($0.utf8) }
+        if let profile {
+            var stream = Data("<< /N \(count) /Length \(profile.count) >>\nstream\n".utf8)
+            stream.append(profile); stream.append(Data("\nendstream".utf8)); objects.append(stream)
+        }
+        var data = Data("%PDF-1.4\n".utf8), offsets = [0]
+        for (index,object) in objects.enumerated() {
+            offsets.append(data.count); data.append(Data("\(index+1) 0 obj\n".utf8))
+            data.append(object); data.append(Data("\nendobj\n".utf8))
+        }
+        let start = data.count
+        var tail = "xref\n0 \(offsets.count)\n0000000000 65535 f \n"
+        for offset in offsets.dropFirst() { tail += String(format:"%010d 00000 n \n",offset) }
+        tail += "trailer\n<< /Size \(offsets.count) /Root 1 0 R >>\nstartxref\n\(start)\n%%EOF\n"
+        data.append(Data(tail.utf8))
+        guard let provider = CGDataProvider(data:data as CFData), let document = CGPDFDocument(provider),
+              let page = document.page(at:1) else { return nil }
+        var pixels = [UInt8](repeating:255,count:16)
+        return pixels.withUnsafeMutableBytes { buffer in
+            guard let context = CGContext(data:buffer.baseAddress,width:1,height:1,bitsPerComponent:8,
+                bytesPerRow:16,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGImageAlphaInfo.none.rawValue) else { return nil }
+            context.drawPDFPage(page)
+            return Double(buffer[0]) / 255
+        }
+    }
+}
+#endif
diff --git a/Takupoke/PDFPaintSpace.swift b/Takupoke/PDFPaintSpace.swift
new file mode 100644
index 0000000..9fe2e6d
--- /dev/null
+++ b/Takupoke/PDFPaintSpace.swift
@@ -0,0 +1,146 @@
+import Foundation
+#if canImport(CoreGraphics)
+import CoreGraphics
+
+/// Color conversion certifies paint against the supported white page background;
+/// it does not decode glyphs or supply Unicode evidence.
+struct PDFPaintSpace {
+    let count: Int
+    let space: CGColorSpace?
+    let device: Bool
+    private let definition: String
+    private let profile: Data?
+    private final class Samples { var values = [String:Double]() }
+    private let samples = Samples()
+    init(count: Int, space: CGColorSpace?, device: Bool = false, definition: String = "", profile: Data? = nil) {
+        self.count = count; self.space = space; self.device = device
+        self.definition = definition; self.profile = profile
+    }
+    static func device(_ count: Int) -> PDFPaintSpace {
+        switch count {
+        case 1: return PDFPaintSpace(count:1,space:CGColorSpaceCreateDeviceGray(),device:true,definition:"/DeviceGray")
+        case 3: return PDFPaintSpace(count:3,space:CGColorSpaceCreateDeviceRGB(),device:true,definition:"/DeviceRGB")
+        case 4: return PDFPaintSpace(count:4,space:CGColorSpaceCreateDeviceCMYK(),device:true,definition:"/DeviceCMYK")
+        default: return PDFPaintSpace(count:0,space:nil)
+        }
+    }
+    func brightness(_ values: [Double], intent: CGColorRenderingIntent) -> Double? {
+        guard space != nil, !definition.isEmpty, values.count == count else { return nil }
+        let key = String(intent.rawValue) + ":" + values.map { String($0) }.joined(separator:",")
+        if let sample = samples.values[key] { return sample }
+        let sample = PDFPaintSample.brightness(definition:definition,profile:profile,count:count,values:values,intent:intent)
+        if let sample, samples.values.count < 256 { samples.values[key] = sample }
+        return sample
+    }
+}
+
+final class PDFPaintSpaceResolver {
+    private var cache = [String:PDFPaintSpace]()
+    private var profileBytes = 0
+    func deviceDefault(_ scanner: CGPDFScannerRef, count: Int) throws -> PDFPaintSpace? {
+        let key = count == 1 ? "DefaultGray" : count == 3 ? "DefaultRGB" : "DefaultCMYK"
+        guard CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner),"ColorSpace",key) != nil else { return nil }
+        let result = try named(scanner,name:key)
+        if result.device && result.count == count { return nil }
+        return result.count == count ? result : PDFPaintSpace(count:count,space:nil)
+    }
+    func named(_ scanner: CGPDFScannerRef, name: String, visited: Set<String> = []) throws -> PDFPaintSpace {
+        guard visited.count < 8, !visited.contains(name) else { return PDFPaintSpace(count:0,space:nil) }
+        switch name {
+        case "DeviceGray": return .device(1)
+        case "DeviceRGB": return .device(3)
+        case "DeviceCMYK": return .device(4)
+        default: break
+        }
+        if let result = cache[name] { return result }
+        guard cache.count < 128 else { throw PDFParseError(code:.limit, branch:.b109) }
+        guard let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner),"ColorSpace",name) else {
+            throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b110)
+        }
+        var next = visited; next.insert(name)
+        var alias: UnsafePointer<CChar>?, array: CGPDFArrayRef?
+        let result: PDFPaintSpace
+        if CGPDFObjectGetValue(object,.name,&alias), let alias {
+            result = try named(scanner,name:String(cString:alias),visited:next)
+        } else if CGPDFObjectGetValue(object,.array,&array), let array {
+            result = try resolve(array)
+        } else { result = PDFPaintSpace(count:0,space:nil) }
+        cache[name] = result
+        return result
+    }
+    private func vector(_ dictionary: CGPDFDictionaryRef, _ key: String, count: Int,
+                        fallback: [CGFloat]? = nil) -> [CGFloat]? {
+        var object: CGPDFObjectRef?, array: CGPDFArrayRef?
+        guard CGPDFDictionaryGetObject(dictionary,key,&object) else { return fallback }
+        guard CGPDFDictionaryGetArray(dictionary,key,&array), let array, CGPDFArrayGetCount(array) == count else { return nil }
+        var values = [CGFloat]()
+        for index in 0..<count {
+            var number: CGPDFReal = 0
+            guard CGPDFArrayGetNumber(array,index,&number), number.isFinite else { return nil }
+            values.append(number)
+        }
+        return values
+    }
+    private func resolve(_ array: CGPDFArrayRef) throws -> PDFPaintSpace {
+        let unsupported = PDFPaintSpace(count:0,space:nil)
+        var name: UnsafePointer<CChar>?
+        guard CGPDFArrayGetCount(array) == 2, CGPDFArrayGetName(array,0,&name), let name else { return unsupported }
+        switch String(cString:name) {
+        case "ICCBased":
+            var stream: CGPDFStreamRef?
+            guard CGPDFArrayGetStream(array,1,&stream), let stream else { return unsupported }
+            guard let dictionary = CGPDFStreamGetDictionary(stream) else { return unsupported }
+            var count: CGPDFInteger = 0, length: CGPDFInteger = 0
+            guard CGPDFDictionaryGetInteger(dictionary,"N",&count), [1,3,4].contains(Int(count)) else { return unsupported }
+            let invalid = PDFPaintSpace(count:Int(count),space:nil)
+            // A nondefault Range can turn apparently dark component values
+            // into white. Do not certify a profile after dropping that setting.
+            var rangeObject: CGPDFObjectRef?, alternateObject: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary,"Range",&rangeObject) {
+                guard let range = vector(dictionary,"Range",count:2*Int(count)),
+                      range.enumerated().allSatisfy({ $0.element == ($0.offset % 2 == 0 ? 0 : 1) }) else { return invalid }
+            }
+            if CGPDFDictionaryGetObject(dictionary,"Alternate",&alternateObject) {
+                var name: UnsafePointer<CChar>?
+                let expected = count == 1 ? "DeviceGray" : count == 3 ? "DeviceRGB" : "DeviceCMYK"
+                guard CGPDFDictionaryGetName(dictionary,"Alternate",&name), let name,
+                      String(cString:name) == expected else { return invalid }
+            }
+            guard CGPDFDictionaryGetInteger(dictionary,"Length",&length), length > 0 else { return invalid }
+            guard length <= 1_048_576 else { throw PDFParseError(code:.limit, branch:.b111) }
+            var format = CGPDFDataFormat.raw
+            guard let data = CGPDFStreamCopyData(stream,&format), format == .raw else { return invalid }
+            let bytes = CFDataGetLength(data)
+            guard bytes <= 1_048_576, profileBytes <= 4_194_304 - bytes else { throw PDFParseError(code:.limit, branch:.b112) }
+            profileBytes += bytes
+            guard let space = CGColorSpace(iccData:data), space.numberOfComponents == Int(count) else { return invalid }
+            return PDFPaintSpace(count:Int(count),space:space,definition:"[/ICCBased 5 0 R]",profile:data as Data)
+        case "CalRGB", "CalGray":
+            let rgb = String(cString:name) == "CalRGB", count = rgb ? 3 : 1
+            let invalid = PDFPaintSpace(count:count,space:nil)
+            var dictionary: CGPDFDictionaryRef?
+            guard CGPDFArrayGetDictionary(array,1,&dictionary), let dictionary,
+                  let white = vector(dictionary,"WhitePoint",count:3), white[0] > 0, white[1] == 1, white[2] > 0,
+                  let black = vector(dictionary,"BlackPoint",count:3,fallback:[0,0,0]),
+                  black.allSatisfy({ $0 >= 0 }) else { return invalid }
+            if rgb {
+                guard let gamma = vector(dictionary,"Gamma",count:3,fallback:[1,1,1]), gamma.allSatisfy({ $0 > 0 }),
+                      let matrix = vector(dictionary,"Matrix",count:9,fallback:[1,0,0,0,1,0,0,0,1]) else { return invalid }
+                let definition = "[/CalRGB << /WhitePoint \(literal(white)) /BlackPoint \(literal(black)) /Gamma \(literal(gamma)) /Matrix \(literal(matrix)) >>]"
+                return PDFPaintSpace(count:3,space:CGColorSpace(calibratedRGBWhitePoint:white,
+                    blackPoint:black,gamma:gamma,matrix:matrix),definition:definition)
+            }
+            var gamma: CGPDFReal = 1, object: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary,"Gamma",&object) {
+                guard CGPDFDictionaryGetNumber(dictionary,"Gamma",&gamma), gamma.isFinite, gamma > 0 else { return invalid }
+            }
+            let definition = "[/CalGray << /WhitePoint \(literal(white)) /BlackPoint \(literal(black)) /Gamma \(PDFPaintNumber.literal(Double(gamma))) >>]"
+            return PDFPaintSpace(count:1,space:CGColorSpace(calibratedGrayWhitePoint:white,blackPoint:black,gamma:gamma),definition:definition)
+        default: return unsupported
+        }
+    }
+    private func literal(_ values: [CGFloat]) -> String {
+        "[" + values.map { PDFPaintNumber.literal(Double($0)) }.joined(separator:" ") + "]"
+    }
+}
+#endif
diff --git a/Takupoke/PDFParseError.swift b/Takupoke/PDFParseError.swift
index 733110c..7ba9def 100644
--- a/Takupoke/PDFParseError.swift
+++ b/Takupoke/PDFParseError.swift
@@ -6,0 +7,8 @@ struct PDFParseAttempt: Codable {
+    var recoveryJob: RecoveryJob? = nil
+    var parserVersion: Int? = nil
+    static func needsAnalysis(digest: String, parserVersion: Int, analysisDigest: String?, analysisVersion: Int?,
+                              attemptDigest: String?, failure: PDFParseError?, attemptVersion: Int?) -> Bool {
+        if analysisDigest == digest && analysisVersion == parserVersion { return false }
+        if attemptDigest == digest, let failure, failure.code != .cancelled, failure.code != .storage, attemptVersion == parserVersion { return false }
+        return true
+    }
@@ -15 +23,34 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-        case fragmentOverlap, fragmentAlignment
+        case fragmentOverlap, fragmentAlignment, rasterInput
+        case paintVisibility, clippingBounds, contentTags
+
+        var diagnosticCode: String {
+            let number: Int
+            switch self {
+            case .characterMapping: number = 1
+            case .pageRotation: number = 2
+            case .yearHeading: number = 3
+            case .documentHeading: number = 4
+            case .periodHeading: number = 5
+            case .gridColumn: number = 6
+            case .gridRow: number = 7
+            case .gridCell: number = 8
+            case .eventColumns: number = 9
+            case .calendarDates: number = 10
+            case .monthHeading: number = 11
+            case .vectorObjects: number = 12
+            case .textOrder: number = 13
+            case .classLabel: number = 14
+            case .gradeLabel: number = 15
+            case .duplicateClass: number = 16
+            case .lessonLines: number = 17
+            case .parallelLessons: number = 18
+            case .emptySubject: number = 19
+            case .fragmentOverlap: number = 20
+            case .fragmentAlignment: number = 21
+            case .rasterInput: number = 22
+            case .paintVisibility: number = 23
+            case .clippingBounds: number = 24
+            case .contentTags: number = 25
+            }
+            return String(format: "P%02d", number)
+        }
@@ -38,0 +80 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
+            case .rasterInput: return "画像からの文字認識が必要（P22）"
@@ -39,0 +82,3 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
+            case .paintVisibility: return "文字・罫線・背景の表示（P23）"
+            case .clippingBounds: return "表示範囲内の文字と罫線（P24）"
+            case .contentTags: return "PDFの表示に関わる情報（P25）"
@@ -59,0 +105,97 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
+    // Fixed identifiers for program rejection sites, never PDF source values.
+    enum Branch: String, Codable, CaseIterable {
+        case b001 = "R001", b002 = "R002", b003 = "R003"
+        case b004 = "R004", b005 = "R005", b006 = "R006"
+        case b007 = "R007", b008 = "R008", b009 = "R009"
+        case b010 = "R010", b011 = "R011", b012 = "R012"
+        case b013 = "R013", b014 = "R014", b015 = "R015"
+        case b016 = "R016", b017 = "R017", b018 = "R018"
+        case b019 = "R019", b020 = "R020", b021 = "R021"
+        case b022 = "R022", b023 = "R023", b024 = "R024"
+        case b025 = "R025", b026 = "R026", b027 = "R027"
+        case b028 = "R028", b029 = "R029", b030 = "R030"
+        case b031 = "R031", b032 = "R032", b033 = "R033"
+        case b034 = "R034", b035 = "R035", b036 = "R036"
+        case b037 = "R037", b038 = "R038", b039 = "R039"
+        case b040 = "R040", b041 = "R041", b042 = "R042"
+        case b043 = "R043", b044 = "R044", b045 = "R045"
+        case b046 = "R046", b047 = "R047", b048 = "R048"
+        case b049 = "R049", b050 = "R050", b051 = "R051"
+        case b052 = "R052", b053 = "R053", b054 = "R054"
+        case b055 = "R055", b056 = "R056", b057 = "R057"
+        case b058 = "R058", b059 = "R059", b060 = "R060"
+        case b061 = "R061", b062 = "R062", b063 = "R063"
+        case b064 = "R064", b065 = "R065", b066 = "R066"
+        case b067 = "R067", b068 = "R068", b069 = "R069"
+        case b070 = "R070", b071 = "R071", b072 = "R072"
+        case b073 = "R073", b074 = "R074", b075 = "R075"
+        case b076 = "R076", b077 = "R077", b078 = "R078"
+        case b079 = "R079", b080 = "R080", b081 = "R081"
+        case b082 = "R082", b083 = "R083", b084 = "R084"
+        case b085 = "R085", b086 = "R086", b087 = "R087"
+        case b088 = "R088", b089 = "R089", b090 = "R090"
+        case b091 = "R091", b092 = "R092", b093 = "R093"
+        case b094 = "R094", b095 = "R095", b096 = "R096"
+        case b097 = "R097", b098 = "R098", b099 = "R099"
+        case b100 = "R100", b101 = "R101", b102 = "R102"
+        case b103 = "R103", b104 = "R104", b105 = "R105"
+        case b106 = "R106", b107 = "R107", b108 = "R108"
+        case b109 = "R109", b110 = "R110", b111 = "R111"
+        case b112 = "R112", b113 = "R113", b114 = "R114"
+        case b115 = "R115", b116 = "R116", b117 = "R117"
+        case b118 = "R118", b119 = "R119", b120 = "R120"
+        case b121 = "R121", b122 = "R122", b123 = "R123"
+        case b124 = "R124", b125 = "R125", b126 = "R126"
+        case b127 = "R127", b128 = "R128", b129 = "R129"
+        case b130 = "R130", b131 = "R131", b132 = "R132"
+        case b133 = "R133", b134 = "R134", b135 = "R135"
+        case b136 = "R136", b137 = "R137", b138 = "R138"
+        case b139 = "R139", b140 = "R140", b141 = "R141"
+        case b142 = "R142", b143 = "R143", b144 = "R144"
+        case b145 = "R145", b146 = "R146", b147 = "R147"
+        case b148 = "R148", b149 = "R149", b150 = "R150"
+        case b151 = "R151", b152 = "R152", b153 = "R153"
+        case b154 = "R154", b155 = "R155", b156 = "R156"
+        case b157 = "R157", b158 = "R158", b159 = "R159"
+        case b160 = "R160", b161 = "R161", b162 = "R162"
+        case b163 = "R163", b164 = "R164", b165 = "R165"
+        case b166 = "R166", b167 = "R167", b168 = "R168"
+        case b169 = "R169", b170 = "R170", b171 = "R171"
+        case b172 = "R172", b173 = "R173", b174 = "R174"
+        case b175 = "R175", b176 = "R176", b177 = "R177"
+        case b178 = "R178", b179 = "R179", b180 = "R180"
+        case b181 = "R181", b182 = "R182", b183 = "R183"
+        case b184 = "R184", b185 = "R185", b186 = "R186"
+        case b187 = "R187", b188 = "R188", b189 = "R189"
+        case b190 = "R190", b191 = "R191", b192 = "R192"
+        case b193 = "R193", b194 = "R194", b195 = "R195"
+        case b196 = "R196", b197 = "R197", b198 = "R198"
+        case b199 = "R199", b200 = "R200", b201 = "R201"
+        case b202 = "R202", b203 = "R203", b204 = "R204"
+        case b205 = "R205", b206 = "R206", b207 = "R207"
+        case b208 = "R208", b209 = "R209", b210 = "R210"
+        case b211 = "R211", b212 = "R212", b213 = "R213"
+        case b214 = "R214", b215 = "R215", b216 = "R216"
+        case b217 = "R217", b218 = "R218", b219 = "R219"
+        case b220 = "R220", b221 = "R221", b222 = "R222"
+        case b223 = "R223", b224 = "R224", b225 = "R225"
+        case b226 = "R226", b227 = "R227", b228 = "R228"
+        case b229 = "R229", b230 = "R230", b231 = "R231"
+        case b232 = "R232", b233 = "R233", b234 = "R234"
+        case b235 = "R235", b236 = "R236", b237 = "R237"
+        case b238 = "R238", b239 = "R239", b240 = "R240"
+        case b241 = "R241", b242 = "R242", b243 = "R243"
+        case b244 = "R244", b245 = "R245", b246 = "R246"
+        case b247 = "R247", b248 = "R248", b249 = "R249"
+        case b250 = "R250", b251 = "R251", b252 = "R252"
+        case b253 = "R253", b254 = "R254", b255 = "R255"
+        case b256 = "R256", b257 = "R257", b258 = "R258"
+        case b259 = "R259", b260 = "R260", b261 = "R261"
+        case b262 = "R262"
+        case b263 = "R263", b264 = "R264", b265 = "R265"
+        case b266 = "R266", b267 = "R267"
+        case b268 = "R268", b269 = "R269"
+        case b270 = "R270"
+        case b271 = "R271"
+    }
+    var branch: Branch? = nil
@@ -67,2 +209 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-    var errorDescription: String? {
-        let reason: String
+    var userMessage: String {
@@ -70,6 +211,6 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-        case .unreadable: reason = "PDFを読み取れません。暗号化・破損・画像だけのPDFには対応していません。"
-        case .unsupported: reason = "未対応のPDF書式です。年度・見出し・表の構造を確認できません。"
-        case .ambiguous: reason = "表の内容を一意に読み取れません。推測せず解析を停止しました。"
-        case .limit: reason = "PDFの解析上限を超えています。"
-        case .cancelled: reason = "PDF解析を中止しました。"
-        case .storage: reason = "PDF解析結果を保存できませんでした。"
+        case .unreadable: return "PDFを読み取れませんでした。"
+        case .unsupported: return "PDFを解析できませんでした。対応していない書式が含まれています。"
+        case .ambiguous: return "PDFの内容を確実に読み取れないため、解析を停止しました。"
+        case .limit: return "PDFの解析上限を超えています。"
+        case .cancelled: return "PDF解析を中止しました。"
+        case .storage: return "PDF解析結果を保存できませんでした。"
@@ -77,3 +218,11 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-        return (page.map { "\($0)ページ目：" } ?? "") + reason +
-            (stage.map { "確認箇所：\($0.label)。" } ?? "") +
-            (cell.map { "対象：\($0.label)。" } ?? "") + "前回の正常な解析結果は保持しています。"
+    }
+    var retentionMessage: String { "前回の正常な解析結果は保持しています。" }
+    var userCode: String? {
+        let parts = [stage?.diagnosticCode, branch?.rawValue].compactMap { $0 }
+        let code = parts.joined(separator: " / ")
+        if let page { return code.isEmpty ? "\(page)ページ目" : "\(code)（\(page)ページ目）" }
+        return code.isEmpty ? nil : code
+    }
+    var errorDescription: String? {
+        [userMessage, retentionMessage, userCode.map { "エラーコード：\($0)" }]
+            .compactMap { $0 }.joined(separator: " ")
diff --git a/Takupoke/PDFPathReader.swift b/Takupoke/PDFPathReader.swift
index faf1ef8..117da53 100644
--- a/Takupoke/PDFPathReader.swift
+++ b/Takupoke/PDFPathReader.swift
@@ -1,0 +2,60 @@ import Foundation
+
+/// Broad-phase lookup only: every candidate still uses the original inclusive
+/// collision predicate. Index creation/search consume the caller's same budget.
+struct PDFTextCollisionIndex {
+    private let boxes: [PDFBox]
+    private let xOrder: [Int]
+    private let yOrder: [Int]
+    private let maximumWidth: Double
+    private let maximumHeight: Double
+
+    init(_ boxes: [PDFBox], work: () throws -> Void) throws {
+        guard boxes.count <= 100000 else { throw PDFParseError(code:.limit, branch:.b113) }
+        var width = 0.0, height = 0.0
+        for box in boxes {
+            try work()
+            guard [box.left,box.top,box.right,box.bottom].allSatisfy(\.isFinite),
+                  box.left <= box.right, box.top <= box.bottom,
+                  (box.right-box.left).isFinite, (box.bottom-box.top).isFinite else { throw PDFParseError(code:.unreadable, branch:.b114) }
+            width = max(width,box.right-box.left); height = max(height,box.bottom-box.top)
+        }
+        self.boxes = boxes; maximumWidth = width.nextUp; maximumHeight = height.nextUp
+        xOrder = try boxes.indices.sorted { a,b in try work(); return boxes[a].left < boxes[b].left }
+        yOrder = try boxes.indices.sorted { a,b in try work(); return boxes[a].top < boxes[b].top }
+    }
+    private func range(_ order: [Int], horizontal: Bool, lower: Double, upper: Double,
+                       work: () throws -> Void) throws -> Range<Int> {
+        func bound(_ target: Double, afterEqual: Bool) throws -> Int {
+            var start = 0, end = order.count
+            while start < end {
+                try work()
+                let mid = start+(end-start)/2
+                let coordinate = horizontal ? boxes[order[mid]].left : boxes[order[mid]].top
+                if coordinate < target || afterEqual && coordinate == target { start = mid+1 } else { end = mid }
+            }
+            return start
+        }
+        return try bound(lower,afterEqual:false)..<bound(upper,afterEqual:true)
+    }
+    func overlaps(_ query: PDFBox, pad: Double, excluding: Int? = nil, work: () throws -> Void) throws -> Bool {
+        guard [query.left,query.top,query.right,query.bottom,pad].allSatisfy(\.isFinite),
+              query.left <= query.right, query.top <= query.bottom, pad >= 0,
+              (query.left-pad).isFinite, (query.top-pad).isFinite,
+              (query.right+pad).isFinite, (query.bottom+pad).isFinite else { throw PDFParseError(code:.unreadable, branch:.b115) }
+        // An overlapping box starts no earlier than query-min minus the largest
+        // original extent. Outward rounding only broadens candidates; the exact
+        // collision predicate below still includes the same touching edges.
+        let xs = try range(xOrder,horizontal:true,lower:(query.left-pad-maximumWidth).nextDown,upper:(query.right+pad).nextUp,work:work)
+        let ys = try range(yOrder,horizontal:false,lower:(query.top-pad-maximumHeight).nextDown,upper:(query.bottom+pad).nextUp,work:work)
+        let horizontal = xs.count < ys.count
+        let selected = horizontal ? xs : ys, order = horizontal ? xOrder : yOrder
+        for index in selected {
+            try work()
+            if order[index] == excluding { continue }
+            let box = boxes[order[index]]
+            if box.left <= query.right+pad && query.left-pad <= box.right &&
+               box.top <= query.bottom+pad && query.top-pad <= box.bottom { return true }
+        }
+        return false
+    }
+}
@@ -30,0 +91,2 @@ final class PDFPathReader {
+    let verifyVisibility: Bool
+    let textBoxes: [PDFBox]
@@ -32,0 +95,12 @@ final class PDFPathReader {
+    private var widthStack: [Double] = []
+    private var lineWidth = 1.0
+    private var colors = PDFPaintColors()
+    private var colorStack: [PDFPaintColors] = []
+    private var uncertifiedOverprint = false
+    private var overprintStack: [Bool] = []
+    private var markedContent = PDFMarkedContent()
+    private var clips: [PDFBox] = []
+    private var paintedBoxes: [PDFBox] = []
+    private var collisionBoxes: [PDFBox] = []
+    private var backgroundBrightness: ClosedRange<Double>?
+    private let paintResolver = PDFPaintSpaceResolver()
@@ -38 +112,9 @@ final class PDFPathReader {
-    private var paintWork = 0
+    private var textSeen = false
+    private var textMode = 0.0
+    private var textModeStack: [Double] = []
+    private var solidDash = true
+    private var dashStack: [Bool] = []
+    private var curvedPath = false
+    private(set) var hasOutlinedText = false
+    private(set) var paintWork = 0
+    private var textIndex: PDFTextCollisionIndex?
@@ -48 +130,3 @@ final class PDFPathReader {
-    init(transform: PDFDisplayTransform, check: @escaping () throws -> Void) { self.transform = transform; self.check = check }
+    init(transform: PDFDisplayTransform, verifyVisibility: Bool = false, textBoxes: [PDFBox] = [], check: @escaping () throws -> Void) {
+        self.transform = transform; self.verifyVisibility = verifyVisibility; self.textBoxes = textBoxes; self.check = check
+    }
@@ -54 +138 @@ final class PDFPathReader {
-        if s.operations > 1000000 { s.failure = PDFParseError(code: .limit); return nil }
+        if s.operations > 1000000 { s.failure = PDFParseError(code: .limit, branch:.b116); return nil }
@@ -62 +146 @@ final class PDFPathReader {
-            guard CGPDFScannerPopNumber(scanner, &n), n.isFinite else { failure = PDFParseError(code: .unreadable); return nil }
+            guard CGPDFScannerPopNumber(scanner, &n), n.isFinite else { failure = PDFParseError(code: .unreadable, branch:.b117); return nil }
@@ -77 +161 @@ final class PDFPathReader {
-        if lines.count > 100000 { failure = PDFParseError(code: .limit) }
+        if lines.count > 100000 { failure = PDFParseError(code: .limit, branch:.b118) }
@@ -85 +169 @@ final class PDFPathReader {
-            failure = PDFParseError(code: .limit)
+            failure = PDFParseError(code: .limit, branch:.b119)
@@ -104,0 +189,12 @@ final class PDFPathReader {
+    private func overlapsText(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat, pad: Double) -> Bool {
+        do {
+            let work = { [self] in
+                guard consumePaintWork() else { throw failure ?? PDFParseError(code:.limit, branch:.b120) }
+            }
+            if textIndex == nil { textIndex = try PDFTextCollisionIndex(textBoxes,work:work) }
+            return try textIndex!.overlaps(PDFBox(left:Double(left),top:Double(top),right:Double(right),bottom:Double(bottom)),pad:pad,work:work)
+        } catch {
+            if failure == nil { failure = error }
+            return true
+        }
+    }
@@ -106 +202 @@ final class PDFPathReader {
-        defer { paths.removeAll(keepingCapacity: true) }
+        defer { paths.removeAll(keepingCapacity: true); curvedPath = false }
@@ -108,0 +205,123 @@ final class PDFPathReader {
+        if verifyVisibility && (curvedPath || stroke && !solidDash && !paths.isEmpty) {
+            failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b121); return
+        }
+        if verifyVisibility && !paths.isEmpty {
+            // A white page background is harmless only before any retained ink.
+            if fill && !stroke && colors.fill.isWhite && !textSeen && lines.isEmpty && arrows.isEmpty && paintedBoxes.isEmpty,
+               paths.count == 1, let box = rectangularPathBox(),
+               box == PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height)) { return }
+            guard (!fill || colors.fill.isVisibleInk) && (!stroke || colors.stroke.isVisibleInk) else {
+                failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b122); return
+            }
+        }
+        if verifyVisibility && fill && !paths.isEmpty {
+            guard !textSeen || !textBoxes.isEmpty else {
+                failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b123); return
+            }
+            // Certify rectangles against all original text, including later
+            // glyphs. Only thin fills become rules below; a disjoint decoration
+            // must not fail merely because it is too broad to be a table rule.
+            for path in paths {
+                if !stroke && isSupportedArrowHead(path) {
+                    guard requireBackgroundContrast(colors.fill) else { return }
+                    guard let box = bounds(of:path),
+                          !overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0) else {
+                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b124) }; return
+                    }
+                    collisionBoxes.append(PDFBox(left:Double(box.left),top:Double(box.top),right:Double(box.right),bottom:Double(box.bottom)))
+                    continue
+                }
+                guard let first = path.first, path.count == 5, path.last == first,
+                      Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
+                      let box = bounds(of:path) else {
+                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b125) }; return
+                }
+                let corners = [CGPoint(x:box.left,y:box.top),CGPoint(x:box.right,y:box.top),CGPoint(x:box.right,y:box.bottom),CGPoint(x:box.left,y:box.bottom)]
+                let uniqueCorners = corners.allSatisfy { corner in path.dropLast().filter { $0 == corner }.count == 1 }
+                let axisEdges = zip(path,path.dropFirst()).allSatisfy { a,b in (a.x == b.x) != (a.y == b.y) }
+                let width = box.right-box.left, height = box.bottom-box.top
+                let thinRule = (width <= 2.1 && height > 3) || (height <= 2.1 && width > 3)
+                // Standalone scans without acquired text bounds cannot certify
+                // a decoration against text that may be painted later.
+                guard uniqueCorners else {
+                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b126) }; return
+                }
+                guard axisEdges else {
+                    failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b263); return
+                }
+                guard thinRule || !textBoxes.isEmpty else {
+                    failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b264); return
+                }
+                let overlaps = overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0)
+                guard failure == nil else { return }
+                if overlaps {
+                    // A broad opaque rectangle before the first text operation
+                    // is a background, never a rule. Subsequent text must also
+                    // prove contrast; paint order alone does not prove visibility.
+                    guard !textSeen, !stroke, !thinRule else {
+                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b265); return
+                    }
+                    // One simple rectangle fills under both winding rules.
+                    // Multiple subpaths can cancel or cut holes (f / f*).
+                    guard paths.count == 1 else {
+                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b270); return
+                    }
+                    guard !uncertifiedOverprint else {
+                        failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b271); return
+                    }
+                    // Do not retain grid ink which an opaque background could
+                    // have erased. Earlier certified backgrounds alone are safe.
+                    guard lines.isEmpty, arrows.isEmpty, collisionBoxes.isEmpty else {
+                        failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b268); return
+                    }
+                    guard let brightness = colors.fill.renderedBrightness,
+                          brightness.isFinite, (0...1).contains(brightness) else {
+                        failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b266); return
+                    }
+                    if let previous = backgroundBrightness {
+                        backgroundBrightness = min(previous.lowerBound,brightness)...max(previous.upperBound,brightness)
+                    } else {
+                        // White remains a possible surface outside a partial
+                        // background; do not certify light text against dark
+                        // paint which might belong to a different cell.
+                        backgroundBrightness = brightness...1
+                    }
+                } else {
+                    guard requireBackgroundContrast(colors.fill) else { return }
+                    collisionBoxes.append(PDFBox(left:Double(box.left),top:Double(box.top),right:Double(box.right),bottom:Double(box.bottom)))
+                }
+            }
+        }
+        if verifyVisibility && stroke && !paths.isEmpty {
+            guard requireBackgroundContrast(colors.stroke) else { return }
+            guard PDFTextVisibility.similarStrokeTransform(a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)),
+                  let pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) else {
+                failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b127); return
+            }
+            for path in paths where path.count >= 2 {
+                for index in 1..<path.count {
+                    guard consumePaintWork() else { return }
+                    let a = path[index-1], b = path[index]
+                    guard (a.x == b.x || a.y == b.y),
+                          !overlapsText(left:min(a.x,b.x),top:min(a.y,b.y),right:max(a.x,b.x),bottom:max(a.y,b.y),pad:pad) else {
+                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b128) }; return
+                    }
+                    collisionBoxes.append(PDFBox(left:Double(min(a.x,b.x))-pad,top:Double(min(a.y,b.y))-pad,
+                                                 right:Double(max(a.x,b.x))+pad,bottom:Double(max(a.y,b.y))+pad))
+                }
+            }
+        }
+        if collisionBoxes.count > 100_000 { failure = PDFParseError(code:.limit, branch:.b129); return }
+        if verifyVisibility {
+            let pad: Double
+            if stroke {
+                pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) ?? 0
+            } else { pad = 0 }
+            for path in paths where path.count >= 2 {
+                guard let box = bounds(of:path), paintedBoxes.count < 100_000 else {
+                    if failure == nil { failure = PDFParseError(code:.limit, branch:.b130) }; return
+                }
+                paintedBoxes.append(PDFBox(left:Double(box.left)-pad,top:Double(box.top)-pad,
+                                           right:Double(box.right)+pad,bottom:Double(box.bottom)+pad))
+            }
+        }
@@ -163,0 +383,132 @@ final class PDFPathReader {
+    private func isSupportedArrowHead(_ path: [CGPoint]) -> Bool {
+        var vertices = path
+        if vertices.count == 4, vertices.first == vertices.last { vertices.removeLast() }
+        guard vertices.count == 3 else { return false }
+        let sorted = vertices.sorted { $0.y < $1.y }
+        let a = sorted[0], b = sorted[1], tip = sorted[2]
+        guard abs(a.y-b.y) < 1, (3...12).contains(abs(a.x-b.x)),
+              (3...12).contains(tip.y-max(a.y,b.y)), abs(tip.x-(a.x+b.x)/2) < 1 else { return false }
+        var matches = 0
+        for stem in paths {
+            guard consumePaintWork() else { return false }
+            guard stem.count == 5, stem.first == stem.last,
+                  Set(stem.map(\.x)).count == 2, Set(stem.map(\.y)).count == 2,
+                  zip(stem,stem.dropFirst()).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }),
+                  let box = bounds(of:stem), box.right-box.left < 2.1, box.bottom-box.top > 5,
+                  abs((box.left+box.right)/2-tip.x) < 2, abs(box.bottom-max(a.y,b.y)) < 2 else { continue }
+            matches += 1
+            if matches > 1 { return false }
+        }
+        return matches == 1
+    }
+    private func contrastsWithBackground(_ paint: PDFDevicePaint) -> Bool {
+        guard let background = backgroundBrightness else { return true }
+        guard !uncertifiedOverprint else { return false }
+        func linear(_ value: Double) -> Double {
+            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055,2.4)
+        }
+        guard let value = paint.renderedBrightness, value.isFinite, (0...1).contains(value) else { return false }
+        // Check the nearest brightness in the entire background interval,
+        // including combinations conservatively, without per-glyph guesses.
+        let nearest = min(max(value,background.lowerBound),background.upperBound)
+        let a = linear(value), b = linear(nearest)
+        return (max(a,b)+0.05)/(min(a,b)+0.05) >= 4.5
+    }
+    private func requireBackgroundContrast(_ paint: PDFDevicePaint) -> Bool {
+        guard contrastsWithBackground(paint) else {
+            failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b269); return false
+        }
+        return true
+    }
+    private func textContrastsWithBackground() -> Bool {
+        switch textMode {
+        case 0: return contrastsWithBackground(colors.fill)
+        case 1: return contrastsWithBackground(colors.stroke)
+        case 2: return contrastsWithBackground(colors.fill) && contrastsWithBackground(colors.stroke)
+        default: return false
+        }
+    }
+    private func rectangularPathBox() -> PDFBox? {
+        guard paths.count == 1, let path = paths.first, path.count == 5, path.first == path.last,
+              Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
+              zip(path,path.dropFirst()).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }),
+              path.dropLast().allSatisfy({ point in path.dropLast().filter { $0 == point }.count == 1 }) else { return nil }
+        return PDFBox(left:Double(path.map(\.x).min()!),top:Double(path.map(\.y).min()!),
+                      right:Double(path.map(\.x).max()!),bottom:Double(path.map(\.y).max()!))
+    }
+    private func recordClip() {
+        guard let box = rectangularPathBox() else { failure = PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b131); return }
+        let page = PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height))
+        guard PDFClipValidation.contains(box,page) else {
+            failure = PDFParseError(code:.unsupported,stage:.clippingBounds, branch:.b132); return
+        }
+        guard clips.count < 128 else { failure = PDFParseError(code:.limit, branch:.b133); return }
+        clips.append(box)
+    }
+    private func color(_ scanner: CGPDFScannerRef, stroke: Bool, count: Int? = nil, space: Bool = false) {
+        do {
+            var paint = stroke ? colors.stroke : colors.fill
+            if space {
+                try paint.space(scanner,resolver:paintResolver)
+            } else {
+                if let count {
+                    guard let n = numbers(scanner,count) else { return }
+                    try paint.device(n.map(Double.init),count:count)
+                    try paint.applyDefault(scanner,resolver:paintResolver)
+                } else { try paint.color(scanner) }
+            }
+            if stroke { colors.stroke = paint } else { colors.fill = paint }
+        } catch { failure = error }
+    }
+    // PDFKit selections also expose text that is not painted. A special schedule
+    // can reuse them only when the content stream has independently proved that
+    // opacity, text rendering and visibility are within this reader's subset.
+    private func graphicsStateIsVisible(_ scanner: CGPDFScannerRef) -> Bool {
+        var name: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner, &name), let name,
+              let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "ExtGState", String(cString:name)) else { return false }
+        var dictionary: CGPDFDictionaryRef?
+        guard CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary else { return false }
+        do { try colors.applyIntent(dictionary) } catch { return false }
+        // The single-color probe does not model overprint compositing. Keep
+        // existing no-background reads unchanged, but do not certify a new
+        // background or subsequent ink under enabled/unknown overprint.
+        var explicitlyDisabled = 0
+        for key in ["OP", "op"] {
+            var object: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary,key,&object) {
+                var value: CGPDFBoolean = 0
+                if !CGPDFDictionaryGetBoolean(dictionary,key,&value) || value != 0 {
+                    uncertifiedOverprint = true
+                } else { explicitlyDisabled += 1 }
+            }
+        }
+        // Both channels explicitly off replace an earlier enabled or unknown
+        // setting. A one-sided update cannot certify the other channel.
+        if explicitlyDisabled == 2 { uncertifiedOverprint = false }
+        for key in ["Font", "SMask", "TR", "TR2"] {
+            var value: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary,key,&value) { return false }
+        }
+        var dashObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetObject(dictionary,"D",&dashObject) {
+            var dash: CGPDFArrayRef?, pattern: CGPDFArrayRef?, phase: CGPDFReal = 0
+            guard CGPDFDictionaryGetArray(dictionary,"D",&dash), let dash, CGPDFArrayGetCount(dash) == 2,
+                  CGPDFArrayGetArray(dash,0,&pattern), let pattern,
+                  CGPDFArrayGetNumber(dash,1,&phase) else { return false }
+            do { solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase)) } catch { return false }
+        }
+        var width: CGPDFReal = 0, widthObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetNumber(dictionary,"LW",&width) {
+            guard width.isFinite, width >= 0 else { return false }
+            lineWidth = Double(width)
+        } else if CGPDFDictionaryGetObject(dictionary,"LW",&widthObject) { return false }
+        guard PDFPaintColors.hasNormalBlendMode(dictionary) else { return false }
+        for key in ["ca", "CA"] {
+            var value: CGPDFReal = 0, object: CGPDFObjectRef?
+            if CGPDFDictionaryGetNumber(dictionary,key,&value) {
+                guard value.isFinite, value == 1 else { return false }
+            } else if CGPDFDictionaryGetObject(dictionary,key,&object) { return false }
+        }
+        return true
+    }
@@ -165 +516 @@ final class PDFPathReader {
-        guard let table = CGPDFOperatorTableCreate() else { throw PDFParseError(code: .unreadable) }
+        guard let table = CGPDFOperatorTableCreate() else { throw PDFParseError(code: .unreadable, branch:.b134) }
@@ -169 +520,5 @@ final class PDFPathReader {
-            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit) } else { s.stack.append(s.ctm) }
+            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit, branch:.b135) } else {
+                s.stack.append(s.ctm); s.widthStack.append(s.lineWidth); s.colorStack.append(s.colors)
+                s.overprintStack.append(s.uncertifiedOverprint)
+                s.textModeStack.append(s.textMode); s.dashStack.append(s.solidDash)
+            }
@@ -173 +528,7 @@ final class PDFPathReader {
-            if let value = s.stack.popLast() { s.ctm = value } else { s.failure = PDFParseError(code: .unreadable) }
+            if let value = s.stack.popLast(), let width = s.widthStack.popLast(), let colors = s.colorStack.popLast(),
+               let mode = s.textModeStack.popLast(), let dash = s.dashStack.popLast(),
+               let overprint = s.overprintStack.popLast() {
+                s.ctm = value; s.lineWidth = width; s.colors = colors
+                s.uncertifiedOverprint = overprint
+                s.textMode = mode; s.solidDash = dash
+            } else { s.failure = PDFParseError(code: .unreadable, branch:.b136) }
@@ -182 +543 @@ final class PDFPathReader {
-            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit) }
+            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b137) }
@@ -187 +548 @@ final class PDFPathReader {
-            if s.paths[s.paths.count - 1].count > 10000 { s.failure = PDFParseError(code: .limit) }
+            if s.paths[s.paths.count - 1].count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b138) }
@@ -193 +554 @@ final class PDFPathReader {
-            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit) }
+            if s.paths.count > 10000 { s.failure = PDFParseError(code: .limit, branch:.b139) }
@@ -205 +566,4 @@ final class PDFPathReader {
-        CGPDFOperatorTableSetCallback(table, "n") { _, p in PDFPathReader.state(p)?.paths.removeAll(keepingCapacity: true) }
+        CGPDFOperatorTableSetCallback(table, "n") { _, p in
+            guard let s = PDFPathReader.state(p) else { return }
+            s.paths.removeAll(keepingCapacity:true); s.curvedPath = false
+        }
@@ -209,2 +573,3 @@ final class PDFPathReader {
-                guard let s = PDFPathReader.state(p), !s.paths.isEmpty else { return }
-                s.paths[s.paths.count - 1].removeAll()
+                guard let s = PDFPathReader.state(p) else { return }
+                if s.verifyVisibility { s.curvedPath = true }
+                if !s.paths.isEmpty { s.paths[s.paths.count - 1].removeAll() }
@@ -215 +580,85 @@ final class PDFPathReader {
-            PDFPathReader.state(p)?.failure = PDFParseError(code: .unsupported, stage: .vectorObjects)
+            PDFPathReader.state(p)?.failure = PDFParseError(code: .unsupported, stage: .vectorObjects, branch:.b140)
+        }
+        if verifyVisibility {
+            CGPDFOperatorTableSetCallback(table,"d") { scanner, p in
+                guard let s = PDFPathReader.state(p), let phase = s.numbers(scanner,1)?.first else { return }
+                var pattern: CGPDFArrayRef?
+                guard CGPDFScannerPopArray(scanner,&pattern), let pattern else {
+                    s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b141); return
+                }
+                do { s.solidDash = try PDFPaintColors.isSolidDash(pattern,phase:Double(phase)) }
+                catch { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b142) }
+            }
+            CGPDFOperatorTableSetCallback(table, "w") { scanner, p in
+                guard let s = PDFPathReader.state(p), let width = s.numbers(scanner,1)?.first else { return }
+                guard width >= 0 else { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b143); return }
+                s.lineWidth = Double(width)
+            }
+            CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in
+                guard let s = PDFPathReader.state(p) else { return }
+                if !s.graphicsStateIsVisible(scanner) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b144) }
+            }
+            CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
+                guard let s = PDFPathReader.state(p), let mode = s.numbers(scanner,1)?.first else { return }
+                guard [0.0,1,2].contains(Double(mode)) else {
+                    s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b145); return
+                }
+                s.textMode = Double(mode)
+            }
+            for op in ["Tj", "TJ", "'", "\""] {
+                CGPDFOperatorTableSetCallback(table, op) { _, p in
+                    guard let s = PDFPathReader.state(p) else { return }
+                    s.textSeen = true
+                    if !s.colors.canPaintText(mode:s.textMode) {
+                        s.failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b146)
+                    }
+                    if s.failure == nil && !s.textContrastsWithBackground() {
+                        s.failure = PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b267)
+                    }
+                    if s.textMode != 0 {
+                        s.hasOutlinedText = true
+                        if !s.solidDash || PDFTextVisibility.strokePad(s.lineWidth,a:Double(s.ctm.a),b:Double(s.ctm.b),c:Double(s.ctm.c),d:Double(s.ctm.d)) == nil {
+                            s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b147)
+                        }
+                    }
+                }
+            }
+            CGPDFOperatorTableSetCallback(table,"g") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:1) }
+            CGPDFOperatorTableSetCallback(table,"ri") { scanner,p in
+                guard let s = PDFPathReader.state(p) else { return }
+                do { try s.colors.intent(scanner) } catch { s.failure = error }
+            }
+            CGPDFOperatorTableSetCallback(table,"G") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:1) }
+            CGPDFOperatorTableSetCallback(table,"rg") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:3) }
+            CGPDFOperatorTableSetCallback(table,"RG") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:3) }
+            CGPDFOperatorTableSetCallback(table,"k") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,count:4) }
+            CGPDFOperatorTableSetCallback(table,"K") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,count:4) }
+            CGPDFOperatorTableSetCallback(table,"cs") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false,space:true) }
+            CGPDFOperatorTableSetCallback(table,"CS") { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true,space:true) }
+            for op in ["sc", "scn"] {
+                CGPDFOperatorTableSetCallback(table,op) { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:false) }
+            }
+            for op in ["SC", "SCN"] {
+                CGPDFOperatorTableSetCallback(table,op) { scanner,p in PDFPathReader.state(p)?.color(scanner,stroke:true) }
+            }
+            for op in ["W", "W*"] {
+                CGPDFOperatorTableSetCallback(table,op) { _,p in PDFPathReader.state(p)?.recordClip() }
+            }
+            CGPDFOperatorTableSetCallback(table,"BMC") { scanner,p in
+                guard let s = PDFPathReader.state(p) else { return }
+                do { try s.markedContent.begin(scanner,properties:false) } catch { s.failure = error }
+            }
+            CGPDFOperatorTableSetCallback(table,"BDC") { scanner,p in
+                guard let s = PDFPathReader.state(p) else { return }
+                do { try s.markedContent.begin(scanner,properties:true) } catch { s.failure = error }
+            }
+            CGPDFOperatorTableSetCallback(table,"EMC") { _,p in
+                guard let s = PDFPathReader.state(p) else { return }
+                do { try s.markedContent.end() } catch { s.failure = error }
+            }
+            // Unsupported painted objects still require separate verification.
+            for op in ["BI", "ID", "EI", "sh"] {
+                CGPDFOperatorTableSetCallback(table, op) { _, p in
+                    PDFPathReader.state(p)?.failure = PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b148)
+                }
+            }
@@ -220,0 +670,4 @@ final class PDFPathReader {
+        if verifyVisibility {
+            try colors.fill.applyDefault(scanner,resolver:paintResolver)
+            try colors.stroke.applyDefault(scanner,resolver:paintResolver)
+        }
@@ -224 +677,13 @@ final class PDFPathReader {
-        guard succeeded else { throw PDFParseError(code: .unreadable) }
+        guard succeeded else { throw PDFParseError(code: .unreadable, branch:.b149) }
+        if verifyVisibility {
+            guard stack.isEmpty else { throw PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b150) }
+            do {
+                try markedContent.finish()
+                try PDFClipValidation.requireContains(textBoxes+paintedBoxes,clips:clips,work:{
+                    guard self.consumePaintWork() else { throw self.failure ?? PDFParseError(code:.limit, branch:.b151) }
+                },check:check)
+            } catch var error as PDFParseError {
+                if error.stage == .characterMapping { error.stage = .vectorObjects }
+                throw error
+            }
+        }
@@ -226,0 +692,14 @@ final class PDFPathReader {
+
+    func validateTextPaintBounds(_ boxes: [PDFBox]) throws {
+        let work = { [self] in
+            guard consumePaintWork() else { throw failure ?? PDFParseError(code:.limit, branch:.b152) }
+        }
+        let page = PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height))
+        try PDFClipValidation.requireContains(boxes,clips:[page]+clips,work:work,check:check)
+        let index = try PDFTextCollisionIndex(boxes,work:work)
+        for box in collisionBoxes {
+            if try index.overlaps(box,pad:0,work:work) {
+                throw PDFParseError(code:.unsupported,stage:.vectorObjects, branch:.b153)
+            }
+        }
+    }
diff --git a/Takupoke/PDFSchoolParser+Timetable.swift b/Takupoke/PDFSchoolParser+Timetable.swift
index 07db4e8..02fd545 100644
--- a/Takupoke/PDFSchoolParser+Timetable.swift
+++ b/Takupoke/PDFSchoolParser+Timetable.swift
@@ -10 +10 @@ extension PDFSchoolParser {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
+            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b158)
@@ -13,2 +13,2 @@ extension PDFSchoolParser {
-        let first = try grid.box(header[0].cx, header[0].cy)
-        let classBox = try grid.box(first.left - 2, first.bottom + 20)
+        let first = try grid.box(header[0].cx, header[0].cy,check:check)
+        let classBox = try grid.box(first.left - 2, first.bottom + 20,check:check)
@@ -16 +16 @@ extension PDFSchoolParser {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .gridColumn)
+            throw PDFParseError(code: .unsupported, page: 1, stage: .gridColumn, branch:.b159)
@@ -19,0 +20,7 @@ extension PDFSchoolParser {
+        let bodyRows = try classRows.map { glyphs -> PDFBox in
+            let y = glyphs.map(\.cy).reduce(0,+)/Double(glyphs.count)
+            var row = try grid.box((classBox.left+classBox.right)/2,y,check:check)
+            row.top = max(row.top,try grid.box(header[0].cx,y,check:check).top)
+            return row
+        }
+        let referenceBoxes = try grid.lessonBoxes(rows:bodyRows,columns:header.map(\.cx),check:check)
@@ -26 +33 @@ extension PDFSchoolParser {
-                throw PDFParseError(code: .ambiguous, page: 1, stage: .classLabel)
+                throw PDFParseError(code: .ambiguous, page: 1, stage: .classLabel, branch:.b160)
@@ -29,2 +36,2 @@ extension PDFSchoolParser {
-            var row = try grid.box((classBox.left + classBox.right) / 2, y)
-            let grade = try key(grid.text(grid.box(classBox.left - 2, y)).joined())
+            var row = try grid.box((classBox.left + classBox.right) / 2, y,check:check)
+            let grade = try key(grid.text(grid.box(classBox.left - 2, y,check:check),check:check).joined())
@@ -32 +39 @@ extension PDFSchoolParser {
-                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel)
+                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel, branch:.b161)
@@ -35 +42 @@ extension PDFSchoolParser {
-            guard classes.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass) }
+            guard classes.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass, branch:.b162) }
@@ -38 +45 @@ extension PDFSchoolParser {
-            row.top = max(row.top, try grid.box(header[0].cx, y).top)
+            row.top = max(row.top, try grid.box(header[0].cx, y,check:check).top)
@@ -46 +53 @@ extension PDFSchoolParser {
-                    let box = try grid.box(h.cx, (edges[i] + edges[i + 1]) / 2)
+                    let box = try grid.box(h.cx, (edges[i] + edges[i + 1]) / 2,check:check)
@@ -50 +57 @@ extension PDFSchoolParser {
-                    do { lines = try grid.timetableText(box) }
+                    do { lines = try grid.timetableText(box,check:check) }
@@ -54 +61 @@ extension PDFSchoolParser {
-                            error.geometry = PDFCellGeometryDiagnostic(grid.glyphs(in: box), box: box)
+                            error.geometry = PDFCellGeometryDiagnostic(try grid.glyphs(in:box,check:check), box: box)
@@ -60,3 +67,4 @@ extension PDFSchoolParser {
-                    guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, page: 1) }
-                    guard lines.count <= 3, !lines[0].isEmpty else { throw PDFParseError(code: .ambiguous, page: 1, stage: .lessonLines, cell: cell) }
-                    let fields = lines + Array(repeating: "", count: 3 - lines.count)
+                    guard lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else { throw PDFParseError(code: .limit, page: 1, branch:.b163) }
+                    guard lines.count <= 3, !lines[0].isEmpty else { throw PDFParseError(code: .ambiguous, page: 1, stage: .lessonLines, cell: cell, branch:.b164) }
+                    guard !lines.contains(where:RecoveryRole.hasLabelPrefix) else { throw PDFParseError(code: .unsupported, stage: .lessonLines, cell: cell, branch:.b165) }
+                    let fields = try grid.lessonFields(box, lines: lines,referenceBoxes:referenceBoxes,check:check)
@@ -65,2 +73,2 @@ extension PDFSchoolParser {
-                    if parts[0].count > 1 && parts[1].count > 1 && !parallel {
-                        throw PDFParseError(code: .ambiguous, page: 1, stage: .parallelLessons, cell: cell)
+                    if parts.filter({ $0.count > 1 }).count >= 2 && !parallel {
+                        throw PDFParseError(code: .ambiguous, page: 1, stage: .parallelLessons, cell: cell, branch:.b166)
@@ -68 +76 @@ extension PDFSchoolParser {
-                    if parallel && parts[0].contains(where: { $0.isEmpty }) { throw PDFParseError(code: .ambiguous, page: 1, stage: .emptySubject, cell: cell) }
+                    if parallel && parts[0].contains(where: { $0.isEmpty }) { throw PDFParseError(code: .ambiguous, page: 1, stage: .emptySubject, cell: cell, branch:.b167) }
@@ -76 +84 @@ extension PDFSchoolParser {
-                    if output.count > maximumRecords { throw PDFParseError(code: .limit) }
+                    if output.count > maximumRecords { throw PDFParseError(code: .limit, branch:.b168) }
@@ -80 +88 @@ extension PDFSchoolParser {
-        guard !classes.isEmpty, !output.isEmpty else { throw PDFParseError(code: .unsupported, page: 1) }
+        guard !classes.isEmpty, !output.isEmpty else { throw PDFParseError(code: .unsupported, page: 1, branch:.b169) }
diff --git a/Takupoke/PDFSchoolParser.swift b/Takupoke/PDFSchoolParser.swift
index e57a714..5f25c15 100644
--- a/Takupoke/PDFSchoolParser.swift
+++ b/Takupoke/PDFSchoolParser.swift
@@ -4,0 +5,47 @@ enum PDFSchoolParser {
+    struct YearMarker { let year: Int; let range: Range<String.Index>; let isReiwa: Bool }
+    static func yearMarkers(_ header: String,check: () throws -> Void = {}) throws -> [YearMarker] {
+        // Remove header whitespace while preserving raw numeric characters:
+        // compatibility normalization can turn an unsupported Roman numeral
+        // into letters and hide its annual marker. Evidence keeps raw bounds.
+        var normalized = "", originalRanges = [Range<String.Index>]()
+        for (offset,index) in header.indices.enumerated() {
+            if offset % 128 == 0 { try check() }
+            let original = index..<header.index(after:index)
+            var detector = ""
+            for scalar in header[original].unicodeScalars {
+                switch scalar.properties.generalCategory {
+                case .decimalNumber, .letterNumber, .otherNumber: detector += String(scalar)
+                default: detector += String(scalar).precomposedStringWithCompatibilityMapping
+                }
+            }
+            for character in detector {
+                if character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) { continue }
+                normalized.append(character); originalRanges.append(original)
+            }
+        }
+        guard normalized.count == originalRanges.count else { throw PDFParseError(code:.unsupported,stage:.yearHeading, branch:.b170) }
+        let originals = Dictionary(uniqueKeysWithValues:zip(normalized.indices,originalRanges))
+        var markers = [YearMarker](), remainder = normalized.startIndex..<normalized.endIndex
+        while let range = normalized.range(of:"(?<![\\p{N}])(?:令和[^年]*?|[\\p{N}]+)年度",options:.regularExpression,range:remainder) {
+            try check()
+            let token = normalized[range], era = token.hasPrefix("令和")
+            let digits = String(era ? token.dropFirst(2).dropLast(2) : token.dropLast(2)).precomposedStringWithCompatibilityMapping
+            guard (era ? (1...2).contains(digits.count) : digits.count == 4),
+                  digits.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(digits),
+                  !era || (1...99).contains(value) else { throw PDFParseError(code:.unsupported,stage:.yearHeading, branch:.b171) }
+            let year = era ? 2018+value:value
+            guard (1900...9998).contains(year) else { throw PDFParseError(code:.unsupported,stage:.yearHeading, branch:.b172) }
+            guard let first = originals[range.lowerBound], let last = originals[normalized.index(before:range.upperBound)] else {
+                throw PDFParseError(code:.unsupported,stage:.yearHeading, branch:.b173)
+            }
+            markers.append(YearMarker(year:year,range:first.lowerBound..<last.upperBound,isReiwa:era))
+            remainder = range.upperBound..<normalized.endIndex
+        }
+        return markers
+    }
+    static func uniqueTitleYear(_ header: String,check: () throws -> Void = {}) throws -> Int {
+        let markers = try yearMarkers(header,check:check)
+        guard let first = markers.first, markers.contains(where:\.isReiwa) else { throw PDFParseError(code:.unsupported,stage:.yearHeading, branch:.b174) }
+        guard markers.allSatisfy({ $0.year == first.year }) else { throw PDFParseError(code:.ambiguous,stage:.yearHeading, branch:.b175) }
+        return first.year
+    }
@@ -10 +57 @@ enum PDFSchoolParser {
-        guard kind != .changes, !pages.isEmpty, pages.count <= 12 else { throw PDFParseError(code: .unsupported) }
+        guard kind != .changes, !pages.isEmpty, pages.count <= 12 else { throw PDFParseError(code: .unsupported, branch:.b176) }
@@ -21 +68,5 @@ enum PDFSchoolParser {
-                throw PDFParseError(code: .limit, page: index + 1)
+                throw PDFParseError(code: .limit, page: index + 1, branch:.b177)
+            }
+            if kind == .timetable {
+                do { try page.requireVisibleBounds(check:check) }
+                catch var error as PDFParseError { error.page = index+1; throw error }
@@ -26,3 +77,11 @@ enum PDFSchoolParser {
-        guard let range = normalized.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
-              let era = Int(normalized[range].dropFirst(2).dropLast(2)), (1...99).contains(era) else {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .yearHeading)
+        let year: Int
+        if kind == .timetable {
+            do { year = try uniqueTitleYear(top,check:check) }
+            catch var error as PDFParseError { error.page = 1; throw error }
+        } else {
+            // Legacy event PDFs retain their original header contract.
+            guard let range = normalized.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
+                  let era = Int(normalized[range].dropFirst(2).dropLast(2)), (1...99).contains(era) else {
+                throw PDFParseError(code: .unsupported, page: 1, stage: .yearHeading, branch:.b178)
+            }
+            year = 2018+era
@@ -30 +88,0 @@ enum PDFSchoolParser {
-        let year = 2018 + era
@@ -32,4 +90,10 @@ enum PDFSchoolParser {
-            let heading = key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 8 }).map { $0.map(\.text).joined() }.joined())
-            guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
-                  Int(heading[range].dropFirst(2).dropLast(2)) == era else {
-                throw PDFParseError(code: .unsupported, page: index + 1, stage: .yearHeading)
+            let rawHeading = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 8 }).map { $0.map(\.text).joined() }.joined()
+            let heading = key(rawHeading)
+            if kind == .timetable {
+                do { guard try uniqueTitleYear(rawHeading,check:check) == year else { throw PDFParseError(code:.ambiguous,stage:.yearHeading, branch:.b179) } }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            } else {
+                guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
+                      Int(heading[range].dropFirst(2).dropLast(2)) == year-2018 else {
+                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .yearHeading, branch:.b180)
+                }
@@ -43 +107 @@ enum PDFSchoolParser {
-                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading)
+                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading, branch:.b181)
@@ -48,2 +112,2 @@ enum PDFSchoolParser {
-            result.notices = ["PDFの記載名を表示しています。正式名称の対応表はまだ取り込んでいません。",
-                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更との統合はまだ行いません。"]
+            result.notices = ["PDFの記載名を解析結果として保存しています。正式名称の対応は表示時に適用します。",
+                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更は日付ごとの表示時に反映します。"]
@@ -52 +116 @@ enum PDFSchoolParser {
-                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading)
+                throw PDFParseError(code: .unsupported, page: 1, stage: .documentHeading, branch:.b182)
@@ -59 +123 @@ enum PDFSchoolParser {
-                    guard months.isDisjoint(with: parsed.months) else { throw PDFParseError(code: .ambiguous) }
+                    guard months.isDisjoint(with: parsed.months) else { throw PDFParseError(code: .ambiguous, branch:.b183) }
@@ -65 +129 @@ enum PDFSchoolParser {
-            guard months == Set(1...12), !result.events.isEmpty else { throw PDFParseError(code: .unsupported) }
+            guard months == Set(1...12), !result.events.isEmpty else { throw PDFParseError(code: .unsupported, branch:.b184) }
@@ -72 +136 @@ enum PDFSchoolParser {
-        guard result.lessons.count + result.events.count <= maximumRecords else { throw PDFParseError(code: .limit) }
+        guard result.lessons.count + result.events.count <= maximumRecords else { throw PDFParseError(code: .limit, branch:.b185) }
diff --git a/Takupoke/PDFTextGeometry.swift b/Takupoke/PDFTextGeometry.swift
index 67446f9..a97c0b6 100644
--- a/Takupoke/PDFTextGeometry.swift
+++ b/Takupoke/PDFTextGeometry.swift
@@ -6 +6,28 @@ enum PDFTextFailure {
-    static var unsupported: PDFParseError { PDFParseError(code: .unsupported, stage: .characterMapping) }
+    static func unsupported(_ branch: PDFParseError.Branch) -> PDFParseError {
+        PDFParseError(code:.unsupported,stage:.characterMapping,branch:branch)
+    }
+}
+
+/// Paint visibility is independent of canonical black classification. Supported
+/// colors must remain visible on the certified white background; opacity,
+/// clipping and later paint are checked separately by the readers.
+enum PDFTextVisibility {
+    static func similarStrokeTransform(a: Double,b: Double,c: Double,d: Double) -> Bool {
+        guard [a,b,c,d].allSatisfy(\.isFinite) else { return false }
+        let first = hypot(a,b), second = hypot(c,d)
+        // A device-axis corner can represent an acute source-angle miter under
+        // shear/nonuniform scale. Only exact angle-preserving bases certify pad.
+        return first.isFinite && first > 0 && first == second && a*c+b*d == 0
+    }
+    static func strokePad(_ width: Double, a: Double, b: Double, c: Double, d: Double) -> Double? {
+        guard width.isFinite, width >= 0, [a,b,c,d].allSatisfy(\.isFinite) else { return nil }
+        // Frobenius norm bounds every transformed stroke direction, including shear.
+        let scale = hypot(hypot(a,b),hypot(c,d)), extent = max(1,width*scale)
+        guard scale.isFinite, scale > 0, extent.isFinite, extent <= 2 else { return nil }
+        return extent/2
+    }
+    static func blackColor(_ components: [Double], count: Int) -> Bool {
+        guard components.count == count, components.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return false }
+        if count == 1 || count == 3 { return components.allSatisfy { $0 == 0 } }
+        return count == 4 && components == [0,0,0,1]
+    }
@@ -13 +40 @@ struct PDFTextMatrix {
-        guard n.count == 6, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported }
+        guard n.count == 6, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported(.b186) }
@@ -29,0 +57,4 @@ final class PDFTextGeometry {
+        var lineWidth = 1.0
+        var lineJoin = 0.0, miterLimit = 10.0
+        var solidDash = true
+        var colors = PDFPaintColors()
@@ -36,0 +68,7 @@ final class PDFTextGeometry {
+    // Keep Strict's stream unchanged and preserve original drawn whitespace
+    // separately for Recovery. Incomplete whitespace geometry remains partial.
+    private(set) var recoveryGlyphs: [PDFGlyph] = []
+    private(set) var recoveryComplete = true
+    private(set) var paintedGlyphBounds: [PDFBox] = []
+    private var occlusionBounds: [PDFBox?] = []
+    private var whiteFillGlyphs: [Int] = []
@@ -38,0 +77 @@ final class PDFTextGeometry {
+    private var clips: [PDFBox] = []
@@ -44 +83 @@ final class PDFTextGeometry {
-        guard operations <= 1_000_000 else { throw PDFParseError(code: .limit) }
+        guard operations <= 1_000_000 else { throw PDFParseError(code: .limit, branch:.b187) }
@@ -47,2 +86,4 @@ final class PDFTextGeometry {
-                      "T*": 0, "Tc": 1, "Tw": 1, "Tz": 1, "TL": 1, "Ts": 1, "Tr": 1]
-        guard let count = counts[op], n.count == count, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported }
+                      "T*": 0, "Tc": 1, "Tw": 1, "Tz": 1, "TL": 1, "Ts": 1, "Tr": 1,
+                      "g": 1, "G": 1, "rg": 3, "RG": 3, "k": 4, "K": 4,
+                      "w": 1, "j": 1, "M": 1]
+        guard let count = counts[op], n.count == count, n.allSatisfy(\.isFinite) else { throw PDFTextFailure.unsupported(.b188) }
@@ -49,0 +91,2 @@ final class PDFTextGeometry {
+        case "g", "rg", "k": try state.colors.fill.device(n, count: n.count)
+        case "G", "RG", "K": try state.colors.stroke.device(n, count: n.count)
@@ -51 +94 @@ final class PDFTextGeometry {
-            guard stack.count < 64 else { throw PDFParseError(code: .limit) }
+            guard stack.count < 64 else { throw PDFParseError(code: .limit, branch:.b189) }
@@ -54 +97 @@ final class PDFTextGeometry {
-            guard let saved = stack.popLast() else { throw PDFTextFailure.unsupported }; state = saved
+            guard let saved = stack.popLast() else { throw PDFTextFailure.unsupported(.b190) }; state = saved
@@ -58 +101 @@ final class PDFTextGeometry {
-            guard !inText else { throw PDFTextFailure.unsupported }
+            guard !inText else { throw PDFTextFailure.unsupported(.b191) }
@@ -61 +104 @@ final class PDFTextGeometry {
-            guard inText else { throw PDFTextFailure.unsupported }; inText = false
+            guard inText else { throw PDFTextFailure.unsupported(.b192) }; inText = false
@@ -63 +106 @@ final class PDFTextGeometry {
-            guard inText else { throw PDFTextFailure.unsupported }
+            guard inText else { throw PDFTextFailure.unsupported(.b193) }
@@ -66 +109 @@ final class PDFTextGeometry {
-            guard inText else { throw PDFTextFailure.unsupported }
+            guard inText else { throw PDFTextFailure.unsupported(.b194) }
@@ -74,0 +118,9 @@ final class PDFTextGeometry {
+        case "w":
+            guard n[0] >= 0 else { throw PDFTextFailure.unsupported(.b195) }
+            state.lineWidth = n[0]
+        case "j":
+            guard [0.0, 1, 2].contains(n[0]) else { throw PDFTextFailure.unsupported(.b196) }
+            state.lineJoin = n[0]
+        case "M":
+            guard n[0] >= 1 else { throw PDFTextFailure.unsupported(.b197) }
+            state.miterLimit = n[0]
@@ -76 +128,3 @@ final class PDFTextGeometry {
-            guard [0, 1, 2].contains(n[0]) else { throw PDFTextFailure.unsupported }
+            // Restore the visible modes supported by the original reader.
+            // Stroke color and extent are checked when text is actually drawn.
+            guard [0.0, 1, 2].contains(n[0]) else { throw PDFTextFailure.unsupported(.b198) }
@@ -78 +132 @@ final class PDFTextGeometry {
-        default: throw PDFTextFailure.unsupported
+        default: throw PDFTextFailure.unsupported(.b199)
@@ -81,2 +135,2 @@ final class PDFTextGeometry {
-    func font(_ font: PDFTextFont, size: Double) throws {
-        guard size.isFinite, size > 0 else { throw PDFTextFailure.unsupported }
+    func font(_ font: PDFTextFont?, size: Double) throws {
+        guard size.isFinite, size > 0 else { throw PDFTextFailure.unsupported(.b200) }
@@ -86 +140 @@ final class PDFTextGeometry {
-        guard inText, amount.isFinite else { throw PDFTextFailure.unsupported }
+        guard inText, amount.isFinite else { throw PDFTextFailure.unsupported(.b201) }
@@ -90 +144,7 @@ final class PDFTextGeometry {
-        guard inText, let font = state.font, state.size > 0, state.scale > 0,
+        try check()
+        guard inText, state.size > 0, state.scale > 0 else { throw PDFTextFailure.unsupported(.b202) }
+        if bytes.isEmpty { return }
+        guard state.colors.canPaintText(mode:state.rendering) else {
+            throw PDFParseError(code:.unsupported,stage:.paintVisibility, branch:.b203)
+        }
+        guard let font = state.font,
@@ -92 +152 @@ final class PDFTextGeometry {
-            throw PDFTextFailure.unsupported
+            throw PDFTextFailure.unsupported(.b204)
@@ -98 +158,2 @@ final class PDFTextGeometry {
-                  textUnits + text.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported }
+                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
+                  textUnits + text.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported(.b205) }
@@ -106 +167,6 @@ final class PDFTextGeometry {
-            guard (xs + ys).allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { throw PDFTextFailure.unsupported }
+            guard (xs + ys).allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { throw PDFTextFailure.unsupported(.b206) }
+            let x = xs.min()!, y = ys.min()!, right = xs.max()!, upper = ys.max()!
+            let validGeometry = width > 0 && right > x && upper > y
+            if validGeometry {
+                recoveryGlyphs.append(PDFGlyph(text:text,x:x,y:y,width:right-x,height:upper-y,sourceLine:line,sourceOrder:order))
+            } else { recoveryComplete = false }
@@ -108,2 +174,22 @@ final class PDFTextGeometry {
-                guard width > 0, let x = xs.min(), let y = ys.min(), let right = xs.max(), let upper = ys.max(),
-                      right > x, upper > y else { throw PDFTextFailure.unsupported }
+                guard validGeometry else { throw PDFTextFailure.unsupported(.b207) }
+                var painted = PDFBox(left:x, top:y, right:right, bottom:upper)
+                let ink = outlineBox(font, code:cid, matrix:total)
+                if state.rendering != 0 {
+                    let ctm = state.ctm
+                    guard state.solidDash, let ink,
+                          let strokePad = PDFTextVisibility.strokePad(state.lineWidth, a:ctm.a, b:ctm.b, c:ctm.c, d:ctm.d) else {
+                        throw PDFTextFailure.unsupported(.b208)
+                    }
+                    // Use the encoded glyph path where available; otherwise the
+                    // conservative font box, never the advance alone.
+                    // Include the configured miter reach before collision/clip checks.
+                    let pad = strokePad * (state.lineJoin == 0 ? state.miterLimit : 1)
+                    painted = PDFBox(left:min(painted.left,ink.left - pad), top:min(painted.top,ink.top - pad),
+                                     right:max(painted.right,ink.right + pad), bottom:max(painted.bottom,ink.bottom + pad))
+                    guard [painted.left,painted.top,painted.right,painted.bottom].allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else {
+                        throw PDFTextFailure.unsupported(.b209)
+                    }
+                }
+                if state.rendering == 2 && state.colors.fill.isWhite { whiteFillGlyphs.append(occlusionBounds.count) }
+                occlusionBounds.append(state.rendering == 0 ? ink : painted)
+                paintedGlyphBounds.append(painted)
@@ -118,0 +205,32 @@ final class PDFTextGeometry {
+    private func outlineBox(_ font: PDFTextFont, code: Int, matrix: PDFTextMatrix) -> PDFBox? {
+        let selected = font.encodedGlyphBounds.map { $0[code] } ?? font.outlineBounds
+        guard let bounds = selected else { return nil }
+        let left = bounds.left / 1000 * state.size * state.scale
+        let right = bounds.right / 1000 * state.size * state.scale
+        let low = bounds.top / 1000 * state.size + state.rise
+        let high = bounds.bottom / 1000 * state.size + state.rise
+        let points = [matrix.point(left,low), matrix.point(left,high),
+                      matrix.point(right,low), matrix.point(right,high)]
+        let xs = points.map { Double($0.x) }, ys = points.map { Double($0.y) }
+        guard (xs+ys).allSatisfy({ $0.isFinite && abs($0) < 10_000_000 }) else { return nil }
+        return PDFBox(left:xs.min()!,top:ys.min()!,right:xs.max()!,bottom:ys.max()!)
+    }
+
+    private func requireNoWhiteGlyphOcclusion() throws {
+        guard !whiteFillGlyphs.isEmpty else { return }
+        let boxes = occlusionBounds.compactMap { $0 }
+        guard boxes.count == occlusionBounds.count else { throw PDFTextFailure.unsupported(.b210) }
+        var workCount = 0
+        let work = { [self] in
+            workCount += 1
+            guard workCount <= 1_000_000 else { throw PDFParseError(code:.limit, branch:.b211) }
+            if workCount % 128 == 0 { try check() }
+        }
+        let index = try PDFTextCollisionIndex(boxes,work:work)
+        for glyph in whiteFillGlyphs {
+            try check()
+            if try index.overlaps(boxes[glyph],pad:0,excluding:glyph,work:work) {
+                throw PDFTextFailure.unsupported(.b212)
+            }
+        }
+    }
@@ -121 +239 @@ final class PDFTextGeometry {
-        guard !inText, stack.isEmpty, !glyphs.isEmpty, expectedText.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported }
+        guard !inText, stack.isEmpty, !glyphs.isEmpty, expectedText.utf16.count <= 100_000 else { throw PDFTextFailure.unsupported(.b213) }
@@ -129 +247,3 @@ final class PDFTextGeometry {
-        guard content(drawnText) == content(expectedText) else { throw PDFTextFailure.unsupported }
+        guard content(drawnText) == content(expectedText) else { throw PDFTextFailure.unsupported(.b214) }
+        try requireNoWhiteGlyphOcclusion()
+        try PDFClipValidation.requireContains(paintedGlyphBounds, clips: clips, check: check)
@@ -131,0 +252,5 @@ final class PDFTextGeometry {
+
+    func clip(_ box: PDFBox) throws {
+        guard clips.count < 128 else { throw PDFParseError(code: .limit, branch:.b215) }
+        clips.append(box)
+    }
diff --git a/Takupoke/PDFUnicodeMap.swift b/Takupoke/PDFUnicodeMap.swift
index a124729..a1d5c9a 100644
--- a/Takupoke/PDFUnicodeMap.swift
+++ b/Takupoke/PDFUnicodeMap.swift
@@ -9,0 +10,2 @@ struct PDFTextFont {
+    let outlineBounds: PDFBox?
+    let encodedGlyphBounds: [Int: PDFBox]?
@@ -12 +14 @@ struct PDFTextFont {
-         ascent: Double, descent: Double) throws {
+         ascent: Double, descent: Double, outlineBounds: PDFBox? = nil, encodedGlyphBounds: [Int: PDFBox]? = nil) throws {
@@ -16 +18 @@ struct PDFTextFont {
-            throw PDFTextFailure.unsupported
+            throw PDFTextFailure.unsupported(.b216)
@@ -19,0 +22,12 @@ struct PDFTextFont {
+        if let box = outlineBounds {
+            guard [box.left, box.top, box.right, box.bottom].allSatisfy(\.isFinite),
+                  box.left < box.right, box.top < box.bottom else { throw PDFTextFailure.unsupported(.b217) }
+        }
+        self.outlineBounds = outlineBounds
+        if let encodedGlyphBounds {
+            guard encodedGlyphBounds.count <= 65536, encodedGlyphBounds.allSatisfy({ key, box in
+                (0...65535).contains(key) && [box.left,box.top,box.right,box.bottom].allSatisfy(\.isFinite) &&
+                box.left < box.right && box.top < box.bottom
+            }) else { throw PDFTextFailure.unsupported(.b218) }
+        }
+        self.encodedGlyphBounds = encodedGlyphBounds
@@ -26 +40,2 @@ enum PDFUnicodeMap {
-    static func read(_ data: Data) throws -> (bytes: Int, values: [Int: String]) {
+    static func read(_ data: Data, check: () throws -> Void = {}) throws -> (bytes: Int, values: [Int: String]) {
+        try check()
@@ -28 +43 @@ enum PDFUnicodeMap {
-            throw PDFTextFailure.unsupported
+            throw PDFTextFailure.unsupported(.b219)
@@ -33 +48,6 @@ enum PDFUnicodeMap {
-        let tokens = regex.matches(in: noComments, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
+        let matches = regex.matches(in: noComments, range: NSRange(location:0,length:ns.length))
+        var tokens = [String]()
+        for (index,match) in matches.enumerated() {
+            if index % 128 == 0 { try check() }
+            tokens.append(ns.substring(with:match.range))
+        }
@@ -35,3 +55,10 @@ enum PDFUnicodeMap {
-              !tokens.contains("beginnotdefchar") else { throw PDFTextFailure.unsupported }
-        var spaces: [(Int, Int)] = [], byteCount: Int?, values: [Int: String] = [:]
-        var i = 0
+              !tokens.contains("beginnotdefchar") else { throw PDFTextFailure.unsupported(.b220) }
+        // The code domain is finite. Each valid disjoint range marks at most
+        // 65,536 positions in total; membership no longer rescans every range.
+        var covered = [Bool](repeating:false,count:65536)
+        var byteCount: Int?, values: [Int: String] = [:]
+        var i = 0, work = 0
+        func consume() throws {
+            work += 1
+            if work % 128 == 0 { try check() }
+        }
@@ -39 +66 @@ enum PDFUnicodeMap {
-            guard value.first == "<", value.last == ">" else { throw PDFTextFailure.unsupported }
+            guard value.first == "<", value.last == ">" else { throw PDFTextFailure.unsupported(.b221) }
@@ -41 +68 @@ enum PDFUnicodeMap {
-            guard !body.isEmpty, body.count % 2 == 0, body.count <= 128 else { throw PDFTextFailure.unsupported }
+            guard !body.isEmpty, body.count % 2 == 0, body.count <= 128 else { throw PDFTextFailure.unsupported(.b222) }
@@ -45 +72 @@ enum PDFUnicodeMap {
-                guard let b = UInt8(body[cursor..<end], radix: 16) else { throw PDFTextFailure.unsupported }
+                guard let b = UInt8(body[cursor..<end], radix: 16) else { throw PDFTextFailure.unsupported(.b223) }
@@ -52 +79 @@ enum PDFUnicodeMap {
-            guard let count = byteCount, b.count == count else { throw PDFTextFailure.unsupported }
+            guard let count = byteCount, b.count == count else { throw PDFTextFailure.unsupported(.b224) }
@@ -55,0 +83 @@ enum PDFUnicodeMap {
+            try consume()
@@ -57,4 +85,3 @@ enum PDFUnicodeMap {
-                  spaces.contains(where: { $0.0 <= key && key <= $0.1 }),
-                  let text = String(data: Data(bytes), encoding: .utf16BigEndian), !text.isEmpty,
-                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
-                throw PDFTextFailure.unsupported
+                  covered.indices.contains(key), covered[key],
+                  let text = String(data: Data(bytes), encoding: .utf16BigEndian), !text.isEmpty else {
+                throw PDFTextFailure.unsupported(.b225)
@@ -61,0 +89,2 @@ enum PDFUnicodeMap {
+            // Unused entries (including the conventional .notdef NUL) are
+            // metadata. PDFTextGeometry rejects a control mapping at actual use.
@@ -65 +94,2 @@ enum PDFUnicodeMap {
-            guard i < tokens.count else { throw PDFTextFailure.unsupported }
+            try consume()
+            guard i < tokens.count else { throw PDFTextFailure.unsupported(.b226) }
@@ -69 +99 @@ enum PDFUnicodeMap {
-            let token = tokens[i]; i += 1
+            let token = try next()
@@ -71 +101 @@ enum PDFUnicodeMap {
-                guard try next() == "0" else { throw PDFTextFailure.unsupported }
+                guard try next() == "0" else { throw PDFTextFailure.unsupported(.b227) }
@@ -74 +104 @@ enum PDFUnicodeMap {
-            guard i >= 2, let count = Int(tokens[i - 2]), (1...65536).contains(count) else { throw PDFTextFailure.unsupported }
+            guard i >= 2, let count = Int(tokens[i - 2]), (1...65536).contains(count) else { throw PDFTextFailure.unsupported(.b228) }
@@ -79 +109 @@ enum PDFUnicodeMap {
-                          byteCount == nil || byteCount == low.count else { throw PDFTextFailure.unsupported }
+                          byteCount == nil || byteCount == low.count else { throw PDFTextFailure.unsupported(.b229) }
@@ -82,2 +112,6 @@ enum PDFUnicodeMap {
-                    guard l <= h, !spaces.contains(where: { l <= $0.1 && h >= $0.0 }) else { throw PDFTextFailure.unsupported }
-                    spaces.append((l, h))
+                    guard l <= h else { throw PDFTextFailure.unsupported(.b230) }
+                    for code in l...h {
+                        try consume()
+                        guard !covered[code] else { throw PDFTextFailure.unsupported(.b231) }
+                        covered[code] = true
+                    }
@@ -89 +123 @@ enum PDFUnicodeMap {
-                    guard high >= low, high - low < 65536 else { throw PDFTextFailure.unsupported }
+                    guard high >= low, high - low < 65536 else { throw PDFTextFailure.unsupported(.b232) }
@@ -93 +127 @@ enum PDFUnicodeMap {
-                        guard try next() == "]" else { throw PDFTextFailure.unsupported }
+                        guard try next() == "]" else { throw PDFTextFailure.unsupported(.b233) }
@@ -103 +137 @@ enum PDFUnicodeMap {
-                                guard !carry else { throw PDFTextFailure.unsupported }
+                                guard !carry else { throw PDFTextFailure.unsupported(.b234) }
@@ -110 +144 @@ enum PDFUnicodeMap {
-            guard try next() == ending else { throw PDFTextFailure.unsupported }
+            guard try next() == ending else { throw PDFTextFailure.unsupported(.b235) }
@@ -112 +146 @@ enum PDFUnicodeMap {
-        guard let bytes = byteCount, !values.isEmpty else { throw PDFTextFailure.unsupported }
+        guard let bytes = byteCount, !values.isEmpty else { throw PDFTextFailure.unsupported(.b236) }
diff --git a/Takupoke/SpecialSchedule.swift b/Takupoke/SpecialSchedule.swift
index 78bdec3..ed6cf57 100644
--- a/Takupoke/SpecialSchedule.swift
+++ b/Takupoke/SpecialSchedule.swift
@@ -26 +26 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
-    static let parserVersion = 6
+    static let parserVersion = 28
@@ -36,0 +37 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
+    var recovery: RecoveryAdopted? = nil
@@ -43,0 +45 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
+        if let recovered = recovery?.document.times["\(date):\(period)"] { return recovered }
diff --git a/Takupoke/SpecialScheduleParser+Pages.swift b/Takupoke/SpecialScheduleParser+Pages.swift
index 8be40fd..2c47587 100644
--- a/Takupoke/SpecialScheduleParser+Pages.swift
+++ b/Takupoke/SpecialScheduleParser+Pages.swift
@@ -14 +14 @@ extension SpecialScheduleParser {
-        guard labels.count == columns else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .classLabel) }
+        guard labels.count == columns else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .classLabel, branch:.b237) }
@@ -22 +22 @@ extension SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .calendarDates)
+            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .calendarDates, branch:.b238)
@@ -24,0 +25 @@ extension SpecialScheduleParser {
+        let referenceBoxes = try grid.lessonBoxes(rows:dateRuns.map { try grid.box($0.0.cx,$0.0.cy,check:check) },columns:periods.map(\.cx),check:check)
@@ -28 +29 @@ extension SpecialScheduleParser {
-            let row = try grid.box(dayRun.cx, dayRun.cy)
+            let row = try grid.box(dayRun.cx, dayRun.cy,check:check)
@@ -38 +39 @@ extension SpecialScheduleParser {
-                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2)
+                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2,check:check)
@@ -42 +43 @@ extension SpecialScheduleParser {
-                                              times: times, pageNumber: pageNumber)
+                                              times: times, pageNumber: pageNumber,referenceBoxes:referenceBoxes,using:grid,check:check)
@@ -55 +56 @@ extension SpecialScheduleParser {
-        guard step > 5 else { throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading) }
+        guard step > 5 else { throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b239) }
@@ -61,2 +62,3 @@ extension SpecialScheduleParser {
-        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5 else {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .calendarDates)
+        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5,
+              zip(dates,dates.dropFirst()).allSatisfy({ $0.0.1 < $0.1.1 }) else {
+            throw PDFParseError(code: .unsupported, page: 1, stage: .calendarDates, branch:.b240)
@@ -72 +74 @@ extension SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading)
+            throw PDFParseError(code: .unsupported, page: 1, stage: .periodHeading, branch:.b241)
@@ -86 +88 @@ extension SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, page: 1, stage: .classLabel)
+            throw PDFParseError(code: .unsupported, page: 1, stage: .classLabel, branch:.b242)
@@ -88,0 +91 @@ extension SpecialScheduleParser {
+        let referenceBoxes = try grid.lessonBoxes(rows:classRuns.map { try grid.box($0.cx,$0.cy,check:check) },columns:periods.map(\.cx),check:check)
@@ -95 +98 @@ extension SpecialScheduleParser {
-                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel)
+                throw PDFParseError(code: .ambiguous, page: 1, stage: .gradeLabel, branch:.b243)
@@ -98,2 +101,2 @@ extension SpecialScheduleParser {
-            guard seenClasses.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass) }
-            let row = try grid.box(run.cx, run.cy)
+            guard seenClasses.insert(name).inserted else { throw PDFParseError(code: .ambiguous, page: 1, stage: .duplicateClass, branch:.b244) }
+            let row = try grid.box(run.cx, run.cy,check:check)
@@ -110 +113 @@ extension SpecialScheduleParser {
-                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2)
+                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2,check:check)
@@ -114 +117 @@ extension SpecialScheduleParser {
-                                              times: dayTimes, pageNumber: 1)
+                                              times: dayTimes, pageNumber: 1,referenceBoxes:referenceBoxes,using:grid,check:check)
diff --git a/Takupoke/SpecialScheduleParser+Times.swift b/Takupoke/SpecialScheduleParser+Times.swift
index 504f1d3..7707302 100644
--- a/Takupoke/SpecialScheduleParser+Times.swift
+++ b/Takupoke/SpecialScheduleParser+Times.swift
@@ -5,0 +6 @@ extension SpecialScheduleParser {
+        guard (1...8).contains(count) else { throw PDFParseError(code:.unsupported,page:pageNumber,stage:.periodHeading, branch:.b245) }
@@ -20 +21 @@ extension SpecialScheduleParser {
-                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
+                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b246)
@@ -34 +35 @@ extension SpecialScheduleParser {
-                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
+                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b247)
@@ -41 +42,9 @@ extension SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading)
+            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading, branch:.b248)
+        }
+        for period in 1..<count {
+            // Canonical HH:mm strings have the same order as clock minutes.
+            // Explicit consecutive periods remain their own PDF-backed chart.
+            guard let previous = times[period], let current = times[period+1],
+                  String(previous.suffix(5)) <= String(current.prefix(5)) else {
+                throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.periodHeading, branch:.b249)
+            }
diff --git a/Takupoke/SpecialScheduleParser.swift b/Takupoke/SpecialScheduleParser.swift
index 1e14c7c..44c7fa0 100644
--- a/Takupoke/SpecialScheduleParser.swift
+++ b/Takupoke/SpecialScheduleParser.swift
@@ -25 +25 @@ enum SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, stage: .documentHeading)
+            throw PDFParseError(code: .unsupported, stage: .documentHeading, branch:.b250)
@@ -38 +38 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .limit, page: index + 1)
+                throw PDFParseError(code: .limit, page: index + 1, branch:.b251)
@@ -40,5 +40,6 @@ enum SpecialScheduleParser {
-            let header = PDFSchoolParser.key(PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 4 })
-                .map { $0.map(\.text).joined() }.joined())
-            guard let range = header.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
-                  let era = Int(header[range].dropFirst(2).dropLast(2)),
-                  (1...99).contains(era), header.contains("試験"),
+            do { try page.requireVisibleBounds(check:check) }
+            catch var error as PDFParseError { error.page = index+1; throw error }
+            let rawHeader = PDFGrid.rows(page.glyphs.filter { $0.cy < page.height / 4 })
+                .map { $0.map(\.text).joined() }.joined()
+            let header = PDFSchoolParser.key(rawHeader)
+            guard header.contains("試験"),
@@ -46 +47 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .unsupported, page: index + 1, stage: .documentHeading)
+                throw PDFParseError(code: .unsupported, page: index + 1, stage: .documentHeading, branch:.b252)
@@ -48 +49,3 @@ enum SpecialScheduleParser {
-            let pageYear = 2018 + era
+            let pageYear: Int
+            do { pageYear = try PDFSchoolParser.uniqueTitleYear(rawHeader,check:check) }
+            catch var error as PDFParseError { error.page = index+1; throw error }
@@ -50 +53 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .yearHeading)
+                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .yearHeading, branch:.b253)
@@ -56 +59 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .periodHeading)
+                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .periodHeading, branch:.b254)
@@ -65 +68 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .calendarDates)
+                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .calendarDates, branch:.b255)
@@ -69 +72 @@ enum SpecialScheduleParser {
-                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .duplicateClass)
+                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .duplicateClass, branch:.b256)
@@ -73 +76 @@ enum SpecialScheduleParser {
-            guard lessons.count <= PDFSchoolParser.maximumRecords else { throw PDFParseError(code: .limit) }
+            guard lessons.count <= PDFSchoolParser.maximumRecords else { throw PDFParseError(code: .limit, branch:.b257) }
@@ -76 +79 @@ enum SpecialScheduleParser {
-              coveredClasses.count == 17, !lessons.isEmpty else { throw PDFParseError(code: .unsupported) }
+              coveredClasses == Set(RecoveryValidator.specialClasses), !lessons.isEmpty else { throw PDFParseError(code: .unsupported, branch:.b258) }
@@ -108 +111 @@ enum SpecialScheduleParser {
-            throw PDFParseError(code: .unsupported, stage: .periodHeading)
+            throw PDFParseError(code: .unsupported, stage: .periodHeading, branch:.b259)
@@ -125,3 +128,3 @@ enum SpecialScheduleParser {
-                                times: Times, pageNumber: Int) throws -> [SpecialScheduleLesson] {
-        let grid = PDFGrid(page: page)
-        let lines = try grid.timetableText(box).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
+                                times: Times, pageNumber: Int, referenceBoxes: [PDFBox], using suppliedGrid: PDFGrid? = nil, check: () throws -> Void = {}) throws -> [SpecialScheduleLesson] {
+        let grid = suppliedGrid ?? PDFGrid(page: page)
+        let rawLines = try grid.timetableText(box,check:check).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
@@ -129,2 +132,2 @@ enum SpecialScheduleParser {
-        guard lines.count <= 8, lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
-            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .lessonLines)
+        guard rawLines.count <= 3, rawLines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
+            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .lessonLines, branch:.b260)
@@ -132 +135,3 @@ enum SpecialScheduleParser {
-        guard !lines.isEmpty else { return [] }
+        guard !rawLines.isEmpty else { return [] }
+        guard !rawLines.contains(where:RecoveryRole.hasLabelPrefix) else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .lessonLines, branch:.b261) }
+        let lines = try grid.lessonFields(box, lines: rawLines,referenceBoxes:referenceBoxes,check:check)
@@ -136 +141 @@ enum SpecialScheduleParser {
-            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .gridCell)
+            throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .gridCell, branch:.b262)
```

## Strictから呼ぶ追加の共通判定

元の文字列からラベルprefixを検出する純粋関数と固定のクラス集合。これらの呼出しはモデル推論ではない。

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
