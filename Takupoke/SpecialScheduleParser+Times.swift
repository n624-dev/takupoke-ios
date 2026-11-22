import Foundation

extension SpecialScheduleParser {
    static func readPeriodTimes(_ page: PDFPageLayout, count: Int,
                                        pageNumber: Int) throws -> Times {
        guard (1...8).contains(count) else { throw PDFParseError(code:.unsupported,page:pageNumber,stage:.periodHeading, branch:.b245) }
        let pattern = try NSRegularExpression(pattern: "([1-8])時限目([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        let consecutivePattern = try NSRegularExpression(pattern: "([1-8])[・･]([1-8])時限連続([0-9]{1,2}:[0-9]{2})[~〜]([0-9]{1,2}:[0-9]{2})")
        var times: [Int: String] = [:]
        var consecutive: [String: String] = [:]
        for row in PDFGrid.rows(page.glyphs) {
            let value = PDFSchoolParser.key(row.map(\.text).joined())
            let ns = value as NSString
            let singles = pattern.matches(in: value, range: NSRange(location: 0, length: ns.length))
            let pairs = consecutivePattern.matches(in: value, range: NSRange(location: 0, length: ns.length))
            let whole = wholeNumericHeadings(singles + pairs, in: ns)
            guard whole.count == singles.count + pairs.count else {
                throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b425)
            }
            for match in singles {
                let period = Int(ns.substring(with: match.range(at: 1)))!
                let start = ns.substring(with: match.range(at: 2))
                let end = ns.substring(with: match.range(at: 3))
                guard period <= count, let startTime = clockMinutes(start),
                      let endTime = clockMinutes(end), startTime < endTime,
                      times[period] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b246)
                }
                times[period] = String(format: "%02d:%02d〜%02d:%02d",
                                       startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
            for match in pairs {
                let first = Int(ns.substring(with: match.range(at: 1)))!
                let last = Int(ns.substring(with: match.range(at: 2)))!
                let start = ns.substring(with: match.range(at: 3))
                let end = ns.substring(with: match.range(at: 4))
                let key = "\(first)-\(last)"
                guard first < last, last <= count,
                      let startTime = clockMinutes(start), let endTime = clockMinutes(end),
                      startTime < endTime, consecutive[key] == nil else {
                    throw PDFParseError(code: .ambiguous, page: pageNumber, stage: .periodHeading, branch:.b247)
                }
                consecutive[key] = String(format: "%02d:%02d〜%02d:%02d",
                                          startTime / 60, startTime % 60, endTime / 60, endTime % 60)
            }
        }
        guard times.count == count else {
            throw PDFParseError(code: .unsupported, page: pageNumber, stage: .periodHeading, branch:.b248)
        }
        for period in 1..<count {
            // Canonical HH:mm strings have the same order as clock minutes.
            // Explicit consecutive periods remain their own PDF-backed chart.
            guard let previous = times[period], let current = times[period+1],
                  String(previous.suffix(5)) <= String(current.prefix(5)) else {
                throw PDFParseError(code:.ambiguous,page:pageNumber,stage:.periodHeading, branch:.b249)
            }
        }
        return Times(single: times, consecutive: consecutive)
    }

    static func wholeNumericHeadings(_ input: [NSTextCheckingResult], in text: NSString) -> Set<NSRange> {
        guard !input.isEmpty else { return [] }
        let matches = input.sorted { $0.range.location < $1.range.location }
        let units = Array((text as String).utf16)
        var accepted = Set<NSRange>()
        var first = 0
        while first < matches.count {
            var next = first + 1
            // The complete adjacent headings remain independent after spaces
            // are normalized; reject a numeric continuation outside the group.
            while next < matches.count && NSMaxRange(matches[next - 1].range) == matches[next].range.location {
                next += 1
            }
            let start = matches[first].range.location
            let end = NSMaxRange(matches[next - 1].range)
            let startsInNumber = isDecimalDigit(units, at: start - 1)
            // Keep independent complete headings separated by a dot, but do not
            // take the end of a longer list whose first number was not matched.
            let followsHeading = first > 0 && NSMaxRange(matches[first - 1].range) == start - 1
            let startsInPeriodList = start >= 2 && (units[start - 1] == 0x30FB || units[start - 1] == 0xFF65)
                && isDecimalDigit(units, at: start - 2) && !followsHeading
            let endsInNumber = isDecimalDigit(units, at: end)
            // A colon or decimal point followed by a number extends the clock.
            let clockContinues = units.indices.contains(end) && (units[end] == 0x3A || units[end] == 0x2E)
                && isDecimalDigit(units, at: end + 1)
            if !startsInNumber && !startsInPeriodList && !endsInNumber && !clockContinues {
                for index in first..<next { accepted.insert(matches[index].range) }
            }
            first = next
        }
        return accepted
    }

    private static func isDecimalDigit(_ units: [UInt16], at index: Int) -> Bool {
        guard units.indices.contains(index) else { return false }
        var start = index
        if (0xDC00...0xDFFF).contains(units[start]), start > 0,
           (0xD800...0xDBFF).contains(units[start - 1]) { start -= 1 }
        let first = UInt32(units[start])
        let value: UInt32
        if (0xD800...0xDBFF).contains(first), start + 1 < units.count,
           (0xDC00...0xDFFF).contains(UInt32(units[start + 1])) {
            value = 0x10000 + ((first - 0xD800) << 10) + UInt32(units[start + 1]) - 0xDC00
        } else { value = first }
        guard let scalar = Unicode.Scalar(value) else { return false }
        return CharacterSet.decimalDigits.contains(scalar)
    }

    private static func clockMinutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
