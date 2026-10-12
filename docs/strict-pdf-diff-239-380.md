# PDF厳格解析の完全な差分：239.1 → 380.1

比較元：`bfc599fd5a552ced0c140497c703199547c30fd4`（239.1）。
比較先：`bfdf7c51b31d5331a9308ac8cb4ae28388aaa897`（380.1の配布ソース）。
対象は[調査記録](strict-pdf-diff-audit-239-380.md)のStrict本体18ファイル。
新たにStrictから呼ぶ共通判定2箇所の定義は、同じ調査記録へ別途収録している。
18ファイルすべての124差分区間を省略せず収録する。
コンテキスト行は`--unified=0`で省き、追加・削除された行はすべて残している。

下のdiff本文は1,624行、99,133 bytes、SHA-256は
`f27ee9776695d2fa05eccdaaf1d661f35ac821e226d997ee5ac8b05a8de91930`。
このハッシュはMarkdown全体ではなく、コードブロック内のdiff本文に対応する。
所有する一時Git領域で旧18ファイルに適用し、新18ファイルとの全bytes一致を確認済み。
旧ソースへ適用する場合は`git apply --unidiff-zero`の形式。
製品の作業ツリーへこの文書の差分を適用してはいない。

```diff
diff --git a/Takupoke/PDFAnalysis.swift b/Takupoke/PDFAnalysis.swift
index 937c68c..7a7647e 100644
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
+        guard width.isFinite, height.isFinite, width > 0, height > 0 else { throw PDFParseError(code:.unsupported,stage:.rasterInput) }
+        for (index,glyph) in glyphs.enumerated() {
+            if index % 128 == 0 { try check() }
+            guard glyph.width.isFinite, glyph.height.isFinite, glyph.width >= 0, glyph.height >= 0,
+                  inside(glyph.x,glyph.y), inside(glyph.x+glyph.width,glyph.y+glyph.height) else {
+                throw PDFParseError(code:.unsupported,stage:.rasterInput)
+            }
+        }
+        for (index,line) in lines.enumerated() {
+            if index % 128 == 0 { try check() }
+            guard inside(line.x1,line.y1), inside(line.x2,line.y2) else { throw PDFParseError(code:.unsupported,stage:.rasterInput) }
+        }
+    }
@@ -36 +58 @@ struct PDFPageLayout: Codable {
-struct PDFArrow: Codable { var x: Double; var top: Double; var bottom: Double }
+struct PDFArrow: Codable, Sendable { var x: Double; var top: Double; var bottom: Double }
@@ -157 +179 @@ struct PDFAnalysis: Codable {
-    static let parserVersion = 8
+    static let parserVersion = 28
@@ -169,0 +192 @@ struct PDFAnalysis: Codable {
+    var recovery: RecoveryAdopted? = nil
diff --git a/Takupoke/PDFContentVisibility.swift b/Takupoke/PDFContentVisibility.swift
new file mode 100644
index 0000000..8304833
--- /dev/null
+++ b/Takupoke/PDFContentVisibility.swift
@@ -0,0 +1,231 @@
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
+            throw PDFParseError(code:.unsupported,stage:.paintVisibility)
+        }
+        self.count = count; components = values
+    }
+    mutating func space(_ name: String) throws {
+        switch name {
+        case "DeviceGray": try device([0], count: 1)
+        case "DeviceRGB": try device([0, 0, 0], count: 3)
+        case "DeviceCMYK": try device([0, 0, 0, 1], count: 4)
+        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility)
+        }
+    }
+}
+
+struct PDFPaintColors {
+    var fill = PDFDevicePaint(), stroke = PDFDevicePaint()
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
+        guard clips.count <= 128 else { throw PDFParseError(code: .limit) }
+        var comparisons = 0
+        for clip in clips { for box in boxes {
+            try work()
+            comparisons += 1
+            guard comparisons <= 1_000_000 else { throw PDFParseError(code: .limit) }
+            if comparisons % 128 == 0 { try check() }
+            guard contains(clip, box) else { throw PDFParseError(code:.unsupported,stage:.clippingBounds) }
+        } }
+        try check()
+    }
+}
+
+#if canImport(CoreGraphics)
+import CoreGraphics
+
+extension PDFPaintColors {
+    mutating func intent(_ name: String) throws {
+        let value: CGColorRenderingIntent
+        switch name {
+        case "Perceptual": value = .perceptual
+        case "RelativeColorimetric": value = .relativeColorimetric
+        case "Saturation": value = .saturation
+        case "AbsoluteColorimetric": value = .absoluteColorimetric
+        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility)
+        }
+        fill.renderingIntent = value; stroke.renderingIntent = value
+    }
+    mutating func intent(_ scanner: CGPDFScannerRef) throws {
+        var name: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner,&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
+        try intent(String(cString:name))
+    }
+    mutating func applyIntent(_ dictionary: CGPDFDictionaryRef) throws {
+        var object: CGPDFObjectRef?, name: UnsafePointer<CChar>?
+        guard CGPDFDictionaryGetObject(dictionary,"RI",&object) else { return }
+        guard CGPDFDictionaryGetName(dictionary,"RI",&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
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
+        guard CGPDFScannerPopName(scanner,&pointer), let pointer else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
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
+            throw PDFParseError(code:.limit)
+        }
+        var values = [Double]()
+        for _ in 0..<count {
+            var value: CGPDFReal = 0
+            guard CGPDFScannerPopNumber(scanner,&value) else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
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
+        guard let candidate else { throw PDFParseError(code:.unsupported,stage:.clippingBounds) }
+        return candidate
+    }
+}
+
+struct PDFMarkedContent {
+    private var depth = 0
+    mutating func begin(_ scanner: CGPDFScannerRef, properties: Bool) throws {
+        guard depth < 64 else { throw PDFParseError(code: .limit) }
+        if properties {
+            var object: CGPDFObjectRef?
+            guard CGPDFScannerPopObject(scanner, &object), let object else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+            var dictionary: CGPDFDictionaryRef?
+            if CGPDFObjectGetType(object) == .name {
+                var name: UnsafePointer<CChar>?
+                guard CGPDFObjectGetValue(object, .name, &name), let name,
+                      let resource = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "Properties", String(cString: name)),
+                      CGPDFObjectGetValue(resource, .dictionary, &dictionary) else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+            } else if !CGPDFObjectGetValue(object, .dictionary, &dictionary) { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+            guard let dictionary else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+            // Only structure ID and language metadata are inert. Replacement,
+            // optional-content membership, and unknown entries remain rejected.
+            var known = 0, metadataObject: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary, "MCID", &metadataObject) {
+                var value: CGPDFInteger = 0
+                guard CGPDFDictionaryGetInteger(dictionary, "MCID", &value), value >= 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+                known += 1
+            }
+            if CGPDFDictionaryGetObject(dictionary, "Lang", &metadataObject) {
+                var language: CGPDFStringRef?
+                guard CGPDFDictionaryGetString(dictionary, "Lang", &language), let language,
+                      CGPDFStringGetLength(language) <= 256 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+                known += 1
+            }
+            guard CGPDFDictionaryGetCount(dictionary) == known else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+        }
+        var tag: UnsafePointer<CChar>?
+        guard CGPDFScannerPopName(scanner, &tag), let tag, String(cString: tag) != "OC" else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+        depth += 1
+    }
+    mutating func end() throws {
+        guard depth > 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+        depth -= 1
+    }
+    func finish() throws {
+        guard depth == 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
+    }
+}
+#endif
diff --git a/Takupoke/PDFDrawnTextReader+Fonts.swift b/Takupoke/PDFDrawnTextReader+Fonts.swift
index e08a3ce..aaf31e0 100644
--- a/Takupoke/PDFDrawnTextReader+Fonts.swift
+++ b/Takupoke/PDFDrawnTextReader+Fonts.swift
@@ -25,0 +26,4 @@ extension PDFDrawnTextReader {
+        if !selectedFontKeys.contains(key) {
+            guard selectedFontKeys.count < 128 else { throw PDFParseError(code: .limit) }
+            selectedFontKeys.insert(key)
+        }
@@ -30,2 +34,7 @@ extension PDFDrawnTextReader {
-        guard CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream), let mapStream = mapStream else {
-            throw PDFTextFailure.unsupported
+        if !CGPDFDictionaryGetStream(dict, "ToUnicode", &mapStream) {
+            // Only an absent map can be an unused setup font. An explicitly
+            // malformed map, broken resource, cancellation, or limit still fails.
+            var object: CGPDFObjectRef?
+            guard !CGPDFDictionaryGetObject(dict, "ToUnicode", &object) else { throw PDFTextFailure.unsupported }
+            try engine.font(nil, size: size)
+            return
@@ -32,0 +42 @@ extension PDFDrawnTextReader {
+        guard let mapStream = mapStream else { throw PDFTextFailure.unsupported }
@@ -35 +45 @@ extension PDFDrawnTextReader {
-        let mapping = try PDFUnicodeMap.read(data as Data)
+        let mapping = try PDFUnicodeMap.read(data as Data,check:engine.check)
diff --git a/Takupoke/PDFDrawnTextReader.swift b/Takupoke/PDFDrawnTextReader.swift
index 9e5a05a..09e132c 100644
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
@@ -41 +50 @@ final class PDFDrawnTextReader {
-        if length == 0 { return }
+        if length == 0 { try engine.show([]); return }
@@ -58,0 +68 @@ final class PDFDrawnTextReader {
+        try engine.state.colors.applyIntent(dict)
@@ -63,0 +74,8 @@ final class PDFDrawnTextReader {
+        var lineWidth: CGPDFReal = 0, widthObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetNumber(dict,"LW",&lineWidth) {
+            guard lineWidth.isFinite, lineWidth >= 0 else { throw PDFTextFailure.unsupported }
+        } else if CGPDFDictionaryGetObject(dict,"LW",&widthObject) { throw PDFTextFailure.unsupported }
+        var blendMode: UnsafePointer<CChar>?, blendObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetName(dict,"BM",&blendMode), let blendMode {
+            guard String(cString:blendMode) == "Normal" else { throw PDFTextFailure.unsupported }
+        } else if CGPDFDictionaryGetObject(dict,"BM",&blendObject) { throw PDFTextFailure.unsupported }
@@ -67,0 +86,10 @@ final class PDFDrawnTextReader {
+    private func deviceColor(_ scanner: CGPDFScannerRef, stroke: Bool, count: Int) throws {
+        let values = try numbers(scanner,count)
+        let operation = count == 1 ? (stroke ? "G" : "g") : count == 3 ? (stroke ? "RG" : "rg") : (stroke ? "K" : "k")
+        try engine.operation(operation,values)
+        if stroke {
+            try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
+        } else {
+            try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
+        }
+    }
@@ -68,0 +97,3 @@ final class PDFDrawnTextReader {
+        let media = page.getBoxRect(.mediaBox)
+        pageBounds = PDFBox(left: Double(media.minX), top: Double(media.minY),
+                            right: Double(media.maxX), bottom: Double(media.maxY))
@@ -131,0 +163,52 @@ final class PDFDrawnTextReader {
+        CGPDFOperatorTableSetCallback(table,"ri") { scanner,p in PDFDrawnTextReader.run(p) { try $0.engine.state.colors.intent(scanner) } }
+        CGPDFOperatorTableSetCallback(table, "w") { scanner, p in PDFDrawnTextReader.run(p) { s in
+            guard try s.numbers(scanner,1)[0] >= 0 else { throw PDFTextFailure.unsupported }
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
+                guard s.engine.glyphs.isEmpty || s.deferFillValidation else { throw PDFTextFailure.unsupported }
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
+                    throw PDFParseError(code:.unsupported,stage:.clippingBounds)
+                }
+                try s.engine.clip(clip)
+            } }
+        }
+        CGPDFOperatorTableSetCallback(table, "BMC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:false) } }
+        CGPDFOperatorTableSetCallback(table, "BDC") { scanner, p in PDFDrawnTextReader.run(p) { try $0.markedContent.begin(scanner,properties:true) } }
+        CGPDFOperatorTableSetCallback(table, "EMC") { _, p in PDFDrawnTextReader.run(p) { try $0.markedContent.end() } }
@@ -134 +217 @@ final class PDFDrawnTextReader {
-        for op in ["Do", "BDC", "BMC", "W", "W*"] {
+        for op in ["Do", "BI", "ID", "EI", "sh"] {
@@ -140,0 +224,2 @@ final class PDFDrawnTextReader {
+        try engine.state.colors.fill.applyDefault(scanner,resolver:paintResolver)
+        try engine.state.colors.stroke.applyDefault(scanner,resolver:paintResolver)
@@ -143,0 +229 @@ final class PDFDrawnTextReader {
+        try markedContent.finish()
diff --git a/Takupoke/PDFGrid.swift b/Takupoke/PDFGrid.swift
index 25227e5..a7333f9 100644
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
+            guard visits <= 64_000_000 else { throw PDFParseError(code:.limit,stage:.gridCell) }
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
+            throw PDFParseError(code:.unsupported,stage:.gridCell)
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
+                              glyph.y + glyph.height <= box.bottom else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
+                    }
+                    selected.append(index)
+                }
+            }
+        }
+        // Spatial lookup cannot change the original PDF reading/drawing order.
+        try selected.sort { a,b in try calibration.consume(check); return a < b }
+        return selected.map { page.glyphs[$0] }
+    }
@@ -33 +105,3 @@ struct PDFGrid {
-            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 }
+            box.top + 0.3 < $0.cy && $0.cy < box.bottom - 0.3 &&
+            ($0.ocrLineAtom != true || $0.x >= box.left && $0.y >= box.top &&
+                $0.x + $0.width <= box.right && $0.y + $0.height <= box.bottom) }
@@ -65,0 +140,3 @@ struct PDFGrid {
+    func text(_ box: PDFBox, check: () throws -> Void) throws -> [String] {
+        try Self.contentRows(try glyphs(in:box,check:check)).map { $0.map(\.text).joined() }
+    }
@@ -72,2 +149,4 @@ struct PDFGrid {
-    func timetableText(_ box: PDFBox) throws -> [String] {
-        let input = glyphs(in: box)
+    func timetableText(_ box: PDFBox, check: () throws -> Void = {}) throws -> [String] {
+        try timetableText(try glyphs(in:box,check:check),check:check)
+    }
+    private func timetableText(_ input: [PDFGlyph], check: () throws -> Void) throws -> [String] {
@@ -97,0 +177 @@ struct PDFGrid {
+            try check()
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
+                    guard cell.top >= row.top-0.8, cell.bottom <= row.bottom+0.8 else { throw PDFParseError(code:.ambiguous,stage:.gridCell) }
+                    boxes.insert(cell)
+                    guard boxes.count <= 10_000 else { throw PDFParseError(code:.limit) }
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
+        guard !lines.isEmpty, lines.count < 3 else { throw PDFParseError(code: .ambiguous, stage: .lessonLines) }
+        let height = box.bottom - box.top
+        var references: [[Double]] = []
+        var seen = Set<PDFBox>()
+        for other in referenceBoxes {
+            try calibration.consume(check)
+            guard seen.insert(other).inserted else { continue }
+            guard seen.count <= 10000 else { throw PDFParseError(code:.limit,stage:.gridCell) }
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
+        guard rows.count == lines.count else { throw PDFParseError(code:.ambiguous,stage:.lessonLines) }
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
+            throw PDFParseError(code: .ambiguous, stage: .lessonLines)
+        }
+        return fields
+    }
+
diff --git a/Takupoke/PDFKitReader.swift b/Takupoke/PDFKitReader.swift
index 3724b6f..4b72043 100644
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
@@ -42,0 +44 @@ enum PDFKitReader {
+        capture?.begin(pageCount: document.pageCount)
@@ -48 +50 @@ enum PDFKitReader {
-                  let string = page.string, page.numberOfCharacters <= 100000 else {
+                  page.numberOfCharacters <= 100000 else {
@@ -50,0 +53,11 @@ enum PDFKitReader {
+            if verifyVisibility || kind == .timetable {
+                let media = ref.getBoxRect(.mediaBox), crop = ref.getBoxRect(.cropBox)
+                guard media == crop else {
+                    // The viewer displays CropBox. Selectable content outside it
+                    // must never become a complete timetable through MediaBox.
+                    throw PDFParseError(code:.unsupported,page:index+1,stage:.rasterInput)
+                }
+            }
+            guard let string = page.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
+                throw PDFParseError(code: .unsupported, page: index + 1, stage: .rasterInput)
+            }
@@ -59,0 +73,2 @@ enum PDFKitReader {
+            var recoveryGlyphs: [PDFGlyph]? = nil
+            var recoveryComplete = true
@@ -62 +77,2 @@ enum PDFKitReader {
-                    glyphs = try PDFDrawnTextReader(check: check).read(ref, expectedText: string).map { glyph in
+                    let drawnReader = PDFDrawnTextReader(deferFillValidation: true, check: check)
+                    func transformed(_ glyph:PDFGlyph) -> PDFGlyph {
@@ -67,0 +84,3 @@ enum PDFKitReader {
+                    glyphs = try drawnReader.read(ref,expectedText:string).map(transformed)
+                    recoveryGlyphs = drawnReader.engine.recoveryGlyphs.map(transformed)
+                    recoveryComplete = drawnReader.engine.recoveryComplete
@@ -148 +167,9 @@ enum PDFKitReader {
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
@@ -151,3 +178,14 @@ enum PDFKitReader {
-            do { lines = try reader.read(ref) }
-            catch var error as PDFParseError { error.page = index + 1; throw error }
-            guard !glyphs.isEmpty, !lines.isEmpty else { throw PDFParseError(code: .unreadable, page: index + 1) }
+            do {
+                defer { diagnostics?.record(.paths,page:index+1,values:[Double(reader.operations),Double(reader.paintWork)]) }
+                lines = try reader.read(ref)
+            } catch var error as PDFParseError { error.page = index + 1; throw error }
+            let layout = PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows)
+            if verifyVisibility || kind == .timetable {
+                do { try layout.requireVisibleBounds(check:check) }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            }
+            var capturedLayout = layout
+            capturedLayout.glyphs = recoveryGlyphs ?? glyphs
+            capture?.record(page: index + 1, state: glyphs.isEmpty ? .rasterOnly : recoveryComplete ? .complete : .partial, layout: capturedLayout)
+            guard !glyphs.isEmpty else { throw PDFParseError(code: .unsupported, page: index + 1, stage: .rasterInput) }
+            guard !lines.isEmpty else { throw PDFParseError(code: .unsupported, page: index + 1, stage: .gridCell) }
@@ -156 +194 @@ enum PDFKitReader {
-            output.append(PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows))
+            output.append(layout)
@@ -158,0 +197 @@ enum PDFKitReader {
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
index 0000000..06ecba4
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
+        guard cache.count < 128 else { throw PDFParseError(code:.limit) }
+        guard let object = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner),"ColorSpace",name) else {
+            throw PDFParseError(code:.unsupported,stage:.paintVisibility)
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
+            guard length <= 1_048_576 else { throw PDFParseError(code:.limit) }
+            var format = CGPDFDataFormat.raw
+            guard let data = CGPDFStreamCopyData(stream,&format), format == .raw else { return invalid }
+            let bytes = CFDataGetLength(data)
+            guard bytes <= 1_048_576, profileBytes <= 4_194_304 - bytes else { throw PDFParseError(code:.limit) }
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
index 733110c..a09cb1a 100644
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
@@ -15 +23,2 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-        case fragmentOverlap, fragmentAlignment
+        case fragmentOverlap, fragmentAlignment, rasterInput
+        case paintVisibility, clippingBounds, contentTags
@@ -38,0 +48 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
+            case .rasterInput: return "画像からの文字認識が必要（P22）"
@@ -39,0 +50,3 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
+            case .paintVisibility: return "文字・罫線・背景の表示（P23）"
+            case .clippingBounds: return "表示範囲内の文字と罫線（P24）"
+            case .contentTags: return "PDFの表示に関わる情報（P25）"
@@ -70 +83 @@ struct PDFParseError: Error, LocalizedError, Codable, Equatable {
-        case .unreadable: reason = "PDFを読み取れません。暗号化・破損・画像だけのPDFには対応していません。"
+        case .unreadable: reason = "PDFを読み取れません。暗号化・破損などにより原本を確認できません。"
diff --git a/Takupoke/PDFPathReader.swift b/Takupoke/PDFPathReader.swift
index faf1ef8..1861728 100644
--- a/Takupoke/PDFPathReader.swift
+++ b/Takupoke/PDFPathReader.swift
@@ -1,0 +2,59 @@ import Foundation
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
+        guard boxes.count <= 100000 else { throw PDFParseError(code:.limit) }
+        var width = 0.0, height = 0.0
+        for box in boxes {
+            try work()
+            guard [box.left,box.top,box.right,box.bottom].allSatisfy(\.isFinite),
+                  box.left <= box.right, box.top <= box.bottom,
+                  (box.right-box.left).isFinite, (box.bottom-box.top).isFinite else { throw PDFParseError(code:.unreadable) }
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
+    func overlaps(_ query: PDFBox, pad: Double, work: () throws -> Void) throws -> Bool {
+        guard [query.left,query.top,query.right,query.bottom,pad].allSatisfy(\.isFinite),
+              query.left <= query.right, query.top <= query.bottom, pad >= 0,
+              (query.left-pad).isFinite, (query.top-pad).isFinite,
+              (query.right+pad).isFinite, (query.bottom+pad).isFinite else { throw PDFParseError(code:.unreadable) }
+        // An overlapping box starts no earlier than query-min minus the largest
+        // original extent. Outward rounding only broadens candidates; the exact
+        // collision predicate below still includes the same touching edges.
+        let xs = try range(xOrder,horizontal:true,lower:(query.left-pad-maximumWidth).nextDown,upper:(query.right+pad).nextUp,work:work)
+        let ys = try range(yOrder,horizontal:false,lower:(query.top-pad-maximumHeight).nextDown,upper:(query.bottom+pad).nextUp,work:work)
+        let horizontal = xs.count < ys.count
+        let selected = horizontal ? xs : ys, order = horizontal ? xOrder : yOrder
+        for index in selected {
+            try work()
+            let box = boxes[order[index]]
+            if box.left <= query.right+pad && query.left-pad <= box.right &&
+               box.top <= query.bottom+pad && query.top-pad <= box.bottom { return true }
+        }
+        return false
+    }
+}
@@ -30,0 +90,2 @@ final class PDFPathReader {
+    let verifyVisibility: Bool
+    let textBoxes: [PDFBox]
@@ -32,0 +94,8 @@ final class PDFPathReader {
+    private var widthStack: [Double] = []
+    private var lineWidth = 1.0
+    private var colors = PDFPaintColors()
+    private var colorStack: [PDFPaintColors] = []
+    private var markedContent = PDFMarkedContent()
+    private var clips: [PDFBox] = []
+    private var paintedBoxes: [PDFBox] = []
+    private let paintResolver = PDFPaintSpaceResolver()
@@ -38 +107,3 @@ final class PDFPathReader {
-    private var paintWork = 0
+    private var textSeen = false
+    private(set) var paintWork = 0
+    private var textIndex: PDFTextCollisionIndex?
@@ -48 +119,3 @@ final class PDFPathReader {
-    init(transform: PDFDisplayTransform, check: @escaping () throws -> Void) { self.transform = transform; self.check = check }
+    init(transform: PDFDisplayTransform, verifyVisibility: Bool = false, textBoxes: [PDFBox] = [], check: @escaping () throws -> Void) {
+        self.transform = transform; self.verifyVisibility = verifyVisibility; self.textBoxes = textBoxes; self.check = check
+    }
@@ -104,0 +178,12 @@ final class PDFPathReader {
+    private func overlapsText(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat, pad: Double) -> Bool {
+        do {
+            let work = { [self] in
+                guard consumePaintWork() else { throw failure ?? PDFParseError(code:.limit) }
+            }
+            if textIndex == nil { textIndex = try PDFTextCollisionIndex(textBoxes,work:work) }
+            return try textIndex!.overlaps(PDFBox(left:Double(left),top:Double(top),right:Double(right),bottom:Double(bottom)),pad:pad,work:work)
+        } catch {
+            if failure == nil { failure = error }
+            return true
+        }
+    }
@@ -108,0 +194,61 @@ final class PDFPathReader {
+        if verifyVisibility && !paths.isEmpty {
+            // A white page background is harmless only before any retained ink.
+            if fill && !stroke && colors.fill.isWhite && !textSeen && lines.isEmpty && arrows.isEmpty && paintedBoxes.isEmpty,
+               paths.count == 1, let box = rectangularPathBox(),
+               box == PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height)) { return }
+            guard (!fill || colors.fill.isVisibleInk) && (!stroke || colors.stroke.isVisibleInk) else {
+                failure = PDFParseError(code:.unsupported,stage:.paintVisibility); return
+            }
+        }
+        if verifyVisibility && fill && !paths.isEmpty {
+            guard !textSeen || !textBoxes.isEmpty else {
+                failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return
+            }
+            // Thin rectangular rules may be painted before or after text. Check
+            // their actual bounds against every original glyph, including text
+            // drawn later. Broad fills and unknown shapes remain unsupported.
+            for path in paths {
+                guard let first = path.first, path.count == 5, path.last == first,
+                      Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
+                      let box = bounds(of:path) else {
+                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
+                }
+                let width = box.right-box.left, height = box.bottom-box.top
+                let corners = [CGPoint(x:box.left,y:box.top),CGPoint(x:box.right,y:box.top),CGPoint(x:box.right,y:box.bottom),CGPoint(x:box.left,y:box.bottom)]
+                let uniqueCorners = corners.allSatisfy { corner in path.dropLast().filter { $0 == corner }.count == 1 }
+                let axisEdges = zip(path,path.dropFirst()).allSatisfy { a,b in (a.x == b.x) != (a.y == b.y) }
+                guard uniqueCorners, axisEdges, ((width <= 2.1 && height > 3) || (height <= 2.1 && width > 3)),
+                      !overlapsText(left:box.left,top:box.top,right:box.right,bottom:box.bottom,pad:0) else {
+                    if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
+                }
+            }
+        }
+        if verifyVisibility && stroke && !paths.isEmpty {
+            guard PDFTextVisibility.similarStrokeTransform(a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)),
+                  let pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) else {
+                failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return
+            }
+            for path in paths where path.count >= 2 {
+                for index in 1..<path.count {
+                    guard consumePaintWork() else { return }
+                    let a = path[index-1], b = path[index]
+                    guard (a.x == b.x || a.y == b.y),
+                          !overlapsText(left:min(a.x,b.x),top:min(a.y,b.y),right:max(a.x,b.x),bottom:max(a.y,b.y),pad:pad) else {
+                        if failure == nil { failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }; return
+                    }
+                }
+            }
+        }
+        if verifyVisibility {
+            let pad: Double
+            if stroke {
+                pad = PDFTextVisibility.strokePad(lineWidth,a:Double(ctm.a),b:Double(ctm.b),c:Double(ctm.c),d:Double(ctm.d)) ?? 0
+            } else { pad = 0 }
+            for path in paths where path.count >= 2 {
+                guard let box = bounds(of:path), paintedBoxes.count < 100_000 else {
+                    if failure == nil { failure = PDFParseError(code:.limit) }; return
+                }
+                paintedBoxes.append(PDFBox(left:Double(box.left)-pad,top:Double(box.top)-pad,
+                                           right:Double(box.right)+pad,bottom:Double(box.bottom)+pad))
+            }
+        }
@@ -163,0 +310,70 @@ final class PDFPathReader {
+    private func rectangularPathBox() -> PDFBox? {
+        guard paths.count == 1, let path = paths.first, path.count == 5, path.first == path.last,
+              Set(path.map(\.x)).count == 2, Set(path.map(\.y)).count == 2,
+              zip(path,path.dropFirst()).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }),
+              path.dropLast().allSatisfy({ point in path.dropLast().filter { $0 == point }.count == 1 }) else { return nil }
+        return PDFBox(left:Double(path.map(\.x).min()!),top:Double(path.map(\.y).min()!),
+                      right:Double(path.map(\.x).max()!),bottom:Double(path.map(\.y).max()!))
+    }
+    private func recordClip() {
+        guard let box = rectangularPathBox() else { failure = PDFParseError(code:.unsupported,stage:.clippingBounds); return }
+        let page = PDFBox(left:0,top:0,right:Double(transform.width),bottom:Double(transform.height))
+        guard PDFClipValidation.contains(box,page) else {
+            failure = PDFParseError(code:.unsupported,stage:.clippingBounds); return
+        }
+        guard clips.count < 128 else { failure = PDFParseError(code:.limit); return }
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
+        for key in ["Font", "SMask", "TR", "TR2"] {
+            var value: CGPDFObjectRef?
+            if CGPDFDictionaryGetObject(dictionary,key,&value) { return false }
+        }
+        var dashObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetObject(dictionary,"D",&dashObject) {
+            var dash: CGPDFArrayRef?, pattern: CGPDFArrayRef?, phase: CGPDFReal = 0
+            guard CGPDFDictionaryGetArray(dictionary,"D",&dash), let dash, CGPDFArrayGetCount(dash) == 2,
+                  CGPDFArrayGetArray(dash,0,&pattern), let pattern, CGPDFArrayGetCount(pattern) == 0,
+                  CGPDFArrayGetNumber(dash,1,&phase), phase == 0 else { return false }
+        }
+        var width: CGPDFReal = 0, widthObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetNumber(dictionary,"LW",&width) {
+            guard width.isFinite, width >= 0 else { return false }
+            lineWidth = Double(width)
+        } else if CGPDFDictionaryGetObject(dictionary,"LW",&widthObject) { return false }
+        var blendMode: UnsafePointer<CChar>?, blendObject: CGPDFObjectRef?
+        if CGPDFDictionaryGetName(dictionary,"BM",&blendMode), let blendMode {
+            guard String(cString:blendMode) == "Normal" else { return false }
+        } else if CGPDFDictionaryGetObject(dictionary,"BM",&blendObject) { return false }
+        for key in ["ca", "CA"] {
+            var value: CGPDFReal = 0, object: CGPDFObjectRef?
+            if CGPDFDictionaryGetNumber(dictionary,key,&value) {
+                guard value.isFinite, value == 1 else { return false }
+            } else if CGPDFDictionaryGetObject(dictionary,key,&object) { return false }
+        }
+        return true
+    }
@@ -169 +385,3 @@ final class PDFPathReader {
-            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit) } else { s.stack.append(s.ctm) }
+            if s.stack.count >= 64 { s.failure = PDFParseError(code: .limit) } else {
+                s.stack.append(s.ctm); s.widthStack.append(s.lineWidth); s.colorStack.append(s.colors)
+            }
@@ -173 +391,3 @@ final class PDFPathReader {
-            if let value = s.stack.popLast() { s.ctm = value } else { s.failure = PDFParseError(code: .unreadable) }
+            if let value = s.stack.popLast(), let width = s.widthStack.popLast(), let colors = s.colorStack.popLast() {
+                s.ctm = value; s.lineWidth = width; s.colors = colors
+            } else { s.failure = PDFParseError(code: .unreadable) }
@@ -209,2 +429,3 @@ final class PDFPathReader {
-                guard let s = PDFPathReader.state(p), !s.paths.isEmpty else { return }
-                s.paths[s.paths.count - 1].removeAll()
+                guard let s = PDFPathReader.state(p) else { return }
+                if s.verifyVisibility { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return }
+                if !s.paths.isEmpty { s.paths[s.paths.count - 1].removeAll() }
@@ -216,0 +438,70 @@ final class PDFPathReader {
+        if verifyVisibility {
+            CGPDFOperatorTableSetCallback(table,"d") { scanner, p in
+                guard let s = PDFPathReader.state(p), let phase = s.numbers(scanner,1)?.first else { return }
+                var pattern: CGPDFArrayRef?
+                guard CGPDFScannerPopArray(scanner,&pattern), let pattern, CGPDFArrayGetCount(pattern) == 0, phase == 0 else {
+                    s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return
+                }
+            }
+            CGPDFOperatorTableSetCallback(table, "w") { scanner, p in
+                guard let s = PDFPathReader.state(p), let width = s.numbers(scanner,1)?.first else { return }
+                guard width >= 0 else { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects); return }
+                s.lineWidth = Double(width)
+            }
+            CGPDFOperatorTableSetCallback(table, "gs") { scanner, p in
+                guard let s = PDFPathReader.state(p) else { return }
+                if !s.graphicsStateIsVisible(scanner) { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
+            }
+            CGPDFOperatorTableSetCallback(table, "Tr") { scanner, p in
+                guard let s = PDFPathReader.state(p), let mode = s.numbers(scanner,1)?.first else { return }
+                if mode != 0 { s.failure = PDFParseError(code:.unsupported,stage:.vectorObjects) }
+            }
+            for op in ["Tj", "TJ", "'", "\""] {
+                CGPDFOperatorTableSetCallback(table, op) { _, p in
+                    guard let s = PDFPathReader.state(p) else { return }
+                    s.textSeen = true
+                    if !s.colors.fill.isVisibleInk {
+                        s.failure = PDFParseError(code:.unsupported,stage:.paintVisibility)
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
+                    PDFPathReader.state(p)?.failure = PDFParseError(code:.unsupported,stage:.vectorObjects)
+                }
+            }
+        }
@@ -220,0 +512,4 @@ final class PDFPathReader {
+        if verifyVisibility {
+            try colors.fill.applyDefault(scanner,resolver:paintResolver)
+            try colors.stroke.applyDefault(scanner,resolver:paintResolver)
+        }
@@ -224,0 +520,12 @@ final class PDFPathReader {
+        if verifyVisibility {
+            guard stack.isEmpty else { throw PDFParseError(code:.unsupported,stage:.vectorObjects) }
+            do {
+                try markedContent.finish()
+                try PDFClipValidation.requireContains(textBoxes+paintedBoxes,clips:clips,work:{
+                    guard self.consumePaintWork() else { throw self.failure ?? PDFParseError(code:.limit) }
+                },check:check)
+            } catch var error as PDFParseError {
+                if error.stage == .characterMapping { error.stage = .vectorObjects }
+                throw error
+            }
+        }
diff --git a/Takupoke/PDFSchoolParser+Timetable.swift b/Takupoke/PDFSchoolParser+Timetable.swift
index 07db4e8..2020100 100644
--- a/Takupoke/PDFSchoolParser+Timetable.swift
+++ b/Takupoke/PDFSchoolParser+Timetable.swift
@@ -13,2 +13,2 @@ extension PDFSchoolParser {
-        let first = try grid.box(header[0].cx, header[0].cy)
-        let classBox = try grid.box(first.left - 2, first.bottom + 20)
+        let first = try grid.box(header[0].cx, header[0].cy,check:check)
+        let classBox = try grid.box(first.left - 2, first.bottom + 20,check:check)
@@ -19,0 +20,7 @@ extension PDFSchoolParser {
+        let bodyRows = try classRows.map { glyphs -> PDFBox in
+            let y = glyphs.map(\.cy).reduce(0,+)/Double(glyphs.count)
+            var row = try grid.box((classBox.left+classBox.right)/2,y,check:check)
+            row.top = max(row.top,try grid.box(header[0].cx,y,check:check).top)
+            return row
+        }
+        let referenceBoxes = try grid.lessonBoxes(rows:bodyRows,columns:header.map(\.cx),check:check)
@@ -29,2 +36,2 @@ extension PDFSchoolParser {
-            var row = try grid.box((classBox.left + classBox.right) / 2, y)
-            let grade = try key(grid.text(grid.box(classBox.left - 2, y)).joined())
+            var row = try grid.box((classBox.left + classBox.right) / 2, y,check:check)
+            let grade = try key(grid.text(grid.box(classBox.left - 2, y,check:check),check:check).joined())
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
@@ -62 +69,2 @@ extension PDFSchoolParser {
-                    let fields = lines + Array(repeating: "", count: 3 - lines.count)
+                    guard !lines.contains(where:RecoveryRole.hasLabelPrefix) else { throw PDFParseError(code: .unsupported, stage: .lessonLines, cell: cell) }
+                    let fields = try grid.lessonFields(box, lines: lines,referenceBoxes:referenceBoxes,check:check)
@@ -65 +73 @@ extension PDFSchoolParser {
-                    if parts[0].count > 1 && parts[1].count > 1 && !parallel {
+                    if parts.filter({ $0.count > 1 }).count >= 2 && !parallel {
diff --git a/Takupoke/PDFSchoolParser.swift b/Takupoke/PDFSchoolParser.swift
index e57a714..83ab343 100644
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
+        guard normalized.count == originalRanges.count else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
+        let originals = Dictionary(uniqueKeysWithValues:zip(normalized.indices,originalRanges))
+        var markers = [YearMarker](), remainder = normalized.startIndex..<normalized.endIndex
+        while let range = normalized.range(of:"(?<![\\p{N}])(?:令和[^年]*?|[\\p{N}]+)年度",options:.regularExpression,range:remainder) {
+            try check()
+            let token = normalized[range], era = token.hasPrefix("令和")
+            let digits = String(era ? token.dropFirst(2).dropLast(2) : token.dropLast(2)).precomposedStringWithCompatibilityMapping
+            guard (era ? (1...2).contains(digits.count) : digits.count == 4),
+                  digits.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(digits),
+                  !era || (1...99).contains(value) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
+            let year = era ? 2018+value:value
+            guard (1900...9998).contains(year) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
+            guard let first = originals[range.lowerBound], let last = originals[normalized.index(before:range.upperBound)] else {
+                throw PDFParseError(code:.unsupported,stage:.yearHeading)
+            }
+            markers.append(YearMarker(year:year,range:first.lowerBound..<last.upperBound,isReiwa:era))
+            remainder = range.upperBound..<normalized.endIndex
+        }
+        return markers
+    }
+    static func uniqueTitleYear(_ header: String,check: () throws -> Void = {}) throws -> Int {
+        let markers = try yearMarkers(header,check:check)
+        guard let first = markers.first, markers.contains(where:\.isReiwa) else { throw PDFParseError(code:.unsupported,stage:.yearHeading) }
+        guard markers.allSatisfy({ $0.year == first.year }) else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) }
+        return first.year
+    }
@@ -22,0 +70,4 @@ enum PDFSchoolParser {
+            if kind == .timetable {
+                do { try page.requireVisibleBounds(check:check) }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            }
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
+                throw PDFParseError(code: .unsupported, page: 1, stage: .yearHeading)
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
+                do { guard try uniqueTitleYear(rawHeading,check:check) == year else { throw PDFParseError(code:.ambiguous,stage:.yearHeading) } }
+                catch var error as PDFParseError { error.page = index+1; throw error }
+            } else {
+                guard let range = heading.range(of: "令和[0-9]{1,2}年度", options: .regularExpression),
+                      Int(heading[range].dropFirst(2).dropLast(2)) == year-2018 else {
+                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .yearHeading)
+                }
@@ -48,2 +112,2 @@ enum PDFSchoolParser {
-            result.notices = ["PDFの記載名を表示しています。正式名称の対応表はまだ取り込んでいません。",
-                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更との統合はまだ行いません。"]
+            result.notices = ["PDFの記載名を解析結果として保存しています。正式名称の対応は表示時に適用します。",
+                              "適用開始日・終了日はPDFの学期名から推測していません。時間割変更は日付ごとの表示時に反映します。"]
diff --git a/Takupoke/PDFTextGeometry.swift b/Takupoke/PDFTextGeometry.swift
index 67446f9..3ef9a8f 100644
--- a/Takupoke/PDFTextGeometry.swift
+++ b/Takupoke/PDFTextGeometry.swift
@@ -8,0 +9,25 @@ enum PDFTextFailure {
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
+}
+
@@ -29,0 +55 @@ final class PDFTextGeometry {
+        var colors = PDFPaintColors()
@@ -36,0 +63,4 @@ final class PDFTextGeometry {
+    // Keep Strict's stream unchanged and preserve original drawn whitespace
+    // separately for Recovery. Incomplete whitespace geometry remains partial.
+    private(set) var recoveryGlyphs: [PDFGlyph] = []
+    private(set) var recoveryComplete = true
@@ -38,0 +69 @@ final class PDFTextGeometry {
+    private var clips: [PDFBox] = []
@@ -47 +78,2 @@ final class PDFTextGeometry {
-                      "T*": 0, "Tc": 1, "Tw": 1, "Tz": 1, "TL": 1, "Ts": 1, "Tr": 1]
+                      "T*": 0, "Tc": 1, "Tw": 1, "Tz": 1, "TL": 1, "Ts": 1, "Tr": 1,
+                      "g": 1, "G": 1, "rg": 3, "RG": 3, "k": 4, "K": 4]
@@ -49,0 +82,2 @@ final class PDFTextGeometry {
+        case "g", "rg", "k": try state.colors.fill.device(n, count: n.count)
+        case "G", "RG", "K": try state.colors.stroke.device(n, count: n.count)
@@ -76 +110,3 @@ final class PDFTextGeometry {
-            guard [0, 1, 2].contains(n[0]) else { throw PDFTextFailure.unsupported }
+            // Glyph advance/ascent bounds do not certify a stroked outline's
+            // painted extent or contrast. Composite those modes in raster.
+            guard n[0] == 0 else { throw PDFTextFailure.unsupported }
@@ -81 +117 @@ final class PDFTextGeometry {
-    func font(_ font: PDFTextFont, size: Double) throws {
+    func font(_ font: PDFTextFont?, size: Double) throws {
@@ -90 +126,5 @@ final class PDFTextGeometry {
-        guard inText, let font = state.font, state.size > 0, state.scale > 0,
+        try check()
+        guard inText, state.size > 0, state.scale > 0 else { throw PDFTextFailure.unsupported }
+        if bytes.isEmpty { return }
+        guard state.colors.fill.isVisibleInk else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
+        guard let font = state.font,
@@ -97,0 +138 @@ final class PDFTextGeometry {
+                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
@@ -106,0 +148,5 @@ final class PDFTextGeometry {
+            let x = xs.min()!, y = ys.min()!, right = xs.max()!, upper = ys.max()!
+            let validGeometry = width > 0 && right > x && upper > y
+            if validGeometry {
+                recoveryGlyphs.append(PDFGlyph(text:text,x:x,y:y,width:right-x,height:upper-y,sourceLine:line,sourceOrder:order))
+            } else { recoveryComplete = false }
@@ -108,2 +154 @@ final class PDFTextGeometry {
-                guard width > 0, let x = xs.min(), let y = ys.min(), let right = xs.max(), let upper = ys.max(),
-                      right > x, upper > y else { throw PDFTextFailure.unsupported }
+                guard validGeometry else { throw PDFTextFailure.unsupported }
@@ -129,0 +175,3 @@ final class PDFTextGeometry {
+        try PDFClipValidation.requireContains(glyphs.map {
+            PDFBox(left: $0.x, top: $0.y, right: $0.x+$0.width, bottom: $0.y+$0.height)
+        }, clips: clips, check: check)
@@ -131,0 +180,5 @@ final class PDFTextGeometry {
+
+    func clip(_ box: PDFBox) throws {
+        guard clips.count < 128 else { throw PDFParseError(code: .limit) }
+        clips.append(box)
+    }
diff --git a/Takupoke/PDFUnicodeMap.swift b/Takupoke/PDFUnicodeMap.swift
index a124729..6157915 100644
--- a/Takupoke/PDFUnicodeMap.swift
+++ b/Takupoke/PDFUnicodeMap.swift
@@ -26 +26,2 @@ enum PDFUnicodeMap {
-    static func read(_ data: Data) throws -> (bytes: Int, values: [Int: String]) {
+    static func read(_ data: Data, check: () throws -> Void = {}) throws -> (bytes: Int, values: [Int: String]) {
+        try check()
@@ -33 +34,6 @@ enum PDFUnicodeMap {
-        let tokens = regex.matches(in: noComments, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
+        let matches = regex.matches(in: noComments, range: NSRange(location:0,length:ns.length))
+        var tokens = [String]()
+        for (index,match) in matches.enumerated() {
+            if index % 128 == 0 { try check() }
+            tokens.append(ns.substring(with:match.range))
+        }
@@ -36,2 +42,9 @@ enum PDFUnicodeMap {
-        var spaces: [(Int, Int)] = [], byteCount: Int?, values: [Int: String] = [:]
-        var i = 0
+        // The code domain is finite. Each valid disjoint range marks at most
+        // 65,536 positions in total; membership no longer rescans every range.
+        var covered = [Bool](repeating:false,count:65536)
+        var byteCount: Int?, values: [Int: String] = [:]
+        var i = 0, work = 0
+        func consume() throws {
+            work += 1
+            if work % 128 == 0 { try check() }
+        }
@@ -55,0 +69 @@ enum PDFUnicodeMap {
+            try consume()
@@ -57,3 +71,2 @@ enum PDFUnicodeMap {
-                  spaces.contains(where: { $0.0 <= key && key <= $0.1 }),
-                  let text = String(data: Data(bytes), encoding: .utf16BigEndian), !text.isEmpty,
-                  !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
+                  covered.indices.contains(key), covered[key],
+                  let text = String(data: Data(bytes), encoding: .utf16BigEndian), !text.isEmpty else {
@@ -61,0 +75,2 @@ enum PDFUnicodeMap {
+            // Unused entries (including the conventional .notdef NUL) are
+            // metadata. PDFTextGeometry rejects a control mapping at actual use.
@@ -64,0 +80 @@ enum PDFUnicodeMap {
+            try consume()
@@ -69 +85 @@ enum PDFUnicodeMap {
-            let token = tokens[i]; i += 1
+            let token = try next()
@@ -82,2 +98,6 @@ enum PDFUnicodeMap {
-                    guard l <= h, !spaces.contains(where: { l <= $0.1 && h >= $0.0 }) else { throw PDFTextFailure.unsupported }
-                    spaces.append((l, h))
+                    guard l <= h else { throw PDFTextFailure.unsupported }
+                    for code in l...h {
+                        try consume()
+                        guard !covered[code] else { throw PDFTextFailure.unsupported }
+                        covered[code] = true
+                    }
diff --git a/Takupoke/SpecialSchedule.swift b/Takupoke/SpecialSchedule.swift
index 78bdec3..2702e69 100644
--- a/Takupoke/SpecialSchedule.swift
+++ b/Takupoke/SpecialSchedule.swift
@@ -26 +26 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
-    static let parserVersion = 6
+    static let parserVersion = 25
@@ -36,0 +37 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
+    var recovery: RecoveryAdopted? = nil
@@ -43,0 +45 @@ struct SpecialScheduleAnalysis: Codable, Equatable {
+        if let recovered = recovery?.document.times["\(date):\(period)"] { return recovered }
diff --git a/Takupoke/SpecialScheduleParser+Pages.swift b/Takupoke/SpecialScheduleParser+Pages.swift
index 8be40fd..3e51133 100644
--- a/Takupoke/SpecialScheduleParser+Pages.swift
+++ b/Takupoke/SpecialScheduleParser+Pages.swift
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
@@ -61 +62,2 @@ extension SpecialScheduleParser {
-        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5 else {
+        guard dates.count == 5, Set(dates.map { $0.1 }).count == 5,
+              zip(dates,dates.dropFirst()).allSatisfy({ $0.0.1 < $0.1.1 }) else {
@@ -88,0 +91 @@ extension SpecialScheduleParser {
+        let referenceBoxes = try grid.lessonBoxes(rows:classRuns.map { try grid.box($0.cx,$0.cy,check:check) },columns:periods.map(\.cx),check:check)
@@ -99 +102 @@ extension SpecialScheduleParser {
-            let row = try grid.box(run.cx, run.cy)
+            let row = try grid.box(run.cx, run.cy,check:check)
@@ -110 +113 @@ extension SpecialScheduleParser {
-                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2)
+                        let box = try grid.box(x, (edges[i] + edges[i + 1]) / 2,check:check)
@@ -114 +117 @@ extension SpecialScheduleParser {
-                                              times: dayTimes, pageNumber: 1)
+                                              times: dayTimes, pageNumber: 1,referenceBoxes:referenceBoxes,using:grid,check:check)
diff --git a/Takupoke/SpecialScheduleParser+Times.swift b/Takupoke/SpecialScheduleParser+Times.swift
index 504f1d3..70b8988 100644
--- a/Takupoke/SpecialScheduleParser+Times.swift
+++ b/Takupoke/SpecialScheduleParser+Times.swift
@@ -5,0 +6 @@ extension SpecialScheduleParser {
+        guard (1...8).contains(count) else { throw PDFParseError(code:.unsupported,page:pageNumber,stage:.periodHeading) }
@@ -42,0 +44,8 @@ extension SpecialScheduleParser {
+        for period in 1..<count {
+            // Canonical HH:mm strings have the same order as clock minutes.
+            // Explicit consecutive periods remain their own PDF-backed chart.
+            guard let previous = times[period], let current = times[period+1],
+                  String(previous.suffix(5)) <= String(current.prefix(5)) else {
+                throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.periodHeading)
+            }
+        }
diff --git a/Takupoke/SpecialScheduleParser.swift b/Takupoke/SpecialScheduleParser.swift
index 1e14c7c..f488de0 100644
--- a/Takupoke/SpecialScheduleParser.swift
+++ b/Takupoke/SpecialScheduleParser.swift
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
@@ -48 +49,3 @@ enum SpecialScheduleParser {
-            let pageYear = 2018 + era
+            let pageYear: Int
+            do { pageYear = try PDFSchoolParser.uniqueTitleYear(rawHeader,check:check) }
+            catch var error as PDFParseError { error.page = index+1; throw error }
@@ -76 +79 @@ enum SpecialScheduleParser {
-              coveredClasses.count == 17, !lessons.isEmpty else { throw PDFParseError(code: .unsupported) }
+              coveredClasses == Set(RecoveryValidator.specialClasses), !lessons.isEmpty else { throw PDFParseError(code: .unsupported) }
@@ -125,3 +128,3 @@ enum SpecialScheduleParser {
-                                times: Times, pageNumber: Int) throws -> [SpecialScheduleLesson] {
-        let grid = PDFGrid(page: page)
-        let lines = try grid.timetableText(box).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
+                                times: Times, pageNumber: Int, referenceBoxes: [PDFBox], using suppliedGrid: PDFGrid? = nil, check: () throws -> Void = {}) throws -> [SpecialScheduleLesson] {
+        let grid = suppliedGrid ?? PDFGrid(page: page)
+        let rawLines = try grid.timetableText(box,check:check).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
@@ -129 +132 @@ enum SpecialScheduleParser {
-        guard lines.count <= 8, lines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
+        guard rawLines.count <= 3, rawLines.reduce(0, { $0 + $1.utf8.count }) <= 4096 else {
@@ -132 +135,3 @@ enum SpecialScheduleParser {
-        guard !lines.isEmpty else { return [] }
+        guard !rawLines.isEmpty else { return [] }
+        guard !rawLines.contains(where:RecoveryRole.hasLabelPrefix) else { throw PDFParseError(code: .unsupported, page: pageNumber, stage: .lessonLines) }
+        let lines = try grid.lessonFields(box, lines: rawLines,referenceBoxes:referenceBoxes,check:check)
```
