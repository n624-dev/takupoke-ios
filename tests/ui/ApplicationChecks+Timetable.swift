import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func testMergedCardsFromAllSources() {
        tab("時間割")
        for subject in ["架空科目A", "架空試験A", "架空返却A", "架空変更A"] {
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", subject)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            for _ in 0..<8 {
                let top = app.navigationBars.firstMatch.frame.maxY
                let bottom = app.tabBars.firstMatch.frame.minY
                if card.isHittable && card.frame.midY > top && card.frame.midY < bottom { break }
                if card.frame.midY <= top { app.swipeDown() } else { app.swipeUp() }
            }
            let ready = expectation(
                for: NSPredicate { _, _ in
                    card.isHittable && card.frame.midY > self.app.navigationBars.firstMatch.frame.maxY
                        && card.frame.midY < self.app.tabBars.firstMatch.frame.minY
                }, evaluatedWith: card)
            wait(for: [ready], timeout: 10)
            XCTAssertGreaterThan(card.frame.height, 72)
            card.tap()
            let title = subject == "架空変更A" ? "時間割変更" : "授業詳細"
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), app.debugDescription)
            dismissLesson(title: title)
        }
        XCTAssertTrue(app.staticTexts["架空行事A"].firstMatch.exists || app.buttons["架空行事A"].exists)
    }
    func testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork() {
        func openFirstLesson(_ surface: String) {
            tab(surface)
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            for _ in 0..<8 {
                if card.exists && card.isHittable
                    && card.frame.midY > app.navigationBars.firstMatch.frame.maxY
                    && card.frame.midY < app.tabBars.firstMatch.frame.minY
                {
                    break
                }
                if card.exists && card.frame.midY <= app.navigationBars.firstMatch.frame.maxY {
                    app.swipeDown()
                } else {
                    app.swipeUp()
                }
            }
            XCTAssertTrue(card.exists && card.isHittable, app.debugDescription)
            card.tap()
            screen("授業詳細")
        }
        for surface in ["ホーム", "時間割"] {
            // A changed raw source deliberately retains the last good analysis.
            // Start each surface from a fresh, matching source/analysis pair.
            if surface == "時間割" {
                app.terminate()
                launchReady()
            }
            let initial = app.staticTexts["fixture-selection-data"].label
            openFirstLesson(surface)
            app.buttons["架空処理のみ"].tap()
            let busy = app.staticTexts["fixture-selection-busy"]
            let started = expectation(for: NSPredicate(format: "label == %@", "架空処理中"), evaluatedWith: busy)
            wait(for: [started], timeout: 5)
            XCTAssertTrue(app.navigationBars["授業詳細"].exists, app.debugDescription)
            let outcome = app.staticTexts["fixture-selection-busy-outcome"]
            XCTAssertEqual(outcome.label, "released=false;completion=pending")
            app.buttons["架空処理を終了"].tap()
            let finished = expectation(for: NSPredicate(format: "label == %@", "架空待機中"), evaluatedWith: busy)
            wait(for: [finished], timeout: 10)
            let completed = expectation(
                for: NSPredicate(format: "label == %@", "released=true;completion=success"),
                evaluatedWith: outcome)
            wait(for: [completed], timeout: 10)
            XCTAssertEqual(app.staticTexts["fixture-selection-data"].label, initial)
            XCTAssertTrue(app.navigationBars["授業詳細"].exists, app.debugDescription)
            app.buttons["架空正式更新"].tap()
            XCTAssertTrue(app.navigationBars["授業詳細"].waitForNonExistence(timeout: 15), app.debugDescription)
            XCTAssertNotEqual(app.staticTexts["fixture-selection-data"].label, initial, app.debugDescription)
            let adopted = app.staticTexts["fixture-selection-data"].label
            openFirstLesson(surface)
            app.buttons["架空原本更新"].tap()
            XCTAssertTrue(app.navigationBars["授業詳細"].waitForNonExistence(timeout: 15), app.debugDescription)
            XCTAssertNotEqual(app.staticTexts["fixture-selection-data"].label, adopted, app.debugDescription)
            print(
                "SYNTHETIC_SELECTION_UI \(surface): busy-only kept detail; actual formal and source writes closed detail"
            )
        }
    }
    func testHomeTimetableAndWeekCalendar() {
        XCTAssertTrue(app.staticTexts["今日の予定"].waitForExistence(timeout: 10))
        tab("時間割")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A")).firstMatch
                .waitForExistence(timeout: 10), app.debugDescription)
        // Actual merged cards must stay within the app frame.
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A"))
        XCTAssertGreaterThan(cards.count, 0)
        let first = cards.element(boundBy: 0)
        XCTAssertGreaterThan(first.frame.height, 0)
        XCTAssertLessThanOrEqual(first.frame.maxX, app.frame.maxX + 1)
        first.tap()
        XCTAssertTrue(app.staticTexts["架空教員A"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        dismissLesson()
        let calendar = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "月", "日から")
        ).firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 5), app.debugDescription)
        calendar.tap()
        XCTAssertTrue(app.buttons["この週へ移動"].waitForExistence(timeout: 5))
        tapToolbar("キャンセル", bar: "週を選ぶ")
        XCTAssertFalse(app.buttons["この週へ移動"].exists)
        if app.buttons["翌週"].exists {
            tap("翌週")
            XCTAssertTrue(app.buttons["前週"].exists)
            tap("前週")
        }
    }

    private func gridMetrics() throws -> [String: Any] {
        let probe = app.staticTexts["fixture-grid-metrics"]
        for _ in 0..<8 {
            if probe.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(probe.waitForExistence(timeout: 10), app.debugDescription)
        let json = try XCTUnwrap(probe.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func selectTypeSize(_ title: String) throws -> [String: Any] {
        app.buttons["fixture-type-size"].tap()
        app.buttons[title].tap()
        return try gridMetrics()
    }

    func testTimetableDynamicTypeScalesAndRestoresStandardLayout() throws {
        tab("時間割")
        let standard = try gridMetrics()
        func number(_ key: String, in value: [String: Any]) throws -> Double {
            try XCTUnwrap(value[key] as? Double)
        }
        func assertLayout(_ metrics: [String: Any]) throws {
            let scale = try number("scale", in: metrics)
            let width = try number("width", in: metrics)
            let baseWidth = try number("baseWidth", in: metrics)
            XCTAssertGreaterThanOrEqual(scale, 1)
            XCTAssertEqual(width, baseWidth * scale, accuracy: 0.1)
            XCTAssertEqual(
                baseWidth * 5 + (try number("basePeriodWidth", in: metrics)) + 12,
                try number("viewport", in: metrics), accuracy: 0.1)
            for (key, base) in [
                ("subjectFont", 11.0), ("metadataFont", 9.0), ("eventFont", 14.0), ("periodFont", 15.0),
            ] {
                XCTAssertEqual(try number(key, in: metrics), base * scale, accuracy: 0.01)
            }
            let heights = try XCTUnwrap(metrics["heights"] as? [Double])
            XCTAssertEqual(heights.count, 8)
            XCTAssertTrue(heights.allSatisfy { $0 >= 72 * scale })
            let cards = try XCTUnwrap(metrics["cards"] as? [[String: Any]])
            XCTAssertTrue(cards.contains { ($0["cancellation"] as? Bool) == true })
            XCTAssertEqual(
                Set(cards.compactMap { $0["source"] as? String }),
                Set(["normal", "change", "exam", "examReturn"]))
            for card in cards {
                let frame = try XCTUnwrap(card["frame"] as? [String: Double])
                XCTAssertEqual(try XCTUnwrap(frame["width"]), width, accuracy: 1)
                XCTAssertEqual(try XCTUnwrap(frame["height"]), try number("height", in: card), accuracy: 1)
                XCTAssertGreaterThanOrEqual(
                    try XCTUnwrap(frame["height"]), try number("required", in: card) - 1)
            }
            for source in ["normal", "change", "exam", "examReturn"] {
                XCTAssertTrue(
                    cards.contains {
                        ($0["source"] as? String) == source
                            && ($0["end"] as? Int ?? 0) > ($0["start"] as? Int ?? 0)
                    })
            }
            for day in Set(cards.compactMap { $0["day"] as? String }) {
                let entries = cards.filter { ($0["day"] as? String) == day }
                for (i, first) in entries.enumerated() {
                    for second in entries.dropFirst(i + 1)
                    where (first["lane"] as? Int) == (second["lane"] as? Int) {
                        let a = try XCTUnwrap(first["start"] as? Int)...(try XCTUnwrap(first["end"] as? Int))
                        let b =
                            try XCTUnwrap(second["start"] as? Int)...(try XCTUnwrap(second["end"] as? Int))
                        XCTAssertFalse(a.overlaps(b))
                        let firstFrame = try XCTUnwrap(first["frame"] as? [String: Double])
                        let secondFrame = try XCTUnwrap(second["frame"] as? [String: Double])
                        let upper = a.lowerBound < b.lowerBound ? firstFrame : secondFrame
                        let lower = a.lowerBound < b.lowerBound ? secondFrame : firstFrame
                        XCTAssertLessThanOrEqual(
                            try XCTUnwrap(upper["y"]) + (try XCTUnwrap(upper["height"])),
                            (try XCTUnwrap(lower["y"])) - 1)
                    }
                }
            }
        }
        try assertLayout(standard)
        XCTAssertEqual(try number("scale", in: standard), 1)
        let small = try selectTypeSize("小")
        try assertLayout(small)
        for key in [
            "width", "baseWidth", "subjectFont", "metadataFont", "eventFont", "periodFont", "periodWidth",
        ] {
            XCTAssertEqual(try number(key, in: small), try number(key, in: standard), accuracy: 0.1)
        }
        var previous = standard
        for title in ["大", "最大"] {
            let enlarged = try selectTypeSize(title)
            try assertLayout(enlarged)
            XCTAssertGreaterThan(try number("scale", in: enlarged), try number("scale", in: previous))
            XCTAssertEqual(
                try number("baseWidth", in: enlarged), try number("baseWidth", in: standard), accuracy: 0.1)
            let oldTimes = try XCTUnwrap(previous["cards"] as? [[String: Any]]).compactMap {
                $0["timeFont"] as? Double
            }.filter { $0 > 0 }
            let newTimes = try XCTUnwrap(enlarged["cards"] as? [[String: Any]]).compactMap {
                $0["timeFont"] as? Double
            }.filter { $0 > 0 }
            XCTAssertEqual(oldTimes.count, newTimes.count)
            for (old, new) in zip(oldTimes, newTimes) { XCTAssertGreaterThan(new, old) }
            // Read actual rendered card bounds as well as the layout metrics.
            let first = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "架空科目A", "月")
            ).firstMatch
            XCTAssertTrue(first.exists)
            XCTAssertEqual(first.frame.width, try number("width", in: enlarged), accuracy: 1)
            previous = enlarged
        }
        let restored = try selectTypeSize("標準")
        try assertLayout(restored)
        for key in ["width", "baseWidth", "subjectFont", "metadataFont", "periodWidth"] {
            XCTAssertEqual(try number(key, in: restored), try number(key, in: standard), accuracy: 0.1)
        }
        XCTAssertEqual(
            try XCTUnwrap(restored["heights"] as? [Double]), try XCTUnwrap(standard["heights"] as? [Double]))
    }

    func testTimetableUsesSystemTextSize() throws {
        tab("時間割")
        let metrics = try gridMetrics()
        let scale = try XCTUnwrap(metrics["scale"] as? Double)
        let category = try XCTUnwrap(metrics["systemSize"] as? String)
        XCTAssertEqual(
            category, try XCTUnwrap(metrics["expectedSystemSize"] as? String),
            "The requested Simulator OS setting must actually reach the app")
        let standardOrSmaller = [UIContentSizeCategory.extraSmall, .small, .medium, .large].map(\.rawValue)
        if standardOrSmaller.contains(category) {
            XCTAssertEqual(scale, 1)
        } else {
            XCTAssertGreaterThan(scale, 1, category)
        }
        XCTAssertEqual(try XCTUnwrap(metrics["subjectFont"] as? Double), 11 * scale, accuracy: 0.01)
        XCTAssertEqual(
            try XCTUnwrap(metrics["width"] as? Double),
            (try XCTUnwrap(metrics["baseWidth"] as? Double)) * scale, accuracy: 0.1)
        print("System text size: \(category); timetable scale: \(scale)")
    }

    func testTimetableCommonClocksAndEventOnlyWeekScale() throws {
        for eventsOnly in [false, true] {
            if eventsOnly {
                app.terminate()
                app.launchArguments = [
                    "--reset-fixture", "--grid-probe", "--normal-only", "--events-only",
                    "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
                ]
                launchReady()
            }
            tab("時間割")
            for title in ["標準", "最大", "標準"] {
                let metrics = try selectTypeSize(title)
                let scale = try XCTUnwrap(metrics["scale"] as? Double)
                let heights = try XCTUnwrap(metrics["heights"] as? [Double])
                XCTAssertEqual(metrics["eventsOnly"] as? Bool, eventsOnly)
                let days = try XCTUnwrap(metrics["days"] as? [String])
                let headers = days.map { app.descendants(matching: .any)["timetable-day-" + $0].firstMatch }
                XCTAssertTrue(headers.allSatisfy(\.exists))
                // Combined accessibility elements report their text bounds.
                // Measure the actual outer view, including its aligned frame.
                let frames = try XCTUnwrap(metrics["headerFrames"] as? [String: [String: Double]])
                XCTAssertEqual(Set(frames.keys), Set(days))
                let headerHeight = try XCTUnwrap(frames[days[0]]?["height"])
                XCTAssertGreaterThan(headerHeight, 0)
                for day in days {
                    XCTAssertEqual(try XCTUnwrap(frames[day]?["height"]), headerHeight, accuracy: 1)
                }
                if eventsOnly {
                    XCTAssertEqual((metrics["cards"] as? [[String: Any]])?.count, 0)
                    let event = app.descendants(matching: .any)["timetable-event-架空行事A"].firstMatch
                    XCTAssertTrue(event.exists)
                    let sizes = try XCTUnwrap(metrics["eventSizes"] as? [String: [String: Double]])
                    XCTAssertEqual(try XCTUnwrap(sizes["架空行事A"]?["height"]), 72 * scale, accuracy: 1)
                    XCTAssertEqual(
                        try XCTUnwrap(sizes["架空行事A"]?["width"]), try XCTUnwrap(metrics["width"] as? Double),
                        accuracy: 1)
                    let grid = app.scrollViews["timetable-week-grid"]
                    XCTAssertTrue(grid.exists)
                    XCTAssertEqual(
                        try XCTUnwrap(frames[days[0]]?["x"]),
                        (try XCTUnwrap(metrics["periodWidth"] as? Double)) + 2, accuracy: 1)
                } else {
                    XCTAssertEqual((metrics["commonClocks"] as? [String])?.count, 8)
                    XCTAssertGreaterThanOrEqual(
                        try XCTUnwrap(metrics["periodWidth"] as? Double),
                        try XCTUnwrap(metrics["basePeriodWidth"] as? Double))
                    XCTAssertTrue(heights.allSatisfy { $0 >= 72 * scale })
                }
            }
        }
    }
    #if TAKUPOKE_VOICEOVER_AUTOMATION
        @MainActor func testVoiceOverReadsTimetableCard() throws {
            guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver automation requires iOS 27") }
            tab("時間割")
            let service = XCUIDevice.shared.voiceOverService
            try service.enable()
            defer { try? service.disable() }
            var utterances: [String] = []
            for _ in 0..<60 {
                let output = try service.moveForward()
                utterances.append(output.utterance)
                if output.utterance.contains("架空科目甲") { break }
            }
            for name in ["架空科目甲", "架空教員甲", "架空教室甲"] {
                XCTAssertTrue(utterances.contains { $0.contains(name) }, utterances.joined(separator: " | "))
            }
        }

    #else
        func testVoiceOverReadsTimetableCard() throws {
            throw XCTSkip("VoiceOver automation requires Xcode 27 and iOS 27")
        }
    #endif
}
