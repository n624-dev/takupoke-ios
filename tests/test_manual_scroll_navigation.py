"""Compile the actual QA-only geometry state with fictional accessibility frames."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ManualScrollNavigationTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("swiftc"), "Swift compiler required for actual geometry controls")
    def test_actual_navigation_state_on_offscreen_virtualized_and_keyboard_frames(self):
        source = (ROOT / "tests/ui/ManualAssistanceChecks.swift").read_text()
        helper = source.split("// BEGIN PURE MANUAL SCROLL NAVIGATION\n", 1)[1].split(
            "// END PURE MANUAL SCROLL NAVIGATION", 1)[0]
        controls = r'''
import Foundation
import XCTest
HELPER
final class GeometryControls:XCTestCase {
 let viewport=CGRect(x:100,y:141,width:1,height:363)
 let inside=CGRect(x:32,y:194.33,width:329,height:23)
 let above=CGRect(x:16,y:-226,width:361,height:53)
 let below=CGRect(x:16,y:610,width:361,height:53)
 func testAboveOwnerRoutesDownDespiteStaleInViewportChild() {
  var state=ManualScrollNavigation();state.locate(target:inside,owner:above,viewport:viewport)
  XCTAssertFalse(state.upward)
 }
 func testAboveOwnerRoutesDownWithInfiniteVirtualizedChild() {
  var state=ManualScrollNavigation();state.locate(target:.init(x:CGFloat.infinity,y:CGFloat.infinity,width:0,height:0),owner:above,viewport:viewport)
  XCTAssertFalse(state.upward)
 }
 func testBelowOwnerRoutesUpWithMissingChild() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:nil,owner:below,viewport:viewport);XCTAssertTrue(state.upward)
 }
 func testFiniteOffscreenTargetAloneRoutesBothDirections() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport);XCTAssertFalse(state.upward)
  state.locate(target:below,owner:nil,viewport:viewport);XCTAssertTrue(state.upward)
 }
 func testNavigationOccludedControlRoutesDown() {
  var state=ManualScrollNavigation();state.locate(target:.init(x:32,y:130,width:329,height:23),owner:nil,viewport:viewport)
  XCTAssertFalse(state.upward)
 }
 func testKeyboardOccludedControlRoutesUp() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:.init(x:32,y:495,width:329,height:23),owner:nil,viewport:viewport);XCTAssertTrue(state.upward)
 }
 func testInViewportGeometryCannotOverridePersistentDownDirection() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:inside,owner:inside,viewport:viewport);XCTAssertFalse(state.upward)
 }
 func testDegenerateAndNonfiniteFramesCannotChooseDirection() {
  for frame in [CGRect.zero,.null,.infinite,.init(x:32,y:CGFloat.nan,width:329,height:23),.init(x:32,y:1000,width:0,height:23)] {
   var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
   state.locate(target:frame,owner:frame,viewport:viewport);XCTAssertFalse(state.upward)
  }
 }
 func testForeignHorizontalGeometryDoesNotChooseDirection() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:.init(x:400,y:610,width:20,height:23),owner:nil,viewport:viewport);XCTAssertFalse(state.upward)
 }
 func testLargeOwnerSpanningBothEdgesDoesNotInventDirection() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:nil,owner:.init(x:16,y:100,width:361,height:800),viewport:viewport);XCTAssertFalse(state.upward)
 }
 func testInvalidViewportDoesNotChooseDirection() {
  var state=ManualScrollNavigation();state.locate(target:above,owner:nil,viewport:viewport)
  state.locate(target:below,owner:below,viewport:.zero);XCTAssertFalse(state.upward)
 }
 func testOneNoProgressReversalPersistsThroughVirtualizedAndStaleInsideFrames() {
  var state=ManualScrollNavigation()
  XCTAssertTrue(state.observe(anchor:"same"));XCTAssertTrue(state.observe(anchor:"same"));XCTAssertTrue(state.observe(anchor:"same"))
  XCTAssertTrue(state.reversed);XCTAssertFalse(state.upward)
  state.locate(target:.init(x:CGFloat.infinity,y:CGFloat.infinity,width:0,height:0),owner:nil,viewport:viewport)
  state.locate(target:inside,owner:nil,viewport:viewport);XCTAssertFalse(state.upward)
 }
 func testSecondNoProgressAfterReversalStopsInsteadOfRepeatedlyToggling() {
  var state=ManualScrollNavigation()
  for _ in 0..<3 { XCTAssertTrue(state.observe(anchor:"same")) }
  XCTAssertTrue(state.observe(anchor:"same"));XCTAssertFalse(state.observe(anchor:"same"))
  XCTAssertFalse(state.upward);XCTAssertTrue(state.reversed)
 }
 func testRealAnchorMovementRestartsNoProgressCountWithoutExtraReversal() {
  var state=ManualScrollNavigation()
  XCTAssertTrue(state.observe(anchor:"a"));XCTAssertTrue(state.observe(anchor:"a"))
  XCTAssertTrue(state.observe(anchor:"b"));XCTAssertFalse(state.reversed)
  XCTAssertTrue(state.observe(anchor:"b"));XCTAssertTrue(state.observe(anchor:"b"));XCTAssertTrue(state.reversed)
  XCTAssertTrue(state.observe(anchor:"c"));XCTAssertTrue(state.observe(anchor:"c"));XCTAssertFalse(state.observe(anchor:"c"))
 }
 func testNewUsableOffscreenEvidenceMayCorrectPriorDirection() {
  var state=ManualScrollNavigation();for _ in 0..<3 { XCTAssertTrue(state.observe(anchor:"same")) }
  state.locate(target:nil,owner:below,viewport:viewport);XCTAssertTrue(state.upward);XCTAssertTrue(state.reversed)
 }
}
'''.replace("HELPER", helper)
        cases = re.findall(r"func (test\w+)\(", controls)
        self.assertEqual(len(cases), 15)
        controls += "\nXCTMain([testCase([\n" + "".join(
            f'("{name}", GeometryControls.{name}),\n' for name in cases) + "])])\n"
        with tempfile.TemporaryDirectory(prefix="manual-scroll-controls-") as directory:
            scratch = Path(directory)
            swift = scratch / "main.swift"
            swift.write_text(controls)
            compiled = subprocess.run([shutil.which("swiftc"), "-swift-version", "5",
                "-module-cache-path", str(scratch / "modules"), str(swift), "-o", str(scratch / "controls")],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(compiled.returncode, 0, compiled.stdout + compiled.stderr)
            actual = subprocess.run([str(scratch / "controls")], capture_output=True, text=True, timeout=30)
            self.assertEqual(actual.returncode, 0, actual.stdout + actual.stderr)
            self.assertIn("Executed 15 tests, with 0 failures", actual.stdout)
            print(actual.stdout)

    def test_qa_only_owner_resolution_and_existing_caps_are_preserved(self):
        source = (ROOT / "tests/ui/ManualAssistanceChecks.swift").read_text()
        visible = source.split("private func visible(", 1)[1].split("private func tap(", 1)[0]
        self.assertIn("list.cells.containing(.any,identifier:targetID)", visible)
        self.assertIn("owners.count==1", visible)
        self.assertIn("for attempt in 0..<16", visible)
        self.assertIn("XCTAssertTrue(e.exists && e.isHittable,app.debugDescription)", visible)
        self.assertNotIn("upward=e.frame", visible)
        self.assertNotIn("typeText(", visible)
        self.assertNotIn(".tap()", visible)
        self.assertEqual(source.count("func test"), 3)


if __name__ == "__main__":
    unittest.main()
