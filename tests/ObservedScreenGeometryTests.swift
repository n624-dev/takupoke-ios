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
}
