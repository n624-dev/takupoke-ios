import Foundation

extension ChangeNormalizer {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    static func serialDate(_ value: String) throws -> String {
        guard matches(value, "^[0-9]+(\\.[0-9]+)?$") else { return value }
        guard let days = Double(value), days > 0, days < 2_958_466 else {
            throw ChangeParseError(code: .date)
        }
        let base = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        guard Int(days) != 60 else { throw ChangeParseError(code: .date) }
        let date = base.addingTimeInterval((days < 60 ? days + 1 : days) * 86_400)
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)/\(c.month!)/\(c.day!)"
    }
    static func date(_ value: String, defaultYear: Int?) throws -> String {
        var v = try serialDate(text(value))
        for separator in ["年", "月", ".", "-"] { v = v.replacingOccurrences(of: separator, with: "/") }
        v = replace(v.replacingOccurrences(of: "日", with: ""), "\\s+", "")
        let parts: [Int]
        if matches(v, "^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$") {
            parts = v.split(separator: "/").compactMap { Int($0) }
        } else if matches(v, "^[0-9]{1,2}/[0-9]{1,2}$"), let year = defaultYear {
            let monthDay = v.split(separator: "/").compactMap { Int($0) }
            guard monthDay.count == 2 else { throw ChangeParseError(code: .date) }
            parts = [monthDay[0] <= 3 ? year + 1 : year] + monthDay
        } else { throw ChangeParseError(code: .date) }
        guard parts.count == 3, (1900...9999).contains(parts[0]),
              (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              let d = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            throw ChangeParseError(code: .date)
        }
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        guard c.year == parts[0], c.month == parts[1], c.day == parts[2] else { throw ChangeParseError(code: .date) }
        return String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
    }
    static func knownWeekday(_ value: String) -> Bool {
        ["日", "月", "火", "水", "木", "金", "土"].contains { day in
            [day, day + "曜", day + "曜日", "(" + day + ")"].contains(text(value))
        }
    }
    static func weekday(_ normalizedDate: String) -> String? {
        let parts = normalizedDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return ["日", "月", "火", "水", "木", "金", "土"][calendar.component(.weekday, from: date) - 1]
    }
    static func weekdayMatches(_ value: String, normalizedDate: String) -> Bool {
        guard let day = weekday(normalizedDate) else { return false }
        return [day, day + "曜", day + "曜日", "(" + day + ")"].contains(text(value))
    }
}

extension ChangeNormalizer {
    static func readableDate(_ value: String, defaultYear: Int?, uses1904: Bool = false) -> String? {
        var input = text(value)
        if uses1904, matches(input, #"^[0-9]+(?:\.[0-9]+)?$"#), let number = Double(input) {
            input = String(number + 1462)
        }
        guard let iso = try? date(input, defaultYear: defaultYear),
              let day = SchoolDate(iso8601: iso) else { return nil }
        return "\(day.year)年\(day.month)月\(day.day)日"
    }

    static func reason(dedicated: String, note: String) -> (reason: String?, remaining: String?) {
        var reasons: [String] = [], other: [String] = []
        for line in note.components(separatedBy: "\n") {
            if let prefix = line.range(of: #"^\s*(変更理由|理由)\s*[:：]\s*(?=\S)"#, options: .regularExpression) {
                reasons.append(String(line[prefix.upperBound...]))
            } else { other.append(line) }
        }
        if !dedicated.isEmpty {
            // Keep independent notes, suppress only repeated verbatim reason lines.
            let retained = note.components(separatedBy: "\n").filter { line in
                guard let range = line.range(of: #"^\s*(変更理由|理由)\s*[:：]\s*(?=\S)"#, options: .regularExpression) else { return true }
                return String(line[range.upperBound...]) != dedicated
            }.joined(separator: "\n")
            return (dedicated, retained == note ? nil : retained)
        }
        guard !reasons.isEmpty else { return (nil, nil) }
        return (reasons.joined(separator: "\n"), other.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct ChangeTimestamp: Codable, Equatable {
    let display: String
    let hasTime: Bool

    static func parse(_ value: String) -> Self? {
        let input = ChangeNormalizer.text(value)
        guard let split = input.range(of: #"^\d{4}([/-]\d{1,2}[/-]\d{1,2}|年\d{1,2}月\d{1,2}日)"#, options: .regularExpression),
              let day = try? ChangeNormalizer.date(String(input[split]), defaultYear: nil) else { return nil }
        let suffix = String(input[split.upperBound...])
        let printed = day.replacingOccurrences(of: "-", with: "/")
        if suffix.isEmpty { return Self(display: printed, hasTime: false) }
        guard ChangeNormalizer.matches(suffix, #"^[T ](?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,9})?)?(?:Z|[+-](?:0\d|1[0-3]):[0-5]\d|[+-]14:00)?$"#) else { return nil }
        var clock = String(suffix.dropFirst())
        let zone = clock.range(of: #"Z|[+-]\d\d:\d\d$"#, options: .regularExpression)
        let offset = zone.map { String(clock[$0]) } ?? "+09:00"
        if let zone { clock.removeSubrange(zone) }
        clock = String(clock.split(separator: ".")[0])
        if clock.count == 5 { clock += ":00" }
        let formatter = ISO8601DateFormatter()
        guard let instant = formatter.date(from: day + "T" + clock + offset) else { return nil }
        return Self(display: japan(instant), hasTime: true)
    }

    static func japan(_ instant: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: instant)
    }

    static func serial(_ text: String, uses1904: Bool, clock: Bool) -> Self? {
        guard let days = Double(text), days.isFinite, days >= 0,
              let date = try? ChangeNormalizer.date(String(days + (uses1904 ? 1462 : 0)), defaultYear: nil) else { return nil }
        let minute = Int(floor((days - floor(days)) * 1440 + 0.0000001))
        let suffix = clock ? String(format: " %02d:%02d", min(minute, 1439) / 60, min(minute, 1439) % 60) : ""
        return Self(display: date.replacingOccurrences(of: "-", with: "/") + suffix, hasTime: clock)
    }
}
