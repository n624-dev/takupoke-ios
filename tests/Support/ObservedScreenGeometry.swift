import Foundation

enum ObservedScreenGeometry {
    private static func edge(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        let pixels = value * scale
        let integer = pixels.rounded()
        // Repair only arithmetic noise within two representable values of an
        // observed physical pixel edge. Fractional-pixel clipping stays clipping.
        return abs(pixels - integer) <= pixels.ulp * 2 ? integer / scale : value
    }

    static func contains(_ frame: CGRect, in viewport: CGRect, scale: CGFloat) -> Bool {
        guard scale.isFinite, scale >= 1,
            [frame, viewport].allSatisfy({ rect in
                !rect.isNull && !rect.isInfinite && rect.width > 0 && rect.height > 0
                    && [rect.minX, rect.minY, rect.maxX, rect.maxY].allSatisfy(\.isFinite)
            }) else { return false }
        return edge(frame.minX, scale: scale) >= edge(viewport.minX, scale: scale)
            && edge(frame.minY, scale: scale) >= edge(viewport.minY, scale: scale)
            && edge(frame.maxX, scale: scale) <= edge(viewport.maxX, scale: scale)
            && edge(frame.maxY, scale: scale) <= edge(viewport.maxY, scale: scale)
    }
}
