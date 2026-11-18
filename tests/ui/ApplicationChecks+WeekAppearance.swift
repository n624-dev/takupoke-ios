import XCTest
import UIKit

extension ApplicationChecks {
    // Extract actual colored ink, excluding the neutral glass, text, and tab
    // background. Medians reduce the influence of anti-aliased edge pixels.
    private func coloredInk(_ image: UIImage) throws -> [Double] {
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

    func testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch() throws {
        tab("時間割")
        tap("翌週")
        let calendar = app.buttons["timetable-week-calendar"]
        let selectedWeek = calendar.label
        for (title, stored) in [("オレンジ", "orange"), ("緑", "green"), ("デフォルト", "未設定"), ("青", "blue")] {
            tab("設定")
            tap("メインカラー")
            tap(title)
            let saved = expectation(for: NSPredicate(format: "label == %@", stored),
                                    evaluatedWith: app.staticTexts["fixture-stored-color"])
            wait(for: [saved], timeout: 10)
            tab("時間割")
            XCTAssertEqual(calendar.label, selectedWeek, "Changing color must retain the selected week")
            let buttonInk = try coloredInk(calendar.screenshot().image)
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
            recoveryScreenshot("live-theme-" + stored)
        }
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
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: visible.midY))
            start.press(forDuration: 0.08,
                        thenDragTo: start.withOffset(CGVector(dx: towardNext ? -195 : 195, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0.3)
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
            wait(for: [completed], timeout: 8)
            print("TAKUPOKE_WEEK_MOTION " + observedJSON)
            let record = try XCTUnwrap(records.last)
            let samples = try XCTUnwrap(record["samples"] as? [[String: Double]])
            let releaseX = try XCTUnwrap(record["releaseX"] as? Double)
            let arrived = try XCTUnwrap(record["arrived"] as? Double)
            XCTAssertGreaterThan(arrived, 0)
            let moving = samples.filter { ($0["t"] ?? .infinity) < arrived }
            let firstMotion = try XCTUnwrap(moving.first { abs(($0["sourceX"] ?? releaseX) - releaseX) > 1 })
            XCTAssertLessThanOrEqual(try XCTUnwrap(firstMotion["t"]), 0.10,
                                     "Release-to-first-visible-movement must include all preparation time")
            let sourcePositions = try moving.map { try XCTUnwrap($0["sourceX"]) }
            let targetPositions = try moving.map { try XCTUnwrap($0["targetX"]) }
            let positions = sourcePositions.map { Int(($0 * 2).rounded()) }
            XCTAssertGreaterThanOrEqual(Set(positions).count, 4, "A final jump is not continuous motion")
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
            for pair in zip(moving, moving.dropFirst()) {
                XCTAssertLessThanOrEqual(try XCTUnwrap(pair.1["t"]) - (try XCTUnwrap(pair.0["t"])), 0.09,
                                         "The main thread must continue serving display frames")
            }
            let badge = try XCTUnwrap(record["badge"] as? [String: Any])
            XCTAssertGreaterThan(try XCTUnwrap(badge["pngBytes"] as? Int), 100)
            func rect(_ key: String) throws -> CGRect {
                let fields = try XCTUnwrap(badge[key] as? [String: Double])
                return CGRect(x: try XCTUnwrap(fields["x"]), y: try XCTUnwrap(fields["y"]),
                              width: try XCTUnwrap(fields["width"]), height: try XCTUnwrap(fields["height"]))
            }
            XCTAssertTrue(try rect("visible").insetBy(dx: 8, dy: 8).contains(rect("frame")),
                          "Both sides and the bottom need room for the glass effect")
            XCTAssertEqual(try gridMetrics()["eventsOnly"] as? Bool, index == 1)
        }
        XCTAssertEqual(calendar.label, initialWeek)
    }
}
