import XCTest
import UIKit
import ObjectiveC
import Darwin

// Individual XCTest coordinate commands wait for quiescence between drags.
// Schedule this input on the test bundle's native synthesizer clock.
private enum WeekContactSequence {
    struct Drag {
        let start: CGPoint
        let end: CGPoint
        let duration: TimeInterval
        let pauseAfterLift: TimeInterval
    }

    private static func typeEncoding(_ copied: UnsafeMutablePointer<CChar>?) -> String {
        guard let copied else { return "unavailable" }
        defer { free(copied) }
        return String(String(cString: copied).drop(while: { "rnNoORV".contains($0) }))
    }

    private static func matches(_ actual: String, _ expected: String) -> Bool {
        if expected == "@" { return actual == "@" || actual.hasPrefix("@\"") }
        if expected == "@?" {
            return ["@?", "@?<v@?B@>", "@?<v@?B@\"NSError\">", "@?<vB@>", "@?<vB@\"NSError\">"].contains(actual)
        }
        return actual == expected
    }

    private static func method<Signature>(
        _ name: String, on type: AnyClass?, returns: String, arguments: [String], as signature: Signature.Type
    ) throws -> (Signature, Selector) {
        let selector = NSSelectorFromString(name)
        guard let entry = class_getInstanceMethod(type, selector) else {
            throw NSError(domain: "WeekContactSequence", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Native XCTest selector unavailable: " + name])
        }
        let types = ["@", ":"] + arguments
        let actualResult = typeEncoding(method_copyReturnType(entry))
        let actualArguments = (0..<method_getNumberOfArguments(entry)).map {
            typeEncoding(method_copyArgumentType(entry, $0))
        }
        guard matches(actualResult, returns), actualArguments.count == types.count,
              zip(actualArguments, types).allSatisfy({ matches($0.0, $0.1) }) else {
            throw NSError(domain: "WeekContactSequence", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "\(name) has result \(actualResult) and arguments \(actualArguments)",
            ])
        }
        return (unsafeBitCast(method_getImplementation(entry), to: signature), selector)
    }

    private static func allocate(_ type: AnyClass) throws -> Unmanaged<AnyObject> {
        typealias Allocate = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let (allocate, selector) = try method("alloc", on: object_getClass(type),
                                              returns: "@", arguments: [], as: Allocate.self)
        return try XCTUnwrap(allocate(type as AnyObject, selector))
    }

    static func send(_ drags: [Drag]) throws {
        typealias RecordInit = @convention(c) (AnyObject, Selector, NSString, Int64) -> Unmanaged<AnyObject>?
        typealias PathInit = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Unmanaged<AnyObject>?
        typealias Add = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        typealias Move = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Void
        typealias Lift = @convention(c) (AnyObject, Selector, Double) -> Void
        let recordType: AnyClass = try XCTUnwrap(NSClassFromString("XCSynthesizedEventRecord"))
        let pathType: AnyClass = try XCTUnwrap(NSClassFromString("XCPointerEventPath"))
        let pointArguments = ["{CGPoint=dd}", "d"]
        let (makeRecord, recordSelector) = try method("initWithName:interfaceOrientation:", on: recordType,
                                                     returns: "@", arguments: ["@", "q"], as: RecordInit.self)
        let (makePath, pathSelector) = try method("initForTouchAtPoint:offset:", on: pathType,
                                                 returns: "@", arguments: pointArguments, as: PathInit.self)
        let (add, addSelector) = try method("addPointerEventPath:", on: recordType,
                                            returns: "v", arguments: ["@"], as: Add.self)
        let (move, moveSelector) = try method("moveToPoint:atOffset:", on: pathType,
                                              returns: "v", arguments: pointArguments, as: Move.self)
        let (lift, liftSelector) = try method("liftUpAtOffset:", on: pathType,
                                              returns: "v", arguments: ["d"], as: Lift.self)
        let record = try XCTUnwrap(makeRecord(try allocate(recordType).takeUnretainedValue(), recordSelector,
                                             "Timed timetable week pulls", Int64(UIInterfaceOrientation.portrait.rawValue))).takeRetainedValue()
        var next = 0.04
        for drag in drags {
            let path = try XCTUnwrap(makePath(try allocate(pathType).takeUnretainedValue(), pathSelector,
                                             drag.start, next)).takeRetainedValue()
            let samples = max(4, Int(drag.duration / 0.02) - 2)
            for sample in 1...samples {
                let fraction = CGFloat(sample) / CGFloat(samples)
                let position = CGPoint(x: drag.start.x + (drag.end.x - drag.start.x) * fraction,
                                       y: drag.start.y + (drag.end.y - drag.start.y) * fraction)
                move(path, moveSelector, position, next + 0.02 + Double(fraction) * (drag.duration - 0.04))
            }
            lift(path, liftSelector, next + drag.duration)
            add(record, addSelector, path)
            next += drag.duration + drag.pauseAfterLift
        }

        try deliver(record)
    }

