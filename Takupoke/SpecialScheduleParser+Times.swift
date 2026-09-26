import Foundation

extension SpecialScheduleParser {
    static func readPeriodTimes(_ page: PDFPageLayout, count: Int,
                                        pageNumber: Int) throws -> Times {
        let pattern = try NSRegularExpression(pattern: "([1-8])時限目([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        let consecutivePattern = try NSRegularExpression(pattern: "([1-8])[・･]([1-8])時限連続([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        var times: [Int: String] = [:]
        var consecutive: [String: String] = [:]
        for row in PDFGrid.rows(page.glyphs) {
            let value = PDFSchoolParser.key(row.map(\.text).joined())
            let ns = value as NSString
            for match in pattern.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let period = Int(ns.substring(with: match.range(at: 1)))!
                let start = ns.substring(with: match.range(at: 2))
                let end = ns.substring(with: match.range(at: 3))
                guard period <= count, let startTime = clockMinutes(start),
                      let endTime = clockMinutes(end), startTime < endTime,
                      times[period] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
                }
                times[period] = String(format: "%02d:%02d〜%02d:%02d",
                                       startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
            for match in consecutivePattern.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                let first = Int(ns.substring(with: match.range(at: 1)))!
                let last = Int(ns.substring(with: match.range(at: 2)))!
                let start = ns.substring(with: match.range(at: 3))
                let end = ns.substring(with: match.range(at: 4))
                let key = "\(first)-\(last)"
                guard first < last, last <= count,
                      let startTime = clockMinutes(start), let endTime = clockMinutes(end),
                      startTime < endTime, consecutive[key] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading)
                }
                consecutive[key] = String(format: "%02d:%02d〜%02d:%02d",
                                          startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
        }
        guard times.count == count else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading)
        }
        return Times(single: times, consecutive: consecutive)
    }

    private static func clockMinutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
