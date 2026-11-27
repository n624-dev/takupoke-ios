"""Test selection, completion checks and the shell runner without Apple tools."""
import json
import io
from contextlib import redirect_stdout
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from test_manual_input_lifecycle import block

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import release_gate
import ui_test_manifest as manifest
import app_test_project


def result_line(test, status="passed"):
    return f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).\n"


class ManifestTests(unittest.TestCase):
    def test_both_countdown_edit_routes_typecheck_with_the_current_initializer(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to type-check the app editor calls")
        source = (ROOT / "Takupoke/CountdownView.swift").read_text()
        init = block(source, "    init(automatic: CountdownAutomatic)")
        calls = [line.strip() for line in source.splitlines() if "CountdownAutomaticEditor(" in line]
        self.assertEqual(len(calls), 2)
        probe = """
struct CountdownAutomatic {
    struct Preferences { let notifications = false }
    let enabled = true
    let preferences = Preferences()
}
@propertyWrapper struct State<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    init(initialValue: Value) { wrappedValue = initialValue }
}
struct EditorModel {
    struct Library { let automatic = CountdownAutomatic() }
    let library = Library()
    var automaticProgress: (key: Int, date: Int)?
}
private struct CountdownAutomaticEditor {
    @State var automatic: CountdownAutomatic
    private let oldNotifications: Bool
INITIALIZER
}
func openFromListAndDetail(model: EditorModel) {
CALLS
}
""".replace("INITIALIZER", init).replace("CALLS", "\n".join("    _ = " + call for call in calls))
        with tempfile.TemporaryDirectory(prefix="countdown-edit-routes-") as directory:
            path = Path(directory) / "CountdownEditRoutes.swift"
            path.write_text(probe)
            subprocess.run([compiler, "-typecheck", str(path)], check=True, timeout=30)

    def test_countdown_progress_fixture_uses_matching_confirmed_source_evidence(self):
        fixture = (ROOT / "tests/ui/ApplicationFixture+Events.swift").read_text()
        progress = block(fixture, "static func seedProgress(")
        self.assertIn('arguments.contains("--countdown-progress-announced") ? 0 : 2', progress)
        self.assertIn('today.addingDays(7)', progress)
        self.assertIn('responseDataVersion: version, lastEventsCheckedAt: observed', progress)
        self.assertIn('dataVersion: version,', progress)
        self.assertIn('adoptedSourcePdfSha256: source, status: .matched, lastSuccessfulStatus: .matched', progress)
        self.assertIn('receivedAt: observed, response: status, requestedTarget: .init(saved)', progress)
        self.assertLess(progress.index('try store.save(saved)'), progress.index('try store.saveSourceStatus'))
        test = block((ROOT / "tests/ui/ApplicationChecks+Events.swift").read_text(),
                     "func testCountdownShowsProgressFromAnnouncementAndRestoresEditedLabel()")
        self.assertIn('XCTAssertFalse(progress.exists)', test)
        self.assertIn('contains("・自動")', test)
        self.assertIn('card.label.contains(label)', test)

    def test_notification_navigation_can_reset_timetable_details_from_its_own_file(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for the cross-file access check")
        timetable = ROOT / "Takupoke/TimetableView.swift"
        declaration = next(line for line in timetable.read_text().splitlines() if "func closeDetailSelections()" in line)
        function = block(timetable.read_text(), declaration)
        navigation = timetable.with_name("TimetableView+Navigation.swift").read_text()
        action = block(navigation, "    func consumeUpdateRequest()")
        call = next(line for line in action.splitlines() if "closeDetailSelections()" in line)
        with tempfile.TemporaryDirectory(prefix="timetable-notice-access-") as directory:
            root = Path(directory)
            view = root / "TimetableView.swift"
            # SwiftUI's State setters are nonmutating. The stub supplies the
            # same property semantics independently of the view framework.
            details = "\n".join(f"    var {name}: Int? {{ get {{ nil }} nonmutating set {{}} }}"
                                for name in ("selectedLesson", "selectedSpecial", "selectedChange"))
            view.write_text("struct TimetableView {\n" + details + "\n" + function + "\n}\n")
            route = root / "TimetableView+Navigation.swift"
            route.write_text("extension TimetableView {\n    func clearDetailsForNotification() {\n" + call + "\n    }\n}\n")
            subprocess.run([compiler, "-typecheck", str(view), str(route)], check=True, timeout=30)

    def test_countdown_os_trace_adds_only_fixed_stage_observation(self):
        source = (ROOT / "Takupoke/CountdownModel.swift").read_text(encoding="utf-8")
        observed = app_test_project.instrument_countdown_notification_center(source)
        for operation in ("settings", "pending", "delivered", "backoff-read", "read-back"):
            for phase in ("begin", "end"):
                self.assertEqual(observed.count(f'FixtureCITrace.mark("countdown-notice-{operation}-{phase}")'), 1)
        self.assertEqual(observed.count(app_test_project.COUNTDOWN_OBSERVED_ADD), 1)
        self.assertEqual(observed.count(app_test_project.COUNTDOWN_NATIVE_ADD), 0)
        for metric in ("authorization", "remove-pending", "read-back-total", "read-back-expected",
                       "backoff-read-total", "backoff-read-expected"):
            self.assertEqual(observed.count(f'FixtureCITrace.mark("countdown-notice-{metric}-'), 1)
        stripped = "".join(line for line in observed.splitlines(keepends=True) if "FixtureCITrace.mark" not in line)
        stripped = stripped.replace(app_test_project.COUNTDOWN_OBSERVED_ADD, app_test_project.COUNTDOWN_NATIVE_ADD)
        self.assertEqual(stripped, source)
        view = (ROOT / "Takupoke/CountdownView.swift").read_text(encoding="utf-8")
        trace = app_test_project.COUNTDOWN_TOGGLE_TRACE
        observed_view = app_test_project.instrument_countdown_notification_draft(view)
        self.assertEqual(observed_view.count(trace), 1)
        self.assertEqual(observed_view.replace(trace, ""), view)
        with self.assertRaises(AssertionError):
            app_test_project.instrument_countdown_notification_draft(view + app_test_project.COUNTDOWN_TOGGLE)

    def test_countdown_reservation_observer_forwards_exact_requests_and_only_safe_stages(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify the actual native reservation observer")
        source = (ROOT / "tests/ui/ApplicationFixture+Events.swift").read_text(encoding="utf-8")
        observe = block(source, "@MainActor static func observeNativeReservation")
        program = r'''import Foundation
struct UNCalendarNotificationTrigger {
    let date: Date?
    func nextTriggerDate() -> Date? { date }
}
final class UNNotificationRequest {
    let trigger: Any?
    init(_ date: Date?) { trigger = UNCalendarNotificationTrigger(date:date) }
}
final class UNUserNotificationCenter {
    var failure: NSError?
    var submissions = [UNNotificationRequest]()
    func add(_ request: UNNotificationRequest) async throws {
        submissions.append(request)
        if let failure { throw failure }
    }
}
@MainActor enum FixtureCITrace {
    static var stages = [String]()
    static func mark(_ stage: String) { stages.append(stage) }
}
enum SimulatorCountdownEventsFixture {
OBSERVE
}
@main struct Probe {
    @MainActor static func main() async throws {
        let center = UNUserNotificationCenter()
        let expected = Date(timeIntervalSince1970:2_000_000_000)
        let accepted = UNNotificationRequest(expected), missing = UNNotificationRequest(nil)
        let mismatched = UNNotificationRequest(expected.addingTimeInterval(60))
        try await SimulatorCountdownEventsFixture.observeNativeReservation(center,request:accepted,expected:expected)
        center.failure = NSError(domain:"UNErrorDomain",code:1,userInfo:[NSLocalizedFailureReasonErrorKey:"Source is not authorized"])
        do {
            try await SimulatorCountdownEventsFixture.observeNativeReservation(center,request:missing,expected:expected)
            preconditionFailure("Reservation error was swallowed")
        } catch let error as NSError { precondition(error.domain == "UNErrorDomain" && error.code == 1) }
        center.failure = NSError(domain:"unrelated-raw-value",code:-2)
        do {
            try await SimulatorCountdownEventsFixture.observeNativeReservation(center,request:mismatched,expected:expected)
            preconditionFailure("Reservation error was swallowed")
        } catch let error as NSError { precondition(error.domain == "unrelated-raw-value" && error.code == -2) }
        let originals = [accepted,missing,mismatched]
        precondition(center.submissions.count == originals.count)
        precondition(zip(center.submissions,originals).allSatisfy { $0 === $1 })
        let begin = "countdown-notice-reserve-begin", end = "countdown-notice-reserve-end"
        let stages = [begin, "countdown-notice-reserve-trigger-matches", "countdown-notice-reserve-accepted", end,
            begin, "countdown-notice-reserve-trigger-empty", "countdown-notice-reserve-error-un-1", "countdown-notice-reserve-source-unauthorized", end,
            begin, "countdown-notice-reserve-trigger-mismatch", "countdown-notice-reserve-error-other-n2", end]
        let enabled = ProcessInfo.processInfo.arguments.contains("--countdown-school-notices")
        precondition(FixtureCITrace.stages == (enabled ? stages : []))
    }
}
'''.replace("OBSERVE", observe)
        with tempfile.TemporaryDirectory(prefix="school-notice-observer-") as scratch:
            path = Path(scratch)
            swift = path / "Probe.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(swift),
                            "-o", str(path / "probe")], check=True, timeout=60)
            for flags in ([], ["--countdown-school-notices"]):
                subprocess.run([str(path / "probe"), *flags], check=True, timeout=15)

    def test_week_motion_observation_keeps_real_release_layout_and_animation_unchanged(self):
        source = (ROOT / "Takupoke/TimetableView+Grid.swift").read_text()
        observed = app_test_project.instrument_week_motion(source)
        self.assertNotIn("FixtureWeek", source)
        for marker, insertion in app_test_project.WEEK_MOTION_INSERTIONS:
            self.assertEqual(observed.count(insertion), 1)
            observed = observed.replace(insertion, "", 1)
            with self.assertRaises(AssertionError):
                app_test_project.instrument_week_motion(source.replace(marker, "", 1))
        self.assertEqual(observed, source)
        self.assertIn("testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable", manifest.PROBE_GROUPS["week-appearance"])
        self.assertIn("testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch", manifest.PROBE_GROUPS["week-appearance"])
        workflow = (ROOT / ".github/workflows/week-appearance-probe.yml").read_text()
        self.assertEqual(manifest.PROBE_GROUPS["yellow-contrast"],
                         ("testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch",))
        self.assertIn("week-navigation-and-yellow, yellow-contrast", workflow)
        self.assertIn("default: week-motion", workflow)
        self.assertIn("inputs.focus || 'week-motion'", workflow)
        self.assertIn("testTimetableCommonClocksAndEventOnlyWeekScale", manifest.PROBE_GROUPS["week-motion"])

        contact_file = "NativeTestContacts.swift"
        for files in (manifest.CHECK_SOURCES, manifest.MANUAL_CHECK_SOURCES):
            self.assertEqual(files.count(contact_file), 1)
        contacts = (ROOT / "tests/ui" / contact_file).read_text()
        self.assertIn("if contact.start != contact.end", contacts)
        self.assertIn('"moveToPoint:atOffset:"', contacts)
        self.assertIn('"liftUpAtOffset:"', contacts)
        self.assertEqual(contacts.count("try deliver(record)"), 1)
        generated_grid = app_test_project.instrument_week_motion(source)
        promotion = generated_grid.split("private func promote(", 1)[1].split("private func finishHeight(", 1)[0]
        self.assertLess(promotion.index("transition = nil"), promotion.index("signalHeightWindow()"))
        self.assertIn("if heightAdjustment != nil", promotion)
        swift = (ROOT / "tests/ui/ApplicationChecks+WeekAppearance.swift").read_text()
        sequence = swift.split("func testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating()", 1)[1]
        self.assertLess(sequence.index("WeekMotionSignal.heightWindow.observe("), sequence.index("sequence.prefix(1)"))
        self.assertIn("WeekMotionSignal.heightWindow.remove(observer)", sequence)
        self.assertIn("ApplicationFixture+WeekHandoff.swift", manifest.CHECK_SOURCES)
        self.assertIn("ApplicationFixture+WeekHandoff.swift", manifest.FIXTURE_SOURCES)
        self.assertLess(sequence.index("XCTWaiter.wait(for: [heightWindow]"), sequence.index("sequence.dropFirst()"))
        self.assertIn('$0.phase == "height"', sequence)
        frames = swift.split("func testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable()", 1)[1]
        self.assertLess(frames.index("WeekMotionSignal.reportReady.observe("), frames.index("NativeTestContacts.send("))
        self.assertLess(frames.index("XCTWaiter.wait(for: [reportReady]"), frames.index('app.staticTexts["fixture-week-motion"]'))
        self.assertIn("WeekMotionSignal.reportReady.remove(observer)", frames)
        self.assertIn("holdBeforeMove: 0.08, holdBeforeLift: 0.30", frames)
        self.assertIn('0.09, "Height adjustment must keep drawing frames"', frames)
        self.assertLess(frames.index("XCTWaiter.wait(for: [reportReady]"), frames.index("gridMetrics()"))
        self.assertIn('XCTAssertEqual(record["gridMetricReadsDuringMotion"] as? Int, 0,', frames)
        self.assertIn('XCTAssertEqual(record["gridGeometryWritesDuringMotion"] as? Int, 0,', frames)
        self.assertIn('XCTAssertEqual(record["weekContentBuildsAfterArrival"] as? Int, 0,', frames)
        grid_fixture = (ROOT / "tests/ui/ApplicationFixture+Grid.swift").read_text()
        self.assertLess(grid_fixture.index("if isDisplayed && !motion.isRecording"),
                        grid_fixture.index(".accessibilityValue(read())"))
        self.assertIn("FixtureWeekMotionRecorder.shared.recordGridMetricsRead()", grid_fixture)
        project_generator = (ROOT / "tools/app_test_project.py").read_text()
        self.assertIn("settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'", project_generator)

    def test_motion_fixture_leaves_detailed_geometry_to_the_sizing_checks(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify the motion fixture condition")
        fixture = (ROOT / "tests/ui/ApplicationFixture+Grid.swift").read_text(encoding="utf-8")
        active = next(line for line in fixture.splitlines() if "static let capturesDetailGeometry =" in line)
        selection = block(fixture, "nonisolated static func capturesDetailGeometry(arguments:")
        program = f'''import Foundation
@MainActor final class FixtureGridMeasurements {{
    {active}
    {selection}
}}
precondition(FixtureGridMeasurements.capturesDetailGeometry)
precondition(!FixtureGridMeasurements.capturesDetailGeometry(arguments: []))
precondition(FixtureGridMeasurements.capturesDetailGeometry(arguments: ["--grid-probe"]))
precondition(FixtureGridMeasurements.capturesDetailGeometry(arguments: ["--grid-probe", "--week-sequence-probe"]))
precondition(!FixtureGridMeasurements.capturesDetailGeometry(arguments: ["--grid-probe", "--week-motion-probe"]))
'''
        with tempfile.TemporaryDirectory(prefix="takupoke-grid-observation-") as directory:
            path = Path(directory)
            swift = path / "test.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", str(swift), "-o", str(path / "test")],
                           check=True, timeout=60)
            subprocess.run([str(path / "test"), "--grid-probe"], check=True, timeout=15)

    def test_prepared_week_content_is_lazy_and_expires_with_its_window_or_revision(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify the prepared week cache")
        source = (ROOT / "Takupoke/TimetableView+Grid.swift").read_text(encoding="utf-8")
        types = "\n".join(block(source, name) for name in (
            "@MainActor\nprivate final class WeekPageContent", "private struct WeekPage:",
            "@MainActor\nprivate final class PreparedWeekPages"))
        program = '''import Foundation
typealias SchoolDate = Int
@MainActor protocol View { associatedtype Body; var body: Body { get } }
struct AnyView: View {
    let label: String
    var body: Never { fatalError("Type erasure fixture has no render tree") }
}
''' + types + '''
@main struct Check {
    @MainActor static func main() {
        let cache = PreparedWeekPages()
        var built: [String] = []
        func build(_ revision: String) -> (SchoolDate) -> AnyView {
            { week in
                let label = "\\(week)-\\(revision)"
                built.append(label)
                return AnyView(label: label)
            }
        }
        let first = cache.pages(for: [1, 2, 3], revision: ["A"], build: build("A"))
        precondition(built.isEmpty)
        precondition(first[1].content.view().label == "2-A")
        precondition(first[1].content.view().label == "2-A")
        let same = cache.pages(for: [1, 2, 3], revision: ["A"], build: build("A"))
        precondition(same[1].content === first[1].content)
        let moved = cache.pages(for: [2, 3, 4], revision: ["A"], build: build("A"))
        precondition(moved.map(\\.id) == [2, 3, 4] && moved[0].content === first[1].content)
        let returned = cache.pages(for: [1, 2, 3], revision: ["A"], build: build("A"))
        precondition(returned[0].content !== first[0].content)
        precondition(returned[0].content.view().label == "1-A")
        let refreshed = cache.pages(for: [1, 2, 3], revision: ["B"], build: build("B"))
        precondition(refreshed[1].content !== first[1].content)
        precondition(refreshed[1].content.view().label == "2-B")
        precondition(built == ["2-A", "1-A", "2-B"])
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="takupoke-week-content-") as directory:
            root = Path(directory)
            swift = root / "check.swift"
            swift.write_text(program, encoding="utf-8")
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", str(swift), "-o", str(root / "check")],
                           check=True, timeout=60)
            subprocess.run([str(root / "check")], check=True, timeout=15)

    def test_week_column_placement_reuses_only_the_matching_size_measurement(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for the layout test")
        from test_manual_input_lifecycle import block

        source = (ROOT / "Takupoke/TimetableView+Grid.swift").read_text()
        layout = block(source, "private struct WeekColumnsLayout: Layout")
        interface = """import Foundation
struct ProposedViewSize { let width: CGFloat?; let height: CGFloat? }
enum UnitPoint { case topLeading }
protocol Layout { typealias Subviews = [Subview] }
final class Subview {
    var height: CGFloat
    var measurements = 0
    var position = CGPoint.zero
    init(_ height: CGFloat) { self.height = height }
    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        measurements += 1
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    func place(at point: CGPoint, anchor: UnitPoint, proposal: ProposedViewSize) { position = point }
}
"""
        checks = """
private let columns = WeekColumnsLayout(widths: [80,60], spacing: 2)
let views = [Subview(20), Subview(40), Subview(100), Subview(130)]
let proposal = ProposedViewSize(width: 142, height: nil)
let bounds = CGRect(x: 5, y: 7, width: 142, height: 172)
private var cache = columns.makeCache(subviews: views)
precondition(columns.sizeThatFits(proposal: proposal, subviews: views, cache: &cache) == CGSize(width:142,height:172))
columns.placeSubviews(in: bounds, proposal: proposal, subviews: views, cache: &cache)
precondition(views.allSatisfy { $0.measurements == 1 })
precondition(views[3].position == CGPoint(x:87,y:49))
views[1].height = 45
columns.placeSubviews(in: bounds, proposal: proposal, subviews: views, cache: &cache)
precondition(views.allSatisfy { $0.measurements == 2 })
precondition(views[3].position == CGPoint(x:87,y:54))
_ = columns.sizeThatFits(proposal: proposal, subviews: views, cache: &cache)
private let resized = WeekColumnsLayout(widths: [90,50], spacing: 2)
resized.placeSubviews(in: bounds, proposal: proposal, subviews: views, cache: &cache)
precondition(views.allSatisfy { $0.measurements == 4 })
precondition(views[3].position == CGPoint(x:97,y:54))
_ = resized.sizeThatFits(proposal: proposal, subviews: views, cache: &cache)
resized.placeSubviews(in: bounds, proposal: proposal, subviews: Array(views.dropLast()), cache: &cache)
precondition(views.map { $0.measurements } == [6,5,6,5])
precondition(views[2].position == CGPoint(x:5,y:29))
"""
        with tempfile.TemporaryDirectory(prefix="takupoke-week-layout-") as scratch:
            path = Path(scratch) / "main.swift"
            path.write_text(interface + layout + "\n" + checks, encoding="utf-8")
            executable = path.with_suffix("")
            subprocess.run([compiler, "-module-cache-path", scratch, str(path), "-o", str(executable)],
                           check=True, timeout=30)
            subprocess.run([str(executable)], check=True, timeout=10)

    def test_native_motion_only_invalidates_the_footer_for_horizontal_changes(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify week motion observation")
        grid = (ROOT / "Takupoke/TimetableView+Grid.swift").read_text(encoding="utf-8")
        week_model = (ROOT / "Takupoke/TimetableSchedule+Weeks.swift").read_text(encoding="utf-8")
        attrs = grid.split("private final class WeekPageMotion", 1)[0].rstrip().splitlines()[-1]
        state = "\n".join(line for line in grid.splitlines() if "var transition: Transition?" in line
                          or "var reservedHeight: CGFloat?" in line)
        update = block(grid, "private func advanceFrame(")
        setup = '''import Foundation
import Observation
typealias SchoolDate = Int
struct CADisplayLink { let timestamp: Double; let targetTimestamp: Double }
struct Transaction { var disablesAnimations = false }
func withTransaction(_ transaction: Transaction, _ work: () -> Void) {
    precondition(transaction.disablesAnimations); work()
}
final class Counter: @unchecked Sendable { var value = 0 }
'''
        probe = '''
    var reduceMotion = false
    var slideClock = WeekSlideClock()
    var lastSlideProgress: CGFloat?
    var arrivals = 0
    func adjustHeight(_ link: CADisplayLink) {}
    func settle(id: UUID) {
        precondition(transition?.id == id)
        lastSlideProgress = transition?.slideProgress
        arrivals += 1
        transition = nil
    }
    func run(reducing: Bool, direction: CGFloat) {
        reduceMotion = reducing
        let source = 2, destination = direction == 1 ? 3 : 1
        transition = Transition(source: source, destination: destination, rubber: -direction * 30,
            width: 360, direction: direction, targetHeight: 240)
        let footer = Counter(), row = Counter()
        withObservationTracking { _ = transition } onChange: { footer.value += 1 }
        withObservationTracking { _ = reservedHeight } onChange: { row.value += 1 }
        reservedHeight = 300
        precondition(footer.value == 0 && row.value == 1)
        for frame in 0..<30 where arrivals == 0 {
            let time = Double(frame) / 60
            advanceFrame(CADisplayLink(timestamp: time, targetTimestamp: time + 1.0 / 60))
        }
        precondition(arrivals == 1 && footer.value == 1 && transition == nil)
        precondition(lastSlideProgress.map { $0 > 0 && $0 < 1 } == true)
        precondition(offset(for: destination, selected: destination, viewportWidth: 360) == 0)
        precondition(opacity(for: source, selected: destination) == 0)
        precondition(opacity(for: destination, selected: destination) == 1)
    }
}
@main struct Probe {
    @MainActor static func main() {
        for reducing in [false, true] {
            for direction: CGFloat in [-1, 1] { Motion().run(reducing: reducing, direction: direction) }
        }
    }
}
'''
        motion_methods = "\n".join(block(grid, name) for name in ("func offset(for week:", "func opacity(for week:"))
        program = "\n".join((setup, block(week_model, "struct WeekSlideClock"), attrs + " final class Motion: NSObject {",
                             block(grid, "struct Transition"), state, update, motion_methods, probe))
        with tempfile.TemporaryDirectory(prefix="takupoke-week-landing-") as scratch:
            path = Path(scratch) / "check.swift"
            path.write_text(program, encoding="utf-8")
            executable = path.with_suffix("")
            # Swift 6.1.2's Linux Observation dylib references a private Core symbol.
            linker = ["-static-stdlib"] if sys.platform == "linux" else []
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library", *linker, str(path), "-o", str(executable)],
                           check=True, timeout=30)
            subprocess.run([str(executable)], check=True, timeout=10)

    def test_week_height_changes_reuse_equal_positioned_pages(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify reuse of positioned pages")
        grid = (ROOT / "Takupoke/TimetableView+Grid.swift").read_text()
        declaration = grid.split("private struct PositionedWeekPage:", 1)[1].split("    var body:", 1)[0]
        page = "private struct PositionedWeekPage:" + declaration.replace("View, Equatable", "Equatable", 1) + "}"
        canvas = block(grid, "private struct WeekPagesCanvas: View")
        self.assertIn("WeekPagesLayout(currentIndex: currentIndex, reservedHeight: motion.reservedHeight)", canvas)
        self.assertIn("acceptsTouches: isDisplayed && motion.transition == nil)\n                    .equatable()", canvas)
        timetable = (ROOT / "Takupoke/TimetableView.swift").read_text()
        main_body = block(timetable, "var body: some View")
        self.assertEqual(main_body.count("weekBounds"), 1)
        self.assertIn("weekSection(within: bounds)", main_body)
        controls_source = (ROOT / "Takupoke/TimetableView+WeekSection.swift").read_text()
        self.assertNotIn("weekBounds", controls_source)
        controls = block(controls_source, "fileprivate func weekControls(")
        self.assertEqual(controls.count("weekStart"), 1)
        self.assertEqual(controls.count("bounds.contains("), 2)
        self.assertIn("bounds: bounds, revision: revision", block(grid, "func weekGrid("))
        self.assertIn("weekBounds.contains(target)", block(grid, "func weekGrid("))
        program = """import Foundation
struct WeekPage: Equatable { let date: Int; let revision: Int }
final class WeekPageMotion { var reservedHeight: CGFloat = 240 }
PAGE
private let motion = WeekPageMotion()
private func rendered(date: Int = 3, revision: Int = 1, offset: CGFloat = 0, opacity: Double = 1,
                      displayed: Bool = true, acceptsTouches: Bool = true,
                      using owner: WeekPageMotion = motion) -> PositionedWeekPage {
    PositionedWeekPage(page: WeekPage(date: date, revision: revision), motion: owner,
                       horizontalOffset: offset, opacity: opacity, isDisplayed: displayed, acceptsTouches: acceptsTouches)
}
private let landed = rendered()
motion.reservedHeight = 315
precondition(landed == rendered())
precondition(landed != rendered(date: 4) && landed != rendered(revision: 2))
precondition(landed != rendered(offset: -50) && landed != rendered(opacity: 0.5))
precondition(landed != rendered(displayed: false) && landed != rendered(acceptsTouches: false))
precondition(landed != rendered(using: WeekPageMotion()))
""".replace("PAGE", page)
        with tempfile.TemporaryDirectory(prefix="takupoke-positioned-week-") as scratch:
            source = Path(scratch) / "main.swift"
            source.write_text(program, encoding="utf-8")
            executable = source.with_suffix("")
            subprocess.run([compiler, str(source), "-o", str(executable)], check=True, timeout=30)
            subprocess.run([str(executable)], check=True, timeout=10)

    def test_generated_week_selection_initialization_respects_actor_isolation(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for generated initializer type checking")
        from test_manual_input_lifecycle import block

        timetable = ROOT / "Takupoke/TimetableView.swift"
        navigation = timetable.with_name("TimetableView+Navigation.swift")
        generated = {}
        for path in (timetable, navigation):
            original = path.read_text()
            sites = app_test_project.TIMETABLE_DATE_SITES[path.name]
            generated[path.name] = app_test_project.instrument_timetable_date(original, path.name)
            self.assertEqual(generated[path.name].count("SimulatorSelectionFixture.day"), len(sites))
            with self.assertRaisesRegex(AssertionError, "Unexpected timetable date sites"):
                app_test_project.instrument_timetable_date(original + "let unreviewed = SchoolDate.today()\n", path.name)
            for site in sites:
                with self.assertRaisesRegex(AssertionError, "Timetable date insertion point missing"):
                    app_test_project.instrument_timetable_date(original.replace(site, " " + site, 1), path.name)

        source = generated[timetable.name]
        model = block(source, "@Observable\nfinal class TimetableWeekSelection")
        fields = re.findall(r"^    @State (?:private )?(var \w+ = .*SimulatorSelectionFixture\.day.*)$",
                            source, re.MULTILINE)
        actions = re.findall(r"^        ((?:let current|today) = .*SimulatorSelectionFixture\.day.*)$",
                             generated[navigation.name], re.MULTILINE)
        self.assertEqual(len(fields), 3)
        self.assertEqual(len(actions), 2)
        probe = """import Foundation
import Observation

enum SimulatorAuxiliaryStoreFixture {
    static let fixedDayEnabled = false
    static let day = SchoolDate(iso8601: "2032-04-05")!
}
enum SimulatorEventsYearFixture {
    static let enabled = false
    static let day = SchoolDate(iso8601: "2032-04-12")!
}
@MainActor enum SimulatorSelectionFixture {
    static var day: SchoolDate { SchoolDate(iso8601: "2032-04-19")! }
}

""" + model + """
@MainActor private struct RenderedTimetable {
""" + "\n".join(fields) + """
    mutating func readDates() {
""" + "\n".join(actions) + """
        _ = current
    }
}
"""
        with tempfile.TemporaryDirectory(prefix="week-selection-isolation-") as scratch:
            path = Path(scratch) / "main.swift"
            path.write_text(probe)
            result = subprocess.run(
                [compiler, "-typecheck", "-swift-version", "5", "-strict-concurrency=complete", "-warnings-as-errors",
                 "-module-cache-path", str(Path(scratch) / "modules"), str(timetable.with_name("SchoolDate.swift")), str(path)],
                capture_output=True, text=True, timeout=45,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_phases_partition_every_shard_and_focused_selection_without_duplicates(self):
        for tests in (*manifest.SHARDS.values(), manifest.selected_tests("all"),
                      manifest.NOTIFICATION_PROBE_TESTS, manifest.CONTROL_PROBE_TESTS,
                      *manifest.PROBE_GROUPS.values(), (manifest.SYSTEM_SIZE_TEST,)):
            with self.subTest(tests=tests):
                notifications = manifest.phase_tests(tests, "notifications")
                remaining = manifest.phase_tests(tests, "remaining")
                self.assertEqual(set(notifications) & set(remaining), set())
                self.assertEqual(sorted(notifications + remaining), sorted(tests))
                self.assertEqual(len(notifications + remaining), len(tests))
                self.assertEqual(manifest.phase_tests(tests, "all"), tuple(tests))
                for test in notifications:
                    self.assertIn(test, manifest.NATIVE_NOTIFICATION_CASES)
                for test in remaining:
                    self.assertNotIn(test, manifest.NATIVE_NOTIFICATION_CASES)
                phases = manifest.runner_phases(tests)
                partition = tuple(test for phase in phases for test in manifest.phase_tests(tests, phase))
                self.assertEqual(sorted(partition), sorted(tests))
                self.assertEqual(len(partition), len(tests))
                ordered = tuple(test for phase in phases if phase != "notifications"
                                for test in sorted(manifest.phase_tests(tests, phase)))
                expected = tuple(sorted(remaining))
                if "week-motion" in phases:
                    self.assertEqual(phases[0], "week-motion")
                    self.assertEqual(manifest.phase_tests(tests, "week-motion"), (manifest.WEEK_MOTION_TEST,))
                    expected = (manifest.WEEK_MOTION_TEST,) + tuple(test for test in expected if test != manifest.WEEK_MOTION_TEST)
                self.assertEqual(ordered, expected)
                for phase, test in (("settings", manifest.SETTINGS_TEST),
                                    ("voiceover", manifest.VOICEOVER_TEST)):
                    if test in tests:
                        self.assertIn(phase, phases)
                        self.assertEqual(manifest.phase_tests(tests, phase), (test,))
        self.assertEqual(manifest.runner_phases(manifest.SHARDS["A"]), ("remaining", "notifications"))
        self.assertEqual(manifest.phase_tests(manifest.SHARDS["B"], "notifications"),
                         ("testNotificationControlsAndAppearance", manifest.COUNTDOWN_NOTIFICATION_TEST))
        self.assertEqual(manifest.runner_phases(manifest.PROBE_GROUPS["input-delivery"]),
                         ("settings", "voiceover"))
        with self.assertRaisesRegex(ValueError, "Unknown"):
            manifest.phase_tests(manifest.SHARDS["B"], "unregistered")

    def test_merged_card_probe_starts_with_only_the_original_case(self):
        cases = manifest.PROBE_GROUPS["merged-lesson-cards"]
        self.assertEqual(cases, ("testMergedCardsFromAllSources",))
        self.assertEqual(manifest.runner_phases(cases), ("remaining",))
        self.assertIn(cases[0], manifest.SHARDS["A"])
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        self.assertIn("- merged-lesson-cards\n", workflow)

    def test_week_card_contact_uses_one_observed_enabled_button_and_requires_the_real_detail(self):
        source = (ROOT / "tests/ui/ApplicationChecks+Timetable.swift").read_text()
        readiness = source.split("private func readyWeekCard(", 1)[1].split("private func tapWeekCard(", 1)[0]
        self.assertEqual(readiness.count("self.app.snapshot()"), 1)
        self.assertIn(".intersection(grids[0].frame)", readiness)
        self.assertIn("matches($0.label) && $0.isEnabled", readiness)
        self.assertIn("ObservedScreenGeometry.contains($0.frame, in: viewport", readiness)
        self.assertIn("buttons.filter({ $0.label == observed.label }).count == 1", readiness)
        self.assertNotIn(".isHittable", readiness)
        touch = source.split("private func tapWeekCard(", 1)[1].split("func testMergedCardsFromAllSources(", 1)[0]
        self.assertIn("CGPoint(x: frame.midX, y: frame.midY)", touch)
        self.assertEqual(touch.count("NativeTestContacts.send("), 1)
        self.assertIn("start: center, end: center", touch)
        self.assertIn("try tapWeekCard(first)\n        XCTAssertTrue(app.staticTexts[\"架空教員A\"]", source)
        self.assertIn("try tapWeekCard(card)\n            let title", source)

    def test_both_suites_use_the_same_native_tab_contact(self):
        common = "NativeTabActivation.swift"
        for files in (manifest.CHECK_SOURCES, manifest.MANUAL_CHECK_SOURCES):
            self.assertEqual(files[1:].count(common), 1)
        folder = ROOT / "tests/ui"
        app = (folder / "ApplicationChecks+Navigation.swift").read_text()
        manual = (folder / "ManualAssistanceChecks.swift").read_text()
        self.assertIn("guard pressNativeTabIcon(title, in: app, timeout: 45)", app)
        self.assertIn('guard pressNativeTabIcon("設定", in: app, timeout: nativeStateTimeout)', manual)
        self.assertIn("return current.exists && current.isSelected", app)
        self.assertIn("current.count==1 && current[0].isSelected", manual)
        contact = (folder / common).read_text()
        self.assertEqual(contact.count("app.snapshot()"), 1)
        self.assertIn("button.isEnabled", contact)
        self.assertNotIn("allElementsBoundByAccessibilityElement", contact)
        self.assertIn("icons.count == 1", contact)
        self.assertIn("ObservedScreenGeometry.contains(iconFrame, in: buttonFrame", contact)
        self.assertIn("ObservedScreenGeometry.contains(iconFrame, in: barFrame", contact)
        self.assertEqual(contact.count("NativeTestContacts.send("), 1)
        self.assertIn("CGPoint(x: iconFrame.midX, y: iconFrame.midY)", contact)
        self.assertIn("NativeTestContacts.send([.init(start: contact, end: contact, duration: 0.1, pauseAfterLift: 0)]", contact)
        self.assertIn("app.state == .runningForeground", contact)
        self.assertNotIn(".coordinate(", contact)
        self.assertNotIn(".tap()", contact)

    def test_retained_row_checks_the_current_visible_screen_before_and_after_relaunch(self):
        source = (ROOT / "tests/ui/ApplicationChecks+Changes.swift").read_text()
        helper, case = source.split("private func assertRetainedChangeRows(", 1)[1].split(
            "func testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch(", 1)
        self.assertIn('let retainedIsVisible = visible(app.staticTexts["変更後、架空科目C"]).exists', helper)
        self.assertIn('let excludedExists = app.staticTexts["変更後、架空除外科目B"].exists', helper)
        self.assertIn(r'visible=\(retainedIsVisible) excluded=\(!excludedExists)', helper)
        self.assertIn('XCTAssertTrue(retainedIsVisible)', helper)
        self.assertIn('XCTAssertFalse(excludedExists)', helper)
        before, after = case.split('app.launchArguments.removeAll { $0 == "--reset-fixture" }', 1)
        self.assertIn('assertRetainedChangeRows(stage: "after-apply")', before)
        self.assertIn('assertRetainedChangeRows(stage: "after-relaunch")', after)
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        long_runner = "(matrix.probe_case == 'rows' || (matrix.ios == 26 && matrix.probe_case == 'yellow-contrast'))"
        self.assertIn("timeout-minutes: ${{ " + long_runner + " && 45 || 30 }}", workflow)
        self.assertIn("TKPK_RELAUNCH_RUNNER_SECONDS: ${{ " + long_runner + " && 2400 || 1440 }}", workflow)
        self.assertIn('--timeout "$TKPK_RELAUNCH_RUNNER_SECONDS" --cleanup-grace 120', workflow)

    def test_row_apply_uses_the_current_toolbar_and_still_requires_the_real_confirmation(self):
        source = (ROOT / "tests/ui/ApplicationChecks+Changes.swift").read_text()
        helper, case = source.split("private func tapRowReviewApply(", 1)[1].split(
            "func testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch(", 1)
        self.assertEqual(helper.count("navigation.snapshot()"), 1)
        self.assertIn("if candidates.count > 1 { return true }", helper)
        self.assertIn("button.isEnabled, ObservedScreenGeometry.contains(button.frame, in: bar.frame", helper)
        self.assertIn("XCTWaiter.wait(for: [ready], timeout: 10)", helper)
        self.assertEqual(helper.count("NativeTestContacts.send("), 1)
        self.assertEqual(case.count("tapRowReviewApply(in: review)"), 3)
        self.assertIn('let alert = app.alerts["個人修正を反映しますか？"]', case)
        self.assertIn('alert.buttons["キャンセル"].tap()', case)
        self.assertEqual(case.count('alert.buttons["反映する"].tap()'), 2)

    def test_toolbar_tap_checks_one_current_native_button(self):
        source = (ROOT / "tests/ui/ApplicationChecks+Navigation.swift").read_text()
        toolbar = source.split("    func tapToolbar(", 1)[1].split("    func tapSetupNext(", 1)[0]
        self.assertIn("navigation.waitForExistence(timeout: 10)", toolbar)
        self.assertIn("navigation.buttons.matching", toolbar)
        self.assertIn("if buttons.count > 1 { return true }", toolbar)
        self.assertEqual(toolbar.count("button.snapshot()"), 1)
        self.assertIn("guard let button = buttons.first, ProcessInfo.processInfo.systemUptime < deadline,", toolbar)
        self.assertEqual(toolbar.count("navigation.frame"), 1)
        self.assertIn("snapshot.elementType == .button", toolbar)
        self.assertIn("ObservedScreenGeometry.contains(frame, in: barFrame, scale: scale)", toolbar)
        self.assertIn("snapshot.isEnabled", toolbar)
        self.assertIn("button.isHittable", toolbar)
        self.assertIn("XCTWaiter.wait(for: [ready], timeout: 10)", toolbar)
        self.assertIn("object: nil", toolbar)
        self.assertEqual(toolbar.count("button.tap()"), 1)
        self.assertNotIn("contained(button", toolbar)
        self.assertNotIn("app.debugDescription", toolbar)

    def test_split_sources_are_registered_in_the_selected_target_only(self):
        project = {'rootObject': 'project', 'objects': {
            'project': {'mainGroup': 'group'}, 'group': {'children': []},
            'app': {'buildPhases': ['app-sources']},
            'test': {'buildPhases': ['test-sources']},
            'app-sources': {'isa': 'PBXSourcesBuildPhase', 'files': []},
            'test-sources': {'isa': 'PBXSourcesBuildPhase', 'files': []},
        }}
        paths = [ROOT / 'tests/ui' / name for name in manifest.CHECK_SOURCES[1:]]
        app_test_project.add_swift_sources(project, 'test', paths, '9B')
        support = ROOT / 'tests/Support/ObservedScreenGeometry.swift'
        app_test_project.add_swift_sources(project, 'test', [support], '9C')
        objects = project['objects']
        registered = [objects[objects[key]['fileRef']]['path']
                      for key in objects['test-sources']['files']]
        self.assertEqual(registered, [str(path) for path in paths] + [str(support)])
        self.assertEqual(objects['app-sources']['files'], [])
        self.assertEqual(len(objects['group']['children']), len(paths) + 1)
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            app_test_project.add_swift_sources(project, 'test', paths, '9B')

    def test_unregistered_split_file_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='takupoke-ui-source-check-') as directory:
            root = Path(directory)
            folder = root / 'tests/ui'
            folder.mkdir(parents=True)
            for name in manifest.CHECK_SOURCES:
                shutil.copyfile(ROOT / 'tests/ui' / name, folder / name)
            self.assertEqual(manifest.check_source(root), manifest.check_source())
            (folder / 'ApplicationChecks+Unregistered.swift').write_text('func testForgotten() {}')
            with self.assertRaisesRegex(ValueError, 'registered'):
                manifest.check_source(root)

    def test_manual_split_registers_all_helpers_and_refuses_unknown_files(self):
        with tempfile.TemporaryDirectory(prefix='takupoke-manual-source-check-') as directory:
            root = Path(directory)
            folder = root / 'tests/ui'
            folder.mkdir(parents=True)
            for name in manifest.MANUAL_CHECK_SOURCES:
                shutil.copyfile(ROOT / 'tests/ui' / name, folder / name)
            self.assertEqual(manifest.manual_check_source(root), manifest.manual_check_source())
            (folder / 'ManualAssistanceChecks+Unregistered.swift').write_text('func testMissing() {}')
            with self.assertRaisesRegex(ValueError, 'registered'):
                manifest.manual_check_source(root)

    def test_network_rewrite_preserves_standard_xlsx_identifiers_only(self):
        source = (ROOT / "Takupoke/XLSXReader.swift").read_text(encoding="utf-8")
        rewritten = app_test_project.rewrite_network_urls(source)
        for namespace in (
            "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
            "http://schemas.openxmlformats.org/package/2006/relationships",
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        ):
            self.assertIn('"' + namespace + '"', rewritten)
        endpoints = 'let url = "https://files.example.invalid/source"; let other = "http://schemas.openxmlformats.org/spreadsheetml/2006/main?fetch=1"'
        changed = app_test_project.rewrite_network_urls(endpoints)
        self.assertEqual(changed.count('"https://fixture.example.test"'), 2)
        self.assertNotIn("files.example.invalid", changed)
        self.assertNotIn("fetch=1", changed)

    def test_service_status_fixture_changes_only_the_network_endpoint(self):
        original = (ROOT / "Takupoke/ServiceStatusModel.swift").read_text()
        rewritten = app_test_project.rewrite_network_urls(original)
        generated = app_test_project.instrument_service_status_endpoint(rewritten)
        self.assertNotIn("status.n624.jp", generated)
        self.assertEqual(generated.count('.appendingPathComponent("service-status")'), 1)
        self.assertIn('static let pageURL = URL(string: "https://fixture.example.test")!', generated)
        self.assertEqual(generated.replace('.appendingPathComponent("service-status")', ''), rewritten)
        marker = 'nonisolated static let endpoint = URL(string: "https://fixture.example.test")!'
        for invalid in (rewritten.replace(marker, ''), rewritten + marker):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_service_status_endpoint(invalid)
        self.assertEqual(len(re.findall(r'\b(?:let|var) \w+ = URLSessionConfiguration\.(?:ephemeral|default)', generated)), 1)

    def test_status_launch_does_not_inherit_a_previous_events_fixture(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the real fixture storage reset")
        source = (ROOT / "tests/ui/ApplicationFixture+Events.swift").read_text(encoding="utf-8")
        app = (ROOT / "tests/ui/ApplicationFixture.swift").read_text(encoding="utf-8")
        seed = app.split("private static func seed()", 1)[1]
        self.assertLess(seed.index("SimulatorEventsCacheFixture.resetForIsolatedLaunch"), seed.index("let onlyDistributedData"))
        self.assertIn('FixtureCITrace.mark(clearedEvents ? "status-fixture-prior-cache-cleared" : "status-fixture-no-prior-cache")', seed)
        checks = '''
