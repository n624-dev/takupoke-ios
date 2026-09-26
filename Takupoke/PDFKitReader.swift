import Foundation

#if canImport(PDFKit)
import PDFKit
import CoreGraphics

/// PDFKit opens documents and validates text; Core Graphics reads timetable
/// text placement and painted rules. Calendar selection handling stays unchanged.
/// No JavaScript, links, embedded files, or actions in a PDF are executed.
enum PDFKitReader {
    static func read(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder? = nil,
                     check: @escaping () throws -> Void = {}) throws -> [PDFPageLayout] {
        let recorder = kind == .timetable ? (diagnostics ?? PDFDiagnosticRecorder()) : nil
        do { return try readPages(url, kind: kind, diagnostics: recorder, check: check) }
        catch {
            if let recorder = recorder { throw recorder.attaching(to: error) }
            throw error
        }
    }

    /// The exam PDFs contain marked content or clipping commands rejected by
    /// the ordinary timetable's drawing interpreter. Their PDFKit character
    /// selections are validated individually by the calendar text path.
    static func readSpecial(_ url: URL, diagnostics: PDFDiagnosticRecorder? = nil,
                            check: @escaping () throws -> Void = {}) throws -> [PDFPageLayout] {
        do { return try readPages(url, kind: .events, diagnostics: diagnostics, check: check) }
        catch {
            if let diagnostics { throw diagnostics.attaching(to: error) }
            throw error
        }
    }

