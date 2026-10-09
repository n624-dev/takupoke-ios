import Foundation

// QA geometry only: no value assignment or acknowledgement synthesis.
func manualAcknowledgementPoint(outer:CGRect,inner:CGRect,viewport:CGRect)->CGPoint? {
    guard [outer,inner,viewport].allSatisfy({
        !$0.isNull && !$0.isInfinite && $0.width>0 && $0.height>0
            && [$0.minX,$0.minY,$0.maxX,$0.maxY].allSatisfy(\.isFinite)
    }), [outer,viewport].allSatisfy({
        inner.minX >= $0.minX && inner.maxX <= $0.maxX
            && inner.minY >= $0.minY && inner.maxY <= $0.maxY
    }) else { return nil }
    return CGPoint(x:inner.midX,y:inner.midY)
}

// BEGIN PURE MANUAL SCROLL NAVIGATION
// Geometry controls only. A recycled editor's existence does not locate its row.
struct ManualScrollNavigation {
    private(set) var upward=true
    private(set) var reversed=false
    private var unchanged=0
    private var previousAnchor=""

    init(initiallyUpward:Bool=true) { upward=initiallyUpward }

    static func usable(_ frame:CGRect)->Bool {
        !frame.isNull && !frame.isInfinite && frame.width>0 && frame.height>0
            && [frame.minX,frame.minY,frame.maxX,frame.maxY].allSatisfy(\.isFinite)
    }
    private static func direction(_ frame:CGRect?,viewport:CGRect)->Bool? {
        guard let frame,usable(frame),usable(viewport),
              frame.maxX>viewport.minX,frame.minX<viewport.maxX else { return nil }
        if frame.maxY<=viewport.minY { return false } // Drag down to reveal above.
        if frame.minY>=viewport.maxY { return true }  // Drag up to reveal below.
        // A small control may straddle navigation/keyboard occlusion. A large
        // owner spanning both edges cannot establish a direction on its own.
        if frame.height<=viewport.height {
            if frame.minY<viewport.minY { return false }
            if frame.maxY>viewport.maxY { return true }
        }
        return nil
    }
    mutating func locate(target:CGRect?,owner:CGRect?,viewport:CGRect) {
        if let direction=Self.direction(owner,viewport:viewport)
            ?? Self.direction(target,viewport:viewport) { upward=direction }
        // Unknown/zero/infinite/in-viewport geometry keeps the last direction,
        // including the one bounded no-progress reversal.
    }
    mutating func observeTopBoundary() {
        // The actual first List row is visible: a further downward drag can
        // move the sheet instead of its content. Search forward without adding
        // another speculative no-progress reversal.
        upward=true
    }
    mutating func observe(anchor:String,atTop:Bool=false)->Bool {
        unchanged=anchor==previousAnchor ? unchanged+1:0
        previousAnchor=anchor
        if unchanged>=2 {
            guard !reversed else { return false }
            upward.toggle();reversed=true;unchanged=0
        }
        if atTop { observeTopBoundary() }
        return true
    }
}
// END PURE MANUAL SCROLL NAVIGATION

// BEGIN PURE MANUAL PASSIVE SELECTION
func manualPassiveCell<T>(cells: [T], viewport: CGRect, upward: Bool,
                          frame: (T) -> CGRect, isPassive: (T) -> Bool) -> T? {
    let candidates = cells.compactMap { cell -> (T, CGRect)? in
        let bounds = frame(cell)
        guard ManualScrollNavigation.usable(bounds) else { return nil }
        let safe = bounds.intersection(viewport)
        guard ManualScrollNavigation.usable(safe), safe.height > 36 else { return nil }
        return (cell, safe)
    }.sorted { upward ? $0.1.maxY > $1.1.maxY : $0.1.minY < $1.1.minY }
    // Only inspect native descendants until the first safe passive row. The
    // remaining visible rows do not need six separate accessibility queries.
    return candidates.first(where: { isPassive($0.0) })?.0
}
// END PURE MANUAL PASSIVE SELECTION
