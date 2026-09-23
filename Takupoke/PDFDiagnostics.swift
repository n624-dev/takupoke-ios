import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Structured diagnostics accept only fixed codes and numbers, never source text.
struct PDFDiagnosticSnapshot: Codable, Equatable {
    struct Rect: Codable, Equatable {
        enum State: String, Codable { case valid, null, empty, infinite, nonFinite }
        var state: State
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?

        init(_ rect: CGRect) {
            let numbers: [Double] = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].map { Double($0) }
            state = rect.isNull ? .null : rect.isInfinite ? .infinite :
                !numbers.allSatisfy(\.isFinite) ? .nonFinite : rect.isEmpty ? .empty : .valid
            x = numbers[0].isFinite ? numbers[0] : nil
            y = numbers[1].isFinite ? numbers[1] : nil
            width = numbers[2].isFinite ? numbers[2] : nil
            height = numbers[3].isFinite ? numbers[3] : nil
        }
    }
    enum Step: String, Codable {
        case start, material, file, document, page, pageText, pageSelection
        case lines, lineRanges, lineRange, lineOffset, characterRange, selection, characterBounds, displayBounds
        case paths, pageComplete, readComplete, parse, parseComplete, save, saveComplete
        case failure, failureSave, failureSaved, failureSaveFailed, complete
    }
    struct Entry: Codable, Equatable {
        var sequence: Int
        var step: Step
        var page: Int?
        var index: Int?
        var length: Int?
        var line: Int?
        var values: [Double?]
        var bounds: Rect?
        var code: PDFParseError.Code?
        var stage: PDFParseError.Stage?
    }
    var schemaVersion = 1
    var parserVersion = PDFAnalysis.currentVersion(for: .timetable)
    var totalEntries: Int
    var omittedEntries: Int
    var entries: [Entry]

    var report: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else { return nil }
        return "TAKUPOKE-PDF-TRACE-1\n" + json
    }
}

/// One instance per attempt, owned by the serial material worker. Keep startup
/// context and the latest entries if an unusually large document hits the cap.
final class PDFDiagnosticRecorder {
    static let maximumEntries = 16_384
    private let limit: Int
    private let parserVersion: Int
    private let prefixCount: Int
    private var entries: [PDFDiagnosticSnapshot.Entry] = []
    private var total = 0
    private var nextReplacement: Int

    init(limit: Int = PDFDiagnosticRecorder.maximumEntries,
         parserVersion: Int = PDFAnalysis.currentVersion(for: .timetable)) {
        self.limit = min(Self.maximumEntries, max(2, limit))
        self.parserVersion = parserVersion
        prefixCount = min(64, self.limit / 2)
        nextReplacement = prefixCount
    }

    func record(_ step: PDFDiagnosticSnapshot.Step, page: Int? = nil, index: Int? = nil,
                length: Int? = nil, line: Int? = nil, values: [Double] = [], bounds: CGRect? = nil,
                failure: PDFParseError? = nil) {
        let entry = PDFDiagnosticSnapshot.Entry(sequence: total, step: step, page: page, index: index,
            length: length, line: line, values: values.map { $0.isFinite ? $0 : nil },
            bounds: bounds.map(PDFDiagnosticSnapshot.Rect.init), code: failure?.code, stage: failure?.stage)
        total += 1
        if entries.count < limit { entries.append(entry) }
        else {
            entries[nextReplacement] = entry
            nextReplacement += 1
            if nextReplacement == limit { nextReplacement = prefixCount }
        }
    }

    var snapshot: PDFDiagnosticSnapshot {
        var result = PDFDiagnosticSnapshot(totalEntries: total, omittedEntries: total - entries.count,
                                           entries: entries.sorted { $0.sequence < $1.sequence })
        result.parserVersion = parserVersion
        return result
    }

    func attaching(to error: Error, fallback: PDFParseError.Code = .unreadable) -> PDFParseError {
        var failure = (error as? PDFParseError) ?? PDFParseError(code: fallback)
        record(.failure, page: failure.page, failure: failure)
        failure.trace = snapshot
        return failure
    }
}

/// Explicit full-content export. Kept in memory for one attempt, never stored in
/// the library manifest, a log file, or automatically sent to a service.
struct PDFFullReadDiagnostic: Codable {
    struct Range: Codable {
        var location: Int
        var length: Int
        init(_ value: NSRange) { location = value.location; length = value.length }
    }
    struct Line: Codable {
        var text: String?
        var ranges: [Range]
        var bounds: PDFDiagnosticSnapshot.Rect
    }
    struct Character: Codable {
        var range: Range
        var text: String
        var whitespace: Bool
        var selectionText: String?
        var selectionBounds: PDFDiagnosticSnapshot.Rect?
        // One slot per UTF-16 unit; nil means the native index was out of range.
        var characterBounds: [PDFDiagnosticSnapshot.Rect?]
    }
    struct Page: Codable {
        var number: Int
        var rotation: Int?
        var mediaBox: PDFDiagnosticSnapshot.Rect?
        var nativeCharacterCount: Int?
        var utf16Count: Int?
        var text: String?
        var lines: [Line] = []
        var characters: [Character] = []
        var rules: [PDFRule] = []
        var arrows: [PDFArrow] = []
        var drawingOperations: Int?
        var issues: [PDFParseError] = []
    }
    enum IncompleteReason: String, Codable { case unavailable, locked, pageLimit, characterLimit, rangeLimit, cancelled, drawingFailure }
    var schemaVersion = 1
    var parserVersion = PDFAnalysis.currentVersion(for: .timetable)
    var appVersion: String?
    var appBuild: String?
    var commit: String?
    var osVersion: String?
    var materialKind: String?
    var sourceName: String?
    var analysisSucceeded = false
    var fileBytes: Int?
    var pageCount: Int?
    var locked: Bool?
    var pages: [Page] = []
    var incomplete: [IncompleteReason] = []
    var issues: [PDFParseError] = []
    var attemptFailure: PDFParseError?
    var trace: PDFDiagnosticSnapshot?

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(self)
    }
}