    private typealias EventSynthesizer = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    private typealias Completion = @convention(block) (ObjCBool, NSError?) -> Void
    private typealias Synthesize = @convention(c) (AnyObject, Selector, AnyObject, Completion) -> Void

    private static func simulatorEventProxy() throws -> (AnyObject, Synthesize, Selector) {
        let device = XCUIDevice.shared
        let (findSynthesizer, synthSelector) = try method("eventSynthesizer", on: object_getClass(device),
                                                         returns: "@", arguments: [], as: EventSynthesizer.self)
        guard let proxy = findSynthesizer(device, synthSelector)?.takeUnretainedValue() else {
            throw NSError(domain: "WeekContactSequence", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The simulator has no XCTest event proxy"])
        }
        let (synthesize, sendSelector) = try method("synthesizeEvent:completion:", on: object_getClass(proxy),
                                                    returns: "v", arguments: ["@", "@?"], as: Synthesize.self)
        return (proxy, synthesize, sendSelector)
    }

    private static func deliver(_ record: AnyObject) throws {
        let proxy: (AnyObject, Synthesize, Selector)
        do {
            proxy = try simulatorEventProxy()
        } catch {
            // Choose the compatible entry point before any input is sent.
            print("TAKUPOKE_WEEK_SYNTHESIS_PROXY \(error.localizedDescription)")
            typealias RecordSynthesis = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
            let (synthesize, selector) = try method("synthesizeWithError:", on: object_getClass(record),
                                                     returns: "B", arguments: ["^@"], as: RecordSynthesis.self)
            var nativeError: Unmanaged<AnyObject>?
            let delivered = withUnsafeMutablePointer(to: &nativeError) { error in
                synthesize(record, selector, UnsafeMutableRawPointer(error))
            }
            guard delivered else {
                throw (nativeError?.takeUnretainedValue() as? NSError) ?? NSError(domain: "WeekContactSequence", code: 2)
            }
            // The test still requires the app's real contacts, releases and arrivals.
            return
        }
        let (synthesizer, synthesize, sendSelector) = proxy
        let delivered = XCTestExpectation(description: "XCTest delivered all timed contacts as native events")
        var eventError: NSError?
        synthesize(synthesizer, sendSelector, record) { sent, error in
            eventError = error ?? (sent.boolValue ? nil : NSError(domain: "WeekContactSequence", code: 2))
            delivered.fulfill()
        }
        guard XCTWaiter.wait(for: [delivered], timeout: 8) == .completed else {
            throw NSError(domain: "WeekContactSequence", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The native synthesizer did not return"])
        }
        if let eventError { throw eventError }
    }
}

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
        for (title, stored) in [("オレンジ", "orange"), ("緑", "green"), ("黄色", "yellow"), ("デフォルト", "未設定"), ("青", "blue")] {
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
            } else if stored == "yellow" {
                XCTAssertGreaterThan(buttonInk[0], buttonInk[1])
                XCTAssertGreaterThan(buttonInk[1], buttonInk[2] + 0.22)
                XCTAssertLessThan(buttonInk[0], 0.64, "Light appearance must use the readable shared gold")
            } else {
                XCTAssertGreaterThan(buttonInk[2], 0.7)
                XCTAssertGreaterThan(buttonInk[2], buttonInk[0] + 0.15)
            }
            recoveryScreenshot("live-theme-" + stored)
        }
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
            return WeekContactSequence.Drag(start: start, end: end, duration: duration, pauseAfterLift: pause)
        }
        // Separate native records keep this pause on the test clock. XCTest
        // compressed idle gaps between separate touch paths in a single record.
        try WeekContactSequence.send(Array(sequence.prefix(1)))
        let firstDelivery = ProcessInfo.processInfo.systemUptime
        Thread.sleep(forTimeInterval: 0.28)
        let continuation = ProcessInfo.processInfo.systemUptime
        try WeekContactSequence.send(Array(sequence.dropFirst()))
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
