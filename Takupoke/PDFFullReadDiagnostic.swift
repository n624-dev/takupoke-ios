import Foundation

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
