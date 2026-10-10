import Foundation

enum ObservedScreenGeometry {
    static func usable(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.width > 0 && rect.height > 0
            && [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy(\.isFinite)
    }

    // nil means absent. A present footer with unreadable geometry must block
    // visibility until another observation resolves it, including before scrolling.
    static func excludingFooter(_ footer: CGRect?, from viewport: CGRect) -> CGRect {
        guard usable(viewport) else { return .null }
        guard let footer else { return viewport }
        guard usable(footer) else { return .null }
        guard usable(viewport.intersection(footer)) else { return viewport }
        guard footer.minY > viewport.minY else { return .null }
        return CGRect(
            x: viewport.minX, y: viewport.minY, width: viewport.width,
            height: min(viewport.maxY, footer.minY) - viewport.minY
        )
    }

    private static func edge(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        let pixels = value * scale
        let integer = pixels.rounded()
        // Repair only arithmetic noise within two representable values of an
        // observed physical pixel edge. Fractional-pixel clipping stays clipping.
        return abs(pixels - integer) <= pixels.ulp * 2 ? integer / scale : value
    }

    static func contains(_ frame: CGRect, in viewport: CGRect, scale: CGFloat) -> Bool {
        guard scale.isFinite, scale >= 1,
            [frame, viewport].allSatisfy(usable) else { return false }
        return edge(frame.minX, scale: scale) >= edge(viewport.minX, scale: scale)
            && edge(frame.minY, scale: scale) >= edge(viewport.minY, scale: scale)
            && edge(frame.maxX, scale: scale) <= edge(viewport.maxX, scale: scale)
            && edge(frame.maxY, scale: scale) <= edge(viewport.maxY, scale: scale)
    }
}
