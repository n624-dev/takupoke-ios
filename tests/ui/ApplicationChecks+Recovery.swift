import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func dismissLesson(title: String = "授業詳細") {
        let bar = app.navigationBars[title]
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    }
    private func openRecoveryPreview(material: String = "通常時間割", recovery: String = "時間割の復旧") {
        tab("設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        tap("\(material)の詳細を見る")
        screen(material)
        XCTAssertTrue(
            app.staticTexts["fixture-recovery-formal"].firstMatch.label == "前回の正式結果を保持", app.debugDescription)
        tap("端末内で復旧する")
        screen(recovery)
        tap("端末内で復旧を開始")
        _ = recoveryVisible(app.staticTexts["採用する資料全体"].firstMatch)
        _ = recoveryVisible(app.staticTexts["選択クラスだけでなく、以下の資料全体を採用します。元のPDFと読み取り結果を確認してください。"].firstMatch)
    }
    func recoveryScreenshot(_ name: String, marker: String = "TAKUPOKE_UI_IMAGE") {
        let bytes = app.screenshot().pngRepresentation
        XCTAssertTrue((9...2 * 1024 * 1024).contains(bytes.count))
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let encoded = bytes.base64EncodedString()
        let chunkSize = 6000
        print("\(marker) BEGIN \(name) \(hash) \(bytes.count)")
        let characters = Array(encoded)
        for offset in stride(from: 0, to: characters.count, by: chunkSize) {
            let chunk = String(characters[offset..<min(offset + chunkSize, characters.count)])
            print("\(marker) DATA \(name) \(offset / chunkSize) \(chunk)")
        }
        print("\(marker) END \(name) \((characters.count + chunkSize - 1) / chunkSize)")
    }
    private var recoveryList: XCUIElement {
        app.collectionViews["fixture-recovery-list"].firstMatch
    }
    private var recoveryBar: XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "の復旧")).firstMatch
    }
    private var recoveryViewport: CGRect {
        let list = recoveryList.frame
        let top = max(list.minY, recoveryBar.frame.maxY) + 12
        let bottom = min(list.maxY, app.frame.maxY - 34) - 12
        return CGRect(x: list.minX, y: top, width: list.width, height: max(0, bottom - top))
    }
    private func recoveryDrag(earlier: Bool, distance: CGFloat? = nil) {
        guard recoveryBar.exists, recoveryList.exists else {
            XCTFail("Recovery sheet disappeared before its gesture")
            return
        }
        let viewport = recoveryViewport
        guard usable(viewport) else {
            XCTFail("Invalid recovery viewport")
            return
        }
        let privacy = recoveryList.staticTexts["学校の資料・OCR文字・授業情報は端末内で処理され、外部のAIへ送信されません。"].firstMatch
        guard !(earlier && contained(privacy, in: viewport)) else {
            XCTFail("Target was not found before reaching the recovery list top")
            return
        }
        // Begin on a passive row inside this sheet, never an editor/button,
        // the covered underlying List, or the outer sheet's dismissible gutter.
        let candidates = recoveryList.cells.allElementsBoundByIndex.filter {
            let area = $0.frame.intersection(viewport)
            return usable(area) && area.height > 36 && $0.buttons.count == 0 && $0.switches.count == 0
                && $0.textFields.count == 0 && $0.textViews.count == 0 && $0.pickers.count == 0
                && $0.pickerWheels.count == 0 && $0.staticTexts.count > 0
        }
        guard
            let cell = candidates.max(by: {
                earlier ? $0.frame.minY > $1.frame.minY : $0.frame.maxY < $1.frame.maxY
            })
        else {
            XCTFail("No passive recovery row for a safe drag")
            return
        }
        let safe = cell.frame.intersection(viewport)
        let x = max(safe.minX + 12, min(safe.maxX - 12, viewport.minX + 100))
        let y = earlier ? safe.minY + 12 : safe.maxY - 12
        let endY =
            earlier
            ? min(viewport.maxY - 12, y + (distance ?? 120))
            : max(viewport.minY + 12, y - (distance ?? viewport.height))
        guard abs(endY - y) > 1 else {
            XCTFail("No room for a recovery drag")
            return
        }
        let base = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let origin = app.frame.origin
        base.withOffset(CGVector(dx: x - origin.x, dy: y - origin.y)).press(
            forDuration: 0.1,
            thenDragTo: base.withOffset(CGVector(dx: x - origin.x, dy: endY - origin.y)))
    }
    private func recoveryVisible(_ element: XCUIElement, searchEarlierRows: Bool = false) -> XCUIElement {
        for _ in 0..<12 {
            guard recoveryBar.exists, recoveryList.exists else {
                XCTFail("The recovery sheet disappeared while locating its row: " + app.debugDescription)
                return element
            }
            let viewport = recoveryViewport
            if contained(element, in: viewport) { return element }
            let earlier =
                element.exists && usable(element.frame)
                ? element.frame.minY < viewport.minY : searchEarlierRows
            recoveryDrag(earlier: earlier)
        }
        XCTAssertTrue(
            recoveryBar.exists && recoveryList.exists && contained(element, in: recoveryViewport),
            "Recovery target remains outside its own sheet viewport: " + app.debugDescription)
        return element
    }
    func testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption() {
        openRecoveryPreview()
        recoveryScreenshot("ios-recovery-normal-preview")
        let fields = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "教員: 記載なし", "架空教室A")
        ).firstMatch
        _ = recoveryVisible(fields)
        _ = recoveryVisible(app.staticTexts["空欄"].firstMatch)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        // Stop as soon as the original button is visible. Extra downward
        // swipes at the top can dismiss the sheet through its native gesture.
        let original = recoveryVisible(app.buttons["元のPDFを確認"].firstMatch, searchEarlierRows: true)
        XCTAssertTrue(original.isHittable, app.debugDescription)
        original.tap()
        screen("元のPDF")
        XCTAssertTrue(app.navigationBars["元のPDF"].exists, app.debugDescription)
        recoveryScreenshot("ios-recovery-original")
        app.navigationBars["元のPDF"].buttons["閉じる"].tap()
        screen("時間割の復旧")
        let adoption = app.buttons["この資料全体の結果を使用"]
        _ = recoveryVisible(adoption)
        XCTAssertTrue(adoption.isHittable, app.debugDescription)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        adoption.tap()
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
        app.terminate()
        app.launchArguments = ["--recovery-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertEqual(
            app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み", app.debugDescription)
    }
    func testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption() {
        for (index, item) in [
            ("試験時間割", "試験時間割の復旧", "--recovery-exam", "08:05〜08:30"),
            ("試験返却時間割", "試験返却時間割の復旧", "--recovery-return", "08:50〜09:35"),
        ].enumerated() {
            if index > 0 {
                app.terminate()
                app.launchArguments = [
                    "--reset-fixture", "--recovery-preview", item.2, "-AppleLanguages", "(ja)",
                    "-AppleLocale", "ja_JP",
                ]
                launchReady()
            }
            openRecoveryPreview(material: item.0, recovery: item.1)
            _ = recoveryVisible(app.staticTexts["08:00〜09:00"].firstMatch)
            _ = recoveryVisible(app.staticTexts[item.3].firstMatch)
            recoveryScreenshot(index == 0 ? "ios-recovery-exam-preview" : "ios-recovery-return-preview")
            XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
            let adoption = app.buttons["この資料全体の結果を使用"]
            _ = recoveryVisible(adoption)
            XCTAssertTrue(adoption.isHittable, app.debugDescription)
            adoption.tap()
            XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
            XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
            app.terminate()
            app.launchArguments = [
                "--recovery-probe", item.2, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
            ]
            launchReady()
            XCTAssertEqual(
                app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み",
                app.debugDescription)
        }
    }
    func testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis() {
        openRecoveryPreview()
        for suffix in ["A", "B"] {
            _ = recoveryVisible(app.staticTexts["架空並記科目\(suffix)"])
            let paired = app.staticTexts.matching(
                NSPredicate(
                    format: "label CONTAINS %@ AND label CONTAINS %@",
                    "架空並記担当\(suffix)", "架空並記教室\(suffix)")
            ).firstMatch
            _ = recoveryVisible(paired)
        }
        let pairedFields = ["A", "B"].flatMap { suffix in
            [
                app.staticTexts["架空並記科目\(suffix)"],
                app.staticTexts.matching(
                    NSPredicate(
                        format: "label CONTAINS %@ AND label CONTAINS %@",
                        "架空並記担当\(suffix)", "架空並記教室\(suffix)")
                ).firstMatch,
            ]
        }
        // Align the whole pair group before measuring it. Full-list swipes
        // used to expose the last field can move the first behind the bar.
        for _ in 0..<10 {
            let top = recoveryViewport.minY
            let bottom = recoveryViewport.maxY
            guard recoveryBar.exists, recoveryList.exists,
                pairedFields.allSatisfy({ $0.exists && usable($0.frame) })
            else {
                XCTFail("Parallel fields lost their recovery sheet or geometry")
                return
            }
            let first = pairedFields.first!.frame.minY
            let last = pairedFields.last!.frame.maxY
            if first >= top && last <= bottom { break }
            let delta = first < top ? min(140, top - first + 12) : -min(140, last - bottom + 12)
            recoveryDrag(earlier: delta > 0, distance: abs(delta))
        }
        var previousBottom: CGFloat = 0
        for suffix in ["A", "B"] {
            let subject = app.staticTexts["架空並記科目\(suffix)"]
            let metadata = app.staticTexts.matching(
                NSPredicate(
                    format: "label CONTAINS %@ AND label CONTAINS %@",
                    "架空並記担当\(suffix)", "架空並記教室\(suffix)")
            ).firstMatch
            for field in [subject, metadata] {
                print("SYNTHETIC_PARALLEL_UI \(field.label) frame=\(field.frame)")
                XCTAssertTrue(
                    field.exists && !field.frame.isEmpty
                        && field.frame.minY >= app.navigationBars["時間割の復旧"].frame.maxY
                        && field.frame.maxY <= app.frame.maxY && field.frame.minY >= previousBottom - 1,
                    app.debugDescription)
                previousBottom = field.frame.maxY
            }
        }
        recoveryScreenshot("ios-recovery-parallel", marker: "TAKUPOKE_PARALLEL_UI_IMAGE")
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        let adoption = app.buttons["この資料全体の結果を使用"]
        _ = recoveryVisible(adoption)
        XCTAssertTrue(adoption.isHittable, app.debugDescription)
        adoption.tap()
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
        app.terminate()
        app.launchArguments = ["--recovery-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
        tab("設定")
        tap("時間割ファイル")
        tap("通常時間割の詳細を見る")
        screen("通常時間割")
        _ = heading("解析結果")
        for suffix in ["A", "B"] {
            let paired = app.buttons.matching(
                NSPredicate(
                    format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@",
                    "架空並記科目\(suffix)", "架空並記担当\(suffix)", "架空並記教室\(suffix)")
            ).firstMatch
            _ = visible(paired)
            XCTAssertTrue(paired.label.contains("3-IT · 月曜 · 1限"), app.debugDescription)
        }
    }
    func testRecoveryClosingKeepsFormalAndModelManagementIsAccessible() {
        openRecoveryPreview()
        app.navigationBars["時間割の復旧"].buttons["閉じる"].tap()
        screen("通常時間割")
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        back(to: "時間割ファイル")
        back(to: "設定")
        tap("端末内AIモデル")
        screen("端末内AIモデル")
        _ = heading("追加モデルは品質評価後に提供します。OSの端末内AIが利用可能な端末では追加ダウンロードは不要です。")
        XCTAssertFalse(app.buttons["モデルをダウンロード"].exists, app.debugDescription)
        recoveryScreenshot("ios-recovery-models")
    }
    func testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster() {
        let result = app.staticTexts["fixture-ocr-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), app.debugDescription)
        let finished = expectation(for: NSPredicate(format: "label != %@", "OCR実行中"), evaluatedWith: result)
        wait(for: [finished], timeout: 60)
        let accepted = "CropBox/footer検証済み; OCR・上端座標・罫線・未読インク検証済み"
        let safelyRejected = "CropBox/footer検証済み; 低信頼OCRを安全拒否・実raster・上端座標・罫線・未読インク・空欄検証済み; confidence="
        let observedConfidence =
            result.label.hasPrefix(safelyRejected)
            ? Double(result.label.dropFirst(safelyRejected.count)) : nil
        let rejectedLowConfidence = observedConfidence.map { $0.isFinite && $0 >= 0 && $0 < 0.85 } ?? false
        XCTAssertTrue(result.label == accepted || rejectedLowConfidence, app.debugDescription)
        print("SYNTHETIC_NATIVE_OCR_RESULT " + result.label)
        let table = app.staticTexts["fixture-native-table-capture"]
        XCTAssertTrue(table.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(table.label.contains("wholeDocumentQuality=UNASSESSED"), app.debugDescription)
        print(table.label)
    }
}