    private static func readPages(_ url: URL, kind: MaterialKind, diagnostics: PDFDiagnosticRecorder?,
                                  check: @escaping () throws -> Void) throws -> [PDFPageLayout] {
        diagnostics?.record(.file)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        diagnostics?.record(.file, values: [Double(size ?? -1)])
        guard let size = size, size > 0, size <= MaterialLibrary.maximumBytes else { throw PDFParseError(code: .unreadable) }
        let opened = PDFDocument(url: url)
        diagnostics?.record(.document, values: [Double(opened?.pageCount ?? -1), opened?.isLocked == true ? 1 : 0])
        guard let document = opened, !document.isLocked,
              document.pageCount > 0, document.pageCount <= 12 else { throw PDFParseError(code: .unreadable) }
        var output: [PDFPageLayout] = []
        for index in 0..<document.pageCount {
            try check()
            diagnostics?.record(.page, page: index + 1)
            guard let page = document.page(at: index), let ref = page.pageRef,
                  let string = page.string, page.numberOfCharacters <= 100000 else {
                throw PDFParseError(code: .unreadable, page: index + 1)
            }
            let media = ref.getBoxRect(.mediaBox)
            let rotation = ((page.rotation % 360) + 360) % 360
            guard [0, 90, 180, 270].contains(rotation) else {
                throw PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation)
            }
            let transform = PDFDisplayTransform(media: media, rotation: rotation)
            diagnostics?.record(.pageText, page: index + 1,
                values: [Double(string.utf16.count), Double(page.numberOfCharacters), Double(rotation)], bounds: media)
            var glyphs: [PDFGlyph]
            if kind == .timetable {
                do {
                    glyphs = try PDFDrawnTextReader(check: check).read(ref, expectedText: string).map { glyph in
                        let b = transform.rect(CGRect(x: glyph.x, y: glyph.y, width: glyph.width, height: glyph.height))
                        return PDFGlyph(text: glyph.text, x: Double(b.minX), y: Double(b.minY),
                                        width: Double(b.width), height: Double(b.height),
                                        sourceLine: glyph.sourceLine, sourceOrder: glyph.sourceOrder)
                    }
                } catch var error as PDFParseError { error.page = index + 1; throw error }
            } else {
                let ns = string as NSString
                guard ns.length == page.numberOfCharacters else {
                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                }
                diagnostics?.record(.pageSelection, page: index + 1)
                guard ns.length > 0, let pageSelection = page.selection(for: NSRange(location: 0, length: ns.length)) else {
                    throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                }
                var sourceLines = [Int?](repeating: nil, count: ns.length)
                let textLines = pageSelection.selectionsByLine()
                diagnostics?.record(.lines, page: index + 1, values: [Double(textLines.count)])
                guard textLines.count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
                var coveredUnits = 0
                for (lineID, line) in textLines.enumerated() {
                    try check()
                    let count = line.numberOfTextRanges(on: page)
                    diagnostics?.record(.lineRanges, page: index + 1, line: lineID, values: [Double(count)])
                    guard count <= 100000 else { throw PDFParseError(code: .limit, page: index + 1) }
                    for rangeIndex in 0..<count {
                        let range = line.range(at: rangeIndex, on: page)
                        diagnostics?.record(.lineRange, page: index + 1, index: range.location, length: range.length, line: lineID)
                        guard range.location >= 0, range.location <= ns.length,
                              range.length >= 0, range.length <= ns.length - range.location else {
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                        }
                        coveredUnits += range.length
                        guard coveredUnits <= ns.length * 2 else { throw PDFParseError(code: .limit, page: index + 1) }
                        for offset in range.location..<NSMaxRange(range) {
                            if let scalar = UnicodeScalar(UInt32(ns.character(at: offset))),
                               CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
                            guard sourceLines[offset] == nil || sourceLines[offset] == lineID else {
                                diagnostics?.record(.lineOffset, page: index + 1, index: offset, line: lineID,
                                                    values: [Double(sourceLines[offset] ?? -1)])
                                throw PDFParseError(code: .ambiguous, page: index + 1, stage: .textOrder)
                            }
                            sourceLines[offset] = lineID
                        }
                    }
                }
                glyphs = []
                var cursor = 0
                while cursor < ns.length {
                    if cursor % 128 == 0 { try check() }
                    let range = ns.rangeOfComposedCharacterSequence(at: cursor)
                    let text = ns.substring(with: range)
                    diagnostics?.record(.characterRange, page: index + 1, index: range.location, length: range.length,
                        line: sourceLines[cursor], values: [text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0,
                        text.unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) } ? 1 : 0])
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        guard let sourceLine = sourceLines[cursor],
                              (range.location..<NSMaxRange(range)).allSatisfy({ sourceLines[$0] == sourceLine }) else {
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .textOrder)
                        }
                        // Keep the calendar's UTF-16 selection verification.
                        let selected = page.selection(for: range)
                        diagnostics?.record(.selection, page: index + 1, index: range.location, length: range.length,
                            line: sourceLine, values: [selected == nil ? 0 : 1, selected?.string == text ? 1 : 0],
                            bounds: selected?.bounds(for: page))
                        guard let selection = selected, selection.string == text else {
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                        }
                        // The calendar path is intentionally kept unchanged.
                        let box = selection.bounds(for: page)
                        guard !box.isNull, !box.isEmpty,
                              [box.minX, box.minY, box.width, box.height].allSatisfy(\.isFinite) else {
                            // Dropping a visible character could silently change a subject or date.
                            throw PDFParseError(code: .unsupported, page: index + 1, stage: .characterMapping)
                        }
                        let b = transform.rect(box)
                        diagnostics?.record(.displayBounds, page: index + 1, index: range.location, length: range.length,
                                            line: sourceLine, bounds: b)
                        glyphs.append(PDFGlyph(text: text, x: Double(b.minX), y: Double(b.minY),
                                               width: Double(b.width), height: Double(b.height),
                                               sourceLine: sourceLine, sourceOrder: cursor))
                    }
                    cursor = NSMaxRange(range)
                }
            }
            let reader = PDFPathReader(transform: transform, check: check)
            diagnostics?.record(.paths, page: index + 1)
            let lines: [PDFRule]
            do { lines = try reader.read(ref) }
            catch var error as PDFParseError { error.page = index + 1; throw error }
            guard !glyphs.isEmpty, !lines.isEmpty else { throw PDFParseError(code: .unreadable, page: index + 1) }
            diagnostics?.record(.pageComplete, page: index + 1,
                values: [Double(glyphs.count), Double(lines.count), Double(reader.arrows.count), Double(reader.operations)])
            output.append(PDFPageLayout(width: Double(transform.width), height: Double(transform.height), glyphs: glyphs, lines: lines, arrows: reader.arrows))
        }
        diagnostics?.record(.readComplete, values: [Double(output.count)])
        return output
    }

}
#endif
