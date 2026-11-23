import XCTest
import UIKit

extension ApplicationChecks {
    private func sRGBPixels(_ image: UIImage) throws -> (width: Int, bytes: [UInt8]) {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (width, pixels)
    }

    // Extract actual colored ink, excluding the neutral glass, text, and tab
    // background. Medians reduce the influence of anti-aliased edge pixels.
    private func coloredInk(_ image: UIImage) throws -> [Double] {
        let pixels = try sRGBPixels(image).bytes
        var channels = [[Double](), [Double](), [Double]()]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = (0..<3).map { Double(pixels[offset + $0]) / 255 }
            guard rgb.max()! - rgb.min()! > 0.25, rgb.max()! > 0.35 else { continue }
            for channel in 0..<3 { channels[channel].append(rgb[channel]) }
        }
        XCTAssertGreaterThan(channels[0].count, 30, "The real control must contain visible colored ink")
        return try channels.map { values in
            let ordered = values.sorted()
            return try XCTUnwrap(ordered.isEmpty ? nil : ordered[ordered.count / 2])
        }
    }

    private func assertYellowSettingsIcon(contrast: String) throws {
        let row = visible(app.buttons["時間割ファイル"], navigation: "設定", searchEarlierRows: true)
        recoveryScreenshot("yellow-settings-" + contrast)
        let scan = try sRGBPixels(row.screenshot().image)
        let pixels = scan.bytes
        var left = scan.width, right = 0, top = pixels.count / (scan.width * 4), bottom = 0
        var yellowPixels = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset] >= 250, (199...209).contains(pixels[offset + 1]), pixels[offset + 2] <= 5 else { continue }
            let index = offset / 4
            let x = index % scan.width, y = index / scan.width
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
            yellowPixels += 1
        }
        XCTAssertGreaterThan(yellowPixels, 30, "The icon must draw its existing glyph in #FFCC00")
        guard left < right, top < bottom else {
            XCTFail("The setting row must include a visible yellow glyph")
            return
        }
        var whitePixels = 0
        for y in top...bottom {
            for x in left...right {
                let offset = (y * scan.width + x) * 4
                if pixels[offset] >= 235 && pixels[offset + 1] >= 235 && pixels[offset + 2] >= 235 {
                    whitePixels += 1
                }
            }
        }
        let area = (right - left + 1) * (bottom - top + 1)
        print("YELLOW_ICON contrast=\(contrast);yellow=\(yellowPixels);white=\(whitePixels);area=\(area)")
        XCTAssertGreaterThan(whitePixels, area / 3, "The original icon interior must show the light row surface")
    }

    private func assertYellowTab(_ title: String, appearance: String) throws -> Double {
        let tab = app.tabBars.buttons[title]
        let button = try tab.snapshot()
        XCTAssertTrue(button.isSelected)
        let frame = button.frame
        let images = try XCTUnwrap(snapshotNodes(in: button)).filter { $0.elementType == .image }
        XCTAssertEqual(images.count, 1, "The selected tab must expose one native icon")
        let icon = try XCTUnwrap(images.first).frame
        XCTAssertTrue(frame.contains(icon), "The real icon must be within the native tab")
        recoveryScreenshot("yellow-tab-" + (title == "設定" ? "settings" : "timetable") + "-" + appearance)
        let photo = try XCTUnwrap(tab.screenshot().image.cgImage)
        let scaleX = CGFloat(photo.width) / frame.width
        let scaleY = CGFloat(photo.height) / frame.height
        func pixels(in region: CGRect) throws -> [UInt8] {
            let crop = CGRect(x: (region.minX - frame.minX) * scaleX, y: (region.minY - frame.minY) * scaleY,
                              width: region.width * scaleX, height: region.height * scaleY).integral
            let cg = try XCTUnwrap(photo.cropping(to: crop))
            return try sRGBPixels(UIImage(cgImage: cg)).bytes
        }
        let glyph = try pixels(in: icon)
        let yellowPixels = stride(from: 0, to: glyph.count, by: 4).count { offset in
            glyph[offset] >= 250 && (199...209).contains(glyph[offset + 1]) && glyph[offset + 2] <= 5
        }
        XCTAssertGreaterThan(yellowPixels, 120, "The selected tab icon must render #FFCC00")
        let textRegion = CGRect(x: frame.minX + frame.width * 0.16, y: icon.maxY,
                                width: frame.width * 0.68, height: frame.maxY - icon.maxY)
        let ink = try pixels(in: textRegion)
        var textLuminances: [Double] = []
        var backgroundLuminances: [Double] = []
        func linear(_ channel: UInt8) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        for offset in stride(from: 0, to: ink.count, by: 4) {
            let red = ink[offset], green = ink[offset + 1], blue = ink[offset + 2]
            let darkest = min(red, green, blue), lightest = max(red, green, blue)
            guard lightest - darkest <= 28 else { continue }
            let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
            if lightest <= 120 { textLuminances.append(luminance) }
            if darkest >= 170 { backgroundLuminances.append(luminance) }
        }
        XCTAssertGreaterThan(textLuminances.count, 50, "The selected tab must have dark readable lettering")
        XCTAssertGreaterThan(backgroundLuminances.count, 50, "The label must have a light stock background")
        let textSample = try XCTUnwrap(textLuminances.sorted().dropFirst(textLuminances.count / 4).first)
        let background = try XCTUnwrap(backgroundLuminances.sorted().dropFirst(backgroundLuminances.count / 4).first)
        let ratio = (background + 0.05) / (textSample + 0.05)
        print("YELLOW_TAB title=\(title);appearance=\(appearance);yellow=\(yellowPixels);text-contrast=\(ratio)")
        XCTAssertGreaterThanOrEqual(ratio, 4.5)
        return ratio
    }

    private func requireThemeContrast(_ value: String) {
        let observed = expectation(for: NSPredicate(format: "label == %@", value),
                                   evaluatedWith: app.staticTexts["fixture-theme-contrast"])
        wait(for: [observed], timeout: 10)
    }

    func testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch() throws {
        requireThemeContrast("standard")
        tab("時間割")
        tap("翌週")
        let calendar = app.buttons["timetable-week-calendar"]
        let selectedWeek = calendar.label
        var settingsTitle: Double?
        var timetableTitle: Double?
        for (title, stored) in [("オレンジ", "orange"), ("黄色", "yellow"), ("緑", "green"), ("デフォルト", "未設定"), ("青", "blue")] {
            tab("設定")
            tap("メインカラー")
            tap(title)
            let saved = expectation(for: NSPredicate(format: "label == %@", stored),
                                    evaluatedWith: app.staticTexts["fixture-stored-color"])
            wait(for: [saved], timeout: 10)
            if stored == "yellow" {
                try assertYellowSettingsIcon(contrast: "standard")
                settingsTitle = try assertYellowTab("設定", appearance: "standard")
            }
            tab("時間割")
            XCTAssertEqual(calendar.label, selectedWeek, "Changing color must retain the selected week")
            if stored == "yellow" { recoveryScreenshot("yellow-week-standard") }
            let buttonInk = try coloredInk(calendar.screenshot().image)
            if stored == "yellow" {
                XCTAssertGreaterThan(buttonInk[2], 0.7)
                XCTAssertGreaterThan(buttonInk[2], buttonInk[0] + 0.15)
                timetableTitle = try assertYellowTab("時間割", appearance: "standard")
            } else {
                let tabInk = try coloredInk(app.tabBars.buttons["時間割"].screenshot().image)
                for channel in 0..<3 {
                    XCTAssertEqual(buttonInk[channel], tabInk[channel], accuracy: 0.12,
                                   "Calendar and selected tab must draw the same \(title) without dark mixing")
                }
                if stored == "orange" {
                    XCTAssertGreaterThan(buttonInk[0], 0.8)
                    XCTAssertGreaterThan(buttonInk[0], buttonInk[2] + 0.3)
                } else if stored == "green" {
                    XCTAssertGreaterThan(buttonInk[1], 0.5)
                    XCTAssertGreaterThan(buttonInk[1], buttonInk[0] + 0.1)
                } else {
                    XCTAssertGreaterThan(buttonInk[2], 0.7)
                    XCTAssertGreaterThan(buttonInk[2], buttonInk[0] + 0.15)
                }
            }
            recoveryScreenshot("live-theme-" + stored)
        }

        tab("設定")
        tap("メインカラー")
        tap("黄色")
        let saved = expectation(for: NSPredicate(format: "label == %@", "yellow"),
                                evaluatedWith: app.staticTexts["fixture-stored-color"])
        wait(for: [saved], timeout: 10)
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        app.launchArguments.append("--increased-theme-contrast")
        launchReady()
        requireThemeContrast("increased")
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "yellow")
        tab("設定")
        try assertYellowSettingsIcon(contrast: "increased")
        let increasedSettings = try assertYellowTab("設定", appearance: "increased")
        XCTAssertGreaterThan(increasedSettings, try XCTUnwrap(settingsTitle) + 1)
        tab("時間割")
        recoveryScreenshot("yellow-week-increased")
        let highContrastCalendar = try coloredInk(app.buttons["timetable-week-calendar"].screenshot().image)
        XCTAssertGreaterThan(highContrastCalendar[2], 0.7)
        XCTAssertGreaterThan(highContrastCalendar[2], highContrastCalendar[0] + 0.15)
        let increasedTimetable = try assertYellowTab("時間割", appearance: "increased")
        XCTAssertGreaterThan(increasedTimetable, try XCTUnwrap(timetableTitle) + 1)
        recoveryScreenshot("yellow-calendar-increased")
    }

    func testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating() throws {
        tab("時間割")
        let grid = app.scrollViews["timetable-week-grid"]
        let calendar = app.buttons["timetable-week-calendar"]
        let initial = calendar.label
        let metrics = try gridMetrics()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let initialWeek = try XCTUnwrap(metrics["week"] as? String)
        let initialDate = try XCTUnwrap(formatter.date(from: initialWeek))
        let lastDate = try XCTUnwrap(formatter.date(from: try XCTUnwrap(metrics["lastWeek"] as? String)))
        let firstDate = try XCTUnwrap(formatter.date(from: try XCTUnwrap(metrics["firstWeek"] as? String)))
        let runsForward = lastDate.timeIntervalSince(initialDate) >= 3 * 604800
        if !runsForward { XCTAssertGreaterThanOrEqual(initialDate.timeIntervalSince(firstDate), 3 * 604800) }
        let visible = grid.frame.intersection(bodyViewport(navigation: "時間割"))
        let appFrame = app.frame
        XCTAssertGreaterThan(appFrame.height, appFrame.width, "Timed touches require the app's portrait window")
        XCTAssertGreaterThan(visible.width, 285)
        XCTAssertGreaterThan(visible.height, 30)
        let distance = min(240, visible.width - 65)
        let inputs = [(runsForward, 0.30, 0.0), (runsForward, 0.30, 0.10),
                      (runsForward, 0.105, 0.10), (!runsForward, 0.30, 0.0)]
        let sequence = inputs.map { next, duration, pause in
            let start = CGPoint(x: next ? visible.maxX - 30 : visible.minX + 30, y: visible.midY)
            let end = CGPoint(x: start.x + (next ? -distance : distance), y: start.y)
            return NativeTestContacts.Contact(start: start, end: end, duration: duration, pauseAfterLift: pause)
        }
        // Schedule the next real contact from the observed height handoff.
        // XCTest may compress requested idle gaps or take a different time to
        // return from the first dispatch on a loaded Simulator.
        let firstDelivery: TimeInterval
        do {
            let heightWindow = XCTestExpectation(description: "The arriving week began height adjustment")
            let observer = Unmanaged.passUnretained(heightWindow).toOpaque()
            guard WeekMotionSignal.heightWindow.observe(observer, callback: { _, context, _, _, _ in
                guard let context else { return }
                Unmanaged<XCTestExpectation>.fromOpaque(context).takeUnretainedValue().fulfill()
            }) else {
                XCTFail("Could not observe the simulator's week height handoff"); return
            }
            defer {
                WeekMotionSignal.heightWindow.remove(observer)
                withExtendedLifetime(heightWindow) {}
            }
            try NativeTestContacts.send(Array(sequence.prefix(1)), named: "Timed timetable week pulls")
            firstDelivery = ProcessInfo.processInfo.systemUptime
            guard XCTWaiter.wait(for: [heightWindow], timeout: 1.5) == .completed else {
                XCTFail("The first physical pull did not report a height handoff"); return
            }
        }
        let continuation = ProcessInfo.processInfo.systemUptime
        try NativeTestContacts.send(Array(sequence.dropFirst()), named: "Timed timetable week pulls")
        print("TAKUPOKE_WEEK_RECORDS firstDelivery=\(firstDelivery) continuation=\(continuation)")

        struct Event: Decodable {
            let kind: String
            let week: String?
            let target: String?
            let phase: String?
            let deferred: Bool?
            let time: Double
        }
        let proof = app.staticTexts["fixture-week-sequence"]
        var events: [Event] = []
        var latestReport = "none"
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let raw = proof.value as? String, let data = raw.data(using: .utf8),
                  let observed = try? JSONDecoder().decode([Event].self, from: data) else { return false }
            latestReport = raw
            events = observed
            return observed.filter { $0.kind == "arrival" }.count >= 4 && observed.last?.kind == "settled"
        }, object: proof)
        let result = XCTWaiter.wait(for: [complete], timeout: 8)
        print("TAKUPOKE_WEEK_SEQUENCE " + latestReport)
        guard result == .completed else {
            XCTFail("Four native drags and the final height adjustment must complete. Observed \(latestReport)"); return
        }
        let contacts = events.filter { $0.kind == "contact" }
        let releases = events.filter { $0.kind == "release" }
        let arrivals = events.filter { $0.kind == "arrival" }
        guard contacts.count == 4, releases.count == 4, arrivals.count == 4 else {
            XCTFail("Expected four distinct physical contacts and arrivals. Observed \(events)"); return
        }
        XCTAssertTrue(contacts.dropFirst().contains { $0.phase == "slide" },
                      "At least one new contact must reach the actual view during the preceding slide")
        XCTAssertTrue(contacts.dropFirst().contains { $0.phase == "height" },
                      "At least one contact must enter the arriving page during height adjustment")
        XCTAssertTrue(releases.dropFirst().contains { $0.phase == "slide" },
                      "At least one release must be received before the preceding slide has finished")
        var expectedWeek = initialWeek
        let expectedForwardInterval: TimeInterval = runsForward ? 604800 : -604800
        for (index, arrival) in arrivals.enumerated() {
            if let weekAtContact = contacts[index].week { XCTAssertEqual(weekAtContact, expectedWeek) }
            XCTAssertEqual(arrival.week, expectedWeek)
            XCTAssertGreaterThan(arrival.time, contacts[index].time)
            let source = try XCTUnwrap(formatter.date(from: expectedWeek))
            let destination = try XCTUnwrap(arrival.target)
            let actualTarget = try XCTUnwrap(formatter.date(from: destination))
            XCTAssertEqual(actualTarget.timeIntervalSince(source), index == 3 ? -expectedForwardInterval : expectedForwardInterval)
            expectedWeek = destination
        }
        XCTAssertEqual(arrivals[3].target, arrivals[1].target, "The last pull must reverse one week")
        var calendarDates = Calendar(identifier: .gregorian)
        calendarDates.timeZone = .gmt
        let start = try XCTUnwrap(formatter.date(from: expectedWeek))
        let end = try XCTUnwrap(calendarDates.date(byAdding: .day, value: 6, to: start))
        let lower = calendarDates.dateComponents([.month, .day], from: start)
        let upper = calendarDates.dateComponents([.month, .day], from: end)
        let expectedLabel = "\(try XCTUnwrap(lower.month))月\(try XCTUnwrap(lower.day))日から\(try XCTUnwrap(upper.month))月\(try XCTUnwrap(upper.day))日"
        XCTAssertNotEqual(expectedLabel, initial)
        XCTAssertEqual(calendar.label, expectedLabel, "The actual timetable calendar must show the fourth arrival")
        let duplicate = expectation(for: NSPredicate { _, _ in
            guard let raw = proof.value as? String,
                  let observed = try? JSONDecoder().decode([Event].self, from: Data(raw.utf8)) else { return false }
            return observed.filter { $0.kind == "arrival" }.count > 4
        }, evaluatedWith: proof)
        duplicate.isInverted = true
        wait(for: [duplicate], timeout: 0.65)
    }

    func testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable() throws {
        tab("時間割")
        let calendar = app.buttons["timetable-week-calendar"]
        let initialWeek = calendar.label
        let grid = app.scrollViews["timetable-week-grid"]
        let next = app.buttons["翌週"].exists
        for (index, towardNext) in [next, !next].enumerated() {
            let visible = grid.frame.intersection(bodyViewport(navigation: "時間割"))
            XCTAssertGreaterThan(visible.width, 230)
            XCTAssertGreaterThan(visible.height, 30)
            let x = towardNext ? visible.maxX - 30 : visible.minX + 30
            let start = CGPoint(x: x, y: visible.midY)
            let end = CGPoint(x: x + (towardNext ? -195 : 195), y: visible.midY)
            let reportReady = XCTestExpectation(description: "The app sampled and published the actual week frames")
            let observer = Unmanaged.passUnretained(reportReady).toOpaque()
            guard WeekMotionSignal.reportReady.observe(observer, callback: { _, context, _, _, _ in
                guard let context else { return }
                Unmanaged<XCTestExpectation>.fromOpaque(context).takeUnretainedValue().fulfill()
            }) else {
                XCTFail("Could not observe completion of the actual week frames"); return
            }
            defer {
                WeekMotionSignal.reportReady.remove(observer)
                withExtendedLifetime(reportReady) {}
            }
            // Keep the pre-release glass hold and the same real edge drag.
            // Do not ask XCTest to wait for application idle while frames are sampled.
            try NativeTestContacts.send([.init(start: start, end: end, duration: 0.8, pauseAfterLift: 0,
                                               holdBeforeMove: 0.08, holdBeforeLift: 0.30)], named: "Prepared week edge pull")
            let deadline = ProcessInfo.processInfo.systemUptime + 8
            guard XCTWaiter.wait(for: [reportReady], timeout: 8) == .completed else {
                XCTFail("The app did not finish recording the actual week frames"); return
            }
            let probe = app.staticTexts["fixture-week-motion"]
            var records: [[String: Any]] = []
            var observedJSON = ""
            let completed = expectation(for: NSPredicate { _, _ in
                guard let raw = probe.value as? String, let data = raw.data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
                records = value
                observedJSON = raw
                return value.count == index + 1
            }, evaluatedWith: probe)
            wait(for: [completed], timeout: max(0, deadline - ProcessInfo.processInfo.systemUptime))
            print("TAKUPOKE_WEEK_MOTION " + observedJSON)
            let record = try XCTUnwrap(records.last)
            XCTAssertEqual(record["gridMetricReadsDuringMotion"] as? Int, 0,
                           "The final grid snapshot must not compete with frame recording")
            let samples = try XCTUnwrap(record["samples"] as? [[String: Double]])
            let releaseX = try XCTUnwrap(record["releaseX"] as? Double)
            let releaseY = try XCTUnwrap(record["releaseY"] as? Double)
            let arrived = try XCTUnwrap(record["arrived"] as? Double)
            let finished = try XCTUnwrap(record["finished"] as? Double)
            let badge = try XCTUnwrap(record["badge"] as? [String: Any])
            let pngBytes = try XCTUnwrap(badge["pngBytes"] as? Int,
                "Require an actual pre-release glass capture: \(observedJSON)")
            XCTAssertGreaterThan(pngBytes, 100)
            func rect(_ key: String) throws -> CGRect {
                let fields = try XCTUnwrap(badge[key] as? [String: Double])
                return CGRect(x: try XCTUnwrap(fields["x"]), y: try XCTUnwrap(fields["y"]),
                              width: try XCTUnwrap(fields["width"]), height: try XCTUnwrap(fields["height"]))
            }
            let visibleBody = try rect("visible")
            let width = Double(visibleBody.width)
            let relativeX = towardNext ? width : -width
            XCTAssertTrue(try visibleBody.insetBy(dx: 8, dy: 8).contains(rect("frame")),
                          "Both sides and the bottom need room for the glass effect")
            XCTAssertGreaterThan(arrived, 0)
            XCTAssertGreaterThan(finished, arrived)
            let moving = samples.filter { ($0["t"] ?? .infinity) < arrived }
            let firstMotion = try XCTUnwrap(moving.first { abs(($0["sourceX"] ?? releaseX) - releaseX) > 1 })
            XCTAssertLessThanOrEqual(try XCTUnwrap(firstMotion["t"]), 0.10,
                                     "Release-to-first-visible-movement must include all preparation time")
            let sourcePositions = try moving.map { try XCTUnwrap($0["sourceX"]) }
            var visibleSourcePositions: [Double] = []
            var targetPositions: [Double] = []
            for frame in moving {
                let sourceX = try XCTUnwrap(frame["sourceX"])
                let targetX = try XCTUnwrap(frame["targetX"])
                let intersectsBody = targetX < Double(visibleBody.maxX) - 0.5
                    && targetX + width > Double(visibleBody.minX) + 0.5
                if intersectsBody {
                    XCTAssertEqual(targetX - sourceX, relativeX, accuracy: 1.5,
                                   "Visible pages must move together at their prepared spacing")
                    visibleSourcePositions.append(sourceX)
                    targetPositions.append(targetX)
                } else {
                    XCTAssertTrue(targetPositions.isEmpty, "The arriving page must stay visible once it enters")
                    XCTAssertEqual(sourceX, releaseX, accuracy: 1,
                                   "Once the released source moves, the prepared page must also be visible")
                }
            }
            for positions in [visibleSourcePositions, targetPositions] {
                XCTAssertGreaterThanOrEqual(Set(positions.map { Int(($0 * 2).rounded()) }).count, 4,
                                            "Both pages must travel through distinct positions")
            }
            for pagePositions in [[releaseX] + sourcePositions, targetPositions] {
                for (earlier, later) in zip(pagePositions, pagePositions.dropFirst()) {
                    let travel = later - earlier
                    XCTAssertGreaterThanOrEqual(towardNext ? -travel : travel, -0.5,
                                                  "Neither page may reverse after release")
                }
            }
            for axis in ["sourceY", "targetY"] {
                let values = moving.compactMap { $0[axis] }
                XCTAssertGreaterThanOrEqual(values.count, 4)
                XCTAssertLessThanOrEqual(try XCTUnwrap(values.max()) - (try XCTUnwrap(values.min())), 1.5,
                                         "Headers and body must keep their y position throughout horizontal travel")
            }
            XCTAssertEqual(try XCTUnwrap(moving.first?["sourceY"]), releaseY, accuracy: 1.5)
            for pair in zip(moving, moving.dropFirst()) {
                XCTAssertLessThanOrEqual(try XCTUnwrap(pair.1["t"]) - (try XCTUnwrap(pair.0["t"])), 0.09,
                                         "The main thread must continue serving display frames")
            }
            let landingFrames = samples.filter { ($0["t"] ?? -.infinity) >= arrived }
            let landed = try XCTUnwrap(landingFrames.last)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(landed["t"]), finished)
            let arrivingY = try XCTUnwrap(moving.last?["targetY"])
            let landedX = try XCTUnwrap(landed["targetX"])
            for frame in landingFrames {
                XCTAssertEqual(try XCTUnwrap(frame["targetY"]), arrivingY, accuracy: 1.5,
                               "Changing the row height must keep the arriving lessons anchored")
                XCTAssertEqual(try XCTUnwrap(frame["targetX"]), landedX, accuracy: 1.5,
                               "The arrived page must stay aligned as the row settles")
            }
            let heightBefore = try XCTUnwrap(moving.last?["rowHeight"])
            let heightAfter = try XCTUnwrap(landed["rowHeight"])
            let heightDirection = heightAfter > heightBefore ? 1.0 : -1.0
            XCTAssertGreaterThan(abs(heightAfter - heightBefore), 2, "The fixture must exercise a real height change")
            let adjusting = landingFrames.filter { ($0["t"] ?? .infinity) < finished }
            let heights = try adjusting.map { try XCTUnwrap($0["rowHeight"]) }
            let intermediate = heights.filter { height in
                (height - heightBefore) * heightDirection > 1 && (heightAfter - height) * heightDirection > 1
            }
            XCTAssertGreaterThanOrEqual(Set(intermediate.map { Int($0.rounded()) }).count, 2,
                                        "The actual row must resize through intermediate heights")
            let heightPath = [heightBefore] + heights + [heightAfter]
            for (earlier, later) in zip(heightPath, heightPath.dropFirst()) {
                XCTAssertGreaterThanOrEqual((later - earlier) * heightDirection, -1.5,
                                            "The height adjustment must not reverse")
            }
            let timePath = [arrived] + (try adjusting.map { try XCTUnwrap($0["t"]) }) + [finished]
            for (earlier, later) in zip(timePath, timePath.dropFirst()) {
                XCTAssertLessThanOrEqual(later - earlier, 0.09, "Height adjustment must keep drawing frames")
            }
            XCTAssertEqual(landedX, Double(visibleBody.minX), accuracy: 1.5,
                           "The destination must land at the observed left edge of the grid")
            let firstLanding = try XCTUnwrap(landingFrames.first)
            let sourceTravel = try [releaseX] + sourcePositions + [XCTUnwrap(firstLanding["sourceX"])]
            let targetAtRelease = releaseX + relativeX
            let targetTravel = try [targetAtRelease] + targetPositions + [XCTUnwrap(firstLanding["targetX"])]
            for positions in [sourceTravel, targetTravel] {
                for (earlier, later) in zip(positions, positions.dropFirst()) {
                    XCTAssertLessThanOrEqual(abs(later - earlier), width / 5,
                                             "A displayed frame must not skip a fifth of the grid")
                }
            }
            XCTAssertEqual(try gridMetrics()["eventsOnly"] as? Bool, index == 1)
        }
        XCTAssertEqual(calendar.label, initialWeek)
    }
}
