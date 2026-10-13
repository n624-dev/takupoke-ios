import Foundation

/// Bounds for a composed character are built only from its own UTF-16 indices.
/// A selection's highlight rectangle is not a per-character bounding box.
enum PDFCharacterGeometry {
    static func bounds(for range: NSRange, count: Int, characterBounds: (Int) -> CGRect) throws -> CGRect {
        guard range.location >= 0, range.location < count, range.length > 0,
              range.length <= count - range.location else {
            throw PDFParseError(code: .unsupported, stage: .characterMapping, branch:.b004)
        }
        var result = CGRect.null
        for index in range.location..<(range.location + range.length) {
            let rect = characterBounds(index)
            guard !rect.isNull, !rect.isEmpty, !rect.isInfinite,
                  [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) else {
                throw PDFParseError(code: .unsupported, stage: .characterMapping, branch:.b005)
            }
            result = result.union(rect)
        }
        return result
    }
}