let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let cache = base.appendingPathComponent("SchoolEventsAPI", isDirectory: true)
let previous = cache.appendingPathComponent("events-2032.json")
let other = base.appendingPathComponent("kept.json")
let bytes = Data("entirely fictional".utf8)
try bytes.write(to: other)
let launches: [([String], Bool)] = [
    (["--reset-fixture"], true),
    (["--only-distributed-data"], true),
    (["--countdown-calendar"], true),
    (["--only-distributed-data", "--reset-fixture"], false),
    (["--countdown-calendar", "--reset-fixture"], false),
]
for (arguments, keepsPublicEvents) in launches {
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    try bytes.write(to: previous)
    let removed = try SimulatorEventsCacheFixture.resetForIsolatedLaunch(base, arguments: arguments)
    precondition(removed != keepsPublicEvents)
    precondition(FileManager.default.fileExists(atPath: previous.path) == keepsPublicEvents)
    let unrelated = try Data(contentsOf: other)
    precondition(unrelated == bytes)
}
let absent = try SimulatorEventsCacheFixture.resetForIsolatedLaunch(base, arguments: ["--only-distributed-data", "--reset-fixture"])
precondition(!absent)
'''
        with tempfile.TemporaryDirectory(prefix="takupoke-status-fixture-") as scratch:
            root = Path(scratch)
            swift = root / "reset.swift"
            swift.write_text("import Foundation\nenum SimulatorEventsCacheFixture {\n"
                             + block(source, "static func resetForIsolatedLaunch(") + "\n}\n" + checks, encoding="utf-8")
            executable = root / "reset"
            subprocess.run([compiler, "-swift-version", "5", str(swift), "-o", str(executable)],
                           check=True, timeout=30)
            subprocess.run([str(executable), scratch], check=True, timeout=10)

    def test_ai_switch_probe_preserves_production_setter_and_rejects_marker_drift(self):
        launch = (ROOT / "tests/ui/ApplicationChecks.swift").read_text(encoding="utf-8")
        self.assertIn('"testSettingsAccountDataAndFileDetails": ["--ai-feature-probe", "--fixture-input-trace"]', launch)
        source = (ROOT / "Takupoke/SettingsView.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_ai_switch(source)
        self.assertNotIn("FixtureLaunchDiagnostics", source)
        self.assertEqual(generated.count(app_test_project.AI_SWITCH_BEFORE), 1)
        self.assertEqual(generated.count(app_test_project.AI_SWITCH_AFTER), 1)
        self.assertEqual(generated.replace(app_test_project.AI_SWITCH_BEFORE, "", 1)
                         .replace(app_test_project.AI_SWITCH_AFTER, "", 1), source)
        marker = 'useAiFeatures = $0; LocalAIFeaturePolicy.setEnabled($0)'
        for changed in (source.replace(marker, ""), source + "\n" + marker):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_ai_switch(changed)

    def test_notification_switch_trace_preserves_setters_and_rejects_marker_drift(self):
        source = (ROOT / "Takupoke/NotificationSettingsView.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_notification_switch(source)
        self.assertNotIn("FixtureLaunchDiagnostics", source)
        self.assertEqual(generated.count(app_test_project.NOTIFICATION_BINDING_TRACE), 2)
        self.assertEqual(generated.replace(app_test_project.NOTIFICATION_BINDING_TRACE, ""), source)
        for changed in (source.replace("set: { value in", "set: { other in", 1), source + source):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_notification_switch(changed)

    def test_notification_readiness_probe_observes_os_without_granting_or_saving(self):
        launch = (ROOT / "tests/ui/ApplicationChecks.swift").read_text()
        self.assertIn('"testNotificationControlsAndAppearance": ["--theme-probe", "--notification-permission-probe", "--fixture-input-trace"]', launch)
        source = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_notification_permission(source)
        self.assertNotIn("FixtureNotificationAuthorization", source)
        for operation in ("await readCurrentNotificationSettings()", "center.getNotificationSettings"):
            self.assertEqual(generated.count(operation), source.count(operation))
        restored = generated
        for insertion in (app_test_project.NOTIFICATION_PERMISSION_BEGIN,
                          app_test_project.NOTIFICATION_PERMISSION_END,
                          app_test_project.NOTIFICATION_PERMISSION_SKIPPED,
                          app_test_project.NOTIFICATION_NATIVE_REQUEST,
                          app_test_project.NOTIFICATION_NATIVE_CALLBACK,
                          app_test_project.NOTIFICATION_AUTH_REQUEST,
                          app_test_project.NOTIFICATION_AUTH_RETURNED,
                          app_test_project.NOTIFICATION_AUTH_CALLBACK):
            self.assertEqual(restored.count(insertion), 1)
            restored = restored.replace(insertion, "", 1)
        self.assertEqual(restored.count(app_test_project.NOTIFICATION_PERMISSION_READ), 1)
        restored = restored.replace(app_test_project.NOTIFICATION_PERMISSION_READ,
                                    app_test_project.NOTIFICATION_PERMISSION_READ_ORIGINAL, 1)
        self.assertEqual(restored, source)
        for marker in ("center.getNotificationSettings { settings in",
                       "callback(settings)",
                       "center.requestAuthorization(options: [.alert, .sound]) { granted, error in"):
            for changed in (source.replace(marker, ""), source + marker + "\n"):
                with self.assertRaises(AssertionError):
                    app_test_project.instrument_notification_permission(changed)
        self.assertIn("settings?.authorizationStatus.rawValue", generated)
        self.assertIn("cancelled: Task.isCancelled", generated)
        for changed in (source.replace("func checkPermission()", "func otherPermission()", 1),
                        source + source):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_notification_permission(changed)
        probe = (ROOT / "tests/ui/ApplicationFixture+NotificationPermission.swift").read_text(encoding="utf-8")
        self.assertIn("ApplicationFixture+NotificationPermission.swift", manifest.FIXTURE_SOURCES)
        self.assertIn("UIApplication.shared.applicationState.rawValue", probe)
        self.assertIn('"notification-settings-unavailable"', probe)
        recorder = (ROOT / "tests/ui/ApplicationFixture.swift").read_text(encoding="utf-8")
        self.assertIn('"notification-settings-not-requested"', recorder)
        self.assertIn('"notification-auth-request"', recorder)
        self.assertIn('"notification-auth-callback"', recorder)
        self.assertIn("@Environment(\\.scenePhase)", probe)
        self.assertIn(".onDisappear { permission.invalidate() }", probe)
        self.assertNotRegex(probe, r"notificationSettings\(|getNotificationSettings|requestAuthorization|setEnabled|UserDefaults\.standard\.set\(")
        workflow = (ROOT / ".github/workflows/application-relaunch-native-probe.yml").read_text()
        self.assertNotIn("TKPK_NOTIFICATION_SETTINGS_READ", workflow)
        checks = (ROOT / "tests/ui/ApplicationChecks+Notifications.swift").read_text(encoding="utf-8")
        self.assertIn('"notRequested"', checks)
        self.assertIn('changes=false;saved=false;specials=false;savedSpecials=false;', checks)
        activate_switch = 'tapNativeSwitch(toggle, thumbDragDuration: thumbDragDuration)'
        self.assertEqual(len(re.findall(r"\btapNativeSwitch\s*\(\s*toggle\b", checks)), 1)
        self.assertEqual(checks.count(activate_switch), 1)
        before = checks.index('"NOTIFICATION_SWITCH before row=')
        single_contact = checks.index(activate_switch, before)
        self.assertNotIn('recoveryScreenshot(', checks[before:single_contact])
        self.assertIn('recoveryScreenshot("notification-switch-unresolved")', checks)
        self.assertIn('recoveryScreenshot("notification-system-unresolved", systemScreen: true)', checks)
        activation = checks.split(activate_switch, 1)[1]
        pending = activation.split('guard didEnable else {', 1)[0]
        self.assertNotIn("touch.tap()", pending)
        self.assertEqual(pending.count("allow.tap()"), 1)
        self.assertEqual(pending.count("XCTWaiter.wait"), 1)
        self.assertIn('!permissionHandled', pending)
        self.assertLess(pending.index('permissionHandled = true'), pending.index('allow.tap()'))
        self.assertNotIn("for _ in", pending)
        self.assertIn('(toggle.value as? String) == "1"', pending)
        self.assertIn('state.hasPrefix("requesting=false;changes=true;saved=true;")', pending)
        self.assertIn('Date().addingTimeInterval(45)', pending)
        self.assertIn('deadline.timeIntervalSinceNow', pending)
        self.assertIn('self.permissionAllowButton(predicate)', pending)
        self.assertIn('Date() <= deadline', pending)
        self.assertNotIn('state.hasSuffix(";application=', pending)
        alert = checks.split('private func permissionAllowButton(', 1)[1].split(
            'private func openNotificationSettings()', 1)[0]
        self.assertIn('guard current.count == 1', alert)
        self.assertIn('allow.count == 1', alert)
        self.assertIn('button.isEnabled, button.isHittable', alert)
        self.assertIn('current[0].frame.contains(button.frame)', alert)
        self.assertNotIn('addUIInterruptionMonitor', pending)
        navigation = (ROOT / "tests/ui/ApplicationChecks+Navigation.swift").read_text()
        switch = navigation.split("func tapNativeSwitch(", 1)[1]
        self.assertNotIn(".tap()", switch)
        self.assertEqual(switch.count(".press(forDuration: 0.05)"), 1)
        drag, short_contact = switch.split("if dragThumb {", 1)[1].split("            return", 1)
        self.assertEqual(drag.count(".press(forDuration:"), 1)
        self.assertIn("thenDragTo: finish, withVelocity: .slow, thenHoldForDuration: 0", drag)
        self.assertEqual(short_contact.count(".press(forDuration:"), 1)
        self.assertEqual(switch.count(".press(forDuration:"), 2)
        timed_drag = switch.split("if let thumbDragDuration {", 1)[1].split("if dragThumb {", 1)[0]
        self.assertEqual(timed_drag.count("NativeTestContacts.send("), 1)
        self.assertIn('frame.minX + frame.width * (state == "0" ? 0.75 : 0.25)', timed_drag)
        self.assertIn("start: point, end: stop, duration: thumbDragDuration", timed_drag)
        self.assertIn("XCTFail", timed_drag)
        rows = (ROOT / "tests/ui/ApplicationChecks+Changes.swift").read_text()
        # Checkmarks change the selection for a pending bulk action. Only
        # persisted per-row settings use native switch gestures.
        selection = rows.split("func selectRows(", 1)[1].split("        openChanges()", 1)[0]
        self.assertIn("app.collectionViews.buttons.matching(identifier: identifier)", selection)
        self.assertIn("visible(matches.element, navigation: page)", selection)
        self.assertIn("button.identifier == identifier, button.isEnabled, !button.isSelected", selection)
        self.assertNotIn("matches.count", selection)
        self.assertEqual(selection.count("NativeTestContacts.send("), 1)
        self.assertIn("return current.isSelected", selection)
        self.assertIn("XCTWaiter.wait(for: [changed], timeout: 15)", selection)
        self.assertIn('selection: "change-select-all"', rows)
        self.assertIn('selectRows("change-select-row-', rows)
        expected_controls = ["excluded", "derive", "blankRowExcluded"]
        self.assertCountEqual(re.findall(
            r"tapNativeSwitch\(\s*(\w+)\s*,[^)]*?thumbDragDuration:\s*0\.33\s*\)", rows), expected_controls)
        self.assertEqual(rows.count("tapNativeSwitch("), len(expected_controls))
        self.assertNotIn(".press(forDuration: 0.1)", switch)
        self.assertNotIn(".doubleTap(", switch)
        self.assertNotIn("row.tap()", switch)
        self.assertNotIn("control.tap()", switch)
        self.assertIn('state == "0" ? 0.25 : 0.75', switch)
        self.assertIn('control.coordinate(withNormalizedOffset: CGVector(', switch)
        self.assertNotIn('app.coordinate(', switch)
        self.assertNotIn("for _ in", switch)
        self.assertIn("let observed = try? control.snapshot()", switch)
        self.assertIn("observed.elementType == .switch", switch)
        self.assertIn("let frame = observed.frame", switch)
        self.assertIn("outer.contains(frame), observed.isEnabled", switch)
        self.assertIn("let state = observed.value as? String", switch)
        self.assertIn("rowState == state, control.isHittable", switch)
        self.assertIn("row.isEnabled, row.isHittable", switch)
        self.assertIn("contentViewport(navigation: navigation).contains(outer)", switch)
        self.assertIn("page.contains(outer)", switch)
        self.assertIn("rowState == state", switch)
        settings = (ROOT / "tests/ui/ApplicationChecks+Settings.swift").read_text()
        self.assertIn("func changeAI(to value: String, dragThumb: Bool = false)", settings)
        self.assertIn('for value in ["1", "0", "1"] { changeAI(to: value) }', settings)
        self.assertEqual(settings.count("tapNativeSwitch(ai, dragThumb: dragThumb, thumbDragDuration: dragThumb ? nil : 0.33)"), 1)
        self.assertEqual(settings.count('changeAI(to: "0", dragThumb: true)'), 1)
        context = settings.split("private func linkContextAction(", 1)[1].split(
            "func testLegalDocumentsAndIndividualLicenses", 1)[0]
        self.assertEqual(context.count("link.press(forDuration: 2)"), 1)
        self.assertNotIn("coordinate(", context)
        self.assertIn("rowFrame.minY >= barFrame.maxY", context)
        self.assertIn("rowFrame.maxY <= tabsFrame.minY", context)

    def test_actual_loopback_browser_input_serves_only_fictional_page_and_closes(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for the actual loopback fixture")
        import http.client
        import select
        import socket
        import threading
        import time
        from urllib.parse import urlsplit
        source = (ROOT / "tests/ui/ApplicationChecks+Settings.swift").read_text()
        helper = source.split("// BEGIN PURE LOOPBACK BROWSER FIXTURE\n", 1)[1].split(
            "// END PURE LOOPBACK BROWSER FIXTURE", 1)[0]
        program = helper + r'''
