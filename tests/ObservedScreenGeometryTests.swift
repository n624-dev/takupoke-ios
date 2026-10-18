import Foundation
import XCTest

final class ObservedScreenGeometryTests: XCTestCase {
    func testObservedEqualPhysicalEdgesSurviveFloatingPointArithmetic() {
        let frame = CGRect(x: 16, y: 113, width: 361, height: 121.0 / 3)
        let viewport = CGRect(x: 0, y: CGFloat(113).nextUp, width: 393, height: 656)
        XCTAssertFalse(viewport.contains(frame), "Reproduce the exact native observation failure")
        XCTAssertTrue(ObservedScreenGeometry.contains(frame, in: viewport, scale: 3))
    }

    func testPhysicalAndFractionalPixelClippingIsStillRejectedOnEveryEdge() {
        let viewport = CGRect(x: 0, y: 113, width: 393, height: 656)
        for scale: CGFloat in [1, 2, 3] {
            for delta: CGFloat in [1 / scale, 0.001 / scale] {
                for clipped in [
                    CGRect(x: -delta, y: 200, width: 30, height: 30),
                    CGRect(x: 30, y: 113 - delta, width: 30, height: 30),
                    CGRect(x: 393 - 30 + delta, y: 200, width: 30, height: 30),
                    CGRect(x: 30, y: 769 - 30 + delta, width: 30, height: 30),
                ] {
                    XCTAssertFalse(ObservedScreenGeometry.contains(clipped, in: viewport, scale: scale))
                }
            }
        }
    }

    func testEmptyNonFiniteAndInvalidScaleDoNotBecomeVisible() {
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
        for frame in [CGRect.null, CGRect.infinite, .zero, CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10)] {
            XCTAssertFalse(ObservedScreenGeometry.contains(frame, in: viewport, scale: 3))
        }
        for scale: CGFloat in [0, -1, .nan, .infinity] {
            XCTAssertFalse(ObservedScreenGeometry.contains(viewport, in: viewport, scale: scale))
        }
    }

    func testObservedClippedRowsUseBoundedDragTowardBodyCenter() {
        let viewport = CGRect(x: 0, y: 129, width: 393, height: 640)
        for target in [CGRect(x: 16, y: 730.333, width: 361, height: 52.333),
                       CGRect(x: 16, y: 62.667, width: 361, height: 52.333)] {
            guard let drag = ObservedScreenGeometry.scrollDrag(for: target, in: viewport) else {
                return XCTFail("Observed clipped row must produce a scroll")
            }
            XCTAssertTrue(viewport.contains(drag.start))
            XCTAssertTrue(viewport.contains(drag.end))
            let offset = drag.end.y - drag.start.y
            XCTAssertLessThanOrEqual(abs(offset), viewport.height / 3 + 0.001)
            XCTAssertGreaterThan(offset * (viewport.midY - target.midY), 0)
            XCTAssertTrue(ObservedScreenGeometry.contains(target.offsetBy(dx: 0, dy: offset), in: viewport, scale: 3))
        }
    }

    func testUnusableOversizeOrAlreadyVisibleRowsNeverInventScrollGeometry() {
        let viewport = CGRect(x: 0, y: 100, width: 100, height: 200)
        for target in [CGRect.null, .infinite, .zero,
                       CGRect(x: 10, y: 120, width: 80, height: 30),
                       CGRect(x: 10, y: 80, width: 80, height: 250),
                       CGRect(x: -1, y: 80, width: 80, height: 30)] {
            XCTAssertNil(ObservedScreenGeometry.scrollDrag(for: target, in: viewport))
        }
        XCTAssertNil(ObservedScreenGeometry.scrollDrag(for: viewport, in: .null))
    }

    func testUnresolvedPresentFooterNeverMakesBodyVisible() {
        let viewport = CGRect(x: 0, y: 100, width: 100, height: 200)
        let body = CGRect(x: 10, y: 120, width: 80, height: 30)
        XCTAssertTrue(ObservedScreenGeometry.contains(body, in: viewport, scale: 3))
        for footer in [CGRect.null, CGRect.infinite, .zero,
            CGRect(x: CGFloat.nan, y: 200, width: 100, height: 30)]
        {
            let unresolved = ObservedScreenGeometry.excludingFooter(footer, from: viewport)
            XCTAssertTrue(unresolved.isNull)
            XCTAssertFalse(ObservedScreenGeometry.contains(body, in: unresolved, scale: 3))
        }
        XCTAssertTrue(ObservedScreenGeometry.excludingFooter(.null, from: .null).isNull)
    }

    func testAbsentResolvedAndCoveringFooterHaveDifferentVisibleBounds() {
        let viewport = CGRect(x: 0, y: 100, width: 100, height: 200)
        XCTAssertEqual(ObservedScreenGeometry.excludingFooter(nil, from: viewport), viewport)
        for offscreen in [
            CGRect(x: 0, y: 300, width: 100, height: 30),
            CGRect(x: 100, y: 200, width: 100, height: 30),
        ] {
            XCTAssertEqual(ObservedScreenGeometry.excludingFooter(offscreen, from: viewport), viewport)
        }
        let footer = CGRect(x: 0, y: 250, width: 100, height: 50)
        let visible = ObservedScreenGeometry.excludingFooter(footer, from: viewport)
        XCTAssertEqual(visible, CGRect(x: 0, y: 100, width: 100, height: 150))
        XCTAssertFalse(ObservedScreenGeometry.contains(footer, in: visible, scale: 3))
        let covering = CGRect(x: 0, y: 90, width: 100, height: 210)
        XCTAssertTrue(ObservedScreenGeometry.excludingFooter(covering, from: viewport).isNull)
    }
}
