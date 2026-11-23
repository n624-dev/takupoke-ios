import Foundation
import XCTest

final class ObservedScreenGeometryTests: XCTestCase {
    func testCoherentBodyViewportKeepsAllOccludersAndRejectsUnknownGeometry() {
        let app=CGRect(x:0,y:0,width:400,height:800)
        let nav=CGRect(x:0,y:40,width:400,height:60)
        let tab=CGRect(x:0,y:740,width:400,height:60)
        let keyboard=CGRect(x:0,y:600,width:400,height:200)
        let footer=CGRect(x:0,y:550,width:400,height:50)
        func project(_ tab:CGRect?,_ keyboards:[CGRect],_ footers:[CGRect], requiresKeyboard: Bool = false)->CGRect {
            ObservedScreenGeometry.bodyViewport(app:app,navigation:nav,tab:tab,keyboards:keyboards,footers:footers,
                                                requiresKeyboard:requiresKeyboard)
        }
        XCTAssertEqual(project(tab,[],[]),CGRect(x:0,y:100,width:400,height:640))
        XCTAssertEqual(project(nil,[],[]),CGRect(x:0,y:100,width:400,height:700))
        XCTAssertEqual(project(tab,[keyboard],[]),CGRect(x:0,y:100,width:400,height:500))
        XCTAssertEqual(project(tab,[keyboard],[],requiresKeyboard:true),project(tab,[keyboard],[]))
        XCTAssertEqual(project(tab,[keyboard],[footer]),CGRect(x:0,y:100,width:400,height:450))
        XCTAssertEqual(project(tab,[],[CGRect(x:0,y:780,width:400,height:20)]),project(tab,[],[]))
        for result in [project(tab,[keyboard,keyboard],[]),project(tab,[],[footer,footer]),
                       project(.zero,[],[]),project(tab,[.infinite],[]),project(tab,[.zero],[]),
                       project(tab,[.null],[]),project(tab,[],[.null]),
                       project(tab,[],[],requiresKeyboard:true),project(tab,[.null],[],requiresKeyboard:true),
                       ObservedScreenGeometry.bodyViewport(app:.null,navigation:nav,tab:tab,keyboards:[],footers:[]),
                       ObservedScreenGeometry.bodyViewport(app:app,navigation:.zero,tab:tab,keyboards:[],footers:[])] {
            XCTAssertFalse(ObservedScreenGeometry.usable(result))
        }
    }

    func testObservedEqualPhysicalEdgesSurviveFloatingPointArithmetic() {
        let observations: [(headerY: CGFloat, viewportY: CGFloat)] = [
            (113, CGFloat(113).nextUp),
            (165, CGFloat(165).nextUp.nextUp),
        ]
        for (headerY, viewportY) in observations {
            let frame = CGRect(x: 16, y: headerY, width: 361, height: 121.0 / 3)
            let viewport = CGRect(x: 0, y: viewportY, width: 393, height: 769 - viewportY)
            XCTAssertFalse(viewport.contains(frame), "Reproduce the native observation at y=\(headerY)")
            XCTAssertTrue(ObservedScreenGeometry.contains(frame, in: viewport, scale: 3), "y=\(headerY)")
        }
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
        // Representable point steps are smaller just below a power of two.
        let boundary = CGFloat(128)
        let clipped = CGRect(x: 30, y: boundary.nextDown.nextDown.nextDown.nextDown, width: 30, height: 30)
        let visible = CGRect(x: 0, y: boundary, width: 393, height: 640)
        XCTAssertFalse(ObservedScreenGeometry.contains(clipped, in: visible, scale: 3))
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

    func testClippedScrollLabelOffersOnlyPointsWithBothDragEndpointsVisible() throws {
        let viewport = CGRect(x: 0, y: 113, width: 393, height: 656)
        let label = CGRect(x: 16, y: 563, width: 361, height: 217)
        let offset: CGFloat = -218
        XCTAssertFalse(ObservedScreenGeometry.contains(label, in: viewport, scale: 3))
        let start = try XCTUnwrap(ObservedScreenGeometry.visibleScrollStart(for: label, in: viewport, offset: offset))
        XCTAssertTrue(label.intersection(viewport).contains(start))
        XCTAssertTrue(viewport.contains(CGPoint(x: start.x, y: start.y + offset)))
        XCTAssertNil(ObservedScreenGeometry.visibleScrollStart(for: label, in: viewport, offset: 300))
        XCTAssertNil(ObservedScreenGeometry.visibleScrollStart(for: .null, in: viewport, offset: offset))
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
