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
        let date = base.addingTimeInterval(days * 86_400)
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
    static func weekdayMatches(_ value: String, normalizedDate: String) -> Bool {
        let parts = normalizedDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return false }
        let weekday = ["日", "月", "火", "水", "木", "金", "土"][calendar.component(.weekday, from: date) - 1]
        return [weekday, weekday + "曜", weekday + "曜日", "(" + weekday + ")"].contains(text(value))
    }
}
