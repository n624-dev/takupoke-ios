import Foundation

enum SpecialScheduleKind: String, Codable, CaseIterable, Identifiable {
    case exam, examReturn

    var id: String { rawValue }
    var title: String { self == .exam ? "試験時間割" : "試験返却時間割" }
}

struct SpecialScheduleLesson: Codable, Equatable {
    let date: String
    let className: String
    let period: Int
    let spanStart: Int
    let spanEnd: Int
    let timeRange: String?
    let lines: [String]
    let page: Int

    var subject: String { lines.first ?? "" }
    var teacher: String { lines.count > 1 ? lines[1] : "" }
    var room: String { lines.count > 2 ? lines[2] : "" }
}

struct SpecialScheduleAnalysis: Codable, Equatable {
    static let parserVersion = 6
    var version = parserVersion
    let kind: SpecialScheduleKind
    let sourceDigest: String
    let sourceName: String
    let parsedAt: Date
    let schoolYear: Int
    let coveredDates: [String]
    let coveredClasses: [String]
    let periodTimes: [Int: String]
    let lessons: [SpecialScheduleLesson]

    func applies(date: String, className: String) -> Bool {
        coveredDates.contains(date) && coveredClasses.contains(className)
    }

    func periodTime(on date: String, period: Int) -> String? {
        guard coveredDates.contains(date) else { return nil }
        if kind == .examReturn && date != coveredDates.first {
            guard (1...TimetableSchedule.normalPeriodTimes.count).contains(period) else { return nil }
            return TimetableSchedule.normalPeriodTimes[period - 1]
        }
        return periodTimes[period]
    }

    func timeRange(for lesson: SpecialScheduleLesson) -> String? {
        guard applies(date: lesson.date, className: lesson.className) else { return nil }
        if kind != .examReturn || lesson.date == coveredDates.first,
           let recorded = lesson.timeRange { return recorded }
        guard let start = periodTime(on: lesson.date, period: lesson.spanStart)?
            .components(separatedBy: "〜").first,
              let end = periodTime(on: lesson.date, period: lesson.spanEnd)?
            .components(separatedBy: "〜").last else { return nil }
        return "\(start)〜\(end)"
    }
}

/// Reads only the two table layouts confirmed in the supplied PDFs. A changed
/// layout fails validation and never replaces the previous successful result.
/// The same full-content export format as the ordinary timetable. The special
/// material kind and parser version travel inside diagnostic.json.
enum SpecialScheduleDiagnosticReport {
    static func make(_ diagnostic: PDFFullReadDiagnostic, kind: SpecialScheduleKind,
                     sourceName: String?, succeeded: Bool, failure: PDFParseError?,
                     trace: PDFDiagnosticSnapshot?) -> String? {
        var full = diagnostic
        full.materialKind = kind.rawValue
        full.parserVersion = SpecialScheduleAnalysis.parserVersion
        full.sourceName = sourceName
        full.analysisSucceeded = succeeded
        full.attemptFailure = failure
        full.trace = trace
        return (try? PDFFullDiagnosticEncoding.report(full)) ??
            (try? full.jsonData()).flatMap { String(data: $0, encoding: .utf8) }
                .map { "TAKUPOKE-PDF-FULL-JSON-1\n" + $0 }
    }
}
