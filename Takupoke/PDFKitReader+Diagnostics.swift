#if DEBUG && TAKUPOKE_INTERNAL_DIAGNOSTICS
import Foundation
#if canImport(PDFKit)
import PDFKit
import CoreGraphics

extension PDFKitReader {
    /// Independent inspection continues past invalid character bounds. It never
    /// creates lessons, saves an analysis, or substitutes data into the parser.
    static func diagnose(_ url: URL, check: @escaping () throws -> Void = {}) -> PDFFullReadDiagnostic {
        var report = PDFFullReadDiagnostic()
        report.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        report.appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        report.commit = Bundle.main.object(forInfoDictionaryKey: "TakupokeCommit") as? String
        let os = ProcessInfo.processInfo.operatingSystemVersion
        report.osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        do {
            try check()
            report.fileBytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard let size = report.fileBytes, size > 0, size <= MaterialLibrary.maximumBytes,
                  let document = PDFDocument(url: url) else {
                report.incomplete.append(.unavailable); return report
            }
            report.pageCount = document.pageCount
            report.locked = document.isLocked
            guard !document.isLocked else { report.incomplete.append(.locked); return report }
            if document.pageCount > 12 { report.incomplete.append(.pageLimit) }
            var characterBudget = 100_000
            var rangeBudget = 100_000
            for index in 0..<min(document.pageCount, 12) {
                try check()
                var output = PDFFullReadDiagnostic.Page(number: index + 1)
                // Preserve a partially inspected page if cancellation/error occurs.
                defer { report.pages.append(output) }
                guard let page = document.page(at: index), let ref = page.pageRef else {
                    output.issues.append(PDFParseError(code: .unreadable, page: index + 1))
                    report.incomplete.append(.unavailable); continue
                }
                let rotation = ((page.rotation % 360) + 360) % 360
                let media = ref.getBoxRect(.mediaBox)
                output.rotation = rotation
                output.mediaBox = .init(media)
                output.nativeCharacterCount = page.numberOfCharacters
                let ns = (page.string ?? "") as NSString
                output.utf16Count = ns.length
                guard ns.length <= 100_000 else { report.incomplete.append(.characterLimit); continue }
                output.text = page.string
                if let selection = page.selection(for: NSRange(location: 0, length: ns.length)) {
                    for line in selection.selectionsByLine() {
                        try check()
                        guard rangeBudget > 0 else { report.incomplete.append(.rangeLimit); break }
                        let count = min(line.numberOfTextRanges(on: page), rangeBudget)
                        if count < line.numberOfTextRanges(on: page) { report.incomplete.append(.rangeLimit) }
                        let ranges = (0..<count).map { PDFFullReadDiagnostic.Range(line.range(at: $0, on: page)) }
                        rangeBudget -= max(1, count)
                        output.lines.append(.init(text: line.string, ranges: ranges, bounds: .init(line.bounds(for: page))))
                    }
                }
                var cursor = 0
                while cursor < ns.length {
                    try check()
                    let range = ns.rangeOfComposedCharacterSequence(at: cursor)
                    guard range.length <= characterBudget else { report.incomplete.append(.characterLimit); break }
                    let text = ns.substring(with: range)
                    let selection = NSMaxRange(range) <= page.numberOfCharacters ? page.selection(for: range) : nil
                    let bounds: [PDFDiagnosticSnapshot.Rect?] = (range.location..<NSMaxRange(range)).map { offset in
                        offset < page.numberOfCharacters ? .init(page.characterBounds(at: offset)) : nil
                    }
                    output.characters.append(.init(range: .init(range), text: text,
                        whitespace: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        selectionText: selection?.string, selectionBounds: selection.map { .init($0.bounds(for: page)) },
                        characterBounds: bounds))
                    characterBudget -= range.length
                    cursor = NSMaxRange(range)
                }
                if [0, 90, 180, 270].contains(rotation) {
                    let reader = PDFPathReader(transform: PDFDisplayTransform(media: media, rotation: rotation), check: check)
                    do { _ = try reader.read(ref) }
                    catch {
                        var failure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
                        failure.page = index + 1
                        output.issues.append(failure)
                        report.incomplete.append(.drawingFailure)
                        if failure.code == .cancelled { throw failure }
                    }
                    output.rules = reader.lines
                    output.arrows = reader.arrows
                    output.drawingOperations = reader.operations
                } else {
                    output.issues.append(PDFParseError(code: .unsupported, page: index + 1, stage: .pageRotation))
                    report.incomplete.append(.drawingFailure)
                }
            }
        } catch {
            let failure = (error as? PDFParseError) ?? PDFParseError(code: .unreadable)
            report.issues.append(failure)
            report.incomplete.append(failure.code == .cancelled ? .cancelled : .unavailable)
        }
        return report
    }
}
#endif

#endif