@main struct Probe {
    static func main() throws {
        let fixture = try LoopbackBrowserFixture()
        FileHandle.standardOutput.write(Data((fixture.url.absoluteString + "\n").utf8))
        _ = readLine()
        fixture.stop()
        FileHandle.standardOutput.write(Data("stopped\n".utf8))
        Thread.sleep(forTimeInterval: 3)
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="loopback-browser-controls-") as scratch:
            root = Path(scratch)
            swift, binary = root / "main.swift", root / "probe"
            swift.write_text(program)
            built = subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                                    "-module-cache-path", str(root / "modules"), str(swift), "-o", str(binary)],
                                   capture_output=True, text=True, timeout=60)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            process = subprocess.Popen([str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, text=True)
            idle = None
            try:
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], "Fixture did not bind")
                parsed = urlsplit(process.stdout.readline().strip())
                self.assertEqual((parsed.scheme, parsed.hostname, parsed.path),
                                 ("http", "127.0.0.1", "/fictional-link"))
                self.assertTrue(parsed.port and 0 < parsed.port < 65536)
                # The same owner serves both sides of an app relaunch.
                for method, path, status in (("GET", parsed.path, 200), ("GET", parsed.path, 200),
                                             ("GET", "/../private-document", 404), ("POST", parsed.path, 405)):
                    connection = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=4)
                    try:
                        connection.request(method, path)
                        response = connection.getresponse()
                        body = response.read()
                        self.assertEqual(response.status, status)
                        self.assertEqual(int(response.getheader("Content-Length")), len(body))
                        self.assertEqual(response.getheader("Cache-Control"), "no-store")
                        self.assertEqual("架空リンクAの検証ページ" in body.decode(), status == 200)
                    finally:
                        connection.close()
                # A preconnected client with partial headers must not block the real page.
                with socket.create_connection((parsed.hostname, parsed.port), timeout=4) as first:
                    first.sendall(b"GET /fictional-link HTTP/1.1\r\nHost: 127.0.0.1\r\n")
                    second = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=4)
                    try:
                        second.request("GET", parsed.path)
                        ready = second.getresponse()
                        expected = ready.read()
                        self.assertEqual(ready.status, 200)
                        self.assertIn("架空リンクAの検証ページ", expected.decode())
                    finally:
                        second.close()
                    first.sendall(b"\r\n")
                    with http.client.HTTPResponse(first) as earlier:
                        earlier.begin()
                        self.assertEqual(earlier.status, 200)
                        self.assertEqual(earlier.read(), expected)
                # A client sending partial headers cannot extend the total deadline.
                trickle = socket.create_connection((parsed.hostname, parsed.port), timeout=3)
                stop_sending = threading.Event()
                def send_partial_header():
                    while not stop_sending.is_set():
                        try:
                            trickle.sendall(b"G")
                        except OSError:
                            return
                        stop_sending.wait(0.1)
                sender = threading.Thread(target=send_partial_header, daemon=True)
                sender.start()
                try:
                    trickle.settimeout(2.8)
                    try:
                        closed_in_time = trickle.recv(1) == b""
                    except ConnectionResetError:
                        closed_in_time = True
                    self.assertTrue(closed_in_time)
                finally:
                    stop_sending.set()
                    trickle.close()
                    sender.join(timeout=1)
                    self.assertFalse(sender.is_alive())
                # An unfinished local client must not keep the listener alive.
                idle = socket.create_connection((parsed.hostname, parsed.port), timeout=3)
                time.sleep(0.05)
                process.stdin.write("stop\n")
                process.stdin.flush()
                self.assertEqual(process.stdout.readline().strip(), "stopped")
                deadline = time.monotonic() + 2.8
                closed = False
                while time.monotonic() < deadline:
                    try:
                        with socket.create_connection((parsed.hostname, parsed.port), timeout=0.1):
                            pass
                    except OSError:
                        closed = True
                        break
                    time.sleep(0.02)
                self.assertTrue(closed, "Owned loopback listener survived stop")
                self.assertIsNone(process.poll(), "Closure must not depend on process exit")
                process.stdin.close()
                process.wait(timeout=6)
                self.assertEqual(process.returncode, 0, process.stderr.read())
            finally:
                if idle is not None:
                    idle.close()
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
                process.stdout.close()
                process.stderr.close()

    def test_browser_fixture_changes_only_native_network_input_and_rejects_other_urls(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for actual generated browser input validation")
        import resource
        from test_manual_input_lifecycle import block
        original = (ROOT / "Takupoke/SafariLinkView.swift").read_text()
        generated = app_test_project.instrument_browser_fixture(original)
        method = block(generated, "func makeUIViewController(")
        url_validator = block(generated, "static func fixtureBrowserURL(")
        window_observer = block(generated, "private static func observeFixtureBrowserWindow(")
        self.assertIn("[weak controller]", window_observer)
        self.assertIn("controller?.viewIfLoaded?.window", window_observer)
        self.assertNotRegex(window_observer, r"loadView|present\(|dismiss\(|didCompleteInitialLoad")
        cover = (ROOT / "Takupoke/LinksView.swift").read_text()
        instrumented_cover = app_test_project.instrument_browser_cover(cover)
        cover_trace = app_test_project.BROWSER_COVER_TRACE
        self.assertEqual(instrumented_cover.count(cover_trace), 1)
        self.assertEqual(instrumented_cover.replace(cover_trace, ""), cover)
        with self.assertRaises(AssertionError):
            app_test_project.instrument_browser_cover(cover + app_test_project.BROWSER_COVER)
        fixture = (ROOT / "tests/ui/ApplicationFixture.swift").read_text()
        prewarming = block(fixture, "private enum FixtureBrowserPrewarming")
        startup = (
            '.task {\n'
            '                    FixtureLaunchDiagnostics.record("root-task-enter")\n'
            '                    FixtureBrowserPrewarming.startIfNeeded()\n'
            '                    let data = ApplicationData.shared'
        )
        self.assertEqual(fixture.count(startup), 1)
        self.assertEqual(fixture.count("FixtureBrowserPrewarming.startIfNeeded()"), 1)
        finish = block(generated, "func safariViewControllerDidFinish(")
        trace = '            FixtureLaunchDiagnostics.record("browser-finish-received")\n'
        self.assertEqual(finish.count(trace), 1)
        self.assertEqual(finish.replace(trace, ""), block(original, "func safariViewControllerDidFinish("))
        self.assertLess(finish.index(trace), finish.index("onDismiss()"))
        with self.assertRaises(AssertionError):
            app_test_project.instrument_browser_fixture(original.replace("safariViewControllerDidFinish", "otherCallback"))
        program = r'''import Foundation
final class SFSafariViewController {
    struct PrewarmingToken {}
    struct View { let window: Int? = nil }
    static var prewarmed: [URL] = []
    let url: URL
    var delegate: NSObject?
    let viewIfLoaded: View? = nil
    init(url: URL) { self.url = url }
    static func prewarmConnections(to urls: [URL]) -> PrewarmingToken {
        prewarmed += urls
        return PrewarmingToken()
    }
}
enum FixtureCITrace { static func mark(_ stage: String) {} }
enum FixtureLaunchDiagnostics {
    static var stages: [String] = []
    static func record(_ stage: String) { stages.append(stage) }
}
struct Context { let coordinator = NSObject() }
@MainActor
struct SafariLinkView {
    let url = URL(string: ProcessInfo.processInfo.environment["ORIGINAL_BROWSER_URL"] ?? "https://fixture.example.test")!
VALIDATOR
WINDOW_OBSERVER
METHOD
}
@MainActor
PREWARMING
@main struct Probe {
    @MainActor
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        let prewarm = !arguments.contains("--factory-only")
        if prewarm {
            FixtureBrowserPrewarming.startIfNeeded()
            FixtureBrowserPrewarming.startIfNeeded()
        }
        if arguments.contains("--prewarm-only") { return }
        let controller = SafariLinkView().makeUIViewController(context: Context())
        let hasPrewarmed = prewarm && arguments.contains("--loopback-browser-fixture")
        precondition(SFSafariViewController.prewarmed == (hasPrewarmed ? [controller.url] : []))
        let expectedStages = (hasPrewarmed ? ["browser-prewarm-requested"] : []) + ["browser-controller-created"]
        precondition(FixtureLaunchDiagnostics.stages == expectedStages)
        print(controller.url.absoluteString)
    }
}
'''.replace("VALIDATOR", url_validator).replace("METHOD", method).replace("PREWARMING", prewarming).replace(
            "WINDOW_OBSERVER", window_observer)
        with self.assertRaises(AssertionError):
            app_test_project.instrument_browser_fixture(original.replace(
                "SFSafariViewController(url: url)", "SFSafariViewController(url: anotherURL)"))
        with tempfile.TemporaryDirectory(prefix="browser-input-boundary-") as scratch:
            root = Path(scratch)
            path, binary = root / "main.swift", root / "probe"
            path.write_text(program)
            built = subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                                    "-module-cache-path", str(root / "modules"), str(path), "-o", str(binary)],
                                   capture_output=True, text=True, timeout=60)
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            def run(raw, fixture=True, original=None, mode=None):
                environment = os.environ.copy()
                environment.pop("TKPK_BROWSER_FIXTURE_URL", None)
                environment.pop("ORIGINAL_BROWSER_URL", None)
                if original is not None:
                    environment["ORIGINAL_BROWSER_URL"] = original
                if raw is not None:
                    environment["TKPK_BROWSER_FIXTURE_URL"] = raw
                arguments = [str(binary)]
                if fixture:
                    arguments.append("--loopback-browser-fixture")
                if mode is not None:
                    arguments.append(mode)
                return subprocess.run(arguments, env=environment, cwd=root, capture_output=True, text=True, timeout=10,
                                      preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_CORE, (0, 0)))
            valid = "http://127.0.0.1:23456/fictional-link"
            actual = run(valid)
            self.assertEqual(actual.returncode, 0, actual.stderr)
            self.assertEqual(actual.stdout.strip(), valid)
            unchanged = run(valid, fixture=False)
            self.assertEqual(unchanged.returncode, 0, unchanged.stderr)
            self.assertEqual(unchanged.stdout.strip(), "https://fixture.example.test")
            self.assertEqual(run(valid, mode="--factory-only").returncode, 0)
            self.assertEqual(run(valid, mode="--prewarm-only").returncode, 0)
            self.assertNotEqual(run(valid, original="https://wrong.fixture.test", mode="--factory-only").returncode, 0)
            for invalid in (None, "https://127.0.0.1:23456/fictional-link",
                            "http://localhost:23456/fictional-link", "http://127.0.0.1/fictional-link",
                            "http://127.0.0.1:0/fictional-link", "http://127.0.0.1:23456/other",
                            valid + "?q=1", valid + "#fragment", "http://u:p@127.0.0.1:23456/fictional-link"):
                with self.subTest(url=invalid):
                    for mode in ("--factory-only", "--prewarm-only"):
                        self.assertNotEqual(run(invalid, mode=mode).returncode, 0, mode)

    def test_link_menu_observes_one_press_before_diagnostics_and_never_accepts_timeout(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to execute the actual link-menu helper")
        from test_manual_input_lifecycle import block
        source = (ROOT / "tests/ui/ApplicationChecks+Settings.swift").read_text()
        method = block(source, "private func linkContextAction(")
        program = '''import Foundation
enum Trace { static var events=[String](); static var failures=0 }
struct NSPredicate { init(format: String, _ value: String) {} }
func XCTFail(_ message: String) { Trace.failures += 1 }
final class Elements {
    let element: XCUIElement
    init(_ element: XCUIElement) { self.element=element }
    subscript(_ key: String) -> XCUIElement { element }
    var firstMatch: XCUIElement { element }
    func matching(_ predicate: NSPredicate) -> Elements { self }
}
final class XCUIElement {
    let id: String
    var frame: CGRect, isEnabled=true, isHittable=true, present=true
    init(_ id: String, _ frame: CGRect) { self.id=id; self.frame=frame }
    var staticTexts: Elements { Elements(XCUIElement("text", CGRect(x:1,y:21,width:10,height:5))) }
    func waitForExistence(timeout: TimeInterval) -> Bool {
        Trace.events.append("wait:\\(id):\\(timeout)"); return present
    }
    func press(forDuration: TimeInterval) {
        precondition(forDuration==2); Trace.events.append("press")
    }
    func tap() { Trace.events.append("tap:"+id) }
}
final class XCUIApplication {
    let system: Bool
    init(bundleIdentifier: String = "fixture") { system=bundleIdentifier=="com.apple.springboard" }
    let action=XCUIElement("action",CGRect(x:1,y:30,width:20,height:10))
    var navigationBars: Elements { Elements(XCUIElement("bar",CGRect(x:0,y:0,width:100,height:10))) }
    var tabBars: Elements { Elements(XCUIElement("tabs",CGRect(x:0,y:90,width:100,height:10))) }
    var buttons: Elements { Elements(action) }
    var state: State { State() }; struct State { var rawValue=4 }
    var debugDescription: String {
        Trace.events.append(system ? "snapshot-system" : "snapshot-app"); return "fictional tree"
    }
}
final class Probe {
    let app=XCUIApplication()
    func recoveryScreenshot(_ name: String, systemScreen: Bool = false) {
        Trace.events.append(systemScreen ? "image-system" : "image-app")
    }
    func contained(_ element: XCUIElement, in frame: CGRect) -> Bool { frame.contains(element.frame) }
METHOD
    func run(_ row: XCUIElement) { linkContextAction(row,title:"fictional action") }
}
@main struct Main {
    static func main() {
        // Pure dependency doubles verify control flow, not UIKit input delivery.
        for present in [true,false] {
            Trace.events=[]; Trace.failures=0
            let probe=Probe(),row=XCUIElement("row",CGRect(x:0,y:20,width:100,height:20))
            probe.app.action.present=present
            probe.run(row)
            let events=Trace.events,press=events.firstIndex(of:"press")!
            precondition(events.filter { $0=="press" }.count==1)
            precondition(events[press+1]=="wait:action:45.0")
            if present {
                precondition(events.last=="tap:action" && Trace.failures==0)
                precondition(!events.contains("snapshot-app") && !events.contains("snapshot-system"))
                precondition(events.filter { $0=="image-app" }.count==1)
            } else {
                precondition(!events.contains("tap:action") && Trace.failures==1)
                precondition(events.contains("image-system") && events.contains("snapshot-system"))
            }
        }
        for disabledTarget in [false,true] {
            Trace.events=[]; Trace.failures=0
            let probe=Probe(),row=XCUIElement("row",CGRect(x:0,y:20,width:100,height:20))
            if disabledTarget { probe.app.action.isHittable=false } else { row.isHittable=false }
            probe.run(row)
            precondition(!Trace.events.contains("tap:action") && Trace.failures==1)
            precondition(Trace.events.contains("press")==disabledTarget)
        }
    }
}
'''.replace("METHOD", method)
        with tempfile.TemporaryDirectory(prefix="link-menu-order-") as directory:
            path = Path(directory)
            (path / "probe.swift").write_text(program)
            subprocess.run([compiler, "-swift-version", "5", "-parse-as-library",
                            "-module-cache-path", str(path / "modules"), str(path / "probe.swift"),
                            "-o", str(path / "probe")], check=True)
            subprocess.run([str(path / "probe")], check=True)

    def test_retention_observation_preserves_the_real_automatic_recovery(self):
        source = (ROOT / "Takupoke/ContentView.swift").read_text(encoding="utf-8")
        self.assertNotIn("FixtureLaunchDiagnostics", source)
        generated = app_test_project.instrument_retention_recovery(source)
        self.assertEqual(generated.count(app_test_project.RETENTION_RECOVERY_TRACE), 1)
        self.assertEqual(generated.replace(app_test_project.RETENTION_RECOVERY_TRACE, "", 1), source)
        for changed in (source.replace('.onChange(of: dataReady)', '.onChange(of: retentionFailure)'), source + source):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_retention_recovery(changed)

        notifications = (ROOT / "Takupoke/ScheduleNotifications.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_retention_notification_reads(notifications)
        for stage in ("pending", "delivered"):
            for phase in ("request", "callback"):
                self.assertEqual(generated.count(f'FixtureCITrace.mark("retention-notice-{stage}-{phase}-\\(fixtureRetentionRead)")'), 1)
        for original, observed in app_test_project.retention_notice_read_insertions():
            self.assertEqual(generated.count(observed), 1)
            self.assertIn('callback(requests)', observed)
            generated = generated.replace(observed, original, 1)
            for changed in (notifications.replace(original, ""), notifications + original):
                with self.assertRaises(AssertionError):
                    app_test_project.instrument_retention_notification_reads(changed)
        self.assertEqual(generated, notifications)
        fixture = (ROOT / "tests/ui/ApplicationFixture.swift").read_text(encoding="utf-8")
        readiness = fixture.split("struct SimulatorRetentionProofView:", 1)[1].split("private final class FixtureYearInputObservation", 1)[0]
        self.assertIn('accessibilityIdentifier("fixture-retention-proof")', readiness)
        self.assertIn('accessibilityIdentifier("fixture-retention-bytes")', readiness)
        self.assertNotRegex(readiness, r"UNUserNotificationCenter|pendingNotificationRequests|deliveredNotifications|requestAuthorization|removePending|removeDelivered|Task\.sleep")
        launcher = (ROOT / "tests/ui/ApplicationChecks.swift").read_text(encoding="utf-8")
        setup = launcher.split('if name.contains("testRetentionMarkerRecoversAutomaticallyAndPreservesOriginals")', 1)[1].split('override func tearDown', 1)[0]
        self.assertLess(setup.index('launchReady(waitForReadyMarker: false)'), setup.index('launchReady()'))
        self.assertNotIn('保存期間の管理情報を復旧', launcher)
        case = (ROOT / "tests/ui/ApplicationChecks+Settings.swift").read_text(encoding="utf-8")
        recovery = case.split("func testRetentionMarkerRecoversAutomaticallyAndPreservesOriginals()", 1)[1].split("func testSettingsAccountDataAndFileDetails()", 1)[0]
        self.assertIn('notice.waitForExistence(timeout: 45)', recovery)
        self.assertLess(recovery.index('notice.buttons["閉じる"].tap()'), recovery.index('notice.waitForNonExistence(timeout: 10)'))
        self.assertLess(recovery.index('notice.waitForNonExistence(timeout: 10)'), recovery.index('app.staticTexts["fixture-ready"]'))
        self.assertIn('marker=1;old=0;prefs=1;public=1;original=1;archive=1', recovery)
        self.assertLess(recovery.index('let fingerprints'), recovery.index('app.terminate()'))
        self.assertIn('XCTAssertFalse(app.alerts["保存期間の復旧"].exists)', recovery)

    def test_owned_launch_trace_filters_other_content_and_refuses_symlinks_and_large_files(self):
        runner = (ROOT / "tools/test-app-ui.sh").read_text(encoding="utf-8")
        collector = runner.split("<<'PY_TRACE'\n", 1)[1].split("\nPY_TRACE", 1)[0]
        allowed = "TAKUPOKE_AI_SWITCH pid=123 time=1791534293.0 phase=before requested=1 stored=0"
        lifecycle = "TAKUPOKE_LIFECYCLE pid=123 time=1791534293.0 stage=application-ready"
        query = lifecycle.replace("application-ready", "notification-settings-enter")
        binding = lifecycle.replace("application-ready", "notification-on-binding")
        callbacks = "".join(lifecycle.replace("application-ready", stage) + "\n" for stage in (
            "notification-native-request", "notification-native-callback",
            "notification-auth-request", "notification-auth-callback", "notification-auth-returned",
            "notification-auth-error", "notification-auth-granted", "notification-auth-denied",
            "browser-prewarm-requested", "browser-controller-created", "browser-load-success", "browser-load-failure", "browser-finish-received",
            "notification-settings-not-requested", "retention-recovery-action",
            "retention-dialog-on", "retention-dialog-off", "year-input-observer-installed",
            "year-edit-began", "year-edit-ended", "year-edit-changed",
            "year-keyboard-will-show", "year-keyboard-did-show",
            "year-keyboard-will-hide", "year-keyboard-did-hide"))
        removed = "TAKUPOKE_HIT_PATH pid=123 touch=UIView~UISwitch thumb=UIView~UISwitch opposite=UIView~UISwitch"
        with tempfile.TemporaryDirectory(prefix="takupoke-launch-collector-") as directory:
            root = Path(directory)
            owned = root / "tmp/takupoke-fictional-launch-owned.log"
            owned.parent.mkdir()
            def collect():
                output = io.StringIO()
                response = subprocess.CompletedProcess([], 0, stdout=str(root) + "\n")
                with patch.object(subprocess, "run", return_value=response) as call, \
                     patch.object(sys, "argv", ["collector", "owned-simulator"]), redirect_stdout(output):
                    exec(compile(collector, "owned-trace-collector", "exec"), {})
                self.assertEqual(call.call_args.args[0], [
                    "xcrun", "simctl", "get_app_container", "owned-simulator",
                    "jp.n624.takupoke.app-checks", "data"])
                return output.getvalue()
            owned.write_text(allowed + "\n" + lifecycle + "\n" + query + "\n" + binding + "\n" + callbacks + removed +
                "\n架空の診断対象外本文\n" +
                allowed.replace("requested=1", "requested=架空の本文") + "\n",
                encoding="utf-8")
            self.assertEqual(collect(), allowed + "\n" + lifecycle + "\n" + query + "\n" + binding + "\n" + callbacks)
            owned.write_bytes(b"x" * 65537)
            self.assertEqual(collect(), "TAKUPOKE_LIFECYCLE capture-missing-or-limited\n")
            owned.unlink()
            other = root / "other-owned.txt"
            other.write_text(allowed, encoding="utf-8")
            owned.symlink_to(other)
            self.assertEqual(collect(), "TAKUPOKE_LIFECYCLE capture-missing-or-limited\n")

    def test_picker_completion_rejects_missing_failed_skipped_duplicate_and_unknown_cases(self):
        runner = (ROOT / "tools/test-picker-ui.sh").read_text(encoding="utf-8")
        program = runner.split("<<'PY_PICKER'\n", 1)[1].split("\nPY_PICKER", 1)[0]
        names = ("testInstructionSurroundMatchesFilesBackground", "testReselectionWithMissingAppearanceReturn", "testReselectionThroughActualButtons")
        def row(name, status="passed"):
            identity={'case':'-[PickerTapChecks.MaterialPickerTapChecks '+name+']',
                      'udid':'00000000-0000-0000-0000-000000000001','runtime':'27.0.0',
                      'simulatorCompileTarget':True,'pid':123}
            return ('TAKUPOKE_UI_EXECUTION_IDENTITY '+json.dumps(identity)+'\n'+
                    f"Test Case '-[PickerTapChecks.MaterialPickerTapChecks {name}]' {status} (1.0 seconds).\n")
        complete = "".join(row(name) for name in names)
        with tempfile.TemporaryDirectory() as scratch:
            log = Path(scratch) / "picker.log"
            cases = [(complete, True), ("", False), (row(names[0]), False),
                     (complete + row(names[0]), False), (complete + row("testUnknown"), False),
                     (complete.replace(row(names[0]), row(names[0], "failed")), False),
                     (complete.replace(row(names[0]), row(names[0], "skipped")), False)]
            for text, accepted in cases:
                log.write_text(text, encoding="utf-8")
                result = subprocess.run([sys.executable, "-c", program, str(log),
                    '00000000-0000-0000-0000-000000000001','com.apple.CoreSimulator.SimRuntime.iOS-27-0'],
                    capture_output=True, text=True,cwd=ROOT)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

    def test_event_cache_probe_changes_only_automatic_startup_in_isolated_copy(self):
        source = (ROOT / "Takupoke/SchoolEventsModel.swift").read_text(encoding="utf-8")
        self.assertNotIn("--events-cache-", source)
        generated = app_test_project.instrument_events_cache(source)
        insertion = generated[len(source.split('    func refreshAtStartup() {')[0]):].split('        loadIfNeeded()', 2)
        self.assertIn('"--events-cache-corrupt"', insertion[0])
        self.assertIn('"--events-cache-probe"', insertion[0])
        self.assertIn('SimulatorEventsYearFixture.enabled', insertion[0])
        self.assertIn('return', insertion[1])
        # Actual manual fetch, response validation, persistence and background
        # refresh remain byte-for-byte identical; no fabricated model readiness.
        self.assertEqual(source.split('    func fetch(year: Int) {', 1)[1],
                         generated.split('    func fetch(year: Int) {', 1)[1])

    def test_native_ocr_probe_preserves_actual_multiline_confidence_guard(self):
        source = (ROOT / "Takupoke/RecoveryVisionCapture.swift").read_text(encoding="utf-8")
        recognition = (ROOT / "Takupoke/PDFRecoveryRecognition.swift").read_text(encoding="utf-8")
        assessment = (ROOT / "Takupoke/RecoveryOCRAcquisition.swift").read_text(encoding="utf-8")
        self.assertNotIn("--recovery-ocr-probe", source)
        generated = app_test_project.instrument_native_ocr(source)
        probe = app_test_project.NATIVE_OCR_DIAGNOSTIC
        self.assertEqual(generated.count(probe), 1)
        self.assertEqual(generated.replace(probe, "", 1), source)
        self.assertNotIn("--recovery-ocr-probe", recognition)
        generator=(ROOT / "tools/app_test_project.py").read_text(encoding="utf-8")
        self.assertIn("if path.name == 'RecoveryVisionCapture.swift':\n            text = instrument_native_ocr(text)", generator)
        marker='                lines.append(try captureLine(line, order: lines.count, hierarchy: false))'
        for changed in (source.replace(marker, ""), source+"\n"+marker):
            with self.assertRaises(AssertionError): app_test_project.instrument_native_ocr(changed)
        self.assertIn("SYNTHETIC_NATIVE_OCR", probe)
        self.assertIn("let captured = lines.last?.candidates.first", probe)
        self.assertIn("$0.lineRange", probe)
        self.assertIn("$0.observationRange", probe)
        self.assertNotIn("topCandidates(", probe)
        self.assertNotRegex(probe, r"\b(?:lines|candidates|characters)\.(?:append|remove|sort)")
        acquire = recognition.split("static func acquire(", 1)[1].split("private static func snapshotHash(", 1)[0]
        for retained in (
                "for candidate in line.topCandidates(5) {",
                "let text = candidate.string",
                "candidate.boundingBox(for: start..<end)",
                "characters.append(RecoveryOCRCharacter(text: characterText, range: range))",
                "lineRange: wholeRange, observationRange:observationRange",
                "lines.append(try captureLine(line, order: lines.count, hierarchy: false))",
                "nativeDocumentCount: observations.count, lines: lines, captureComplete: true"):
            self.assertIn(retained, source)
        self.assertLess(generated.index("lines.append(try captureLine(line"), generated.index("SYNTHETIC_NATIVE_OCR"))
        self.assertLess(generated.index("SYNTHETIC_NATIVE_OCR"), generated.index("var tables ="))
        self.assertIn("hierarchy: true", source)
        for retained in ("for number in required {", "RecoveryVisionCapture.page(", "requiredOCRPages: required, pages: output"):
            self.assertIn(retained, acquire)
        self.assertNotIn("0.85", acquire)
        self.assertNotIn(".assess(", acquire)

        # Confidence still rejects nonfinite/out-of-range candidates. Only original
        # top-one confidence controls the unchanged inclusive .85 direct gate.
        assess = assessment.split("func assess(", 1)[1]
        guard = assess.split("guard !candidate.text.isEmpty,", 1)[1].split("else", 1)[0]
        self.assertIn("candidate.confidence.isFinite", guard)
        self.assertIn("(0...1).contains(candidate.confidence)", guard)
        self.assertIn("pages.count == requiredOCRPages.count", assess)
        self.assertIn(r"pages.map(\.page) == requiredOCRPages", assess)
        self.assertLess(assess.index("guard page.captureComplete"), assess.index("candidate.confidence.isFinite"))
        self.assertIn("let top1 = line.candidates[0]", assess)
        self.assertIn("if top1.confidence < 0.85 { low[page.page, default: []].append(order) }", assess)
        self.assertIn(r"lowConfidenceNativeOrders.values.allSatisfy(\.isEmpty)", assessment)
        strict = recognition.split("func strictLayouts(", 1)[1].split("private func makeLayouts(", 1)[0]
        self.assertLess(strict.index("acquisition.strictAssessment(check: check)"), strict.index("guard assessment.directLayoutsAllowed"))
        self.assertLess(strict.index("guard assessment.directLayoutsAllowed"), strict.index("return try makeLayouts(check: check)"))
        self.assertIn("return try await acquire(url, only: only, check: check).strictLayouts(check: check)", recognition)

    def test_all_source_tests_are_assigned_once_and_both_os_checks_are_required(self):
        manifest.validate_source(manifest.check_source())
        self.assertEqual(len(manifest.selected_tests("all")), 45)
        self.assertIn("testStatusScreenUsesPublicResourcesAndDataRoutes", manifest.SHARDS["A"])
        self.assertIn(manifest.SCHOOL_COUNTDOWN_NOTIFICATION_TEST, manifest.SHARDS["A"])
        self.assertIn(manifest.COUNTDOWN_DELETE_TEST, manifest.SHARDS["A"])
        self.assertIn("testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent", manifest.SHARDS["B"])
        self.assertIn("testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors", manifest.SHARDS["B"])
        self.assertIn("testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups", manifest.SHARDS["B"])
        self.assertIn("testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch", manifest.SHARDS["B"])
        self.assertIn("testPreparedWeeksMoveContinuouslyAndKeepTheirHeadersStable", manifest.SHARDS["B"])
        self.assertIn("testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating", manifest.SHARDS["A"])
        self.assertIn("testConsecutiveWeekPullsTrackOverlappingContactsWithoutRepeating",
                      manifest.PROBE_GROUPS["week-navigation-and-yellow"])
        self.assertIn("testChangedRoomInHomeWeekAndList", manifest.SHARDS["A"])
        self.assertIn("testRetentionMarkerRecoversAutomaticallyAndPreservesOriginals", manifest.SHARDS["A"])
        self.assertIn("testFirstFailedSpecialDocumentsWarnOnHomeAndWeekAndOpenTheirDetails", manifest.SHARDS["A"])
        self.assertIn("testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover", manifest.SHARDS["A"])
        self.assertTrue(all(manifest.SHARDS[shard] for shard in ("A", "B")))
        self.assertFalse(set(manifest.SHARDS["A"]) & set(manifest.SHARDS["B"]))
        self.assertEqual(release_gate.REQUIRED, manifest.ALL_UI_REQUIRED_JOBS | {"Distribution tests", "Native PDF and recovery tests"})
        self.assertIn(manifest.SYSTEM_SIZE_TEST, manifest.SHARDS["B"])

    def test_missing_obsolete_or_duplicate_source_tests_fail(self):
        source = manifest.check_source()
        for altered in (source + "\nfunc testNewCase() {}",
                        source.replace("testMergedCardsFromAllSources", "testRenamedCase"),
                        source + "\nfunc testMergedCardsFromAllSources() {}"):
            with self.subTest(source=altered[-45:]), self.assertRaises(ValueError):
                manifest.validate_source(altered)

    def test_overlapping_manifest_is_rejected(self):
        with patch.dict(manifest.SHARDS, {"B": manifest.SHARDS["B"] + manifest.SHARDS["A"][:1]}):
            with self.assertRaisesRegex(ValueError, "duplicate tests"):
                manifest.validate_source(manifest.check_source())

    def test_passed_results_with_only_the_declared_voiceover_exception(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                expected = manifest.selected_tests(shard)
                log = "unrelated Xcode output\n" + "".join(result_line(
                    test, "skipped" if ios == 26 and test == manifest.VOICEOVER_TEST else "passed"
                ) for test in expected)
                manifest.validate_results(log, expected, ios)

    def test_empty_missing_extra_and_duplicate_results_fail(self):
        expected = manifest.selected_tests("A")
        log = "".join(result_line(test) for test in expected)
        for altered in ("", log.replace(result_line(expected[0]), ""),
                        log + result_line("testUnexpected"), log + result_line(expected[0])):
            with self.subTest(log=altered[-80:]), self.assertRaises(ValueError):
                manifest.validate_results(altered, expected, 27)

    def test_failure_and_unexpected_skip_fail(self):
        for test, ios, status in ((manifest.SYSTEM_SIZE_TEST, 26, "skipped"),
                                   (manifest.SYSTEM_SIZE_TEST, 27, "failed"),
                                   (manifest.VOICEOVER_TEST, 27, "skipped"),
                                   (manifest.VOICEOVER_TEST, 26, "passed")):
            with self.subTest(test=test, ios=ios, status=status), self.assertRaises(ValueError):
                manifest.validate_results(result_line(test, status), (test,), ios)

    def test_workflow_matrix_matches_gate_and_publish_follows_gate(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text(encoding="utf-8")
        simulator = workflow.split("  simulator-27-a:\n", 1)[1].split("  manual-27:\n", 1)[0]
        entries = re.findall(r"- ios: (26|27)\n\s+shard: ([AB])", simulator)
        self.assertEqual(len(entries), 4)
        self.assertEqual({f"Application iOS {ios} UI {shard}" for ios, shard in entries},
                         manifest.REQUIRED_JOBS)
        self.assertIn("name: Application iOS ${{ matrix.ios }} UI ${{ matrix.shard }}", simulator)
        self.assertIn("TKPK_UI_SHARD: ${{ matrix.shard }}", simulator)
        release = workflow.split("  release:\n", 1)[1]
        dependency = re.search(r"^    needs: \[([^\]]+)\]$", release, re.MULTILINE)
        self.assertIsNotNone(dependency)
        self.assertEqual({name.strip() for name in dependency.group(1).split(",")},
                         {"checks", "native-parsing", "simulator-27-a", "simulator-27-b",
                          "simulator-26-a", "simulator-26-b", "manual-27", "manual-26"})
        self.assertIn("actions: read", release)
        self.assertLess(release.index("tools/release_gate.py"), release.index("tools/publish.py"))
        jobs = dict(re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)",
                               workflow, re.MULTILINE | re.DOTALL))
        self.assertNotIn("TKPK_SIMULATOR_FRONTEND", workflow.split("jobs:\n", 1)[0])
        self.assertNotIn("TKPK_SIMULATOR_FRONTEND", jobs["checks"])
        self.assertIn("Xcode_26.6.app", jobs["native-parsing"])
        for job in ("build-check", "release"):
            self.assertIn("TKPK_EXPECTED_IOS_SDK: '27.2'", jobs[job])
            self.assertIn("DEVELOPER_DIR: /Applications/Xcode_27.2.app/Contents/Developer", jobs[job])
            self.assertIn("TKPK_SIMULATOR_FRONTEND: headless", jobs[job])

    def test_apple_validation_lanes_can_start_after_distribution_checks(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text()
        jobs = dict(re.findall(r"^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)",
                               workflow, re.MULTILINE | re.DOTALL))
        for shard in ("a", "b"):
            with self.subTest(shard=shard):
                first = jobs[f"simulator-27-{shard}"]
                second = jobs[f"simulator-26-{shard}"]
                self.assertIn("    needs: checks\n", first)
                self.assertIn("    needs: checks\n", second)
                self.assertIsNone(re.search(r"^    if:", first + second, re.MULTILINE))
                self.assertNotIn("continue-on-error", first + second)
                for ios, block in ((27, first), (26, second)):
                    self.assertIn(f"- ios: {ios}\n            shard: {shard.upper()}", block)
                    self.assertIn("bash tools/test-app-ui.sh", block)
                    self.assertIn("--runner-log", block)
                    self.assertIn("TKPK_EXPECTED_IOS_SDK: '27.2'", block)
                    self.assertIn(f"TKPK_SIMULATOR_FRONTEND: {'gui' if ios == 26 else 'headless'}", block)
                self.assertIn("runner: xcode-27", second)
                self.assertIn("developer: /Applications/Xcode_27.2.app/Contents/Developer", second)
                prepare = "python3 -B tools/prepare-ios26-runtime.py"
                self.assertIn(prepare, second)
                self.assertLess(second.index(prepare), second.index("bash tools/test-app-ui.sh"))
                self.assertIn("run: " + prepare + " --hold-export\n", second)
                cleanup = "run: " + prepare + " --cleanup-export\n"
                self.assertIn("if: always()\n        " + cleanup, second)
                self.assertLess(second.index("bash tools/test-app-ui.sh"), second.index(cleanup))
        for lane in ("native-parsing", "manual-26", "manual-27"):
            with self.subTest(lane=lane):
                self.assertIn("    needs: checks\n", jobs[lane])
                self.assertNotIn("continue-on-error", jobs[lane])

    def test_manual_matrix_requires_every_unchanged_case_on_both_os_separately(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text(encoding="utf-8")
        manual = workflow.split("  manual-27:\n", 1)[1].split("  build-check:\n", 1)[0]
        self.assertIn("ios: [27]", manual)
        self.assertIn("ios: [26]", manual)
        cases = re.findall(r"^          - (test\w+)$", manual, re.MULTILINE)
        self.assertEqual(cases, list(manifest.MANUAL_CASES) * 2)
        declared = re.findall(r"\bfunc\s+(test\w+)\s*\(", manifest.manual_check_source())
        self.assertCountEqual(cases, declared * 2)
        self.assertEqual(len(declared), 4)
        original={"testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground",
                  "testChangedOriginalCannotSubmitOrReplaceLastGood",
                  "testThreeFieldsRequireEachAcknowledgementAndFourRefuses"}
        selected="testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch"
        self.assertEqual(set(declared),original|{selected})
        expanded = {f"Manual correction iOS {ios} / {case}" for ios in (26, 27) for case in cases}
        self.assertEqual(expanded, manifest.MANUAL_REQUIRED_JOBS)
        self.assertEqual(len(expanded), 8)
        self.assertEqual(len(manifest.ALL_UI_REQUIRED_JOBS), 12)
        self.assertEqual(len(release_gate.REQUIRED), 14)  # Main builds its IPA in the publishing job.
        self.assertIn("name: Manual correction iOS ${{ matrix.ios }} / ${{ matrix.case }}", manual)
        self.assertIn("TKPK_MANUAL_CASE: ${{ matrix.case }}", manual)
        self.assertIn("TKPK_TEST_IOS: ${{ matrix.ios }}", manual)
        self.assertIn("ref: ${{ github.sha }}", manual)
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', manual)
        self.assertIn("fail-fast: false", manual)
        self.assertIn("timeout-minutes: 45", manual)
        self.assertIn("bash tools/test-manual-ui.sh", manual)
        self.assertNotIn("continue-on-error", manual)
        self.assertEqual(manual.count("TKPK_MANUAL_DIAGNOSTICS: '1'"), 2)
        self.assertEqual(workflow.count("TKPK_MANUAL_DIAGNOSTICS"), 2)
        for ios in (26, 27):
            self.assertIn(f"- ios: {ios}\n            runner: xcode-27\n            developer: /Applications/Xcode_27.2.app/Contents/Developer", manual)
            block = manual.split(f"  manual-{ios}:\n", 1)[-1]
            if ios == 27:
                block = block.split("  manual-26:\n", 1)[0]
            self.assertIn("TKPK_EXPECTED_IOS_SDK: '27.2'", block)
            self.assertIn(f"TKPK_SIMULATOR_FRONTEND: {'gui' if ios == 26 else 'headless'}", block)
            budget = 'python3 -B tools/timed_command.py --timeout 2400 --cleanup-grace 120 "Manual preparation and UI runner" bash -euo pipefail -c'
            self.assertIn(budget, block)
            prepare = f"python3 -B tools/prepare-ios{ios}-runtime.py"
            self.assertIn(prepare, block)
            self.assertLess(block.index(budget), block.index("python3 -B tools/select-ci-xcode.py"))
            self.assertLess(block.index(prepare), block.index("bash tools/test-manual-ui.sh"))
            if ios == 26:
                self.assertIn(prepare + " --hold-export\n", block)
                cleanup = "run: " + prepare + " --cleanup-export\n"
                self.assertIn("if: always()\n        " + cleanup, block)
                self.assertLess(block.index("bash tools/test-manual-ui.sh"), block.index(cleanup))
        simulator = workflow.split("  simulator-27-a:\n", 1)[1].split("  manual-27:\n", 1)[0]
        for ios, shard, minutes in ((27, "a", 75), (27, "b", 75), (26, "a", 80), (26, "b", 90)):
            block = workflow.split(f"  simulator-{ios}-{shard}:\n", 1)[1]
            block = re.split(r"^  [a-z][a-z0-9-]*:\s*$", block, maxsplit=1, flags=re.MULTILINE)[0]
            self.assertEqual(re.findall(r"^    timeout-minutes: (\d+)$", block, re.MULTILINE),
                             [str(minutes)], (ios, shard))
        self.assertNotIn("test-manual-ui.sh", simulator)
        probe=(ROOT/".github/workflows/manual-input-native-probe.yml").read_text(encoding="utf-8")
        for case in original|{selected}:
            self.assertIn("          - "+case+"\n",probe)
        extended_preparation = f"(matrix.case == '{selected}' || (matrix.ios == 26 && inputs.sdk26 != '26.6'))"
        self.assertIn("timeout-minutes: ${{ " + extended_preparation + " && 45 || 35 }}",probe)
        all_cases=json.loads(re.search(r"inputs.case == 'all' && '([^']+)'",probe).group(1))
        self.assertCountEqual(all_cases,original|{selected})
        ios_input=probe.split("      ios:\n",1)[1].split("\npermissions:",1)[0]
        self.assertIn("default: both",ios_input)
        self.assertIn("options: ['both', '26', '27']",ios_input)
        matrix_ios=re.search(r"ios: \$\{\{ fromJSON\(([^\n]+)\) \}\}",probe).group(1)
        self.assertEqual(matrix_ios,"inputs.ios == 'both' && '[26,27]' || inputs.ios == '26' && '[26]' || '[27]'")
        self.assertEqual([json.loads(value) for value in re.findall(r"'(\[[^']+\])'",matrix_ios)],[[26,27],[26],[27]])
        self.assertNotIn("        include:",probe)  # include must not re-add an unselected OS.
        self.assertIn("TKPK_MANUAL_CASE: ${{ matrix.case }}",probe)
        self.assertNotIn("continue-on-error",probe)
        sdk26=probe.split("      sdk26:\n",1)[1].split("\npermissions:",1)[0]
        self.assertIn("default: '26.6'",sdk26)
        self.assertIn("options: ['26.6', '27.1', '27.2']",sdk26)
        self.assertIn("matrix.ios == 26 && inputs.sdk26 == '26.6' && 'macos-26' || 'xcode-27'",probe)
        self.assertIn("format('/Applications/Xcode_{0}.app/Contents/Developer', matrix.ios == 27 && inputs.sdk27 || inputs.sdk26)",probe)
        self.assertIn("matrix.ios == 27 && inputs.sdk27 || inputs.sdk26 != '26.6' && inputs.sdk26 || '26.5'",probe)
        sdk27=probe.split("      sdk27:\n",1)[1].split("      ios:\n",1)[0]
        self.assertIn("default: '27.1'",sdk27)
        self.assertIn("options: ['27.1', '27.2']",sdk27)
        self.assertIn("TKPK_FOCUS_IOS: ${{ inputs.ios }}",probe)
        self.assertIn("TKPK_FOCUS_SDK26: ${{ inputs.sdk26 }}",probe)
        self.assertIn("TKPK_FOCUS_SDK27: ${{ inputs.sdk27 }}",probe)
        self.assertIn("TKPK_MANUAL_RUNNER_SECONDS: ${{ " + extended_preparation + " && 2400 || 1800 }}",probe)
        budget='python3 -B tools/timed_command.py --timeout "$TKPK_MANUAL_RUNNER_SECONDS" --cleanup-grace 120 "Focused manual preparation and UI runner" bash -euo pipefail -c'
        self.assertIn(budget,probe)
        self.assertLess(probe.index(budget),probe.index('python3 -B tools/select-ci-xcode.py'))
        self.assertLess(probe.index('python3 -B tools/prepare-ios26-runtime.py --hold-export'),probe.index('bash tools/test-manual-ui.sh'))
        preflight=probe.split("      - name: Validate focused OS and toolchain selection\n        run: |\n",1)[1].split("      - name:",1)[0]
        preflight="\n".join(line[10:] for line in preflight.splitlines())
        for ios in ('both','26','27','25','26,27',''):
            for sdk in ('26.6','27.1','27.2','27.0',''):
                for sdk27 in ('27.1','27.2','27.0',''):
                    run=subprocess.run(['bash','-eu','-c',preflight],capture_output=True,text=True,
                        env=os.environ|{'TKPK_FOCUS_IOS':ios,'TKPK_FOCUS_SDK26':sdk,'TKPK_FOCUS_SDK27':sdk27})
                    self.assertEqual(run.returncode,0 if ios in ('both','26','27') and sdk in ('26.6','27.1','27.2')
                        and sdk27 in ('27.1','27.2') else 2,(ios,sdk,sdk27,run.stderr))
        self.assertLess(probe.index(preflight.splitlines()[0].strip()),probe.index("python3 -B tools/prepare-ios"))
        prepare="python3 -B tools/prepare-ios26-runtime.py --hold-export"
        self.assertIn('if [[ "$TKPK_TEST_IOS" == 27 ]]; then\n              python3 -B tools/prepare-ios27-runtime.py\n            elif [[ "$TKPK_TEST_IOS" == 26 && "$TKPK_FOCUS_SDK26" != 26.6 ]]; then\n              '+prepare+'\n            fi',probe)
        self.assertLess(probe.index(prepare),probe.index("bash tools/test-manual-ui.sh"))
        cleanup="python3 -B tools/prepare-ios26-runtime.py --cleanup-export"
        self.assertIn("if: always() && matrix.ios == 26 && inputs.sdk26 != '26.6'\n        run: "+cleanup,probe)
        self.assertLess(probe.index("bash tools/test-manual-ui.sh"),probe.index(cleanup))
        self.assertIn("bash tools/test-app-ui.sh", simulator)

    def test_cli_selects_the_complete_shard_and_rejects_invalid_shard(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        selected = subprocess.check_output(command + ["--shard", "A", "--mode", "selectors"], text=True)
        self.assertEqual(selected.splitlines(), [
            "-only-testing:PickerTapChecks/ApplicationChecks/" + test for test in manifest.SHARDS["A"]])
        invalid = subprocess.run(command + ["--shard", "C", "--mode", "selectors"],
                                 capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)

    def test_cli_reads_japanese_source_with_non_utf8_default_encoding(self):
        environment = os.environ | {"LC_ALL": "C", "PYTHONCOERCECLOCALE": "0", "PYTHONUTF8": "0"}
        result = subprocess.run([sys.executable, "-X", "utf8=0", "-B",
            str(ROOT / "tools/ui_test_manifest.py"), "--shard", "A", "--mode", "selectors"],
            env=environment, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), len(manifest.SHARDS["A"]))

    def test_relaunch_diagnosis_cannot_replace_the_full_shard_gate(self):
        self.assertEqual(manifest.RELAUNCH_PROBE_TESTS, (
            "testChangedAccountDataNoticeOpensSharedAcquisition",
            "testChangedDataProducesOneLocalNotification",
            "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork",
            "testLinkPreferencesSurviveRelaunch",
            "testNotificationControlsAndAppearance",
            "testSettingsAccountDataAndFileDetails"))
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        selected = subprocess.check_output(command + ["--relaunch-probe", "--mode", "selectors"], text=True)
        self.assertEqual(selected.splitlines(), [
            "-only-testing:PickerTapChecks/ApplicationChecks/" + test for test in manifest.RELAUNCH_PROBE_TESTS])
        self.assertEqual(subprocess.check_output(command + ["--relaunch-probe", "--mode", "system-size"], text=True).strip(), "0")
        for incompatible in (["--shard", "B"], ["--system-size-only"]):
            result = subprocess.run(command + ["--relaunch-probe", "--mode", "selectors"] + incompatible,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
        focused = "".join(result_line(test) for test in manifest.RELAUNCH_PROBE_TESTS)
        manifest.validate_results(focused, manifest.RELAUNCH_PROBE_TESTS, 27)
        with self.assertRaises(ValueError):
            manifest.validate_results(focused, manifest.selected_tests("B"), 27)

    def test_diagnostic_selection_requires_exact_completion_and_cannot_select_full_shards(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        case = "testChangedDataProducesOneLocalNotification"
        selection = ["--relaunch-probe", "--probe-case", case]
        self.assertEqual(subprocess.check_output(command + selection + ["--mode", "selectors"],
                                                text=True).splitlines(),
                         ["-only-testing:PickerTapChecks/ApplicationChecks/" + case])
        for incompatible in (["--probe-case", case], selection + ["--shard", "A"],
                             ["--relaunch-probe", "--probe-case", "testUnknown"]):
            result = subprocess.run(command + incompatible + ["--mode", "selectors"],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, result.stdout)
        with tempfile.TemporaryDirectory(prefix="takupoke-one-diagnostic-") as directory:
            log = Path(directory) / "owned.log"
            for contents, expected in (
                (result_line(case), True), ("", False), (result_line(case, "failed"), False),
                (result_line(case, "skipped"), False), (result_line(case) * 2, False),
                (result_line("testLinkPreferencesSurviveRelaunch"), False),
                (result_line(case) + result_line("testLinkPreferencesSurviveRelaunch"), False),
            ):
                log.write_text(contents, encoding="utf-8")
                result = subprocess.run(command + selection + ["--mode", "verify", "--ios", "27",
                    "--runner-log", "--log", str(log)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected, result.stderr)


        pair = ("testChangedDataProducesOneLocalNotification", "testNotificationControlsAndAppearance")
        self.assertEqual(manifest.NOTIFICATION_PROBE_TESTS, pair)
        selection = ["--relaunch-probe", "--probe-case", "notifications"]
        self.assertEqual(subprocess.check_output(command + selection + ["--mode", "selectors"],
                                                text=True).splitlines(),
                         ["-only-testing:PickerTapChecks/ApplicationChecks/" + item for item in pair])
        rejected = subprocess.run(command + ["--probe-case", "notifications", "--mode", "selectors"],
                                  capture_output=True, text=True)
        self.assertNotEqual(rejected.returncode, 0)
        with tempfile.TemporaryDirectory(prefix="takupoke-two-diagnostic-") as directory:
            log = Path(directory) / "owned.log"
            complete = "".join(result_line(item) for item in pair)
            for contents, expected in (
                (complete, True), (result_line(pair[0]), False),
                (complete + result_line(pair[0]), False),
                (complete.replace("passed", "failed", 1), False),
                (complete.replace("passed", "skipped", 1), False),
                (complete + result_line("testLinkPreferencesSurviveRelaunch"), False),
            ):
                log.write_text(contents, encoding="utf-8")
                result = subprocess.run(command + selection + ["--mode", "verify", "--ios", "27",
                    "--runner-log", "--log", str(log)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected, result.stderr)

        controls = pair + ("testLinkPreferencesSurviveRelaunch",
                       "testSettingsAccountDataAndFileDetails",
                       "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch")
        self.assertEqual(manifest.CONTROL_PROBE_TESTS, controls)
        groups = (
            ("controls", controls),
            ("rows", (controls[-1],)),
            ("weekday-carryover", ("testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups",)),
            ("countdown-notifications", ("testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch",)),
            ("countdown-school-notices", ("testSchoolCountdownReservesBothLaterPeriodsWhileCurrentPeriodIsDisplayed",)),
            ("countdown-storage", ("testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration",)),
            ("countdown-delete", ("testCountdownDeleteWriteFailureKeepsDetailAndCanRetry",)),
            ("countdown-notification-route", ("testCountdownNotificationRouteOpensCurrentDetailAndMissingTargetList",)),
            ("countdown-and-yellow", ("testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors",
                                      "testMainColorUpdatesAlreadyOpenedTimetableWithoutRelaunch")),
            ("countdown-notification-context", (manifest.SETTINGS_TEST, "testNotificationControlsAndAppearance",
                                                "testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch")),
            ("countdown-calendar", ("testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent",)),
            ("countdown", ("testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent",
                           "testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch",
                           "testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors")),
            ("rows-context", ("testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover", controls[-1])),
            ("input-delivery", ("testSettingsAccountDataAndFileDetails", manifest.VOICEOVER_TEST)),
            ("file-details", ("testFileFailuresKeepResultsAndStayInTheirOwnDetails",
                              "testSetupCanBeSkippedAndOffersAllFiles")),
            ("status-settings", ("testSettingsGroupsAndCompactDataOverviews",
                                 "testStatusScreenUsesPublicResourcesAndDataRoutes",
                                 "testEmptyDataCanBeConfigured", manifest.SETTINGS_TEST,
                                 "testSetupCanBeSkippedAndOffersAllFiles")),
            ("status-settings-overviews", ("testSettingsGroupsAndCompactDataOverviews",
                                           "testEmptyDataCanBeConfigured",
                                           "testSetupCanBeSkippedAndOffersAllFiles")),
            ("status-settings-screen", ("testStatusScreenUsesPublicResourcesAndDataRoutes",)),
            ("updates", ("testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair",
                         "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork")),
            ("auxiliary-store", ("testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover",)),
            ("timetable-clocks", ("testTimetableCommonClocksAndEventOnlyWeekScale",)),
            ("home-launch", ("testChangedAccountDataNoticeOpensSharedAcquisition",
                             "testHomeTimetableAndWeekCalendar")),
        )
        for group_name, selected in groups:
            selection = ["--relaunch-probe", "--probe-case", group_name]
            self.assertEqual(subprocess.check_output(command + selection + ["--mode", "selectors"],
                                                    text=True).splitlines(),
                             ["-only-testing:PickerTapChecks/ApplicationChecks/" + item for item in selected])
            rejected = subprocess.run(command + ["--probe-case", group_name, "--mode", "selectors"],
                                      capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            with tempfile.TemporaryDirectory(prefix="takupoke-control-diagnostic-") as directory:
                log = Path(directory) / "owned.log"
                complete = "".join(result_line(item) for item in selected)
                for contents, expected in (
                    (complete, True), (complete.replace(result_line(selected[0]), ""), False),
                    (complete + result_line(selected[0]), False),
                    (complete.replace("passed", "failed", 1), False),
                    (complete.replace("passed", "skipped", 1), False),
                    (complete + result_line("testHomeTimetableAndWeekCalendar"), False),
                ):
                    log.write_text(contents, encoding="utf-8")
                    result = subprocess.run(command + selection + ["--mode", "verify", "--ios", "27",
                        "--runner-log", "--log", str(log)], capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, expected, result.stderr)

    def test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py"),
                   "--shard", "B", "--mode", "verify", "--runner-log"]
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "owned.log"
            for ios in (26, 27):
                base = "".join(result_line(test, "skipped" if ios == 26 and test == manifest.VOICEOVER_TEST else "passed")
                               for test in manifest.selected_tests("B"))
                complete = base + result_line(manifest.SYSTEM_SIZE_TEST) * 3
                for contents, success in (("", False), (base, False), (complete, True),
                                          (complete + result_line(manifest.SYSTEM_SIZE_TEST), False)):
                    path.write_text(contents, encoding="utf-8")
                    result = subprocess.run(command + ["--ios", str(ios), "--log", str(path)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, success, result.stderr)
