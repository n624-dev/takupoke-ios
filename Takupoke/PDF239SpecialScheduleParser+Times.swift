// Strict parsing contract from 239.1 (bfc599fd5a552ced0c140497c703199547c30fd4).
// Includes the documented whole numeric token fix; no recovery proof is implied.
import Foundation

extension PDF239SpecialScheduleParser {
    static func readPeriodTimes(_ page: PDFPageLayout, count: Int,
                                        pageNumber: Int) throws -> Times {
        let pattern = try NSRegularExpression(pattern: "([1-8])時限目([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        let consecutivePattern = try NSRegularExpression(pattern: "([1-8])[・･]([1-8])時限連続([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        var times: [Int: String] = [:]
        var consecutive: [String: String] = [:]
        for row in PDF239Grid.rows(page.glyphs) {
            let value = PDF239SchoolParser.key(row.map(\.text).joined())
            let ns = value as NSString
            let singles = pattern.matches(in: value, range: NSRange(location: 0, length: ns.length))
            let pairs = consecutivePattern.matches(in: value, range: NSRange(location: 0, length: ns.length))
            let whole = wholeNumericHeadings(singles + pairs, in: ns)
            for match in singles where whole.contains(match.range) {
                let period = Int(ns.substring(with: match.range(at: 1)))!
                let start = ns.substring(with: match.range(at: 2))
                let end = ns.substring(with: match.range(at: 3))
                guard period <= count, let startTime = clockMinutes(start),
                      let endTime = clockMinutes(end), startTime < endTime,
                      times[period] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b407)
                }
                times[period] = String(format: "%02d:%02d〜%02d:%02d",
                                       startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
            for match in pairs where whole.contains(match.range) {
                let first = Int(ns.substring(with: match.range(at: 1)))!
                let last = Int(ns.substring(with: match.range(at: 2)))!
                let start = ns.substring(with: match.range(at: 3))
                let end = ns.substring(with: match.range(at: 4))
                let key = "\(first)-\(last)"
                guard first < last, last <= count,
                      let startTime = clockMinutes(start), let endTime = clockMinutes(end),
                      startTime < endTime, consecutive[key] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b406)
                }
                consecutive[key] = String(format: "%02d:%02d〜%02d:%02d",
                                          startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
        }
        guard times.count == count else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading, branch:.b405)
        }
        return Times(single: times, consecutive: consecutive)
    }

    private static func wholeNumericHeadings(_ input: [NSTextCheckingResult], in text: NSString) -> Set<NSRange> {
        let matches = input.sorted { $0.range.location < $1.range.location }
        var accepted = Set<NSRange>()
        var first = 0
        while first < matches.count {
            var next = first + 1
            // Space normalization can place two complete headings directly next
            // to each other. Their shared edge is a real grammar boundary.
            while next < matches.count && NSMaxRange(matches[next - 1].range) == matches[next].range.location {
                next += 1
            }
            let start = matches[first].range.location
            let end = NSMaxRange(matches[next - 1].range)
            let startsInNumber = start > 0 && text.rangeOfCharacter(from: .decimalDigits,
                options: [.backwards, .anchored], range: NSRange(location: 0, length: start)).location != NSNotFound
            let endsInNumber = end < text.length && text.rangeOfCharacter(from: .decimalDigits,
                options: .anchored, range: NSRange(location: end, length: text.length - end)).location != NSNotFound
            if !startsInNumber && !endsInNumber {
                for index in first..<next { accepted.insert(matches[index].range) }
            }
            first = next
        }
        return accepted
    }

    private static func clockMinutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
